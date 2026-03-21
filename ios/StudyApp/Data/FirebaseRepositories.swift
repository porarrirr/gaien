import Combine
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

    func signOut() async throws {
        try auth.signOut()
        session = nil
    }
}

@MainActor
final class FirebaseSyncRepository: ObservableObject, SyncRepository {
    private let authRepository: FirebaseAuthRepository
    private let firestore: Firestore
    private let persistence: PersistenceController
    private let preferencesRepository: UserDefaultsPreferencesRepository
    private let lastSyncKey = "studyapp.sync.lastSyncAt"
    private var lastLoadedVersion: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    private static let maxChunkBytes = 500_000
    private static let maxSyncRetries = 3

    @Published private(set) var status = SyncStatus()

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

        authRepository.$session
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                self.status.isAuthenticated = session != nil
                self.status.email = session?.email
                if session == nil {
                    self.status.isSyncing = false
                    self.status.errorMessage = nil
                }
            }
            .store(in: &cancellables)
    }

    func syncNow() async throws {
        guard let session = authRepository.session else {
            throw ValidationError(message: "同期するにはサインインが必要です")
        }
        status.isSyncing = true
        status.errorMessage = nil
        do {
            for _ in 0..<Self.maxSyncRetries {
                let remotePayload = try await loadSnapshot(userId: session.localId)
                let local = try await persistence.exportData()
                let localChangeToken = persistence.changeToken
                let merged: AppData
                if let remotePayload {
                    let remote = try JSONDecoder().decode(AppData.self, from: Data(remotePayload.utf8))
                    merged = merge(local: local, remote: remote)
                } else {
                    merged = local
                }
                let synced = markSynced(merged, at: Date().epochMilliseconds)
                let payload = String(data: try JSONEncoder().encode(synced), encoding: .utf8) ?? "{}"
                try await saveSnapshot(
                    userId: session.localId,
                    payload: payload,
                    updatedAt: synced.exportDate,
                    expectedVersion: lastLoadedVersion
                )
                guard persistence.changeToken == localChangeToken else {
                    continue
                }
                let useCase = ExportImportDataUseCase(repository: persistence)
                _ = try await useCase.importJSON(payload, currentPreferences: preferencesRepository.loadPreferences())
                UserDefaults.standard.set(synced.exportDate, forKey: lastSyncKey)
                status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: synced.exportDate)
                return
            }
            throw ValidationError(message: "同期中にローカルデータが更新されました。もう一度お試しください。")
        } catch {
            status.isSyncing = false
            status.errorMessage = error.localizedDescription
            throw error
        }
    }

    func importLocalDataToCloud() async throws {
        guard let session = authRepository.session else {
            throw ValidationError(message: "同期するにはサインインが必要です")
        }
        status.isSyncing = true
        status.errorMessage = nil
        do {
            for _ in 0..<Self.maxSyncRetries {
                _ = try await loadSnapshot(userId: session.localId)
                let local = markSynced(try await persistence.exportData(), at: Date().epochMilliseconds)
                let localChangeToken = persistence.changeToken
                let payload = String(data: try JSONEncoder().encode(local), encoding: .utf8) ?? "{}"
                try await saveSnapshot(
                    userId: session.localId,
                    payload: payload,
                    updatedAt: local.exportDate,
                    expectedVersion: lastLoadedVersion
                )
                guard persistence.changeToken == localChangeToken else {
                    continue
                }
                UserDefaults.standard.set(local.exportDate, forKey: lastSyncKey)
                status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: local.exportDate)
                return
            }
            throw ValidationError(message: "同期中にローカルデータが更新されました。もう一度お試しください。")
        } catch {
            status.isSyncing = false
            status.errorMessage = error.localizedDescription
            throw error
        }
    }

    // MARK: - Chunked snapshot I/O (backward-compatible with legacy payload format)

    private func loadSnapshot(userId: String) async throws -> String? {
        let manifestRef = firestore
            .collection("users").document(userId)
            .collection("sync").document("default")
        let snapshot = try await manifestRef.getDocument()
        guard let data = snapshot.data() else {
            lastLoadedVersion = 0
            return nil
        }

        // Legacy format: direct payload field
        if let payload = data["payload"] as? String {
            lastLoadedVersion = data["version"] as? Int64 ?? 0
            return payload
        }

        // Chunked-v2 format
        guard let format = data["format"] as? String, format == "chunked-v2",
              let version = data["version"] as? Int64,
              let chunkCount = data["chunkCount"] as? Int,
              chunkCount > 0 else {
            lastLoadedVersion = data["version"] as? Int64 ?? 0
            return nil
        }

        lastLoadedVersion = version
        let chunksCol = manifestRef.collection("chunks")

        var parts = [String]()
        for i in 0..<chunkCount {
            let chunkId = String(format: "%06d", i)
            let chunkSnap = try await chunksCol.document(chunkId).getDocument()
            guard let chunkData = chunkSnap.data(),
                  let chunkVersion = chunkData["version"] as? Int64,
                  chunkVersion == version,
                  let payloadPart = chunkData["payloadPart"] as? String else {
                throw ValidationError(message: "同期データの読み込みに失敗しました")
            }
            parts.append(payloadPart)
        }
        return parts.joined()
    }

    private func saveSnapshot(userId: String, payload: String, updatedAt: Int64, expectedVersion: Int64?) async throws {
        let db = firestore
        let manifestRef = db.collection("users").document(userId)
            .collection("sync").document("default")
        let chunks = Self.splitPayloadIntoChunks(payload)
        let newChunkCount = chunks.count

        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            let manifestSnap: DocumentSnapshot
            do {
                manifestSnap = try transaction.getDocument(manifestRef)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }

            let currentData = manifestSnap.data() ?? [:]
            let currentVersion: Int64 = currentData["version"] as? Int64 ?? 0
            let oldChunkCount = currentData["chunkCount"] as? Int ?? 0

            if let expected = expectedVersion, currentVersion != expected {
                errorPointer?.pointee = NSError(
                    domain: "StudyApp", code: 409,
                    userInfo: [NSLocalizedDescriptionKey: "同期の競合が発生しました。再試行してください。"])
                return nil
            }

            let newVersion = currentVersion + 1

            transaction.setData([
                "format": "chunked-v2",
                "version": newVersion,
                "updatedAt": updatedAt,
                "chunkCount": newChunkCount
            ], forDocument: manifestRef)

            let chunksCol = manifestRef.collection("chunks")
            for (i, part) in chunks.enumerated() {
                let chunkRef = chunksCol.document(String(format: "%06d", i))
                transaction.setData([
                    "version": newVersion,
                    "index": i,
                    "payloadPart": part
                ], forDocument: chunkRef)
            }

            // Remove stale chunks if count shrank
            for i in newChunkCount..<oldChunkCount {
                let chunkRef = chunksCol.document(String(format: "%06d", i))
                transaction.deleteDocument(chunkRef)
            }

            return NSNumber(value: newVersion)
        }
        if let version = result as? NSNumber {
            lastLoadedVersion = version.int64Value
        }
    }

    private static func splitPayloadIntoChunks(_ payload: String) -> [String] {
        let utf8 = Array(payload.utf8)
        guard !utf8.isEmpty else { return [""] }
        var chunks = [String]()
        var start = 0
        while start < utf8.count {
            var end = min(start + maxChunkBytes, utf8.count)
            // Avoid splitting in the middle of a multi-byte UTF-8 character
            while end < utf8.count && end > start && (utf8[end] & 0xC0) == 0x80 {
                end -= 1
            }
            if end <= start { end = min(start + maxChunkBytes, utf8.count) }
            if let chunk = String(bytes: utf8[start..<end], encoding: .utf8) {
                chunks.append(chunk)
            }
            start = end
        }
        return chunks
    }

    // MARK: - Merge helpers

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
