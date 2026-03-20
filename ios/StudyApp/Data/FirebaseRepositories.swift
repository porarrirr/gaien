import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseAuthRepository: ObservableObject, AuthRepository {
    @Published private(set) var session: AuthSession?
    private let auth: Auth
    private var stateDidChangeHandle: AuthStateDidChangeListenerHandle?

    init(auth: Auth = Auth.auth()) {
        self.auth = auth
        self.session = auth.currentUser.map { AuthSession(localId: $0.uid, email: $0.email ?? "", idToken: "", refreshToken: "") }
        self.stateDidChangeHandle = auth.addStateDidChangeListener { [weak self] _, user in
            self?.session = user.map { AuthSession(localId: $0.uid, email: $0.email ?? "", idToken: "", refreshToken: "") }
        }
    }

    func signIn(email: String, password: String) async throws {
        let result = try await auth.signIn(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
    }

    func signUp(email: String, password: String) async throws {
        let result = try await auth.createUser(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
    }

    func signOut() async {
        try? auth.signOut()
        session = nil
    }
}

@MainActor
final class FirebaseSyncRepository: SyncRepository {
    private let authRepository: FirebaseAuthRepository
    private let firestore: Firestore
    private let persistence: PersistenceController
    private let preferencesRepository: UserDefaultsPreferencesRepository
    private let lastSyncKey = "studyapp.sync.lastSyncAt"

    private(set) var status = SyncStatus()

    init(
        authRepository: FirebaseAuthRepository,
        firestore: Firestore = Firestore.firestore(),
        persistence: PersistenceController,
        preferencesRepository: UserDefaultsPreferencesRepository
    ) {
        self.authRepository = authRepository
        self.firestore = firestore
        self.persistence = persistence
        self.preferencesRepository = preferencesRepository
        self.status = SyncStatus(
            isAuthenticated: authRepository.session != nil,
            email: authRepository.session?.email,
            lastSyncAt: UserDefaults.standard.object(forKey: lastSyncKey) as? Int64
        )
    }

    func syncNow() async throws {
        guard let session = authRepository.session else {
            throw ValidationError(message: "同期するにはサインインが必要です")
        }
        status.isSyncing = true
        defer { status.isSyncing = false }
        let useCase = ExportImportDataUseCase(repository: persistence)
        let local = try await persistence.exportData()
        let merged: AppData
        if let remotePayload = try await loadSnapshot(userId: session.localId) {
            let remote = try JSONDecoder().decode(AppData.self, from: Data(remotePayload.utf8))
            merged = merge(local: local, remote: remote)
        } else {
            merged = local
        }
        let synced = markSynced(merged, at: Date().epochMilliseconds)
        let payload = String(data: try JSONEncoder().encode(synced), encoding: .utf8) ?? "{}"
        _ = try await useCase.importJSON(payload, currentPreferences: preferencesRepository.loadPreferences())
        try await saveSnapshot(userId: session.localId, payload: payload, updatedAt: synced.exportDate)
        UserDefaults.standard.set(synced.exportDate, forKey: lastSyncKey)
        status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: synced.exportDate)
    }

    func importLocalDataToCloud() async throws {
        guard let session = authRepository.session else {
            throw ValidationError(message: "同期するにはサインインが必要です")
        }
        status.isSyncing = true
        defer { status.isSyncing = false }
        let local = markSynced(try await persistence.exportData(), at: Date().epochMilliseconds)
        let payload = String(data: try JSONEncoder().encode(local), encoding: .utf8) ?? "{}"
        try await saveSnapshot(userId: session.localId, payload: payload, updatedAt: local.exportDate)
        UserDefaults.standard.set(local.exportDate, forKey: lastSyncKey)
        status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: local.exportDate)
    }

    private func loadSnapshot(userId: String) async throws -> String? {
        let snapshot = try await firestore
            .collection("users")
            .document(userId)
            .collection("sync")
            .document("default")
            .getDocument()
        return snapshot.data()?["payload"] as? String
    }

    private func saveSnapshot(userId: String, payload: String, updatedAt: Int64) async throws {
        try await firestore
            .collection("users")
            .document(userId)
            .collection("sync")
            .document("default")
            .setData([
                "payload": payload,
                "updatedAt": updatedAt
            ])
    }

    private func merge(local: AppData, remote: AppData) -> AppData {
        AppData(
            subjects: merge(local.subjects, remote.subjects, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            materials: merge(local.materials, remote.materials, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            sessions: merge(local.sessions, remote.sessions, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            goals: merge(local.goals, remote.goals, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            exams: merge(local.exams, remote.exams, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            plans: mergePlans(local.plans, remote.plans),
            exportDate: max(local.exportDate, remote.exportDate)
        )
    }

    private func mergePlans(_ local: [PlanData], _ remote: [PlanData]) -> [PlanData] {
        let plans = merge(local.map(\.plan), remote.map(\.plan), key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt)
        let items = merge(local.flatMap(\.items), remote.flatMap(\.items), key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt)
        let grouped = Dictionary(grouping: items, by: \.planSyncId)
        return plans.map { plan in
            PlanData(plan: plan, items: grouped[plan.syncId] ?? [])
        }
    }

    private func merge<T>(_ lhs: [T], _ rhs: [T], key: KeyPath<T, String>, updatedAt: KeyPath<T, Int64>, deletedAt: KeyPath<T, Int64?>) -> [T] {
        var result: [String: T] = [:]
        for item in lhs + rhs {
            let id = item[keyPath: key]
            guard let existing = result[id] else {
                result[id] = item
                continue
            }
            let existingDelete = existing[keyPath: deletedAt] ?? .min
            let candidateDelete = item[keyPath: deletedAt] ?? .min
            if candidateDelete > existing[keyPath: updatedAt] && candidateDelete >= existingDelete {
                result[id] = item
            } else if existingDelete > item[keyPath: updatedAt] && existingDelete >= candidateDelete {
                result[id] = existing
            } else if item[keyPath: updatedAt] >= existing[keyPath: updatedAt] {
                result[id] = item
            }
        }
        return Array(result.values)
    }

    private func markSynced(_ appData: AppData, at timestamp: Int64) -> AppData {
        AppData(
            subjects: appData.subjects.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            materials: appData.materials.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            sessions: appData.sessions.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            goals: appData.goals.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            exams: appData.exams.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            plans: appData.plans.map {
                var plan = $0.plan
                plan.lastSyncedAt = timestamp
                let items = $0.items.map { item -> PlanItem in
                    var value = item
                    value.lastSyncedAt = timestamp
                    return value
                }
                return PlanData(plan: plan, items: items)
            },
            exportDate: timestamp
        )
    }
}
