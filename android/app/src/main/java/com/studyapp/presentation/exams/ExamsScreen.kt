package com.studyapp.presentation.exams

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Exam
import com.studyapp.presentation.components.EmptyState
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import java.text.SimpleDateFormat
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExamsScreen(
    viewModel: ExamsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showAddDialog by remember { mutableStateOf(false) }
    var editingExam by remember { mutableStateOf<Exam?>(null) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "テスト管理",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        },
        floatingActionButton = {
            FloatingActionButton(
                onClick = { showAddDialog = true },
                containerColor = MaterialTheme.colorScheme.primary
            ) {
                Icon(Icons.Default.Add, contentDescription = "追加")
            }
        }
    ) { paddingValues ->
        if (uiState.exams.isEmpty()) {
            EmptyState(
                icon = Icons.Default.Event,
                title = "テスト予定がありません",
                description = "＋ボタンで追加してください",
                modifier = Modifier.padding(paddingValues)
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                items(uiState.exams, key = { it.id }) { exam ->
                    ExamCard(
                        exam = exam,
                        onEdit = { editingExam = exam },
                        onDelete = { viewModel.deleteExam(exam) }
                    )
                }
            }
        }
    }
    
    if (showAddDialog) {
        AddEditExamDialog(
            onDismiss = { showAddDialog = false },
            onConfirm = { name, date, note ->
                viewModel.addExam(name, date, note)
                showAddDialog = false
            }
        )
    }
    
    editingExam?.let { exam ->
        AddEditExamDialog(
            exam = exam,
            onDismiss = { editingExam = null },
            onConfirm = { name, date, note ->
                viewModel.updateExam(exam.copy(name = name, date = date, note = note))
                editingExam = null
            }
        )
    }
}

@Composable
private fun ExamCard(
    exam: Exam,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    var showDeleteConfirm by remember { mutableStateOf(false) }
    val dateFormat = SimpleDateFormat("yyyy年M月d日", Locale.JAPANESE)
    val examDateMillis = exam.date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
    val daysRemaining = exam.getDaysRemaining(LocalDate.now())

    val urgencyColor = when {
        daysRemaining < 0 -> MaterialTheme.colorScheme.surfaceVariant
        daysRemaining <= 7 -> MaterialTheme.colorScheme.error
        daysRemaining <= 30 -> MaterialTheme.colorScheme.tertiary
        else -> MaterialTheme.colorScheme.primary
    }
    val urgencyContentColor = when {
        daysRemaining < 0 -> MaterialTheme.colorScheme.onSurfaceVariant
        daysRemaining <= 7 -> MaterialTheme.colorScheme.onError
        daysRemaining <= 30 -> MaterialTheme.colorScheme.onTertiary
        else -> MaterialTheme.colorScheme.onPrimary
    }

    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = if (daysRemaining < 0) MaterialTheme.colorScheme.surfaceVariant
                            else MaterialTheme.colorScheme.surface
        )
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(IntrinsicSize.Min)
        ) {
            if (daysRemaining >= 0) {
                val stripColor = when {
                    daysRemaining < 7 -> MaterialTheme.colorScheme.error
                    daysRemaining < 30 -> MaterialTheme.colorScheme.tertiary
                    else -> MaterialTheme.colorScheme.primary
                }
                Box(
                    modifier = Modifier
                        .width(4.dp)
                        .fillMaxHeight()
                        .background(stripColor)
                )
            }
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
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = exam.name,
                            style = MaterialTheme.typography.titleMedium,
                            fontWeight = FontWeight.Bold
                        )
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = dateFormat.format(Date(examDateMillis)),
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }

                    Surface(
                        color = urgencyColor,
                        shape = RoundedCornerShape(12.dp)
                    ) {
                        Text(
                            text = if (daysRemaining < 0) "終了"
                                   else if (daysRemaining == 0L) "今日"
                                   else "あと${daysRemaining}日",
                            modifier = Modifier.padding(horizontal = 12.dp, vertical = 4.dp),
                            style = MaterialTheme.typography.labelLarge,
                            fontWeight = FontWeight.Bold,
                            color = urgencyContentColor
                        )
                    }
                }

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.End
                ) {
                    IconButton(onClick = onEdit) {
                        Icon(Icons.Default.Edit, contentDescription = "編集")
                    }
                    IconButton(onClick = { showDeleteConfirm = true }) {
                        Icon(Icons.Default.Delete, contentDescription = "削除")
                    }
                }

                if (!exam.note.isNullOrBlank()) {
                    Text(
                        text = exam.note,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("削除確認") },
            text = { Text("「${exam.name}」を削除しますか？") },
            confirmButton = {
                TextButton(
                    onClick = {
                        onDelete()
                        showDeleteConfirm = false
                    }
                ) {
                    Text("削除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeleteConfirm = false }) {
                    Text("キャンセル")
                }
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun AddEditExamDialog(
    exam: Exam? = null,
    onDismiss: () -> Unit,
    onConfirm: (name: String, date: LocalDate, note: String?) -> Unit
) {
    var name by remember { mutableStateOf(exam?.name ?: "") }
    var selectedDate by remember { mutableStateOf(exam?.date ?: LocalDate.now()) }
    var note by remember { mutableStateOf(exam?.note ?: "") }
    var showDatePicker by remember { mutableStateOf(false) }
    
    val initialDateMillis = remember {
        selectedDate.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
    }
    
    val datePickerState = rememberDatePickerState(
        initialSelectedDateMillis = initialDateMillis
    )
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (exam == null) "テスト追加" else "テスト編集") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("テスト名") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                
                OutlinedButton(
                    onClick = { showDatePicker = true },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    val dateFormat = SimpleDateFormat("yyyy年M月d日", Locale.JAPANESE)
                    val dateMillis = selectedDate.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
                    Text("日付: ${dateFormat.format(Date(dateMillis))}")
                }
                
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("メモ（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (name.isNotBlank()) {
                        onConfirm(name, selectedDate, note.ifBlank { null })
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
    
    if (showDatePicker) {
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(
                    onClick = {
                        datePickerState.selectedDateMillis?.let { millis ->
                            selectedDate = java.time.Instant.ofEpochMilli(millis)
                                .atZone(ZoneId.systemDefault())
                                .toLocalDate()
                        }
                        showDatePicker = false
                    }
                ) {
                    Text("OK")
                }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) {
                    Text("キャンセル")
                }
            }
        ) {
            DatePicker(state = datePickerState)
        }
    }
}