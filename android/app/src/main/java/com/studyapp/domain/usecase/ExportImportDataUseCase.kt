package com.studyapp.domain.usecase

import android.util.Log
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
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
import com.studyapp.data.local.db.entity.SubjectEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
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
    note = optString("note").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"),
    lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun Goal.toJson() = JSONObject().apply {
    put("id", id)
    put("syncId", syncId)
    put("type", type.name)
    put("targetMinutes", targetMinutes)
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
    private val studyDatabase: StudyDatabase
) {
    suspend fun exportToJson(): Result<String> {
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
    
    suspend fun importFromJson(jsonString: String): Result<Unit> {
        Log.d(TAG, "Starting data import")
        
        val backup = try {
            createBackup()
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create backup before import", e)
            return Result.Error(e, "インポート前のバックアップに失敗しました")
        }
        
        return try {
            val json = JSONObject(jsonString)
            val appData = AppData.fromJson(json)
            
            when (val deleteResult = deleteAllData()) {
                is Result.Error -> return deleteResult
                is Result.Success -> Unit
            }
            
            var importError: Throwable? = null
            
            appData.subjects.forEach { subject ->
                if (importError == null) {
                    when (val result = subjectRepository.insertSubject(subject)) {
                        is Result.Error -> importError = result.exception
                        else -> {}
                    }
                }
            }
            
            appData.materials.forEach { material ->
                if (importError == null) {
                    when (val result = materialRepository.insertMaterial(material)) {
                        is Result.Error -> importError = result.exception
                        else -> {}
                    }
                }
            }
            
            appData.sessions.forEach { session ->
                if (importError == null) {
                    when (val result = studySessionRepository.insertSession(session)) {
                        is Result.Error -> importError = result.exception
                        else -> {}
                    }
                }
            }
            
            appData.goals.forEach { goal ->
                if (importError == null) {
                    when (val result = goalRepository.insertGoal(goal)) {
                        is Result.Error -> importError = result.exception
                        else -> {}
                    }
                }
            }
            
            appData.exams.forEach { exam ->
                if (importError == null) {
                    when (val result = examRepository.insertExam(exam)) {
                        is Result.Error -> importError = result.exception
                        else -> {}
                    }
                }
            }
            
            appData.plans
                .sortedBy { it.plan.isActive }
                .forEach { planData ->
                if (importError == null) {
                    when (val result = planRepository.createPlan(planData.plan, planData.items)) {
                        is Result.Error -> importError = result.exception
                        else -> {}
                    }
                }
            }
            
            if (importError != null) {
                Log.e(TAG, "Import failed, restoring from backup", importError)
                restoreFromBackup(backup)
                Result.Error(importError!!, "データのインポートに失敗しました")
            } else {
                Log.i(TAG, "Data import completed: subjects=${appData.subjects.size}, materials=${appData.materials.size}, sessions=${appData.sessions.size}, goals=${appData.goals.size}, exams=${appData.exams.size}, plans=${appData.plans.size}")
                Result.Success(Unit)
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed to import data, restoring from backup", e)
            restoreFromBackup(backup)
            Result.Error(e, "データのインポートに失敗しました")
        }
    }
    
    private suspend fun createBackup(): AppData {
        return snapshotAppData()
    }
    
    private suspend fun restoreFromBackup(backup: AppData) {
        try {
            when (deleteAllData()) {
                is Result.Error -> return
                is Result.Success -> Unit
            }
            
            backup.subjects.forEach { subject ->
                subjectRepository.insertSubject(subject)
            }
            
            backup.materials.forEach { material ->
                materialRepository.insertMaterial(material)
            }
            
            backup.sessions.forEach { session ->
                studySessionRepository.insertSession(session)
            }
            
            backup.goals.forEach { goal ->
                goalRepository.insertGoal(goal)
            }
            
            backup.exams.forEach { exam ->
                examRepository.insertExam(exam)
            }
            
            backup.plans
                .sortedBy { it.plan.isActive }
                .forEach { planData ->
                planRepository.createPlan(planData.plan, planData.items)
            }
            
            Log.i(TAG, "Backup restored successfully")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to restore from backup", e)
        }
    }
    
    suspend fun deleteAllData(): Result<Unit> {
        Log.d(TAG, "Starting to delete all data")
        
        return try {
            withContext(Dispatchers.IO) {
                studyDatabase.clearAllTables()
            }
            Log.i(TAG, "All data deleted successfully")
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to delete all data", e)
            Result.Error(e, "データの削除に失敗しました")
        }
    }

    private suspend fun snapshotAppData(): AppData {
        val subjectDao = studyDatabase.subjectDao()
        val materialDao = studyDatabase.materialDao()
        val studySessionDao = studyDatabase.studySessionDao()
        val goalDao = studyDatabase.goalDao()
        val examDao = studyDatabase.examDao()
        val planDao = studyDatabase.planDao()

        val subjects = subjectDao.getAllSubjectsForSync().map { it.toDomain() }
        val materials = materialDao.getAllMaterialsForSync().map { it.toDomain() }
        val sessions = studySessionDao.getAllSessionsForSync().map { it.toDomain() }
        val goals = goalDao.getAllGoalsForSync().map { it.toDomain() }
        val exams = examDao.getAllExamsForSync().map { it.toDomain() }
        val plans = planDao.getAllPlansForSync().map { plan ->
            PlanData(
                plan = plan.toDomain(),
                items = planDao.getPlanItemsForSync(plan.id).map { it.toDomain() }
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
    note = note,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)

private fun GoalEntity.toDomain() = Goal(
    id = id,
    syncId = syncId.ifEmpty { "goal-$id" },
    type = type,
    targetMinutes = targetMinutes,
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
