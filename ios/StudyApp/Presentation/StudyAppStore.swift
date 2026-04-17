import Combine
import Foundation
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class StudyAppContainer: ObservableObject {
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var isLoaded = false
    @Published var errorMessage: String?
    @Published private(set) var dataVersion = 0
    @Published private(set) var syncStatus = SyncStatus()

    let persistence: PersistenceController
    let preferencesRepository: UserDefaultsPreferencesRepository
    let googleBooksService: GoogleBooksService
    let reminderScheduler: ReminderScheduler
    let logger: AppLogger
    let clock = Clock()
    let authRepository: FirebaseAuthRepository
    let syncRepository: FirebaseSyncRepository

    private lazy var widgetSnapshotSync = WidgetSnapshotSync(container: self)
    private lazy var liveActivityController = StudyLiveActivityController(persistence: persistence, logger: logger)
    private var cancellables = Set<AnyCancellable>()
    private var autoSyncDelayTask: Task<Void, Never>?
    private var liveActivitySyncTask: Task<Void, Never>?
    private var lastAutoSyncDataVersion: Int?
    private let autoSyncBlockedKey = "studyapp.sync.autoSyncBlockedUntilLocalChange"
    private var pendingAutoSyncRequest: (reason: String, dataVersion: Int)?
    private var isAutoSyncRunning = false

    convenience init() {
        let persistence = PersistenceController.shared
        let preferencesRepository = UserDefaultsPreferencesRepository()
        let googleBooksService = GoogleBooksService()
        let reminderScheduler = ReminderScheduler()
        let logger = AppLogger()
        let authRepository = FirebaseAuthRepository(logger: logger)

        self.init(
            persistence: persistence,
            preferencesRepository: preferencesRepository,
            googleBooksService: googleBooksService,
            reminderScheduler: reminderScheduler,
            logger: logger,
            authRepository: authRepository,
            syncRepository: nil
        )
    }

    init(
        persistence: PersistenceController,
        preferencesRepository: UserDefaultsPreferencesRepository,
        googleBooksService: GoogleBooksService,
        reminderScheduler: ReminderScheduler,
        logger: AppLogger,
        authRepository: FirebaseAuthRepository,
        syncRepository: FirebaseSyncRepository?
    ) {
        self.persistence = persistence
        self.preferencesRepository = preferencesRepository
        self.googleBooksService = googleBooksService
        self.reminderScheduler = reminderScheduler
        self.logger = logger
        self.authRepository = authRepository
        self.syncRepository = syncRepository ?? FirebaseSyncRepository(
            authRepository: authRepository,
            persistence: persistence,
            preferencesRepository: preferencesRepository,
            logger: logger
        )
        self.preferences = preferencesRepository.loadPreferences()
        self.syncStatus = self.syncRepository.status

        self.syncRepository.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] newStatus in
                self?.syncStatus = newStatus
            }
            .store(in: &cancellables)

        Task {
            logger.log(category: .app, message: "StudyAppContainer initialized")
            await load()
        }
    }

    func load() async {
        do {
            try await persistence.migrateLegacySnapshotIfNeeded(preferencesRepository: preferencesRepository)
            preferences = preferencesRepository.loadPreferences()
            syncStatus = syncRepository.status
            isLoaded = true
            logger.log(category: .app, message: "Initial app load completed", details: "isLoaded=true")
            bumpDataVersion(shouldScheduleAutoSync: false)
            scheduleAutoSync(reason: "app-load")
            syncLiveActivity(reason: "app-load")
        } catch {
            isLoaded = true
            present(error)
        }
    }

    func savePreferences(_ update: (inout AppPreferences) -> Void) {
        let previous = preferences
        var next = preferences
        update(&next)
        preferences = next
        preferencesRepository.savePreferences(next)
        widgetSnapshotSync.scheduleRefresh(reason: "preferences")
        if shouldSyncLiveActivity(previous: previous, next: next) {
            syncLiveActivity(reason: "preferences")
        }
        objectWillChange.send()
    }

    func completeOnboarding() {
        savePreferences { $0.onboardingCompleted = true }
    }

    func setThemeMode(_ mode: ThemeMode) {
        savePreferences { $0.selectedThemeMode = mode }
    }

    func setColorTheme(_ theme: ColorTheme) {
        savePreferences { $0.selectedColorTheme = theme }
    }

    func setLiveActivityEnabled(_ enabled: Bool) {
        savePreferences { $0.liveActivityEnabled = enabled }
    }

    func setLiveActivityDisplayPreset(_ preset: LiveActivityDisplayPreset) {
        savePreferences { $0.liveActivityDisplayPreset = preset }
    }

    func setReminderEnabled(_ enabled: Bool) async {
        if enabled {
            do {
                let granted = try await reminderScheduler.requestAuthorizationIfNeeded()
                guard granted else {
                    present("通知の許可が必要です")
                    return
                }
                try await reminderScheduler.scheduleDailyReminder(hour: preferences.reminderHour, minute: preferences.reminderMinute)
                savePreferences { $0.reminderEnabled = true }
            } catch {
                present(error)
            }
        } else {
            reminderScheduler.cancelReminder()
            savePreferences { $0.reminderEnabled = false }
        }
    }

    func setReminderTime(hour: Int, minute: Int) async {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            present("時刻の形式が正しくありません")
            return
        }
        do {
            if preferences.reminderEnabled {
                try await reminderScheduler.scheduleDailyReminder(hour: hour, minute: minute)
            }
            savePreferences {
                $0.reminderHour = hour
                $0.reminderMinute = minute
            }
        } catch {
            present(error)
        }
    }

    func updateActiveTimer(_ timer: TimerSnapshot?) {
        savePreferences { $0.activeTimer = timer }
    }

    func bumpDataVersion(shouldScheduleAutoSync: Bool = true) {
        dataVersion += 1
        widgetSnapshotSync.scheduleRefresh(reason: "data-version-\(dataVersion)")
        if preferences.activeTimer != nil {
            syncLiveActivity(reason: "data-version-\(dataVersion)")
        }
        if shouldScheduleAutoSync {
            scheduleAutoSync(reason: "data-version-\(dataVersion)")
        }
    }

    func clearError() {
        errorMessage = nil
    }

    func refreshSyncStatus() {
        syncStatus = syncRepository.status
    }

    func handleSceneDidBecomeActive() {
        scheduleAutoSync(reason: "scene-active")
    }

    func scheduleAutoSync(reason: String) {
        guard syncRepository.status.isAuthenticated else { return }

        if isAutoSyncBlockedUntilLocalChange {
            if reason.hasPrefix("data-version-") {
                isAutoSyncBlockedUntilLocalChange = false
            } else {
                logger.log(category: .sync, message: "Auto sync skipped", details: "reason=\(reason) blocked=true")
                return
            }
        }

        let currentVersion = dataVersion
        if lastAutoSyncDataVersion == currentVersion, reason != "scene-active", reason != "app-load" {
            return
        }

        pendingAutoSyncRequest = (reason, currentVersion)
        autoSyncDelayTask?.cancel()
        autoSyncDelayTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            await self.runQueuedAutoSync()
        }
    }

    private func runQueuedAutoSync() async {
        guard !isAutoSyncRunning else { return }

        while let request = pendingAutoSyncRequest {
            guard syncRepository.status.isAuthenticated else {
                pendingAutoSyncRequest = nil
                return
            }
            guard !syncRepository.status.isSyncing else { return }

            pendingAutoSyncRequest = nil
            isAutoSyncRunning = true
            do {
                logger.log(category: .sync, message: "Auto sync started", details: "reason=\(request.reason) dataVersion=\(request.dataVersion)")
                try await syncRepository.syncNow()
                refreshSyncStatus()
                lastAutoSyncDataVersion = request.dataVersion
                logger.log(category: .sync, message: "Auto sync completed", details: "reason=\(request.reason) dataVersion=\(request.dataVersion)")
            } catch {
                logger.log(category: .sync, level: .warning, message: "Auto sync failed", details: "reason=\(request.reason)", error: error)
            }
            isAutoSyncRunning = false
        }
    }

    func recordManualSyncApplied() {
        lastAutoSyncDataVersion = dataVersion
        isAutoSyncBlockedUntilLocalChange = false
    }

    func blockAutoSyncUntilLocalChange() {
        autoSyncDelayTask?.cancel()
        autoSyncDelayTask = nil
        pendingAutoSyncRequest = nil
        isAutoSyncBlockedUntilLocalChange = true
    }

    func present(_ error: Error) {
        logger.log(category: .ui, level: .error, message: "Presented error to user", error: error)
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    func present(_ message: String) {
        logger.log(category: .ui, level: .warning, message: "Presented message to user", details: message)
        errorMessage = message
    }

    private var isAutoSyncBlockedUntilLocalChange: Bool {
        get { UserDefaults.standard.bool(forKey: autoSyncBlockedKey) }
        set { UserDefaults.standard.set(newValue, forKey: autoSyncBlockedKey) }
    }

    private func shouldSyncLiveActivity(previous: AppPreferences, next: AppPreferences) -> Bool {
        previous.activeTimer != next.activeTimer ||
        previous.liveActivityEnabled != next.liveActivityEnabled ||
        previous.liveActivityDisplayPreset != next.liveActivityDisplayPreset
    }

    private func syncLiveActivity(reason: String) {
        liveActivitySyncTask?.cancel()
        let preferences = self.preferences
        let activeTimer = preferences.activeTimer
        liveActivitySyncTask = Task { [weak self] in
            guard let self else { return }
            await self.liveActivityController.sync(activeTimer: activeTimer, preferences: preferences, reason: reason)
        }
    }
}

@MainActor
class ScreenViewModel: ObservableObject {
    unowned let app: StudyAppContainer

    init(app: StudyAppContainer) {
        self.app = app
    }

    func perform(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                app.present(error)
            }
        }
    }
}

@MainActor
final class OnboardingViewModel: ScreenViewModel {
    func complete() {
        app.completeOnboarding()
    }
}

@MainActor
final class HomeViewModel: ScreenViewModel {
    @Published private(set) var homeData = HomeData(todayStudyMinutes: 0, todaySessions: [], weeklyGoal: nil, weeklyStudyMinutes: 0, upcomingExams: [])
    @Published private(set) var recentMaterials: [(Material, Subject)] = []

    func load() async {
        do {
            let homeUseCase = GetHomeDataUseCase(studySessionRepository: app.persistence, goalRepository: app.persistence, examRepository: app.persistence, clock: app.clock)
            let recentUseCase = GetRecentMaterialsUseCase(materialRepository: app.persistence, studySessionRepository: app.persistence, subjectRepository: app.persistence)
            homeData = try await homeUseCase.execute()
            recentMaterials = try await recentUseCase.execute()
        } catch {
            app.present(error)
        }
    }
}

@MainActor
final class SubjectsViewModel: ScreenViewModel {
    @Published private(set) var subjects: [Subject] = []

    func load() async {
        do {
            subjects = try await app.persistence.getAllSubjects()
        } catch {
            app.present(error)
        }
    }

    func saveSubject(id: Int64? = nil, name: String, color: Int, icon: SubjectIcon?) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "科目名を入力してください") }
            if let id {
                try await self.app.persistence.updateSubject(
                    Subject(id: id, name: trimmed, color: color, icon: icon, createdAt: Date().epochMilliseconds, updatedAt: Date().epochMilliseconds)
                )
            } else {
                _ = try await self.app.persistence.insertSubject(Subject(name: trimmed, color: color, icon: icon))
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteSubject(_ subject: Subject) {
        perform {
            try await self.app.persistence.deleteSubject(subject)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class MaterialsViewModel: ScreenViewModel {
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var materials: [Material] = []
    @Published var bookSearchResult: BookInfo?
    @Published var isShowingBookResult = false
    @Published private(set) var isSearchingBook = false

    private var lastRequestedIsbn = ""

    func load() async {
        do {
            async let subjectsTask = app.persistence.getAllSubjects()
            async let materialsTask = app.persistence.getAllMaterials()
            subjects = try await subjectsTask
            materials = try await materialsTask
        } catch {
            app.present(error)
        }
    }

    func materials(for subjectId: Int64) -> [Material] {
        materials.filter { $0.subjectId == subjectId }
    }

    func searchBook(isbn: String) {
        let normalizedIsbn = isbn
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !normalizedIsbn.isEmpty else {
            app.present("ISBNを入力してください")
            return
        }
        guard !(isSearchingBook && lastRequestedIsbn == normalizedIsbn) else { return }

        isSearchingBook = true
        lastRequestedIsbn = normalizedIsbn
        perform {
            defer { self.isSearchingBook = false }
            let useCase = ManageMaterialsUseCase(materialRepository: self.app.persistence, subjectRepository: self.app.persistence, bookSearchRepository: self.app.googleBooksService)
            self.bookSearchResult = try await useCase.searchBook(isbn: normalizedIsbn)
            self.isShowingBookResult = self.bookSearchResult != nil
        }
    }

    func clearSearchResult() {
        bookSearchResult = nil
        isShowingBookResult = false
    }

    func saveMaterial(id: Int64? = nil, name: String, subjectId: Int64, totalPages: Int, currentPage: Int = 0, note: String?) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "教材名を入力してください") }
            guard totalPages >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard currentPage >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard totalPages == 0 || currentPage <= totalPages else { throw ValidationError(message: "現在のページは総ページ数以下にしてください") }
            if let id {
                guard let subject = try await self.app.persistence.getSubjectById(subjectId) else {
                    throw ValidationError(message: "科目を選択してください")
                }
                try await self.app.persistence.updateMaterial(
                    Material(
                        id: id,
                        name: trimmed,
                        subjectId: subjectId,
                        subjectSyncId: subject.syncId,
                        totalPages: totalPages,
                        currentPage: currentPage,
                        color: nil,
                        note: note?.nilIfBlank
                    )
                )
            } else {
                let useCase = ManageMaterialsUseCase(materialRepository: self.app.persistence, subjectRepository: self.app.persistence, bookSearchRepository: self.app.googleBooksService)
                try await useCase.addMaterial(name: trimmed, subjectId: subjectId, totalPages: totalPages, note: note?.nilIfBlank)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func updateProgress(materialId: Int64, currentPage: Int) {
        perform {
            let materials = try await self.app.persistence.getAllMaterials()
            guard let material = materials.first(where: { $0.id == materialId }) else {
                throw ValidationError(message: "教材が見つかりません")
            }
            var updated = material
            updated.currentPage = currentPage
            try await self.app.persistence.updateMaterial(updated)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteMaterial(_ material: Material) {
        perform {
            try await self.app.persistence.deleteMaterial(material)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class TimerViewModel: ScreenViewModel {
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var materials: [Material] = []
    @Published private(set) var elapsedMilliseconds: Int64 = 0
    @Published var selectedSubjectId: Int64?
    @Published var selectedMaterialId: Int64?

    private var cancellable: AnyCancellable?

    func load() async {
        do {
            async let subjectsTask = app.persistence.getAllSubjects()
            async let materialsTask = app.persistence.getAllMaterials()
            subjects = try await subjectsTask
            materials = try await materialsTask
            let activeTimer = app.preferences.activeTimer
            selectedSubjectId = resolveSelectedSubjectId(activeTimer: activeTimer)
            selectedMaterialId = resolveSelectedMaterialId(activeTimer: activeTimer, subjectId: selectedSubjectId)
            elapsedMilliseconds = activeTimer?.elapsedTime() ?? 0
            syncActiveTimerSelection()
            configureTicker()
        } catch {
            app.present(error)
        }
    }

    var isRunning: Bool {
        app.preferences.activeTimer?.isRunning ?? false
    }

    var recentMaterialPairs: [(Material, Subject)] {
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        return materials.compactMap { material in
            guard let subject = subjectMap[material.subjectId] else { return nil }
            return (material, subject)
        }
    }

    var effectiveSelectedSubjectId: Int64? {
        resolvedSubjectId(activeTimer: app.preferences.activeTimer)
    }

    func materialsForSelectedSubject() -> [Material] {
        guard let subjectId = effectiveSelectedSubjectId else { return [] }
        return materials.filter { $0.subjectId == subjectId }
    }

    func startOrResume() {
        perform {
            guard let subjectId = self.effectiveSelectedSubjectId else {
                throw ValidationError(message: "科目を選択してください")
            }
            let current = self.app.preferences.activeTimer
            let next = TimerSnapshot(
                subjectId: subjectId,
                materialId: self.selectedMaterialId,
                startedAt: Date().epochMilliseconds,
                accumulatedMilliseconds: current?.elapsedTime() ?? 0,
                isRunning: true
            )
            self.app.updateActiveTimer(next)
            self.elapsedMilliseconds = next.elapsedTime()
            self.configureTicker()
        }
    }

    func pause() {
        guard var timer = app.preferences.activeTimer else { return }
        timer.accumulatedMilliseconds = timer.elapsedTime()
        timer.startedAt = nil
        timer.isRunning = false
        app.updateActiveTimer(timer)
        elapsedMilliseconds = timer.accumulatedMilliseconds
        configureTicker()
    }

    func handleSubjectSelectionChange() {
        selectedSubjectId = effectiveSelectedSubjectId
        selectedMaterialId = resolveSelectedMaterialId(activeTimer: app.preferences.activeTimer, subjectId: selectedSubjectId)
        syncActiveTimerSelection()
    }

    func handleMaterialSelectionChange() {
        selectedMaterialId = resolveSelectedMaterialId(activeTimer: app.preferences.activeTimer, subjectId: selectedSubjectId)
        syncActiveTimerSelection()
    }

    func stop(note: String? = nil) {
        perform {
            guard let timer = self.app.preferences.activeTimer else { return }
            let elapsed = timer.elapsedTime()
            guard elapsed > 0 else {
                self.app.updateActiveTimer(nil)
                self.elapsedMilliseconds = 0
                self.configureTicker()
                return
            }
            let subject = if let selectedSubject = self.selectedSubject {
                selectedSubject
            } else {
                try await self.app.persistence.getSubjectById(timer.subjectId)
            }
            guard let subject else {
                throw ValidationError(message: "科目を選択してください")
            }
            let materials = try await self.app.persistence.getAllMaterials()
            let materialId = self.selectedMaterialId
            let material = materials.first(where: { $0.id == materialId })
            let materialName = material?.name ?? ""
            let end = Date().epochMilliseconds
            let start = end - elapsed
            _ = try await self.app.persistence.insertSession(
                StudySession(
                    materialId: materialId,
                    materialSyncId: material?.syncId,
                    materialName: materialName,
                    subjectId: subject.id,
                    subjectSyncId: subject.syncId,
                    subjectName: subject.name,
                    startTime: start,
                    endTime: end,
                    note: note?.nilIfBlank
                )
            )
            self.app.updateActiveTimer(nil)
            self.elapsedMilliseconds = 0
            self.configureTicker()
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func saveManualSession(subjectId: Int64, materialId: Int64?, durationMinutes: Int, note: String?) {
        perform {
            guard durationMinutes > 0 else { throw ValidationError(message: "学習時間は0より大きくしてください") }
            let useCase = SaveStudySessionUseCase(sessionRepository: self.app.persistence, subjectRepository: self.app.persistence, materialRepository: self.app.persistence)
            try await useCase.saveManualSession(subjectId: subjectId, materialId: materialId, durationMinutes: durationMinutes, note: note)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    private func configureTicker() {
        cancellable?.cancel()
        guard app.preferences.activeTimer?.isRunning == true else { return }
        cancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                self.elapsedMilliseconds = self.app.preferences.activeTimer?.elapsedTime() ?? 0
            }
    }

    private var selectedSubject: Subject? {
        guard let subjectId = effectiveSelectedSubjectId else { return nil }
        return subjects.first(where: { $0.id == subjectId })
    }

    private func resolvedSubjectId(activeTimer: TimerSnapshot?) -> Int64? {
        if let selectedSubjectId, subjects.contains(where: { $0.id == selectedSubjectId }) {
            return selectedSubjectId
        }
        if let timerSubjectId = activeTimer?.subjectId, subjects.contains(where: { $0.id == timerSubjectId }) {
            return timerSubjectId
        }
        return subjects.first?.id
    }

    private func resolveSelectedSubjectId(activeTimer: TimerSnapshot?) -> Int64? {
        resolvedSubjectId(activeTimer: activeTimer)
    }

    private func resolveSelectedMaterialId(activeTimer: TimerSnapshot?, subjectId: Int64?) -> Int64? {
        guard let subjectId else { return nil }
        let availableMaterials = materials.filter { $0.subjectId == subjectId }

        if let selectedMaterialId, availableMaterials.contains(where: { $0.id == selectedMaterialId }) {
            return selectedMaterialId
        }
        if let timerMaterialId = activeTimer?.materialId,
           availableMaterials.contains(where: { $0.id == timerMaterialId }) {
            return timerMaterialId
        }
        return nil
    }

    private func syncActiveTimerSelection() {
        guard var timer = app.preferences.activeTimer else { return }
        guard let subjectId = effectiveSelectedSubjectId else { return }

        let materialId = selectedMaterialId
        guard timer.subjectId != subjectId || timer.materialId != materialId else { return }

        timer.subjectId = subjectId
        timer.materialId = materialId
        app.updateActiveTimer(timer)
    }
}

@MainActor
final class HistoryViewModel: ScreenViewModel {
    @Published private(set) var sessions: [StudySession] = []
    @Published private(set) var subjects: [Subject] = []
    @Published var filterSubjectId: Int64?

    var filteredSessions: [StudySession] {
        guard let filterSubjectId else { return sessions }
        return sessions.filter { $0.subjectId == filterSubjectId }
    }

    func load() async {
        do {
            async let sessionsTask = app.persistence.getAllSessions()
            async let subjectsTask = app.persistence.getAllSubjects()
            sessions = try await sessionsTask
            subjects = try await subjectsTask
        } catch {
            app.present(error)
        }
    }

    func setFilter(_ subjectId: Int64?) {
        filterSubjectId = subjectId
    }

    func updateSession(_ session: StudySession, durationMinutes: Int, note: String?) {
        perform {
            guard durationMinutes > 0 else { throw ValidationError(message: "学習時間は0より大きくしてください") }
            var updated = session
            updated.endTime = updated.startTime + Int64(durationMinutes * 60_000)
            updated.note = note?.nilIfBlank
            try await self.app.persistence.updateSession(updated)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteSession(_ session: StudySession) {
        perform {
            try await self.app.persistence.deleteSession(session)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class GoalsViewModel: ScreenViewModel {
    @Published private(set) var dailyGoal: Goal?
    @Published private(set) var weeklyGoal: Goal?

    func load() async {
        do {
            dailyGoal = try await app.persistence.getActiveGoalByType(.daily)
            weeklyGoal = try await app.persistence.getActiveGoalByType(.weekly)
        } catch {
            app.present(error)
        }
    }

    func updateGoal(type: GoalType, targetMinutes: Int) {
        perform {
            guard targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            let useCase = ManageGoalsUseCase(repository: self.app.persistence)
            try await useCase.updateGoal(type: type, targetMinutes: targetMinutes)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class ExamsViewModel: ScreenViewModel {
    @Published private(set) var exams: [Exam] = []

    func load() async {
        do {
            exams = try await app.persistence.getAllExams()
        } catch {
            app.present(error)
        }
    }

    func saveExam(id: Int64? = nil, name: String, date: Date, note: String?) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "テスト名を入力してください") }
            let exam = Exam(id: id ?? 0, name: trimmed, date: date.startOfDay.epochDay, note: note?.nilIfBlank)
            if id == nil {
                _ = try await self.app.persistence.insertExam(exam)
            } else {
                try await self.app.persistence.updateExam(exam)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteExam(_ exam: Exam) {
        perform {
            try await self.app.persistence.deleteExam(exam)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class PlanViewModel: ScreenViewModel {
    @Published private(set) var plans: [StudyPlan] = []
    @Published private(set) var activePlan: StudyPlan?
    @Published private(set) var planItems: [PlanItem] = []
    @Published private(set) var subjects: [Subject] = []
    @Published var selectedDay: StudyWeekday?

    var weeklySchedule: [StudyWeekday: [PlanItemWithSubject]] {
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        return Dictionary(uniqueKeysWithValues: StudyWeekday.allCases.map { day in
            let dayItems = planItems
                .filter { $0.dayOfWeek == day }
                .compactMap { item -> PlanItemWithSubject? in
                    guard let subject = subjectMap[item.subjectId] else { return nil }
                    return PlanItemWithSubject(item: item, subject: subject)
                }
            return (day, dayItems)
        })
    }

    var totalTargetMinutes: Int {
        planItems.reduce(0) { $0 + $1.targetMinutes }
    }

    var completionRate: Double {
        guard totalTargetMinutes > 0 else { return 0 }
        let totalActual = planItems.reduce(0) { $0 + $1.actualMinutes }
        return min(Double(totalActual) / Double(totalTargetMinutes), 1)
    }

    func load() async {
        do {
            async let plansTask = app.persistence.getAllPlans()
            async let subjectsTask = app.persistence.getAllSubjects()
            let loadedPlans = try await plansTask
            plans = loadedPlans
            activePlan = loadedPlans.first(where: \.isActive)
            subjects = try await subjectsTask
            if let activePlan {
                planItems = try await app.persistence.getPlanItems(planId: activePlan.id)
                if selectedDay == nil {
                    selectedDay = StudyWeekday.allCases.first(where: { !(weeklySchedule[$0] ?? []).isEmpty }) ?? .monday
                }
            } else {
                planItems = []
                selectedDay = nil
            }
        } catch {
            app.present(error)
        }
    }

    func createPlan(name: String, startDate: Date, endDate: Date, items: [PlanItem]) {
        perform {
            let useCase = ManagePlansUseCase(repository: self.app.persistence)
            let syncedItems = items.map { item -> PlanItem in
                var value = item
                value.subjectSyncId = self.subjects.first(where: { $0.id == item.subjectId })?.syncId
                return value
            }
            try await useCase.createPlan(name: name, startDate: startDate, endDate: endDate, items: syncedItems)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func savePlanItem(_ item: PlanItem) {
        perform {
            guard item.targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            let subjectSyncId = self.subjects.first(where: { $0.id == item.subjectId })?.syncId
            let planSyncId = item.planSyncId ?? self.activePlan?.syncId
            if item.id == 0 {
                guard let activePlan = self.activePlan else {
                    throw ValidationError(message: "アクティブなプランがありません")
                }
                _ = try await self.app.persistence.insertPlanItem(
                    PlanItem(
                        planId: activePlan.id,
                        planSyncId: activePlan.syncId,
                        subjectId: item.subjectId,
                        subjectSyncId: subjectSyncId,
                        dayOfWeek: item.dayOfWeek,
                        targetMinutes: item.targetMinutes,
                        actualMinutes: item.actualMinutes,
                        timeSlot: item.timeSlot
                    )
                )
            } else {
                var updatedItem = item
                updatedItem.planSyncId = planSyncId
                updatedItem.subjectSyncId = subjectSyncId
                try await self.app.persistence.updatePlanItem(updatedItem)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deletePlanItem(_ item: PlanItem) {
        perform {
            try await self.app.persistence.deletePlanItem(item)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteActivePlan() {
        perform {
            guard let activePlan = self.activePlan else { return }
            try await self.app.persistence.deletePlan(activePlan)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class CalendarViewModel: ScreenViewModel {
    @Published private(set) var monthStudyMap: [Int: Int] = [:]
    @Published private(set) var daySessionsMap: [Int: [StudySession]] = [:]
    @Published var displayedMonth = Date()

    func load() async {
        do {
            let monthInterval = Calendar.current.dateInterval(of: .month, for: displayedMonth)
            let start = monthInterval?.start ?? displayedMonth.startOfDay
            let end = monthInterval?.end ?? displayedMonth
            let sessions = try await app.persistence.getSessionsBetweenDates(
                start: start.epochMilliseconds,
                end: end.epochMilliseconds
            )
            let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }

            monthStudyMap = sortedSessions.reduce(into: [:]) { result, session in
                let day = Calendar.current.component(.day, from: session.startDate)
                result[day, default: 0] += session.durationMinutes
            }
            daySessionsMap = Dictionary(grouping: sortedSessions) { session in
                Calendar.current.component(.day, from: session.startDate)
            }
        } catch {
            app.present(error)
        }
    }

    func sessions(for day: Int) -> [StudySession] {
        daySessionsMap[day] ?? []
    }

    func totalMinutes(for day: Int) -> Int {
        sessions(for: day).reduce(0) { $0 + $1.durationMinutes }
    }

    func updateSessionNote(_ session: StudySession, note: String?) {
        perform {
            var updated = session
            updated.note = note?.nilIfBlank
            try await self.app.persistence.updateSession(updated)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class ReportsViewModel: ScreenViewModel {
    @Published private(set) var reports = ReportsData(daily: [], weekly: [], monthly: [], bySubject: [], streakDays: 0, bestStreak: 0)

    func load() async {
        do {
            let useCase = GetReportsDataUseCase(subjectRepository: app.persistence, sessionRepository: app.persistence, clock: app.clock)
            reports = try await useCase.execute()
        } catch {
            app.present(error)
        }
    }
}

@MainActor
final class SettingsViewModel: ScreenViewModel {
    @Published private(set) var exportURL: URL?
    @Published private(set) var summary = SettingsSummary(totalSessions: 0, totalStudyMinutes: 0)
    @Published private(set) var debugLogEntries: [DebugLogEntry] = []
    @Published var syncEmail = ""
    @Published var syncPassword = ""

    func load() async {
        do {
            let useCase = GetSettingsSummaryUseCase(sessionRepository: app.persistence)
            summary = try await useCase.execute()
            app.refreshSyncStatus()
            debugLogEntries = app.logger.recentEntries()
        } catch {
            app.present(error)
        }
    }

    func export(format: ExportFormat) {
        perform {
            let useCase = ExportImportDataUseCase(repository: self.app.persistence)
            let contents = try await (format == .json ? useCase.exportJSON() : useCase.exportCSV())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("studyapp_backup_\(Int(Date().timeIntervalSince1970)).\(format.rawValue)")
            try contents.write(to: url, atomically: true, encoding: .utf8)
            self.app.logger.log(category: .app, message: "Export completed", details: "format=\(format.rawValue) url=\(url.lastPathComponent)")
            self.exportURL = url
        }
    }

    func importBackup(from url: URL) {
        perform {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let useCase = ExportImportDataUseCase(repository: self.app.persistence)
            let preferences = try await useCase.importJSON(contents, currentPreferences: self.app.preferences)
            self.app.savePreferences { $0 = preferences }
            self.app.logger.log(category: .app, message: "Backup import completed", details: "file=\(url.lastPathComponent)")
            self.app.bumpDataVersion()
        }
    }

    func deleteAllData() {
        perform {
            try await self.app.persistence.deleteAllData()
            if self.app.syncStatus.isAuthenticated {
                try await self.app.syncRepository.importLocalDataToCloud()
            } else {
                await self.app.syncRepository.clearLocalSyncState()
            }
            self.app.updateActiveTimer(nil)
            self.summary = SettingsSummary(totalSessions: 0, totalStudyMinutes: 0)
            self.app.logger.log(category: .app, level: .warning, message: "All local data deleted")
            self.app.bumpDataVersion(shouldScheduleAutoSync: false)
            self.app.recordManualSyncApplied()
        }
    }

    func signInToSync() {
        perform {
            let password = self.syncPassword
            let email = self.syncEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            defer { self.syncPassword = "" }
            self.app.logger.log(category: .auth, message: "Sign in requested", details: "emailProvided=\(!email.isEmpty) passwordLength=\(password.count)")
            try await self.app.authRepository.signIn(email: email, password: password)
            self.app.refreshSyncStatus()
            self.app.scheduleAutoSync(reason: "sign-in")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func createSyncAccount() {
        perform {
            let password = self.syncPassword
            let email = self.syncEmail.trimmingCharacters(in: .whitespacesAndNewlines)
            defer { self.syncPassword = "" }
            self.app.logger.log(category: .auth, message: "Sign up requested", details: "emailProvided=\(!email.isEmpty) passwordLength=\(password.count)")
            try await self.app.authRepository.signUp(email: email, password: password)
            self.app.refreshSyncStatus()
            self.app.scheduleAutoSync(reason: "sign-up")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func signOutOfSync() {
        perform {
            try await self.app.authRepository.signOut()
            self.app.logger.log(category: .auth, message: "Sign out completed")
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func syncNow() {
        guard !app.syncStatus.isSyncing else {
            app.logger.log(category: .sync, level: .warning, message: "syncNow ignored in view model", details: "reason=already-syncing")
            return
        }
        perform {
            try await self.app.syncRepository.syncNow()
            self.app.refreshSyncStatus()
            self.summary = try await GetSettingsSummaryUseCase(sessionRepository: self.app.persistence).execute()
            self.debugLogEntries = self.app.logger.recentEntries()
            self.app.bumpDataVersion(shouldScheduleAutoSync: false)
            self.app.recordManualSyncApplied()
        }
    }

    func importLocalDataToCloud() {
        guard !app.syncStatus.isSyncing else {
            app.logger.log(category: .sync, level: .warning, message: "importLocalDataToCloud ignored in view model", details: "reason=already-syncing")
            return
        }
        perform {
            try await self.app.syncRepository.importLocalDataToCloud()
            self.app.refreshSyncStatus()
            self.app.recordManualSyncApplied()
            self.debugLogEntries = self.app.logger.recentEntries()
        }
    }

    func refreshDebugLogs() {
        debugLogEntries = app.logger.recentEntries()
    }

    func exportDebugLogs() {
        guard AppLogger.isDebugToolsEnabled else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("studyapp_debug_logs_\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try app.logger.exportText().write(to: url, atomically: true, encoding: .utf8)
            app.logger.log(category: .app, message: "Debug logs exported", details: "file=\(url.lastPathComponent)")
            exportURL = url
            debugLogEntries = app.logger.recentEntries()
        } catch {
            app.present(error)
        }
    }

    func copyDebugLogs() {
        guard AppLogger.isDebugToolsEnabled else { return }
        #if canImport(UIKit)
        UIPasteboard.general.string = app.logger.exportText()
        app.logger.log(category: .app, message: "Debug logs copied to clipboard", details: "entryCount=\(app.logger.recentEntries().count)")
        debugLogEntries = app.logger.recentEntries()
        #endif
    }

    func clearDebugLogs() {
        app.logger.clear()
        app.logger.log(category: .app, level: .warning, message: "Debug logs cleared")
        debugLogEntries = app.logger.recentEntries()
    }
}
