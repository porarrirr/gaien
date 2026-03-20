package com.studyapp.domain.model

import java.time.DayOfWeek

data class DailyPlan(
    val date: Long,
    val items: List<PlanItemWithSubject>
)

data class PlanItemWithSubject(
    val item: PlanItem,
    val subject: Subject
)

data class WeeklyPlanSummary(
    val weekStart: Long,
    val weekEnd: Long,
    val totalTargetMinutes: Int,
    val totalActualMinutes: Int,
    val dailyBreakdown: Map<DayOfWeek, DailyPlanSummary>
)

data class DailyPlanSummary(
    val dayOfWeek: DayOfWeek,
    val targetMinutes: Int,
    val actualMinutes: Int,
    val completionRate: Float
)