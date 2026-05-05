package com.studyapp.domain.model

import org.junit.Assert.assertEquals
import org.junit.Test

class MaterialTest {
    @Test
    fun `progress is clamped between zero and one`() {
        assertEquals(0.5, Material(name = "Book", subjectId = 1, totalPages = 100, currentPage = 50).progress, 0.001)
        assertEquals(1.0, Material(name = "Book", subjectId = 1, totalPages = 100, currentPage = 120).progress, 0.001)
        assertEquals(0.0, Material(name = "Book", subjectId = 1, totalPages = 0, currentPage = 10).progress, 0.001)
    }

    @Test
    fun `effectiveTotalProblems is derived from chapters when present`() {
        val material = Material(
            name = "Workbook",
            subjectId = 1,
            totalProblems = 50,
            problemChapters = listOf(
                ProblemChapter(title = "A", problemCount = 10),
                ProblemChapter(title = "B", problemCount = 20)
            )
        )

        assertEquals(30, material.effectiveTotalProblems)
    }
}
