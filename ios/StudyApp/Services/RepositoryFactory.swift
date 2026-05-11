import Foundation

/// Wires up the concrete repositories the app uses at runtime. Isolated from
/// `StudyAppContainer` so that the container's responsibility narrows to
/// runtime DI + shared state, and so tests can plug in fakes without touching
/// Firebase.
@MainActor
enum RepositoryFactory {
    struct Repositories {
        let authRepository: any AuthRepository
        let syncRepository: any SyncRepository
    }

    static func make(
        persistence: PersistenceController,
        preferencesRepository: UserDefaultsPreferencesRepository,
        logger: AppLogger
    ) -> Repositories {
        if FirebaseBootstrap.status.isConfigured {
            let firebaseAuth = FirebaseAuthRepository(logger: logger)
            let firebaseSync = FirebaseSyncRepository(
                authRepository: firebaseAuth,
                persistence: persistence,
                preferencesRepository: preferencesRepository,
                logger: logger
            )
            return Repositories(authRepository: firebaseAuth, syncRepository: firebaseSync)
        }
        return Repositories(
            authRepository: DisabledAuthRepository(),
            syncRepository: DisabledSyncRepository(logger: logger)
        )
    }
}
