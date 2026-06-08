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
    private let currentFirebaseUserId: () -> String?
    private let lastSyncKey = "studyapp.sync.lastSyncAt"
    private let localSyncOwnerKey = "studyapp.sync.localOwnerUserId"
    /// Per-user delta cursor. Stored under
    /// `studyapp.sync.deltaCursor.<uid>` so switching accounts does not mix
    /// cursors. Measured in client-clock milliseconds.
    private let deltaCursorKeyPrefix = "studyapp.sync.deltaCursor."
    /// Set to true once we have migrated a user away from the legacy
    /// chunked-v2 snapshot and cleaned up those documents. Stored per user.
    private let deltaMigrationDoneKeyPrefix = "studyapp.sync.deltaMigrationDone."
    private var lastLoadedVersion: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    private static let maxSyncRetries = 3
    private static let syncSchemaVersion = AppData.currentSchemaVersion
    private static let backupRetentionDays = 30
    /// Delta tombstones are kept for at least this long so offline devices
    /// can still see deletions on their next sync. 90 days is comfortably
    /// longer than typical offline usage while bounding storage.
    private static let tombstoneRetentionMillis: Int64 = 90 * 24 * 60 * 60 * 1000
    private static let signInRequiredMessage = "同期するにはサインインが必要です"
    private static let alreadySyncingMessage = "同期はすでに実行中です。完了までお待ちください。"
    private static let accountSwitchMessage = "この端末のローカルデータは別の同期アカウントに紐づいています。全データを削除してから再度同期してください。"
    private static let destructiveSyncMessage = "同期により問題集の進捗履歴が大きく減少するため停止しました。自動バックアップを確認してください。"
    private static let firestorePermissionMessage = "クラウド同期に失敗しました。Firestoreルールが未反映か、このアカウントに十分な権限がありません。"
    private static let authenticationExpiredMessage = "認証情報の有効期限が切れています。もう一度サインインしてください。"
    private static let pendingConflictsMessage = "同期データに解決が必要な競合があります。設定の「競合を解決」から選択してください。"

    private lazy var deltaStore = FirestoreDeltaSyncStore(firestore: firestore, logger: logger)
    private var pendingConflictUserId: String?

    @Published private(set) var status = SyncStatus()

    var statusPublisher: AnyPublisher<SyncStatus, Never> {
        $status.eraseToAnyPublisher()
    }

    init(
        authRepository: FirebaseAuthRepository,
        firestore: Firestore,
        persistence: PersistenceController,
        preferencesRepository: UserDefaultsPreferencesRepository,
        logger: AppLogger,
        currentFirebaseUserId: @escaping () -> String? = { Auth.auth().currentUser?.uid }
    ) {
        self.authRepository = authRepository
        self.firestore = firestore
        self.persistence = persistence
        self.preferencesRepository = preferencesRepository
        self.logger = logger
        self.currentFirebaseUserId = currentFirebaseUserId
        let initialConflictCount = authRepository.session.map { SyncConflictStore.load(userId: $0.localId).count } ?? 0
        self.pendingConflictUserId = authRepository.session?.localId
        self.status = SyncStatus(
            isAuthenticated: authRepository.session != nil,
            email: authRepository.session?.email,
            lastSyncAt: UserDefaults.standard.object(forKey: lastSyncKey) as? Int64,
            errorMessage: initialConflictCount > 0 ? Self.pendingConflictsMessage : nil,
            pendingConflictCount: initialConflictCount
        )

        authRepository.$session
            .removeDuplicates()
            .receive(on: RunLoop.main)
            .sink { [weak self] session in
                guard let self else { return }
                self.pendingConflictUserId = session?.localId
                let conflictCount = session.map { SyncConflictStore.load(userId: $0.localId).count } ?? 0
                self.status.isAuthenticated = session != nil
                self.status.email = session?.email
                if session == nil {
                    self.status.isSyncing = false
                }
                self.status.pendingConflictCount = conflictCount
                self.status.errorMessage = conflictCount > 0 ? Self.pendingConflictsMessage : nil
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
        let session = try requireActiveSession(operation: "syncNow")
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
            try await migrateLegacyChunkedSnapshotIfNeeded(session: session)

            for attempt in 0..<Self.maxSyncRetries {
                logger.log(category: .sync, message: "syncNow attempt started", details: "attempt=\(attempt + 1)")
                let local = try await persistence.exportData()
                try await saveLocalBackup(local, reason: "before-syncNow")
                try ensureLocalSyncOwnership(session: session, local: local)

                let localChangeToken = persistence.changeToken
                let cursor = loadCompositeDeltaCursor(userId: session.localId)
                try SyncBaseShadowStore.bootstrapIfNeeded(userId: session.localId, local: local)
                let baseShadow = SyncBaseShadowStore.load(userId: session.localId)

                let remoteEnvelopes = try await deltaStore.fetchEnvelopes(
                    userId: session.localId,
                    changedSince: cursor
                )

                let syncedAt = Date().epochMilliseconds
                let mergeOutcome = try await MergeExecutor.apply(
                    envelopes: remoteEnvelopes,
                    onto: local,
                    baseShadow: baseShadow,
                    syncedAt: syncedAt
                )
                let merged = mergeOutcome.merged
                try ensureNoProblemProgressLoss(from: local, to: merged, operation: "syncNow")

                let storedConflicts = mergeStoredConflicts(
                    userId: session.localId,
                    newlyDetected: mergeOutcome.conflicts
                )
                pendingConflictUserId = session.localId

                var outboundEnvelopes = SyncDeltaSerializer.changedSince(merged, cursor: cursor)
                let previousRevisions = SyncBaseShadowStore.loadRevisionMap(userId: session.localId)
                outboundEnvelopes = SyncRevisionStamper.stamp(
                    outboundEnvelopes,
                    previousBase: baseShadow,
                    previousRevisions: previousRevisions
                )
                let unresolvedConflictIds = Set(storedConflicts.map(\.documentId))
                if !unresolvedConflictIds.isEmpty {
                    outboundEnvelopes.removeAll { unresolvedConflictIds.contains($0.documentId) }
                }
                logger.log(
                    category: .sync,
                    message: "Prepared delta sync",
                    details: "attempt=\(attempt + 1) cursorUpdatedAt=\(cursor.updatedAt) cursorDoc=\(cursor.documentId) inbound=\(remoteEnvelopes.count) outbound=\(outboundEnvelopes.count) conflicts=\(storedConflicts.count) legacyFallback=\(mergeOutcome.usedLegacyTwoWayFallback)"
                )

                guard persistence.changeToken == localChangeToken else {
                    logger.log(
                        category: .sync,
                        level: .warning,
                        message: "Local change detected before delta commit",
                        details: "attempt=\(attempt + 1)"
                    )
                    continue
                }

                // Apply merge locally first so a Firestore write failure
                // doesn't leave us out of sync with what we intend to push.
                try await applyMergedSnapshotLocally(merged)

                if !outboundEnvelopes.isEmpty {
                    try await deltaStore.writeEnvelopes(outboundEnvelopes, userId: session.localId)
                }

                let resolvedMergedEnvelopes = SyncDeltaSerializer.decompose(merged)
                    .filter { !unresolvedConflictIds.contains($0.documentId) }
                let resolvedRemoteEnvelopes = remoteEnvelopes
                    .filter { !unresolvedConflictIds.contains($0.documentId) }
                var newCursor = cursor
                for envelope in resolvedRemoteEnvelopes + resolvedMergedEnvelopes + outboundEnvelopes {
                    newCursor.absorb(envelope)
                }
                saveCompositeDeltaCursor(userId: session.localId, cursor: newCursor)
                if unresolvedConflictIds.isEmpty {
                    try? SyncBaseShadowStore.save(merged, userId: session.localId)
                } else {
                    let nextBase = SyncDeltaSerializer.assemble(
                        envelopes: resolvedMergedEnvelopes,
                        onto: baseShadow ?? local
                    )
                    try? SyncBaseShadowStore.save(nextBase, userId: session.localId)
                }
                try? SyncBaseShadowStore.mergeRevisionMap(
                    envelopes: resolvedRemoteEnvelopes + outboundEnvelopes,
                    userId: session.localId
                )
                UserDefaults.standard.set(merged.exportDate, forKey: lastSyncKey)
                UserDefaults.standard.set(session.localId, forKey: localSyncOwnerKey)
                status = SyncStatus(
                    isAuthenticated: true,
                    email: session.email,
                    isSyncing: false,
                    lastSyncAt: merged.exportDate,
                    errorMessage: storedConflicts.isEmpty ? nil : Self.pendingConflictsMessage,
                    pendingConflictCount: storedConflicts.count
                )

                // Background purge of stale tombstones. Run best-effort; a
                // failure here doesn't invalidate the successful sync.
                Task { [weak self] in
                    guard let self else { return }
                    do {
                        try await self.deltaStore.purgeTombstonesOlderThan(
                            retentionMillis: Self.tombstoneRetentionMillis,
                            now: Date().epochMilliseconds,
                            userId: session.localId
                        )
                    } catch {
                        self.logger.log(
                            category: .sync,
                            level: .warning,
                            message: "Tombstone purge failed",
                            error: error
                        )
                    }
                }

                logger.log(
                    category: .sync,
                    message: "syncNow succeeded",
                    details: "attempt=\(attempt + 1) lastSyncAt=\(merged.exportDate) cursorUpdatedAt=\(newCursor.updatedAt) cursorDoc=\(newCursor.documentId)"
                )
                return
            }
            throw ValidationError(message: "同期中にローカルデータが更新されました。もう一度お試しください。")
        } catch {
            let mapped = mapSyncFailure(error)
            status.errorMessage = mapped.localizedDescription
            logger.log(category: .sync, level: .error, message: "syncNow failed", details: "uid=\(session.localId)", error: error)
            throw mapped
        }
    }

    func importLocalDataToCloud() async throws {
        let session = try requireActiveSession(operation: "importLocalDataToCloud")
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
            try await migrateLegacyChunkedSnapshotIfNeeded(session: session)

            for attempt in 0..<Self.maxSyncRetries {
                let localData = try await persistence.exportData()
                try await saveLocalBackup(localData, reason: "before-importLocalDataToCloud")
                try ensureLocalSyncOwnership(session: session, local: localData)

                // Defend against destructive uploads: if the cloud already
                // has progress we don't, bail out and force the user to
                // pull first.
                let cursor = loadCompositeDeltaCursor(userId: session.localId)
                let remoteEnvelopes = try await deltaStore.fetchEnvelopes(userId: session.localId, changedSince: cursor)
                if !remoteEnvelopes.isEmpty {
                    let remoteApp = SyncDeltaSerializer.assemble(envelopes: remoteEnvelopes, onto: localData)
                    try ensureNoProblemProgressLoss(from: remoteApp, to: localData, operation: "importLocalDataToCloud")
                }

                let nowMs = Date().epochMilliseconds
                let stampedLocal = SyncMergeEngine.markSynced(localData, at: nowMs)
                let baseShadow = SyncBaseShadowStore.load(userId: session.localId)
                var envelopes = SyncDeltaSerializer.decompose(stampedLocal)
                envelopes = SyncRevisionStamper.stamp(
                    envelopes,
                    previousBase: baseShadow,
                    previousRevisions: SyncBaseShadowStore.loadRevisionMap(userId: session.localId)
                )
                let localChangeToken = persistence.changeToken

                logger.log(
                    category: .sync,
                    message: "Prepared local upload",
                    details: "attempt=\(attempt + 1) envelopes=\(envelopes.count)"
                )
                guard persistence.changeToken == localChangeToken else {
                    logger.log(category: .sync, level: .warning, message: "Local change detected during upload", details: "attempt=\(attempt + 1)")
                    continue
                }

                try await deltaStore.writeEnvelopes(envelopes, userId: session.localId)
                var newCursor = cursor
                envelopes.forEach { newCursor.absorb($0) }
                saveCompositeDeltaCursor(userId: session.localId, cursor: newCursor)
                try? SyncBaseShadowStore.save(stampedLocal, userId: session.localId)
                try? SyncBaseShadowStore.mergeRevisionMap(envelopes: envelopes, userId: session.localId)
                UserDefaults.standard.set(nowMs, forKey: lastSyncKey)
                UserDefaults.standard.set(session.localId, forKey: localSyncOwnerKey)
                status = SyncStatus(isAuthenticated: true, email: session.email, isSyncing: false, lastSyncAt: nowMs)
                logger.log(category: .sync, message: "importLocalDataToCloud succeeded", details: "attempt=\(attempt + 1) lastSyncAt=\(nowMs) envelopes=\(envelopes.count)")
                return
            }
            throw ValidationError(message: "同期中にローカルデータが更新されました。もう一度お試しください。")
        } catch {
            let mapped = mapSyncFailure(error)
            status.errorMessage = mapped.localizedDescription
            logger.log(category: .sync, level: .error, message: "importLocalDataToCloud failed", details: "uid=\(session.localId)", error: error)
            throw mapped
        }
    }

    func clearLocalSyncState() async {
        if let userId = authRepository.session?.localId {
            SyncConflictStore.delete(userId: userId)
            SyncBaseShadowStore.delete(userId: userId)
        }
        pendingConflictUserId = nil
        UserDefaults.standard.removeObject(forKey: lastSyncKey)
        UserDefaults.standard.removeObject(forKey: localSyncOwnerKey)
        // Scrub every per-user delta cursor / migration marker so a later
        // sign-in starts from a clean slate (mirrors the pre-delta
        // behaviour where there was no per-user state to leak).
        for key in UserDefaults.standard.dictionaryRepresentation().keys {
            if key.hasPrefix(deltaCursorKeyPrefix) || key.hasPrefix(deltaMigrationDoneKeyPrefix) {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
        status.lastSyncAt = nil
        status.errorMessage = nil
        status.pendingConflictCount = 0
    }

    func pendingConflicts() -> [SyncConflict] {
        guard let userId = authRepository.session?.localId else { return [] }
        pendingConflictUserId = userId
        return SyncConflictStore.load(userId: userId)
    }

    func resolveConflicts(_ resolutions: [SyncConflictResolution]) async throws {
        let session = try requireActiveSession(operation: "resolveConflicts")
        let conflicts = SyncConflictStore.load(userId: session.localId)
        guard !conflicts.isEmpty else { return }

        let local = try await persistence.exportData()
        let resolved = SyncThreeWayMergeEngine.applyResolutions(resolutions, to: local, conflicts: conflicts)
        try ensureNoProblemProgressLoss(from: local, to: resolved, operation: "resolveConflicts")
        try await applyMergedSnapshotLocally(resolved)

        let remaining = conflicts.filter { conflict in
            !resolutions.contains { $0.kind == conflict.kind && $0.syncId == conflict.syncId }
        }
        try SyncConflictStore.save(remaining, userId: session.localId)
        try? SyncBaseShadowStore.save(resolved, userId: session.localId)

        status.pendingConflictCount = remaining.count
        status.errorMessage = remaining.isEmpty ? nil : Self.pendingConflictsMessage

        try await syncNow()
    }

    func deleteCloudDataForCurrentUser() async throws {
        let session = try requireActiveSession(operation: "deleteCloudDataForCurrentUser")
        try beginSyncOperation(named: "deleteCloudDataForCurrentUser", session: session)
        logger.log(category: .sync, level: .warning, message: "Cloud account data deletion started")
        defer {
            endSyncOperation()
        }

        do {
            try await deltaStore.deleteAllUserData(userId: session.localId)
            await clearLocalSyncState()
            status = SyncStatus(isAuthenticated: true, email: session.email)
            logger.log(category: .sync, level: .warning, message: "Cloud account data deletion succeeded")
        } catch {
            let mapped = mapSyncFailure(error)
            status.errorMessage = mapped.localizedDescription
            logger.log(category: .sync, level: .error, message: "Cloud account data deletion failed", details: "uid=\(session.localId)", error: error)
            throw mapped
        }
    }

    // MARK: - Delta helpers

    private func deltaCursorKey(for userId: String) -> String {
        deltaCursorKeyPrefix + userId
    }

    private func deltaMigrationDoneKey(for userId: String) -> String {
        deltaMigrationDoneKeyPrefix + userId
    }

    private func loadCompositeDeltaCursor(userId: String) -> SyncDeltaCursor {
        let key = deltaCursorKey(for: userId)
        if let data = UserDefaults.standard.data(forKey: key),
           let cursor = try? JSONDecoder().decode(SyncDeltaCursor.self, from: data) {
            return cursor
        }
        let raw = UserDefaults.standard.object(forKey: key)
        if let number = raw as? NSNumber {
            return SyncDeltaCursor.fromLegacy(number.int64Value)
        }
        if let int64 = raw as? Int64 {
            return SyncDeltaCursor.fromLegacy(int64)
        }
        return .zero
    }

    private func saveCompositeDeltaCursor(userId: String, cursor: SyncDeltaCursor) {
        let key = deltaCursorKey(for: userId)
        if let data = try? JSONEncoder().encode(cursor) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func mergeStoredConflicts(userId: String, newlyDetected: [SyncConflict]) -> [SyncConflict] {
        var merged = Dictionary(uniqueKeysWithValues: SyncConflictStore.load(userId: userId).map { ($0.documentId, $0) })
        for conflict in newlyDetected {
            merged[conflict.documentId] = conflict
        }
        let conflicts = Array(merged.values)
        try? SyncConflictStore.save(conflicts, userId: userId)
        return conflicts
    }

    /// On the first sync for a given user, pull any legacy chunked-v2
    /// snapshot, materialise it as per-entity delta documents, then delete
    /// the legacy manifest + chunks. After this migration runs exactly
    /// once, all subsequent syncs use the delta collection only.
    private func migrateLegacyChunkedSnapshotIfNeeded(session: AuthSession) async throws {
        let doneKey = deltaMigrationDoneKey(for: session.localId)
        if UserDefaults.standard.bool(forKey: doneKey) {
            return
        }
        guard let legacyPayload = try await loadSnapshot(userId: session.localId) else {
            // Nothing to migrate; record that we looked so we don't
            // repeat this round-trip every sync.
            UserDefaults.standard.set(true, forKey: doneKey)
            return
        }
        logger.log(
            category: .sync,
            message: "Migrating legacy chunked snapshot to delta",
            details: "payloadBytes=\(legacyPayload.lengthOfBytes(using: .utf8))"
        )
        let remote = try await SyncPayloadCodec.decode(legacyPayload)
        try ensureRemoteCanMerge(remote)
        let envelopes = SyncDeltaSerializer.decompose(remote)
        if !envelopes.isEmpty {
            try await deltaStore.writeEnvelopes(envelopes, userId: session.localId)
        }
        try await deltaStore.clearLegacyChunkedSnapshot(userId: session.localId)
        // Keep cursor at zero so the very next sync still fetches the
        // envelopes we just wrote and merges them locally as well.
        saveCompositeDeltaCursor(userId: session.localId, cursor: .zero)
        UserDefaults.standard.set(true, forKey: doneKey)
        logger.log(
            category: .sync,
            message: "Legacy chunked snapshot migrated",
            details: "envelopes=\(envelopes.count)"
        )
    }

    /// Persists the merged snapshot into Core Data. We intentionally reuse
    /// the existing `importJSON` path so all of the import-time coherence
    /// logic (ID remapping, plan actual-minute recompute, problem progress
    /// preservation) runs exactly as in a manual import.
    private func applyMergedSnapshotLocally(_ merged: AppData) async throws {
        let payload = try await SyncPayloadCodec.encode(merged)
        let json = String(data: payload, encoding: .utf8) ?? "{}"
        let useCase = ExportImportDataUseCase(repository: persistence)
        _ = try await useCase.importJSON(json, currentPreferences: preferencesRepository.loadPreferences())
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

    private func requireActiveSession(operation: String) throws -> AuthSession {
        guard let session = authRepository.session else {
            logger.log(category: .sync, level: .warning, message: "\(operation) rejected", details: "reason=unauthenticated")
            throw ValidationError(message: Self.signInRequiredMessage)
        }
        guard currentFirebaseUserId() == session.localId else {
            logger.log(
                category: .sync,
                level: .warning,
                message: "\(operation) rejected",
                details: "reason=firebase-auth-session-mismatch"
            )
            status.isAuthenticated = false
            status.email = nil
            throw ValidationError(message: Self.signInRequiredMessage)
        }
        return session
    }

    private func mapSyncFailure(_ error: Error) -> Error {
        if isPermissionDenied(error) {
            return ValidationError(message: Self.firestorePermissionMessage)
        }
        if isAuthenticationExpired(error) {
            status.isAuthenticated = false
            status.email = nil
            return ValidationError(message: Self.authenticationExpiredMessage)
        }
        return error
    }

    private func isPermissionDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        return (nsError.code == 7 && nsError.domain.localizedCaseInsensitiveContains("firestore")) ||
            error.localizedDescription.localizedCaseInsensitiveContains("permission_denied") ||
            error.localizedDescription.localizedCaseInsensitiveContains("Missing or insufficient permissions")
    }

    private func isAuthenticationExpired(_ error: Error) -> Bool {
        let nsError = error as NSError
        let description = nsError.localizedDescription
        let isFirestoreUnauthenticated = nsError.code == 16 && nsError.domain.localizedCaseInsensitiveContains("firestore")
        let isFirebaseAuthCredentialFailure = nsError.domain.localizedCaseInsensitiveContains("auth") &&
            description.localizedCaseInsensitiveContains("auth credential")
        return isFirestoreUnauthenticated ||
            isFirebaseAuthCredentialFailure ||
            description.localizedCaseInsensitiveContains("supplied auth credential") ||
            description.localizedCaseInsensitiveContains("malformed or has expired") ||
            description.localizedCaseInsensitiveContains("unauthenticated")
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

private func makeSyncChunkId(for index: Int) -> String {
    String(format: "%06d", index)
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
