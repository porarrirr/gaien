package com.studyapp.presentation.home

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
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.EventNote
import androidx.compose.material.icons.filled.Flag
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
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
import com.studyapp.domain.usecase.TodaySession
import com.studyapp.presentation.components.CircularProgressRing
import com.studyapp.presentation.components.SectionHeader
import com.studyapp.presentation.components.SlideInCard
import java.time.LocalDate
import com.studyapp.R
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
    onNavigateToPlan: () -> Unit = {}
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
                            sessions = uiState.todaySessions
                        )
                    }
                }

                // Weekly goal section
                item {
                    SlideInCard(visible = true, delayMillis = 100) {
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

                // Upcoming exams section
                if (uiState.upcomingExams.isNotEmpty()) {
                    item {
                        SlideInCard(visible = true, delayMillis = 200) {
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

                // Quick actions grid
                item {
                    SlideInCard(visible = true, delayMillis = 300) {
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
                                onViewPlan = onNavigateToPlan
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
private fun TodayStudySection(
    totalMinutes: Long,
    sessions: List<TodaySession>
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
                val dailyTargetMinutes = 120f
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
                val daysRemaining = exam.getDaysRemaining(LocalDate.now())
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
    onViewPlan: () -> Unit = {}
) {
    val actions = listOf(
        Triple(Icons.Default.Timer, R.string.home_quick_timer, onStartTimer),
        Triple(Icons.Default.Add, R.string.home_quick_material, onAddMaterial),
        Triple(Icons.Default.Flag, R.string.home_quick_goals, onViewGoals),
        Triple(Icons.Default.Event, R.string.home_quick_exams, onViewExams),
        Triple(Icons.Default.EventNote, R.string.home_quick_plan, onViewPlan)
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
