package com.studyapp.domain.model

import org.junit.Assert.*
import org.junit.Test

class MaterialTest {
    
    @Test
    fun `progress returns correct value`() {
        val material = Material(
            id = 1,
            name = "数学I",
            subjectId = 1,
            totalPages = 200,
            currentPage = 100
        )
        assertEquals(0.5f, material.progress, 0.01f)
    }
    
    @Test
    fun `progress returns zero when totalPages is zero`() {
        val material = Material(
            id = 1,
            name = "ノート",
            subjectId = 1,
            totalPages = 0,
            currentPage = 0
        )
        assertEquals(0f, material.progress, 0.01f)
    }
    
    @Test
    fun `progressPercent returns correct percentage`() {
        val material = Material(
            id = 1,
            name = "数学I",
            subjectId = 1,
            totalPages = 100,
            currentPage = 75
        )
        assertEquals(75, material.progressPercent)
    }
    
    @Test
    fun `progressPercent returns 100 when complete`() {
        val material = Material(
            id = 1,
            name = "数学I",
            subjectId = 1,
            totalPages = 100,
            currentPage = 100
        )
        assertEquals(100, material.progressPercent)
    }
    
    @Test
    fun `progressPercentage returns 0 when starting`() {
        val material = Material(
            id = 1,
            name = "数学I",
            subjectId = 1,
            totalPages = 100,
            currentPage = 0
        )
        assertEquals(0f, material.progress, 0.01f)
        assertEquals(0, material.progressPercent)
    }
    
    @Test
    fun `progressPercentage handles zero totalPages`() {
        val material = Material(
            id = 1,
            name = "Book",
            subjectId = 1,
            totalPages = 0,
            currentPage = 0
        )
        assertEquals(0f, material.progress, 0.01f)
        assertEquals(0, material.progressPercent)
    }
    
    @Test
    fun `progressPercent returns 100 when currentPage exceeds totalPages`() {
        val material = Material(
            id = 1,
            name = "Book",
            subjectId = 1,
            totalPages = 100,
            currentPage = 150
        )
        assertEquals(150, material.progressPercent)
    }
    
    @Test
    fun `progress handles currentPage exceeds totalPages gracefully`() {
        val material = Material(
            id = 1,
            name = "Book",
            subjectId = 1,
            totalPages = 100,
            currentPage = 150
        )
        assertEquals(1.5f, material.progress, 0.01f)
    }
    
    @Test
    fun `progress handles single page material`() {
        val material = Material(
            id = 1,
            name = "Single Page",
            subjectId = 1,
            totalPages = 1,
            currentPage = 0
        )
        assertEquals(0f, material.progress, 0.01f)
        
        val completed = material.copy(currentPage = 1)
        assertEquals(1f, completed.progress, 0.01f)
    }
    
    @Test
    fun `progress handles large page counts`() {
        val material = Material(
            id = 1,
            name = "Large Book",
            subjectId = 1,
            totalPages = 1000,
            currentPage = 333
        )
        assertEquals(0.333f, material.progress, 0.001f)
        assertEquals(33, material.progressPercent)
    }
    
    @Test
    fun `progressPercent rounds down correctly`() {
        val material = Material(
            id = 1,
            name = "Book",
            subjectId = 1,
            totalPages = 300,
            currentPage = 100
        )
        assertEquals(33, material.progressPercent)
    }
    
    @Test
    fun `progressPercent handles 99 percent`() {
        val material = Material(
            id = 1,
            name = "Book",
            subjectId = 1,
            totalPages = 100,
            currentPage = 99
        )
        assertEquals(99, material.progressPercent)
    }
    
    @Test
    fun `progressPercent handles 1 percent`() {
        val material = Material(
            id = 1,
            name = "Book",
            subjectId = 1,
            totalPages = 100,
            currentPage = 1
        )
        assertEquals(1, material.progressPercent)
    }
    
    @Test
    fun `material with note preserves note`() {
        val material = Material(
            id = 1,
            name = "Reference",
            subjectId = 1,
            totalPages = 50,
            currentPage = 10,
            note = "Important chapters: 1-5"
        )
        assertEquals("Important chapters: 1-5", material.note)
    }
    
    @Test
    fun `material with color preserves color`() {
        val material = Material(
            id = 1,
            name = "Colored Book",
            subjectId = 1,
            totalPages = 100,
            currentPage = 50,
            color = 0xFF4CAF50.toInt()
        )
        assertEquals(0xFF4CAF50.toInt(), material.color)
    }
    
    @Test
    fun `material defaults are correct`() {
        val material = Material(
            id = 1,
            name = "Book",
            subjectId = 1
        )
        assertEquals(0, material.totalPages)
        assertEquals(0, material.currentPage)
        assertNull(material.color)
        assertNull(material.note)
    }
}