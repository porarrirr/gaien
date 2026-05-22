package com.studyapp.presentation.home

import androidx.compose.animation.animateContentSize
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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.EventNote
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Category
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
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
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
import com.studyapp.presentation.components.SectionHeader
import com.studyapp.presentation.components.SlideInCard
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.util.Date
import java.util.Locale
import kotlin.math.absoluteValue

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HomeScreen(
    viewModel: HomeViewModel = hiltViewModel(),
    onNavigateToTimer: () -> Unit = {},
    onNavigateToMaterials: () -> Unit = {},
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
                    .padding(horizontal = 16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                // Surface-styled header row
                item {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(MaterialTheme.colorScheme.surface)
                            .padding(vertical = 12.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = stringResource(R.string.home_screen_title),
                            style = MaterialTheme.typography.headlineMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Row {
                            IconButton(onClick = onNavigateToHistory) {
                                Icon(
                                    Icons.Default.History,
                                    contentDescription = stringResource(R.string.home_nav_history),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            IconButton(onClick = onNavigateToSettings) {
                                Icon(
                                    Icons.Default.Settings,
                                    contentDescription = stringResource(R.string.home_nav_settings),
                                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }

                // Gradient hero section with CircularProgressRing
                item {
                    SlideInCard(visible = true, delayMillis = 0) {
                        TodayStudySection(
                            totalMinutes = uiState.todayStudyMinutes,
                            sessions = uiState.todaySessions,
                            goal = uiState.todayGoal
                        )
                    }
                }

                item {
                    SlideInCard(visible = true, delayMillis = 50) {
                        Column {
                            SectionHeader(
                                title = "今日の復習",
                                icon = Icons.AutoMirrored.Filled.EventNote
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            TodayReviewSection(problems = uiState.todayReviewProblems)
                        }
                    }
                }

                // Today's sessions section
                if (uiState.todaySessions.isNotEmpty()) {
                    item {
                        SlideInCard(visible = true, delayMillis = 100) {
                            Column {
                                SectionHeader(
                                    title = "今日のセッション",
                                    icon = Icons.Default.Timer
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                TodaySessionsSection(sessions = uiState.todaySessions)
                            }
                        }
                    }
                }

                // Weekly goal section
                item {
                    SlideInCard(visible = true, delayMillis = 200) {
                        Column {
                            SectionHeader(
                                title = stringResource(R.string.home_weekly_goal_title),
                                icon = Icons.Default.Flag
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            WeeklyGoalSection(
                                goal = uiState.weeklyGoal,
                                currentMinutes = uiState.weeklyStudyMinutes
                            )
                        }
                    }
                }

                // Timetable lesson sections (current + upcoming)
                item {
                    SlideInCard(visible = true, delayMillis = 250) {
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            TimetableLessonHomeCard(
                                eyebrow = "現在の授業",
                                lesson = uiState.timetableLesson,
                                emptyMessage = "現在の授業はありません",
                                accentColor = MaterialTheme.colorScheme.primary,
                                onClick = onNavigateToTimetable
                            )
                            TimetableLessonHomeCard(
                                eyebrow = "次の授業",
                                lesson = uiState.upcomingTimetableLesson,
                                emptyMessage = "登録された次の授業はありません",
                                accentColor = MaterialTheme.colorScheme.tertiary,
                                onClick = onNavigateToTimetable
                            )
                        }
                    }
                }

                // Upcoming exams section
                if (uiState.upcomingExams.isNotEmpty()) {
                    item {
                        SlideInCard(visible = true, delayMillis = 300) {
                            Column {
                                SectionHeader(
                                    title = stringResource(R.string.home_upcoming_exams_title),
                                    icon = Icons.Default.Event
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                ExamsSection(exams = uiState.upcomingExams)
                            }
                        }
                    }
                }

                // Recent materials section
                if (uiState.recentMaterials.isNotEmpty()) {
                    item {
                        SlideInCard(visible = true, delayMillis = 350) {
                            Column {
                                SectionHeader(
                                    title = "最近使った教材",
                                    icon = Icons.Default.Book
                                )
                                Spacer(modifier = Modifier.height(8.dp))
                                RecentMaterialsHomeSection(materials = uiState.recentMaterials)
                            }
                        }
                    }
                }

                // Quick actions grid
                item {
                    SlideInCard(visible = true, delayMillis = 400) {
                        Column {
                            SectionHeader(
                                title = stringResource(R.string.home_quick_actions_title),
                                icon = Icons.Default.Timer
                            )
                            Spacer(modifier = Modifier.height(8.dp))
                            QuickActionsSection(
                                onStartTimer = onNavigateToTimer,
                                onAddMaterial = onNavigateToMaterials,
                                onViewExams = onNavigateToExams,
                                onViewGoals = onNavigateToGoals,
                                onViewPlan = onNavigateToPlan,
                                onViewTimetable = onNavigateToTimetable,
                                onViewSubjects = onNavigateToSubjects,
                                onViewHistory = onNavigateToHistory
                            )
                        }
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
    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .animateContentSize(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            if (problems.isEmpty()) {
                Text(
                    text = "今日の復習はありません",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                problems.take(8).forEachIndexed { index, problem ->
                    TodayReviewProblemRow(problem = problem)
                    if (index != problems.take(8).lastIndex) {
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
private fun TodayReviewProblemRow(problem: TodayReviewProblem) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(MaterialTheme.colorScheme.tertiaryContainer),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = problem.problemLabel,
                style = MaterialTheme.typography.labelLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onTertiaryContainer,
                maxLines = 1
            )
        }
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(3.dp)
        ) {
            Text(
                text = problem.materialName,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold
            )
            Text(
                text = buildReviewProblemSubtitle(problem),
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Text(
            text = reviewDueText(problem.nextReviewDate),
            style = MaterialTheme.typography.labelMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.primary
        )
    }
}

private fun buildReviewProblemSubtitle(problem: TodayReviewProblem): String {
    val subject = problem.subjectName.ifBlank { "科目未設定" }
    return "$subject・連続正解 ${problem.consecutiveCorrectCount}・不正解 ${problem.wrongCount}"
}

private fun reviewDueText(nextReviewDate: Long): String {
    val today = LocalDate.now()
    val dueDate = java.time.Instant.ofEpochMilli(nextReviewDate)
        .atZone(java.time.ZoneId.systemDefault())
        .toLocalDate()
    return when {
        dueDate.isBefore(today) -> "期限超過"
        dueDate == today -> "今日"
        else -> SimpleDateFormat("M/d", Locale.JAPANESE).format(Date(nextReviewDate))
    }
}

@Composable
private fun TodayStudySection(
    totalMinutes: Long,
    sessions: List<TodaySession>,
    goal: Goal?
) {
    val heroGradient = Brush.verticalGradient(
        colors = listOf(
            MaterialTheme.colorScheme.primaryContainer,
            MaterialTheme.colorScheme.surface
        )
    )

    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .background(heroGradient)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(20.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    text = stringResource(R.string.home_today_study),
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(modifier = Modifier.height(16.dp))

                // Progress ring showing today's study as fraction of a daily goal (e.g. 120 min)
                val dailyTargetMinutes = (goal?.targetMinutes ?: 120).toFloat()
                val progress = (totalMinutes.toFloat() / dailyTargetMinutes).coerceIn(0f, 1f)

                CircularProgressRing(
                    progress = progress,
                    size = 140.dp,
                    strokeWidth = 12.dp,
                    showPercentage = false,
                    centerContent = {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "$totalMinutes",
                                fontSize = 36.sp,
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.primary
                            )
                            Text(
                                text = stringResource(R.string.home_minutes),
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            goal?.let {
                                Text(
                                    text = "目標 ${it.targetFormatted}",
                                    style = MaterialTheme.typography.labelMedium,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            Text(
                                text = "${(progress * 100).toInt()}%",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.primary.copy(alpha = 0.7f)
                            )
                        }
                    }
                )

                if (sessions.isNotEmpty()) {
                    Spacer(modifier = Modifier.height(16.dp))
                    Column(
                        modifier = Modifier.fillMaxWidth(),
                        verticalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        sessions.take(3).forEach { session ->
                            Row(
                                verticalAlignment = Alignment.CenterVertically
                            ) {
                                // Subject color indicator dot
                                Box(
                                    modifier = Modifier
                                        .size(10.dp)
                                        .clip(CircleShape)
                                        .background(subjectColor(session.subjectName))
                                )
                                Spacer(modifier = Modifier.width(8.dp))
                                Text(
                                    text = stringResource(
                                        R.string.home_session_minutes,
                                        session.subjectName,
                                        session.duration / 60000
                                    ),
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                }
            }
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
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            sessions.forEach { session ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(subjectColor(session.subjectName))
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Column {
                            Text(
                                text = session.subjectName,
                                style = MaterialTheme.typography.bodyMedium,
                                fontWeight = FontWeight.Medium
                            )
                            if (session.materialName.isNotBlank()) {
                                Text(
                                    text = session.materialName,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                        }
                    }
                    Text(
                        text = "${session.duration / 60000}分",
                        style = MaterialTheme.typography.bodyMedium,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun RecentMaterialsHomeSection(materials: List<Pair<Material, com.studyapp.domain.model.Subject>>) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier.padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            materials.take(5).forEach { (material, subject) ->
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(10.dp)
                            .clip(CircleShape)
                            .background(Color(subject.color))
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = material.name,
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Medium
                        )
                        Text(
                            text = subject.name,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (material.totalPages > 0) {
                        Text(
                            text = "${material.progressPercent}%",
                            style = MaterialTheme.typography.bodyMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun WeeklyGoalSection(
    goal: Goal?,
    currentMinutes: Long
) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            if (goal != null) {
                val targetMinutes = goal.targetMinutes.toLong()
                val progress = if (targetMinutes > 0) {
                    (currentMinutes.toFloat() / targetMinutes.toFloat()).coerceIn(0f, 1f)
                } else 0f

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressRing(
                        progress = progress,
                        size = 80.dp,
                        strokeWidth = 8.dp,
                        showPercentage = true
                    )

                    Spacer(modifier = Modifier.width(16.dp))

                    Column {
                        Text(
                            text = stringResource(R.string.home_achievement_percent, (progress * 100).toInt()),
                            style = MaterialTheme.typography.titleMedium
                        )
                        Text(
                            text = stringResource(R.string.home_progress_minutes, currentMinutes, targetMinutes),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            } else {
                Text(
                    text = stringResource(R.string.home_no_goal_set),
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ExamsSection(exams: List<Exam>) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            exams.take(3).forEach { exam ->
                val daysRemaining = exam.daysRemaining(LocalDate.now())
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 4.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text(text = exam.name)
                    Text(
                        text = stringResource(R.string.home_days_left, daysRemaining),
                        color = if (daysRemaining <= 7) MaterialTheme.colorScheme.error
                               else MaterialTheme.colorScheme.primary,
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
    }
}

@Composable
private fun QuickActionsSection(
    onStartTimer: () -> Unit,
    onAddMaterial: () -> Unit,
    onViewExams: () -> Unit = {},
    onViewGoals: () -> Unit = {},
    onViewPlan: () -> Unit = {},
    onViewTimetable: () -> Unit = {},
    onViewSubjects: () -> Unit = {},
    onViewHistory: () -> Unit = {}
) {
    val actions = listOf(
        Triple(Icons.Default.Timer, R.string.home_quick_timer, onStartTimer),
        Triple(Icons.Default.Add, R.string.home_quick_material, onAddMaterial),
        Triple(Icons.Default.Flag, R.string.home_quick_goals, onViewGoals),
        Triple(Icons.Default.Event, R.string.home_quick_exams, onViewExams),
        Triple(Icons.AutoMirrored.Filled.EventNote, R.string.home_quick_plan, onViewPlan),
        Triple(Icons.Default.GridView, R.string.home_quick_timetable, onViewTimetable),
        Triple(Icons.Default.Category, R.string.home_quick_subjects, onViewSubjects)
    )

    // 2-column grid layout
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        actions.chunked(2).forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                rowItems.forEach { (icon, labelRes, onClick) ->
                    QuickActionItem(
                        icon = icon,
                        label = stringResource(labelRes),
                        onClick = onClick,
                        modifier = Modifier.weight(1f)
                    )
                }
                // Fill remaining space if odd number of items in this row
                if (rowItems.size == 1) {
                    Spacer(modifier = Modifier.weight(1f))
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
    onClick: () -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionHeader(
            title = eyebrow,
            icon = Icons.Default.GridView
        )
        if (lesson == null) {
            ElevatedCard(
                modifier = Modifier.fillMaxWidth(),
                elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
            ) {
                Text(
                    text = emptyMessage,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(16.dp)
                )
            }
        } else {
            TimetableLessonCard(
                lesson = lesson,
                accentColor = accentColor,
                onClick = onClick
            )
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
    ElevatedCard(
        onClick = onClick,
        modifier = modifier.height(80.dp),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center
        ) {
            Icon(
                icon,
                contentDescription = null,
                modifier = Modifier.size(24.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                textAlign = TextAlign.Center,
                maxLines = 1
            )
        }
    }
}
