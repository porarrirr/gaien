import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

enum FirebaseConfigurationStatus: Equatable {
    case configured
    case unavailable(String)

    var isConfigured: Bool {
        if case .configured = self { return true }
        return false
    }

    var logDescription: String {
        switch self {
        case .configured:
            return "configured=true"
        case .unavailable(let reason):
            return "configured=false reason=\(reason)"
        }
    }
}

enum FirebaseBootstrap {
    private(set) static var status: FirebaseConfigurationStatus = .unavailable("not-started")

    static func configureIfAvailable() {
        if FirebaseApp.app() != nil {
            status = .configured
            return
        }

        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            status = .unavailable("missing-google-service-info")
            return
        }

        guard let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            status = .unavailable("unreadable-google-service-info")
            return
        }

        guard isUsableFirebasePlist(plist) else {
            status = .unavailable("invalid-google-service-info")
            return
        }

        FirebaseApp.configure()
        status = .configured
    }

    private static func isUsableFirebasePlist(_ plist: [String: Any]) -> Bool {
        guard
            let appId = plist["GOOGLE_APP_ID"] as? String,
            let apiKey = plist["API_KEY"] as? String,
            let projectId = plist["PROJECT_ID"] as? String,
            let senderId = plist["GCM_SENDER_ID"] as? String,
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !senderId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        let pattern = #"^1:[0-9]+:ios:[0-9a-fA-F]+$"#
        return appId.range(of: pattern, options: .regularExpression) != nil
    }
}

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
        logger?.log(category: .auth, message: "Firebase sign-in started", details: "emailProvided=\(!email.isEmpty)")
        let result = try await auth.signIn(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
        logger?.log(category: .auth, message: "Firebase sign-in succeeded", details: "emailVerified=\(result.user.isEmailVerified)")
    }

    func signUp(email: String, password: String) async throws {
        logger?.log(category: .auth, message: "Firebase sign-up started", details: "emailProvided=\(!email.isEmpty)")
        let result = try await auth.createUser(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
        logger?.log(category: .auth, message: "Firebase sign-up succeeded", details: "emailVerified=\(result.user.isEmailVerified)")
    }

    func signOut() async throws {
        logger?.log(category: .auth, message: "Firebase sign-out started")
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
            details: "authenticated=\(user != nil)"
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
    private let localSyncOwnerKey = "studyapp.sync.localOwnerUserId"
    private var lastLoadedVersion: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    private static let maxChunkBytes = 200_000
    private static let maxSyncRetries = 3
    private static let syncSchemaVersion = AppData.currentSchemaVersion
    private static let backupRetentionDays = 30
    private static let alreadySyncingMessage = "同期はすでに実行中です。完了までお待ちください。"
    private static let accountSwitchMessage = "この端末のローカルデータは別の同期アカウントに紐づいています。全データを削除してから再度同期してください。"
    private static let destructiveSyncMessage = "同期により問題集の進捗履歴が大きく減少するため停止しました。自動バックアップを確認してください。"

    @Published private(set) var status = SyncStatus()

    var statusPublisher: AnyPublisher<SyncStatus, Never> {
        $status.eraseToAnyPublisher()
    }

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
                    details: "authenticated=\(session != nil)"
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
        try beginSyncOperation(named: "syncNow", session: session)
        logger.log(category: .sync, message: "syncNow started")
        defer {
            endSyncOperation()
            logger.log(
                category: .sync,
                message: "syncNow finished",
                details: "error=\(status.errorMessage ?? "-") lastSyncAt=\(status.lastSyncAt.map(String.init) ?? "-")"
            )
        }
        do {
            for attempt in 0..<Self.maxSyncRetries {
                logger.log(category: .sync, message: "syncNow attempt started", details: "attempt=\(attempt + 1)")
                let local = try await persistence.exportData()
                try saveLocalBackup(local, reason: "before-syncNow")
                try ensureLocalSyncOwnership(session: session, local: local)
                let remotePayload = try await loadSnapshot(userId: session.localId)
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
                        try ensureRemoteCanMerge(remote)
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
                try ensureNoProblemProgressLoss(from: local, to: synced, operation: "syncNow")
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
                UserDefaults.standard.set(session.localId, forKey: localSyncOwnerKey)
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
        try beginSyncOperation(named: "importLocalDataToCloud", session: session)
        logger.log(category: .sync, message: "importLocalDataToCloud started")
        defer {
            endSyncOperation()
            logger.log(
                category: .sync,
                message: "importLocalDataToCloud finished",
                details: "error=\(status.errorMessage ?? "-") lastSyncAt=\(status.lastSyncAt.map(String.init) ?? "-")"
            )
        }
        do {
            for attempt in 0..<Self.maxSyncRetries {
                let localData = try await persistence.exportData()
                try saveLocalBackup(localData, reason: "before-importLocalDataToCloud")
                try ensureLocalSyncOwnership(session: session, local: localData)
                if let remotePayload = try await loadSnapshot(userId: session.localId) {
                    let remote = try JSONDecoder().decode(AppData.self, from: Data(remotePayload.utf8))
                    try ensureRemoteCanMerge(remote)
                    try ensureNoProblemProgressLoss(from: remote, to: localData, operation: "importLocalDataToCloud")
                }
                let local = markSynced(localData, at: Date().epochMilliseconds)
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
                UserDefaults.standard.set(session.localId, forKey: localSyncOwnerKey)
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

    func clearLocalSyncState() async {
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        UserDefaults.standard.removeObject(forKey: localSyncOwnerKey)
        status.lastSyncAt = nil
        status.errorMessage = nil
    }

    private func beginSyncOperation(named operation: String, session: AuthSession) throws {
        guard !status.isSyncing else {
            logger.log(
                category: .sync,
                level: .warning,
                message: "\(operation) rejected",
                details: "reason=already-syncing uid=\(session.localId)"
            )
            throw ValidationError(message: Self.alreadySyncingMessage)
        }
        status.isSyncing = true
        status.errorMessage = nil
    }

    private func endSyncOperation() {
        status.isSyncing = false
    }

    private func ensureLocalSyncOwnership(session: AuthSession, local: AppData) throws {
        let localSyncOwnerUserId = UserDefaults.standard.string(forKey: localSyncOwnerKey)
        if localSyncOwnerUserId == nil || localSyncOwnerUserId == session.localId || local.isEmpty {
            return
        }
        logger.log(category: .sync, level: .warning, message: "Sync blocked due to account mismatch")
        throw ValidationError(message: Self.accountSwitchMessage)
    }

    private func ensureRemoteCanMerge(_ remote: AppData) throws {
        if remote.schemaVersion < Self.syncSchemaVersion && !remote.supportsProblemRecords {
            logger.log(
                category: .sync,
                level: .warning,
                message: "Remote snapshot uses legacy problem-progress schema",
                details: "schemaVersion=\(remote.schemaVersion) supportsProblemRecords=\(remote.supportsProblemRecords)"
            )
        }
    }

    private func ensureNoProblemProgressLoss(from source: AppData, to destination: AppData, operation: String) throws {
        let sourceSummary = SyncDataSummary(appData: source)
        let destinationSummary = SyncDataSummary(appData: destination)
        guard sourceSummary.hasProblemProgress else { return }

        let lostSessionRecords = destinationSummary.sessionProblemRecords < sourceSummary.sessionProblemRecords
        let lostMaterialRecords = destinationSummary.materialProblemRecords < sourceSummary.materialProblemRecords
        let lostReviewRecords = destinationSummary.activeProblemReviewRecords < sourceSummary.activeProblemReviewRecords
        let lostProblemTotal = destinationSummary.materialsWithProblemTotals < sourceSummary.materialsWithProblemTotals

        guard lostSessionRecords || lostMaterialRecords || lostReviewRecords || lostProblemTotal else { return }
        logger.log(
            category: .sync,
            level: .error,
            message: "Sync blocked to protect problem progress",
            details: "operation=\(operation) before=\(sourceSummary.logDescription) after=\(destinationSummary.logDescription)"
        )
        throw ValidationError(message: Self.destructiveSyncMessage)
    }

    private func saveLocalBackup(_ appData: AppData, reason: String) throws {
        let backupRoot = try localBackupDirectory()
        let timestamp = Date().epochMilliseconds
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        let fileName = "sync-\(reason)-\(formatter.string(from: Date(epochMilliseconds: timestamp))).json"
        let url = backupRoot.appendingPathComponent(fileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(appData)
        try data.write(to: url, options: .atomic)
        try pruneLocalBackups(in: backupRoot, now: timestamp)
        logger.log(
            category: .sync,
            message: "Local sync backup saved",
            details: "file=\(fileName) bytes=\(data.count) \(SyncDataSummary(appData: appData).logDescription)"
        )
    }

    private func localBackupDirectory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("StudyApp/SyncBackups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func pruneLocalBackups(in directory: URL, now: Int64) throws {
        let cutoff = now - Int64(Self.backupRetentionDays) * 24 * 60 * 60 * 1000
        let files = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        for file in files where file.pathExtension == "json" {
            let values = try file.resourceValues(forKeys: [.contentModificationDateKey])
            guard let modified = values.contentModificationDate else { continue }
            if modified.epochMilliseconds < cutoff {
                try? FileManager.default.removeItem(at: file)
            }
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
        let payloadSummary = SyncDataSummary(payload: payload)
        let payloadBytes = payload.lengthOfBytes(using: .utf8)

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
            let snapshotId = Self.snapshotId(for: newVersion)
            let snapshotRef = db.collection("users").document(userId)
                .collection("sync_snapshots").document(snapshotId)
            let snapshotChunksCol = snapshotRef.collection("chunks")
            let manifestData: [String: Any] = [
                "format": "chunked-v2",
                "schemaVersion": Self.syncSchemaVersion,
                "supportsProblemRecords": true,
                "version": newVersion,
                "updatedAt": updatedAt,
                "chunkCount": newChunkCount,
                "payloadBytes": payloadBytes,
                "retentionDays": Self.backupRetentionDays,
                "counts": payloadSummary.firestoreData
            ]

            transaction.setData(manifestData, forDocument: manifestRef)
            transaction.setData(
                manifestData.merging([
                    "snapshotId": snapshotId,
                    "createdAt": updatedAt
                ]) { current, _ in current },
                forDocument: snapshotRef
            )

            let chunksCol = manifestRef.collection("chunks")
            for (i, part) in chunks.enumerated() {
                let chunkRef = chunksCol.document(String(format: "%06d", i))
                transaction.setData([
                    "version": newVersion,
                    "index": i,
                    "payloadPart": part
                ], forDocument: chunkRef)

                let snapshotChunkRef = snapshotChunksCol.document(String(format: "%06d", i))
                transaction.setData([
                    "version": newVersion,
                    "index": i,
                    "payloadPart": part
                ], forDocument: snapshotChunkRef)
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
            try await pruneRemoteSnapshots(userId: userId, now: updatedAt)
            logger.log(category: .sync, message: "Saved sync manifest", details: "uid=\(userId) version=\(lastLoadedVersion) chunkCount=\(newChunkCount) payloadBytes=\(payload.lengthOfBytes(using: .utf8)) updatedAt=\(updatedAt)")
        }
    }

    private func pruneRemoteSnapshots(userId: String, now: Int64) async throws {
        let cutoff = now - Int64(Self.backupRetentionDays) * 24 * 60 * 60 * 1000
        let snapshots = try await firestore.collection("users").document(userId)
            .collection("sync_snapshots")
            .whereField("createdAt", isLessThan: cutoff)
            .getDocuments()
        guard !snapshots.documents.isEmpty else { return }

        for snapshot in snapshots.documents {
            let chunks = try await snapshot.reference.collection("chunks").getDocuments()
            var batch = firestore.batch()
            var writeCount = 0
            for chunk in chunks.documents {
                batch.deleteDocument(chunk.reference)
                writeCount += 1
                if writeCount >= 450 {
                    try await batch.commit()
                    batch = firestore.batch()
                    writeCount = 0
                }
            }
            batch.deleteDocument(snapshot.reference)
            try await batch.commit()
        }
        logger.log(category: .sync, message: "Pruned remote sync snapshots", details: "count=\(snapshots.documents.count) cutoff=\(cutoff)")
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

    private static func snapshotId(for version: Int64) -> String {
        String(format: "%020lld", version)
    }

    // MARK: - Merge helpers

    private func merge(local: AppData, remote: AppData) -> AppData {
        AppData(
            subjects: merge(local.subjects, remote.subjects, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            materials: mergeMaterials(local.materials, remote.materials),
            sessions: mergeSessions(local.sessions, remote.sessions),
            goals: merge(local.goals, remote.goals, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            exams: merge(local.exams, remote.exams, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            plans: mergePlans(local.plans, remote.plans),
            timetablePeriods: merge(local.timetablePeriods, remote.timetablePeriods, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            timetableEntries: merge(local.timetableEntries, remote.timetableEntries, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            timetableTerms: merge(local.timetableTerms, remote.timetableTerms, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            timetableReviewRecords: merge(local.timetableReviewRecords, remote.timetableReviewRecords, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            problemReviewRecords: merge(local.problemReviewRecords, remote.problemReviewRecords, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            exportDate: max(local.exportDate, remote.exportDate)
        )
    }

    private func mergeMaterials(_ local: [Material], _ remote: [Material]) -> [Material] {
        merge(local, remote, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt) { selected, other in
            guard selected.deletedAt == nil else { return selected }
            var enriched = selected
            if enriched.problemChapters.isEmpty, !other.problemChapters.isEmpty {
                enriched.problemChapters = other.problemChapters
            }
            if enriched.problemRecords.isEmpty, !other.problemRecords.isEmpty {
                enriched.problemRecords = other.problemRecords
            }
            if enriched.totalProblems == 0, other.totalProblems > 0 {
                enriched.totalProblems = other.totalProblems
            }
            return enriched
        }
    }

    private func mergeSessions(_ local: [StudySession], _ remote: [StudySession]) -> [StudySession] {
        merge(local, remote, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt) { selected, other in
            guard selected.deletedAt == nil else { return selected }
            var enriched = selected
            if enriched.problemRecords.isEmpty, !other.problemRecords.isEmpty {
                enriched.problemRecords = other.problemRecords
            }
            if enriched.problemStart == nil {
                enriched.problemStart = other.problemStart
            }
            if enriched.problemEnd == nil {
                enriched.problemEnd = other.problemEnd
            }
            if enriched.wrongProblemCount == nil {
                enriched.wrongProblemCount = other.wrongProblemCount
            }
            return enriched
        }
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
        merge(lhs, rhs, key: key, updatedAt: updatedAt, deletedAt: deletedAt) { selected, _ in selected }
    }

    private func merge<T>(
        _ lhs: [T],
        _ rhs: [T],
        key: KeyPath<T, String>,
        updatedAt: KeyPath<T, Int64>,
        deletedAt: KeyPath<T, Int64?>,
        preservingDetails enrich: (T, T) -> T
    ) -> [T] {
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
                result[id] = enrich(item, existing)
            } else {
                result[id] = enrich(existing, item)
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
            timetablePeriods: appData.timetablePeriods.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            timetableEntries: appData.timetableEntries.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            timetableTerms: appData.timetableTerms.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            timetableReviewRecords: appData.timetableReviewRecords.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            problemReviewRecords: appData.problemReviewRecords.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            exportDate: timestamp
        )
    }
}

private extension AppData {
    var isEmpty: Bool {
        subjects.isEmpty &&
        materials.isEmpty &&
        sessions.isEmpty &&
        goals.isEmpty &&
        exams.isEmpty &&
        plans.isEmpty &&
        timetablePeriods.isEmpty &&
        timetableEntries.isEmpty &&
        timetableTerms.isEmpty &&
        timetableReviewRecords.isEmpty &&
        problemReviewRecords.isEmpty
    }
}

private struct SyncDataSummary {
    let subjects: Int
    let materials: Int
    let sessions: Int
    let sessionProblemRecords: Int
    let materialProblemRecords: Int
    let materialsWithProblemTotals: Int
    let problemReviewRecords: Int
    let activeProblemReviewRecords: Int

    init(
        subjects: Int,
        materials: Int,
        sessions: Int,
        sessionProblemRecords: Int,
        materialProblemRecords: Int,
        materialsWithProblemTotals: Int,
        problemReviewRecords: Int,
        activeProblemReviewRecords: Int
    ) {
        self.subjects = subjects
        self.materials = materials
        self.sessions = sessions
        self.sessionProblemRecords = sessionProblemRecords
        self.materialProblemRecords = materialProblemRecords
        self.materialsWithProblemTotals = materialsWithProblemTotals
        self.problemReviewRecords = problemReviewRecords
        self.activeProblemReviewRecords = activeProblemReviewRecords
    }

    init(appData: AppData) {
        self.init(
            subjects: appData.subjects.count,
            materials: appData.materials.count,
            sessions: appData.sessions.count,
            sessionProblemRecords: appData.sessions.reduce(0) { $0 + $1.problemRecords.count },
            materialProblemRecords: appData.materials.reduce(0) { $0 + $1.problemRecords.count },
            materialsWithProblemTotals: appData.materials.filter { $0.effectiveTotalProblems > 0 }.count,
            problemReviewRecords: appData.problemReviewRecords.count,
            activeProblemReviewRecords: appData.problemReviewRecords.filter { $0.deletedAt == nil }.count
        )
    }

    init(payload: String) {
        if let data = payload.data(using: .utf8),
           let appData = try? JSONDecoder().decode(AppData.self, from: data) {
            self.init(appData: appData)
        } else {
            self.init(
                subjects: 0,
                materials: 0,
                sessions: 0,
                sessionProblemRecords: 0,
                materialProblemRecords: 0,
                materialsWithProblemTotals: 0,
                problemReviewRecords: 0,
                activeProblemReviewRecords: 0
            )
        }
    }

    var hasProblemProgress: Bool {
        sessionProblemRecords > 0 ||
        materialProblemRecords > 0 ||
        activeProblemReviewRecords > 0 ||
        materialsWithProblemTotals > 0
    }

    var firestoreData: [String: Any] {
        [
            "subjects": subjects,
            "materials": materials,
            "sessions": sessions,
            "sessionProblemRecords": sessionProblemRecords,
            "materialProblemRecords": materialProblemRecords,
            "materialsWithProblemTotals": materialsWithProblemTotals,
            "problemReviewRecords": problemReviewRecords,
            "activeProblemReviewRecords": activeProblemReviewRecords
        ]
    }

    var logDescription: String {
        "subjects=\(subjects) materials=\(materials) sessions=\(sessions) sessionProblemRecords=\(sessionProblemRecords) materialProblemRecords=\(materialProblemRecords) problemReviewRecords=\(problemReviewRecords) activeProblemReviewRecords=\(activeProblemReviewRecords) materialsWithProblemTotals=\(materialsWithProblemTotals)"
    }
}

@MainActor
final class DisabledAuthRepository: AuthRepository {
    var session: AuthSession? { nil }

    func signIn(email: String, password: String) async throws {
        throw ValidationError(message: "Firebase設定が無効なため、クラウド同期は利用できません")
    }

    func signUp(email: String, password: String) async throws {
        throw ValidationError(message: "Firebase設定が無効なため、クラウド同期は利用できません")
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
        throw ValidationError(message: "Firebase設定が無効なため、クラウド同期は利用できません")
    }

    func importLocalDataToCloud() async throws {
        logger.log(category: .sync, level: .warning, message: "Cloud upload unavailable", details: FirebaseBootstrap.status.logDescription)
        throw ValidationError(message: "Firebase設定が無効なため、クラウド同期は利用できません")
    }

    func clearLocalSyncState() async {}
}
