package com.studyapp.presentation.goals

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material.icons.filled.WbSunny
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.presentation.components.CircularProgressRing
import kotlin.math.roundToInt

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GoalsScreen(
    viewModel: GoalsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

    LaunchedEffect(uiState.error) {
        val message = uiState.error ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(message)
        viewModel.clearError()
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "目標",
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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .background(MaterialTheme.colorScheme.background)
                .padding(paddingValues),
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            item {
                TodayGoalCard(
                    dailyGoals = uiState.dailyGoals,
                    todayDayOfWeek = uiState.todayDayOfWeek,
                    currentMinutes = uiState.todayMinutes
                )
            }
            item {
                WeekdayGoalsList(
                    dailyGoals = uiState.dailyGoals,
                    todayDayOfWeek = uiState.todayDayOfWeek,
                    onUpdate = viewModel::updateDailyGoal
                )
            }
            item {
                WeeklyGoalCard(
                    goal = uiState.weeklyGoal,
                    currentMinutes = uiState.weekMinutes,
                    onUpdate = viewModel::updateWeeklyGoal
                )
            }
        }
    }
}

@Composable
private fun TodayGoalCard(
    dailyGoals: Map<StudyWeekday, Goal>,
    todayDayOfWeek: StudyWeekday,
    currentMinutes: Long
) {
    val success = MaterialTheme.colorScheme.primary
    val todayTargetMinutes = dailyGoals[todayDayOfWeek]?.targetMinutes ?: 0
    val progress = goalProgress(currentMinutes, todayTargetMinutes)

    GoalSurfaceCard(horizontalPadding = 22.dp, verticalPadding = 20.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(18.dp)) {
            GoalHeader(
                icon = Icons.Default.WbSunny,
                iconColor = Color(0xFFF6A000),
                title = "曜日別の1日目標"
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(22.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                GoalRing(progress = progress, size = 112.dp)

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        text = todayDayOfWeek.japaneseTitle,
                        fontSize = 30.sp,
                        fontWeight = FontWeight.Bold,
                        color = success,
                        maxLines = 1
                    )
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = currentMinutes.toString(),
                            fontSize = 34.sp,
                            fontWeight = FontWeight.Bold,
                            color = success
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "分 / ${todayTargetMinutes}分",
                            fontSize = 24.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.padding(bottom = 4.dp)
                        )
                    }
                    Text(
                        text = "今日の進捗",
                        fontSize = 18.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun WeekdayGoalsList(
    dailyGoals: Map<StudyWeekday, Goal>,
    todayDayOfWeek: StudyWeekday,
    onUpdate: (StudyWeekday, Int) -> Unit
) {
    var editingDay by remember { mutableStateOf<StudyWeekday?>(null) }

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.outlinedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column {
            orderedWeekdays.forEachIndexed { index, day ->
                val goal = dailyGoals[day]
                val isToday = day == todayDayOfWeek
                WeekdayGoalRow(
                    day = day,
                    goal = goal,
                    isToday = isToday,
                    onEdit = { editingDay = day }
                )
                if (index < orderedWeekdays.lastIndex) {
                    HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                }
            }
        }
    }

    editingDay?.let { day ->
        GoalEditDialog(
            title = "${day.japaneseTitle}の目標",
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
private fun WeekdayGoalRow(
    day: StudyWeekday,
    goal: Goal?,
    isToday: Boolean,
    onEdit: () -> Unit
) {
    val success = MaterialTheme.colorScheme.primary
    val rowBackground = if (isToday) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.42f)
    } else {
        MaterialTheme.colorScheme.surface
    }
    val dayColor = weekdayColor(day, isToday)

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(52.dp)
            .background(rowBackground)
            .padding(horizontal = 20.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = day.japaneseTitle,
            fontSize = 20.sp,
            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
            color = dayColor,
            modifier = Modifier.width(84.dp),
            maxLines = 1
        )

        Text(
            text = goal?.targetFormatted ?: "未設定",
            fontSize = 20.sp,
            fontWeight = if (isToday) FontWeight.Bold else FontWeight.Normal,
            color = when {
                isToday -> success
                goal == null -> MaterialTheme.colorScheme.onSurfaceVariant
                else -> MaterialTheme.colorScheme.onSurface
            },
            textAlign = TextAlign.Center,
            modifier = Modifier.weight(1f),
            maxLines = 1
        )

        SmallEditButton(
            text = if (goal == null) "設定" else "編集",
            selected = isToday,
            onClick = onEdit
        )
    }
}

@Composable
private fun WeeklyGoalCard(
    goal: Goal?,
    currentMinutes: Long,
    onUpdate: (Int) -> Unit
) {
    var showEditDialog by remember { mutableStateOf(false) }
    val success = MaterialTheme.colorScheme.primary
    val targetMinutes = goal?.targetMinutes ?: 0
    val progress = goalProgress(currentMinutes, targetMinutes)
    val targetText = if (targetMinutes > 0) Goal.formatMinutes(targetMinutes) else "未設定"

    GoalSurfaceCard(horizontalPadding = 22.dp, verticalPadding = 18.dp) {
        Column(verticalArrangement = Arrangement.spacedBy(16.dp)) {
            GoalHeader(
                icon = Icons.Default.CalendarMonth,
                iconColor = success,
                title = "週間目標"
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(14.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                GoalRing(progress = progress, size = 106.dp)

                Column(
                    modifier = Modifier.weight(1f),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = "目標:",
                            fontSize = 21.sp,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.width(6.dp))
                        Text(
                            text = targetText,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = success,
                            maxLines = 1
                        )
                    }

                    Row(verticalAlignment = Alignment.Bottom) {
                        Text(
                            text = Goal.formatMinutes(currentMinutes.toInt()),
                            fontSize = 26.sp,
                            fontWeight = FontWeight.Bold,
                            color = success,
                            maxLines = 1
                        )
                        Spacer(modifier = Modifier.width(4.dp))
                        Text(
                            text = "/ $targetText",
                            fontSize = 20.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1
                        )
                    }

                    LinearGoalProgress(progress = progress)

                    Text(
                        text = "今週の進捗",
                        fontSize = 17.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }

                SmallEditButton(
                    text = "変更",
                    selected = false,
                    onClick = { showEditDialog = true }
                )
            }
        }
    }

    if (showEditDialog) {
        GoalEditDialog(
            title = "週間目標",
            currentMinutes = goal?.targetMinutes ?: 0,
            onDismiss = { showEditDialog = false },
            onConfirm = { minutes ->
                onUpdate(minutes)
                showEditDialog = false
            }
        )
    }
}

@Composable
private fun GoalHeader(
    icon: ImageVector,
    iconColor: Color,
    title: String
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = iconColor,
            modifier = Modifier.size(40.dp)
        )
        Text(
            text = title,
            fontSize = 24.sp,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1
        )
    }
}

@Composable
private fun GoalRing(
    progress: Float,
    size: androidx.compose.ui.unit.Dp
) {
    CircularProgressRing(
        progress = progress,
        size = size,
        strokeWidth = 13.dp,
        trackColor = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.75f),
        progressColor = MaterialTheme.colorScheme.primary,
        showPercentage = false,
        centerContent = {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = "${(progress * 100).roundToInt()}%",
                    fontSize = 29.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "達成",
                    fontSize = 16.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    )
}

@Composable
private fun LinearGoalProgress(progress: Float) {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .height(8.dp)
            .clip(RoundedCornerShape(50))
            .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.8f))
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth(progress.coerceIn(0f, 1f))
                .fillMaxHeight()
                .clip(RoundedCornerShape(50))
                .background(MaterialTheme.colorScheme.primary)
        )
    }
}

@Composable
private fun SmallEditButton(
    text: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    if (selected) {
        Button(
            onClick = onClick,
            modifier = Modifier
                .width(56.dp)
                .height(32.dp),
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(0.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            )
        ) {
            Text(text = text, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
    } else {
        OutlinedButton(
            onClick = onClick,
            modifier = Modifier
                .width(56.dp)
                .height(32.dp),
            shape = RoundedCornerShape(8.dp),
            contentPadding = PaddingValues(0.dp),
            border = BorderStroke(1.5.dp, MaterialTheme.colorScheme.primary),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = MaterialTheme.colorScheme.primary
            )
        ) {
            Text(text = text, fontWeight = FontWeight.Bold, fontSize = 14.sp)
        }
    }
}

@Composable
private fun GoalSurfaceCard(
    horizontalPadding: androidx.compose.ui.unit.Dp,
    verticalPadding: androidx.compose.ui.unit.Dp,
    content: @Composable () -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.outlinedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = horizontalPadding, vertical = verticalPadding)
        ) {
            content()
        }
    }
}

@Composable
private fun GoalEditDialog(
    title: String,
    currentMinutes: Int,
    onDismiss: () -> Unit,
    onConfirm: (Int) -> Unit
) {
    var minutes by remember { mutableStateOf(currentMinutes.toString()) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(title) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.TrackChanges,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.primary
                    )
                    Text(
                        text = title,
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.Bold
                    )
                }
                OutlinedTextField(
                    value = minutes,
                    onValueChange = { next -> minutes = next.filter { it.isDigit() } },
                    label = { Text("目標時間（分）") },
                    modifier = Modifier.fillMaxWidth(),
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                    singleLine = true,
                    textStyle = MaterialTheme.typography.headlineSmall.copy(
                        fontWeight = FontWeight.Bold,
                        textAlign = TextAlign.Center
                    )
                )
                minutes.toIntOrNull()?.takeIf { it > 0 }?.let { value ->
                    Text(
                        text = Goal.formatMinutes(value),
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(MaterialTheme.colorScheme.primaryContainer)
                            .padding(horizontal = 12.dp, vertical = 6.dp)
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    onConfirm(minutes.toIntOrNull() ?: 0)
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

private fun goalProgress(currentMinutes: Long, targetMinutes: Int): Float {
    return if (targetMinutes > 0) {
        (currentMinutes.toFloat() / targetMinutes.toFloat()).coerceIn(0f, 1f)
    } else {
        0f
    }
}

@Composable
private fun weekdayColor(day: StudyWeekday, isToday: Boolean): Color {
    if (isToday) return MaterialTheme.colorScheme.primary
    return when (day) {
        StudyWeekday.SUNDAY -> Color(0xFFFF3B30)
        StudyWeekday.SATURDAY -> Color(0xFF1E88E5)
        else -> MaterialTheme.colorScheme.onSurface
    }
}

private val orderedWeekdays = listOf(
    StudyWeekday.SUNDAY,
    StudyWeekday.MONDAY,
    StudyWeekday.TUESDAY,
    StudyWeekday.WEDNESDAY,
    StudyWeekday.THURSDAY,
    StudyWeekday.FRIDAY,
    StudyWeekday.SATURDAY
)
