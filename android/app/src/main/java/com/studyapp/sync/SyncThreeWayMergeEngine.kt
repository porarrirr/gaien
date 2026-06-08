package com.studyapp.sync

import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.ProblemChapter
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.Subject
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.PlanData
import com.studyapp.domain.usecase.toExam
import com.studyapp.domain.usecase.toGoal
import com.studyapp.domain.usecase.toJson
import com.studyapp.domain.usecase.toMaterial
import com.studyapp.domain.usecase.toPlanItem
import com.studyapp.domain.usecase.toProblemReviewRecord
import com.studyapp.domain.usecase.toStudyPlan
import com.studyapp.domain.usecase.toStudySession
import com.studyapp.domain.usecase.toSubject
import com.studyapp.domain.usecase.toTimetableEntry
import com.studyapp.domain.usecase.toTimetablePeriod
import com.studyapp.domain.usecase.toTimetableReviewRecord
import com.studyapp.domain.usecase.toTimetableTerm
import java.security.MessageDigest
import org.json.JSONObject

data class SyncThreeWayMergeOutcome(
    val merged: AppData,
    val conflicts: List<SyncConflict>,
    val usedLegacyTwoWayFallback: Boolean
)

object SyncThreeWayMergeEngine {
    fun merge(
        base: AppData?,
        local: AppData,
        remoteEnvelopes: List<SyncEntityEnvelope>,
        now: Long = System.currentTimeMillis()
    ): SyncThreeWayMergeOutcome {
        val remotePartial = SyncDeltaSerializer.partialAppData(remoteEnvelopes, local.exportDate)
        if (base == null) {
            return SyncThreeWayMergeOutcome(
                merged = SyncMergeEngine.merge(local, remotePartial),
                conflicts = emptyList(),
                usedLegacyTwoWayFallback = true
            )
        }

        val conflicts = mutableListOf<SyncConflict>()
        val merged = AppData(
            schemaVersion = maxOf(local.schemaVersion, remotePartial.schemaVersion, base.schemaVersion),
            supportsProblemRecords = local.supportsProblemRecords || remotePartial.supportsProblemRecords || base.supportsProblemRecords,
            subjects = mergeSubjects(base.subjects, local.subjects, remotePartial.subjects, conflicts, now),
            materials = mergeMaterials(base.materials, local.materials, remotePartial.materials, conflicts, now),
            sessions = mergeSessions(base.sessions, local.sessions, remotePartial.sessions, conflicts, now),
            goals = mergeEntities(base.goals, local.goals, remotePartial.goals, SyncEntityKind.GOAL, { it.type.name }, conflicts, now, Goal::syncId, Goal::syncId, Goal::updatedAt, Goal::deletedAt) { it.toJson().toString() },
            exams = mergeEntities(base.exams, local.exams, remotePartial.exams, SyncEntityKind.EXAM, Exam::name, conflicts, now, Exam::syncId, Exam::syncId, Exam::updatedAt, Exam::deletedAt) { it.toJson().toString() },
            plans = mergePlans(base.plans, local.plans, remotePartial.plans, conflicts, now),
            timetablePeriods = mergeEntities(base.timetablePeriods, local.timetablePeriods, remotePartial.timetablePeriods, SyncEntityKind.TIMETABLE_PERIOD, TimetablePeriod::name, conflicts, now, TimetablePeriod::syncId, TimetablePeriod::syncId, TimetablePeriod::updatedAt, TimetablePeriod::deletedAt) { it.toJson().toString() },
            timetableEntries = mergeEntities(base.timetableEntries, local.timetableEntries, remotePartial.timetableEntries, SyncEntityKind.TIMETABLE_ENTRY, TimetableEntry::subjectName, conflicts, now, TimetableEntry::syncId, TimetableEntry::syncId, TimetableEntry::updatedAt, TimetableEntry::deletedAt) { it.toJson().toString() },
            timetableTerms = mergeEntities(base.timetableTerms, local.timetableTerms, remotePartial.timetableTerms, SyncEntityKind.TIMETABLE_TERM, TimetableTerm::name, conflicts, now, TimetableTerm::syncId, TimetableTerm::syncId, TimetableTerm::updatedAt, TimetableTerm::deletedAt) { it.toJson().toString() },
            timetableReviewRecords = mergeEntities(base.timetableReviewRecords, local.timetableReviewRecords, remotePartial.timetableReviewRecords, SyncEntityKind.TIMETABLE_REVIEW_RECORD, TimetableReviewRecord::subjectName, conflicts, now, TimetableReviewRecord::syncId, TimetableReviewRecord::syncId, TimetableReviewRecord::updatedAt, TimetableReviewRecord::deletedAt) { it.toJson().toString() },
            problemReviewRecords = mergeProblemReviews(base.problemReviewRecords, local.problemReviewRecords, remotePartial.problemReviewRecords, conflicts, now),
            exportDate = maxOf(local.exportDate, remotePartial.exportDate, base.exportDate, now)
        )

        return SyncThreeWayMergeOutcome(
            merged = merged,
            conflicts = conflicts,
            usedLegacyTwoWayFallback = false
        )
    }

    fun applyResolutions(
        resolutions: List<SyncConflictResolution>,
        local: AppData,
        conflicts: List<SyncConflict>,
        resolvedAt: Long = System.currentTimeMillis()
    ): AppData {
        var result = local
        val conflictMap = conflicts.associateBy { it.documentId }
        for (resolution in resolutions) {
            val documentId = "${resolution.kind.rawValue}-${resolution.syncId}"
            val conflict = conflictMap[documentId] ?: continue
            val json = when (resolution.strategy) {
                SyncConflictResolutionStrategy.KEEP_LOCAL -> conflict.localJson
                SyncConflictResolutionStrategy.KEEP_REMOTE -> conflict.remoteJson
                SyncConflictResolutionStrategy.KEEP_MERGED -> conflict.suggestedMergedJson
            }
            result = replaceEntity(result, resolution.kind, resolution.syncId, jsonWithUpdatedAt(json, resolvedAt))
        }
        return result
    }

    private fun mergeSubjects(
        base: List<Subject>,
        local: List<Subject>,
        remote: List<Subject>,
        conflicts: MutableList<SyncConflict>,
        now: Long
    ): List<Subject> = mergeEntities(base, local, remote, SyncEntityKind.SUBJECT, Subject::name, conflicts, now, Subject::syncId, Subject::syncId, Subject::updatedAt, Subject::deletedAt) { it.toJson().toString() }

    private fun mergeMaterials(
        base: List<Material>,
        local: List<Material>,
        remote: List<Material>,
        conflicts: MutableList<SyncConflict>,
        now: Long
    ): List<Material> {
        val baseMap = base.associateBy(Material::syncId)
        val localMap = local.associateBy(Material::syncId)
        val remoteMap = remote.associateBy(Material::syncId)
        val ids = baseMap.keys + localMap.keys + remoteMap.keys
        return ids.mapNotNull { syncId ->
            val localValue = localMap[syncId]
            val remoteValue = remoteMap[syncId]
            when {
                localValue != null && remoteValue != null ->
                    mergeMaterial(baseMap[syncId], localValue, remoteValue, conflicts, now)
                localValue != null -> localValue
                else -> remoteValue
            }
        }
    }

    private fun mergeMaterial(
        base: Material?,
        local: Material,
        remote: Material,
        conflicts: MutableList<SyncConflict>,
        now: Long
    ): Material {
        deletionConflict(base, local, remote, SyncEntityKind.MATERIAL, local.name, now)?.let { conflict ->
            conflicts += conflict
            return if (local.deletedAt == null) local else remote
        }

        val baseValue = base ?: local
        val conflictFields = mutableListOf<SyncConflictField>()
        if (scalarConflict(baseValue.name, local.name, remote.name)) conflictFields += SyncConflictField.NAME
        if (scalarConflict(baseValue.note.orEmpty(), local.note.orEmpty(), remote.note.orEmpty())) {
            conflictFields += SyncConflictField.NOTE
        }

        val merged = pickNewer(local, remote).copy(
            currentPage = maxOf(local.currentPage, remote.currentPage, baseValue.currentPage),
            totalPages = maxOf(local.totalPages, remote.totalPages, baseValue.totalPages),
            totalProblems = maxOf(local.totalProblems, remote.totalProblems, baseValue.totalProblems),
            problemChapters = unionChapters(baseValue.problemChapters, local.problemChapters, remote.problemChapters),
            problemRecords = unionProblemRecords(baseValue.problemRecords, local.problemRecords, remote.problemRecords)
        )

        if (conflictFields.isNotEmpty()) {
            conflicts += makeMaterialConflict(merged, local, remote, base, conflictFields, "教材「${local.name}」の内容が端末間で異なります", now)
            return local
        }
        return merged
    }

    private fun mergeSessions(
        base: List<StudySession>,
        local: List<StudySession>,
        remote: List<StudySession>,
        conflicts: MutableList<SyncConflict>,
        now: Long
    ): List<StudySession> {
        val baseMap = base.associateBy(StudySession::syncId)
        val localMap = local.associateBy(StudySession::syncId)
        val remoteMap = remote.associateBy(StudySession::syncId)
        val ids = baseMap.keys + localMap.keys + remoteMap.keys
        return ids.mapNotNull { syncId ->
            val localValue = localMap[syncId]
            val remoteValue = remoteMap[syncId]
            if (localValue == null) return@mapNotNull remoteValue
            if (remoteValue == null) return@mapNotNull localValue

            deletionConflict(baseMap[syncId], localValue, remoteValue, SyncEntityKind.SESSION, localValue.subjectName, now)?.let { conflict ->
                conflicts += conflict
                return@mapNotNull if (localValue.deletedAt == null) localValue else remoteValue
            }

            val baseValue = baseMap[syncId] ?: localValue
            val newer = pickNewer(localValue, remoteValue)
            newer.copy(
                problemRecords = unionProblemRecords(baseValue.problemRecords, localValue.problemRecords, remoteValue.problemRecords),
                problemStart = newer.problemStart ?: localValue.problemStart ?: remoteValue.problemStart ?: baseValue.problemStart,
                problemEnd = newer.problemEnd ?: localValue.problemEnd ?: remoteValue.problemEnd ?: baseValue.problemEnd,
                wrongProblemCount = maxOptional(localValue.wrongProblemCount, remoteValue.wrongProblemCount, baseValue.wrongProblemCount)
            )
        }
    }

    private fun mergeProblemReviews(
        base: List<ProblemReviewRecord>,
        local: List<ProblemReviewRecord>,
        remote: List<ProblemReviewRecord>,
        conflicts: MutableList<SyncConflict>,
        now: Long
    ): List<ProblemReviewRecord> {
        val baseMap = base.associateBy(ProblemReviewRecord::syncId)
        val localMap = local.associateBy(ProblemReviewRecord::syncId)
        val remoteMap = remote.associateBy(ProblemReviewRecord::syncId)
        val ids = baseMap.keys + localMap.keys + remoteMap.keys
        return ids.mapNotNull { syncId ->
            val localValue = localMap[syncId]
            val remoteValue = remoteMap[syncId]
            if (localValue == null) return@mapNotNull remoteValue
            if (remoteValue == null) return@mapNotNull localValue

            if (localValue.deletedAt != null || remoteValue.deletedAt != null) {
                return@mapNotNull SyncMergeEngine.merge(
                    listOf(localValue),
                    listOf(remoteValue),
                    ProblemReviewRecord::syncId,
                    ProblemReviewRecord::updatedAt,
                    ProblemReviewRecord::deletedAt
                ).firstOrNull()
            }

            if (localValue.reviewedAt == remoteValue.reviewedAt) {
                return@mapNotNull if (localValue.updatedAt >= remoteValue.updatedAt) localValue else remoteValue
            }

            val winner = if (localValue.reviewedAt >= remoteValue.reviewedAt) localValue else remoteValue
            val baseValue = baseMap[syncId]
            if (baseValue != null &&
                localValue.reviewedAt != baseValue.reviewedAt &&
                remoteValue.reviewedAt != baseValue.reviewedAt &&
                localValue.problemId == remoteValue.problemId &&
                localValue.rating != remoteValue.rating
            ) {
                conflicts += makeProblemReviewConflict(
                    winner,
                    localValue,
                    remoteValue,
                    baseValue,
                    "問題 ${localValue.problemNumber} の復習結果が端末間で異なります",
                    now
                )
                return@mapNotNull localValue
            }
            winner
        }
    }

    private fun mergePlans(
        base: List<PlanData>,
        local: List<PlanData>,
        remote: List<PlanData>,
        conflicts: MutableList<SyncConflict>,
        now: Long
    ): List<PlanData> {
        val mergedPlans = mergeEntities(
            base.map { it.plan },
            local.map { it.plan },
            remote.map { it.plan },
            SyncEntityKind.PLAN,
            StudyPlan::name,
            conflicts,
            now,
            StudyPlan::syncId,
            StudyPlan::syncId,
            StudyPlan::updatedAt,
            StudyPlan::deletedAt
        ) { it.toJson().toString() }
        val mergedItems = mergeEntities(
            base.flatMap { it.items },
            local.flatMap { it.items },
            remote.flatMap { it.items },
            SyncEntityKind.PLAN_ITEM,
            { "計画項目" },
            conflicts,
            now,
            PlanItem::syncId,
            PlanItem::syncId,
            PlanItem::updatedAt,
            PlanItem::deletedAt
        ) { it.toJson().toString() }
        val grouped = mergedItems.groupBy(PlanItem::planSyncId)
        return mergedPlans.map { plan -> PlanData(plan = plan, items = grouped[plan.syncId].orEmpty()) }
    }

    private fun <T> mergeEntities(
        base: List<T>,
        local: List<T>,
        remote: List<T>,
        kind: SyncEntityKind,
        title: (T) -> String,
        conflicts: MutableList<SyncConflict>,
        now: Long,
        key: (T) -> String,
        syncId: (T) -> String,
        updatedAt: (T) -> Long,
        deletedAt: (T) -> Long?,
        encode: (T) -> String
    ): List<T> {
        val baseMap = base.associateBy(key)
        val localMap = local.associateBy(key)
        val remoteMap = remote.associateBy(key)
        val ids = baseMap.keys + localMap.keys + remoteMap.keys
        return ids.mapNotNull { id ->
            val localValue = localMap[id]
            val remoteValue = remoteMap[id]
            if (localValue == null) return@mapNotNull remoteValue
            if (remoteValue == null) return@mapNotNull localValue

            val baseValue = baseMap[id]
            val aliveSideChanged = baseValue != null && when {
                deletedAt(localValue) == null && deletedAt(remoteValue) != null -> updatedAt(localValue) != updatedAt(baseValue)
                deletedAt(remoteValue) == null && deletedAt(localValue) != null -> updatedAt(remoteValue) != updatedAt(baseValue)
                else -> false
            }
            if (deletedAt(localValue) == null != (deletedAt(remoteValue) == null) && aliveSideChanged) {
                conflicts += SyncConflict(
                    kind = kind,
                    syncId = syncId(localValue),
                    title = "「${title(localValue)}」の削除が端末間で競合しています",
                    summary = "「${title(localValue)}」の削除が端末間で競合しています",
                    conflictFields = listOf(SyncConflictField.DELETION),
                    baseJson = baseValue?.let(encode),
                    localJson = encode(localValue),
                    remoteJson = encode(remoteValue),
                    suggestedMergedJson = if (deletedAt(localValue) == null) encode(localValue) else encode(remoteValue),
                    detectedAt = now
                )
                return@mapNotNull if (deletedAt(localValue) == null) localValue else remoteValue
            }

            if (baseValue != null &&
                jsonHash(encode(localValue)) != jsonHash(encode(baseValue)) &&
                jsonHash(encode(remoteValue)) != jsonHash(encode(baseValue)) &&
                jsonHash(encode(localValue)) != jsonHash(encode(remoteValue))
            ) {
                val merged = pickNewer(localValue, remoteValue, updatedAt, deletedAt)
                conflicts += SyncConflict(
                    kind = kind,
                    syncId = syncId(localValue),
                    title = "「${title(localValue)}」が端末間で異なります",
                    summary = "「${title(localValue)}」が端末間で異なります",
                    conflictFields = listOf(SyncConflictField.OTHER),
                    baseJson = encode(baseValue),
                    localJson = encode(localValue),
                    remoteJson = encode(remoteValue),
                    suggestedMergedJson = encode(merged),
                    detectedAt = now
                )
                return@mapNotNull localValue
            }

            SyncMergeEngine.merge(listOf(localValue), listOf(remoteValue), key, updatedAt, deletedAt).firstOrNull()
        }
    }

    private fun <T> pickNewer(local: T, remote: T, updatedAt: (T) -> Long, deletedAt: (T) -> Long?): T {
        val localDelete = deletedAt(local)
        val remoteDelete = deletedAt(remote)
        if (localDelete != null && remoteDelete != null) {
            return if (localDelete >= remoteDelete) local else remote
        }
        return if (updatedAt(local) >= updatedAt(remote)) local else remote
    }

    private fun pickNewer(local: Material, remote: Material): Material =
        pickNewer(local, remote, Material::updatedAt, Material::deletedAt)

    private fun pickNewer(local: StudySession, remote: StudySession): StudySession =
        pickNewer(local, remote, StudySession::updatedAt, StudySession::deletedAt)

    private fun scalarConflict(base: String, local: String, remote: String): Boolean =
        local != base && remote != base && local != remote

    private fun unionProblemRecords(
        base: List<ProblemSessionRecord>,
        local: List<ProblemSessionRecord>,
        remote: List<ProblemSessionRecord>
    ): List<ProblemSessionRecord> {
        val map = linkedMapOf<String, ProblemSessionRecord>()
        (base + local + remote).forEach { map[it.stableKey] = it }
        return map.values.sortedWith(compareBy({ it.number }, { it.normalizedSubNumber.orEmpty() }))
    }

    private fun unionChapters(
        base: List<ProblemChapter>,
        local: List<ProblemChapter>,
        remote: List<ProblemChapter>
    ): List<ProblemChapter> {
        val map = linkedMapOf<String, ProblemChapter>()
        (base + local + remote).forEach { map[it.id] = it }
        return map.values.toList()
    }

    private fun maxOptional(vararg values: Int?): Int? = values.filterNotNull().maxOrNull()

    private fun deletionConflict(
        base: Material?,
        local: Material,
        remote: Material,
        kind: SyncEntityKind,
        title: String,
        now: Long
    ): SyncConflict? = deletionConflict(
        base = base,
        localDeleted = local.deletedAt,
        remoteDeleted = remote.deletedAt,
        aliveSideChanged = when {
            base == null -> false
            local.deletedAt == null && remote.deletedAt != null -> local.updatedAt != base.updatedAt
            remote.deletedAt == null && local.deletedAt != null -> remote.updatedAt != base.updatedAt
            else -> false
        },
        kind = kind,
        syncId = local.syncId,
        title = title,
        now = now,
        localJson = local.toJson().toString(),
        remoteJson = remote.toJson().toString(),
        baseJson = base?.toJson()?.toString()
    )

    private fun deletionConflict(
        base: StudySession?,
        local: StudySession,
        remote: StudySession,
        kind: SyncEntityKind,
        title: String,
        now: Long
    ): SyncConflict? = deletionConflict(
        base = base,
        localDeleted = local.deletedAt,
        remoteDeleted = remote.deletedAt,
        aliveSideChanged = when {
            base == null -> false
            local.deletedAt == null && remote.deletedAt != null -> local.updatedAt != base.updatedAt
            remote.deletedAt == null && local.deletedAt != null -> remote.updatedAt != base.updatedAt
            else -> false
        },
        kind = kind,
        syncId = local.syncId,
        title = title,
        now = now,
        localJson = local.toJson().toString(),
        remoteJson = remote.toJson().toString(),
        baseJson = base?.toJson()?.toString()
    )

    private fun deletionConflict(
        base: Any?,
        localDeleted: Long?,
        remoteDeleted: Long?,
        aliveSideChanged: Boolean,
        kind: SyncEntityKind,
        syncId: String,
        title: String,
        now: Long,
        localJson: String,
        remoteJson: String,
        baseJson: String?
    ): SyncConflict? {
        val localAlive = localDeleted == null
        val remoteAlive = remoteDeleted == null
        if (localAlive == remoteAlive || base == null || !aliveSideChanged) return null
        return SyncConflict(
            kind = kind,
            syncId = syncId,
            title = "「$title」の削除が端末間で競合しています",
            summary = "「$title」の削除が端末間で競合しています",
            conflictFields = listOf(SyncConflictField.DELETION),
            baseJson = baseJson,
            localJson = localJson,
            remoteJson = remoteJson,
            suggestedMergedJson = if (localAlive) localJson else remoteJson,
            detectedAt = now
        )
    }

    private fun makeMaterialConflict(
        entity: Material,
        local: Material,
        remote: Material,
        base: Material?,
        fields: List<SyncConflictField>,
        summary: String,
        now: Long
    ): SyncConflict = SyncConflict(
        kind = SyncEntityKind.MATERIAL,
        syncId = local.syncId,
        title = summary,
        summary = summary,
        conflictFields = fields,
        baseJson = base?.toJson()?.toString(),
        localJson = local.toJson().toString(),
        remoteJson = remote.toJson().toString(),
        suggestedMergedJson = entity.toJson().toString(),
        detectedAt = now
    )

    private fun makeProblemReviewConflict(
        entity: ProblemReviewRecord,
        local: ProblemReviewRecord,
        remote: ProblemReviewRecord,
        base: ProblemReviewRecord,
        summary: String,
        now: Long
    ): SyncConflict = SyncConflict(
        kind = SyncEntityKind.PROBLEM_REVIEW_RECORD,
        syncId = local.syncId,
        title = summary,
        summary = summary,
        conflictFields = listOf(SyncConflictField.PROBLEM_REVIEW_STATE),
        baseJson = base.toJson().toString(),
        localJson = local.toJson().toString(),
        remoteJson = remote.toJson().toString(),
        suggestedMergedJson = entity.toJson().toString(),
        detectedAt = now
    )

    private fun jsonHash(json: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(json.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }

    private fun replaceEntity(appData: AppData, kind: SyncEntityKind, syncId: String, json: String): AppData {
        val data = JSONObject(json)
        return when (kind) {
            SyncEntityKind.SUBJECT -> appData.copy(subjects = replace(appData.subjects, syncId, data.toSubject(), Subject::syncId))
            SyncEntityKind.MATERIAL -> appData.copy(materials = replace(appData.materials, syncId, data.toMaterial(), Material::syncId))
            SyncEntityKind.SESSION -> appData.copy(sessions = replace(appData.sessions, syncId, data.toStudySession(), StudySession::syncId))
            SyncEntityKind.GOAL -> appData.copy(goals = replace(appData.goals, syncId, data.toGoal(), Goal::syncId))
            SyncEntityKind.EXAM -> appData.copy(exams = replace(appData.exams, syncId, data.toExam(), Exam::syncId))
            SyncEntityKind.PLAN -> appData.copy(
                plans = appData.plans.map { planData ->
                    if (planData.plan.syncId != syncId) planData else planData.copy(plan = data.toStudyPlan())
                }
            )
            SyncEntityKind.PLAN_ITEM -> appData.copy(
                plans = replacePlanItem(appData.plans, syncId, data.toPlanItem())
            )
            SyncEntityKind.TIMETABLE_PERIOD -> appData.copy(
                timetablePeriods = replace(appData.timetablePeriods, syncId, data.toTimetablePeriod(), TimetablePeriod::syncId)
            )
            SyncEntityKind.TIMETABLE_ENTRY -> appData.copy(
                timetableEntries = replace(appData.timetableEntries, syncId, data.toTimetableEntry(), TimetableEntry::syncId)
            )
            SyncEntityKind.TIMETABLE_TERM -> appData.copy(
                timetableTerms = replace(appData.timetableTerms, syncId, data.toTimetableTerm(), TimetableTerm::syncId)
            )
            SyncEntityKind.TIMETABLE_REVIEW_RECORD -> appData.copy(
                timetableReviewRecords = replace(appData.timetableReviewRecords, syncId, data.toTimetableReviewRecord(), TimetableReviewRecord::syncId)
            )
            SyncEntityKind.PROBLEM_REVIEW_RECORD -> data.toProblemReviewRecord()?.let { record ->
                appData.copy(problemReviewRecords = replace(appData.problemReviewRecords, syncId, record, ProblemReviewRecord::syncId))
            } ?: appData
        }
    }

    private fun <T> replace(values: List<T>, syncId: String, value: T, key: (T) -> String): List<T> {
        val index = values.indexOfFirst { key(it) == syncId }
        return if (index >= 0) values.toMutableList().apply { this[index] = value } else values + value
    }

    private fun replacePlanItem(plans: List<PlanData>, syncId: String, value: PlanItem): List<PlanData> {
        val ownerPlanSyncId = value.planSyncId
        val existingOwner = plans.firstOrNull { planData ->
            planData.items.any { it.syncId == syncId }
        }?.plan?.syncId
        val targetPlanSyncId = ownerPlanSyncId ?: existingOwner
        return plans.map { planData ->
            val withoutDuplicate = planData.items.filterNot { it.syncId == syncId }
            if (planData.plan.syncId == targetPlanSyncId) {
                planData.copy(items = withoutDuplicate + value.copy(planSyncId = targetPlanSyncId))
            } else {
                planData.copy(items = withoutDuplicate)
            }
        }
    }

    private fun jsonWithUpdatedAt(json: String, updatedAt: Long): String {
        return runCatching {
            JSONObject(json).put("updatedAt", updatedAt).toString()
        }.getOrDefault(json)
    }
}
