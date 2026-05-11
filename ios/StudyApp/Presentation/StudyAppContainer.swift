import Combine
import Foundation

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
    let authRepository: any AuthRepository
    let syncRepository: any SyncRepository

    // MARK: - Repository facades
    //
    // Expose the repository protocols implemented by `persistence` as protocol-typed
    // properties so ViewModels can depend on protocols instead of the concrete
    // `PersistenceController`. This unlocks testability and keeps call sites tidy.
    var subjectRepo: SubjectRepository { persistence }
    var materialRepo: MaterialRepository { persistence }
    var sessionRepo: StudySessionRepository { persistence }
    var goalRepo: GoalRepository { persistence }
    var examRepo: ExamRepository { persistence }
    var planRepo: PlanRepository { persistence }
    var timetableRepo: TimetableRepository { persistence }
    var problemReviewRepo: ProblemReviewRepository { persistence }
    var appDataRepo: AppDataRepository { persistence }
    var bookSearchRepo: BookSearchRepository { googleBooksService }

    private lazy var widgetSnapshotSync = WidgetSnapshotSync(container: self)
    private lazy var liveActivityController = StudyLiveActivityController(persistence: persistence, logger: logger)
    private lazy var autoSyncCoordinator = AutoSyncCoordinator(
        syncRepository: syncRepository,
        logger: logger,
        currentDataVersion: { [weak self] in self?.dataVersion ?? 0 },
        onSyncStatusChanged: { [weak self] in self?.refreshSyncStatus() }
    )
    private lazy var reminderCoordinator = ReminderCoordinator(
        scheduler: reminderScheduler,
        persistence: persistence,
        logger: logger
    )
    private var cancellables = Set<AnyCancellable>()
    private var liveActivitySyncTask: Task<Void, Never>?

    convenience init() {
        let persistence = PersistenceController.shared
        let preferencesRepository = UserDefaultsPreferencesRepository()
        let googleBooksService = GoogleBooksService()
        let reminderScheduler = ReminderScheduler()
        let logger = AppLogger()
        let repositories = RepositoryFactory.make(
            persistence: persistence,
            preferencesRepository: preferencesRepository,
            logger: logger
        )

        self.init(
            persistence: persistence,
            preferencesRepository: preferencesRepository,
            googleBooksService: googleBooksService,
            reminderScheduler: reminderScheduler,
            logger: logger,
            authRepository: repositories.authRepository,
            syncRepository: repositories.syncRepository
        )
    }

    init(
        persistence: PersistenceController,
        preferencesRepository: UserDefaultsPreferencesRepository,
        googleBooksService: GoogleBooksService,
        reminderScheduler: ReminderScheduler,
        logger: AppLogger,
        authRepository: any AuthRepository,
        syncRepository: (any SyncRepository)?
    ) {
        self.persistence = persistence
        self.preferencesRepository = preferencesRepository
        self.googleBooksService = googleBooksService
        self.reminderScheduler = reminderScheduler
        self.logger = logger
        self.authRepository = authRepository
        self.syncRepository = syncRepository ?? DisabledSyncRepository(logger: logger)
        self.preferences = preferencesRepository.loadPreferences()
        self.syncStatus = self.syncRepository.status

        self.syncRepository.statusPublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] newStatus in
                self?.syncStatus = newStatus
            }
            .store(in: &cancellables)

        Task {
            logger.log(category: .app, message: "StudyAppContainer initialized")
            logger.log(category: .app, message: "Firebase configuration state", details: FirebaseBootstrap.status.logDescription)
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

    func setLandscapeTimerDisplayPreset(_ preset: LandscapeTimerDisplayPreset) {
        savePreferences { $0.landscapeTimerDisplayPreset = preset }
    }

    func setReminderEnabled(_ enabled: Bool) async {
        let result = await reminderCoordinator.setEnabled(enabled, preferences: preferences)
        switch result {
        case .success(let applied):
            savePreferences { $0.reminderEnabled = applied }
        case .failure(.permissionDenied):
            present("通知の許可が必要です")
        case .failure(.scheduling(let error)):
            present(error)
        }
    }

    func setReminderTime(hour: Int, minute: Int) async {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            present("時刻の形式が正しくありません")
            return
        }
        if case .failure(let error) = await reminderCoordinator.applyReminderTime(hour: hour, minute: minute, preferences: preferences) {
            present(error)
            return
        }
        savePreferences {
            $0.reminderHour = hour
            $0.reminderMinute = minute
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
        if preferences.reminderEnabled {
            Task { await refreshTimetableReviewReminder() }
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

    func refreshTimetableReviewReminder() async {
        do {
            try await reminderCoordinator.refreshTimetableReviewReminder()
        } catch {
            present(error)
        }
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
