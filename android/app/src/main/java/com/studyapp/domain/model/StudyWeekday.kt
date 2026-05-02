package com.studyapp.domain.model

import java.time.DayOfWeek

enum class StudyWeekday {
    MONDAY,
    TUESDAY,
    WEDNESDAY,
    THURSDAY,
    FRIDAY,
    SATURDAY,
    SUNDAY;

    val japaneseShortTitle: String
        get() = when (this) {
            MONDAY -> "月"
            TUESDAY -> "火"
            WEDNESDAY -> "水"
            THURSDAY -> "木"
            FRIDAY -> "金"
            SATURDAY -> "土"
            SUNDAY -> "日"
        }

    val japaneseTitle: String
        get() = japaneseShortTitle + "曜日"

    val calendarWeekday: Int
        get() = when (this) {
            SUNDAY -> 1
            MONDAY -> 2
            TUESDAY -> 3
            WEDNESDAY -> 4
            THURSDAY -> 5
            FRIDAY -> 6
            SATURDAY -> 7
        }

    fun toDayOfWeek(): DayOfWeek = when (this) {
        MONDAY -> DayOfWeek.MONDAY
        TUESDAY -> DayOfWeek.TUESDAY
        WEDNESDAY -> DayOfWeek.WEDNESDAY
        THURSDAY -> DayOfWeek.THURSDAY
        FRIDAY -> DayOfWeek.FRIDAY
        SATURDAY -> DayOfWeek.SATURDAY
        SUNDAY -> DayOfWeek.SUNDAY
    }

    companion object {
        fun from(calendarWeekday: Int): StudyWeekday = when (calendarWeekday) {
            1 -> SUNDAY
            2 -> MONDAY
            3 -> TUESDAY
            4 -> WEDNESDAY
            5 -> THURSDAY
            6 -> FRIDAY
            else -> SATURDAY
        }

        fun fromDayOfWeek(dayOfWeek: DayOfWeek): StudyWeekday = when (dayOfWeek) {
            DayOfWeek.MONDAY -> MONDAY
            DayOfWeek.TUESDAY -> TUESDAY
            DayOfWeek.WEDNESDAY -> WEDNESDAY
            DayOfWeek.THURSDAY -> THURSDAY
            DayOfWeek.FRIDAY -> FRIDAY
            DayOfWeek.SATURDAY -> SATURDAY
            DayOfWeek.SUNDAY -> SUNDAY
        }

        val timetableDays: List<StudyWeekday> = listOf(MONDAY, TUESDAY, WEDNESDAY, THURSDAY, FRIDAY, SATURDAY)
    }
}
