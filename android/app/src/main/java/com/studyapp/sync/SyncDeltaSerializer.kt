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
import org.json.JSONObject

object SyncDeltaSerializer {
    fun decompose(appData: AppData): List<SyncEntityEnvelope> {
        val envelopes = ArrayList<SyncEntityEnvelope>(estimatedEnvelopeCount(appData))
        appData.subjects.forEach { envelopes += envelope(it, SyncEntityKind.SUBJECT) }
        appData.materials.forEach { envelopes += envelope(it, SyncEntityKind.MATERIAL) }
        appData.sessions.forEach { envelopes += envelope(it, SyncEntityKind.SESSION) }
        appData.goals.forEach { envelopes += envelope(it, SyncEntityKind.GOAL) }
        appData.exams.forEach { envelopes += envelope(it, SyncEntityKind.EXAM) }
        appData.plans.forEach { planData ->
            envelopes += envelope(planData.plan, SyncEntityKind.PLAN)
            planData.items.forEach { envelopes += envelope(it, SyncEntityKind.PLAN_ITEM) }
        }
        appData.timetablePeriods.forEach { envelopes += envelope(it, SyncEntityKind.TIMETABLE_PERIOD) }
        appData.timetableEntries.forEach { envelopes += envelope(it, SyncEntityKind.TIMETABLE_ENTRY) }
        appData.timetableTerms.forEach { envelopes += envelope(it, SyncEntityKind.TIMETABLE_TERM) }
        appData.timetableReviewRecords.forEach { envelopes += envelope(it, SyncEntityKind.TIMETABLE_REVIEW_RECORD) }
        appData.problemReviewRecords.forEach { envelopes += envelope(it, SyncEntityKind.PROBLEM_REVIEW_RECORD) }
        return envelopes
    }

    fun changedSince(appData: AppData, cursor: Long): List<SyncEntityEnvelope> {
        return decompose(appData).filter { it.updatedAt > cursor }
    }

    fun assemble(envelopes: List<SyncEntityEnvelope>, onto: AppData): AppData {
        val partial = partialAppData(envelopes, onto.exportDate)
        return SyncMergeEngine.merge(local = onto, remote = partial)
    }

    private fun estimatedEnvelopeCount(appData: AppData): Int {
        return appData.subjects.size +
            appData.materials.size +
            appData.sessions.size +
            appData.goals.size +
            appData.exams.size +
            appData.plans.size +
            appData.plans.sumOf { it.items.size } +
            appData.timetablePeriods.size +
            appData.timetableEntries.size +
            appData.timetableTerms.size +
            appData.timetableReviewRecords.size +
            appData.problemReviewRecords.size
    }

    private fun envelope(
        syncId: String,
        updatedAt: Long,
        deletedAt: Long?,
        kind: SyncEntityKind,
        json: String
    ): SyncEntityEnvelope {
        return SyncEntityEnvelope(kind = kind, syncId = syncId, updatedAt = updatedAt, deletedAt = deletedAt, json = json)
    }

    private fun envelope(subject: Subject, kind: SyncEntityKind) =
        envelope(subject.syncId, subject.updatedAt, subject.deletedAt, kind, subject.toJson().toString())

    private fun envelope(material: Material, kind: SyncEntityKind) =
        envelope(material.syncId, material.updatedAt, material.deletedAt, kind, material.toJson().toString())

    private fun envelope(session: StudySession, kind: SyncEntityKind) =
        envelope(session.syncId, session.updatedAt, session.deletedAt, kind, session.toJson().toString())

    private fun envelope(goal: Goal, kind: SyncEntityKind) =
        envelope(goal.syncId, goal.updatedAt, goal.deletedAt, kind, goal.toJson().toString())

    private fun envelope(exam: Exam, kind: SyncEntityKind) =
        envelope(exam.syncId, exam.updatedAt, exam.deletedAt, kind, exam.toJson().toString())

    private fun envelope(plan: StudyPlan, kind: SyncEntityKind) =
        envelope(plan.syncId, plan.updatedAt, plan.deletedAt, kind, plan.toJson().toString())

    private fun envelope(item: PlanItem, kind: SyncEntityKind) =
        envelope(item.syncId, item.updatedAt, item.deletedAt, kind, item.toJson().toString())

    private fun envelope(period: TimetablePeriod, kind: SyncEntityKind) =
        envelope(period.syncId, period.updatedAt, period.deletedAt, kind, period.toJson().toString())

    private fun envelope(entry: TimetableEntry, kind: SyncEntityKind) =
        envelope(entry.syncId, entry.updatedAt, entry.deletedAt, kind, entry.toJson().toString())

    private fun envelope(term: TimetableTerm, kind: SyncEntityKind) =
        envelope(term.syncId, term.updatedAt, term.deletedAt, kind, term.toJson().toString())

    private fun envelope(record: TimetableReviewRecord, kind: SyncEntityKind) =
        envelope(record.syncId, record.updatedAt, record.deletedAt, kind, record.toJson().toString())

    private fun envelope(record: ProblemReviewRecord, kind: SyncEntityKind) =
        envelope(record.syncId, record.updatedAt, record.deletedAt, kind, record.toJson().toString())

    private fun partialAppData(envelopes: List<SyncEntityEnvelope>, exportDate: Long): AppData {
        val subjects = mutableListOf<Subject>()
        val materials = mutableListOf<Material>()
        val sessions = mutableListOf<StudySession>()
        val goals = mutableListOf<Goal>()
        val exams = mutableListOf<Exam>()
        val plans = mutableListOf<StudyPlan>()
        val planItems = mutableListOf<PlanItem>()
        val timetablePeriods = mutableListOf<TimetablePeriod>()
        val timetableEntries = mutableListOf<TimetableEntry>()
        val timetableTerms = mutableListOf<TimetableTerm>()
        val timetableReviewRecords = mutableListOf<TimetableReviewRecord>()
        val problemReviewRecords = mutableListOf<ProblemReviewRecord>()

        envelopes.forEach { envelope ->
            runCatching {
                val json = JSONObject(envelope.json)
                when (envelope.kind) {
                    SyncEntityKind.SUBJECT -> subjects += json.toSubject()
                    SyncEntityKind.MATERIAL -> materials += json.toMaterial()
                    SyncEntityKind.SESSION -> sessions += json.toStudySession()
                    SyncEntityKind.GOAL -> goals += json.toGoal()
                    SyncEntityKind.EXAM -> exams += json.toExam()
                    SyncEntityKind.PLAN -> plans += json.toStudyPlan()
                    SyncEntityKind.PLAN_ITEM -> planItems += json.toPlanItem()
                    SyncEntityKind.TIMETABLE_PERIOD -> timetablePeriods += json.toTimetablePeriod()
                    SyncEntityKind.TIMETABLE_ENTRY -> timetableEntries += json.toTimetableEntry()
                    SyncEntityKind.TIMETABLE_TERM -> timetableTerms += json.toTimetableTerm()
                    SyncEntityKind.TIMETABLE_REVIEW_RECORD -> timetableReviewRecords += json.toTimetableReviewRecord()
                    SyncEntityKind.PROBLEM_REVIEW_RECORD -> json.toProblemReviewRecord()?.let { problemReviewRecords += it }
                }
            }
        }

        val itemsByPlanSyncId = planItems.groupBy { it.planSyncId }
        val planData = plans.map { plan -> PlanData(plan = plan, items = itemsByPlanSyncId[plan.syncId].orEmpty()) }

        return AppData(
            subjects = subjects,
            materials = materials,
            sessions = sessions,
            goals = goals,
            exams = exams,
            plans = planData,
            timetablePeriods = timetablePeriods,
            timetableEntries = timetableEntries,
            timetableTerms = timetableTerms,
            timetableReviewRecords = timetableReviewRecords,
            problemReviewRecords = problemReviewRecords,
            exportDate = exportDate
        )
    }
}
