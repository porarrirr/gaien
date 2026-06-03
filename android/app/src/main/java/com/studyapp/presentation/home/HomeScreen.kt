package com.studyapp.presentation.home

import androidx.compose.animation.animateContentSize
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.EventNote
import androidx.compose.material.icons.filled.Category
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.R
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.TimetableLesson
import com.studyapp.domain.model.TodayReviewProblem
import com.studyapp.domain.usecase.TodaySession
import com.studyapp.presentation.components.CircularProgressRing
import com.studyapp.presentation.components.SlideInCard
import com.studyapp.presentation.theme.toSubjectColor
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.util.Date
import java.util.Locale
import kotlin.math.absoluteValue

private const val DEFAULT_DAILY_GOAL_MINUTES = 120
private const val DEFAULT_WEEKLY_GOAL_MINUTES = 600

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToExams: () -> Unit = {},
    onNavigateToGoals: () -> Unit = {},
    onNavigateToHistory: () -> Unit = {},
    onNavigateToSettings: () -> Unit = {},
    onNavigateToPlan: () -> Unit = {},
    onNavigateToTimetable: () -> Unit = {},
    onNavigateToSubjects: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    when {
        uiState.isLoading -> {
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                CircularProgressIndicator()
                Spacer(modifier = Modifier.height(16.dp))
                Text(
                    text = stringResource(R.string.common_loading),
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
        uiState.error != null -> {
            Column(
                modifier = Modifier.fillMaxSize(),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    text = uiState.error ?: stringResource(R.string.common_error),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error
                )
                Spacer(modifier = Modifier.height(16.dp))
                Button(onClick = { viewModel.retry() }) {
                    Text(stringResource(R.string.common_ok))
                }
            }
        }
        else -> {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
                    .padding(horizontal = 10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                item {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(52.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = "ホーム",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                item {
                    SlideInCard(visible = true, delayMillis = 0) {
                        TodayStudySection(
                            totalMinutes = uiState.todayStudyMinutes,
                            goal = uiState.todayGoal
                        )
                    }
                }

                item {
                    SlideInCard(visible = true, delayMillis = 50) {
                        TodayReviewSection(problems = uiState.todayReviewProblems)
                    }
                }

                // Weekly goal section
                item {
                    SlideInCard(visible = true, delayMillis = 200) {
                        WeeklyGoalSection(
                            goal = uiState.weeklyGoal,
                            currentMinutes = uiState.weeklyStudyMinutes,
                            onViewGoals = onNavigateToGoals
                        )
                    }
                }

                // Timetable lesson sections (current + upcoming)
                item {
                    SlideInCard(visible = true, delayMillis = 250) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            TimetableLessonHomeCard(
                                eyebrow = "現在の授業",
                                lesson = uiState.timetableLesson,
                                emptyMessage = "現在の授業はありません",
                                accentColor = MaterialTheme.colorScheme.primary,
                                onClick = onNavigateToTimetable,
                                modifier = Modifier.weight(1f)
                            )
                            TimetableLessonHomeCard(
                                eyebrow = "次の授業",
                                lesson = uiState.upcomingTimetableLesson,
                                emptyMessage = "登録された次の授業はありません",
                                accentColor = MaterialTheme.colorScheme.tertiary,
                                onClick = onNavigateToTimetable,
                                modifier = Modifier.weight(1f)
                            )
                        }
                    }
                }

                // Today's sessions section
                item {
                    SlideInCard(visible = true, delayMillis = 275) {
                        TodaySessionsSection(sessions = uiState.todaySessions)
                    }
                }

                // Upcoming exams section
                item {
                    SlideInCard(visible = true, delayMillis = 300) {
                        ExamsSection(exams = uiState.upcomingExams)
                    }
                }

                // Recent materials section
                item {
                    SlideInCard(visible = true, delayMillis = 350) {
                        RecentMaterialsHomeSection(materials = uiState.recentMaterials)
                    }
                }

                // Quick actions grid
                item {
                    SlideInCard(visible = true, delayMillis = 400) {
                        QuickActionsSection(
                            onViewExams = onNavigateToExams,
                            onViewGoals = onNavigateToGoals,
                            onViewPlan = onNavigateToPlan,
                            onViewTimetable = onNavigateToTimetable,
                            onViewSubjects = onNavigateToSubjects,
                            onViewHistory = onNavigateToHistory,
                            onViewSettings = onNavigateToSettings
                        )
                    }
                }

                // Bottom spacing
                item {
                    Spacer(modifier = Modifier.height(16.dp))
                }
            }
        }
    }
}

@Composable
private fun TodayReviewSection(problems: List<TodayReviewProblem>) {
    val groups = rememberReviewGroups(problems)

    HomeCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize()
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            HomeCardHeader(
                title = "今日の復習",
                icon = Icons.AutoMirrored.Filled.EventNote,
                countText = "${problems.size}件",
                showChevron = true
            )
            if (problems.isEmpty()) {
                EmptyCompactText("今日の復習はありません")
            } else {
                groups.take(3).forEachIndexed { index, group ->
                    TodayReviewGroupRow(
                        group = group,
                        dueText = reviewDueRelativeText(group.earliestReviewDate),
                        color = listOf(
                            MaterialTheme.colorScheme.primary,
                            Color(0xFFF59E0B),
                            Color(0xFF1D7FEA)
                        )[index % 3]
                    )
                    if (index != groups.take(3).lastIndex) {
                        Surface(
                            modifier = Modifier
                                .fillMaxWidth()
                                .height(1.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                        ) {}
                    }
                }
            }
        }
    }
}

@Composable
private fun TodayReviewGroupRow(
    group: TodayReviewMaterialGroup,
    dueText: String,
    color: Color
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.Top
    ) {
        Box(
            modifier = Modifier
                .size(42.dp)
                .clip(CircleShape)
                .background(color),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = "${group.problems.size}",
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 1
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(5.dp)
        ) {
            Text(
                text = group.materialName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = group.subjectText,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
                Text(
                    text = dueText,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = when (dueText) {
                        "今日まで" -> MaterialTheme.colorScheme.error
                        "明日まで" -> Color(0xFFF59E0B)
                        else -> MaterialTheme.colorScheme.onSurface
                    },
                    maxLines = 1
                )
            }
            Text(
                text = group.compactProblemLabels(limit = 4),
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2
            )
        }

        Column(
            modifier = Modifier.width(58.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "復習",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                text = "${group.problems.size}問",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = color
            )
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            modifier = Modifier
                .padding(top = 14.dp)
                .size(18.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun TodayStudySection(
    totalMinutes: Long,
    goal: Goal?
) {
    val targetMinutes = goal?.targetMinutes ?: DEFAULT_DAILY_GOAL_MINUTES
    HomeCard(modifier = Modifier.fillMaxWidth()) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Icon(
                        Icons.Default.Timer,
                        contentDescription = null,
                        modifier = Modifier.size(22.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = stringResource(R.string.home_today_study),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
                Row(
                    verticalAlignment = Alignment.Bottom,
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    Text(
                        text = "$totalMinutes",
                        fontSize = 44.sp,
                        fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = stringResource(R.string.home_minutes),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        modifier = Modifier.padding(bottom = 8.dp)
                    )
                }
                Text(
                    text = "目標 ${Goal.formatMinutes(targetMinutes)}",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            val progress = (totalMinutes.toFloat() / targetMinutes.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)
            CircularProgressRing(
                progress = progress,
                size = 90.dp,
                strokeWidth = 8.dp,
                trackColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.65f),
                progressColor = MaterialTheme.colorScheme.primary,
                showPercentage = false,
                centerContent = {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        Text(
                            text = "${(progress * 100).toInt()}%",
                            style = MaterialTheme.typography.titleLarge,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Text(
                            text = "達成率",
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            )
        }
    }
}

/** Derives a deterministic color from a subject name string. */
@Composable
private fun subjectColor(name: String): Color {
    val palette = listOf(
        Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFFF9800),
        Color(0xFFE91E63), Color(0xFF9C27B0), Color(0xFF00BCD4),
        Color(0xFFFF5722), Color(0xFF3F51B5)
    )
    return palette[name.hashCode().absoluteValue % palette.size]
}

@Composable
private fun TodaySessionsSection(sessions: List<TodaySession>) {
    HomeCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            HomeCardHeader(
                title = "今日のセッション",
                icon = Icons.Default.Timer,
                countText = "${sessions.size}件",
                showChevron = true
            )
            if (sessions.isEmpty()) {
                EmptyCompactText("セッションはまだありません")
            } else {
                sessions.take(3).forEachIndexed { index, session ->
                    SessionRow(session = session, color = sessionColor(index))
                    if (index != sessions.take(3).lastIndex) {
                        DividerLine()
                    }
                }
            }
            FooterLink("すべてのセッションを表示")
        }
    }
}

@Composable
private fun RecentMaterialsHomeSection(materials: List<Pair<Material, com.studyapp.domain.model.Subject>>) {
    HomeCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            HomeCardHeader(
                title = "最近使った教材",
                icon = Icons.Default.Book,
                countText = "${materials.size}件",
                showChevron = true
            )
            if (materials.isEmpty()) {
                EmptyCompactText("最近使った教材はありません")
            } else {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    items(materials.take(6)) { (material, subject) ->
                        MaterialMiniCard(material = material, subject = subject)
                    }
                }
            }
        }
    }
}

@Composable
private fun WeeklyGoalSection(
    goal: Goal?,
    currentMinutes: Long,
    onViewGoals: () -> Unit
) {
    val targetMinutes = goal?.targetMinutes?.toLong() ?: DEFAULT_WEEKLY_GOAL_MINUTES.toLong()
    val progress = (currentMinutes.toFloat() / targetMinutes.toFloat().coerceAtLeast(1f)).coerceIn(0f, 1f)

    HomeCard(
        modifier = Modifier.fillMaxWidth(),
        onClick = onViewGoals
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            HomeCardHeader(
                title = stringResource(R.string.home_weekly_goal_title),
                icon = Icons.Default.Flag,
                countText = "${Goal.formatMinutes(currentMinutes.toInt())} / ${Goal.formatMinutes(targetMinutes.toInt())}",
                showChevron = true
            )

            Text(
                text = "学習時間の目標 ${Goal.formatMinutes(targetMinutes.toInt())}",
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(7.dp)
                        .clip(RoundedCornerShape(4.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                ) {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth(progress)
                            .height(7.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(MaterialTheme.colorScheme.primary)
                    )
                }
                Text(
                    text = "${(progress * 100).toInt()}%",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.width(46.dp),
                    textAlign = TextAlign.End
                )
            }
        }
    }
}

@Composable
private fun HomeCardHeader(
    title: String,
    icon: ImageVector,
    countText: String? = null,
    showChevron: Boolean = false
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(9.dp)
    ) {
        Icon(
            icon,
            contentDescription = null,
            modifier = Modifier.size(22.dp),
            tint = MaterialTheme.colorScheme.primary
        )
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f)
        )
        countText?.let {
            Text(
                text = it,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        if (showChevron) {
            Icon(
                Icons.Default.ChevronRight,
                contentDescription = null,
                modifier = Modifier.size(18.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
    }
}

@Composable
private fun ExamsSection(exams: List<Exam>) {
    HomeCard(modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            HomeCardHeader(
                title = "今後のテスト",
                icon = Icons.Default.Event,
                countText = "${exams.size}件",
                showChevron = true
            )
            if (exams.isEmpty()) {
                EmptyCompactText("予定されたテストはありません")
            } else {
                exams.take(4).forEachIndexed { index, exam ->
                    ExamRow(exam = exam)
                    if (index != exams.take(4).lastIndex) {
                        DividerLine()
                    }
                }
            }
            FooterLink("すべてのテストを表示")
        }
    }
}

@Composable
private fun QuickActionsSection(
    onViewExams: () -> Unit = {},
    onViewGoals: () -> Unit = {},
    onViewPlan: () -> Unit = {},
    onViewTimetable: () -> Unit = {},
    onViewSubjects: () -> Unit = {},
    onViewHistory: () -> Unit = {},
    onViewSettings: () -> Unit = {}
) {
    val actions = listOf(
        Triple(Icons.Default.Event, "試験", onViewExams),
        Triple(Icons.Default.Category, "科目", onViewSubjects),
        Triple(Icons.Default.History, "履歴", onViewHistory),
        Triple(Icons.Default.Flag, "目標", onViewGoals),
        Triple(Icons.AutoMirrored.Filled.EventNote, "計画", onViewPlan),
        Triple(Icons.Default.GridView, "時間割", onViewTimetable),
        Triple(Icons.Default.Settings, "設定", onViewSettings)
    )

    HomeCard(
        modifier = Modifier.fillMaxWidth()
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            actions.chunked(4).forEach { rowItems ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    rowItems.forEach { (icon, label, onClick) ->
                        QuickActionItem(
                            icon = icon,
                            label = label,
                            onClick = onClick,
                            modifier = Modifier.weight(1f)
                        )
                    }
                    repeat(4 - rowItems.size) {
                        Spacer(modifier = Modifier.weight(1f))
                    }
                }
            }
        }
    }
}

@Composable
private fun TimetableLessonHomeCard(
    eyebrow: String,
    lesson: TimetableLesson?,
    emptyMessage: String,
    accentColor: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    HomeCard(
        onClick = onClick,
        modifier = modifier.height(128.dp),
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            Text(
                text = eyebrow,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = accentColor
            )
            if (lesson == null) {
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = emptyMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 2
                )
                Text(
                    text = "時間割で登録してください",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.82f),
                    maxLines = 1
                )
                Spacer(modifier = Modifier.weight(1f))
            } else {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(accentColor)
                    )
                    Text(
                        text = lesson.entry.subjectName.ifBlank { "授業名未設定" },
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1
                    )
                }
                Text(
                    text = lesson.entry.courseName?.takeIf { it.isNotBlank() } ?: "講座名なし",
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1
                )
                Text(
                    text = "${lesson.dayOfWeek.japaneseTitle} ${lesson.period.name}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
                Text(
                    text = lesson.period.timeRangeText,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun TimetableLessonCard(
    lesson: TimetableLesson,
    accentColor: Color = if (lesson.isCurrent) {
        MaterialTheme.colorScheme.primary
    } else {
        MaterialTheme.colorScheme.secondary
    },
    onClick: () -> Unit
) {
    ElevatedCard(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(48.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(accentColor)
            )

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = lesson.entry.subjectName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                lesson.entry.courseName?.takeIf { it.isNotBlank() }?.let { course ->
                    Text(
                        text = course,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = lesson.period.name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = lesson.period.timeRangeText,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    lesson.entry.roomName?.takeIf { it.isNotBlank() }?.let { room ->
                        Text(
                            text = room,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            Surface(
                shape = RoundedCornerShape(8.dp),
                color = if (lesson.isCurrent) MaterialTheme.colorScheme.primaryContainer
                else MaterialTheme.colorScheme.secondaryContainer
            ) {
                Text(
                    text = lesson.statusTitle,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = if (lesson.isCurrent) MaterialTheme.colorScheme.onPrimaryContainer
                    else MaterialTheme.colorScheme.onSecondaryContainer,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun QuickActionItem(
    icon: ImageVector,
    label: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    HomeCard(
        onClick = onClick,
        modifier = modifier.height(62.dp),
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 4.dp, vertical = 8.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                icon,
                contentDescription = null,
                modifier = Modifier.size(22.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                textAlign = TextAlign.Center,
                maxLines = 1
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HomeCard(
    modifier: Modifier = Modifier,
    containerColor: Color = MaterialTheme.colorScheme.surface,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit
) {
    val shape = RoundedCornerShape(8.dp)
    val border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.55f))
    if (onClick != null) {
        Surface(
            onClick = onClick,
            modifier = modifier,
            shape = shape,
            color = containerColor,
            shadowElevation = 1.dp,
            border = border,
            content = content
        )
    } else {
        Surface(
            modifier = modifier,
            shape = shape,
            color = containerColor,
            shadowElevation = 1.dp,
            border = border,
            content = content
        )
    }
}

@Composable
private fun EmptyCompactText(title: String) {
    Text(
        text = title,
        style = MaterialTheme.typography.labelMedium,
        fontWeight = FontWeight.Medium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier
            .fillMaxWidth()
            .height(92.dp),
        textAlign = TextAlign.Center
    )
}

@Composable
private fun FooterLink(title: String) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(38.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.primary
        )
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun DividerLine() {
    Surface(
        modifier = Modifier
            .fillMaxWidth()
            .height(1.dp),
        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
    ) {}
}

@Composable
private fun SessionRow(session: TodaySession, color: Color) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .size(10.dp)
                .clip(CircleShape)
                .background(color)
        )
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = session.subjectName.ifBlank { "科目未設定" },
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
            Text(
                text = session.materialName.ifBlank { "教材未設定" },
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = "${session.duration / 60000}分",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Bold
            )
            Text(
                text = timeRangeText(session.startTime, session.duration),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1
            )
        }
    }
}

@Composable
private fun ExamRow(exam: Exam) {
    val daysRemaining = exam.daysRemaining(LocalDate.now())
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(44.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.SpaceBetween
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = exam.name,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
            Text(
                text = SimpleDateFormat("M/d", Locale.JAPANESE).format(Date(exam.date)),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            text = stringResource(R.string.home_days_left, daysRemaining),
            color = if (daysRemaining <= 7) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.primary,
            fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.labelMedium
        )
    }
}

@Composable
private fun MaterialMiniCard(
    material: Material,
    subject: com.studyapp.domain.model.Subject
) {
    HomeCard(
        modifier = Modifier
            .width(138.dp)
            .height(90.dp)
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                Box(
                    modifier = Modifier
                        .size(9.dp)
                        .clip(CircleShape)
                        .background(subject.color.toSubjectColor())
                )
                Text(
                    text = subject.name,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1
                )
            }
            Text(
                text = material.name,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                maxLines = 2
            )
            if (material.totalPages > 0) {
                Text(
                    text = "${material.progressPercent}%",
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }
    }
}

private fun reviewDueRelativeText(nextReviewDate: Long): String {
    val today = LocalDate.now()
    val dueDate = java.time.Instant.ofEpochMilli(nextReviewDate)
        .atZone(java.time.ZoneId.systemDefault())
        .toLocalDate()
    val days = java.time.temporal.ChronoUnit.DAYS.between(today, dueDate)
    return when {
        days <= 0 -> "今日まで"
        days == 1L -> "明日まで"
        else -> "${days}日後"
    }
}

private fun timeRangeText(startTime: Long, duration: Long): String {
    val formatter = SimpleDateFormat("H:mm", Locale.JAPANESE)
    val start = Date(startTime)
    val end = Date(startTime + duration)
    return "${formatter.format(start)}-${formatter.format(end)}"
}

private fun sessionColor(index: Int): Color {
    return listOf(Color(0xFF1D7FEA), Color(0xFFE53935), Color(0xFFF59E0B))[index % 3]
}

private fun rememberReviewGroups(problems: List<TodayReviewProblem>): List<TodayReviewMaterialGroup> {
    return problems
        .groupBy { it.materialId }
        .map { (_, values) ->
            val sorted = values.sortedWith(
                compareBy<TodayReviewProblem> { it.nextReviewDate }
                    .thenBy { it.problemNumber }
            )
            val first = sorted.first()
            TodayReviewMaterialGroup(
                materialId = first.materialId,
                materialName = first.materialName,
                subjectName = first.subjectName,
                problems = sorted
            )
        }
        .sortedWith(
            compareBy<TodayReviewMaterialGroup> { it.earliestReviewDate }
                .thenBy { it.materialName }
                .thenBy { it.materialId }
        )
}

private data class TodayReviewMaterialGroup(
    val materialId: Long,
    val materialName: String,
    val subjectName: String,
    val problems: List<TodayReviewProblem>
) {
    val subjectText: String
        get() = subjectName.ifBlank { "科目未設定" }

    val earliestReviewDate: Long
        get() = problems.minOfOrNull { it.nextReviewDate } ?: 0L

    fun compactProblemLabels(limit: Int): String {
        val labels = problems.map { it.problemLabel }
        return if (labels.size <= limit) {
            labels.joinToString("、")
        } else {
            "${labels.take(limit).joinToString("、")} ほか${labels.size - limit}問"
        }
    }
}
