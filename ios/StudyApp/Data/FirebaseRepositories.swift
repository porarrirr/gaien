import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

@MainActor
final class FirebaseAuthRepository: ObservableObject, AuthRepository {
    @Published private(set) var session: AuthSession?
    private let auth: Auth
    private let logger: AppLogger?
    private var stateDidChangeHandle: AuthStateDidChangeListenerHandle?

    init(logger: AppLogger? = nil) {
        self.auth = Auth.auth()
        self.logger = logger
        self.session = self.auth.currentUser.map(Self.makeSession(from:))
        self.stateDidChangeHandle = self.auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.applyAuthStateChange(user)
            }
        }
    }

    init(auth: Auth, logger: AppLogger? = nil) {
        self.auth = auth
        self.logger = logger
        self.session = auth.currentUser.map(Self.makeSession(from:))
        self.stateDidChangeHandle = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.applyAuthStateChange(user)
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        logger?.log(category: .auth, message: "Firebase sign-in started", details: "email=\(email)")
        let result = try await auth.signIn(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
        logger?.log(category: .auth, message: "Firebase sign-in succeeded", details: "uid=\(result.user.uid) email=\(result.user.email ?? email)")
    }

    func signUp(email: String, password: String) async throws {
        logger?.log(category: .auth, message: "Firebase sign-up started", details: "email=\(email)")
        let result = try await auth.createUser(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
        logger?.log(category: .auth, message: "Firebase sign-up succeeded", details: "uid=\(result.user.uid) email=\(result.user.email ?? email)")
    }

    func signOut() async throws {
        logger?.log(category: .auth, message: "Firebase sign-out started", details: "uid=\(auth.currentUser?.uid ?? "-")")
        try auth.signOut()
        session = nil
        logger?.log(category: .auth, message: "Firebase sign-out succeeded")
    }

    private static func makeSession(from user: User) -> AuthSession {
        AuthSession(localId: user.uid, email: user.email ?? "", idToken: "", refreshToken: "")
    }

    private func applyAuthStateChange(_ user: User?) {
        let nextSession = user.map(Self.makeSession(from:))
        guard session != nextSession else { return }
        session = nextSession
        logger?.log(
            category: .auth,
            message: "Firebase auth state changed",
            details: "uid=\(user?.uid ?? "-") email=\(user?.email ?? "-") authenticated=\(user != nil)"
        )
    }
}

@MainActor
final class FirebaseSyncRepository: ObservableObject, SyncRepository {
    private let authRepository: FirebaseAuthRepository
    private let firestore: Firestore
    private let persistence: PersistenceController
    private let preferencesRepository: UserDefaultsPreferencesRepository
    private let logger: AppLogger
    private let lastSyncKey = "studyapp.sync.lastSyncAt"
    private var lastLoadedVersion: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    private static let maxChunkBytes = 500_000
    private static let maxSyncRetries = 3

    @Published private(set) var status = SyncStatus()

    init(
        authRepository: FirebaseAuthRepository,
        firestore: Firestore,
        persistence: PersistenceController,
        preferencesRepository: UserDefaultsPreferencesRepository,
        logger: AppLogger
    ) {
        self.authRepository = authRepository
        self.firestore = firestore
        self.persistence = persistence
        self.preferencesRepository = preferencesRepository
        self.logger = logger
        self.status = SyncStatus(
            isAuthenticated: authRepository.session != nil,
            email: authRepository.session?.email,
            lastSyncAt: UserDefaults.standard.object(forKey: lastSyncKey) as? Int64
        )

        authRepository.$session
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                self.status.isAuthenticated = session != nil
                self.status.email = session?.email
                if session == nil {
                    self.status.isSyncing = false
                    self.status.errorMessage = nil
                }
                self.logger.log(
                    category: .sync,
                    message: "Sync auth session updated",
                    details: "authenticated=\(session != nil) uid=\(session?.localId ?? "-") email=\(session?.email ?? "-")"
                )
            }
            .store(in: &cancellables)
    }

    convenience init(
        authRepository: FirebaseAuthRepository,
        persistence: PersistenceController,
        preferencesRepository: UserDefaultsPreferencesRepository,
        logger: AppLogger
    ) {
        self.init(
            authRepository: authRepository,
            firestore: Firestore.firestore(),
            persistence: persistence,
            preferencesRepository: preferencesRepository,
            logger: logger
        )
    }

    func syncNow() async throws {
        guard let session = authRepository.session else {
            logger.log(category: .sync, level: .warning, message: "syncNow rejected", details: "reason=unauthenticated")
            throw ValidationError(message: "同期するにはサインインが必要です")
        }
        status.isSyncing = true
        status.errorMessage = nil
        logger.log(category: .sync, message: "syncNow started", details: "uid=\(session.localId) email=\(session.email)")
        defer {
            status.isSyncing = false
            logger.log(
                category: .sync,
                message: "syncNow finished",
                details: "uid=\(session.localId) error=\(status.errorMessage ?? "-") lastSyncAt=\(status.lastSyncAt.map(String.init) ?? "-")"
            )
        }
        do {
            for attempt in 0..<Self.maxSyncRetries {
                logger.log(category: .sync, message: "syncNow attempt started", details: "attempt=\(attempt + 1)")
                let remotePayload = try await loadSnapshot(userId: session.localId)
                let local = try await persistence.exportData()
                let localChangeToken = persistence.changeToken
                let merged: AppData
                if let remotePayload {
                    logger.log(
                        category: .sync,
                        message: "Remote snapshot loaded",
                        details: "payloadBytes=\(remotePayload.lengthOfBytes(using: .utf8)) localSubjects=\(local.subjects.count) localMaterials=\(local.materials.count) localSessions=\(local.sessions.count)"
                    )
                    do {
                        let remote = try JSONDecoder().decode(AppData.self, from: Data(remotePayload.utf8))
                        logger.log(
                            category: .sync,
                            message: "Remote snapshot decoded",
                            details: "remoteSubjects=\(remote.subjects.count) remoteMaterials=\(remote.materials.count) remoteSessions=\(remote.sessions.count) remoteGoals=\(remote.goals.count) remoteExams=\(remote.exams.count) remotePlans=\(remote.plans.count)"
                        )
                        merged = merge(local: local, remote: remote)
                    } catch {
                        logger.log(category: .sync, level: .error, message: "Remote snapshot decode failed", details: "attempt=\(attempt + 1)", error: error)
                        throw ValidationError(message: "クラウド同期データの読み込みに失敗しました")
                    }
                } else {
                    logger.log(category: .sync, message: "No remote snapshot found", details: "uid=\(session.localId)")
                    merged = local
                }
                let synced = markSynced(merged, at: Date().epochMilliseconds)
                let payload = String(data: try JSONEncoder().encode(synced), encoding: .utf8) ?? "{}"
                logger.log(
                    category: .sync,
                    message: "Prepared merged payload",
                    details: "attempt=\(attempt + 1) payloadBytes=\(payload.lengthOfBytes(using: .utf8)) mergedSubjects=\(synced.subjects.count) mergedMaterials=\(synced.materials.count) mergedSessions=\(synced.sessions.count)"
                )
                do {
                    try await saveSnapshot(
                        userId: session.localId,
                        payload: payload,
                        updatedAt: synced.exportDate,
                        expectedVersion: lastLoadedVersion
                    )
                } catch {
                    logger.log(category: .sync, level: .error, message: "Remote snapshot save failed", details: "attempt=\(attempt + 1)", error: error)
                    throw error
                }
                guard persistence.changeToken == localChangeToken else {
                    logger.log(category: .sync, level: .warning, message: "Local change detected during sync", details: "attempt=\(attempt + 1)")
                    continue
                }
                do {
                    let useCase = ExportImportDataUseCase(repository: persistence)
                    _ = try await useCase.importJSON(payload, currentPreferences: preferencesRepository.loadPreferences())
                } catch {
                    logger.log(category: .sync, level: .error, message: "Merged snapshot import failed", details: "attempt=\(attempt + 1)", error: error)
                    throw ValidationError(message: "同期後のローカル反映に失敗しました")
                }
                UserDefaults.standard.set(synced.exportDate, forKey: lastSyncKey)
                status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: synced.exportDate)
                logger.log(category: .sync, message: "syncNow succeeded", details: "attempt=\(attempt + 1) lastSyncAt=\(synced.exportDate)")
                return
            }
            throw ValidationError(message: "同期中にローカルデータが更新されました。もう一度お試しください。")
        } catch {
            status.errorMessage = error.localizedDescription
            logger.log(category: .sync, level: .error, message: "syncNow failed", details: "uid=\(session.localId)", error: error)
            throw error
        }
    }

    func importLocalDataToCloud() async throws {
        guard let session = authRepository.session else {
            logger.log(category: .sync, level: .warning, message: "importLocalDataToCloud rejected", details: "reason=unauthenticated")
            throw ValidationError(message: "同期するにはサインインが必要です")
        }
        status.isSyncing = true
        status.errorMessage = nil
        logger.log(category: .sync, message: "importLocalDataToCloud started", details: "uid=\(session.localId) email=\(session.email)")
        defer {
            status.isSyncing = false
            logger.log(
                category: .sync,
                message: "importLocalDataToCloud finished",
                details: "uid=\(session.localId) error=\(status.errorMessage ?? "-") lastSyncAt=\(status.lastSyncAt.map(String.init) ?? "-")"
            )
        }
        do {
            for attempt in 0..<Self.maxSyncRetries {
                _ = try await loadSnapshot(userId: session.localId)
                let local = markSynced(try await persistence.exportData(), at: Date().epochMilliseconds)
                let localChangeToken = persistence.changeToken
                let payload = String(data: try JSONEncoder().encode(local), encoding: .utf8) ?? "{}"
                logger.log(
                    category: .sync,
                    message: "Prepared local upload payload",
                    details: "attempt=\(attempt + 1) payloadBytes=\(payload.lengthOfBytes(using: .utf8)) subjects=\(local.subjects.count) materials=\(local.materials.count) sessions=\(local.sessions.count)"
                )
                do {
                    try await saveSnapshot(
                        userId: session.localId,
                        payload: payload,
                        updatedAt: local.exportDate,
                        expectedVersion: lastLoadedVersion
                    )
                } catch {
                    logger.log(category: .sync, level: .error, message: "Local upload save failed", details: "attempt=\(attempt + 1)", error: error)
                    throw error
                }
                guard persistence.changeToken == localChangeToken else {
                    logger.log(category: .sync, level: .warning, message: "Local change detected during upload", details: "attempt=\(attempt + 1)")
                    continue
                }
                UserDefaults.standard.set(local.exportDate, forKey: lastSyncKey)
                status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: local.exportDate)
                logger.log(category: .sync, message: "importLocalDataToCloud succeeded", details: "attempt=\(attempt + 1) lastSyncAt=\(local.exportDate)")
                return
            }
            throw ValidationError(message: "同期中にローカルデータが更新されました。もう一度お試しください。")
        } catch {
            status.errorMessage = error.localizedDescription
            logger.log(category: .sync, level: .error, message: "importLocalDataToCloud failed", details: "uid=\(session.localId)", error: error)
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
            logger.log(category: .sync, message: "No sync manifest found", details: "uid=\(userId)")
            return nil
        }

        // Legacy format: direct payload field
        if let payload = data["payload"] as? String {
            lastLoadedVersion = readInteger(data["version"]) ?? 0
            logger.log(category: .sync, message: "Loaded legacy sync payload", details: "uid=\(userId) version=\(lastLoadedVersion) payloadBytes=\(payload.lengthOfBytes(using: .utf8))")
            return payload
        }

        // Chunked-v2 format
        guard let format = data["format"] as? String, format == "chunked-v2",
              let version = readInteger(data["version"]),
              let chunkCountInt64 = readInteger(data["chunkCount"]),
              chunkCountInt64 > 0 else {
            lastLoadedVersion = readInteger(data["version"]) ?? 0
            logger.log(category: .sync, level: .warning, message: "Sync manifest format was unreadable", details: "uid=\(userId) version=\(lastLoadedVersion)")
            return nil
        }
        let chunkCount = Int(chunkCountInt64)

        lastLoadedVersion = version
        let chunksCol = manifestRef.collection("chunks")

        var parts = [String]()
        for i in 0..<chunkCount {
            let chunkId = String(format: "%06d", i)
            let chunkSnap = try await chunksCol.document(chunkId).getDocument()
            guard let chunkData = chunkSnap.data(),
                  let chunkVersion = readInteger(chunkData["version"]),
                  chunkVersion == version,
                  let payloadPart = chunkData["payloadPart"] as? String else {
                logger.log(category: .sync, level: .error, message: "Chunk read failed", details: "uid=\(userId) version=\(version) chunkIndex=\(i)")
                throw ValidationError(message: "同期データの読み込みに失敗しました")
            }
            parts.append(payloadPart)
        }
        logger.log(category: .sync, message: "Loaded chunked sync payload", details: "uid=\(userId) version=\(version) chunkCount=\(chunkCount)")
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
            let currentVersion: Int64 = self.readInteger(currentData["version"]) ?? 0
            let oldChunkCount = Int(self.readInteger(currentData["chunkCount"]) ?? 0)

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
            logger.log(category: .sync, message: "Saved sync manifest", details: "uid=\(userId) version=\(lastLoadedVersion) chunkCount=\(newChunkCount) payloadBytes=\(payload.lengthOfBytes(using: .utf8)) updatedAt=\(updatedAt)")
        }
    }

    private func readInteger(_ value: Any?) -> Int64? {
        switch value {
        case let intValue as Int:
            return Int64(intValue)
        case let int64Value as Int64:
            return int64Value
        case let number as NSNumber:
            return number.int64Value
        case let string as String:
            return Int64(string)
        default:
            return nil
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
