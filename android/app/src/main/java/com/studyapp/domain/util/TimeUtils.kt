package com.studyapp.domain.util

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.util.Locale
import java.util.concurrent.TimeUnit

object TimeUtils {
    private val zoneId = ZoneId.systemDefault()
    
    fun toLocalDate(timestamp: Long): LocalDate = 
        Instant.ofEpochMilli(timestamp).atZone(zoneId).toLocalDate()
    
    fun toEpochMillis(date: LocalDate): Long = 
        date.atStartOfDay(zoneId).toInstant().toEpochMilli()
    
    fun formatDuration(milliseconds: Long): String {
        val hours = milliseconds / 3600000
        val minutes = (milliseconds % 3600000) / 60000
        val seconds = (milliseconds % 60000) / 1000
        return when {
            hours > 0 -> String.format("%d:%02d:%02d", hours, minutes, seconds)
            else -> String.format("%02d:%02d", minutes, seconds)
        }
    }
    
    fun formatDurationShort(milliseconds: Long): String {
        val hours = TimeUnit.MILLISECONDS.toHours(milliseconds)
        val minutes = TimeUnit.MILLISECONDS.toMinutes(milliseconds) % 60
        return when {
            hours > 0 -> "${hours}h ${minutes}m"
            else -> "${minutes}m"
        }
    }
    
    fun formatDurationLong(milliseconds: Long): String {
        val hours = TimeUnit.MILLISECONDS.toHours(milliseconds)
        val minutes = TimeUnit.MILLISECONDS.toMinutes(milliseconds) % 60
        return when {
            hours > 0 && minutes > 0 -> "${hours}時間${minutes}分"
            hours > 0 -> "${hours}時間"
            else -> "${minutes}分"
        }
    }
}

private val dateFormatFull = DateTimeFormatter.ofPattern("yyyy年M月d日 (E)", Locale.JAPANESE)
private val dateFormatShort = DateTimeFormatter.ofPattern("M月d日", Locale.JAPANESE)
private val dateFormatMonth = DateTimeFormatter.ofPattern("yyyy年M月", Locale.JAPANESE)
private val timeFormat = DateTimeFormatter.ofPattern("HH:mm", Locale.JAPANESE)
private val dateTimeFormat = DateTimeFormatter.ofPattern("yyyy/M/d HH:mm", Locale.JAPANESE)

fun Long.toLocalDate(): LocalDate = TimeUtils.toLocalDate(this)
fun LocalDate.toEpochMillis(): Long = TimeUtils.toEpochMillis(this)
fun Long.formatDateFull(): String = this.toLocalDate().format(dateFormatFull)
fun Long.formatDateShort(): String = this.toLocalDate().format(dateFormatShort)
fun Long.formatMonth(): String = this.toLocalDate().format(dateFormatMonth)
fun Long.formatTime(): String = Instant.ofEpochMilli(this).atZone(ZoneId.systemDefault()).format(timeFormat)
fun Long.formatDateTime(): String = Instant.ofEpochMilli(this).atZone(ZoneId.systemDefault()).format(dateTimeFormat)
