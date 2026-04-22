package com.studyapp.domain.usecase

import android.util.Log
import androidx.room.withTransaction
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.Subject
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.PlanRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.util.Result
import com.studyapp.data.local.db.StudyDatabase
import com.studyapp.data.local.db.entity.ExamEntity
import com.studyapp.data.local.db.entity.GoalEntity
import com.studyapp.data.local.db.entity.MaterialEntity
import com.studyapp.data.local.db.entity.PlanEntity
import com.studyapp.data.local.db.entity.PlanItemEntity
import com.studyapp.data.local.db.entity.StudySessionEntity
import com.studyapp.data.local.db.entity.StudySessionWithNames
import com.studyapp.data.local.db.entity.SubjectEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import com.studyapp.sync.AppDataWriteLock
import javax.inject.Inject

data class AppData(
    val subjects: List<Subject>,
    val materials: List<Material>,
    val sessions: List<StudySession>,
    val goals: List<Goal>,
    val exams: List<Exam>,
    val plans: List<PlanData>,
    val exportDate: Long
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("subjects", JSONArray(subjects.map { it.toJson() }))
            put("materials", JSONArray(materials.map { it.toJson() }))
            put("sessions", JSONArray(sessions.map { it.toJson() }))
            put("goals", JSONArray(goals.map { it.toJson() }))
            put("exams", JSONArray(exams.map { it.toJson() }))
            put("plans", JSONArray(plans.map { it.toJson() }))
            put("exportDate", exportDate)
        }
    }
    
    companion object {
        fun fromJson(json: JSONObject): AppData {
            return AppData(
                subjects = json.optJSONArray("subjects")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toSubject() }
                } ?: emptyList(),
                materials = json.optJSONArray("materials")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toMaterial() }
                } ?: emptyList(),
                sessions = json.optJSONArray("sessions")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toStudySession() }
                } ?: emptyList(),
                goals = json.optJSONArray("goals")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toGoal() }
                } ?: emptyList(),
                exams = json.optJSONArray("exams")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toExam() }
                } ?: emptyList(),
                plans = json.optJSONArray("plans")?.let { arr ->
                    (0 until arr.length()).mapNotNull { PlanData.fromJson(arr.getJSONObject(it)) }
                } ?: emptyList(),
                exportDate = json.optLong("exportDate", System.currentTimeMillis())
            )
        }
    }
}

data class PlanData(
    val plan: StudyPlan,
    val items: List<PlanItem>
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("plan", plan.toJson())
            put("items", JSONArray(items.map { it.toJson() }))
        }
    }
    
    companion object {
        fun fromJson(json: JSONObject): PlanData {
            return PlanData(
                plan = json.getJSONObject("plan").toStudyPlan(),
                items = json.optJSONArray("items")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toPlanItem() }
                } ?: emptyList()
            )
        }
    }
}

private fun Subject.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("name", name)
    put("color", color)
    put("icon", icon?.name)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("deletedAt", deletedAt)
    put("lastSyncedAt", lastSyncedAt)
}

private fun JSONObject.toSubject() = Subject(
    id = optLong("id"),
    syncId = optString("syncId").ifEmpty { "subject-${optLong("id")}" },
    name = optString("name"),
    color = optInt("color"),
    icon = optString("icon").let { if (it.isNullOrEmpty()) null else com.studyapp.domain.model.SubjectIcon.fromName(it) },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun Material.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("name", name)
    put("subjectId", subjectId)
    put("subjectSyncId", subjectSyncId)
    put("totalPages", totalPages)
    put("currentPage", currentPage)
    put("color", color)
    put("note", note)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("deletedAt", deletedAt)
    put("lastSyncedAt", lastSyncedAt)
}

private fun JSONObject.toMaterial() = Material(
    id = optLong("id"),
    syncId = optString("syncId").ifEmpty { "material-${optLong("id")}" },
    name = optString("name"),
    subjectId = optLong("subjectId"),
    subjectSyncId = optString("subjectSyncId").takeIf { it.isNotEmpty() },
    totalPages = optInt("totalPages"),
    currentPage = optInt("currentPage"),
    color = if (has("color")) getInt("color") else null,
    note = optString("note").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun StudySession.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("materialId", materialId)
    put("materialSyncId", materialSyncId)
    put("materialName", materialName)
    put("subjectId", subjectId)
    put("subjectSyncId", subjectSyncId)
    put("subjectName", subjectName)
    put("startTime", startTime)
    put("endTime", endTime)
    put("intervals", JSONArray(effectiveIntervals.map { it.toJson() }))
    put("note", note)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("deletedAt", deletedAt)
    put("lastSyncedAt", lastSyncedAt)
}

private fun JSONObject.toStudySession() = StudySession(
    id = optLong("id"),
    syncId = optString("syncId").ifEmpty { "session-${optLong("id")}" },
    materialId = if (has("materialId")) getLong("materialId") else null,
    materialSyncId = optString("materialSyncId").takeIf { it.isNotEmpty() },
    materialName = optString("materialName"),
    subjectId = optLong("subjectId"),
    subjectSyncId = optString("subjectSyncId").takeIf { it.isNotEmpty() },
    subjectName = optString("subjectName"),
    startTime = optLong("startTime"),
    endTime = optLong("endTime"),
    intervals = optJSONArray("intervals")?.let { intervals ->
        (0 until intervals.length()).mapNotNull { index ->
            intervals.optJSONObject(index)?.toStudySessionInterval()
        }
    } ?: emptyList(),
    note = optString("note").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun StudySessionInterval.toJson() = JSONObject().apply {
    put("startTime", startTime)
    put("endTime", endTime)
}

private fun JSONObject.toStudySessionInterval() = StudySessionInterval(
    startTime = optLong("startTime"),
    endTime = optLong("endTime")
)

private fun Goal.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("type", type.name)
    put("targetMinutes", targetMinutes)
    put("dayOfWeek", dayOfWeek?.name)
    put("weekStartDay", weekStartDay.name)
    put("isActive", isActive)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("deletedAt", deletedAt)
    put("lastSyncedAt", lastSyncedAt)
}

private fun JSONObject.toGoal() = Goal(
    id = optLong("id"),
    syncId = optString("syncId").ifEmpty { "goal-${optLong("id")}" },
    type = com.studyapp.domain.model.GoalType.valueOf(optString("type", "DAILY")),
    targetMinutes = optInt("targetMinutes"),
    dayOfWeek = optString("dayOfWeek").takeIf { it.isNotEmpty() }?.let(java.time.DayOfWeek::valueOf),
    weekStartDay = java.time.DayOfWeek.valueOf(optString("weekStartDay", "MONDAY")),
    isActive = optBoolean("isActive", true),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun Exam.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("name", name)
    put("date", date.toEpochDay())
    put("note", note)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("deletedAt", deletedAt)
    put("lastSyncedAt", lastSyncedAt)
}

private fun JSONObject.toExam() = Exam(
    id = optLong("id"),
    syncId = optString("syncId").ifEmpty { "exam-${optLong("id")}" },
    name = optString("name"),
    date = java.time.LocalDate.ofEpochDay(optLong("date")),
    note = optString("note").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun StudyPlan.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("name", name)
    put("startDate", startDate)
    put("endDate", endDate)
    put("isActive", isActive)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("deletedAt", deletedAt)
    put("lastSyncedAt", lastSyncedAt)
}

private fun JSONObject.toStudyPlan() = StudyPlan(
    id = optLong("id"),
    syncId = optString("syncId").ifEmpty { "plan-${optLong("id")}" },
    name = optString("name"),
    startDate = optLong("startDate"),
    endDate = optLong("endDate"),
    isActive = optBoolean("isActive", true),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun PlanItem.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("planId", planId)
    put("planSyncId", planSyncId)
    put("subjectId", subjectId)
    put("subjectSyncId", subjectSyncId)
    put("dayOfWeek", dayOfWeek.name)
    put("targetMinutes", targetMinutes)
    put("actualMinutes", actualMinutes)
    put("timeSlot", timeSlot)
    put("createdAt", createdAt)
    put("updatedAt", updatedAt)
    put("deletedAt", deletedAt)
    put("lastSyncedAt", lastSyncedAt)
}

private fun JSONObject.toPlanItem() = PlanItem(
    id = optLong("id"),
    syncId = optString("syncId").ifEmpty { "plan-item-${optLong("id")}" },
    planId = optLong("planId"),
    planSyncId = optString("planSyncId").takeIf { it.isNotEmpty() },
    subjectId = optLong("subjectId"),
    subjectSyncId = optString("subjectSyncId").takeIf { it.isNotEmpty() },
    dayOfWeek = java.time.DayOfWeek.valueOf(optString("dayOfWeek", "MONDAY")),
    targetMinutes = optInt("targetMinutes"),
    actualMinutes = optInt("actualMinutes"),
    timeSlot = optString("timeSlot").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun JSONObject.optNullableLong(key: String): Long? {
    if (!has(key) || isNull(key)) {
        return null
    }
    return optLong(key)
}

class ExportImportDataUseCase @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val materialRepository: MaterialRepository,
    private val studySessionRepository: StudySessionRepository,
    private val goalRepository: GoalRepository,
    private val examRepository: ExamRepository,
    private val planRepository: PlanRepository,
    private val studyDatabase: StudyDatabase,
    private val writeLock: AppDataWriteLock
) {
    suspend fun exportToJson(): Result<String> {
        return writeLock.withLock {
            exportToJsonWithoutWriteLock()
        }
    }

    suspend fun exportAppDataWithoutWriteLock(): AppData {
        return snapshotAppData()
    }

    suspend fun importFromJson(jsonString: String): Result<Unit> {
        return writeLock.withLock {
            importFromJsonWithoutWriteLock(jsonString)
        }
    }

    suspend fun importFromJsonWithoutWriteLock(jsonString: String): Result<Unit> {
        Log.d(TAG, "Starting data import")
        return try {
            val appData = AppData.fromJson(JSONObject(jsonString))
            studyDatabase.withTransaction {
                clearAllDataForImport()
                insertAppDataForImport(appData)
            }
            Log.i(
                TAG,
                "Data import completed: subjects=${appData.subjects.size}, materials=${appData.materials.size}, sessions=${appData.sessions.size}, goals=${appData.goals.size}, exams=${appData.exams.size}, plans=${appData.plans.size}"
            )
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to import data", e)
            Result.Error(e, "データのインポートに失敗しました")
        }
    }

    suspend fun deleteAllData(): Result<Unit> {
        return writeLock.withLock {
            Log.d(TAG, "Starting to delete all data")
            try {
                studyDatabase.withTransaction {
                    clearAllDataForImport()
                }
                Log.i(TAG, "All data deleted successfully")
                Result.Success(Unit)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to delete all data", e)
                Result.Error(e, "データの削除に失敗しました")
            }
        }
    }

    private suspend fun exportToJsonWithoutWriteLock(): Result<String> {
        Log.d(TAG, "Starting data export")

        val appData = snapshotAppData()
        
        return try {
            val jsonString = appData.toJson().toString(2)
            Log.i(TAG, "Data export completed: subjects=${appData.subjects.size}, materials=${appData.materials.size}, sessions=${appData.sessions.size}, goals=${appData.goals.size}, exams=${appData.exams.size}, plans=${appData.plans.size}")
            Result.Success(jsonString)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to export data", e)
            Result.Error(e, "データのエクスポートに失敗しました")
        }
    }

    private suspend fun snapshotAppData(): AppData {
        val subjectDao = studyDatabase.subjectDao()
        val materialDao = studyDatabase.materialDao()
        val studySessionDao = studyDatabase.studySessionDao()
        val goalDao = studyDatabase.goalDao()
        val examDao = studyDatabase.examDao()
        val planDao = studyDatabase.planDao()

        val subjectEntities = subjectDao.getAllSubjectsForSync()
        val subjects = subjectEntities.map { it.toDomain() }
        val subjectsById = subjectEntities.associateBy { it.id }

        val materialEntities = materialDao.getAllMaterialsForSync()
        val materials = materialEntities.map { entity ->
            entity.toDomain().copy(
                subjectSyncId = entity.subjectSyncId ?: subjectsById[entity.subjectId]?.syncId
            )
        }
        val materialsById = materials.associateBy { it.id }

        val sessions = studySessionDao.getAllSessionsForSyncWithNames().map { row ->
            row.toDomain().copy(
                materialSyncId = row.session.materialSyncId ?: row.session.materialId?.let { materialsById[it]?.syncId },
                subjectSyncId = row.session.subjectSyncId ?: subjectsById[row.session.subjectId]?.syncId
            )
        }
        val goals = goalDao.getAllGoalsForSync().map { it.toDomain() }
        val exams = examDao.getAllExamsForSync().map { it.toDomain() }
        val planEntities = planDao.getAllPlansForSync()
        val plans = planEntities.map { plan ->
            PlanData(
                plan = plan.toDomain(),
                items = planDao.getPlanItemsForSync(plan.id).map { item ->
                    item.toDomain().copy(
                        planSyncId = item.planSyncId ?: plan.syncId,
                        subjectSyncId = item.subjectSyncId ?: subjectsById[item.subjectId]?.syncId
                    )
                }
            )
        }

        return AppData(
            subjects = subjects,
            materials = materials,
            sessions = sessions,
            goals = goals,
            exams = exams,
            plans = plans,
            exportDate = System.currentTimeMillis()
        )
    }

    private suspend fun clearAllDataForImport() {
        val subjectDao = studyDatabase.subjectDao()
        val materialDao = studyDatabase.materialDao()
        val studySessionDao = studyDatabase.studySessionDao()
        val goalDao = studyDatabase.goalDao()
        val examDao = studyDatabase.examDao()
        val planDao = studyDatabase.planDao()

        planDao.deleteAllPlanItemsForImport()
        studySessionDao.deleteAllSessionsForImport()
        materialDao.deleteAllMaterialsForImport()
        examDao.deleteAllExamsForImport()
        goalDao.deleteAllGoalsForImport()
        planDao.deleteAllPlansForImport()
        subjectDao.deleteAllSubjectsForImport()
    }

    private suspend fun insertAppDataForImport(appData: AppData) {
        val subjectDao = studyDatabase.subjectDao()
        val materialDao = studyDatabase.materialDao()
        val studySessionDao = studyDatabase.studySessionDao()
        val goalDao = studyDatabase.goalDao()
        val examDao = studyDatabase.examDao()
        val planDao = studyDatabase.planDao()

        val subjectIdsBySyncId = linkedMapOf<String, Long>()
        val subjectIdsByLegacyId = linkedMapOf<Long, Long>()
        val subjectSyncIdsByLegacyId = linkedMapOf<Long, String>()
        appData.subjects.forEach { subject ->
            val newId = subjectDao.insertSubject(
                SubjectEntity(
                    syncId = subject.syncId,
                    name = subject.name,
                    color = subject.color,
                    icon = subject.icon?.name,
                    createdAt = subject.createdAt,
                    updatedAt = subject.updatedAt,
                    deletedAt = subject.deletedAt,
                    lastSyncedAt = subject.lastSyncedAt
                )
            )
            subjectIdsBySyncId[subject.syncId] = newId
            subjectIdsByLegacyId[subject.id] = newId
            subjectSyncIdsByLegacyId[subject.id] = subject.syncId
        }

        val materialIdsBySyncId = linkedMapOf<String, Long>()
        val materialIdsByLegacyId = linkedMapOf<Long, Long>()
        val materialSyncIdsByLegacyId = linkedMapOf<Long, String>()
        appData.materials.forEach { material ->
            val resolvedSubjectId = resolveMappedId(
                label = "subject",
                ownerSyncId = material.syncId,
                syncId = material.subjectSyncId,
                legacyId = material.subjectId,
                idsBySyncId = subjectIdsBySyncId,
                idsByLegacyId = subjectIdsByLegacyId
            )
            val resolvedSubjectSyncId = material.subjectSyncId ?: subjectSyncIdsByLegacyId[material.subjectId]
            val newId = materialDao.insertMaterial(
                MaterialEntity(
                    syncId = material.syncId,
                    name = material.name,
                    subjectId = resolvedSubjectId,
                    subjectSyncId = resolvedSubjectSyncId,
                    totalPages = material.totalPages,
                    currentPage = material.currentPage,
                    color = material.color,
                    note = material.note,
                    createdAt = material.createdAt,
                    updatedAt = material.updatedAt,
                    deletedAt = material.deletedAt,
                    lastSyncedAt = material.lastSyncedAt
                )
            )
            materialIdsBySyncId[material.syncId] = newId
            materialIdsByLegacyId[material.id] = newId
            materialSyncIdsByLegacyId[material.id] = material.syncId
        }

        appData.sessions.forEach { session ->
            val resolvedSubjectId = resolveMappedId(
                label = "subject",
                ownerSyncId = session.syncId,
                syncId = session.subjectSyncId,
                legacyId = session.subjectId,
                idsBySyncId = subjectIdsBySyncId,
                idsByLegacyId = subjectIdsByLegacyId
            )
            val resolvedMaterialId = session.materialId?.let { legacyMaterialId ->
                resolveMappedOptionalId(
                    label = "material",
                    ownerSyncId = session.syncId,
                    syncId = session.materialSyncId,
                    legacyId = legacyMaterialId,
                    idsBySyncId = materialIdsBySyncId,
                    idsByLegacyId = materialIdsByLegacyId
                )
            }
            studySessionDao.insertSession(
                StudySessionEntity(
                    syncId = session.syncId,
                    materialId = resolvedMaterialId,
                    materialSyncId = session.materialSyncId ?: session.materialId?.let { materialSyncIdsByLegacyId[it] },
                    subjectId = resolvedSubjectId,
                    subjectSyncId = session.subjectSyncId ?: subjectSyncIdsByLegacyId[session.subjectId],
                    startTime = session.sessionStartTime,
                    endTime = session.sessionEndTime,
                    duration = session.duration,
                    date = session.date.atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli(),
                    intervalsJson = session.intervals.takeIf { it.isNotEmpty() }?.let { intervals ->
                        JSONArray(intervals.map { it.toJson() }).toString()
                    },
                    note = session.note,
                    createdAt = session.createdAt,
                    updatedAt = session.updatedAt,
                    deletedAt = session.deletedAt,
                    lastSyncedAt = session.lastSyncedAt
                )
            )
        }

        appData.goals.forEach { goal ->
            goalDao.insertGoal(
                GoalEntity(
                    syncId = goal.syncId,
                    type = goal.type,
                    targetMinutes = goal.targetMinutes,
                    dayOfWeek = goal.dayOfWeek?.value ?: 0,
                    weekStartDay = goal.weekStartDay.value,
                    isActive = goal.isActive,
                    createdAt = goal.createdAt,
                    updatedAt = goal.updatedAt,
                    deletedAt = goal.deletedAt,
                    lastSyncedAt = goal.lastSyncedAt
                )
            )
        }

        appData.exams.forEach { exam ->
            examDao.insertExam(
                ExamEntity(
                    syncId = exam.syncId,
                    name = exam.name,
                    date = exam.date.atStartOfDay(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli(),
                    note = exam.note,
                    createdAt = exam.createdAt,
                    updatedAt = exam.updatedAt,
                    deletedAt = exam.deletedAt,
                    lastSyncedAt = exam.lastSyncedAt
                )
            )
        }

        val planIdsBySyncId = linkedMapOf<String, Long>()
        val planIdsByLegacyId = linkedMapOf<Long, Long>()
        val planSyncIdsByLegacyId = linkedMapOf<Long, String>()
        val activePlanSyncId = appData.plans.lastOrNull { it.plan.isActive && it.plan.deletedAt == null }?.plan?.syncId
        appData.plans.forEach { planData ->
            val plan = planData.plan
            val newId = planDao.insertPlan(
                PlanEntity(
                    syncId = plan.syncId,
                    name = plan.name,
                    startDate = plan.startDate,
                    endDate = plan.endDate,
                    isActive = plan.syncId == activePlanSyncId,
                    createdAt = plan.createdAt,
                    updatedAt = plan.updatedAt,
                    deletedAt = plan.deletedAt,
                    lastSyncedAt = plan.lastSyncedAt
                )
            )
            planIdsBySyncId[plan.syncId] = newId
            planIdsByLegacyId[plan.id] = newId
            planSyncIdsByLegacyId[plan.id] = plan.syncId
        }

        appData.plans.flatMap { it.items }.forEach { item ->
            val resolvedPlanId = resolveMappedId(
                label = "plan",
                ownerSyncId = item.syncId,
                syncId = item.planSyncId,
                legacyId = item.planId,
                idsBySyncId = planIdsBySyncId,
                idsByLegacyId = planIdsByLegacyId
            )
            val resolvedSubjectId = resolveMappedId(
                label = "subject",
                ownerSyncId = item.syncId,
                syncId = item.subjectSyncId,
                legacyId = item.subjectId,
                idsBySyncId = subjectIdsBySyncId,
                idsByLegacyId = subjectIdsByLegacyId
            )
            planDao.insertPlanItem(
                PlanItemEntity(
                    syncId = item.syncId,
                    planId = resolvedPlanId,
                    planSyncId = item.planSyncId ?: planSyncIdsByLegacyId[item.planId],
                    subjectId = resolvedSubjectId,
                    subjectSyncId = item.subjectSyncId ?: subjectSyncIdsByLegacyId[item.subjectId],
                    dayOfWeek = item.dayOfWeek.value,
                    targetMinutes = item.targetMinutes,
                    actualMinutes = item.actualMinutes,
                    timeSlot = item.timeSlot,
                    createdAt = item.createdAt,
                    updatedAt = item.updatedAt,
                    deletedAt = item.deletedAt,
                    lastSyncedAt = item.lastSyncedAt
                )
            )
        }
    }

    private fun resolveMappedId(
        label: String,
        ownerSyncId: String,
        syncId: String?,
        legacyId: Long,
        idsBySyncId: Map<String, Long>,
        idsByLegacyId: Map<Long, Long>
    ): Long {
        syncId?.let { idsBySyncId[it] }?.let { return it }
        idsByLegacyId[legacyId]?.let { return it }
        error("Missing $label mapping for $ownerSyncId")
    }

    private fun resolveMappedOptionalId(
        label: String,
        ownerSyncId: String,
        syncId: String?,
        legacyId: Long,
        idsBySyncId: Map<String, Long>,
        idsByLegacyId: Map<Long, Long>
    ): Long? {
        syncId?.let { idsBySyncId[it] }?.let { return it }
        idsByLegacyId[legacyId]?.let { return it }
        error("Missing $label mapping for $ownerSyncId")
    }
    
    companion object {
        private const val TAG = "ExportImportDataUseCase"
    }
}

private fun SubjectEntity.toDomain() = Subject(
    id = id,
    syncId = syncId.ifEmpty { "subject-$id" },
    name = name,
    color = color,
    icon = icon?.let { com.studyapp.domain.model.SubjectIcon.fromName(it) },
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)

private fun MaterialEntity.toDomain() = Material(
    id = id,
    syncId = syncId.ifEmpty { "material-$id" },
    name = name,
    subjectId = subjectId,
    subjectSyncId = subjectSyncId,
    totalPages = totalPages,
    currentPage = currentPage,
    color = color,
    note = note,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)

private fun StudySessionEntity.toDomain() = StudySession(
    id = id,
    syncId = syncId.ifEmpty { "session-$id" },
    materialId = materialId,
    materialSyncId = materialSyncId,
    materialName = "",
    subjectId = subjectId,
    subjectSyncId = subjectSyncId,
    subjectName = "",
    startTime = startTime,
    endTime = endTime,
    intervals = intervalsJson?.let { intervals ->
        JSONArray(intervals).let { array ->
            (0 until array.length()).mapNotNull { index ->
                array.optJSONObject(index)?.toStudySessionInterval()
            }
        }
    } ?: emptyList(),
    note = note,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)

private fun StudySessionWithNames.toDomain() = StudySession(
    id = session.id,
    syncId = session.syncId.ifEmpty { "session-${session.id}" },
    materialId = session.materialId,
    materialSyncId = session.materialSyncId,
    materialName = materialName.orEmpty(),
    subjectId = session.subjectId,
    subjectSyncId = session.subjectSyncId,
    subjectName = subjectName,
    startTime = session.startTime,
    endTime = session.endTime,
    intervals = session.intervalsJson?.let { intervals ->
        JSONArray(intervals).let { array ->
            (0 until array.length()).mapNotNull { index ->
                array.optJSONObject(index)?.toStudySessionInterval()
            }
        }
    } ?: emptyList(),
    note = session.note,
    createdAt = session.createdAt,
    updatedAt = session.updatedAt,
    deletedAt = session.deletedAt,
    lastSyncedAt = session.lastSyncedAt
)

private fun GoalEntity.toDomain() = Goal(
    id = id,
    syncId = syncId.ifEmpty { "goal-$id" },
    type = type,
    targetMinutes = targetMinutes,
    dayOfWeek = dayOfWeek.takeIf { it in 1..7 }?.let(java.time.DayOfWeek::of),
    weekStartDay = java.time.DayOfWeek.of(weekStartDay),
    isActive = isActive,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)

private fun ExamEntity.toDomain() = Exam(
    id = id,
    syncId = syncId.ifEmpty { "exam-$id" },
    name = name,
    date = java.time.Instant.ofEpochMilli(date).atZone(java.time.ZoneId.systemDefault()).toLocalDate(),
    note = note,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)

private fun PlanEntity.toDomain() = StudyPlan(
    id = id,
    syncId = syncId.ifEmpty { "plan-$id" },
    name = name,
    startDate = startDate,
    endDate = endDate,
    isActive = isActive,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)

private fun PlanItemEntity.toDomain() = PlanItem(
    id = id,
    syncId = syncId.ifEmpty { "plan-item-$id" },
    planId = planId,
    planSyncId = planSyncId,
    subjectId = subjectId,
    subjectSyncId = subjectSyncId,
    dayOfWeek = java.time.DayOfWeek.of(dayOfWeek),
    targetMinutes = targetMinutes,
    actualMinutes = actualMinutes,
    timeSlot = timeSlot,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)
