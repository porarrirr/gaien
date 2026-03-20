package com.studyapp.domain.util

import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import javax.inject.Inject
import javax.inject.Singleton

interface Clock {
    fun currentTimeMillis(): Long
    fun currentLocalDate(): LocalDate
    fun currentLocalDateTime(): LocalDateTime
    fun startOfDay(timestamp: Long): Long
    fun startOfToday(): Long
    fun startOfWeek(): Long
    fun startOfMonth(): Long
}

@Singleton
class SystemClock @Inject constructor() : Clock {
    private val zoneId = ZoneId.systemDefault()
    
    override fun currentTimeMillis(): Long = System.currentTimeMillis()
    
    override fun currentLocalDate(): LocalDate = LocalDate.now(zoneId)
    
    override fun currentLocalDateTime(): LocalDateTime = LocalDateTime.now(zoneId)
    
    override fun startOfDay(timestamp: Long): Long {
        return java.util.Calendar.getInstance().apply {
            timeInMillis = timestamp
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
    
    override fun startOfToday(): Long = startOfDay(currentTimeMillis())
    
    override fun startOfWeek(): Long {
        return java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.DAY_OF_WEEK, firstDayOfWeek)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
    
    override fun startOfMonth(): Long {
        return java.util.Calendar.getInstance().apply {
            set(java.util.Calendar.DAY_OF_MONTH, 1)
            set(java.util.Calendar.HOUR_OF_DAY, 0)
            set(java.util.Calendar.MINUTE, 0)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
        }.timeInMillis
    }
}