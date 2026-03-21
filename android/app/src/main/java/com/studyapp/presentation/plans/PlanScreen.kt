package com.studyapp.presentation.plans

import androidx.compose.animation.*
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.PlanItemWithSubject
import com.studyapp.domain.model.Subject
import com.studyapp.presentation.components.EmptyState
import java.text.SimpleDateFormat
import java.time.DayOfWeek
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlanScreen(
    viewModel: PlanViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showCreateDialog by remember { mutableStateOf(false) }
    var showAddItemDialog by remember { mutableStateOf(false) }
    var selectedDay by remember { mutableStateOf<DayOfWeek?>(null) }
    var showDeletePlanDialog by remember { mutableStateOf(false) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "学習計画",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    if (uiState.activePlan != null) {
                        IconButton(onClick = { showAddItemDialog = true }) {
                            Icon(
                                Icons.Default.Add,
                                contentDescription = "追加",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        IconButton(onClick = { showDeletePlanDialog = true }) {
                            Icon(
                                Icons.Default.Delete,
                                contentDescription = "削除",
                                tint = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                }
            )
        }
    ) { paddingValues ->
        if (uiState.isLoading) {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentAlignment = Alignment.Center
            ) {
                CircularProgressIndicator()
            }
        } else if (uiState.activePlan == null) {
            EmptyPlanState(
                onCreatePlan = { showCreateDialog = true }
            )
        } else {
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues)
            ) {
                PlanHeader(
                    plan = uiState.activePlan!!,
                    totalTarget = uiState.totalTargetMinutes,
                    completionRate = viewModel.getCompletionRate()
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                WeeklyScheduleView(
                    weeklySchedule = uiState.weeklySchedule,
                    onDayClick = { day ->
                        selectedDay = day
                    }
                )
            }
        }
    }
    
    if (showCreateDialog) {
        CreatePlanDialog(
            subjects = uiState.subjects,
            onDismiss = { showCreateDialog = false },
            onCreate = { name, startDate, endDate, items ->
                viewModel.createPlan(name, startDate, endDate, items)
                showCreateDialog = false
            }
        )
    }
    
    if (showAddItemDialog && uiState.activePlan != null) {
        AddPlanItemDialog(
            subjects = uiState.subjects,
            onDismiss = { showAddItemDialog = false },
            onAdd = { subjectId, dayOfWeek, minutes, timeSlot ->
                viewModel.addPlanItem(subjectId, dayOfWeek, minutes, timeSlot)
                showAddItemDialog = false
            }
        )
    }
    
    if (showDeletePlanDialog) {
        AlertDialog(
            onDismissRequest = { showDeletePlanDialog = false },
            title = { Text("計画を削除") },
            text = { Text("この学習計画を削除してもよろしいですか？\nこの操作は取り消せません。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deletePlan()
                        showDeletePlanDialog = false
                    }
                ) {
                    Text("削除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeletePlanDialog = false }) {
                    Text("キャンセル")
                }
            }
        )
    }
}

@Composable
private fun EmptyPlanState(
    onCreatePlan: () -> Unit
) {
    EmptyState(
        icon = Icons.Default.EventNote,
        title = "学習計画がありません",
        description = "1週間の学習スケジュールを作成して\n効率的に学習しましょう",
        actionLabel = "計画を作成",
        onAction = onCreatePlan
    )
}

@Composable
private fun PlanHeader(
    plan: com.studyapp.domain.model.StudyPlan,
    totalTarget: Int,
    completionRate: Float
) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.primaryContainer
        )
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(20.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = plan.name,
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer
                    )
                    
                    val dateFormat = SimpleDateFormat("M/d", Locale.JAPANESE)
                    Text(
                        text = "${dateFormat.format(Date(plan.startDate))} - ${dateFormat.format(Date(plan.endDate))}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.7f)
                    )
                }
                
                Box(
                    modifier = Modifier
                        .size(64.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.primary),
                    contentAlignment = Alignment.Center
                ) {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally
                    ) {
                        Text(
                            text = "${(completionRate * 100).toInt()}%",
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                        Text(
                            text = "達成",
                            style = MaterialTheme.typography.labelSmall,
                            color = MaterialTheme.colorScheme.onPrimary.copy(alpha = 0.8f)
                        )
                    }
                }
            }
            
            Spacer(modifier = Modifier.height(16.dp))
            
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                StatChip(
                    icon = Icons.Default.Timer,
                    label = "目標",
                    value = "${totalTarget / 60}時間${totalTarget % 60}分/週"
                )
            }
        }
    }
}

@Composable
private fun StatChip(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    label: String,
    value: String
) {
    Surface(
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.primary.copy(alpha = 0.1f)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.primary
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = value,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun WeeklyScheduleView(
    weeklySchedule: Map<DayOfWeek, List<PlanItemWithSubject>>,
    onDayClick: (DayOfWeek) -> Unit
) {
    val dayNames = listOf(
        DayOfWeek.MONDAY to "月",
        DayOfWeek.TUESDAY to "火",
        DayOfWeek.WEDNESDAY to "水",
        DayOfWeek.THURSDAY to "木",
        DayOfWeek.FRIDAY to "金",
        DayOfWeek.SATURDAY to "土",
        DayOfWeek.SUNDAY to "日"
    )
    
    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 16.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        items(dayNames) { (day, name) ->
            DayScheduleCard(
                dayName = name,
                dayOfWeek = day,
                items = weeklySchedule[day] ?: emptyList(),
                onClick = { onDayClick(day) }
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun DayScheduleCard(
    dayName: String,
    dayOfWeek: DayOfWeek,
    items: List<PlanItemWithSubject>,
    onClick: () -> Unit
) {
    val isToday = java.time.LocalDate.now().dayOfWeek == dayOfWeek
    
    Card(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.cardElevation(
            defaultElevation = if (isToday) 4.dp else 1.dp
        ),
        colors = CardDefaults.cardColors(
            containerColor = if (isToday) 
                MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
            else 
                MaterialTheme.colorScheme.surface
        ),
        onClick = onClick
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
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    if (isToday) {
                        Surface(
                            shape = RoundedCornerShape(4.dp),
                            color = MaterialTheme.colorScheme.primary
                        ) {
                            Text(
                                text = "今日",
                                style = MaterialTheme.typography.labelSmall,
                                color = MaterialTheme.colorScheme.onPrimary,
                                modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp)
                            )
                        }
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    
                    Text(
                        text = "${dayName}曜日",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                }
                
                val totalMinutes = items.sumOf { it.item.targetMinutes }
                Text(
                    text = "${totalMinutes / 60}時間${totalMinutes % 60}分",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.primary,
                    fontWeight = FontWeight.Bold
                )
            }
            
            if (items.isEmpty()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "予定なし",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            } else {
                Spacer(modifier = Modifier.height(12.dp))
                
                items.forEach { itemWithSubject ->
                    PlanItemRow(
                        item = itemWithSubject.item,
                        subject = itemWithSubject.subject
                    )
                    if (items.last() != itemWithSubject) {
                        Spacer(modifier = Modifier.height(8.dp))
                    }
                }
            }
        }
    }
}

@Composable
private fun PlanItemRow(
    item: PlanItem,
    subject: Subject
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(8.dp))
            .background(Color(subject.color).copy(alpha = 0.1f))
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .size(8.dp)
                .clip(CircleShape)
                .background(Color(subject.color))
        )
        
        Spacer(modifier = Modifier.width(12.dp))
        
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = subject.name,
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.Medium
            )
            
            item.timeSlot?.let { slot ->
                Text(
                    text = slot,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        Text(
            text = "${item.targetMinutes}分",
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = Color(subject.color)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreatePlanDialog(
    subjects: List<Subject>,
    onDismiss: () -> Unit,
    onCreate: (name: String, startDate: Long, endDate: Long, items: List<PlanItem>) -> Unit
) {
    var name by remember { mutableStateOf("") }
    var startDate by remember { mutableStateOf(System.currentTimeMillis()) }
    var endDate by remember { mutableStateOf(System.currentTimeMillis() + 7 * 24 * 60 * 60 * 1000) }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("学習計画を作成") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("計画名") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                
                Text(
                    text = "期間: 1週間",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (name.isNotBlank()) {
                        onCreate(name, startDate, endDate, emptyList())
                    }
                }
            ) {
                Text("作成")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddPlanItemDialog(
    subjects: List<Subject>,
    onDismiss: () -> Unit,
    onAdd: (subjectId: Long, dayOfWeek: DayOfWeek, minutes: Int, timeSlot: String?) -> Unit
) {
    var selectedSubject by remember { mutableStateOf<Subject?>(null) }
    var selectedDay by remember { mutableStateOf(DayOfWeek.MONDAY) }
    var minutes by remember { mutableStateOf("60") }
    var timeSlot by remember { mutableStateOf("") }
    
    val days = listOf(
        DayOfWeek.MONDAY to "月曜日",
        DayOfWeek.TUESDAY to "火曜日",
        DayOfWeek.WEDNESDAY to "水曜日",
        DayOfWeek.THURSDAY to "木曜日",
        DayOfWeek.FRIDAY to "金曜日",
        DayOfWeek.SATURDAY to "土曜日",
        DayOfWeek.SUNDAY to "日曜日"
    )
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("計画項目を追加") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Text(
                    text = "科目",
                    style = MaterialTheme.typography.labelMedium
                )
                
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(subjects) { subject ->
                        FilterChip(
                            selected = selectedSubject?.id == subject.id,
                            onClick = { selectedSubject = subject },
                            label = { Text(subject.name) },
                            leadingIcon = {
                                Box(
                                    modifier = Modifier
                                        .size(12.dp)
                                        .clip(CircleShape)
                                        .background(Color(subject.color))
                                )
                            }
                        )
                    }
                }
                
                Text(
                    text = "曜日",
                    style = MaterialTheme.typography.labelMedium
                )
                
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    items(days) { (day, name) ->
                        FilterChip(
                            selected = selectedDay == day,
                            onClick = { selectedDay = day },
                            label = { Text(name) }
                        )
                    }
                }
                
                OutlinedTextField(
                    value = minutes,
                    onValueChange = { minutes = it.filter { c -> c.isDigit() } },
                    label = { Text("学習時間（分）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                
                OutlinedTextField(
                    value = timeSlot,
                    onValueChange = { timeSlot = it },
                    label = { Text("時間帯（任意）") },
                    placeholder = { Text("例: 19:00-21:00") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    selectedSubject?.let { subject ->
                        val mins = minutes.toIntOrNull() ?: 60
                        onAdd(subject.id, selectedDay, mins, timeSlot.ifBlank { null })
                    }
                },
                enabled = selectedSubject != null
            ) {
                Text("追加")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}