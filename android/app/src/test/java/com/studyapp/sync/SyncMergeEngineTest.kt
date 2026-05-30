package com.studyapp.sync

import com.studyapp.domain.model.Material
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemReviewRating
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.Subject
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.PlanData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncMergeEngineTest {
    @Test
    fun `merge keeps newer updatedAt for ordinary entities`() {
        val local = listOf(subject(syncId = "s1", updatedAt = 1_000, color = 1))
        val remote = listOf(subject(syncId = "s1", updatedAt = 2_000, color = 2))

        val merged = SyncMergeEngine.merge(appData(subjects = local), appData(subjects = remote))

        assertEquals(1, merged.subjects.size)
        assertEquals(2, merged.subjects.first().color)
    }

    @Test
    fun `merge lets tombstone win over newer non deleted entity`() {
        val local = listOf(subject(syncId = "s1", updatedAt = 1_000, color = 1))
        val remote = listOf(subject(syncId = "s1", updatedAt = 500, color = 2, deletedAt = 1_500))

        val merged = SyncMergeEngine.merge(appData(subjects = local), appData(subjects = remote))

        assertNotNull(merged.subjects.single().deletedAt)
    }

    @Test
    fun `merge lets newer non deleted entity win over older tombstone`() {
        val local = listOf(subject(syncId = "s1", updatedAt = 2_000, color = 7))
        val remote = listOf(subject(syncId = "s1", updatedAt = 500, color = 2, deletedAt = 1_000))

        val merged = SyncMergeEngine.merge(appData(subjects = local), appData(subjects = remote))

        assertNull(merged.subjects.single().deletedAt)
        assertEquals(7, merged.subjects.single().color)
    }

    @Test
    fun `mergeMaterials preserves problem progress from older side`() {
        val localMaterial = material(
            syncId = "m1",
            updatedAt = 1_000,
            problemRecords = listOf(ProblemSessionRecord(number = 1, result = ProblemResult.WRONG)),
            totalProblems = 50
        )
        val remoteMaterial = material(syncId = "m1", updatedAt = 2_000, problemRecords = emptyList(), totalProblems = 0)

        val merged = SyncMergeEngine.mergeMaterials(listOf(localMaterial), listOf(remoteMaterial))

        assertEquals(1, merged.single().problemRecords.size)
        assertEquals(50, merged.single().totalProblems)
    }

    @Test
    fun `mergeMaterials does not revive progress on selected tombstone`() {
        val localMaterial = material(syncId = "m1", updatedAt = 1_000, problemRecords = listOf(ProblemSessionRecord(1, ProblemResult.WRONG)), totalProblems = 50)
        val remoteTombstone = material(syncId = "m1", updatedAt = 500, deletedAt = 2_000)

        val merged = SyncMergeEngine.mergeMaterials(listOf(localMaterial), listOf(remoteTombstone))

        assertNotNull(merged.single().deletedAt)
        assertTrue(merged.single().problemRecords.isEmpty())
        assertEquals(0, merged.single().totalProblems)
    }

    @Test
    fun `mergeSessions preserves problem range and records from older side`() {
        val localSession = session(syncId = "x1", updatedAt = 1_000, problemStart = 1, problemEnd = 5, wrongProblemCount = 2)
        val remoteSession = session(syncId = "x1", updatedAt = 2_000, records = listOf(ProblemSessionRecord(3, ProblemResult.WRONG)))

        val merged = SyncMergeEngine.mergeSessions(listOf(localSession), listOf(remoteSession))

        assertEquals(1, merged.single().problemStart)
        assertEquals(5, merged.single().problemEnd)
        assertEquals(2, merged.single().wrongProblemCount)
        assertEquals(listOf("3"), merged.single().problemRecords.map { it.stableKey })
    }

    @Test
    fun `mergePlans regroups items by selected plan sync id`() {
        val localPlan = plan("p1", updatedAt = 100)
        val remotePlan = plan("p1", updatedAt = 200)
        val localItem = planItem("i1", "p1", StudyWeekday.MONDAY)
        val remoteItem = planItem("i2", "p1", StudyWeekday.TUESDAY)

        val merged = SyncMergeEngine.mergePlans(
            listOf(PlanData(localPlan, listOf(localItem))),
            listOf(PlanData(remotePlan, listOf(remoteItem)))
        )

        assertEquals("p1", merged.single().plan.syncId)
        assertEquals(setOf("i1", "i2"), merged.single().items.map { it.syncId }.toSet())
    }

    @Test
    fun `markSynced stamps every sync entity and export date`() {
        val synced = SyncMergeEngine.markSynced(
            appData(
                subjects = listOf(subject("s1", updatedAt = 1)),
                materials = listOf(material("m1")),
                sessions = listOf(session("x1")),
                plans = listOf(PlanData(plan("p1"), listOf(planItem("i1", "p1", StudyWeekday.MONDAY)))),
                problemReviewRecords = listOf(problemReview("r1"))
            ),
            timestamp = 9_999
        )

        assertEquals(9_999L, synced.exportDate)
        assertEquals(9_999L, synced.subjects.single().lastSyncedAt)
        assertEquals(9_999L, synced.materials.single().lastSyncedAt)
        assertEquals(9_999L, synced.sessions.single().lastSyncedAt)
        assertEquals(9_999L, synced.plans.single().plan.lastSyncedAt)
        assertEquals(9_999L, synced.plans.single().items.single().lastSyncedAt)
        assertEquals(9_999L, synced.problemReviewRecords.single().lastSyncedAt)
    }

    @Test
    fun `syncProgressGuard detects loss of problem progress`() {
        val source = appData(
            materials = listOf(material(syncId = "m1", totalProblems = 10, problemRecords = listOf(ProblemSessionRecord(1, ProblemResult.CORRECT)))),
            sessions = listOf(session(syncId = "x1", records = listOf(ProblemSessionRecord(2, ProblemResult.WRONG)))),
            problemReviewRecords = listOf(problemReview("r1"))
        )
        val destination = appData(materials = listOf(material(syncId = "m1")))

        assertTrue(SyncProgressGuard.wouldLoseProgress(source, destination))
    }

    @Test
    fun `syncProgressGuard allows empty source progress`() {
        assertFalse(SyncProgressGuard.wouldLoseProgress(from = appData(), to = appData()))
    }

    private fun appData(
        subjects: List<Subject> = emptyList(),
        materials: List<Material> = emptyList(),
        sessions: List<StudySession> = emptyList(),
        plans: List<PlanData> = emptyList(),
        problemReviewRecords: List<ProblemReviewRecord> = emptyList()
    ): AppData {
        return AppData(
            subjects = subjects,
            materials = materials,
            sessions = sessions,
            goals = emptyList(),
            exams = emptyList(),
            plans = plans,
            problemReviewRecords = problemReviewRecords,
            exportDate = 0L
        )
    }

    private fun subject(syncId: String, updatedAt: Long, color: Int = 0, deletedAt: Long? = null): Subject =
        Subject(syncId = syncId, name = "Subject", color = color, updatedAt = updatedAt, deletedAt = deletedAt)

    private fun material(
        syncId: String,
        updatedAt: Long = 0L,
        problemRecords: List<ProblemSessionRecord> = emptyList(),
        totalProblems: Int = 0,
        deletedAt: Long? = null
    ): Material {
        return Material(
            syncId = syncId,
            name = "Material",
            subjectId = 1L,
            totalProblems = totalProblems,
            problemRecords = problemRecords,
            updatedAt = updatedAt,
            deletedAt = deletedAt
        )
    }

    private fun session(
        syncId: String,
        updatedAt: Long = 0,
        problemStart: Int? = null,
        problemEnd: Int? = null,
        wrongProblemCount: Int? = null,
        records: List<ProblemSessionRecord> = emptyList()
    ) = StudySession(
        syncId = syncId,
        subjectId = 1,
        startTime = 0,
        endTime = 60_000,
        updatedAt = updatedAt,
        problemStart = problemStart,
        problemEnd = problemEnd,
        wrongProblemCount = wrongProblemCount,
        problemRecords = records
    )

    private fun plan(syncId: String, updatedAt: Long = 0) =
        StudyPlan(syncId = syncId, name = "Plan", startDate = 0, endDate = 1, updatedAt = updatedAt)

    private fun planItem(syncId: String, planSyncId: String, day: StudyWeekday) =
        PlanItem(syncId = syncId, planId = 1, planSyncId = planSyncId, subjectId = 1, dayOfWeek = day, targetMinutes = 30)

    private fun problemReview(syncId: String) = ProblemReviewRecord(
        syncId = syncId,
        problemId = "m1-1",
        materialId = 1,
        problemNumber = 1,
        reviewedAt = 100,
        rating = ProblemReviewRating.AGAIN,
        nextReviewDate = 200,
        consecutiveCorrectCount = 0,
        wrongCount = 1
    )
}
