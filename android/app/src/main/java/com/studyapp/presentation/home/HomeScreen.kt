package com.studyapp.presentation.home

import android.content.Intent
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.Crossfade
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
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.EventNote
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.AssistChip
import androidx.compose.material3.AssistChipDefaults
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.ui.platform.LocalContext
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
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.compose.ui.platform.LocalLifecycleOwner
import com.ichi2.anki.api.AddContentApi
import com.studyapp.R
import com.studyapp.domain.model.AnkiIntegrationStatus
import com.studyapp.domain.model.AnkiTodayStats
import com.studyapp.domain.model.Exam
import com.studyapp.domain.model.Goal
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
    onNavigateToPlan: () -> Unit = {}
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val ankiPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) {
        viewModel.refreshAnkiStats()
    }

    DisposableEffect(lifecycleOwner, viewModel) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refreshAnkiStats()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

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
                                    title = stringResource(R.string.home_anki_today_title),
                                    icon = Icons.AutoMirrored.Filled.EventNote
                                )
                            Spacer(modifier = Modifier.height(8.dp))
                            AnkiTodaySection(
                                stats = uiState.ankiStats,
                                isRefreshing = uiState.isRefreshingAnkiStats,
                                onGrantAnkiPermission = {
                                    ankiPermissionLauncher.launch(AddContentApi.READ_WRITE_PERMISSION)
                                },
                                onOpenUsageAccess = {
                                    context.startActivity(
                                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                                        }
                                    )
                                },
                                onRefresh = viewModel::refreshAnkiStats
                            )
                        }
                    }
                }

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
private fun AnkiTodaySection(
    stats: AnkiTodayStats,
    isRefreshing: Boolean,
    onGrantAnkiPermission: () -> Unit,
    onOpenUsageAccess: () -> Unit,
    onRefresh: () -> Unit
) {
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
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    Text(
                        text = stringResource(R.string.home_anki_today_summary),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.SemiBold
                    )
                    StatusChip(status = stats.status)
                }
                OutlinedButton(onClick = onRefresh) {
                    Text(stringResource(R.string.home_anki_refresh))
                }
            }

            Crossfade(targetState = isRefreshing, label = "anki-refresh-state") { refreshing ->
                if (refreshing) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                        Text(
                            text = stringResource(R.string.home_anki_loading),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                } else {
                    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(12.dp)
                        ) {
                            AnkiMetric(
                                modifier = Modifier.weight(1f),
                                label = stringResource(R.string.home_anki_answered_cards),
                                value = stats.answeredCards?.toString()
                                    ?: stringResource(R.string.home_anki_unavailable)
                            )
                            AnkiMetric(
                                modifier = Modifier.weight(1f),
                                label = stringResource(R.string.home_anki_usage_time),
                                value = stats.usageMinutes?.let { "$it${stringResource(R.string.home_minutes)}" }
                                    ?: stringResource(R.string.home_anki_unavailable)
                            )
                        }

                        if (stats.requiresAnkiPermission || stats.requiresUsageAccess || stats.status == AnkiIntegrationStatus.ANKI_NOT_INSTALLED) {
                            HorizontalDivider()
                        }

                        if (stats.status == AnkiIntegrationStatus.ANKI_NOT_INSTALLED) {
                            Text(
                                text = stringResource(R.string.home_anki_not_installed),
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        } else {
                            if (stats.requiresAnkiPermission) {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(
                                        text = stringResource(R.string.home_anki_permission_required),
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    OutlinedButton(onClick = onGrantAnkiPermission) {
                                        Text(stringResource(R.string.home_anki_grant_permission))
                                    }
                                }
                            }

                            if (stats.requiresUsageAccess) {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    Text(
                                        text = stringResource(R.string.home_anki_usage_access_required),
                                        style = MaterialTheme.typography.bodyMedium,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                    OutlinedButton(onClick = onOpenUsageAccess) {
                                        Text(stringResource(R.string.home_anki_open_usage_access))
                                    }
                                }
                            }
                        }

                        if (stats.status == AnkiIntegrationStatus.ERROR && !stats.errorMessage.isNullOrBlank()) {
                            Text(
                                text = stats.errorMessage,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.error
                            )
                        }

                        Text(
                            text = stringResource(
                                R.string.home_anki_last_updated,
                                stats.lastUpdatedAt?.let { formatAnkiTimestamp(it) }
                                    ?: stringResource(R.string.home_anki_not_updated)
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

@Composable
private fun StatusChip(status: AnkiIntegrationStatus) {
    val (label, containerColor) = when (status) {
        AnkiIntegrationStatus.AVAILABLE -> stringResource(R.string.home_anki_status_available) to MaterialTheme.colorScheme.secondaryContainer
        AnkiIntegrationStatus.ANKI_NOT_INSTALLED -> stringResource(R.string.home_anki_status_not_installed) to MaterialTheme.colorScheme.surfaceVariant
        AnkiIntegrationStatus.NEEDS_ANKI_PERMISSION -> stringResource(R.string.home_anki_status_permission) to MaterialTheme.colorScheme.tertiaryContainer
        AnkiIntegrationStatus.NEEDS_USAGE_ACCESS -> stringResource(R.string.home_anki_status_usage_access) to MaterialTheme.colorScheme.tertiaryContainer
        AnkiIntegrationStatus.ERROR -> stringResource(R.string.home_anki_status_error) to MaterialTheme.colorScheme.errorContainer
    }

    AssistChip(
        onClick = {},
        enabled = false,
        label = { Text(label) },
        colors = AssistChipDefaults.assistChipColors(
            disabledContainerColor = containerColor,
            disabledLabelColor = MaterialTheme.colorScheme.onSurface
        )
    )
}

@Composable
private fun AnkiMetric(
    label: String,
    value: String,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = value,
            style = MaterialTheme.typography.headlineSmall,
            fontWeight = FontWeight.Bold
        )
    }
}

private fun formatAnkiTimestamp(timestamp: Long): String {
    return SimpleDateFormat("M/d HH:mm", Locale.JAPANESE).format(Date(timestamp))
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
        Triple(Icons.AutoMirrored.Filled.EventNote, R.string.home_quick_plan, onViewPlan)
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
