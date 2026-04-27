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
