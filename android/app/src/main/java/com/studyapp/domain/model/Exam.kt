package com.studyapp.domain.model

import java.time.LocalDate
import java.time.temporal.ChronoUnit
import java.util.UUID

data class Exam(
    val id: Long = 0,
    val syncId: String = UUID.randomUUID().toString().lowercase(),
    val name: String,
    val date: Long,
    val note: String? = null,
    val createdAt: Long = System.currentTimeMillis(),
    val updatedAt: Long = System.currentTimeMillis(),
    val deletedAt: Long? = null,
    val lastSyncedAt: Long? = null
) {
    val dateValue: LocalDate
        get() = LocalDate.ofEpochDay(date)

    fun daysRemaining(from: LocalDate = LocalDate.now()): Int {
        val start = from
        val end = dateValue
        return ChronoUnit.DAYS.between(start, end).toInt()
    }

    fun isPast(from: LocalDate = LocalDate.now()): Boolean =
        daysRemaining(from) < 0

    fun isToday(from: LocalDate = LocalDate.now()): Boolean =
        dateValue == from
}
