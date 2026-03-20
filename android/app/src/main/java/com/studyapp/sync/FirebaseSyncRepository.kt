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
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import org.json.JSONObject

@Singleton
class FirebaseSyncRepository @Inject constructor(
    private val authRepository: AuthRepository,
    private val firebaseRestClient: FirebaseRestClient,
    private val syncPreferences: SyncPreferences,
    private val exportImportDataUseCase: ExportImportDataUseCase
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
        val session = requireSession()
        setSyncing(true)
        try {
            val local = exportLocalData()
            val remoteJson = firebaseRestClient.loadSnapshot(session)
            val merged = if (remoteJson == null) local else merge(local, AppData.fromJson(JSONObject(remoteJson)))
            val payload = markSynced(merged, System.currentTimeMillis()).toJson().toString()
            when (val result = exportImportDataUseCase.importFromJson(payload)) {
                is Result.Error -> throw result.exception
                is Result.Success -> Unit
            }
            val now = System.currentTimeMillis()
            firebaseRestClient.saveSnapshot(session, payload, now)
            syncPreferences.setLastSyncAt(now)
            _status.value = SyncStatus(true, session.email, false, now, null)
        } catch (t: Throwable) {
            _status.value = _status.value.copy(isSyncing = false, errorMessage = t.message)
            throw t
        }
    }

    override suspend fun importLocalDataToCloud() {
        val session = requireSession()
        setSyncing(true)
        try {
            val now = System.currentTimeMillis()
            val payload = markSynced(exportLocalData(), now).toJson().toString()
            firebaseRestClient.saveSnapshot(session, payload, now)
            syncPreferences.setLastSyncAt(now)
            _status.value = SyncStatus(true, session.email, false, now, null)
        } catch (t: Throwable) {
            _status.value = _status.value.copy(isSyncing = false, errorMessage = t.message)
            throw t
        }
    }

    private suspend fun exportLocalData(): AppData {
        return when (val result = exportImportDataUseCase.exportToJson()) {
            is Result.Error -> throw result.exception
            is Result.Success -> AppData.fromJson(JSONObject(result.data))
        }
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

    private fun requireSession(): AuthSession {
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
}
