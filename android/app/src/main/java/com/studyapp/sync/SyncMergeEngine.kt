package com.studyapp.sync

import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.PlanData

object SyncMergeEngine {
    fun merge(local: AppData, remote: AppData): AppData {
        return AppData(
            schemaVersion = maxOf(local.schemaVersion, remote.schemaVersion),
            supportsProblemRecords = local.supportsProblemRecords || remote.supportsProblemRecords,
            subjects = merge(local.subjects, remote.subjects, Subject::syncId, Subject::updatedAt, Subject::deletedAt),
            materials = mergeMaterials(local.materials, remote.materials),
            sessions = mergeSessions(local.sessions, remote.sessions),
            goals = merge(local.goals, remote.goals, Goal::syncId, Goal::updatedAt, Goal::deletedAt),
            exams = merge(local.exams, remote.exams, Exam::syncId, Exam::updatedAt, Exam::deletedAt),
            plans = mergePlans(local.plans, remote.plans),
            timetablePeriods = merge(
                local.timetablePeriods,
                remote.timetablePeriods,
                TimetablePeriod::syncId,
                TimetablePeriod::updatedAt,
                TimetablePeriod::deletedAt
            ),
            timetableEntries = merge(
                local.timetableEntries,
                remote.timetableEntries,
                TimetableEntry::syncId,
                TimetableEntry::updatedAt,
                TimetableEntry::deletedAt
            ),
            timetableTerms = merge(
                local.timetableTerms,
                remote.timetableTerms,
                TimetableTerm::syncId,
                TimetableTerm::updatedAt,
                TimetableTerm::deletedAt
            ),
            timetableReviewRecords = merge(
                local.timetableReviewRecords,
                remote.timetableReviewRecords,
                TimetableReviewRecord::syncId,
                TimetableReviewRecord::updatedAt,
                TimetableReviewRecord::deletedAt
            ),
            problemReviewRecords = merge(
                local.problemReviewRecords,
                remote.problemReviewRecords,
                ProblemReviewRecord::syncId,
                ProblemReviewRecord::updatedAt,
                ProblemReviewRecord::deletedAt
            ),
            exportDate = maxOf(local.exportDate, remote.exportDate)
        )
    }

    fun mergeMaterials(local: List<Material>, remote: List<Material>): List<Material> {
        return merge(local, remote, Material::syncId, Material::updatedAt, Material::deletedAt) { selected, other ->
            if (selected.deletedAt != null) {
                selected
            } else {
                selected.copy(
                    problemChapters = selected.problemChapters.ifEmpty { other.problemChapters },
                    problemRecords = selected.problemRecords.ifEmpty { other.problemRecords },
                    totalProblems = selected.totalProblems.takeIf { it > 0 } ?: other.totalProblems
                )
            }
        }
    }

    fun mergeSessions(local: List<StudySession>, remote: List<StudySession>): List<StudySession> {
        return merge(local, remote, StudySession::syncId, StudySession::updatedAt, StudySession::deletedAt) { selected, other ->
            if (selected.deletedAt != null) {
                selected
            } else {
                selected.copy(
                    problemRecords = selected.problemRecords.ifEmpty { other.problemRecords },
                    problemStart = selected.problemStart ?: other.problemStart,
                    problemEnd = selected.problemEnd ?: other.problemEnd,
                    wrongProblemCount = selected.wrongProblemCount ?: other.wrongProblemCount
                )
            }
        }
    }

    fun mergePlans(local: List<PlanData>, remote: List<PlanData>): List<PlanData> {
        val plans = merge(local.map { it.plan }, remote.map { it.plan }, StudyPlan::syncId, StudyPlan::updatedAt, StudyPlan::deletedAt)
        val items = merge(local.flatMap { it.items }, remote.flatMap { it.items }, PlanItem::syncId, PlanItem::updatedAt, PlanItem::deletedAt)
        val grouped = items.groupBy { it.planSyncId }
        return plans.map { plan -> PlanData(plan = plan, items = grouped[plan.syncId].orEmpty()) }
    }

    fun <T> merge(
        lhs: List<T>,
        rhs: List<T>,
        key: (T) -> String,
        updatedAt: (T) -> Long,
        deletedAt: (T) -> Long?
    ): List<T> = merge(lhs, rhs, key, updatedAt, deletedAt) { selected, _ -> selected }

    fun <T> merge(
        lhs: List<T>,
        rhs: List<T>,
        key: (T) -> String,
        updatedAt: (T) -> Long,
        deletedAt: (T) -> Long?,
        preserveDetails: (T, T) -> T
    ): List<T> {
        val result = linkedMapOf<String, T>()
        (lhs + rhs).forEach { item ->
            val id = key(item)
            val existing = result[id]
            if (existing == null) {
                result[id] = item
            } else {
                val existingDelete = deletedAt(existing) ?: Long.MIN_VALUE
                val candidateDelete = deletedAt(item) ?: Long.MIN_VALUE
                result[id] = when {
                    candidateDelete > updatedAt(existing) && candidateDelete >= existingDelete -> item
                    existingDelete > updatedAt(item) && existingDelete >= candidateDelete -> existing
                    updatedAt(item) >= updatedAt(existing) -> preserveDetails(item, existing)
                    else -> preserveDetails(existing, item)
                }
            }
        }
        return result.values.toList()
    }

    fun markSynced(appData: AppData, timestamp: Long): AppData {
        return appData.copy(
            schemaVersion = appData.schemaVersion,
            supportsProblemRecords = appData.supportsProblemRecords,
            subjects = appData.subjects.map { it.copy(lastSyncedAt = timestamp) },
            materials = appData.materials.map { it.copy(lastSyncedAt = timestamp) },
            sessions = appData.sessions.map { it.copy(lastSyncedAt = timestamp) },
            goals = appData.goals.map { it.copy(lastSyncedAt = timestamp) },
            exams = appData.exams.map { it.copy(lastSyncedAt = timestamp) },
            plans = appData.plans.map { planData ->
                planData.copy(
                    plan = planData.plan.copy(lastSyncedAt = timestamp),
                    items = planData.items.map { it.copy(lastSyncedAt = timestamp) }
                )
            },
            timetablePeriods = appData.timetablePeriods.map { it.copy(lastSyncedAt = timestamp) },
            timetableEntries = appData.timetableEntries.map { it.copy(lastSyncedAt = timestamp) },
            timetableTerms = appData.timetableTerms.map { it.copy(lastSyncedAt = timestamp) },
            timetableReviewRecords = appData.timetableReviewRecords.map { it.copy(lastSyncedAt = timestamp) },
            problemReviewRecords = appData.problemReviewRecords.map { it.copy(lastSyncedAt = timestamp) },
            exportDate = timestamp
        )
    }
}

data class SyncProgressSummary(
    val sessionProblemRecords: Int,
    val materialProblemRecords: Int,
    val materialsWithProblemTotals: Int,
    val activeProblemReviewRecords: Int
) {
    val hasProblemProgress: Boolean
        get() = sessionProblemRecords > 0 ||
            materialProblemRecords > 0 ||
            activeProblemReviewRecords > 0 ||
            materialsWithProblemTotals > 0

    constructor(appData: AppData) : this(
        sessionProblemRecords = appData.sessions.sumOf { it.problemRecords.size },
        materialProblemRecords = appData.materials.sumOf { it.problemRecords.size },
        materialsWithProblemTotals = appData.materials.count { it.effectiveTotalProblems > 0 },
        activeProblemReviewRecords = appData.problemReviewRecords.count { it.deletedAt == null }
    )

    fun logDescription(): String {
        return "sessionProblemRecords=$sessionProblemRecords materialProblemRecords=$materialProblemRecords " +
            "activeProblemReviewRecords=$activeProblemReviewRecords materialsWithProblemTotals=$materialsWithProblemTotals"
    }
}

object SyncProgressGuard {
    fun wouldLoseProgress(from: AppData, to: AppData): Boolean {
        val before = SyncProgressSummary(from)
        val after = SyncProgressSummary(to)
        if (!before.hasProblemProgress) return false
        return after.sessionProblemRecords < before.sessionProblemRecords ||
            after.materialProblemRecords < before.materialProblemRecords ||
            after.activeProblemReviewRecords < before.activeProblemReviewRecords ||
            after.materialsWithProblemTotals < before.materialsWithProblemTotals
    }
}
