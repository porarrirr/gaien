package com.studyapp.presentation.goals

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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Goal
import com.studyapp.presentation.components.AnimatedProgressBar
import com.studyapp.presentation.components.CircularProgressRing
import com.studyapp.presentation.components.SectionHeader
import java.time.DayOfWeek

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoalsScreen(
    viewModel: GoalsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "目標設定",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            DailyGoalSection(
                dailyGoals = uiState.dailyGoals,
                todayDayOfWeek = uiState.todayDayOfWeek,
                currentMinutes = uiState.todayMinutes,
                onUpdate = viewModel::updateDailyGoal
            )

            WeeklyGoalSection(
                goal = uiState.weeklyGoal,
                currentMinutes = uiState.weekMinutes,
                onUpdate = viewModel::updateWeeklyGoal
            )
        }
    }
}

@Composable
private fun DailyGoalSection(
    dailyGoals: Map<DayOfWeek, Goal>,
    todayDayOfWeek: DayOfWeek,
    currentMinutes: Long,
    onUpdate: (DayOfWeek, Int) -> Unit
) {
    var editingDay by remember { mutableStateOf<DayOfWeek?>(null) }
    val todayGoal = dailyGoals[todayDayOfWeek]
    val todayTargetMinutes = todayGoal?.targetMinutes ?: 0
    val progress = if (todayTargetMinutes > 0) {
        (currentMinutes.toFloat() / todayTargetMinutes.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionHeader(title = "曜日別の1日目標")

        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 4.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(16.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    CircularProgressRing(
                        progress = progress,
                        size = 64.dp,
                        strokeWidth = 6.dp,
                        progressColor = MaterialTheme.colorScheme.primary
                    )

                    Column {
                        Text(
                            text = todayDayOfWeek.toJapaneseTitle(),
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            text = "${currentMinutes}分 / ${todayTargetMinutes}分",
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                AnimatedProgressBar(
                    progress = progress,
                    modifier = Modifier.fillMaxWidth(),
                    height = 12.dp,
                    progressColor = MaterialTheme.colorScheme.primary
                )

                DayOfWeek.values().forEach { day ->
                    val goal = dailyGoals[day]
                    val isToday = day == todayDayOfWeek
                    Surface(
                        color = if (isToday) MaterialTheme.colorScheme.primaryContainer else MaterialTheme.colorScheme.surface,
                        shape = MaterialTheme.shapes.medium,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 12.dp, vertical = 10.dp),
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column {
                                Text(
                                    text = day.toJapaneseTitle(),
                                    fontWeight = if (isToday) FontWeight.Bold else FontWeight.Medium
                                )
                                Text(
                                    text = goal?.targetFormatted ?: "未設定",
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            TextButton(onClick = { editingDay = day }) {
                                Text(if (goal == null) "設定" else "編集")
                            }
                        }
                    }
                }

                if (progress >= 1f && todayTargetMinutes > 0) {
                    Surface(
                        color = MaterialTheme.colorScheme.primaryContainer,
                        shape = MaterialTheme.shapes.medium,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Row(
                            modifier = Modifier.padding(12.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.Center
                        ) {
                            Surface(
                                shape = CircleShape,
                                color = MaterialTheme.colorScheme.primary,
                                modifier = Modifier.size(32.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    androidx.compose.material3.Icon(
                                        Icons.Default.Check,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onPrimary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.size(8.dp))
                            Text(
                                text = "${todayDayOfWeek.toJapaneseShortLabel()}の目標を達成しました",
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                style = MaterialTheme.typography.titleMedium
                            )
                        }
                    }
                }
            }
        }
    }

    editingDay?.let { day ->
        GoalEditDialog(
            title = "${day.toJapaneseTitle()}の目標を設定",
            currentMinutes = dailyGoals[day]?.targetMinutes ?: 60,
            onDismiss = { editingDay = null },
            onConfirm = { minutes ->
                onUpdate(day, minutes)
                editingDay = null
            }
        )
    }
}

@Composable
private fun WeeklyGoalSection(
    goal: Goal?,
    currentMinutes: Long,
    onUpdate: (Int) -> Unit
) {
    var showEditDialog by remember { mutableStateOf(false) }
    val targetMinutes = goal?.targetMinutes ?: 0
    val progress = if (targetMinutes > 0) {
        (currentMinutes.toFloat() / targetMinutes.toFloat()).coerceIn(0f, 1f)
    } else 0f

    val currentHours = currentMinutes / 60
    val currentMins = currentMinutes % 60
    val targetHours = targetMinutes / 60
    val targetMins = targetMinutes % 60

    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionHeader(title = "週間目標")

        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 4.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(16.dp)
                    ) {
                        CircularProgressRing(
                            progress = progress,
                            size = 64.dp,
                            strokeWidth = 6.dp,
                            progressColor = MaterialTheme.colorScheme.tertiary
                        )

                        Column {
                            Text(
                                text = "${currentHours}時間${currentMins}分",
                                fontSize = 24.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (progress >= 1f) MaterialTheme.colorScheme.tertiary
                                else MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "目標: ${targetHours}時間${targetMins}分",
                                style = MaterialTheme.typography.bodyMedium,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }

                    TextButton(onClick = { showEditDialog = true }) {
                        Text("編集")
                    }
                }

                Spacer(modifier = Modifier.height(16.dp))

                AnimatedProgressBar(
                    progress = progress,
                    modifier = Modifier.fillMaxWidth(),
                    height = 14.dp,
                    progressColor = MaterialTheme.colorScheme.tertiary
                )

                Spacer(modifier = Modifier.height(8.dp))

                Text(
                    text = "達成率 ${(progress * 100).toInt()}%",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.tertiary
                )
            }
        }
    }

    if (showEditDialog) {
        GoalEditDialog(
            title = "週間目標を設定",
            currentMinutes = goal?.targetMinutes ?: 420,
            onDismiss = { showEditDialog = false },
            onConfirm = { minutes ->
                onUpdate(minutes)
                showEditDialog = false
            }
        )
    }
}

@Composable
private fun GoalEditDialog(
    title: String,
    currentMinutes: Int,
    onDismiss: () -> Unit,
    onConfirm: (Int) -> Unit
) {
    var hours by remember { mutableStateOf((currentMinutes / 60).toString()) }
    var minutes by remember { mutableStateOf((currentMinutes % 60).toString()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = hours,
                        onValueChange = { hours = it.filter { c -> c.isDigit() } },
                        label = { Text("時間") },
                        modifier = Modifier.weight(1f),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true
                    )

                    OutlinedTextField(
                        value = minutes,
                        onValueChange = { minutes = it.filter { c -> c.isDigit() } },
                        label = { Text("分") },
                        modifier = Modifier.weight(1f),
                        keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                        singleLine = true
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val totalMinutes = (hours.toIntOrNull() ?: 0) * 60 + (minutes.toIntOrNull() ?: 0)
                    if (totalMinutes > 0) {
                        onConfirm(totalMinutes)
                    }
                }
            ) {
                Text("保存")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}

private fun DayOfWeek.toJapaneseShortLabel(): String = when (this) {
    DayOfWeek.MONDAY -> "月"
    DayOfWeek.TUESDAY -> "火"
    DayOfWeek.WEDNESDAY -> "水"
    DayOfWeek.THURSDAY -> "木"
    DayOfWeek.FRIDAY -> "金"
    DayOfWeek.SATURDAY -> "土"
    DayOfWeek.SUNDAY -> "日"
}

private fun DayOfWeek.toJapaneseTitle(): String = "${toJapaneseShortLabel()}曜日"
