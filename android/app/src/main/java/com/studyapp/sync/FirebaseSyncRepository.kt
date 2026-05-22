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
    private val syncChangeNotifier: SyncChangeNotifier
) : SyncRepository {
    private val _status = MutableStateFlow(
        SyncStatus(
            isAuthenticated = authRepository.session.value != null,
            email = authRepository.session.value?.email,
            lastSyncAt = syncPreferences.getLastSyncAt()
        )
    )
    override val status: StateFlow<SyncStatus> = _status.asStateFlow()

    override suspend fun syncNow() {
        try {
            val session = requireSession()
            setSyncing(true)
            writeLock.withLock {
                migrateLegacyChunkedSnapshotIfNeeded(session.localId)

                var lastLocalChangeDuringSync: Throwable? = null
                repeat(MAX_SYNC_ATTEMPTS) { attempt ->
                    val local = exportLocalData()
                    val localBackupTime = System.currentTimeMillis()
                    syncPreferences.saveLocalBackup(local.toJson().toString(), localBackupTime, "before-syncNow")
                    ensureLocalSyncOwnership(session, local)

                    val localChangeToken = syncChangeNotifier.localChangeGeneration
                    val cursor = syncPreferences.getDeltaCursor(session.localId)
                    val remoteEnvelopes = deltaStore.fetchEnvelopes(session.localId, cursor)
                    val merged = if (remoteEnvelopes.isEmpty()) {
                        local
                    } else {
                        SyncDeltaSerializer.assemble(remoteEnvelopes, onto = local)
                    }
                    val now = System.currentTimeMillis()
                    val synced = SyncMergeEngine.markSynced(merged, now)
                    ensureNoProblemProgressLoss(local, synced, "syncNow")

                    val outboundEnvelopes = SyncDeltaSerializer.changedSince(synced, cursor)
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

                    val newCursor = maxOf(
                        synced.exportDate,
                        SyncDeltaSerializer.decompose(synced).maxOfOrNull { it.updatedAt } ?: cursor
                    )
                    syncPreferences.setDeltaCursor(session.localId, newCursor)
                    syncPreferences.setLastSyncAt(now)
                    syncPreferences.setLocalSyncOwnerUserId(session.localId)
                    syncChangeNotifier.recordManualSyncApplied()
                    _status.value = SyncStatus(true, session.email, false, now, null)

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
                repeat(MAX_SYNC_ATTEMPTS) { attempt ->
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
                    val envelopes = SyncDeltaSerializer.decompose(stampedLocal)
                    val localChangeToken = syncChangeNotifier.localChangeGeneration

                    if (syncChangeNotifier.localChangeGeneration != localChangeToken) {
                        lastLocalChangeDuringSync = IllegalStateException(LOCAL_CHANGE_DURING_SYNC_MESSAGE)
                        return@repeat
                    }

                    deltaStore.writeEnvelopes(envelopes, session.localId)
                    val newCursor = envelopes.maxOfOrNull { it.updatedAt } ?: now
                    syncPreferences.setDeltaCursor(session.localId, newCursor)
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
        syncPreferences.clearLocalSyncState()
        _status.value = _status.value.copy(lastSyncAt = null, errorMessage = null)
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
    }
}
