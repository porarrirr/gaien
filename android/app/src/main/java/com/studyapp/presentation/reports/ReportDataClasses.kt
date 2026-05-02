package com.studyapp.presentation.reports

data class DailyStudyData(
    val dateLabel: String,
    val dateMillis: Long,
    val minutes: Long,
    val hours: Float,
    val segments: List<SubjectStudySegment> = emptyList()
)

data class WeeklyStudyData(
    val weekLabel: String,
    val hours: Long,
    val minutes: Long,
    val segments: List<SubjectStudySegment> = emptyList()
)

data class SubjectStudySegment(
    val subjectId: Long,
    val subjectName: String,
    val minutes: Long,
    val color: Int
)

data class MonthlyStudyData(
    val monthLabel: String,
    val totalHours: Long
)

data class SubjectStudyData(
    val subjectName: String,
    val hours: Long,
    val minutes: Long,
    val color: Int
)

data class RatingAverageSummary(
    val average: Double? = null,
    val ratedMinutes: Int = 0
)

data class RatingAveragesData(
    val today: RatingAverageSummary = RatingAverageSummary(),
    val week: RatingAverageSummary = RatingAverageSummary(),
    val month: RatingAverageSummary = RatingAverageSummary()
)
