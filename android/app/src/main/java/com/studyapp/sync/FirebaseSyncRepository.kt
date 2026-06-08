package com.studyapp.sync

import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.ExportImportDataUseCase
import com.studyapp.domain.util.Result
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await
import org.json.JSONObject

@Singleton
class FirebaseSyncRepository @Inject constructor(
    private val authRepository: AuthRepository,
    private val firebaseAuth: FirebaseAuth,
    private val firebaseFirestore: FirebaseFirestore,
    private val syncPreferences: SyncPreferences,
    private val exportImportDataUseCase: ExportImportDataUseCase,
    private val writeLock: AppDataWriteLock,
    private val deltaStore: FirestoreDeltaSyncStore,
    private val syncChangeNotifier: SyncChangeNotifier,
    private val baseShadowStore: SyncBaseShadowStore,
    private val conflictStore: SyncConflictStore,
    private val revisionStamper: SyncRevisionStamper
) : SyncRepository {
    private var pendingConflictUserId: String? = null
    private val _status = MutableStateFlow(
        initialStatus()
    )
    override val status: StateFlow<SyncStatus> = _status.asStateFlow()

    override suspend fun syncNow() {
        try {
            val session = requireSession()
            setSyncing(true)
            writeLock.withLock {
                migrateLegacyChunkedSnapshotIfNeeded(session.localId)

                var lastLocalChangeDuringSync: Throwable? = null
                repeat(MAX_SYNC_ATTEMPTS) {
                    val local = exportLocalData()
                    val localBackupTime = System.currentTimeMillis()
                    syncPreferences.saveLocalBackup(local.toJson().toString(), localBackupTime, "before-syncNow")
                    ensureLocalSyncOwnership(session, local)

                    val localChangeToken = syncChangeNotifier.localChangeGeneration
                    val cursor = syncPreferences.getDeltaCursor(session.localId)
                    baseShadowStore.bootstrapIfNeeded(session.localId, local)
                    val baseShadow = baseShadowStore.load(session.localId)
                    val remoteEnvelopes = deltaStore.fetchEnvelopes(session.localId, cursor)
                    val now = System.currentTimeMillis()
                    val mergeOutcome = SyncThreeWayMergeEngine.merge(
                        base = baseShadow,
                        local = local,
                        remoteEnvelopes = remoteEnvelopes,
                        now = now
                    )
                    val synced = SyncMergeEngine.markSynced(mergeOutcome.merged, now)
                    ensureNoProblemProgressLoss(local, synced, "syncNow")

                    val storedConflicts = mergeStoredConflicts(session.localId, mergeOutcome.conflicts)
                    pendingConflictUserId = session.localId

                    var outboundEnvelopes = SyncDeltaSerializer.changedSince(synced, cursor)
                    val previousRevisions = baseShadowStore.loadRevisionMap(session.localId)
                    outboundEnvelopes = revisionStamper.stamp(outboundEnvelopes, baseShadow, previousRevisions)
                    val unresolvedConflictIds = storedConflicts.map { it.documentId }.toSet()
                    if (unresolvedConflictIds.isNotEmpty()) {
                        outboundEnvelopes = outboundEnvelopes.filterNot { it.documentId in unresolvedConflictIds }
                    }
                    if (syncChangeNotifier.localChangeGeneration != localChangeToken) {
                        lastLocalChangeDuringSync = IllegalStateException(LOCAL_CHANGE_DURING_SYNC_MESSAGE)
                        return@repeat
                    }

                    when (val result = exportImportDataUseCase.importFromJsonWithoutWriteLock(synced.toJson().toString())) {
                        is Result.Error -> throw result.exception
                        is Result.Success -> Unit
                    }

                    if (outboundEnvelopes.isNotEmpty()) {
                        deltaStore.writeEnvelopes(outboundEnvelopes, session.localId)
                    }

                    val resolvedMergedEnvelopes = SyncDeltaSerializer.decompose(synced)
                        .filterNot { it.documentId in unresolvedConflictIds }
                    val resolvedRemoteEnvelopes = remoteEnvelopes
                        .filterNot { it.documentId in unresolvedConflictIds }
                    var newCursor = cursor
                    (resolvedRemoteEnvelopes + resolvedMergedEnvelopes + outboundEnvelopes).forEach { envelope ->
                        newCursor = newCursor.absorb(envelope)
                    }
                    syncPreferences.setDeltaCursor(session.localId, newCursor)
                    baseShadowStore.save(
                        if (unresolvedConflictIds.isEmpty()) {
                            synced
                        } else {
                            SyncDeltaSerializer.assemble(resolvedMergedEnvelopes, onto = baseShadow ?: local)
                        },
                        session.localId
                    )
                    baseShadowStore.mergeRevisionMap(session.localId, resolvedRemoteEnvelopes + outboundEnvelopes)
                    syncPreferences.setLastSyncAt(now)
                    syncPreferences.setLocalSyncOwnerUserId(session.localId)
                    syncChangeNotifier.recordManualSyncApplied()
                    _status.value = SyncStatus(
                        isAuthenticated = true,
                        email = session.email,
                        isSyncing = false,
                        lastSyncAt = now,
                        errorMessage = if (storedConflicts.isEmpty()) null else PENDING_CONFLICTS_MESSAGE,
                        pendingConflictCount = storedConflicts.size
                    )

                    runCatching {
                        deltaStore.purgeTombstonesOlderThan(TOMBSTONE_RETENTION_MILLIS, now, session.localId)
                    }
                    return@withLock
                }

                throw lastLocalChangeDuringSync ?: IllegalStateException(LOCAL_CHANGE_DURING_SYNC_MESSAGE)
            }
        } catch (t: Throwable) {
            val mapped = mapSyncFailure(t)
            _status.value = _status.value.copy(isSyncing = false, errorMessage = mapped.message)
            throw mapped
        }
    }

    override suspend fun importLocalDataToCloud() {
        try {
            val session = requireSession()
            setSyncing(true)
            writeLock.withLock {
                migrateLegacyChunkedSnapshotIfNeeded(session.localId)

                var lastLocalChangeDuringSync: Throwable? = null
                repeat(MAX_SYNC_ATTEMPTS) {
                    val local = exportLocalData()
                    val localBackupTime = System.currentTimeMillis()
                    syncPreferences.saveLocalBackup(local.toJson().toString(), localBackupTime, "before-importLocalDataToCloud")
                    ensureLocalSyncOwnership(session, local)

                    val cursor = syncPreferences.getDeltaCursor(session.localId)
                    val remoteEnvelopes = deltaStore.fetchEnvelopes(session.localId, cursor)
                    if (remoteEnvelopes.isNotEmpty()) {
                        val remoteApp = SyncDeltaSerializer.assemble(remoteEnvelopes, onto = local)
                        ensureNoProblemProgressLoss(remoteApp, local, "importLocalDataToCloud")
                    }

                    val now = System.currentTimeMillis()
                    val stampedLocal = SyncMergeEngine.markSynced(local, now)
                    val baseShadow = baseShadowStore.load(session.localId)
                    var envelopes = SyncDeltaSerializer.decompose(stampedLocal)
                    envelopes = revisionStamper.stamp(
                        envelopes,
                        baseShadow,
                        baseShadowStore.loadRevisionMap(session.localId)
                    )
                    val localChangeToken = syncChangeNotifier.localChangeGeneration

                    if (syncChangeNotifier.localChangeGeneration != localChangeToken) {
                        lastLocalChangeDuringSync = IllegalStateException(LOCAL_CHANGE_DURING_SYNC_MESSAGE)
                        return@repeat
                    }

                    deltaStore.writeEnvelopes(envelopes, session.localId)
                    var newCursor = cursor
                    envelopes.forEach { envelope -> newCursor = newCursor.absorb(envelope) }
                    syncPreferences.setDeltaCursor(session.localId, newCursor)
                    baseShadowStore.save(stampedLocal, session.localId)
                    baseShadowStore.mergeRevisionMap(session.localId, envelopes)
                    syncPreferences.setLastSyncAt(now)
                    syncPreferences.setLocalSyncOwnerUserId(session.localId)
                    syncChangeNotifier.recordManualSyncApplied()
                    _status.value = SyncStatus(true, session.email, false, now, null)
                    return@withLock
                }

                throw lastLocalChangeDuringSync ?: IllegalStateException(LOCAL_CHANGE_DURING_SYNC_MESSAGE)
            }
        } catch (t: Throwable) {
            val mapped = mapSyncFailure(t)
            _status.value = _status.value.copy(isSyncing = false, errorMessage = mapped.message)
            throw mapped
        }
    }

    override suspend fun deleteCloudDataForCurrentUser() {
        val session = requireSession()
        setSyncing(true)
        try {
            deltaStore.deleteAllUserData(session.localId)
            deleteAllSyncSnapshots(session.localId)
            clearLocalSyncState()
            _status.value = SyncStatus(isAuthenticated = true, email = session.email, isSyncing = false, lastSyncAt = null, errorMessage = null)
        } catch (t: Throwable) {
            val mapped = mapSyncFailure(t)
            _status.value = _status.value.copy(isSyncing = false, errorMessage = mapped.message)
            throw mapped
        }
    }

    override suspend fun clearLocalSyncState() {
        val userId = authRepository.session.value?.localId
        if (userId != null) {
            conflictStore.delete(userId)
            baseShadowStore.delete(userId)
        }
        pendingConflictUserId = null
        syncPreferences.clearLocalSyncState()
        _status.value = _status.value.copy(lastSyncAt = null, errorMessage = null, pendingConflictCount = 0)
    }

    override fun pendingConflicts(): List<SyncConflict> {
        val userId = authRepository.session.value?.localId ?: return emptyList()
        pendingConflictUserId = userId
        return conflictStore.load(userId)
    }

    override suspend fun resolveConflicts(resolutions: List<SyncConflictResolution>) {
        val session = requireSession()
        setSyncing(true)
        try {
            writeLock.withLock {
                val conflicts = conflictStore.load(session.localId)
                if (conflicts.isEmpty()) return@withLock

                val local = exportLocalData()
                val resolved = SyncThreeWayMergeEngine.applyResolutions(resolutions, local, conflicts)
                ensureNoProblemProgressLoss(local, resolved, "resolveConflicts")

                when (val result = exportImportDataUseCase.importFromJsonWithoutWriteLock(resolved.toJson().toString())) {
                    is Result.Error -> throw result.exception
                    is Result.Success -> Unit
                }

                val remaining = conflicts.filter { conflict ->
                    resolutions.none { it.kind == conflict.kind && it.syncId == conflict.syncId }
                }
                conflictStore.save(remaining, session.localId)
                baseShadowStore.save(resolved, session.localId)
                pendingConflictUserId = session.localId
                _status.value = _status.value.copy(
                    pendingConflictCount = remaining.size,
                    errorMessage = if (remaining.isEmpty()) null else PENDING_CONFLICTS_MESSAGE
                )
            }
            syncNow()
        } catch (t: Throwable) {
            val mapped = mapSyncFailure(t)
            _status.value = _status.value.copy(isSyncing = false, errorMessage = mapped.message)
            throw mapped
        }
    }

    private fun mergeStoredConflicts(userId: String, newlyDetected: List<SyncConflict>): List<SyncConflict> {
        val merged = conflictStore.load(userId).associateBy { it.documentId }.toMutableMap()
        newlyDetected.forEach { conflict ->
            merged[conflict.documentId] = conflict
        }
        return merged.values.toList().also { conflictStore.save(it, userId) }
    }

    private fun initialStatus(): SyncStatus {
        val session = authRepository.session.value
        val conflictCount = session?.localId?.let { userId ->
            pendingConflictUserId = userId
            conflictStore.load(userId).size
        } ?: 0
        return SyncStatus(
            isAuthenticated = session != null,
            email = session?.email,
            lastSyncAt = syncPreferences.getLastSyncAt(),
            errorMessage = if (conflictCount > 0) PENDING_CONFLICTS_MESSAGE else null,
            pendingConflictCount = conflictCount
        )
    }

    private suspend fun migrateLegacyChunkedSnapshotIfNeeded(userId: String) {
        if (syncPreferences.isDeltaMigrationDone(userId)) return

        val legacyPayload = loadLegacySnapshotPayload(userId) ?: run {
            syncPreferences.setDeltaMigrationDone(userId, true)
            return
        }

        val remote = AppData.fromJson(JSONObject(legacyPayload))
        val envelopes = SyncDeltaSerializer.decompose(remote)
        if (envelopes.isNotEmpty()) {
            deltaStore.writeEnvelopes(envelopes, userId)
        }
        deltaStore.clearLegacyChunkedSnapshot(userId)
        syncPreferences.setDeltaCursor(userId, 0L)
        syncPreferences.setDeltaMigrationDone(userId, true)
    }

    private suspend fun loadLegacySnapshotPayload(userId: String): String? {
        val manifest = firebaseFirestore
            .collection("users")
            .document(userId)
            .collection("sync")
            .document("default")
            .get()
            .await()
        if (!manifest.exists()) return null

        val legacyPayload = manifest.getString("payload")
        if (legacyPayload != null) return legacyPayload

        val chunkCount = (manifest.getLong("chunkCount") ?: 0L).toInt()
        if (chunkCount == 0) return null

        val version = manifest.getLong("version") ?: 0L
        return buildString {
            for (index in 0 until chunkCount) {
                val chunkSnapshot = firebaseFirestore
                    .collection("users")
                    .document(userId)
                    .collection("sync")
                    .document("default")
                    .collection("chunks")
                    .document(chunkId(index))
                    .get()
                    .await()
                val chunkVersion = chunkSnapshot.getLong("version")
                    ?: error("Missing snapshot chunk version for ${chunkId(index)}")
                check(chunkVersion == version) {
                    "Snapshot chunk version mismatch for ${chunkId(index)}"
                }
                append(
                    chunkSnapshot.getString("payloadPart")
                        ?: error("Missing snapshot chunk payload for ${chunkId(index)}")
                )
            }
        }
    }

    private suspend fun deleteAllSyncSnapshots(userId: String) {
        val snapshots = firebaseFirestore
            .collection("users")
            .document(userId)
            .collection("sync_snapshots")
            .get()
            .await()
        snapshots.documents.forEach { snapshot ->
            deleteAllDocumentsInCollection(snapshot.reference.collection("chunks"))
            snapshot.reference.delete().await()
        }
    }

    private suspend fun deleteAllDocumentsInCollection(
        collection: com.google.firebase.firestore.CollectionReference
    ) {
        while (true) {
            val page = collection.limit(DELETE_BATCH_SIZE).get().await()
            if (page.isEmpty) return
            var batch = firebaseFirestore.batch()
            var writeCount = 0
            page.documents.forEach { document ->
                batch.delete(document.reference)
                writeCount += 1
                if (writeCount >= DELETE_BATCH_SIZE) {
                    batch.commit().await()
                    batch = firebaseFirestore.batch()
                    writeCount = 0
                }
            }
            if (writeCount > 0) {
                batch.commit().await()
            }
        }
    }

    private suspend fun exportLocalData(): AppData {
        return exportImportDataUseCase.exportAppDataWithoutWriteLock()
    }

    private fun ensureNoProblemProgressLoss(source: AppData, destination: AppData, operation: String) {
        if (!SyncProgressGuard.wouldLoseProgress(source, destination)) return
        val before = SyncProgressSummary(source)
        val after = SyncProgressSummary(destination)
        throw IllegalStateException(
            "$DESTRUCTIVE_SYNC_MESSAGE operation=$operation before=${before.logDescription()} after=${after.logDescription()}"
        )
    }

    private fun ensureLocalSyncOwnership(session: AuthSession, localData: AppData) {
        val localSyncOwnerUserId = syncPreferences.getLocalSyncOwnerUserId()
        if (localSyncOwnerUserId == null || localSyncOwnerUserId == session.localId || localData.isEmpty()) {
            return
        }
        throw IllegalStateException(ACCOUNT_SWITCH_MESSAGE)
    }

    private fun requireSession(): AuthSession {
        check(firebaseAuth.currentUser != null) { SIGN_IN_REQUIRED_MESSAGE }
        val session = authRepository.session.value ?: error(SIGN_IN_REQUIRED_MESSAGE)
        _status.value = _status.value.copy(isAuthenticated = true, email = session.email)
        return session
    }

    private fun setSyncing(isSyncing: Boolean) {
        _status.value = _status.value.copy(
            isAuthenticated = authRepository.session.value != null,
            email = authRepository.session.value?.email,
            isSyncing = isSyncing,
            errorMessage = null
        )
    }

    private fun mapSyncFailure(throwable: Throwable): Throwable {
        return when {
            isSignInRequired(throwable) -> IllegalStateException(SIGN_IN_REQUIRED_MESSAGE, throwable)
            isPermissionDenied(throwable) -> {
                IllegalStateException(
                    "クラウド同期に失敗しました。Firestoreルールが未反映か、このアカウントに十分な権限がありません。",
                    throwable
                )
            }
            else -> throwable
        }
    }

    private fun isSignInRequired(throwable: Throwable): Boolean {
        return throwable.message == SIGN_IN_REQUIRED_MESSAGE ||
            throwable.message == "Sign in is required before syncing."
    }

    private fun isPermissionDenied(throwable: Throwable): Boolean {
        var current: Throwable? = throwable
        while (current != null) {
            val message = current.message.orEmpty()
            if (
                message.contains("PERMISSION_DENIED", ignoreCase = true) ||
                message.contains("Missing or insufficient permissions", ignoreCase = true)
            ) {
                return true
            }
            current = current.cause
        }
        return false
    }

    private fun chunkId(index: Int): String = index.toString().padStart(6, '0')

    private fun AppData.isEmpty(): Boolean {
        return subjects.isEmpty() &&
            materials.isEmpty() &&
            sessions.isEmpty() &&
            goals.isEmpty() &&
            exams.isEmpty() &&
            plans.isEmpty() &&
            timetablePeriods.isEmpty() &&
            timetableEntries.isEmpty() &&
            timetableTerms.isEmpty() &&
            timetableReviewRecords.isEmpty() &&
            problemReviewRecords.isEmpty()
    }

    private companion object {
        const val DELETE_BATCH_SIZE = 450L
        const val MAX_SYNC_ATTEMPTS = 3
        const val TOMBSTONE_RETENTION_MILLIS = 90L * 24L * 60L * 60L * 1000L
        const val ACCOUNT_SWITCH_MESSAGE =
            "この端末のローカルデータは別の同期アカウントに紐づいています。全データを削除してから再度同期してください。"
        const val DESTRUCTIVE_SYNC_MESSAGE =
            "同期により問題集の進捗履歴が大きく減少するため停止しました。自動バックアップを確認してください。"
        const val SIGN_IN_REQUIRED_MESSAGE = "同期するには先にサインインしてください。"
        const val LOCAL_CHANGE_DURING_SYNC_MESSAGE = "同期中にローカルデータが更新されました。もう一度お試しください。"
        const val PENDING_CONFLICTS_MESSAGE =
            "同期データに解決が必要な競合があります。設定の「競合を解決」から選択してください。"
    }
}
