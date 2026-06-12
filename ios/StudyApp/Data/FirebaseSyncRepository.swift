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
    private var lastLoadedVersion: Int64 = 0
    private var cancellables = Set<AnyCancellable>()

    private static let maxSyncRetries = 3
    private static let syncSchemaVersion = AppData.currentSchemaVersion
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
                var stateError: String?
                if let userId = session?.localId {
                    do {
                        self.status.lastSyncAt = try self.loadSyncState(userId: userId).user.lastSyncAt
                    } catch {
                        self.status.lastSyncAt = nil
                        stateError = error.localizedDescription
                        self.logger.log(category: .sync, level: .error, message: "Failed to load sync state", error: error)
                    }
                } else {
                    self.status.lastSyncAt = nil
                }
                self.status.pendingConflictCount = conflictCount
                self.status.errorMessage = conflictCount > 0 ? Self.pendingConflictsMessage : stateError
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
                _ = try await persistence.createDataBackupIfNeeded(
                    reason: "before-syncNow",
                    minimumInterval: DataBackupStore.syncBackupInterval
                )

                var stateResult = try loadSyncState(userId: session.localId)
                if !stateResult.user.serverCursorMigrationDone {
                    stateResult.user.cursor = .zero
                    stateResult.user.serverCursor = .zero
                    stateResult.user.serverCursorMigrationDone = true
                    stateResult.root.users[session.localId] = stateResult.user
                    try SyncStateStore.save(stateResult.root)
                    recordClientFlags(
                        ["serverUpdatedAtCursorMigrated": true],
                        userId: session.localId
                    )
                }
                try ensureLocalSyncOwnership(
                    session: session,
                    local: local,
                    ownerUserId: stateResult.root.ownerUserId
                )
                let outboundComparisonBase = stateResult.user.baseShadow
                if stateResult.user.baseShadow == nil {
                    stateResult.user.cursor = .zero
                    stateResult.user.revisions = [:]
                    stateResult.user.baseShadow = local
                    stateResult.root.users[session.localId] = stateResult.user
                    try SyncStateStore.save(stateResult.root)
                }

                let localChangeToken = persistence.changeToken
                let cursor = stateResult.user.cursor
                let serverCursor = stateResult.user.serverCursor
                let baseShadow = stateResult.user.baseShadow

                let fetchResult = try await deltaStore.fetchEnvelopes(
                    userId: session.localId,
                    changedSince: serverCursor
                )
                let remoteEnvelopes = fetchResult.envelopes

                let syncedAt = Date().epochMilliseconds
                let mergeOutcome = try await MergeExecutor.apply(
                    envelopes: remoteEnvelopes,
                    onto: local,
                    baseShadow: baseShadow,
                    syncedAt: syncedAt
                )
                let merged = mergeOutcome.merged
                try ensureNoProblemProgressLoss(from: local, to: merged, operation: "syncNow")

                let storedConflicts = try mergeStoredConflicts(
                    userId: session.localId,
                    newlyDetected: mergeOutcome.conflicts
                )
                pendingConflictUserId = session.localId

                let locallyChangedIds = Set(
                    SyncDeltaSerializer.changedComparedTo(local, base: outboundComparisonBase).map(\.documentId)
                )
                var outboundEnvelopes = SyncDeltaSerializer.decompose(merged)
                    .filter { locallyChangedIds.contains($0.documentId) }
                let previousRevisions = stateResult.user.revisions
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
                    details: "attempt=\(attempt + 1) serverCursor=\(serverCursor.seconds).\(serverCursor.nanoseconds) cursorDoc=\(serverCursor.documentId) inbound=\(remoteEnvelopes.count) outbound=\(outboundEnvelopes.count) conflicts=\(storedConflicts.count) legacyFallback=\(mergeOutcome.usedLegacyTwoWayFallback)"
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
                do {
                    try await applyMergedSnapshotLocally(
                        merged,
                        expectedChangeToken: localChangeToken
                    )
                } catch PersistenceController.SyncApplyError.localDataChanged {
                    logger.log(
                        category: .sync,
                        level: .warning,
                        message: "Local change detected at sync apply boundary",
                        details: "attempt=\(attempt + 1)"
                    )
                    continue
                }

                if !outboundEnvelopes.isEmpty {
                    try await deltaStore.writeEnvelopes(outboundEnvelopes, userId: session.localId)
                }

                let resolvedMergedEnvelopes = SyncDeltaSerializer.decompose(merged)
                    .filter { !unresolvedConflictIds.contains($0.documentId) }
                let resolvedRemoteEnvelopes = remoteEnvelopes
                    .filter { !unresolvedConflictIds.contains($0.documentId) }
                var newCursor = cursor
                for envelope in outboundEnvelopes {
                    newCursor.absorb(envelope)
                }
                let nextBase: AppData
                if unresolvedConflictIds.isEmpty {
                    nextBase = merged
                } else {
                    nextBase = SyncDeltaSerializer.assemble(
                        envelopes: resolvedMergedEnvelopes,
                        onto: baseShadow ?? local
                    )
                }
                stateResult.user.cursor = newCursor
                stateResult.user.serverCursor = fetchResult.cursor
                stateResult.user.baseShadow = nextBase
                stateResult.user.revisions = SyncStateStore.mergedRevisions(
                    current: stateResult.user.revisions,
                    envelopes: resolvedRemoteEnvelopes + outboundEnvelopes
                )
                stateResult.user.lastSyncAt = merged.exportDate
                stateResult.root.ownerUserId = session.localId
                stateResult.root.users[session.localId] = stateResult.user
                try SyncStateStore.save(stateResult.root)
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
                    details: "attempt=\(attempt + 1) lastSyncAt=\(merged.exportDate) serverCursor=\(fetchResult.cursor.seconds).\(fetchResult.cursor.nanoseconds) cursorDoc=\(fetchResult.cursor.documentId)"
                )
                if mergeOutcome.usedLegacyTwoWayFallback {
                    recordClientFlags(
                        ["usedLegacyTwoWayFallback": true],
                        userId: session.localId
                    )
                }
                if persistence.didBackfillSyncMetadataDuringPreparation {
                    recordClientFlags(
                        ["backfilledSyncMetadata": true],
                        userId: session.localId
                    )
                }
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
                _ = try await persistence.createDataBackup(reason: "before-importLocalDataToCloud")
                var stateResult = try loadSyncState(userId: session.localId)
                if !stateResult.user.serverCursorMigrationDone {
                    stateResult.user.cursor = .zero
                    stateResult.user.serverCursor = .zero
                    stateResult.user.serverCursorMigrationDone = true
                    stateResult.root.users[session.localId] = stateResult.user
                    try SyncStateStore.save(stateResult.root)
                }
                try ensureLocalSyncOwnership(
                    session: session,
                    local: localData,
                    ownerUserId: stateResult.root.ownerUserId
                )

                // Defend against destructive uploads: if the cloud already
                // has progress we don't, bail out and force the user to
                // pull first.
                let cursor = stateResult.user.cursor
                let fetchResult = try await deltaStore.fetchEnvelopes(
                    userId: session.localId,
                    changedSince: stateResult.user.serverCursor
                )
                let remoteEnvelopes = fetchResult.envelopes
                if !remoteEnvelopes.isEmpty {
                    let remoteApp = SyncDeltaSerializer.assemble(envelopes: remoteEnvelopes, onto: localData)
                    try ensureNoProblemProgressLoss(from: remoteApp, to: localData, operation: "importLocalDataToCloud")
                }

                let nowMs = Date().epochMilliseconds
                let stampedLocal = SyncMergeEngine.markSynced(localData, at: nowMs)
                let baseShadow = stateResult.user.baseShadow
                var envelopes = SyncDeltaSerializer.decompose(stampedLocal)
                envelopes = SyncRevisionStamper.stamp(
                    envelopes,
                    previousBase: baseShadow,
                    previousRevisions: stateResult.user.revisions
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
                stateResult.user.cursor = newCursor
                stateResult.user.serverCursor = fetchResult.cursor
                stateResult.user.baseShadow = stampedLocal
                stateResult.user.revisions = SyncStateStore.mergedRevisions(
                    current: stateResult.user.revisions,
                    envelopes: envelopes
                )
                stateResult.user.lastSyncAt = nowMs
                stateResult.root.ownerUserId = session.localId
                stateResult.root.users[session.localId] = stateResult.user
                try SyncStateStore.save(stateResult.root)
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
        }
        pendingConflictUserId = nil
        do {
            try SyncStateStore.clear()
            status.errorMessage = nil
        } catch {
            status.errorMessage = error.localizedDescription
            logger.log(category: .sync, level: .error, message: "Failed to clear local sync state", error: error)
        }
        status.lastSyncAt = nil
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
        try await applyMergedSnapshotLocally(
            resolved,
            expectedChangeToken: persistence.changeToken
        )

        let remaining = conflicts.filter { conflict in
            !resolutions.contains { $0.kind == conflict.kind && $0.syncId == conflict.syncId }
        }
        try SyncConflictStore.save(remaining, userId: session.localId)
        var stateResult = try loadSyncState(userId: session.localId)
        stateResult.user.baseShadow = resolved
        stateResult.root.users[session.localId] = stateResult.user
        try SyncStateStore.save(stateResult.root)

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

    private func mergeStoredConflicts(userId: String, newlyDetected: [SyncConflict]) throws -> [SyncConflict] {
        var merged = Dictionary(uniqueKeysWithValues: SyncConflictStore.load(userId: userId).map { ($0.documentId, $0) })
        for conflict in newlyDetected {
            merged[conflict.documentId] = conflict
        }
        let conflicts = Array(merged.values)
        try SyncConflictStore.save(conflicts, userId: userId)
        return conflicts
    }

    /// On the first sync for a given user, pull any legacy chunked-v2
    /// snapshot, materialise it as per-entity delta documents, then delete
    /// the legacy manifest + chunks. After this migration runs exactly
    /// once, all subsequent syncs use the delta collection only.
    private func migrateLegacyChunkedSnapshotIfNeeded(session: AuthSession) async throws {
        var stateResult = try loadSyncState(userId: session.localId)
        if stateResult.user.legacyMigrationDone {
            return
        }
        guard let legacyPayload = try await loadSnapshot(userId: session.localId) else {
            stateResult.user.legacyMigrationDone = true
            stateResult.root.users[session.localId] = stateResult.user
            try SyncStateStore.save(stateResult.root)
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
        stateResult.user.cursor = .zero
        stateResult.user.legacyMigrationDone = true
        stateResult.root.users[session.localId] = stateResult.user
        try SyncStateStore.save(stateResult.root)
        logger.log(
            category: .sync,
            message: "Legacy chunked snapshot migrated",
            details: "envelopes=\(envelopes.count)"
        )
        recordClientFlags(
            ["migratedLegacyChunkedSnapshot": true],
            userId: session.localId
        )
    }

    private func applyMergedSnapshotLocally(
        _ merged: AppData,
        expectedChangeToken: Int64
    ) async throws {
        try await persistence.applySyncedData(
            merged,
            expectedChangeToken: expectedChangeToken
        )
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

    private func loadSyncState(userId: String) throws -> SyncStateLoadResult {
        let result = try SyncStateStore.load(userId: userId)
        if result.migratedLegacyState {
            logger.log(category: .sync, message: "Migrated legacy local sync state")
        }
        if result.repairedInconsistentState {
            logger.log(
                category: .sync,
                level: .warning,
                message: "Reset inconsistent sync state",
                details: "action=full-resync"
            )
        }
        return result
    }

    private func recordClientFlags(_ flags: [String: Any], userId: String) {
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.deltaStore.recordClientFlags(flags, userId: userId)
            } catch {
                self.logger.log(
                    category: .sync,
                    level: .warning,
                    message: "Failed to record sync client flags",
                    error: error
                )
            }
        }
    }

    private func ensureLocalSyncOwnership(
        session: AuthSession,
        local: AppData,
        ownerUserId: String?
    ) throws {
        if ownerUserId == nil || ownerUserId == session.localId || local.isEmpty {
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

extension AppData {
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

private struct SyncDataSummary: Equatable {
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

    var hasProblemProgress: Bool {
        sessionProblemRecords > 0 ||
        materialProblemRecords > 0 ||
        activeProblemReviewRecords > 0 ||
        materialsWithProblemTotals > 0
    }

    var logDescription: String {
        "subjects=\(subjects) materials=\(materials) sessions=\(sessions) sessionProblemRecords=\(sessionProblemRecords) materialProblemRecords=\(materialProblemRecords) problemReviewRecords=\(problemReviewRecords) activeProblemReviewRecords=\(activeProblemReviewRecords) materialsWithProblemTotals=\(materialsWithProblemTotals)"
    }
}
