import Combine
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import Foundation

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
                try await saveLocalBackup(local, reason: "before-syncNow")
                try ensureLocalSyncOwnership(session: session, local: local)
                let remotePayload = try await loadSnapshot(userId: session.localId)
                let localChangeToken = persistence.changeToken
                if let remotePayload {
                    logger.log(
                        category: .sync,
                        message: "Remote snapshot loaded",
                        details: "payloadBytes=\(remotePayload.lengthOfBytes(using: .utf8)) localSubjects=\(local.subjects.count) localMaterials=\(local.materials.count) localSessions=\(local.sessions.count)"
                    )
                }
                let merged: AppData
                let remote: AppData?
                let payload: String
                do {
                    // Heavy work (decode remote, merge, re-encode, stamp) runs off the
                    // main actor to keep the UI responsive as data grows.
                    let prepared = try await SyncPayloadCodec.prepareMergedPayload(
                        local: local,
                        remotePayload: remotePayload,
                        syncedAt: Date().epochMilliseconds
                    )
                    merged = prepared.merged
                    remote = prepared.remote
                    payload = prepared.payload
                    if let remote {
                        logger.log(
                            category: .sync,
                            message: "Remote snapshot decoded",
                            details: "remoteSubjects=\(remote.subjects.count) remoteMaterials=\(remote.materials.count) remoteSessions=\(remote.sessions.count) remoteGoals=\(remote.goals.count) remoteExams=\(remote.exams.count) remotePlans=\(remote.plans.count)"
                        )
                    } else {
                        logger.log(category: .sync, message: "No remote snapshot found", details: "uid=\(session.localId)")
                    }
                } catch {
                    logger.log(category: .sync, level: .error, message: "Remote snapshot decode/merge failed", details: "attempt=\(attempt + 1)", error: error)
                    throw ValidationError(message: "クラウド同期データの読み込みに失敗しました")
                }
                if let remote {
                    try ensureRemoteCanMerge(remote)
                }
                try ensureNoProblemProgressLoss(from: local, to: merged, operation: "syncNow")
                logger.log(
                    category: .sync,
                    message: "Prepared merged payload",
                    details: "attempt=\(attempt + 1) payloadBytes=\(payload.lengthOfBytes(using: .utf8)) mergedSubjects=\(merged.subjects.count) mergedMaterials=\(merged.materials.count) mergedSessions=\(merged.sessions.count)"
                )
                do {
                    try await saveSnapshot(
                        userId: session.localId,
                        payload: payload,
                        updatedAt: merged.exportDate,
                        expectedVersion: lastLoadedVersion
                    )
                } catch {
                    if isSyncSnapshotConflict(error) {
                        logger.log(category: .sync, level: .warning, message: "Remote snapshot save conflict", details: "attempt=\(attempt + 1)", error: error)
                        continue
                    }
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
                UserDefaults.standard.set(merged.exportDate, forKey: lastSyncKey)
                UserDefaults.standard.set(session.localId, forKey: localSyncOwnerKey)
                status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: merged.exportDate)
                logger.log(category: .sync, message: "syncNow succeeded", details: "attempt=\(attempt + 1) lastSyncAt=\(merged.exportDate)")
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
                try await saveLocalBackup(localData, reason: "before-importLocalDataToCloud")
                try ensureLocalSyncOwnership(session: session, local: localData)
                if let remotePayload = try await loadSnapshot(userId: session.localId) {
                    let remote = try await SyncPayloadCodec.decode(remotePayload)
                    try ensureRemoteCanMerge(remote)
                    try ensureNoProblemProgressLoss(from: remote, to: localData, operation: "importLocalDataToCloud")
                }
                let prepared = try await SyncPayloadCodec.prepareLocalPayload(local: localData, syncedAt: Date().epochMilliseconds)
                let local = prepared.synced
                let payload = prepared.payload
                let localChangeToken = persistence.changeToken
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
                    if isSyncSnapshotConflict(error) {
                        logger.log(category: .sync, level: .warning, message: "Local upload save conflict", details: "attempt=\(attempt + 1)", error: error)
                        continue
                    }
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

    private func saveLocalBackup(_ appData: AppData, reason: String) async throws {
        let backupRoot = try localBackupDirectory()
        let timestamp = Date().epochMilliseconds
        let formatter = StudyFormatters.fileSafeTimestamp
        let fileName = "sync-\(reason)-\(formatter.string(from: Date(epochMilliseconds: timestamp))).json"
        let url = backupRoot.appendingPathComponent(fileName)
        // Encode off the main actor so the UI stays responsive with large data sets.
        let data = try await SyncPayloadCodec.encode(appData, prettyPrinted: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try protectLocalBackupItem(at: url)
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
        try protectLocalBackupItem(at: directory)
        return directory
    }

    private func protectLocalBackupItem(at url: URL) throws {
        var mutableURL = url
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = true
        try mutableURL.setResourceValues(resourceValues)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
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
            lastLoadedVersion = readFirestoreInteger(data["version"]) ?? 0
            logger.log(category: .sync, message: "Loaded legacy sync payload", details: "uid=\(userId) version=\(lastLoadedVersion) payloadBytes=\(payload.lengthOfBytes(using: .utf8))")
            return payload
        }

        // Chunked-v2 format
        guard let format = data["format"] as? String, format == "chunked-v2",
              let version = readFirestoreInteger(data["version"]),
              let chunkCountInt64 = readFirestoreInteger(data["chunkCount"]),
              chunkCountInt64 > 0 else {
            lastLoadedVersion = readFirestoreInteger(data["version"]) ?? 0
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
                  let chunkVersion = readFirestoreInteger(chunkData["version"]),
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
        let chunks = splitSyncPayloadIntoChunks(payload)
        let newChunkCount = chunks.count
        let saveResult = try await saveChunkedSyncSnapshot(
            firestore: firestore,
            userId: userId,
            chunks: chunks,
            payloadBytes: payload.lengthOfBytes(using: .utf8),
            payloadCounts: SyncDataSummary(payload: payload).firestoreData,
            updatedAt: updatedAt,
            expectedVersion: expectedVersion,
            syncSchemaVersion: Self.syncSchemaVersion,
            backupRetentionDays: Self.backupRetentionDays
        )
        lastLoadedVersion = saveResult.version
        if let cleanupError = saveResult.staleChunkCleanupError {
            logger.log(category: .sync, level: .warning, message: "Stale sync chunks cleanup failed", details: "uid=\(userId) version=\(lastLoadedVersion)", error: cleanupError)
        }
        try await pruneRemoteSnapshots(userId: userId, now: updatedAt)
        logger.log(category: .sync, message: "Saved sync manifest", details: "uid=\(userId) version=\(lastLoadedVersion) chunkCount=\(newChunkCount) payloadBytes=\(payload.lengthOfBytes(using: .utf8)) updatedAt=\(updatedAt)")
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

    // MARK: - Merge helpers (delegated to SyncMergeEngine for testability)

    private func merge(local: AppData, remote: AppData) -> AppData {
        SyncMergeEngine.merge(local: local, remote: remote)
    }

    private func markSynced(_ appData: AppData, at timestamp: Int64) -> AppData {
        SyncMergeEngine.markSynced(appData, at: timestamp)
    }
}

private func readFirestoreInteger(_ value: Any?) -> Int64? {
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

private func makeSyncSnapshotId(for version: Int64) -> String {
    String(format: "%020lld", version)
}

private func makeSyncChunkId(for index: Int) -> String {
    String(format: "%06d", index)
}

private func splitSyncPayloadIntoChunks(_ payload: String) -> [String] {
    let maxChunkBytes = 200_000
    let utf8 = Array(payload.utf8)
    guard !utf8.isEmpty else { return [""] }
    var chunks = [String]()
    var start = 0
    while start < utf8.count {
        var end = min(start + maxChunkBytes, utf8.count)
        // Avoid splitting in the middle of a multi-byte UTF-8 character.
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

private struct SyncSnapshotSaveResult {
    let version: Int64
    let staleChunkCleanupError: Error?
}

private enum SyncSnapshotSaveError: LocalizedError {
    case conflict(expected: Int64, actual: Int64)

    var errorDescription: String? {
        switch self {
        case .conflict:
            return "同期の競合が発生しました。再試行してください。"
        }
    }
}

private func isSyncSnapshotConflict(_ error: Error) -> Bool {
    guard let error = error as? SyncSnapshotSaveError else { return false }
    if case .conflict = error {
        return true
    }
    return false
}

private struct SyncWriteOperation {
    enum Kind {
        case set([String: Any])
        case delete
    }

    let ref: DocumentReference
    let kind: Kind
}

private func commitWriteBatch(firestore: Firestore, operations: [SyncWriteOperation]) async throws {
    let maxBatchOperations = 450
    guard !operations.isEmpty else { return }

    var index = 0
    while index < operations.count {
        let batch = firestore.batch()
        let end = min(index + maxBatchOperations, operations.count)
        for operation in operations[index..<end] {
            switch operation.kind {
            case .set(let data):
                batch.setData(data, forDocument: operation.ref)
            case .delete:
                batch.deleteDocument(operation.ref)
            }
        }
        try await batch.commit()
        index = end
    }
}

private func saveChunkedSyncSnapshot(
    firestore: Firestore,
    userId: String,
    chunks: [String],
    payloadBytes: Int,
    payloadCounts: [String: Any],
    updatedAt: Int64,
    expectedVersion: Int64?,
    syncSchemaVersion: Int,
    backupRetentionDays: Int
) async throws -> SyncSnapshotSaveResult {
    let manifestRef = firestore.collection("users").document(userId)
        .collection("sync").document("default")
    let chunksCol = manifestRef.collection("chunks")

    let version = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Int64, Error>) in
        firestore.runTransaction({ transaction, errorPointer in
            do {
                let manifestSnap = try transaction.getDocument(manifestRef)
                let currentData = manifestSnap.data() ?? [:]
                let currentVersion: Int64 = readFirestoreInteger(currentData["version"]) ?? 0
                let oldChunkCount = Int(readFirestoreInteger(currentData["chunkCount"]) ?? 0)

                if let expected = expectedVersion, currentVersion != expected {
                    throw SyncSnapshotSaveError.conflict(expected: expected, actual: currentVersion)
                }

                let newVersion = currentVersion + 1
                let snapshotId = makeSyncSnapshotId(for: newVersion)
                let snapshotRef = firestore.collection("users").document(userId)
                    .collection("sync_snapshots").document(snapshotId)
                let snapshotChunksCol = snapshotRef.collection("chunks")
                let manifestData: [String: Any] = [
                    "format": "chunked-v2",
                    "schemaVersion": syncSchemaVersion,
                    "supportsProblemRecords": true,
                    "version": newVersion,
                    "updatedAt": updatedAt,
                    "chunkCount": chunks.count,
                    "payloadBytes": payloadBytes,
                    "retentionDays": backupRetentionDays,
                    "counts": payloadCounts
                ]
                let snapshotData = manifestData.merging([
                    "snapshotId": snapshotId,
                    "createdAt": updatedAt
                ]) { current, _ in current }

                transaction.setData(snapshotData, forDocument: snapshotRef)
                for (i, part) in chunks.enumerated() {
                    let chunkData: [String: Any] = [
                        "version": newVersion,
                        "index": i,
                        "payloadPart": part
                    ]
                    transaction.setData(chunkData, forDocument: chunksCol.document(makeSyncChunkId(for: i)))
                    transaction.setData(chunkData, forDocument: snapshotChunksCol.document(makeSyncChunkId(for: i)))
                }
                if oldChunkCount > chunks.count {
                    for index in chunks.count..<oldChunkCount {
                        transaction.deleteDocument(chunksCol.document(makeSyncChunkId(for: index)))
                    }
                }
                transaction.setData(manifestData, forDocument: manifestRef)
                return NSNumber(value: newVersion)
            } catch {
                errorPointer?.pointee = error as NSError
                return nil
            }
        }, completion: { result, error in
            if let error {
                continuation.resume(throwing: error)
            } else if let version = result as? NSNumber {
                continuation.resume(returning: version.int64Value)
            } else {
                continuation.resume(throwing: SyncSnapshotSaveError.conflict(expected: expectedVersion ?? 0, actual: 0))
            }
        })
    }

    return SyncSnapshotSaveResult(version: version, staleChunkCleanupError: nil)
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

