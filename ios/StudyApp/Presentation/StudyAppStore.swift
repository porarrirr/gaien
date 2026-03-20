import Combine
import Foundation

@MainActor
final class StudyAppContainer: ObservableObject {
    @Published private(set) var preferences: AppPreferences
    @Published private(set) var isLoaded = false
    @Published var errorMessage: String?
    @Published private(set) var dataVersion = 0

    let persistence: PersistenceController
    let preferencesRepository: UserDefaultsPreferencesRepository
    let googleBooksService: GoogleBooksService
    let reminderScheduler: ReminderScheduler
    let clock = Clock()

    init(
        persistence: PersistenceController = .shared,
        preferencesRepository: UserDefaultsPreferencesRepository = UserDefaultsPreferencesRepository(),
        googleBooksService: GoogleBooksService = GoogleBooksService(),
        reminderScheduler: ReminderScheduler = ReminderScheduler()
    ) {
        self.persistence = persistence
        self.preferencesRepository = preferencesRepository
        self.googleBooksService = googleBooksService
        self.reminderScheduler = reminderScheduler
        self.preferences = preferencesRepository.loadPreferences()

        Task {
            await load()
        }
    }

    func load() async {
        do {
            try await persistence.migrateLegacySnapshotIfNeeded(preferencesRepository: preferencesRepository)
            preferences = preferencesRepository.loadPreferences()
            isLoaded = true
            bumpDataVersion()
        } catch {
            isLoaded = true
            present(error)
        }
    }

    func savePreferences(_ update: (inout AppPreferences) -> Void) {
        var next = preferences
        update(&next)
        preferences = next
        preferencesRepository.savePreferences(next)
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

    func bumpDataVersion() {
        dataVersion += 1
    }

    func clearError() {
        errorMessage = nil
    }

    func present(_ error: Error) {
        errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    func present(_ message: String) {
        errorMessage = message
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
        perform {
            let useCase = ManageMaterialsUseCase(materialRepository: self.app.persistence, subjectRepository: self.app.persistence, bookSearchRepository: self.app.googleBooksService)
            self.bookSearchResult = try await useCase.searchBook(isbn: isbn)
        }
    }

    func clearSearchResult() {
        bookSearchResult = nil
    }

    func saveMaterial(id: Int64? = nil, name: String, subjectId: Int64, totalPages: Int, currentPage: Int = 0, note: String?) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "教材名を入力してください") }
            guard totalPages >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard currentPage >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard totalPages == 0 || currentPage <= totalPages else { throw ValidationError(message: "現在のページは総ページ数以下にしてください") }
            if let id {
                try await self.app.persistence.updateMaterial(
                    Material(id: id, name: trimmed, subjectId: subjectId, totalPages: totalPages, currentPage: currentPage, color: nil, note: note?.nilIfBlank)
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
            selectedSubjectId = selectedSubjectId ?? activeTimer?.subjectId ?? subjects.first?.id
            selectedMaterialId = selectedMaterialId ?? activeTimer?.materialId
            elapsedMilliseconds = activeTimer?.elapsedTime() ?? 0
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

    func materialsForSelectedSubject() -> [Material] {
        guard let selectedSubjectId else { return [] }
        return materials.filter { $0.subjectId == selectedSubjectId }
    }

    func startOrResume() {
        perform {
            guard let subjectId = self.selectedSubjectId ?? self.subjects.first?.id else {
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
            guard let subject = try await self.app.persistence.getSubjectById(timer.subjectId) else {
                throw ValidationError(message: "科目を選択してください")
            }
            let materials = try await self.app.persistence.getAllMaterials()
            let materialName = materials.first(where: { $0.id == timer.materialId })?.name ?? ""
            let end = Date().epochMilliseconds
            let start = end - elapsed
            _ = try await self.app.persistence.insertSession(
                StudySession(
                    materialId: timer.materialId,
                    materialName: materialName,
                    subjectId: subject.id,
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
}

@MainActor
final class HistoryViewModel: ScreenViewModel {
    @Published private(set) var sessions: [StudySession] = []

    func load() async {
        do {
            sessions = try await app.persistence.getAllSessions()
        } catch {
            app.present(error)
        }
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
            } else {
                planItems = []
            }
        } catch {
            app.present(error)
        }
    }

    func createPlan(name: String, startDate: Date, endDate: Date, items: [PlanItem]) {
        perform {
            let useCase = ManagePlansUseCase(repository: self.app.persistence)
            try await useCase.createPlan(name: name, startDate: startDate, endDate: endDate, items: items)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func savePlanItem(_ item: PlanItem) {
        perform {
            guard item.targetMinutes > 0 else { throw ValidationError(message: "目標時間は0より大きくしてください") }
            if item.id == 0, let activePlan = self.activePlan {
                _ = try await self.app.persistence.createPlan(
                    StudyPlan(id: activePlan.id, name: activePlan.name, startDate: activePlan.startDate, endDate: activePlan.endDate, isActive: activePlan.isActive, createdAt: activePlan.createdAt),
                    items: self.planItems + [item]
                )
            } else {
                try await self.app.persistence.updatePlanItem(item)
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
    @Published var displayedMonth = Date()

    func load() async {
        do {
            let sessions = try await app.persistence.getAllSessions()
            let monthInterval = Calendar.current.dateInterval(of: .month, for: displayedMonth)
            let start = monthInterval?.start ?? displayedMonth.startOfDay
            let end = monthInterval?.end ?? displayedMonth
            monthStudyMap = sessions.reduce(into: [:]) { result, session in
                let sessionDate = session.startDate
                guard sessionDate >= start && sessionDate < end else { return }
                let day = Calendar.current.component(.day, from: sessionDate)
                result[day, default: 0] += session.durationMinutes
            }
        } catch {
            app.present(error)
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

    func export(format: ExportFormat) {
        perform {
            let useCase = ExportImportDataUseCase(repository: self.app.persistence)
            let contents = try await (format == .json ? useCase.exportJSON() : useCase.exportCSV())
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("studyapp_backup_\(Int(Date().timeIntervalSince1970)).\(format.rawValue)")
            try contents.write(to: url, atomically: true, encoding: .utf8)
            self.exportURL = url
        }
    }

    func importBackup(from url: URL) {
        perform {
            let contents = try String(contentsOf: url, encoding: .utf8)
            let useCase = ExportImportDataUseCase(repository: self.app.persistence)
            let preferences = try await useCase.importJSON(contents, currentPreferences: self.app.preferences)
            self.app.savePreferences { $0 = preferences }
            self.app.bumpDataVersion()
        }
    }

    func deleteAllData() {
        perform {
            try await self.app.persistence.deleteAllData()
            self.app.updateActiveTimer(nil)
            self.app.bumpDataVersion()
        }
    }
}
