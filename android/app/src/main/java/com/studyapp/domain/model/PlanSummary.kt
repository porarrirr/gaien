package com.studyapp.domain.model

data class DailyPlan(
    val date: Long,
    val items: List<PlanItemWithSubject>
)

data class PlanItemWithSubject(
    val item: PlanItem,
    val subject: Subject
) {
    val id: Long get() = item.id
}

data class WeeklyPlanSummary(
    val weekStart: Long,
    val weekEnd: Long,
    val totalTargetMinutes: Int,
    val totalActualMinutes: Int,
    val dailyBreakdown: Map<StudyWeekday, DailyPlanSummary>
)

data class DailyPlanSummary(
    val dayOfWeek: StudyWeekday,
    val targetMinutes: Int,
    val actualMinutes: Int,
    val completionRate: Float
)
