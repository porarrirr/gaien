package com.studyapp.domain.util

import java.time.ZoneId
import java.time.ZonedDateTime
import java.util.TimeZone
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Before
import org.junit.Test

class TimeUtilsTest {

    private lateinit var originalTimeZone: TimeZone

    @Before
    fun setUp() {
        originalTimeZone = TimeZone.getDefault()
        TimeZone.setDefault(TimeZone.getTimeZone("Asia/Tokyo"))
    }

    @After
    fun tearDown() {
        TimeZone.setDefault(originalTimeZone)
    }

    @Test
    fun `formatTime formats the local time component`() {
        val timestamp = ZonedDateTime.of(2024, 1, 15, 14, 30, 0, 0, ZoneId.of("Asia/Tokyo"))
            .toInstant()
            .toEpochMilli()

        assertEquals("14:30", timestamp.formatTime())
    }

    @Test
    fun `formatDateTime formats the local date and time`() {
        val timestamp = ZonedDateTime.of(2024, 1, 15, 14, 30, 0, 0, ZoneId.of("Asia/Tokyo"))
            .toInstant()
            .toEpochMilli()

        assertEquals("2024/1/15 14:30", timestamp.formatDateTime())
    }
}
