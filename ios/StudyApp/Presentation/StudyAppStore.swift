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
    private lazy var autoSyncCoordinator = AutoSyncCoordinator(
        syncRepository: syncRepository,
        logger: logger,
        currentDataVersion: { [weak self] in self?.dataVersion ?? 0 },
        onSyncStatusChanged: { [weak self] in self?.refreshSyncStatus() }
    )
    private var cancellables = Set<AnyCancellable>()
    private var liveActivitySyncTask: Task<Void, Never>?

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
        autoSyncCoordinator.schedule(reason: reason)
    }

    func recordManualSyncApplied() {
        autoSyncCoordinator.recordManualSyncApplied()
    }

    func blockAutoSyncUntilLocalChange() {
        autoSyncCoordinator.blockUntilLocalChange()
    }

    func present(_ error: Error) {
        logger.log(category: .ui, level: .error, message: "Presented error to user", error: error)
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    func present(_ message: String) {
        logger.log(category: .ui, level: .warning, message: "Presented message to user", details: message)
        errorMessage = message
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
    @Published private(set) var homeData = HomeData(todayStudyMinutes: 0, todaySessions: [], todayGoal: nil, weeklyGoal: nil, weeklyStudyMinutes: 0, upcomingExams: [])
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

    func saveMaterial(
        id: Int64? = nil,
        name: String,
        subjectId: Int64,
        totalPages: Int,
        currentPage: Int = 0,
        totalProblems: Int = 0,
        note: String?
    ) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "教材名を入力してください") }
            guard totalPages >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard currentPage >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard totalProblems >= 0 else { throw ValidationError(message: "全問題数は0以上で入力してください") }
            guard totalPages == 0 || currentPage <= totalPages else { throw ValidationError(message: "現在のページは総ページ数以下にしてください") }
            if let id {
                let existing = try await self.app.persistence.getAllMaterials().first(where: { $0.id == id })
                guard let subject = try await self.app.persistence.getSubjectById(subjectId) else {
                    throw ValidationError(message: "科目を選択してください")
                }
                try await self.app.persistence.updateMaterial(
                    Material(
                        id: id,
                        name: trimmed,
                        subjectId: subjectId,
                        subjectSyncId: subject.syncId,
                        sortOrder: existing?.sortOrder ?? Date().epochMilliseconds,
                        totalPages: totalPages,
                        currentPage: currentPage,
                        totalProblems: totalProblems,
                        color: nil,
                        note: note?.nilIfBlank
                    )
                )
            } else {
                let useCase = ManageMaterialsUseCase(materialRepository: self.app.persistence, subjectRepository: self.app.persistence, bookSearchRepository: self.app.googleBooksService)
                let nextOrder = (try await self.app.persistence.getAllMaterials().map(\.sortOrder).max() ?? -1) + 1
                guard let subject = try await self.app.persistence.getSubjectById(subjectId) else {
                    throw ValidationError(message: "科目を選択してください")
                }
                try await self.app.persistence.insertMaterial(
                    Material(
                        name: trimmed,
                        subjectId: subjectId,
                        subjectSyncId: subject.syncId,
                        sortOrder: nextOrder,
                        totalPages: totalPages,
                        currentPage: 0,
                        totalProblems: totalProblems,
                        color: nil,
                        note: note?.nilIfBlank
                    )
                )
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

    func moveMaterial(_ materialId: Int64, direction: Int) {
        perform {
            var materials = try await self.app.persistence.getAllMaterials()
            guard let currentIndex = materials.firstIndex(where: { $0.id == materialId }) else { return }
            let targetIndex = currentIndex + direction
            guard materials.indices.contains(targetIndex) else { return }
            let item = materials.remove(at: currentIndex)
            materials.insert(item, at: targetIndex)
            for (index, material) in materials.enumerated() {
                var updated = material
                updated.sortOrder = Int64(index)
                try await self.app.persistence.updateMaterial(updated)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

@MainActor
final class MaterialHistoryViewModel: ScreenViewModel {
    @Published private(set) var material: Material?
    @Published private(set) var subject: Subject?
    @Published private(set) var sessions: [StudySession] = []
    @Published var displayedMonth = Calendar.current.startOfDay(for: Date())
    @Published var selectedDate = Calendar.current.startOfDay(for: Date())

    let materialId: Int64

    init(app: StudyAppContainer, materialId: Int64) {
        self.materialId = materialId
        super.init(app: app)
    }

    var latestStudyDate: Date? {
        sessions.max(by: { $0.sessionStartTime < $1.sessionStartTime })?.startDate.startOfDay
    }

    var totalMinutes: Int {
        sessions.reduce(0) { $0 + $1.durationMinutes }
    }

    var studyMinutesByDay: [Int: Int] {
        let calendar = Calendar.current
        guard let interval = calendar.dateInterval(of: .month, for: displayedMonth) else { return [:] }
        return sessions
            .filter { session in
                session.startDate >= interval.start && session.startDate < interval.end
            }
            .reduce(into: [:]) { result, session in
                let day = calendar.component(.day, from: session.startDate)
                result[day, default: 0] += session.durationMinutes
            }
    }

    var selectedDateSessions: [StudySession] {
        sessions
            .filter { Calendar.current.isDate($0.startDate, inSameDayAs: selectedDate) }
            .sorted { $0.sessionStartTime < $1.sessionStartTime }
    }

    var selectedDateMinutes: Int {
        selectedDateSessions.reduce(0) { $0 + $1.durationMinutes }
    }

    func load() async {
        do {
            async let materialsTask = app.persistence.getAllMaterials()
            async let subjectsTask = app.persistence.getAllSubjects()
            async let sessionsTask = app.persistence.getAllSessions()

            let materials = try await materialsTask
            let subjects = try await subjectsTask
            let allSessions = try await sessionsTask

            material = materials.first { $0.id == materialId }
            subject = material.flatMap { selectedMaterial in
                subjects.first { $0.id == selectedMaterial.subjectId }
            }
            sessions = allSessions
                .filter { $0.materialId == materialId }
                .sorted { $0.sessionStartTime > $1.sessionStartTime }

            let initialDate = latestStudyDate ?? Date().startOfDay
            selectedDate = initialDate
            displayedMonth = initialDate
        } catch {
            app.present(error)
        }
    }

    func previousMonth() {
        moveMonth(by: -1)
    }

    func nextMonth() {
        moveMonth(by: 1)
    }

    func selectDate(_ date: Date) {
        selectedDate = Calendar.current.startOfDay(for: date)
        displayedMonth = selectedDate
    }

    private func moveMonth(by value: Int) {
        let calendar = Calendar.current
        guard let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth),
              let monthInterval = calendar.dateInterval(of: .month, for: newMonth),
              let dayRange = calendar.range(of: .day, in: .month, for: newMonth) else {
            return
        }
        let currentDay = calendar.component(.day, from: selectedDate)
        let clampedDay = min(currentDay, dayRange.count)
        selectedDate = calendar.date(byAdding: .day, value: clampedDay - 1, to: monthInterval.start) ?? monthInterval.start
        displayedMonth = selectedDate
    }
}

@MainActor
final class TimerViewModel: ScreenViewModel {
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var materials: [Material] = []
    @Published private(set) var elapsedMilliseconds: Int64 = 0
    @Published private(set) var remainingMilliseconds: Int64 = 0
    @Published var pendingSessionEvaluation: PendingSessionEvaluation?
    @Published var selectedSubjectId: Int64?
    @Published var selectedMaterialId: Int64?
    @Published var mode: TimerSnapshot.Mode = .stopwatch
    @Published var countdownMinutes: Int = 25

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
            remainingMilliseconds = activeTimer?.remainingTime() ?? 0
            mode = activeTimer?.mode ?? .stopwatch
            countdownMinutes = Int(((activeTimer?.targetDurationMilliseconds ?? Int64(countdownMinutes) * 60_000) / 60_000))
            syncActiveTimerSelection()
            configureTicker()
        } catch {
            app.present(error)
        }
    }

    var isRunning: Bool {
        app.preferences.activeTimer?.isRunning ?? false
    }

    var displayMilliseconds: Int64 {
        mode == .timer ? remainingMilliseconds : elapsedMilliseconds
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
            let now = Date().epochMilliseconds
            let completedIntervals = if let current, current.accumulatedMilliseconds > 0, current.completedIntervals.isEmpty {
                [StudySessionInterval(startTime: now - current.accumulatedMilliseconds, endTime: now)]
            } else {
                current?.completedIntervals ?? []
            }
            let next = TimerSnapshot(
                subjectId: subjectId,
                materialId: self.selectedMaterialId,
                startedAt: now,
                accumulatedMilliseconds: completedIntervals.reduce(0) { $0 + $1.duration },
                completedIntervals: completedIntervals,
                mode: self.mode,
                targetDurationMilliseconds: self.mode == .timer ? Int64(self.countdownMinutes * 60_000) : nil,
                isRunning: true
            )
            self.app.updateActiveTimer(next)
            self.elapsedMilliseconds = next.elapsedTime()
            self.remainingMilliseconds = next.remainingTime()
            self.configureTicker()
        }
    }

    func pause() {
        guard var timer = app.preferences.activeTimer else { return }
        let now = Date().epochMilliseconds
        if timer.isRunning, let startedAt = timer.startedAt {
            timer.completedIntervals.append(
                StudySessionInterval(
                    startTime: startedAt,
                    endTime: now
                )
            )
        }
        timer.accumulatedMilliseconds = timer.completedIntervals.reduce(0) { $0 + $1.duration }
        timer.startedAt = nil
        timer.isRunning = false
        app.updateActiveTimer(timer)
        elapsedMilliseconds = timer.accumulatedMilliseconds
        remainingMilliseconds = timer.remainingTime()
        configureTicker()
    }

    func setMode(_ newMode: TimerSnapshot.Mode) {
        guard !isRunning else {
            app.present("実行中はタイマー種別を変更できません")
            return
        }
        mode = newMode
        if var timer = app.preferences.activeTimer {
            timer.mode = newMode
            timer.targetDurationMilliseconds = newMode == .timer ? Int64(countdownMinutes * 60_000) : nil
            app.updateActiveTimer(timer)
        }
        remainingMilliseconds = newMode == .timer ? Int64(countdownMinutes * 60_000) : 0
    }

    func setCountdownMinutes(_ minutes: Int) {
        guard !isRunning else {
            app.present("実行中は時間を変更できません")
            return
        }
        countdownMinutes = minutes
        remainingMilliseconds = mode == .timer ? Int64(minutes * 60_000) : 0
        if var timer = app.preferences.activeTimer {
            timer.targetDurationMilliseconds = mode == .timer ? Int64(minutes * 60_000) : nil
            app.updateActiveTimer(timer)
        }
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

    func stop() {
        perform {
            guard self.pendingSessionEvaluation == nil else { return }
            guard let timer = self.finalizeTimerForEvaluation() else { return }
            let elapsed = timer.accumulatedMilliseconds
            guard elapsed > 0 else {
                self.app.updateActiveTimer(nil)
                self.elapsedMilliseconds = 0
                self.remainingMilliseconds = 0
                self.configureTicker()
                return
            }
            guard let subject = try await self.app.persistence.getSubjectById(timer.subjectId) else {
                throw ValidationError(message: "科目を選択してください")
            }
            let materials = try await self.app.persistence.getAllMaterials()
            let materialId = timer.materialId
            let material = materials.first(where: { $0.id == materialId })
            let materialName = material?.name ?? ""
            let intervals = timer.finalizedIntervals()
            let start = intervals.first?.startTime ?? (Date().epochMilliseconds - elapsed)
            let end = intervals.last?.endTime ?? Date().epochMilliseconds
            self.pendingSessionEvaluation = PendingSessionEvaluation(
                session: StudySession(
                    materialId: materialId,
                    materialSyncId: material?.syncId,
                    materialName: materialName,
                    subjectId: subject.id,
                    subjectSyncId: subject.syncId,
                    subjectName: subject.name,
                    sessionType: timer.sessionType,
                    startTime: start,
                    endTime: end,
                    intervals: intervals
                )
            )
        }
    }

    func savePendingSessionEvaluation(rating: Int, note: String?, problemStart: Int?, problemEnd: Int?, wrongProblemCount: Int?) {
        perform {
            guard StudySession.allowedRatings.contains(rating) else {
                throw ValidationError(message: "評価は1〜5で入力してください")
            }
            try self.validateProblemRecord(problemStart: problemStart, problemEnd: problemEnd, wrongProblemCount: wrongProblemCount)
            guard var draft = self.pendingSessionEvaluation else { return }
            draft.session.rating = rating
            draft.session.note = note?.nilIfBlank
            draft.session.problemStart = problemStart
            draft.session.problemEnd = problemEnd
            draft.session.wrongProblemCount = wrongProblemCount
            _ = try await self.app.persistence.insertSession(draft.session)
            self.pendingSessionEvaluation = nil
            self.app.updateActiveTimer(nil)
            self.elapsedMilliseconds = 0
            self.remainingMilliseconds = 0
            self.configureTicker()
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func cancelPendingSessionEvaluation() {
        pendingSessionEvaluation = nil
    }

    func saveManualSession(subjectId: Int64, materialId: Int64?, startTime: Int64, endTime: Int64, note: String?) {
        perform {
            let useCase = SaveStudySessionUseCase(sessionRepository: self.app.persistence, subjectRepository: self.app.persistence, materialRepository: self.app.persistence)
            try await useCase.saveManualSession(subjectId: subjectId, materialId: materialId, startTime: startTime, endTime: endTime, note: note)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    private func validateProblemRecord(problemStart: Int?, problemEnd: Int?, wrongProblemCount: Int?) throws {
        if problemStart == nil && problemEnd == nil && wrongProblemCount == nil {
            return
        }
        guard let problemStart, let problemEnd else {
            throw ValidationError(message: "問題範囲は開始と終了を両方入力してください")
        }
        guard problemStart > 0, problemEnd >= problemStart else {
            throw ValidationError(message: "問題範囲を正しく入力してください")
        }
        if let wrongProblemCount {
            guard wrongProblemCount >= 0 else {
                throw ValidationError(message: "間違えた数は0以上で入力してください")
            }
            guard wrongProblemCount <= (problemEnd - problemStart + 1) else {
                throw ValidationError(message: "間違えた数は実施問題数以下にしてください")
            }
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
                self.remainingMilliseconds = self.app.preferences.activeTimer?.remainingTime() ?? 0
                if self.mode == .timer, self.remainingMilliseconds <= 0 {
                    self.stop()
                }
            }
    }

    private func finalizeTimerForEvaluation() -> TimerSnapshot? {
        guard var timer = app.preferences.activeTimer else { return nil }
        let now = Date().epochMilliseconds
        if timer.isRunning, let startedAt = timer.startedAt {
            timer.completedIntervals.append(
                StudySessionInterval(
                    startTime: startedAt,
                    endTime: now
                )
            )
        }
        timer.accumulatedMilliseconds = timer.completedIntervals.reduce(0) { $0 + $1.duration }
        timer.startedAt = nil
        timer.isRunning = false
        app.updateActiveTimer(timer)
        elapsedMilliseconds = timer.accumulatedMilliseconds
        remainingMilliseconds = timer.remainingTime()
        configureTicker()
        return timer
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
        timer.mode = mode
        timer.targetDurationMilliseconds = mode == .timer ? Int64(countdownMinutes * 60_000) : nil
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

    func updateSession(
        _ session: StudySession,
        durationMinutes: Int,
        note: String?,
        rating: Int?,
        problemStart: Int? = nil,
        problemEnd: Int? = nil,
        wrongProblemCount: Int? = nil
    ) {
        perform {
            guard durationMinutes > 0 else { throw ValidationError(message: "学習時間は0より大きくしてください") }
            var updated = session
            updated.endTime = updated.startTime + Int64(durationMinutes * 60_000)
            updated.intervals = [StudySessionInterval(startTime: updated.startTime, endTime: updated.endTime)]
            updated.note = note?.nilIfBlank
            updated.rating = rating
            updated.problemStart = problemStart
            updated.problemEnd = problemEnd
            updated.wrongProblemCount = wrongProblemCount
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
    @Published private(set) var dailyGoals: [StudyWeekday: Goal] = [:]
    @Published private(set) var weeklyGoal: Goal?
    @Published private(set) var todayWeekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: Date()))
    @Published private(set) var todayStudyMinutes = 0
    @Published private(set) var weeklyStudyMinutes = 0

    func load() async {
        do {
            let todayStart = app.clock.startOfToday()
            let weekStart = app.clock.startOfWeek()
            let dayMs: Int64 = 86_400_000
            let weekMs = dayMs * 7

            async let goalsTask = app.persistence.getAllGoals()
            async let todaySessionsTask = app.persistence.getSessionsBetweenDates(start: todayStart, end: todayStart + dayMs)
            async let weeklySessionsTask = app.persistence.getSessionsBetweenDates(start: weekStart, end: weekStart + weekMs)

            let goals = try await goalsTask
            let todaySessions = try await todaySessionsTask
            let weeklySessions = try await weeklySessionsTask

            dailyGoals = goals.latestActiveDailyGoalsByWeekday()
            weeklyGoal = goals.latestActiveWeeklyGoal()
            todayWeekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: Date()))
            todayStudyMinutes = todaySessions.reduce(0) { $0 + $1.durationMinutes }
            weeklyStudyMinutes = weeklySessions.reduce(0) { $0 + $1.durationMinutes }
        } catch {
            app.present(error)
        }
    }

    func updateDailyGoal(dayOfWeek: StudyWeekday, targetMinutes: Int) {
        perform {
            guard targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            let useCase = ManageGoalsUseCase(repository: self.app.persistence)
            try await useCase.updateGoal(type: .daily, targetMinutes: targetMinutes, dayOfWeek: dayOfWeek)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func updateWeeklyGoal(targetMinutes: Int) {
        perform {
            guard targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            let useCase = ManageGoalsUseCase(repository: self.app.persistence)
            try await useCase.updateGoal(type: .weekly, targetMinutes: targetMinutes)
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

    func updateSession(
        _ session: StudySession,
        durationMinutes: Int,
        note: String?,
        rating: Int?,
        problemStart: Int? = nil,
        problemEnd: Int? = nil,
        wrongProblemCount: Int? = nil
    ) {
        perform {
            guard durationMinutes > 0 else { throw ValidationError(message: "学習時間は0より大きくしてください") }
            var updated = session
            updated.endTime = updated.startTime + Int64(durationMinutes * 60_000)
            updated.intervals = [StudySessionInterval(startTime: updated.startTime, endTime: updated.endTime)]
            updated.note = note?.nilIfBlank
            updated.rating = rating
            updated.problemStart = problemStart
            updated.problemEnd = problemEnd
            updated.wrongProblemCount = wrongProblemCount
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
final class ReportsViewModel: ScreenViewModel {
    @Published private(set) var reports = ReportsData(
        daily: [],
        weekly: [],
        monthly: [],
        bySubject: [],
        ratingAverages: RatingAveragesData(
            today: RatingAverageSummary(average: nil, ratedMinutes: 0),
            week: RatingAverageSummary(average: nil, ratedMinutes: 0),
            month: RatingAverageSummary(average: nil, ratedMinutes: 0)
        ),
        streakDays: 0,
        bestStreak: 0
    )

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
