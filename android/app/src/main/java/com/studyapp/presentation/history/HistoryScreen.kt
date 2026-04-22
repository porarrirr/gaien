package com.studyapp.presentation.history

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
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.Subject
import com.studyapp.presentation.components.EmptyState
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(
    viewModel: HistoryViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showFilterDialog by remember { mutableStateOf(false) }
    var editingSession by remember { mutableStateOf<StudySession?>(null) }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "学習履歴",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    IconButton(onClick = { showFilterDialog = true }) {
                        Icon(
                            Icons.Default.FilterList,
                            contentDescription = "フィルタ",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        if (uiState.sessions.isEmpty()) {
            EmptyState(
                icon = Icons.Default.History,
                title = "学習履歴がありません",
                description = "タイマーで学習を記録しましょう",
                modifier = Modifier.padding(paddingValues)
            )
        } else {
            val dateKeyFormat = remember { SimpleDateFormat("yyyyMMdd", Locale.JAPANESE) }
            val dateHeaderFormat = remember { SimpleDateFormat("M月d日 (E)", Locale.JAPANESE) }
            val groupedSessions = remember(uiState.sessions) {
                uiState.sessions.groupBy { session ->
                    dateKeyFormat.format(Date(session.startTime))
                }
            }

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                groupedSessions.forEach { (dateKey, sessionsForDate) ->
                    item(key = "header_$dateKey") {
                        Surface(
                            color = MaterialTheme.colorScheme.surfaceVariant,
                            shape = RoundedCornerShape(8.dp),
                            modifier = Modifier.fillMaxWidth()
                        ) {
                            Text(
                                text = dateHeaderFormat.format(Date(sessionsForDate.first().startTime)),
                                style = MaterialTheme.typography.labelLarge,
                                fontWeight = FontWeight.Bold,
                                modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)
                            )
                        }
                    }
                    items(sessionsForDate, key = { it.id }) { session ->
                        SessionCard(
                            session = session,
                            subject = uiState.subjects.find { it.id == session.subjectId },
                            onEdit = { editingSession = session },
                            onDelete = { viewModel.deleteSession(session) }
                        )
                    }
                }
            }
        }
    }
    
    if (showFilterDialog) {
        FilterDialog(
            subjects = uiState.subjects,
            selectedSubjectId = uiState.filterSubjectId,
            onDismiss = { showFilterDialog = false },
            onFilter = { subjectId ->
                viewModel.setFilter(subjectId)
                showFilterDialog = false
            }
        )
    }
    
    editingSession?.let { session ->
        EditSessionDialog(
            session = session,
            subjects = uiState.subjects,
            onDismiss = { editingSession = null },
            onConfirm = { updatedSession ->
                viewModel.updateSession(updatedSession)
                editingSession = null
            }
        )
    }
}

@Composable
private fun SessionCard(
    session: StudySession,
    subject: Subject?,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    var showDeleteConfirm by remember { mutableStateOf(false) }
    val dateFormat = SimpleDateFormat("M月d日", Locale.JAPANESE)
    val timeFormat = SimpleDateFormat("HH:mm", Locale.JAPANESE)

    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
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
                    modifier = Modifier.weight(1f)
                ) {
                    subject?.let {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(Color(it.color))
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                    }
                    Text(
                        text = subject?.name ?: "不明な科目",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                }
                Text(
                    text = session.durationFormatted,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.primary
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            Row(
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = dateFormat.format(Date(session.startTime)),
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "${timeFormat.format(Date(session.startTime))} - ${timeFormat.format(Date(session.endTime))}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                if (session.materialName.isNotBlank()) {
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "・${session.materialName}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            if (!session.note.isNullOrBlank()) {
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = session.note,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Spacer(modifier = Modifier.height(4.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.End
            ) {
                IconButton(
                    onClick = onEdit,
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Default.Edit,
                        contentDescription = "編集",
                        modifier = Modifier.size(18.dp)
                    )
                }
                IconButton(
                    onClick = { showDeleteConfirm = true },
                    modifier = Modifier.size(36.dp)
                ) {
                    Icon(
                        Icons.Default.Delete,
                        contentDescription = "削除",
                        modifier = Modifier.size(18.dp)
                    )
                }
            }
        }
    }

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("削除確認") },
            text = { Text("この学習記録を削除しますか？") },
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
private fun FilterDialog(
    subjects: List<Subject>,
    selectedSubjectId: Long?,
    onDismiss: () -> Unit,
    onFilter: (Long?) -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("フィルタ") },
        text = {
            Column {
                FilterChip(
                    selected = selectedSubjectId == null,
                    onClick = { onFilter(null) },
                    label = { Text("すべて") }
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                subjects.forEach { subject ->
                    FilterChip(
                        selected = selectedSubjectId == subject.id,
                        onClick = { onFilter(subject.id) },
                        label = { Text(subject.name) },
                        modifier = Modifier.padding(vertical = 4.dp)
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("閉じる")
            }
        }
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EditSessionDialog(
    session: StudySession,
    subjects: List<Subject>,
    onDismiss: () -> Unit,
    onConfirm: (StudySession) -> Unit
) {
    var durationMinutes by remember { 
        mutableStateOf((session.duration / 60000).toString()) 
    }
    var note by remember { mutableStateOf(session.note ?: "") }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("学習記録を編集") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                OutlinedTextField(
                    value = durationMinutes,
                    onValueChange = { durationMinutes = it.filter { c -> c.isDigit() } },
                    label = { Text("学習時間（分）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("メモ") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    val minutes = durationMinutes.toLongOrNull() ?: 0
                    val newDuration = minutes * 60000
                    onConfirm(session.copy(
                        endTime = session.startTime + newDuration,
                        intervals = listOf(
                            StudySessionInterval(
                                startTime = session.startTime,
                                endTime = session.startTime + newDuration
                            )
                        ),
                        note = note.ifBlank { null }
                    ))
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
