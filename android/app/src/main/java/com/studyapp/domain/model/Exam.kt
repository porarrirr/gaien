package com.studyapp.domain.model

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

data class Exam(
    val id: Long = 0,
    val name: String,
    val date: LocalDate,
    val note: String? = null
) {
    fun getDaysRemaining(currentDate: LocalDate): Long {
        return ChronoUnit.DAYS.between(currentDate, date)
    }
    
    fun isPast(currentDate: LocalDate): Boolean {
        return date < currentDate
    }
    
    fun isToday(currentDate: LocalDate): Boolean {
        return date == currentDate
    }
    
    companion object {
        fun fromTimestamp(
            id: Long = 0,
            name: String,
            timestamp: Long,
            note: String? = null,
            zoneId: ZoneId = ZoneId.systemDefault()
        ): Exam {
            return Exam(
                id = id,
                name = name,
                date = Instant.ofEpochMilli(timestamp).atZone(zoneId).toLocalDate(),
                note = note
            )
        }
    }
    
    fun toEpochMillis(zoneId: ZoneId = ZoneId.systemDefault()): Long {
        return date.atStartOfDay(zoneId).toInstant().toEpochMilli()
    }
}
