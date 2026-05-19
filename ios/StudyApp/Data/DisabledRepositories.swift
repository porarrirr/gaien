import Combine
import Foundation

@MainActor
final class DisabledAuthRepository: AuthRepository {
    var session: AuthSession? { nil }

    func signIn(email: String, password: String) async throws {
        throw ValidationError(message: FirebaseBootstrap.status.unavailableMessage ?? "Firebase設定が無効なため、クラウド同期は利用できません")
    }

    func signUp(email: String, password: String) async throws {
        throw ValidationError(message: FirebaseBootstrap.status.unavailableMessage ?? "Firebase設定が無効なため、クラウド同期は利用できません")
    }

    func signOut() async throws {}
}

@MainActor
final class DisabledSyncRepository: SyncRepository {
    private let logger: AppLogger
    private let disabledStatus = SyncStatus()

    var status: SyncStatus { disabledStatus }
    var statusPublisher: AnyPublisher<SyncStatus, Never> {
        Just(disabledStatus).eraseToAnyPublisher()
    }

    init(logger: AppLogger) {
        self.logger = logger
    }

    func syncNow() async throws {
        logger.log(category: .sync, level: .warning, message: "Sync unavailable", details: FirebaseBootstrap.status.logDescription)
        throw ValidationError(message: FirebaseBootstrap.status.unavailableMessage ?? "Firebase設定が無効なため、クラウド同期は利用できません")
    }

    func importLocalDataToCloud() async throws {
        logger.log(category: .sync, level: .warning, message: "Cloud upload unavailable", details: FirebaseBootstrap.status.logDescription)
        throw ValidationError(message: FirebaseBootstrap.status.unavailableMessage ?? "Firebase設定が無効なため、クラウド同期は利用できません")
    }

    func clearLocalSyncState() async {}
}
