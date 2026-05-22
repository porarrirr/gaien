package com.studyapp.sync

import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.Subject
import com.studyapp.domain.usecase.AppData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Test

class SyncMergeEngineTest {

    @Test
    fun merge_keepsNewerUpdatedAt() {
        val local = listOf(subject(syncId = "s1", updatedAt = 1_000, color = 1))
        val remote = listOf(subject(syncId = "s1", updatedAt = 2_000, color = 2))

        val merged = SyncMergeEngine.merge(appData(subjects = local), appData(subjects = remote))

        assertEquals(1, merged.subjects.size)
        assertEquals(2, merged.subjects.first().color)
    }

    @Test
    fun merge_tombstoneWinsOverNewerNonDeleted() {
        val local = listOf(subject(syncId = "s1", updatedAt = 1_000, color = 1))
        val remote = listOf(subject(syncId = "s1", updatedAt = 500, color = 2, deletedAt = 1_500))

        val merged = SyncMergeEngine.merge(appData(subjects = local), appData(subjects = remote))

        assertEquals(1, merged.subjects.size)
        assertNotNull(merged.subjects.first().deletedAt)
    }

    @Test
    fun mergeMaterials_preservesProblemProgressFromOlderSide() {
        val localMaterial = material(
            syncId = "m1",
            updatedAt = 1_000,
            problemRecords = listOf(ProblemSessionRecord(number = 1, result = ProblemResult.WRONG)),
            totalProblems = 50
        )
        val remoteMaterial = material(syncId = "m1", updatedAt = 2_000, problemRecords = emptyList(), totalProblems = 0)

        val merged = SyncMergeEngine.mergeMaterials(listOf(localMaterial), listOf(remoteMaterial))

        assertEquals(1, merged.size)
        assertEquals(1, merged.first().problemRecords.size)
        assertEquals(50, merged.first().totalProblems)
    }

    @Test
    fun syncProgressGuard_detectsLoss() {
        val source = appData(
            materials = listOf(
                material(syncId = "m1", totalProblems = 10, problemRecords = listOf(ProblemSessionRecord(1, ProblemResult.CORRECT)))
            )
        )
        val destination = appData(materials = listOf(material(syncId = "m1", totalProblems = 0, problemRecords = emptyList())))

        assertEquals(true, SyncProgressGuard.wouldLoseProgress(source, destination))
    }

    private fun appData(
        subjects: List<Subject> = emptyList(),
        materials: List<Material> = emptyList()
    ): AppData {
        return AppData(
            subjects = subjects,
            materials = materials,
            sessions = emptyList(),
            goals = emptyList(),
            exams = emptyList(),
            plans = emptyList(),
            exportDate = 0L
        )
    }

    private fun subject(
        syncId: String,
        updatedAt: Long,
        color: Int = 0,
        deletedAt: Long? = null
    ): Subject {
        return Subject(
            syncId = syncId,
            name = "Subject",
            color = color,
            updatedAt = updatedAt,
            deletedAt = deletedAt
        )
    }

    private fun material(
        syncId: String,
        updatedAt: Long = 0L,
        problemRecords: List<ProblemSessionRecord> = emptyList(),
        totalProblems: Int = 0
    ): Material {
        return Material(
            syncId = syncId,
            name = "Material",
            subjectId = 1L,
            totalProblems = totalProblems,
            problemRecords = problemRecords,
            updatedAt = updatedAt
        )
    }
}
