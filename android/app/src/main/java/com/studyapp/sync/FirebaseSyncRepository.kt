package com.studyapp.sync

import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.ExportImportDataUseCase
import com.studyapp.domain.usecase.PlanData
import com.studyapp.domain.util.Result
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Transaction
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
    private val writeLock: AppDataWriteLock
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
                var lastConflict: Throwable? = null
                repeat(MAX_SYNC_ATTEMPTS) { attempt ->
                    val local = exportLocalData()
                    ensureLocalSyncOwnership(session, local)
                    val remoteSnapshot = loadSnapshot(session.localId)
                    val merged = remoteSnapshot.payload?.let { remotePayload ->
                        merge(local, AppData.fromJson(JSONObject(remotePayload)))
                    } ?: local
                    val now = System.currentTimeMillis()
                    val payload = markSynced(merged, now).toJson().toString()

                    try {
                        saveSnapshot(
                            userId = session.localId,
                            payload = payload,
                            updatedAt = now,
                            expectedVersion = remoteSnapshot.version
                        )
                        when (val result = exportImportDataUseCase.importFromJsonWithoutWriteLock(payload)) {
                            is Result.Error -> throw result.exception
                            is Result.Success -> Unit
                        }
                        syncPreferences.setLastSyncAt(now)
                        syncPreferences.setLocalSyncOwnerUserId(session.localId)
                        _status.value = SyncStatus(true, session.email, false, now, null)
                        return@withLock
                    } catch (t: Throwable) {
                        if (isConcurrentSnapshotUpdate(t) && attempt < MAX_SYNC_ATTEMPTS - 1) {
                            lastConflict = t
                            return@repeat
                        }
                        throw t
                    }
                }

                throw lastConflict ?: IllegalStateException("Sync failed after repeated remote conflicts.")
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
                val local = exportLocalData()
                ensureLocalSyncOwnership(session, local)
                val remoteSnapshot = loadSnapshot(session.localId)
                val now = System.currentTimeMillis()
                val payload = markSynced(local, now).toJson().toString()
                saveSnapshot(
                    userId = session.localId,
                    payload = payload,
                    updatedAt = now,
                    expectedVersion = remoteSnapshot.version
                )
                when (val result = exportImportDataUseCase.importFromJsonWithoutWriteLock(payload)) {
                    is Result.Error -> throw result.exception
                    is Result.Success -> Unit
                }
                syncPreferences.setLastSyncAt(now)
                syncPreferences.setLocalSyncOwnerUserId(session.localId)
                _status.value = SyncStatus(true, session.email, false, now, null)
            }
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

    private suspend fun exportLocalData(): AppData {
        return exportImportDataUseCase.exportAppDataWithoutWriteLock()
    }

    private suspend fun loadSnapshot(userId: String): RemoteSnapshot {
        val manifest = manifestDocument(userId).get().await()
        if (!manifest.exists()) {
            return RemoteSnapshot()
        }

        val version = manifest.getLong("version") ?: 0L
        val legacyPayload = manifest.getString("payload")
        if (legacyPayload != null) {
            return RemoteSnapshot(payload = legacyPayload, version = version)
        }

        val chunkCount = (manifest.getLong("chunkCount") ?: 0L).toInt()
        if (chunkCount == 0) {
            return RemoteSnapshot(payload = null, version = version, chunkCount = 0)
        }

        val payload = buildString {
            for (index in 0 until chunkCount) {
                val chunkSnapshot = chunkDocument(userId, index).get().await()
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

        return RemoteSnapshot(payload = payload, version = version, chunkCount = chunkCount)
    }

    private suspend fun saveSnapshot(
        userId: String,
        payload: String,
        updatedAt: Long,
        expectedVersion: Long
    ): Long {
        val manifestRef = manifestDocument(userId)
        val chunks = splitPayloadIntoChunks(payload)

        return firebaseFirestore.runTransaction { transaction ->
            val manifestSnapshot = transaction.get(manifestRef)
            val currentVersion = manifestSnapshot.getLong("version") ?: 0L
            val currentChunkCount = (manifestSnapshot.getLong("chunkCount") ?: 0L).toInt()
            if (currentVersion != expectedVersion) {
                throw ConcurrentSnapshotUpdateException()
            }

            val nextVersion = currentVersion + 1
            chunks.forEachIndexed { index, chunk ->
                transaction.set(
                    chunkDocument(userId, index),
                    mapOf(
                        "version" to nextVersion,
                        "index" to index,
                        "payloadPart" to chunk
                    )
                )
            }
            for (index in chunks.size until currentChunkCount) {
                transaction.delete(chunkDocument(userId, index))
            }
            transaction.set(
                manifestRef,
                mapOf(
                    "format" to SNAPSHOT_FORMAT,
                    "version" to nextVersion,
                    "updatedAt" to updatedAt,
                    "chunkCount" to chunks.size
                )
            )
            nextVersion
        }.await()
    }

    private fun merge(local: AppData, remote: AppData): AppData {
        return AppData(
            subjects = mergeMaster(local.subjects, remote.subjects, Subject::syncId, Subject::updatedAt, Subject::deletedAt),
            materials = mergeMaster(local.materials, remote.materials, Material::syncId, Material::updatedAt, Material::deletedAt),
            sessions = mergeMaster(local.sessions, remote.sessions, StudySession::syncId, StudySession::updatedAt, StudySession::deletedAt),
            goals = mergeMaster(local.goals, remote.goals, Goal::syncId, Goal::updatedAt, Goal::deletedAt),
            exams = mergeMaster(local.exams, remote.exams, Exam::syncId, Exam::updatedAt, Exam::deletedAt),
            plans = mergePlans(local.plans, remote.plans),
            exportDate = maxOf(local.exportDate, remote.exportDate)
        )
    }

    private fun mergePlans(local: List<PlanData>, remote: List<PlanData>): List<PlanData> {
        val mergedPlans = mergeMaster(local.map { it.plan }, remote.map { it.plan }, StudyPlan::syncId, StudyPlan::updatedAt, StudyPlan::deletedAt)
        val localItems = local.flatMap { it.items }
        val remoteItems = remote.flatMap { it.items }
        val mergedItems = mergeMaster(localItems, remoteItems, PlanItem::syncId, PlanItem::updatedAt, PlanItem::deletedAt)
        val itemsByPlanSyncId = mergedItems.groupBy { it.planSyncId }
        return mergedPlans.map { plan ->
            PlanData(
                plan = plan,
                items = itemsByPlanSyncId[plan.syncId].orEmpty()
            )
        }
    }

    private fun <T> mergeMaster(
        local: List<T>,
        remote: List<T>,
        keyOf: (T) -> String,
        updatedAtOf: (T) -> Long,
        deletedAtOf: (T) -> Long?
    ): List<T> {
        val merged = linkedMapOf<String, T>()
        (local + remote).forEach { item ->
            val key = keyOf(item)
            val existing = merged[key]
            if (existing == null) {
                merged[key] = item
            } else {
                val existingDelete = deletedAtOf(existing) ?: Long.MIN_VALUE
                val candidateDelete = deletedAtOf(item) ?: Long.MIN_VALUE
                merged[key] = when {
                    candidateDelete > updatedAtOf(existing) && candidateDelete >= existingDelete -> item
                    existingDelete > updatedAtOf(item) && existingDelete >= candidateDelete -> existing
                    updatedAtOf(item) >= updatedAtOf(existing) -> item
                    else -> existing
                }
            }
        }
        return merged.values.toList()
    }

    private fun markSynced(appData: AppData, syncedAt: Long): AppData {
        return appData.copy(
            subjects = appData.subjects.map { it.copy(lastSyncedAt = syncedAt) },
            materials = appData.materials.map { it.copy(lastSyncedAt = syncedAt) },
            sessions = appData.sessions.map { it.copy(lastSyncedAt = syncedAt) },
            goals = appData.goals.map { it.copy(lastSyncedAt = syncedAt) },
            exams = appData.exams.map { it.copy(lastSyncedAt = syncedAt) },
            plans = appData.plans.map { planData ->
                planData.copy(
                    plan = planData.plan.copy(lastSyncedAt = syncedAt),
                    items = planData.items.map { it.copy(lastSyncedAt = syncedAt) }
                )
            },
            exportDate = syncedAt
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
        check(firebaseAuth.currentUser != null) { "Sign in is required before syncing." }
        val session = authRepository.session.value ?: error("Sign in is required before syncing.")
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

    private fun manifestDocument(userId: String) = firebaseFirestore
        .collection("users")
        .document(userId)
        .collection("sync")
        .document("default")

    private fun chunkDocument(userId: String, index: Int) = manifestDocument(userId)
        .collection("chunks")
        .document(chunkId(index))

    private fun chunkId(index: Int): String = index.toString().padStart(6, '0')

    private fun isConcurrentSnapshotUpdate(throwable: Throwable): Boolean {
        return throwable is ConcurrentSnapshotUpdateException ||
            throwable.cause is ConcurrentSnapshotUpdateException
    }

    private fun mapSyncFailure(throwable: Throwable): Throwable {
        return when {
            isSignInRequired(throwable) -> IllegalStateException("同期するには先にサインインしてください。", throwable)
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
        return throwable.message == "Sign in is required before syncing."
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

    private fun splitPayloadIntoChunks(payload: String): List<String> {
        val utf8 = payload.toByteArray(Charsets.UTF_8)
        if (utf8.isEmpty()) {
            return listOf("")
        }

        val chunks = mutableListOf<String>()
        var start = 0
        while (start < utf8.size) {
            var end = minOf(start + SNAPSHOT_CHUNK_BYTES, utf8.size)
            while (end < utf8.size && end > start && (utf8[end].toInt() and 0xC0) == 0x80) {
                end -= 1
            }
            if (end <= start) {
                end = minOf(start + SNAPSHOT_CHUNK_BYTES, utf8.size)
            }
            chunks += utf8.copyOfRange(start, end).toString(Charsets.UTF_8)
            start = end
        }
        return chunks
    }

    private fun AppData.isEmpty(): Boolean {
        return subjects.isEmpty() &&
            materials.isEmpty() &&
            sessions.isEmpty() &&
            goals.isEmpty() &&
            exams.isEmpty() &&
            plans.isEmpty()
    }

    private data class RemoteSnapshot(
        val payload: String? = null,
        val version: Long = 0L,
        val chunkCount: Int = 0
    )

    private class ConcurrentSnapshotUpdateException : IllegalStateException("Remote snapshot changed during sync.")

    private companion object {
        const val MAX_SYNC_ATTEMPTS = 3
        const val SNAPSHOT_FORMAT = "chunked-v2"
        const val SNAPSHOT_CHUNK_BYTES = 200_000
        const val ACCOUNT_SWITCH_MESSAGE =
            "この端末のローカルデータは別の同期アカウントに紐づいています。全データを削除してから再度同期してください。"
    }
}
