package com.studyapp.domain.usecase

import android.util.Log
import androidx.room.withTransaction
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.ProblemChapter
import com.studyapp.domain.model.ProblemReviewRating
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.repository.ExamRepository
import com.studyapp.domain.repository.GoalRepository
import com.studyapp.domain.repository.MaterialRepository
import com.studyapp.domain.repository.PlanRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.repository.SubjectRepository
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Result
import com.studyapp.data.local.db.StudyDatabase
import com.studyapp.data.local.db.entity.ExamEntity
import com.studyapp.data.local.db.entity.GoalEntity
import com.studyapp.data.local.db.entity.MaterialEntity
import com.studyapp.data.local.db.entity.PlanEntity
import com.studyapp.data.local.db.entity.PlanItemEntity
import com.studyapp.data.local.db.entity.ProblemReviewRecordEntity
import com.studyapp.data.local.db.entity.StudySessionEntity
import com.studyapp.data.local.db.entity.StudySessionWithNames
import com.studyapp.data.local.db.entity.SubjectEntity
import com.studyapp.data.local.db.entity.TimetableEntryEntity
import com.studyapp.data.local.db.entity.TimetablePeriodEntity
import com.studyapp.data.local.db.entity.TimetableReviewRecordEntity
import com.studyapp.data.local.db.entity.TimetableTermEntity
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import com.studyapp.sync.AppDataWriteLock
import javax.inject.Inject

data class AppData(
    val schemaVersion: Int = CURRENT_SCHEMA_VERSION,
    val supportsProblemRecords: Boolean = true,
    val subjects: List<Subject>,
    val materials: List<Material>,
    val sessions: List<StudySession>,
    val goals: List<Goal>,
    val exams: List<Exam>,
    val plans: List<PlanData>,
    val timetablePeriods: List<TimetablePeriod> = emptyList(),
    val timetableEntries: List<TimetableEntry> = emptyList(),
    val timetableTerms: List<TimetableTerm> = emptyList(),
    val timetableReviewRecords: List<TimetableReviewRecord> = emptyList(),
    val problemReviewRecords: List<ProblemReviewRecord> = emptyList(),
    val exportDate: Long
) {
    fun toJson(): JSONObject {
        return JSONObject().apply {
            put("schemaVersion", schemaVersion)
            put("supportsProblemRecords", supportsProblemRecords)
            put("subjects", JSONArray(subjects.map { it.toJson() }))
            put("materials", JSONArray(materials.map { it.toJson() }))
            put("sessions", JSONArray(sessions.map { it.toJson() }))
            put("goals", JSONArray(goals.map { it.toJson() }))
            put("exams", JSONArray(exams.map { it.toJson() }))
            put("plans", JSONArray(plans.map { it.toJson() }))
            put("timetablePeriods", JSONArray(timetablePeriods.map { it.toJson() }))
            put("timetableEntries", JSONArray(timetableEntries.map { it.toJson() }))
            put("timetableTerms", JSONArray(timetableTerms.map { it.toJson() }))
            put("timetableReviewRecords", JSONArray(timetableReviewRecords.map { it.toJson() }))
            put("problemReviewRecords", JSONArray(problemReviewRecords.map { it.toJson() }))
            put("exportDate", exportDate)
        }
    }

    companion object {
        fun fromJson(json: JSONObject): AppData {
            return AppData(
                schemaVersion = json.optInt("schemaVersion", 1),
                supportsProblemRecords = json.optBoolean("supportsProblemRecords", false),
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
                timetablePeriods = json.optJSONArray("timetablePeriods")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toTimetablePeriod() }
                } ?: emptyList(),
                timetableEntries = json.optJSONArray("timetableEntries")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toTimetableEntry() }
                } ?: emptyList(),
                timetableTerms = json.optJSONArray("timetableTerms")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toTimetableTerm() }
                } ?: emptyList(),
                timetableReviewRecords = json.optJSONArray("timetableReviewRecords")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toTimetableReviewRecord() }
                } ?: emptyList(),
                problemReviewRecords = json.optJSONArray("problemReviewRecords")?.let { arr ->
                    (0 until arr.length()).mapNotNull { arr.getJSONObject(it).toProblemReviewRecord() }
                } ?: emptyList(),
                exportDate = json.optLong("exportDate", System.currentTimeMillis())
            )
        }

        const val CURRENT_SCHEMA_VERSION = 2
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

// JSON serialization helpers (internal for delta sync)
internal fun Subject.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("name", name); put("color", color)
    put("icon", icon?.name); put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toSubject() = Subject(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "subject-${optLong("id")}" },
    name = optString("name"), color = optInt("color"),
    icon = optString("icon").let { if (it.isNullOrEmpty()) null else com.studyapp.domain.model.SubjectIcon.fromName(it) },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun Material.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("name", name); put("subjectId", subjectId)
    put("subjectSyncId", subjectSyncId); put("totalPages", totalPages); put("currentPage", currentPage)
    put("totalProblems", totalProblems)
    if (problemChapters.isNotEmpty()) put("problemChapters", JSONArray(problemChapters.map { it.toJson() }))
    if (problemRecords.isNotEmpty()) put("problemRecords", JSONArray(problemRecords.map { it.toJson() }))
    put("color", color); put("note", note); put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toMaterial() = Material(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "material-${optLong("id")}" },
    name = optString("name"), subjectId = optLong("subjectId"),
    subjectSyncId = optString("subjectSyncId").takeIf { it.isNotEmpty() },
    totalPages = optInt("totalPages"), currentPage = optInt("currentPage"),
    totalProblems = optInt("totalProblems"),
    problemChapters = optJSONArray("problemChapters")?.let { arr ->
        (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.toProblemChapter() }
    } ?: emptyList(),
    problemRecords = optJSONArray("problemRecords")?.let { arr ->
        (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.toProblemSessionRecord() }
    } ?: emptyList(),
    color = if (has("color")) getInt("color") else null,
    note = optString("note").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun ProblemChapter.toJson() = JSONObject().apply {
    put("id", id); put("title", title); put("problemCount", problemCount)
}

private fun JSONObject.toProblemChapter() = ProblemChapter(
    id = optString("id", ""), title = optString("title", "章"), problemCount = optInt("problemCount", 0)
)

private fun ProblemSessionRecord.toJson() = JSONObject().apply {
    put("number", number); put("result", result.name); put("isWrong", isWrong)
    detail?.let { put("detail", it) }
    normalizedSubNumber?.let { put("subNumber", it) }
}

private fun JSONObject.toProblemSessionRecord(): ProblemSessionRecord? {
    val number = optInt("number")
    if (number == 0) return null
    val resultStr = optString("result", "CORRECT")
    val result = when (resultStr) {
        "CORRECT", "correct" -> ProblemResult.CORRECT
        "WRONG", "wrong" -> ProblemResult.WRONG
        "REVIEW_CORRECT", "reviewCorrect" -> ProblemResult.REVIEW_CORRECT
        else -> if (optBoolean("isWrong", false)) ProblemResult.WRONG else ProblemResult.CORRECT
    }
    return ProblemSessionRecord(
        number = number,
        result = result,
        detail = optString("detail").takeIf { it.isNotEmpty() },
        subNumber = optString("subNumber").takeIf { it.isNotEmpty() }
    )
}

internal fun StudySession.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("materialId", materialId); put("materialSyncId", materialSyncId)
    put("materialName", materialName); put("subjectId", subjectId); put("subjectSyncId", subjectSyncId)
    put("subjectName", subjectName); put("sessionType", sessionType.name); put("startTime", startTime); put("endTime", endTime)
    put("intervals", JSONArray(effectiveIntervals.map { it.toJson() }))
    if (rating != null) put("rating", rating)
    put("note", note)
    if (problemStart != null) put("problemStart", problemStart)
    if (problemEnd != null) put("problemEnd", problemEnd)
    if (wrongProblemCount != null) put("wrongProblemCount", wrongProblemCount)
    if (problemRecords.isNotEmpty()) put("problemRecords", JSONArray(problemRecords.map { it.toJson() }))
    put("createdAt", createdAt); put("updatedAt", updatedAt); put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toStudySession() = StudySession(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "session-${optLong("id")}" },
    materialId = if (has("materialId") && !isNull("materialId")) getLong("materialId") else null,
    materialSyncId = optString("materialSyncId").takeIf { it.isNotEmpty() },
    materialName = optString("materialName"), subjectId = optLong("subjectId"),
    subjectSyncId = optString("subjectSyncId").takeIf { it.isNotEmpty() },
    subjectName = optString("subjectName"),
    sessionType = try { com.studyapp.domain.model.StudySessionType.valueOf(optString("sessionType", "STOPWATCH")) } catch (_: Exception) { com.studyapp.domain.model.StudySessionType.STOPWATCH },
    startTime = optLong("startTime"), endTime = optLong("endTime"),
    intervals = optJSONArray("intervals")?.let { arr ->
        (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.toStudySessionInterval() }
    } ?: emptyList(),
    rating = optNullableInt("rating"),
    note = optString("note").takeIf { it.isNotEmpty() },
    problemStart = optNullableInt("problemStart"),
    problemEnd = optNullableInt("problemEnd"),
    wrongProblemCount = optNullableInt("wrongProblemCount"),
    problemRecords = optJSONArray("problemRecords")?.let { arr ->
        (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.toProblemSessionRecord() }
    } ?: emptyList(),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

private fun StudySessionInterval.toJson() = JSONObject().apply {
    put("startTime", startTime); put("endTime", endTime)
}

private fun JSONObject.toStudySessionInterval() = StudySessionInterval(
    startTime = optLong("startTime"), endTime = optLong("endTime")
)

internal fun Goal.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("type", type.name); put("targetMinutes", targetMinutes)
    put("dayOfWeek", dayOfWeek?.name); put("weekStartDay", weekStartDay.name)
    put("isActive", isActive); put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toGoal() = Goal(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "goal-${optLong("id")}" },
    type = com.studyapp.domain.model.GoalType.valueOf(optString("type", "DAILY")),
    targetMinutes = optInt("targetMinutes"),
    dayOfWeek = optString("dayOfWeek").takeIf { it.isNotEmpty() }?.let { StudyWeekday.valueOf(it) },
    weekStartDay = try { StudyWeekday.valueOf(optString("weekStartDay", "MONDAY")) } catch (_: Exception) { StudyWeekday.MONDAY },
    isActive = optBoolean("isActive", true),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun Exam.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("name", name); put("date", date)
    put("note", note); put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toExam() = Exam(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "exam-${optLong("id")}" },
    name = optString("name"), date = optLong("date"),
    note = optString("note").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun StudyPlan.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("name", name); put("startDate", startDate); put("endDate", endDate)
    put("isActive", isActive); put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toStudyPlan() = StudyPlan(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "plan-${optLong("id")}" },
    name = optString("name"), startDate = optLong("startDate"), endDate = optLong("endDate"),
    isActive = optBoolean("isActive", true),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun PlanItem.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("planId", planId); put("planSyncId", planSyncId)
    put("subjectId", subjectId); put("subjectSyncId", subjectSyncId); put("dayOfWeek", dayOfWeek.name)
    put("targetMinutes", targetMinutes); put("actualMinutes", actualMinutes); put("timeSlot", timeSlot)
    put("createdAt", createdAt); put("updatedAt", updatedAt); put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toPlanItem() = PlanItem(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "plan-item-${optLong("id")}" },
    planId = optLong("planId"), planSyncId = optString("planSyncId").takeIf { it.isNotEmpty() },
    subjectId = optLong("subjectId"), subjectSyncId = optString("subjectSyncId").takeIf { it.isNotEmpty() },
    dayOfWeek = try { StudyWeekday.valueOf(optString("dayOfWeek", "MONDAY")) } catch (_: Exception) { StudyWeekday.MONDAY },
    targetMinutes = optInt("targetMinutes"), actualMinutes = optInt("actualMinutes"),
    timeSlot = optString("timeSlot").takeIf { it.isNotEmpty() },
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun TimetablePeriod.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("name", name); put("startMinute", startMinute); put("endMinute", endMinute)
    put("sortOrder", sortOrder); put("isActive", isActive); put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toTimetablePeriod() = TimetablePeriod(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "period-${optLong("id")}" },
    name = optString("name"), startMinute = optInt("startMinute"), endMinute = optInt("endMinute"),
    sortOrder = optInt("sortOrder"), isActive = optBoolean("isActive", true),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun TimetableEntry.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("termId", termId); put("termSyncId", termSyncId)
    put("dayOfWeek", dayOfWeek.name); put("periodId", periodId); put("periodSyncId", periodSyncId)
    put("subjectName", subjectName); put("courseName", courseName); put("roomName", roomName)
    put("validFromDate", validFromDate); put("validToDate", validToDate)
    put("createdAt", createdAt); put("updatedAt", updatedAt); put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toTimetableEntry() = TimetableEntry(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "entry-${optLong("id")}" },
    termId = optNullableLong("termId"), termSyncId = optString("termSyncId").takeIf { it.isNotEmpty() },
    dayOfWeek = try { StudyWeekday.valueOf(optString("dayOfWeek", "MONDAY")) } catch (_: Exception) { StudyWeekday.MONDAY },
    periodId = optLong("periodId"), periodSyncId = optString("periodSyncId").takeIf { it.isNotEmpty() },
    subjectName = optString("subjectName"), courseName = optString("courseName").takeIf { it.isNotEmpty() },
    roomName = optString("roomName").takeIf { it.isNotEmpty() },
    validFromDate = optNullableLong("validFromDate"), validToDate = optNullableLong("validToDate"),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun TimetableTerm.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("name", name); put("startDate", startDate); put("endDate", endDate)
    put("isActive", isActive); put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toTimetableTerm() = TimetableTerm(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "term-${optLong("id")}" },
    name = optString("name"), startDate = optLong("startDate"), endDate = optLong("endDate"),
    isActive = optBoolean("isActive", true),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun TimetableReviewRecord.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("termId", termId); put("termSyncId", termSyncId)
    put("entryId", entryId); put("entrySyncId", entrySyncId); put("periodId", periodId); put("periodSyncId", periodSyncId)
    put("occurrenceDate", occurrenceDate); put("dayOfWeek", dayOfWeek.name); put("periodName", periodName)
    put("periodStartMinute", periodStartMinute); put("periodEndMinute", periodEndMinute)
    put("subjectName", subjectName); put("courseName", courseName); put("roomName", roomName)
    put("isReviewed", isReviewed); put("note", note); put("isExcluded", isExcluded); put("reviewedAt", reviewedAt)
    put("createdAt", createdAt); put("updatedAt", updatedAt); put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toTimetableReviewRecord() = TimetableReviewRecord(
    id = optLong("id"), syncId = optString("syncId").ifEmpty { "review-${optLong("id")}" },
    termId = optLong("termId"), termSyncId = optString("termSyncId").takeIf { it.isNotEmpty() },
    entryId = optLong("entryId"), entrySyncId = optString("entrySyncId").takeIf { it.isNotEmpty() },
    periodId = optLong("periodId"), periodSyncId = optString("periodSyncId").takeIf { it.isNotEmpty() },
    occurrenceDate = optLong("occurrenceDate"),
    dayOfWeek = try { StudyWeekday.valueOf(optString("dayOfWeek", "MONDAY")) } catch (_: Exception) { StudyWeekday.MONDAY },
    periodName = optString("periodName"), periodStartMinute = optInt("periodStartMinute"), periodEndMinute = optInt("periodEndMinute"),
    subjectName = optString("subjectName"), courseName = optString("courseName").takeIf { it.isNotEmpty() },
    roomName = optString("roomName").takeIf { it.isNotEmpty() },
    isReviewed = optBoolean("isReviewed", false), note = optString("note").takeIf { it.isNotEmpty() },
    isExcluded = optBoolean("isExcluded", false), reviewedAt = optNullableLong("reviewedAt"),
    createdAt = optLong("createdAt", System.currentTimeMillis()),
    updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
    deletedAt = optNullableLong("deletedAt"), lastSyncedAt = optNullableLong("lastSyncedAt")
)

internal fun ProblemReviewRecord.toJson() = JSONObject().apply {
    put("id", id); put("syncId", syncId); put("problemId", problemId)
    put("materialId", materialId); put("materialSyncId", materialSyncId)
    put("problemNumber", problemNumber); put("reviewedAt", reviewedAt)
    put("rating", rating.wireName); put("nextReviewDate", nextReviewDate)
    put("consecutiveCorrectCount", consecutiveCorrectCount); put("wrongCount", wrongCount)
    put("createdAt", createdAt); put("updatedAt", updatedAt)
    put("deletedAt", deletedAt); put("lastSyncedAt", lastSyncedAt)
}

internal fun JSONObject.toProblemReviewRecord(): ProblemReviewRecord? {
    val materialId = optLong("materialId")
    val problemNumber = optInt("problemNumber")
    if (materialId == 0L || problemNumber == 0) return null
    return ProblemReviewRecord(
        id = optLong("id"),
        syncId = optString("syncId").ifEmpty { "problem-review-${optLong("id")}" },
        problemId = optString("problemId").ifEmpty { ProblemReviewRecord.problemId(materialId, problemNumber) },
        materialId = materialId,
        materialSyncId = optString("materialSyncId").takeIf { it.isNotEmpty() },
        problemNumber = problemNumber,
        reviewedAt = optLong("reviewedAt"),
        rating = ProblemReviewRating.fromWireName(optString("rating", "again")),
        nextReviewDate = optLong("nextReviewDate"),
        consecutiveCorrectCount = optInt("consecutiveCorrectCount"),
        wrongCount = optInt("wrongCount"),
        createdAt = optLong("createdAt", System.currentTimeMillis()),
        updatedAt = optLong("updatedAt", optLong("createdAt", System.currentTimeMillis())),
        deletedAt = optNullableLong("deletedAt"),
        lastSyncedAt = optNullableLong("lastSyncedAt")
    )
}

private fun JSONObject.optNullableLong(key: String): Long? {
    if (!has(key) || isNull(key)) return null
    return optLong(key)
}

private fun JSONObject.optNullableInt(key: String): Int? {
    if (!has(key) || isNull(key)) return null
    return optInt(key)
}

class ExportImportDataUseCase @Inject constructor(
    private val subjectRepository: SubjectRepository,
    private val materialRepository: MaterialRepository,
    private val studySessionRepository: StudySessionRepository,
    private val goalRepository: GoalRepository,
    private val examRepository: ExamRepository,
    private val planRepository: PlanRepository,
    private val timetableRepository: TimetableRepository,
    private val studyDatabase: StudyDatabase,
    private val writeLock: AppDataWriteLock
) {
    suspend fun exportToJson(): Result<String> {
        return writeLock.withLock { exportToJsonWithoutWriteLock() }
    }

    suspend fun exportAppDataWithoutWriteLock(): AppData = snapshotAppData()

    suspend fun importFromJson(jsonString: String): Result<Unit> {
        return writeLock.withLock { importFromJsonWithoutWriteLock(jsonString) }
    }

    suspend fun importFromJsonWithoutWriteLock(jsonString: String): Result<Unit> {
        Log.d(TAG, "Starting data import")
        return try {
            val appData = AppData.fromJson(JSONObject(jsonString))
            studyDatabase.withTransaction {
                clearAllDataForImport()
                insertAppDataForImport(appData)
            }
            Log.i(TAG, "Data import completed")
            Result.Success(Unit)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to import data", e)
            Result.Error(e, "データのインポートに失敗しました")
        }
    }

    suspend fun deleteAllData(): Result<Unit> {
        return writeLock.withLock {
            try {
                studyDatabase.withTransaction { clearAllDataForImport() }
                Result.Success(Unit)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to delete all data", e)
                Result.Error(e, "データの削除に失敗しました")
            }
        }
    }

    private suspend fun exportToJsonWithoutWriteLock(): Result<String> {
        return try {
            val appData = snapshotAppData()
            Result.Success(appData.toJson().toString(2))
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
        val periodDao = studyDatabase.timetablePeriodDao()
        val termDao = studyDatabase.timetableTermDao()
        val entryDao = studyDatabase.timetableEntryDao()
        val reviewDao = studyDatabase.timetableReviewRecordDao()
        val problemReviewDao = studyDatabase.problemReviewRecordDao()

        val subjectEntities = subjectDao.getAllSubjectsForSync()
        val subjects = subjectEntities.map { it.toDomain() }
        val subjectsById = subjectEntities.associateBy { it.id }

        val materialEntities = materialDao.getAllMaterialsForSync()
        val materials = materialEntities.map { it.toDomain() }
        val materialsById = materials.associateBy { it.id }

        val sessions = studySessionDao.getAllSessionsForSyncWithNames().map { row ->
            row.toDomain()
        }
        val goals = goalDao.getAllGoalsForSync().map { it.toDomain() }
        val exams = examDao.getAllExamsForSync().map { it.toDomain() }
        val planEntities = planDao.getAllPlansForSync()
        val plans = planEntities.map { plan ->
            PlanData(
                plan = plan.toDomain(),
                items = planDao.getPlanItemsForSync(plan.id).map { it.toDomain() }
            )
        }

        val timetablePeriods = periodDao.getAllActiveForSync().map { it.toDomain() }
        val timetableTerms = termDao.getAllForSync().map { it.toDomain() }
        val timetableEntries = entryDao.getAllForSync().map { it.toDomain() }
        val timetableReviewRecords = reviewDao.getAllForSync().map { it.toDomain() }
        val problemReviewRecords = problemReviewDao.getAllForSync().map { it.toDomain() }

        return AppData(
            subjects = subjects, materials = materials, sessions = sessions,
            goals = goals, exams = exams, plans = plans,
            timetablePeriods = timetablePeriods, timetableEntries = timetableEntries,
            timetableTerms = timetableTerms, timetableReviewRecords = timetableReviewRecords,
            problemReviewRecords = problemReviewRecords,
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
        val periodDao = studyDatabase.timetablePeriodDao()
        val termDao = studyDatabase.timetableTermDao()
        val entryDao = studyDatabase.timetableEntryDao()
        val reviewDao = studyDatabase.timetableReviewRecordDao()
        val problemReviewDao = studyDatabase.problemReviewRecordDao()

        problemReviewDao.deleteAllForImport()
        reviewDao.deleteAllForImport()
        entryDao.deleteAllForImport()
        termDao.deleteAllForImport()
        periodDao.deleteAllForImport()
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
        val periodDao = studyDatabase.timetablePeriodDao()
        val termDao = studyDatabase.timetableTermDao()
        val entryDao = studyDatabase.timetableEntryDao()
        val reviewDao = studyDatabase.timetableReviewRecordDao()
        val problemReviewDao = studyDatabase.problemReviewRecordDao()

        val subjectIdsBySyncId = linkedMapOf<String, Long>()
        appData.subjects.forEach { subject ->
            val newId = subjectDao.insertSubject(SubjectEntity(
                syncId = subject.syncId, name = subject.name, color = subject.color,
                icon = subject.icon?.name, createdAt = subject.createdAt, updatedAt = subject.updatedAt,
                deletedAt = subject.deletedAt, lastSyncedAt = subject.lastSyncedAt
            ))
            subjectIdsBySyncId[subject.syncId] = newId
        }

        val materialIdsBySyncId = linkedMapOf<String, Long>()
        appData.materials.forEach { material ->
            val resolvedSubjectId = subjectIdsBySyncId[material.subjectSyncId] ?: material.subjectId
            val newId = materialDao.insertMaterial(MaterialEntity(
                syncId = material.syncId, name = material.name, subjectId = resolvedSubjectId,
                subjectSyncId = material.subjectSyncId, totalPages = material.totalPages,
                currentPage = material.currentPage, totalProblems = material.totalProblems,
                problemChaptersJson = material.problemChapters.takeIf { it.isNotEmpty() }?.let { chapters ->
                    JSONArray(chapters.map { c -> JSONObject().apply { put("id", c.id); put("title", c.title); put("problemCount", c.problemCount) } }).toString()
                },
                problemRecordsJson = material.problemRecords.takeIf { it.isNotEmpty() }?.let { records ->
                    JSONArray(records.map { r -> JSONObject().apply { put("number", r.number); put("result", r.result.name); put("isWrong", r.isWrong); r.detail?.let { put("detail", it) } } }).toString()
                },
                color = material.color, note = material.note, createdAt = material.createdAt,
                updatedAt = material.updatedAt, deletedAt = material.deletedAt, lastSyncedAt = material.lastSyncedAt
            ))
            materialIdsBySyncId[material.syncId] = newId
        }

        appData.sessions.forEach { session ->
            val resolvedSubjectId = subjectIdsBySyncId[session.subjectSyncId] ?: session.subjectId
            val resolvedMaterialId = session.materialSyncId?.let { materialIdsBySyncId[it] } ?: session.materialId
            studySessionDao.insertSession(StudySessionEntity(
                syncId = session.syncId, materialId = resolvedMaterialId,
                materialSyncId = session.materialSyncId, subjectId = resolvedSubjectId,
                subjectSyncId = session.subjectSyncId, sessionType = session.sessionType,
                startTime = session.sessionStartTime, endTime = session.sessionEndTime,
                duration = session.duration, date = session.date,
                intervalsJson = session.intervals.takeIf { it.isNotEmpty() }?.let { intervals ->
                    JSONArray(intervals.map { it.toJson() }).toString()
                },
                rating = session.rating, note = session.note,
                problemStart = session.problemStart, problemEnd = session.problemEnd,
                wrongProblemCount = session.wrongProblemCount,
                problemRecordsJson = session.problemRecords.takeIf { it.isNotEmpty() }?.let { records ->
                    JSONArray(records.map { r -> JSONObject().apply { put("number", r.number); put("result", r.result.name); put("isWrong", r.isWrong); r.detail?.let { put("detail", it) } } }).toString()
                },
                createdAt = session.createdAt, updatedAt = session.updatedAt,
                deletedAt = session.deletedAt, lastSyncedAt = session.lastSyncedAt
            ))
        }

        appData.goals.forEach { goal ->
            goalDao.insertGoal(GoalEntity(
                syncId = goal.syncId, type = goal.type, targetMinutes = goal.targetMinutes,
                dayOfWeek = goal.dayOfWeek?.ordinal?.plus(1) ?: 0,
                weekStartDay = goal.weekStartDay.ordinal + 1,
                isActive = goal.isActive, createdAt = goal.createdAt, updatedAt = goal.updatedAt,
                deletedAt = goal.deletedAt, lastSyncedAt = goal.lastSyncedAt
            ))
        }

        appData.exams.forEach { exam ->
            examDao.insertExam(ExamEntity(
                syncId = exam.syncId, name = exam.name, date = exam.date * 86400000L,
                note = exam.note, createdAt = exam.createdAt, updatedAt = exam.updatedAt,
                deletedAt = exam.deletedAt, lastSyncedAt = exam.lastSyncedAt
            ))
        }

        val planIdsBySyncId = linkedMapOf<String, Long>()
        val activePlanSyncId = appData.plans.lastOrNull { it.plan.isActive && it.plan.deletedAt == null }?.plan?.syncId
        appData.plans.forEach { planData ->
            val plan = planData.plan
            val newId = planDao.insertPlan(PlanEntity(
                syncId = plan.syncId, name = plan.name, startDate = plan.startDate, endDate = plan.endDate,
                isActive = plan.syncId == activePlanSyncId, createdAt = plan.createdAt, updatedAt = plan.updatedAt,
                deletedAt = plan.deletedAt, lastSyncedAt = plan.lastSyncedAt
            ))
            planIdsBySyncId[plan.syncId] = newId
        }

        appData.plans.flatMap { it.items }.forEach { item ->
            val resolvedPlanId = planIdsBySyncId[item.planSyncId] ?: item.planId
            val resolvedSubjectId = subjectIdsBySyncId[item.subjectSyncId] ?: item.subjectId
            planDao.insertPlanItem(PlanItemEntity(
                syncId = item.syncId, planId = resolvedPlanId, planSyncId = item.planSyncId,
                subjectId = resolvedSubjectId, subjectSyncId = item.subjectSyncId,
                dayOfWeek = item.dayOfWeek.ordinal + 1, targetMinutes = item.targetMinutes,
                actualMinutes = item.actualMinutes, timeSlot = item.timeSlot,
                createdAt = item.createdAt, updatedAt = item.updatedAt,
                deletedAt = item.deletedAt, lastSyncedAt = item.lastSyncedAt
            ))
        }

        val periodIdsBySyncId = linkedMapOf<String, Long>()
        appData.timetablePeriods.forEach { period ->
            val newId = periodDao.insert(TimetablePeriodEntity(
                syncId = period.syncId, name = period.name, startMinute = period.startMinute,
                endMinute = period.endMinute, sortOrder = period.sortOrder, isActive = period.isActive,
                createdAt = period.createdAt, updatedAt = period.updatedAt,
                deletedAt = period.deletedAt, lastSyncedAt = period.lastSyncedAt
            ))
            periodIdsBySyncId[period.syncId] = newId
        }

        val termIdsBySyncId = linkedMapOf<String, Long>()
        appData.timetableTerms.forEach { term ->
            val newId = termDao.insert(TimetableTermEntity(
                syncId = term.syncId, name = term.name, startDate = term.startDate, endDate = term.endDate,
                isActive = term.isActive, createdAt = term.createdAt, updatedAt = term.updatedAt,
                deletedAt = term.deletedAt, lastSyncedAt = term.lastSyncedAt
            ))
            termIdsBySyncId[term.syncId] = newId
        }

        val entryIdsBySyncId = linkedMapOf<String, Long>()
        appData.timetableEntries.forEach { entry ->
            val resolvedPeriodId = periodIdsBySyncId[entry.periodSyncId] ?: entry.periodId
            val resolvedTermId = entry.termSyncId?.let { termIdsBySyncId[it] } ?: entry.termId
            val newId = entryDao.insert(TimetableEntryEntity(
                syncId = entry.syncId, termId = resolvedTermId, termSyncId = entry.termSyncId,
                dayOfWeek = entry.dayOfWeek.ordinal, periodId = resolvedPeriodId,
                periodSyncId = entry.periodSyncId, subjectName = entry.subjectName,
                courseName = entry.courseName, roomName = entry.roomName,
                validFromDate = entry.validFromDate, validToDate = entry.validToDate,
                createdAt = entry.createdAt, updatedAt = entry.updatedAt,
                deletedAt = entry.deletedAt, lastSyncedAt = entry.lastSyncedAt
            ))
            entryIdsBySyncId[entry.syncId] = newId
        }

        appData.timetableReviewRecords.forEach { record ->
            val resolvedEntryId = entryIdsBySyncId[record.entrySyncId] ?: record.entryId
            val resolvedPeriodId = periodIdsBySyncId[record.periodSyncId] ?: record.periodId
            val resolvedTermId = termIdsBySyncId[record.termSyncId] ?: record.termId
            reviewDao.insert(TimetableReviewRecordEntity(
                syncId = record.syncId, termId = resolvedTermId, termSyncId = record.termSyncId,
                entryId = resolvedEntryId, entrySyncId = record.entrySyncId,
                periodId = resolvedPeriodId, periodSyncId = record.periodSyncId,
                occurrenceDate = record.occurrenceDate, dayOfWeek = record.dayOfWeek.ordinal,
                periodName = record.periodName, periodStartMinute = record.periodStartMinute,
                periodEndMinute = record.periodEndMinute, subjectName = record.subjectName,
                courseName = record.courseName, roomName = record.roomName,
                isReviewed = record.isReviewed, note = record.note, isExcluded = record.isExcluded,
                reviewedAt = record.reviewedAt, createdAt = record.createdAt, updatedAt = record.updatedAt,
                deletedAt = record.deletedAt, lastSyncedAt = record.lastSyncedAt
            ))
        }

        appData.problemReviewRecords.forEach { record ->
            val resolvedMaterialId = record.materialSyncId?.let { materialIdsBySyncId[it] } ?: record.materialId
            problemReviewDao.insert(ProblemReviewRecordEntity(
                syncId = record.syncId,
                problemId = ProblemReviewRecord.problemId(resolvedMaterialId, record.problemNumber),
                materialId = resolvedMaterialId,
                materialSyncId = record.materialSyncId,
                problemNumber = record.problemNumber,
                reviewedAt = record.reviewedAt,
                rating = record.rating.wireName,
                nextReviewDate = record.nextReviewDate,
                consecutiveCorrectCount = record.consecutiveCorrectCount,
                wrongCount = record.wrongCount,
                createdAt = record.createdAt,
                updatedAt = record.updatedAt,
                deletedAt = record.deletedAt,
                lastSyncedAt = record.lastSyncedAt
            ))
        }
    }

    companion object {
        private const val TAG = "ExportImportDataUseCase"
    }
}

// Entity to Domain converters for snapshot
private fun SubjectEntity.toDomain() = Subject(
    id = id, syncId = syncId.ifEmpty { "subject-$id" }, name = name, color = color,
    icon = icon?.let { com.studyapp.domain.model.SubjectIcon.fromName(it) },
    createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun MaterialEntity.toDomain() = Material(
    id = id, syncId = syncId.ifEmpty { "material-$id" }, name = name, subjectId = subjectId,
    subjectSyncId = subjectSyncId, totalPages = totalPages, currentPage = currentPage,
    totalProblems = totalProblems,
    problemChapters = problemChaptersJson?.let { json ->
        try { JSONArray(json).let { arr -> (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.let { obj -> ProblemChapter(id = obj.optString("id", ""), title = obj.optString("title", "章"), problemCount = obj.optInt("problemCount", 0)) } } } } catch (_: Exception) { emptyList() }
    } ?: emptyList(),
    problemRecords = problemRecordsJson?.let { json ->
        try { JSONArray(json).let { arr -> (0 until arr.length()).mapNotNull { obj -> obj?.let { val o = arr.optJSONObject(it); ProblemSessionRecord(number = o.optInt("number"), result = when (o.optString("result", "CORRECT")) { "CORRECT", "correct" -> ProblemResult.CORRECT; "WRONG", "wrong" -> ProblemResult.WRONG; "REVIEW_CORRECT", "reviewCorrect" -> ProblemResult.REVIEW_CORRECT; else -> if (o.optBoolean("isWrong", false)) ProblemResult.WRONG else ProblemResult.CORRECT }, detail = o.optString("detail").takeIf { s -> s.isNotEmpty() }, subNumber = o.optString("subNumber").takeIf { s -> s.isNotEmpty() }) } } } } catch (_: Exception) { emptyList() }
    } ?: emptyList(),
    color = color, note = note, createdAt = createdAt, updatedAt = updatedAt,
    deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun StudySessionWithNames.toDomain() = StudySession(
    id = session.id, syncId = session.syncId.ifEmpty { "session-${session.id}" },
    materialId = session.materialId, materialSyncId = session.materialSyncId,
    materialName = materialName.orEmpty(), subjectId = session.subjectId,
    subjectSyncId = session.subjectSyncId, subjectName = subjectName,
    sessionType = session.sessionType, startTime = session.startTime, endTime = session.endTime,
    intervals = session.intervalsJson?.let { json ->
        try { JSONArray(json).let { arr -> (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.let { o -> StudySessionInterval(startTime = o.optLong("startTime"), endTime = o.optLong("endTime")) } } } } catch (_: Exception) { emptyList() }
    } ?: emptyList(),
    rating = session.rating, note = session.note,
    problemStart = session.problemStart, problemEnd = session.problemEnd,
    wrongProblemCount = session.wrongProblemCount,
    problemRecords = session.problemRecordsJson?.let { json ->
        try { JSONArray(json).let { arr -> (0 until arr.length()).mapNotNull { arr.optJSONObject(it)?.let { o -> ProblemSessionRecord(number = o.optInt("number"), result = when (o.optString("result", "CORRECT")) { "CORRECT", "correct" -> ProblemResult.CORRECT; "WRONG", "wrong" -> ProblemResult.WRONG; "REVIEW_CORRECT", "reviewCorrect" -> ProblemResult.REVIEW_CORRECT; else -> if (o.optBoolean("isWrong", false)) ProblemResult.WRONG else ProblemResult.CORRECT }, detail = o.optString("detail").takeIf { s -> s.isNotEmpty() }, subNumber = o.optString("subNumber").takeIf { s -> s.isNotEmpty() }) } } } } catch (_: Exception) { emptyList() }
    } ?: emptyList(),
    createdAt = session.createdAt, updatedAt = session.updatedAt,
    deletedAt = session.deletedAt, lastSyncedAt = session.lastSyncedAt
)

private fun GoalEntity.toDomain() = Goal(
    id = id, syncId = syncId.ifEmpty { "goal-$id" }, type = type, targetMinutes = targetMinutes,
    dayOfWeek = dayOfWeek.takeIf { it in 1..7 }?.let { StudyWeekday.entries[it - 1] },
    weekStartDay = StudyWeekday.entries.getOrNull(weekStartDay - 1) ?: StudyWeekday.MONDAY,
    isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
    deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun ExamEntity.toDomain() = Exam(
    id = id, syncId = syncId.ifEmpty { "exam-$id" }, name = name, date = date / 86400000L,
    note = note, createdAt = createdAt, updatedAt = updatedAt,
    deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun PlanEntity.toDomain() = StudyPlan(
    id = id, syncId = syncId.ifEmpty { "plan-$id" }, name = name, startDate = startDate, endDate = endDate,
    isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
    deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun PlanItemEntity.toDomain() = PlanItem(
    id = id, syncId = syncId.ifEmpty { "plan-item-$id" }, planId = planId, planSyncId = planSyncId,
    subjectId = subjectId, subjectSyncId = subjectSyncId,
    dayOfWeek = StudyWeekday.entries.getOrNull(dayOfWeek - 1) ?: StudyWeekday.MONDAY,
    targetMinutes = targetMinutes, actualMinutes = actualMinutes, timeSlot = timeSlot,
    createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun TimetablePeriodEntity.toDomain() = TimetablePeriod(
    id = id, syncId = syncId, name = name, startMinute = startMinute, endMinute = endMinute,
    sortOrder = sortOrder, isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
    deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun TimetableTermEntity.toDomain() = TimetableTerm(
    id = id, syncId = syncId, name = name, startDate = startDate, endDate = endDate,
    isActive = isActive, createdAt = createdAt, updatedAt = updatedAt,
    deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun TimetableEntryEntity.toDomain() = TimetableEntry(
    id = id, syncId = syncId, termId = termId, termSyncId = termSyncId,
    dayOfWeek = StudyWeekday.entries[dayOfWeek], periodId = periodId, periodSyncId = periodSyncId,
    subjectName = subjectName, courseName = courseName, roomName = roomName,
    validFromDate = validFromDate, validToDate = validToDate,
    createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun TimetableReviewRecordEntity.toDomain() = TimetableReviewRecord(
    id = id, syncId = syncId, termId = termId, termSyncId = termSyncId,
    entryId = entryId, entrySyncId = entrySyncId, periodId = periodId, periodSyncId = periodSyncId,
    occurrenceDate = occurrenceDate, dayOfWeek = StudyWeekday.entries[dayOfWeek],
    periodName = periodName, periodStartMinute = periodStartMinute, periodEndMinute = periodEndMinute,
    subjectName = subjectName, courseName = courseName, roomName = roomName,
    isReviewed = isReviewed, note = note, isExcluded = isExcluded, reviewedAt = reviewedAt,
    createdAt = createdAt, updatedAt = updatedAt, deletedAt = deletedAt, lastSyncedAt = lastSyncedAt
)

private fun ProblemReviewRecordEntity.toDomain() = ProblemReviewRecord(
    id = id,
    syncId = syncId,
    problemId = problemId,
    materialId = materialId,
    materialSyncId = materialSyncId,
    problemNumber = problemNumber,
    reviewedAt = reviewedAt,
    rating = ProblemReviewRating.fromWireName(rating),
    nextReviewDate = nextReviewDate,
    consecutiveCorrectCount = consecutiveCorrectCount,
    wrongCount = wrongCount,
    createdAt = createdAt,
    updatedAt = updatedAt,
    deletedAt = deletedAt,
    lastSyncedAt = lastSyncedAt
)
