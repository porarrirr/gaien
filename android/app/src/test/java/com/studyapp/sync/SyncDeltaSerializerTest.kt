package com.studyapp.sync

import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.Subject
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.PlanData
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncDeltaSerializerTest {
    @Test
    fun `decompose emits one envelope per entity`() {
        val appData = appData(
            subjects = listOf(subject("s1"), subject("s2")),
            sessions = listOf(session("x1"))
        )

        val envelopes = SyncDeltaSerializer.decompose(appData)

        assertEquals(3, envelopes.size)
        assertEquals(2, envelopes.count { it.kind == SyncEntityKind.SUBJECT })
        assertEquals(1, envelopes.count { it.kind == SyncEntityKind.SESSION })
    }

    @Test
    fun `decompose includes plan and plan items separately`() {
        val plan = StudyPlan(id = 1, syncId = "p1", name = "Plan", startDate = 0, endDate = 1, updatedAt = 100)
        val item = PlanItem(id = 2, syncId = "i1", planId = 1, planSyncId = "p1", subjectId = 1, dayOfWeek = StudyWeekday.MONDAY, targetMinutes = 60, updatedAt = 100)

        val envelopes = SyncDeltaSerializer.decompose(appData(plans = listOf(PlanData(plan, listOf(item)))))

        assertEquals(1, envelopes.count { it.kind == SyncEntityKind.PLAN })
        assertEquals(1, envelopes.count { it.kind == SyncEntityKind.PLAN_ITEM })
    }

    @Test
    fun `session envelope uses iOS compatible json field names`() {
        val source = session("session-1").copy(
            materialId = 10,
            materialSyncId = "material-1",
            materialName = "数学問題集",
            subjectId = 20,
            subjectSyncId = "subject-1",
            subjectName = "数学",
            intervals = listOf(
                StudySessionInterval(startTime = 1_000, endTime = 61_000)
            )
        )

        val envelope = SyncDeltaSerializer.decompose(appData(sessions = listOf(source)))
            .single { it.kind == SyncEntityKind.SESSION }
        val json = JSONObject(envelope.json)

        assertEquals("session-1", json.getString("syncId"))
        assertEquals("material-1", json.getString("materialSyncId"))
        assertEquals("数学問題集", json.getString("materialName"))
        assertEquals("subject-1", json.getString("subjectSyncId"))
        assertEquals("数学", json.getString("subjectName"))
        assertEquals("STOPWATCH", json.getString("sessionType"))
        assertEquals(1_000, json.getJSONArray("intervals").getJSONObject(0).getLong("startTime"))
        assertEquals(61_000, json.getJSONArray("intervals").getJSONObject(0).getLong("endTime"))
    }

    @Test
    fun `changedSince includes only entities strictly newer than cursor`() {
        val changed = SyncDeltaSerializer.changedSince(
            appData(subjects = listOf(subject("old", updatedAt = 100), subject("boundary", updatedAt = 200), subject("new", updatedAt = 201))),
            cursor = SyncDeltaCursor.fromLegacy(200)
        )

        assertEquals(listOf("boundary", "new"), changed.map { it.syncId }.sorted())
    }

    @Test
    fun `changedSince uses document id tie-break at same updatedAt`() {
        val changed = SyncDeltaSerializer.changedSince(
            appData(subjects = listOf(subject("a", updatedAt = 200), subject("z", updatedAt = 200))),
            cursor = SyncDeltaCursor(updatedAt = 200, documentId = "subject-a")
        )

        assertEquals(listOf("z"), changed.map { it.syncId })
    }

    @Test
    fun `assemble merges envelopes onto base data`() {
        val base = appData(subjects = listOf(subject("s1", updatedAt = 100, color = 1)))
        val newer = SyncDeltaSerializer.decompose(appData(subjects = listOf(subject("s1", updatedAt = 300, color = 9))))

        val merged = SyncDeltaSerializer.assemble(newer, onto = base)

        assertEquals(1, merged.subjects.size)
        assertEquals(9, merged.subjects.first().color)
    }

    @Test
    fun `assemble skips malformed envelopes`() {
        val merged = SyncDeltaSerializer.assemble(
            listOf(
                SyncEntityEnvelope(
                    kind = SyncEntityKind.SUBJECT,
                    syncId = "bad",
                    updatedAt = 100,
                    deletedAt = null,
                    json = "not json {"
                )
            ),
            onto = appData()
        )

        assertTrue(merged.subjects.isEmpty())
    }

    private fun appData(
        subjects: List<Subject> = emptyList(),
        sessions: List<StudySession> = emptyList(),
        plans: List<PlanData> = emptyList()
    ) = AppData(
        subjects = subjects,
        materials = emptyList(),
        sessions = sessions,
        goals = emptyList(),
        exams = emptyList(),
        plans = plans,
        exportDate = 0
    )

    private fun subject(syncId: String, updatedAt: Long = 100, color: Int = 1) = Subject(
        syncId = syncId,
        name = "Subject",
        color = color,
        updatedAt = updatedAt
    )

    private fun session(syncId: String) = StudySession(
        syncId = syncId,
        subjectId = 1,
        startTime = 0,
        endTime = 60_000,
        updatedAt = 100
    )
}
