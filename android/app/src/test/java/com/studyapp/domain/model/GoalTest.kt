package com.studyapp.domain.model

import org.junit.Assert.*
import org.junit.Test
import java.time.DayOfWeek

class GoalTest {
    
    @Test
    fun `hoursPart calculates correctly`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 150)
        assertEquals(2, goal.hoursPart)
        assertEquals(30, goal.minutesPart)
    }
    
    @Test
    fun `hoursPart returns 0 for less than 60 minutes`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 45)
        assertEquals(0, goal.hoursPart)
        assertEquals(45, goal.minutesPart)
    }
    
    @Test
    fun `hoursPart handles exact hours`() {
        val goal = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 120)
        assertEquals(2, goal.hoursPart)
        assertEquals(0, goal.minutesPart)
    }
    
    @Test
    fun `targetHours converts minutes to hours`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 120)
        assertEquals(2f, goal.targetHours, 0.01f)
    }
    
    @Test
    fun `targetHours returns correct decimal value`() {
        val goal = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 90)
        assertEquals(1.5f, goal.targetHours, 0.01f)
    }
    
    @Test
    fun `targetHours handles zero minutes`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 0)
        assertEquals(0f, goal.targetHours, 0.01f)
    }
    
    @Test
    fun `targetFormatted shows hours and minutes`() {
        val goal = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 90)
        assertEquals("1時間30分", goal.targetFormatted)
    }
    
    @Test
    fun `targetFormatted shows only minutes when less than hour`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 45)
        assertEquals("45分", goal.targetFormatted)
    }
    
    @Test
    fun `targetFormatted shows only hours when exact hours`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 120)
        assertEquals("2時間", goal.targetFormatted)
    }
    
    @Test
    fun `targetFormatted handles zero target minutes`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 0)
        assertEquals("0分", goal.targetFormatted)
    }
    
    @Test
    fun `default values are correct`() {
        val goal = Goal(type = GoalType.DAILY, targetMinutes = 30)
        assertEquals(0L, goal.id)
        assertEquals(DayOfWeek.MONDAY, goal.weekStartDay)
        assertTrue(goal.isActive)
    }
    
    @Test
    fun `weekStartDay can be set to Sunday`() {
        val goal = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 100, weekStartDay = DayOfWeek.SUNDAY)
        assertEquals(DayOfWeek.SUNDAY, goal.weekStartDay)
    }
    
    @Test
    fun `weekStartDay can be set to different days`() {
        val goal = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 100, weekStartDay = DayOfWeek.FRIDAY)
        assertEquals(DayOfWeek.FRIDAY, goal.weekStartDay)
    }
    
    @Test
    fun `isActive can be set to false`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 60, isActive = false)
        assertFalse(goal.isActive)
    }
    
    @Test
    fun `goalType is DAILY for daily goals`() {
        val goal = Goal(type = GoalType.DAILY, targetMinutes = 60)
        assertEquals(GoalType.DAILY, goal.type)
    }
    
    @Test
    fun `goalType is WEEKLY for weekly goals`() {
        val goal = Goal(type = GoalType.WEEKLY, targetMinutes = 300)
        assertEquals(GoalType.WEEKLY, goal.type)
    }
    
    @Test
    fun `large targetMinutes calculates correctly`() {
        val goal = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 600)
        assertEquals(10f, goal.targetHours, 0.01f)
        assertEquals(10, goal.hoursPart)
        assertEquals(0, goal.minutesPart)
    }
    
    @Test
    fun `very large targetMinutes calculates correctly`() {
        val goal = Goal(id = 1, type = GoalType.WEEKLY, targetMinutes = 1234)
        assertEquals(20, goal.hoursPart)
        assertEquals(34, goal.minutesPart)
        assertEquals(20.566666f, goal.targetHours, 0.001f)
    }
    
    @Test
    fun `minutesPart handles edge case 59 minutes`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 59)
        assertEquals(0, goal.hoursPart)
        assertEquals(59, goal.minutesPart)
    }
    
    @Test
    fun `minutesPart handles edge case 61 minutes`() {
        val goal = Goal(id = 1, type = GoalType.DAILY, targetMinutes = 61)
        assertEquals(1, goal.hoursPart)
        assertEquals(1, goal.minutesPart)
    }
}