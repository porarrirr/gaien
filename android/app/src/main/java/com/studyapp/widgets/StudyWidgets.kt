package com.studyapp.widgets

import android.content.Context
import android.content.Intent
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.background
import androidx.glance.action.Action
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.appWidgetBackground
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.appwidget.action.actionStartActivity
import androidx.glance.color.ColorProvider
import androidx.glance.layout.Alignment
import androidx.glance.layout.Box
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.Spacer
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.fillMaxWidth
import androidx.glance.layout.height
import androidx.glance.layout.padding
import androidx.glance.layout.width
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.studyapp.MainActivity
import kotlin.math.roundToInt

object StudyWidgets {
    private val allWidgets: List<GlanceAppWidget> = listOf(
        TodayStudyAppWidget,
        WeeklyGoalAppWidget,
        StudyStreakAppWidget,
        ExamCountdownAppWidget,
        WeeklyActivityAppWidget,
        DailyGoalAppWidget,
        StudySummaryAppWidget,
        UpcomingExamListAppWidget,
        WeeklyPaceAppWidget
    )

    suspend fun updateAll(context: Context) {
        allWidgets.forEach { widget ->
            widget.updateAll(context)
        }
        StackStudyWidgetReceiver.updateAll(context)
    }
}

private object WidgetPalette {
    val Background = ColorProvider(
        day = Color(0xFFFFFFFF),
        night = Color(0xFF1C1B1F)
    )
    val Primary = ColorProvider(
        day = Color(0xFF4CAF50),
        night = Color(0xFF81C784)
    )
    val Secondary = ColorProvider(
        day = Color(0xFF2196F3),
        night = Color(0xFF64B5F6)
    )
    val Warning = ColorProvider(
        day = Color(0xFFFF9800),
        night = Color(0xFFFFB74D)
    )
    val Danger = ColorProvider(
        day = Color(0xFFF44336),
        night = Color(0xFFEF9A9A)
    )
    val TextPrimary = ColorProvider(
        day = Color(0xDE000000),
        night = Color(0xFFFFFFFF)
    )
    val TextSecondary = ColorProvider(
        day = Color(0x99000000),
        night = Color(0xB3FFFFFF)
    )
    val TextTertiary = ColorProvider(
        day = Color(0x61000000),
        night = Color(0x80FFFFFF)
    )
    val Track = ColorProvider(
        day = Color(0x1F000000),
        night = Color(0x33FFFFFF)
    )
}

private val TitleTextStyle = TextStyle(
    color = WidgetPalette.TextSecondary,
    fontSize = 12.sp,
    fontWeight = FontWeight.Medium
)

private val HeroTextStyle = TextStyle(
    color = WidgetPalette.TextPrimary,
    fontSize = 28.sp,
    fontWeight = FontWeight.Bold
)

private val BodyTextStyle = TextStyle(
    color = WidgetPalette.TextPrimary,
    fontSize = 14.sp,
    fontWeight = FontWeight.Medium
)

private val CaptionTextStyle = TextStyle(
    color = WidgetPalette.TextTertiary,
    fontSize = 12.sp
)

abstract class BaseStudyWidget : GlanceAppWidget() {
    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val snapshot = loadStudyWidgetSnapshot(context)
        val openAppAction = openAppAction(context)
        provideContent {
            WidgetSurface(openAppAction) {
                Content(snapshot)
            }
        }
    }

    @Composable
    protected abstract fun Content(snapshot: StudyWidgetSnapshot)
}

object TodayStudyAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Text(text = "今日の学習", style = TitleTextStyle)
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(text = snapshot.todayStudyMinutes.toDurationText(), style = HeroTextStyle)
            Spacer(modifier = GlanceModifier.height(10.dp))
            SegmentedProgress(progress = snapshot.todayProgress)
            Spacer(modifier = GlanceModifier.height(10.dp))
            val caption = if (snapshot.todaySessionCount > 0) {
                "${snapshot.todaySessionCount}件のセッション"
            } else {
                "タップして学習を始める"
            }
            Text(text = caption, style = CaptionTextStyle)
        }
    }
}

object WeeklyGoalAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        val goalMinutes = snapshot.weeklyGoalMinutes
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Text(text = "週間目標", style = TitleTextStyle)
            Spacer(modifier = GlanceModifier.height(8.dp))
            if (goalMinutes == null || goalMinutes <= 0) {
                Text(text = "未設定", style = HeroTextStyle)
                Spacer(modifier = GlanceModifier.height(10.dp))
                Text(text = "目標を設定してください", style = CaptionTextStyle)
            } else {
                Text(
                    text = "${(snapshot.weeklyProgress * 100f).roundToInt()}%",
                    style = HeroTextStyle
                )
                Spacer(modifier = GlanceModifier.height(10.dp))
                SegmentedProgress(progress = snapshot.weeklyProgress)
                Spacer(modifier = GlanceModifier.height(10.dp))
                Text(
                    text = "${snapshot.weeklyStudyMinutes.toDurationText()} / ${goalMinutes.toLong().toDurationText()}",
                    style = CaptionTextStyle
                )
            }
        }
    }
}

object StudyStreakAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Text(text = "連続学習", style = TitleTextStyle)
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(text = "${snapshot.streakDays}日", style = HeroTextStyle)
            Spacer(modifier = GlanceModifier.height(6.dp))
            val helper = if (snapshot.streakDays > 0) {
                "今日も継続中"
            } else {
                "今日の学習でスタート"
            }
            Text(text = helper, style = BodyTextStyle)
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(text = "最長 ${snapshot.bestStreak}日", style = CaptionTextStyle)
        }
    }
}

object ExamCountdownAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Text(text = "試験カウントダウン", style = TitleTextStyle)
            Spacer(modifier = GlanceModifier.height(8.dp))
            val nextExam = snapshot.upcomingExams.firstOrNull()
            if (nextExam == null) {
                Text(text = "予定なし", style = HeroTextStyle)
                Spacer(modifier = GlanceModifier.height(10.dp))
                Text(text = "今後の試験はありません", style = CaptionTextStyle)
            } else {
                Text(
                    text = examDaysText(nextExam.daysRemaining),
                    style = TextStyle(
                        color = examColor(nextExam.daysRemaining),
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold
                    )
                )
                Spacer(modifier = GlanceModifier.height(8.dp))
                Text(text = nextExam.name, style = BodyTextStyle)
                snapshot.upcomingExams.drop(1).take(2).forEach { exam ->
                    Spacer(modifier = GlanceModifier.height(4.dp))
                    Text(
                        text = "${exam.name} ${examDaysText(exam.daysRemaining)}",
                        style = CaptionTextStyle
                    )
                }
            }
        }
    }
}

object WeeklyActivityAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        WeeklyActivityChart(snapshot = snapshot, title = "今週の推移")
    }
}

object DailyGoalAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Text(text = "今日の目標", style = TitleTextStyle)
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(text = dailyGoalStatusText(snapshot), style = HeroTextStyle)
            Spacer(modifier = GlanceModifier.height(10.dp))
            SegmentedProgress(
                progress = snapshot.todayProgress,
                tint = if (snapshot.todayProgress >= 1f) WidgetPalette.Secondary else WidgetPalette.Primary
            )
            Spacer(modifier = GlanceModifier.height(10.dp))
            Text(text = dailyGoalDetailText(snapshot), style = CaptionTextStyle)
        }
    }
}

object StudySummaryAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Vertical.CenterVertically
            ) {
                Text(text = "学習サマリー", style = TitleTextStyle)
                Spacer(modifier = GlanceModifier.width(8.dp))
                Text(text = snapshot.generatedDateText, style = CaptionTextStyle)
            }
            Spacer(modifier = GlanceModifier.height(12.dp))
            MetricTileRow(
                left = MetricTileData("今日", snapshot.todayStudyMinutes.toDurationText(), WidgetPalette.Primary),
                right = MetricTileData("今週", snapshot.weeklyStudyMinutes.toDurationText(), WidgetPalette.Secondary)
            )
            Spacer(modifier = GlanceModifier.height(8.dp))
            MetricTileRow(
                left = MetricTileData("連続", "${snapshot.streakDays}日", WidgetPalette.Warning),
                right = MetricTileData("次の試験", nextExamSummaryText(snapshot), nextExamTint(snapshot))
            )
        }
    }
}

object UpcomingExamListAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Text(text = "試験一覧", style = TitleTextStyle)
            Spacer(modifier = GlanceModifier.height(12.dp))
            if (snapshot.upcomingExams.isEmpty()) {
                Text(text = "予定なし", style = HeroTextStyle)
                Spacer(modifier = GlanceModifier.height(8.dp))
                Text(text = "登録した試験がここに表示されます", style = CaptionTextStyle)
            } else {
                snapshot.upcomingExams.take(2).forEachIndexed { index, exam ->
                    if (index > 0) {
                        Spacer(modifier = GlanceModifier.height(8.dp))
                    }
                    ExamListRow(exam = exam)
                }
            }
        }
    }
}

object WeeklyPaceAppWidget : BaseStudyWidget() {
    @Composable
    override fun Content(snapshot: StudyWidgetSnapshot) {
        val maxMinutes = snapshot.weekActivity.maxOfOrNull { it.minutes }?.coerceAtLeast(1L) ?: 1L
        Column(modifier = GlanceModifier.fillMaxSize()) {
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Vertical.CenterVertically
            ) {
                Text(text = "週間ペース", style = TitleTextStyle)
                Spacer(modifier = GlanceModifier.width(8.dp))
                Text(
                    text = "平均 ${snapshot.weekAverageMinutes.toCompactDurationText()}",
                    style = CaptionTextStyle
                )
            }
            Spacer(modifier = GlanceModifier.height(8.dp))
            Text(text = snapshot.weekTotalMinutes.toDurationText(), style = HeroTextStyle)
            Spacer(modifier = GlanceModifier.height(6.dp))
            Text(text = snapshot.weeklyPaceBestDayText, style = CaptionTextStyle)
            Spacer(modifier = GlanceModifier.height(12.dp))
            Row(
                modifier = GlanceModifier.fillMaxWidth(),
                verticalAlignment = Alignment.Vertical.Bottom
            ) {
                snapshot.weekActivity.forEachIndexed { index, day ->
                    if (index > 0) {
                        Spacer(modifier = GlanceModifier.width(6.dp))
                    }
                    DayBar(
                        summary = day,
                        maxMinutes = maxMinutes,
                        modifier = GlanceModifier.width(18.dp)
                    )
                }
            }
        }
    }
}

class TodayStudyWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = TodayStudyAppWidget
}

class WeeklyGoalWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = WeeklyGoalAppWidget
}

class StudyStreakWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StudyStreakAppWidget
}

class ExamCountdownWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = ExamCountdownAppWidget
}

class WeeklyActivityWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = WeeklyActivityAppWidget
}

class DailyGoalWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = DailyGoalAppWidget
}

class StudySummaryWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = StudySummaryAppWidget
}

class UpcomingExamListWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = UpcomingExamListAppWidget
}

class WeeklyPaceWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget: GlanceAppWidget = WeeklyPaceAppWidget
}

private data class MetricTileData(
    val title: String,
    val value: String,
    val tint: ColorProvider
)

@Composable
private fun WidgetSurface(
    onClick: Action,
    content: @Composable () -> Unit
) {
    Box(
        modifier = GlanceModifier
            .fillMaxSize()
            .appWidgetBackground()
            .background(WidgetPalette.Background)
            .clickable(onClick)
            .padding(16.dp)
    ) {
        content()
    }
}

@Composable
private fun SegmentedProgress(
    progress: Float,
    tint: ColorProvider = WidgetPalette.Primary
) {
    val filledSegments = (progress.coerceIn(0f, 1f) * 10f).roundToInt().coerceIn(0, 10)
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.Vertical.CenterVertically
    ) {
        repeat(10) { index ->
            if (index > 0) {
                Spacer(modifier = GlanceModifier.width(4.dp))
            }
            Box(
                modifier = GlanceModifier
                    .width(12.dp)
                    .height(6.dp)
                    .background(if (index < filledSegments) tint else WidgetPalette.Track)
            ) {}
        }
    }
}

@Composable
private fun WeeklyActivityChart(
    snapshot: StudyWidgetSnapshot,
    title: String
) {
    val maxMinutes = snapshot.weekActivity.maxOfOrNull { it.minutes }?.coerceAtLeast(1L) ?: 1L
    Column(modifier = GlanceModifier.fillMaxSize()) {
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Vertical.CenterVertically
        ) {
            Text(text = title, style = TitleTextStyle)
            Spacer(modifier = GlanceModifier.width(10.dp))
            Text(text = snapshot.weekTotalMinutes.toDurationText(), style = CaptionTextStyle)
        }
        Spacer(modifier = GlanceModifier.height(12.dp))
        Row(
            modifier = GlanceModifier.fillMaxWidth(),
            verticalAlignment = Alignment.Vertical.Bottom
        ) {
            snapshot.weekActivity.forEachIndexed { index, day ->
                if (index > 0) {
                    Spacer(modifier = GlanceModifier.width(6.dp))
                }
                DayBar(
                    summary = day,
                    maxMinutes = maxMinutes,
                    modifier = GlanceModifier.width(18.dp)
                )
            }
        }
    }
}

@Composable
private fun MetricTileRow(
    left: MetricTileData,
    right: MetricTileData
) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.Vertical.Top
    ) {
        MetricTile(data = left, modifier = GlanceModifier.defaultWeight())
        Spacer(modifier = GlanceModifier.width(8.dp))
        MetricTile(data = right, modifier = GlanceModifier.defaultWeight())
    }
}

@Composable
private fun MetricTile(
    data: MetricTileData,
    modifier: GlanceModifier = GlanceModifier
) {
    Column(modifier = modifier) {
        Text(text = data.title, style = CaptionTextStyle)
        Spacer(modifier = GlanceModifier.height(4.dp))
        Text(
            text = data.value,
            style = TextStyle(
                color = data.tint,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold
            )
        )
    }
}

@Composable
private fun ExamListRow(exam: WidgetExamSummary) {
    Row(
        modifier = GlanceModifier.fillMaxWidth(),
        verticalAlignment = Alignment.Vertical.CenterVertically
    ) {
        Column(
            modifier = GlanceModifier.width(46.dp),
            horizontalAlignment = Alignment.Horizontal.CenterHorizontally
        ) {
            Text(
                text = if (exam.daysRemaining <= 0L) "今日" else "${exam.daysRemaining}",
                style = TextStyle(
                    color = examColor(exam.daysRemaining),
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            )
            if (exam.daysRemaining > 0L) {
                Text(text = "日", style = CaptionTextStyle)
            }
        }
        Spacer(modifier = GlanceModifier.width(10.dp))
        Column(modifier = GlanceModifier.defaultWeight()) {
            Text(text = exam.name, style = BodyTextStyle)
            Spacer(modifier = GlanceModifier.height(2.dp))
            Text(text = exam.examDateText(), style = CaptionTextStyle)
        }
    }
}

private fun dailyGoalStatusText(snapshot: StudyWidgetSnapshot): String {
    val goal = snapshot.dailyGoalMinutes
    if (goal == null || goal <= 0) return "目標未設定"
    val remaining = (goal.toLong() - snapshot.todayStudyMinutes).coerceAtLeast(0L)
    return if (remaining == 0L) "達成済み" else "残り${remaining.toDurationText()}"
}

private fun dailyGoalDetailText(snapshot: StudyWidgetSnapshot): String {
    val goal = snapshot.dailyGoalMinutes
    if (goal == null || goal <= 0) return "アプリで今日の目標を設定"
    return "${snapshot.todayStudyMinutes.toDurationText()} / ${goal.toLong().toDurationText()}"
}

private fun nextExamSummaryText(snapshot: StudyWidgetSnapshot): String {
    val exam = snapshot.upcomingExams.firstOrNull() ?: return "予定なし"
    return examDaysText(exam.daysRemaining)
}

private fun nextExamTint(snapshot: StudyWidgetSnapshot): ColorProvider {
    val exam = snapshot.upcomingExams.firstOrNull() ?: return WidgetPalette.TextSecondary
    return examColor(exam.daysRemaining)
}

@Composable
private fun DayBar(
    summary: WidgetActivitySummary,
    maxMinutes: Long,
    modifier: GlanceModifier = GlanceModifier
) {
    val maxHeight = 44
    val minHeight = 6
    val ratio = if (maxMinutes == 0L) {
        0f
    } else {
        (summary.minutes.toFloat() / maxMinutes.toFloat()).coerceIn(0f, 1f)
    }
    val barHeight = if (summary.minutes == 0L) minHeight else {
        (minHeight + ((maxHeight - minHeight) * ratio)).roundToInt()
    }
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.Horizontal.CenterHorizontally,
        verticalAlignment = Alignment.Vertical.Bottom
    ) {
        Spacer(modifier = GlanceModifier.height((maxHeight - barHeight).dp))
        Box(
            modifier = GlanceModifier
                .width(14.dp)
                .height(barHeight.dp)
                .background(if (summary.isToday) WidgetPalette.Secondary else WidgetPalette.Primary)
        ) {}
        Spacer(modifier = GlanceModifier.height(6.dp))
        Text(text = summary.dayLabel, style = CaptionTextStyle)
    }
}

internal fun examDaysText(daysRemaining: Long): String {
    return when {
        daysRemaining <= 0L -> "今日"
        else -> "あと${daysRemaining}日"
    }
}

private fun examColor(daysRemaining: Long) = when {
    daysRemaining <= 3L -> WidgetPalette.Danger
    daysRemaining <= 7L -> WidgetPalette.Warning
    else -> WidgetPalette.Primary
}

private fun openAppAction(context: Context): Action {
    val intent = Intent(context, MainActivity::class.java).apply {
        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    return actionStartActivity(intent)
}
