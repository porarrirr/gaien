package com.studyapp.presentation.goals

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.GoalType
import com.studyapp.presentation.components.AnimatedProgressBar
import com.studyapp.presentation.components.CircularProgressRing
import com.studyapp.presentation.components.SectionHeader

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
                goal = uiState.dailyGoal,
                currentMinutes = uiState.todayMinutes,
                onUpdate = { minutes -> viewModel.updateDailyGoal(minutes) }
            )
            
            WeeklyGoalSection(
                goal = uiState.weeklyGoal,
                currentMinutes = uiState.weekMinutes,
                onUpdate = { minutes -> viewModel.updateWeeklyGoal(minutes) }
            )
        }
    }
}

@Composable
private fun DailyGoalSection(
    goal: Goal?,
    currentMinutes: Long,
    onUpdate: (Int) -> Unit
) {
    var showEditDialog by remember { mutableStateOf(false) }
    val targetMinutes = goal?.targetMinutes ?: 0
    val progress = if (targetMinutes > 0) {
        (currentMinutes.toFloat() / targetMinutes.toFloat()).coerceIn(0f, 1f)
    } else 0f
    
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SectionHeader(title = "1日の目標")
        
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
                            progressColor = MaterialTheme.colorScheme.primary
                        )
                        
                        Column {
                            Text(
                                text = currentMinutes.toString(),
                                fontSize = 36.sp,
                                fontWeight = FontWeight.Bold,
                                color = if (progress >= 1f) MaterialTheme.colorScheme.primary
                                       else MaterialTheme.colorScheme.onSurface
                            )
                            Text(
                                text = "分 / ${targetMinutes}分",
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
                    progressColor = MaterialTheme.colorScheme.primary
                )
                
                if (progress >= 1f) {
                    Spacer(modifier = Modifier.height(12.dp))
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
                                    Icon(
                                        Icons.Default.Check,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onPrimary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "🎉 目標達成！",
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
    
    if (showEditDialog) {
        GoalEditDialog(
            title = "1日の目標を設定",
            currentMinutes = goal?.targetMinutes ?: 60,
            onDismiss = { showEditDialog = false },
            onConfirm = { minutes ->
                onUpdate(minutes)
                showEditDialog = false
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
                
                if (progress >= 1f) {
                    Spacer(modifier = Modifier.height(12.dp))
                    Surface(
                        color = MaterialTheme.colorScheme.tertiaryContainer,
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
                                color = MaterialTheme.colorScheme.tertiary,
                                modifier = Modifier.size(32.dp)
                            ) {
                                Box(contentAlignment = Alignment.Center) {
                                    Icon(
                                        Icons.Default.Check,
                                        contentDescription = null,
                                        tint = MaterialTheme.colorScheme.onTertiary,
                                        modifier = Modifier.size(20.dp)
                                    )
                                }
                            }
                            Spacer(modifier = Modifier.width(8.dp))
                            Text(
                                text = "🎉 目標達成！",
                                fontWeight = FontWeight.Bold,
                                color = MaterialTheme.colorScheme.onTertiaryContainer,
                                style = MaterialTheme.typography.titleMedium
                            )
                        }
                    }
                }
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