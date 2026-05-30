package com.studyapp.testutil

import com.studyapp.domain.util.Clock
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

class FixedClock(
    private val nowMillis: Long,
    private val zoneId: ZoneId = ZoneId.systemDefault()
) : Clock {
    override fun currentTimeMillis(): Long = nowMillis

    override fun currentLocalDate(): LocalDate =
        Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDate()

    override fun currentLocalDateTime(): LocalDateTime =
        Instant.ofEpochMilli(nowMillis).atZone(zoneId).toLocalDateTime()

    override fun startOfDay(timestamp: Long): Long =
        Instant.ofEpochMilli(timestamp)
            .atZone(zoneId)
            .toLocalDate()
            .atStartOfDay(zoneId)
            .toInstant()
            .toEpochMilli()

    override fun startOfToday(): Long = startOfDay(nowMillis)

    override fun startOfWeek(): Long {
        val today = currentLocalDate()
        val start = today.minusDays((today.dayOfWeek.value - DayOfWeek.MONDAY.value).toLong())
        return start.atStartOfDay(zoneId).toInstant().toEpochMilli()
    }

    override fun startOfMonth(): Long =
        currentLocalDate()
            .withDayOfMonth(1)
            .atStartOfDay(zoneId)
            .toInstant()
            .toEpochMilli()
}
