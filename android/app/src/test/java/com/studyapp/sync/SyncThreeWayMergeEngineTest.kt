package com.studyapp.sync

import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.Subject
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.toJson
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SyncThreeWayMergeEngineTest {
    @Test
    fun `merge without base falls back to two-way merge`() {
        val local = appData(materials = listOf(material("m1", currentPage = 3, updatedAt = 1_000)))
        val remote = listOf(
            envelope(
                kind = SyncEntityKind.MATERIAL,
                syncId = "m1",
                updatedAt = 2_000,
                json = material("m1", currentPage = 1, updatedAt = 2_000).toJson().toString()
            )
        )

        val outcome = SyncThreeWayMergeEngine.merge(base = null, local = local, remoteEnvelopes = remote)

        assertTrue(outcome.usedLegacyTwoWayFallback)
        assertTrue(outcome.conflicts.isEmpty())
        assertEquals(1, outcome.merged.materials.single().currentPage)
    }

    @Test
    fun `merge keeps monotonic current page across devices`() {
        val base = appData(materials = listOf(material("m1", currentPage = 5, updatedAt = 500)))
        val local = appData(materials = listOf(material("m1", currentPage = 8, updatedAt = 1_000)))
        val remote = listOf(
            envelope(
                kind = SyncEntityKind.MATERIAL,
                syncId = "m1",
                updatedAt = 1_100,
                json = material("m1", currentPage = 6, updatedAt = 1_100).toJson().toString()
            )
        )

        val outcome = SyncThreeWayMergeEngine.merge(base = base, local = local, remoteEnvelopes = remote)

        assertFalse(outcome.usedLegacyTwoWayFallback)
        assertEquals(8, outcome.merged.materials.single().currentPage)
    }

    @Test
    fun `merge detects deletion conflict when one side deletes and other updates`() {
        val baseMaterial = material("m1", currentPage = 3, updatedAt = 100)
        val base = appData(materials = listOf(baseMaterial))
        val local = appData(materials = listOf(material("m1", currentPage = 4, updatedAt = 200)))
        val remote = listOf(
            envelope(
                kind = SyncEntityKind.MATERIAL,
                syncId = "m1",
                updatedAt = 250,
                deletedAt = 250,
                json = material("m1", currentPage = 3, updatedAt = 250, deletedAt = 250).toJson().toString()
            )
        )

        val outcome = SyncThreeWayMergeEngine.merge(base = base, local = local, remoteEnvelopes = remote)

        assertEquals(1, outcome.conflicts.size)
        assertEquals(SyncConflictField.DELETION, outcome.conflicts.single().conflictFields.single())
    }

    @Test
    fun `merge unions problem records from both sides`() {
        val base = appData(
            materials = listOf(
                material(
                    "m1",
                    problemRecords = listOf(ProblemSessionRecord(number = 1)),
                    updatedAt = 100
                )
            )
        )
        val local = appData(
            materials = listOf(
                material(
                    "m1",
                    problemRecords = listOf(ProblemSessionRecord(number = 1), ProblemSessionRecord(number = 2)),
                    updatedAt = 200
                )
            )
        )
        val remote = listOf(
            envelope(
                kind = SyncEntityKind.MATERIAL,
                syncId = "m1",
                updatedAt = 210,
                json = material(
                    "m1",
                    problemRecords = listOf(ProblemSessionRecord(number = 1), ProblemSessionRecord(number = 3)),
                    updatedAt = 210
                ).toJson().toString()
            )
        )

        val outcome = SyncThreeWayMergeEngine.merge(base = base, local = local, remoteEnvelopes = remote)

        assertEquals(listOf("1", "2", "3"), outcome.merged.materials.single().problemRecords.map { it.stableKey })
    }

    @Test
    fun `changedSince uses composite cursor document tie-break`() {
        val appData = appData(
            subjects = listOf(
                subject("a", updatedAt = 1_000),
                subject("z", updatedAt = 1_000)
            )
        )
        val cursor = SyncDeltaCursor(updatedAt = 1_000, documentId = "subject-a")

        val changed = SyncDeltaSerializer.changedSince(appData, cursor)

        assertEquals(1, changed.size)
        assertEquals("z", changed.single().syncId)
    }

    @Test
    fun `applyResolutions bumps updatedAt so selected value uploads after cursor`() {
        val local = appData(subjects = listOf(subject("s1", updatedAt = 1_000, color = 1)))
        val remote = subject("s1", updatedAt = 1_100, color = 2)
        val conflict = SyncConflict(
            kind = SyncEntityKind.SUBJECT,
            syncId = "s1",
            title = "subject conflict",
            summary = "subject conflict",
            conflictFields = listOf(SyncConflictField.OTHER),
            baseJson = null,
            localJson = subject("s1", updatedAt = 1_000, color = 1).toJson().toString(),
            remoteJson = remote.toJson().toString(),
            suggestedMergedJson = remote.toJson().toString(),
            detectedAt = 1_100
        )

        val resolved = SyncThreeWayMergeEngine.applyResolutions(
            resolutions = listOf(SyncConflictResolution(SyncEntityKind.SUBJECT, "s1", SyncConflictResolutionStrategy.KEEP_REMOTE)),
            local = local,
            conflicts = listOf(conflict),
            resolvedAt = 2_000
        )

        assertEquals(2, resolved.subjects.single().color)
        assertEquals(2_000, resolved.subjects.single().updatedAt)
        assertEquals(
            listOf("s1"),
            SyncDeltaSerializer.changedSince(resolved, SyncDeltaCursor(updatedAt = 1_100, documentId = "subject-s1")).map { it.syncId }
        )
    }

    private fun appData(
        subjects: List<Subject> = emptyList(),
        materials: List<Material> = emptyList()
    ): AppData = AppData(
        subjects = subjects,
        materials = materials,
        sessions = emptyList(),
        goals = emptyList(),
        exams = emptyList(),
        plans = emptyList(),
        exportDate = 0L
    )

    private fun subject(syncId: String, updatedAt: Long, color: Int = 0) = Subject(
        syncId = syncId,
        name = "Subject $syncId",
        color = color,
        updatedAt = updatedAt
    )

    private fun material(
        syncId: String,
        currentPage: Int = 0,
        updatedAt: Long = 0,
        deletedAt: Long? = null,
        problemRecords: List<ProblemSessionRecord> = emptyList()
    ) = Material(
        syncId = syncId,
        name = "Material $syncId",
        subjectId = 1,
        currentPage = currentPage,
        updatedAt = updatedAt,
        deletedAt = deletedAt,
        problemRecords = problemRecords
    )

    private fun envelope(
        kind: SyncEntityKind,
        syncId: String,
        updatedAt: Long,
        deletedAt: Long? = null,
        json: String
    ) = SyncEntityEnvelope(kind, syncId, updatedAt, deletedAt, json)
}
