package com.studyapp.domain.model

data class DailyStudyData(
    val date: Long,
    val dateLabel: String,
    val minutes: Int,
    val hours: Double,
    val segments: List<SubjectStudySegment> = emptyList()
) {
    val id: Long get() = date
}

data class WeeklyStudyData(
    val weekStart: Long,
    val weekLabel: String,
    val hours: Int,
    val minutes: Int,
    val segments: List<SubjectStudySegment> = emptyList()
) {
    val id: Long get() = weekStart
}

data class SubjectStudySegment(
    val subjectId: Long,
    val subjectName: String,
    val minutes: Int,
    val color: Int
) {
    val id: Long get() = subjectId
}

data class MonthlyStudyData(
    val monthStart: Long,
    val monthLabel: String,
    val totalHours: Int
) {
    val id: Long get() = monthStart
}

data class SubjectStudyData(
    val subjectName: String,
    val hours: Int,
    val minutes: Int,
    val color: Int
) {
    val id: String get() = subjectName
}

data class RatingAverageSummary(
    val average: Double? = null,
    val ratedMinutes: Int = 0
)

data class RatingAveragesData(
    val today: RatingAverageSummary = RatingAverageSummary(),
    val week: RatingAverageSummary = RatingAverageSummary(),
    val month: RatingAverageSummary = RatingAverageSummary()
)

data class BookInfo(
    val title: String,
    val authors: List<String>,
    val publisher: String? = null,
    val publishedDate: String? = null,
    val pageCount: Int? = null,
    val thumbnailUrl: String? = null
)

data class MaterialListProgressSummary(
    val totalProblems: Int = 0,
    val correctCount: Int = 0,
    val mixedCount: Int = 0,
    val untouchedCount: Int = 0,
    val latestStudyDate: Long? = null
) {
    val progressedCount: Int get() = correctCount + mixedCount
    val progressedRatio: Double get() = if (totalProblems > 0) progressedCount.toDouble() / totalProblems.toDouble() else 0.0
    val progressedPercent: Int get() = (progressedRatio * 100).toInt()
}
