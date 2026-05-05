package com.studyapp.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class GoalTest {
    @Test
    fun `formatMinutes formats Japanese duration labels`() {
        assertEquals("45分", Goal.formatMinutes(45))
        assertEquals("2時間", Goal.formatMinutes(120))
        assertEquals("2時間30分", Goal.formatMinutes(150))
    }

    @Test
    fun `latestActiveDailyGoal picks newest active goal for weekday`() {
        val old = Goal(
            id = 1,
            type = GoalType.DAILY,
            targetMinutes = 30,
            dayOfWeek = StudyWeekday.MONDAY,
            updatedAt = 100
        )
        val newer = old.copy(id = 2, targetMinutes = 60, updatedAt = 200)
        val inactive = old.copy(id = 3, targetMinutes = 120, isActive = false, updatedAt = 300)

        assertEquals(newer, listOf(old, newer, inactive).latestActiveDailyGoal(StudyWeekday.MONDAY))
        assertNull(listOf(old).latestActiveDailyGoal(StudyWeekday.TUESDAY))
    }

    @Test
    fun `latestActiveWeeklyGoal ignores deleted goals`() {
        val deleted = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 120, updatedAt = 300, deletedAt = 400)
        val active = Goal(id = 2, type = GoalType.WEEKLY, targetMinutes = 180, updatedAt = 200)

        assertEquals(active, listOf(deleted, active).latestActiveWeeklyGoal())
    }
}
