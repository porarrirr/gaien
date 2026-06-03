package com.studyapp.presentation.history

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.ExpandMore
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.VerticalDivider
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Goal
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.StudySession
import com.studyapp.domain.model.StudySessionInterval
import com.studyapp.domain.model.Subject
import com.studyapp.presentation.components.EmptyState
import com.studyapp.presentation.theme.toSubjectColor
import java.time.Instant
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.LocalTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import java.time.format.DateTimeParseException
import java.util.Locale

private val HistoryDayFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("yyyy年M月d日（E）", Locale.JAPANESE)
private val HistoryDraftDateFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("uuuu/M/d", Locale.JAPANESE)
private val HistoryClockFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("HH:mm", Locale.JAPANESE)
private val HistoryClockParser: DateTimeFormatter =
    DateTimeFormatter.ofPattern("H:mm", Locale.JAPANESE)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HistoryScreen(
    viewModel: HistoryViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var editingSession by remember { mutableStateOf<StudySession?>(null) }
    var pendingDeletionSession by remember { mutableStateOf<StudySession?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "履歴",
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
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentAlignment = Alignment.Center
                ) {
                    Text(
                        text = "読み込み中",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            uiState.sessions.isEmpty() -> {
                EmptyState(
                    icon = Icons.Default.History,
                    title = "学習履歴がありません",
                    description = "タイマーや手動入力で記録した学習履歴がここに表示されます。",
                    modifier = Modifier.padding(paddingValues)
                )
            }

            else -> {
                val groups = remember(uiState.sessions) {
                    uiState.sessions
                        .groupBy { it.sessionLocalDate() }
                        .map { (date, sessions) ->
                            HistoryDayGroup(
                                date = date,
                                sessions = sessions.sortedByDescending { it.sessionStartTime }
                            )
                        }
                        .sortedByDescending { it.date }
                }

                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .background(MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.28f)),
                    contentPadding = PaddingValues(top = 8.dp, bottom = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(18.dp)
                ) {
                    item(key = "history_header") {
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(horizontal = 16.dp),
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Text(
                                text = "すべての履歴",
                                style = MaterialTheme.typography.titleMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onSurface
                            )
                            Spacer(modifier = Modifier.weight(1f))
                            HistoryFilterMenu(
                                subjects = uiState.subjects,
                                selectedSubjectId = uiState.filterSubjectId,
                                onSelect = viewModel::setFilter
                            )
                        }
                    }

                    groups.forEach { group ->
                        item(key = "day_${group.date}") {
                            HistoryDaySection(
                                group = group,
                                subjects = uiState.subjects,
                                materials = uiState.materials,
                                onEdit = { editingSession = it },
                                onDelete = { pendingDeletionSession = it },
                                modifier = Modifier.padding(horizontal = 16.dp)
                            )
                        }
                    }
                }
            }
        }
    }

    if (uiState.error != null) {
        AlertDialog(
            onDismissRequest = viewModel::clearError,
            title = { Text("履歴を読み込めません") },
            text = { Text(uiState.error ?: "") },
            confirmButton = {
                TextButton(onClick = viewModel::clearError) {
                    Text("閉じる")
                }
            }
        )
    }

    editingSession?.let { session ->
        val subject = uiState.subjects.firstOrNull { it.id == session.subjectId }
        val material = uiState.materials.matchingSession(session)
        HistorySessionEditorSheet(
            session = session,
            subject = subject,
            material = material,
            onCancel = { editingSession = null },
            onSave = { updatedSession ->
                viewModel.updateSession(updatedSession)
                editingSession = null
            },
            onDelete = { pendingDeletionSession = session }
        )
    }

    pendingDeletionSession?.let { session ->
        AlertDialog(
            onDismissRequest = { pendingDeletionSession = null },
            title = { Text("この学習履歴を削除しますか？") },
            text = { Text("削除した履歴は元に戻せません。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deleteSession(session)
                        if (editingSession?.id == session.id) {
                            editingSession = null
                        }
                        pendingDeletionSession = null
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = MaterialTheme.colorScheme.error
                    )
                ) {
                    Text("削除")
                }
            },
            dismissButton = {
                TextButton(onClick = { pendingDeletionSession = null }) {
                    Text("キャンセル")
                }
            }
        )
    }
}

@Composable
private fun HistoryFilterMenu(
    subjects: List<Subject>,
    selectedSubjectId: Long?,
    onSelect: (Long?) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }

    Box {
        TextButton(onClick = { expanded = true }) {
            Text(
                text = "編集",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold
            )
            Icon(
                imageVector = Icons.Default.ExpandMore,
                contentDescription = null,
                modifier = Modifier.size(18.dp)
            )
        }

        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            DropdownMenuItem(
                text = { Text("すべて") },
                leadingIcon = {
                    if (selectedSubjectId == null) {
                        Icon(Icons.Default.CheckCircle, contentDescription = null)
                    }
                },
                onClick = {
                    onSelect(null)
                    expanded = false
                }
            )
            subjects.forEach { subject ->
                DropdownMenuItem(
                    text = { Text(subject.name) },
                    leadingIcon = {
                        Box(
                            modifier = Modifier
                                .size(12.dp)
                                .clip(CircleShape)
                                .background(subject.color.toSubjectColor())
                        )
                    },
                    trailingIcon = {
                        if (selectedSubjectId == subject.id) {
                            Icon(Icons.Default.CheckCircle, contentDescription = null)
                        }
                    },
                    onClick = {
                        onSelect(subject.id)
                        expanded = false
                    }
                )
            }
        }
    }
}

private data class HistoryDayGroup(
    val date: LocalDate,
    val sessions: List<StudySession>
) {
    val totalMinutes: Int = sessions.sumOf { it.durationMinutes }
}

@Composable
private fun HistoryDaySection(
    group: HistoryDayGroup,
    subjects: List<Subject>,
    materials: List<Material>,
    onEdit: (StudySession) -> Unit,
    onDelete: (StudySession) -> Unit,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.padding(horizontal = 14.dp),
            verticalAlignment = Alignment.Bottom
        ) {
            Text(
                text = group.date.format(HistoryDayFormatter),
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = "合計 ${group.sessions.size}セッション ・ ${Goal.formatMinutes(group.totalMinutes)}",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Surface(
            modifier = Modifier
                .fillMaxWidth()
                .border(
                    width = 1.dp,
                    color = MaterialTheme.colorScheme.outlineVariant,
                    shape = RoundedCornerShape(8.dp)
                ),
            shape = RoundedCornerShape(8.dp),
            color = MaterialTheme.colorScheme.surface
        ) {
            Column {
                group.sessions.forEachIndexed { index, session ->
                    val subject = subjects.firstOrNull { it.id == session.subjectId }
                    val material = materials.matchingSession(session)
                    HistorySessionRow(
                        session = session,
                        subject = subject,
                        material = material,
                        onEdit = { onEdit(session) },
                        onDelete = { onDelete(session) }
                    )
                    if (index < group.sessions.lastIndex) {
                        HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun HistorySessionRow(
    session: StudySession,
    subject: Subject?,
    material: Material?,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 116.dp)
            .combinedClickable(
                onClick = onEdit,
                onLongClick = onDelete
            )
            .padding(start = 14.dp, end = 6.dp, top = 14.dp, bottom = 14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        MaterialSummaryColumn(
            session = session,
            subject = subject,
            material = material,
            modifier = Modifier
                .weight(1f)
                .padding(end = 10.dp)
        )

        VerticalDivider(
            modifier = Modifier
                .height(88.dp)
                .width(1.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )

        DurationColumn(
            session = session,
            modifier = Modifier.width(94.dp)
        )

        VerticalDivider(
            modifier = Modifier
                .height(88.dp)
                .width(1.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )

        ReviewColumn(
            session = session,
            material = material,
            modifier = Modifier.width(144.dp)
        )

        VerticalDivider(
            modifier = Modifier
                .height(88.dp)
                .width(1.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )

        IconButton(
            onClick = onEdit,
            modifier = Modifier.size(width = 34.dp, height = 44.dp)
        ) {
            Icon(
                imageVector = Icons.Default.Edit,
                contentDescription = "履歴を編集",
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(22.dp)
            )
        }
    }
}

@Composable
private fun MaterialSummaryColumn(
    session: StudySession,
    subject: Subject?,
    material: Material?,
    modifier: Modifier = Modifier
) {
    val subjectName = session.subjectName.ifBlank { subject?.name ?: "未設定" }
    val materialName = session.materialName.ifBlank { material?.name ?: "教材未設定" }

    Column(
        modifier = modifier,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(9.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(14.dp)
                    .clip(CircleShape)
                    .background(sessionColor(subject, material))
            )
            Text(
                text = subjectName,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        Text(
            text = materialName,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )

        Text(
            text = session.problemRangeDisplay(material),
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun DurationColumn(
    session: StudySession,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier.padding(horizontal = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(18.dp)
    ) {
        Row(
            verticalAlignment = Alignment.Bottom,
            horizontalArrangement = Arrangement.Center
        ) {
            Text(
                text = session.durationMinutes.toString(),
                fontSize = 27.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Text(
                text = "分",
                fontSize = 17.sp,
                color = MaterialTheme.colorScheme.onSurface
            )
        }
        Text(
            text = session.historyTimeLabel(),
            fontSize = 11.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun ReviewColumn(
    session: StudySession,
    material: Material?,
    modifier: Modifier = Modifier
) {
    val correctCount = session.problemRecords.count { it.result == ProblemResult.CORRECT }
    val wrongCount = session.effectiveWrongProblemCount ?: 0
    val reviewCorrectCount = session.effectiveReviewCorrectProblemCount

    Column(
        modifier = modifier.padding(horizontal = 8.dp),
        verticalArrangement = Arrangement.spacedBy(7.dp)
    ) {
        StarRatingRow(rating = session.rating ?: 0)
        Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
            ProblemCountColumn("正解", correctCount, MaterialTheme.colorScheme.primary)
            ProblemCountColumn("不正解", wrongCount, MaterialTheme.colorScheme.error)
            ProblemCountColumn("復習正解", reviewCorrectCount, Color(0xFFE49B0F))
        }

        if (session.problemRecords.isNotEmpty()) {
            ProblemResultDetails(session = session, material = material)
        }

        Text(
            text = session.note?.trim()?.takeIf { it.isNotEmpty() } ?: "メモはありません",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
    }
}

@Composable
private fun StarRatingRow(rating: Int) {
    Row(horizontalArrangement = Arrangement.spacedBy(0.dp)) {
        for (value in 1..5) {
            Icon(
                imageVector = if (value <= rating) Icons.Default.Star else Icons.Default.StarBorder,
                contentDescription = null,
                tint = if (value <= rating) Color(0xFFE49B0F) else Color(0xFFC6CAD1),
                modifier = Modifier.size(17.dp)
            )
        }
    }
}

@Composable
private fun ProblemCountColumn(
    title: String,
    value: Int,
    color: Color
) {
    Column(
        modifier = Modifier.width(42.dp),
        verticalArrangement = Arrangement.spacedBy(1.dp)
    ) {
        Text(
            text = title,
            fontSize = 8.sp,
            fontWeight = FontWeight.SemiBold,
            color = color,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Text(
            text = value.toString(),
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold,
            color = color,
            maxLines = 1
        )
    }
}

@Composable
private fun ProblemResultDetails(
    session: StudySession,
    material: Material?
) {
    Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
        ProblemResultLine("正解", ProblemResult.CORRECT, MaterialTheme.colorScheme.primary, session, material)
        ProblemResultLine("不正解", ProblemResult.WRONG, MaterialTheme.colorScheme.error, session, material)
        ProblemResultLine("復習正解", ProblemResult.REVIEW_CORRECT, Color(0xFFE49B0F), session, material)
    }
}

@Composable
private fun ProblemResultLine(
    title: String,
    result: ProblemResult,
    color: Color,
    session: StudySession,
    material: Material?
) {
    val labels = session.problemRecords
        .filter { it.result == result }
        .sortedWith(compareBy<ProblemSessionRecord> { it.number }.thenBy { it.normalizedSubNumber ?: "" })
        .map { it.compactLabel(material) }

    if (labels.isNotEmpty()) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(4.dp),
            verticalAlignment = Alignment.Top
        ) {
            Text(
                text = title,
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                color = color,
                modifier = Modifier.width(38.dp)
            )
            Text(
                text = labels.compactProblemNumbers(),
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun HistorySessionEditorSheet(
    session: StudySession,
    subject: Subject?,
    material: Material?,
    onCancel: () -> Unit,
    onSave: (StudySession) -> Unit,
    onDelete: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val initialProblemCount = remember(session, material) {
        maxOf(
            material?.effectiveTotalProblems ?: 0,
            session.problemRecords.maxOfOrNull { it.number } ?: 0,
            session.problemEnd ?: 0
        )
    }
    var intervalDrafts by remember(session) {
        mutableStateOf(session.effectiveIntervals.map { it.toDraft() })
    }
    var rating by remember(session) { mutableStateOf(session.rating ?: 0) }
    var note by remember(session) { mutableStateOf(session.note ?: "") }
    var problemStart by remember(session) { mutableStateOf(session.problemStart?.toString() ?: "") }
    var problemEnd by remember(session) { mutableStateOf(session.problemEnd?.toString() ?: "") }
    var wrongProblemCount by remember(session) {
        mutableStateOf(
            session.wrongProblemCount?.toString()
                ?: session.problemRecords.count { it.result == ProblemResult.WRONG }.takeIf { session.problemRecords.isNotEmpty() }?.toString()
                ?: ""
        )
    }
    var problemCount by remember(session, initialProblemCount) { mutableStateOf(initialProblemCount) }
    var problemRecords by remember(session) { mutableStateOf(session.problemRecords) }

    val validation = remember(intervalDrafts) { validateIntervalDrafts(intervalDrafts) }
    val normalizedRecords = remember(problemRecords) {
        problemRecords.sortedWith(compareBy<ProblemSessionRecord> { it.number }.thenBy { it.normalizedSubNumber ?: "" })
    }
    val canSave = validation.isValid

    ModalBottomSheet(
        onDismissRequest = onCancel,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier.fillMaxWidth()
        ) {
            HistoryEditorHeader(
                canSave = canSave,
                onCancel = onCancel,
                onSave = {
                    val intervals = validation.intervals
                    if (intervals.isEmpty()) return@HistoryEditorHeader
                    val savedRecords = normalizedRecords
                    val updated = session.copy(
                        startTime = intervals.minOf { it.startTime },
                        endTime = intervals.maxOf { it.endTime },
                        intervals = intervals,
                        rating = rating.takeIf { it in StudySession.allowedRatings },
                        note = note.trim().takeIf { it.isNotEmpty() },
                        problemStart = savedRecords.minOfOrNull { it.number } ?: problemStart.toIntOrNull(),
                        problemEnd = savedRecords.maxOfOrNull { it.number } ?: problemEnd.toIntOrNull(),
                        wrongProblemCount = if (savedRecords.isNotEmpty()) {
                            savedRecords.count { it.result == ProblemResult.WRONG }
                        } else {
                            wrongProblemCount.toIntOrNull()
                        },
                        problemRecords = savedRecords
                    )
                    onSave(updated)
                }
            )

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .weight(1f, fill = false)
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 18.dp, vertical = 10.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                HistoryEditorSummaryCard(
                    session = session,
                    subject = subject,
                    material = material,
                    intervalCount = intervalDrafts.size,
                    totalMinutes = validation.totalMinutes
                )

                IntervalEditorSection(
                    intervalDrafts = intervalDrafts,
                    validation = validation,
                    onChange = { intervalDrafts = it },
                    onAdd = {
                        val lastEnd = intervalDrafts.lastOrNull()?.let { parseDraftDateTime(it.endDate, it.endTime) }
                        if (lastEnd != null) {
                            val start = lastEnd
                            val end = lastEnd.plusMinutes(50)
                            intervalDrafts = intervalDrafts + HistoryIntervalDraft.fromDateTimes(start, end)
                        }
                    }
                )

                RatingEditorSection(
                    rating = rating,
                    onRatingChange = { rating = if (rating == it) 0 else it }
                )

                ProblemEditorSection(
                    problemCount = problemCount,
                    records = problemRecords,
                    problemStart = problemStart,
                    problemEnd = problemEnd,
                    wrongProblemCount = wrongProblemCount,
                    material = material,
                    onProblemCountChange = { nextCount ->
                        problemCount = nextCount
                        val hadRecords = problemRecords.isNotEmpty()
                        val filteredRecords = problemRecords.filter { it.number <= nextCount }
                        problemRecords = filteredRecords
                        if (filteredRecords.isNotEmpty()) {
                            problemStart = filteredRecords.minOf { it.number }.toString()
                            problemEnd = filteredRecords.maxOf { it.number }.toString()
                            wrongProblemCount = filteredRecords.count { it.result == ProblemResult.WRONG }.toString()
                        } else if (hadRecords) {
                            problemStart = ""
                            problemEnd = ""
                            wrongProblemCount = ""
                        }
                    },
                    onRecordsChange = { records ->
                        val hadRecords = problemRecords.isNotEmpty()
                        problemRecords = records
                        if (records.isNotEmpty()) {
                            problemStart = records.minOf { it.number }.toString()
                            problemEnd = records.maxOf { it.number }.toString()
                            wrongProblemCount = records.count { it.result == ProblemResult.WRONG }.toString()
                        } else if (hadRecords) {
                            problemStart = ""
                            problemEnd = ""
                            wrongProblemCount = ""
                        }
                    },
                    onProblemStartChange = { problemStart = it.filter(Char::isDigit) },
                    onProblemEndChange = { problemEnd = it.filter(Char::isDigit) },
                    onWrongProblemCountChange = { wrongProblemCount = it.filter(Char::isDigit) }
                )

                NoteEditorSection(
                    note = note,
                    onNoteChange = { note = it.take(300) }
                )
            }

            HistoryEditorBottomBar(
                canSave = canSave,
                disabledMessage = validation.message,
                onDelete = onDelete,
                onSave = {
                    val intervals = validation.intervals
                    if (intervals.isEmpty()) return@HistoryEditorBottomBar
                    val savedRecords = normalizedRecords
                    onSave(
                        session.copy(
                            startTime = intervals.minOf { it.startTime },
                            endTime = intervals.maxOf { it.endTime },
                            intervals = intervals,
                            rating = rating.takeIf { it in StudySession.allowedRatings },
                            note = note.trim().takeIf { it.isNotEmpty() },
                            problemStart = savedRecords.minOfOrNull { it.number } ?: problemStart.toIntOrNull(),
                            problemEnd = savedRecords.maxOfOrNull { it.number } ?: problemEnd.toIntOrNull(),
                            wrongProblemCount = if (savedRecords.isNotEmpty()) {
                                savedRecords.count { it.result == ProblemResult.WRONG }
                            } else {
                                wrongProblemCount.toIntOrNull()
                            },
                            problemRecords = savedRecords
                        )
                    )
                }
            )
        }
    }
}

@Composable
private fun HistoryEditorHeader(
    canSave: Boolean,
    onCancel: () -> Unit,
    onSave: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp)
            .padding(top = 6.dp, bottom = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        TextButton(onClick = onCancel) {
            Text(
                text = "キャンセル",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Medium
            )
        }
        Spacer(modifier = Modifier.weight(1f))
        Text(
            text = "履歴を編集",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold
        )
        Spacer(modifier = Modifier.weight(1f))
        TextButton(
            onClick = onSave,
            enabled = canSave
        ) {
            Text(
                text = "保存",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Medium
            )
        }
    }
}

@Composable
private fun HistoryEditorSummaryCard(
    session: StudySession,
    subject: Subject?,
    material: Material?,
    intervalCount: Int,
    totalMinutes: Int
) {
    HistoryEditorCard {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(sessionColor(subject, material))
            )
            Text(
                text = session.subjectName.ifBlank { subject?.name ?: "未設定" },
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            if (session.materialName.isNotBlank() || material != null) {
                Text(
                    text = "|",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Text(
                    text = session.materialName.ifBlank { material?.name ?: "" },
                    style = MaterialTheme.typography.bodyMedium,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
        Spacer(modifier = Modifier.height(10.dp))
        Text(
            text = "区間数: $intervalCount    合計予定時間: ${Goal.formatMinutes(totalMinutes)}",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun IntervalEditorSection(
    intervalDrafts: List<HistoryIntervalDraft>,
    validation: IntervalValidation,
    onChange: (List<HistoryIntervalDraft>) -> Unit,
    onAdd: () -> Unit
) {
    HistoryEditorCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "区間 (ドラフト)",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(modifier = Modifier.weight(1f))
            TextButton(
                onClick = onAdd,
                enabled = intervalDrafts.lastOrNull()?.let { parseDraftDateTime(it.endDate, it.endTime) } != null
            ) {
                Icon(Icons.Default.Add, contentDescription = null, modifier = Modifier.size(18.dp))
                Text("区間を追加")
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            intervalDrafts.forEachIndexed { index, draft ->
                IntervalDraftCard(
                    index = index,
                    draft = draft,
                    canRemove = intervalDrafts.size > 1,
                    onDraftChange = { next: HistoryIntervalDraft ->
                        onChange(intervalDrafts.toMutableList().apply { set(index, next) })
                    },
                    onRemove = {
                        onChange(intervalDrafts.toMutableList().apply { removeAt(index) })
                    }
                )
            }
        }

        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End
        ) {
            Text(
                text = validation.message ?: "合計予定時間: ${Goal.formatMinutes(validation.totalMinutes)}",
                style = MaterialTheme.typography.bodySmall,
                color = if (validation.isValid) {
                    MaterialTheme.colorScheme.onSurfaceVariant
                } else {
                    MaterialTheme.colorScheme.error
                }
            )
        }
    }
}

@Composable
private fun IntervalDraftCard(
    index: Int,
    draft: HistoryIntervalDraft,
    canRemove: Boolean,
    onDraftChange: (HistoryIntervalDraft) -> Unit,
    onRemove: () -> Unit
) {
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(
            modifier = Modifier.padding(10.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "区間 ${index + 1}",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold
                )
                Spacer(modifier = Modifier.weight(1f))
                IconButton(
                    onClick = onRemove,
                    enabled = canRemove,
                    modifier = Modifier.size(32.dp)
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = "区間を削除",
                        tint = if (canRemove) MaterialTheme.colorScheme.error else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.35f),
                        modifier = Modifier.size(18.dp)
                    )
                }
            }

            HistoryDateTimeRow(
                title = "開始",
                date = draft.startDate,
                time = draft.startTime,
                onDateChange = { onDraftChange(draft.copy(startDate = it)) },
                onTimeChange = { onDraftChange(draft.copy(startTime = it)) }
            )
            HistoryDateTimeRow(
                title = "終了",
                date = draft.endDate,
                time = draft.endTime,
                onDateChange = { onDraftChange(draft.copy(endDate = it)) },
                onTimeChange = { onDraftChange(draft.copy(endTime = it)) }
            )

            val durationText = parseDraftDateTime(draft.startDate, draft.startTime)
                ?.let { start -> parseDraftDateTime(draft.endDate, draft.endTime)?.let { end -> end to start } }
                ?.let { (end, start) -> java.time.Duration.between(start, end).toMinutes().coerceAtLeast(0).toInt() }
                ?.let(Goal.Companion::formatMinutes)
                ?: "未確定"
            Row {
                Text(
                    text = "予定時間",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = durationText,
                    style = MaterialTheme.typography.bodySmall,
                    fontWeight = FontWeight.SemiBold
                )
            }
        }
    }
}

@Composable
private fun HistoryDateTimeRow(
    title: String,
    date: String,
    time: String,
    onDateChange: (String) -> Unit,
    onTimeChange: (String) -> Unit
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.width(34.dp)
        )
        OutlinedTextField(
            value = date,
            onValueChange = onDateChange,
            label = { Text("日付") },
            singleLine = true,
            modifier = Modifier.weight(1.15f)
        )
        OutlinedTextField(
            value = time,
            onValueChange = onTimeChange,
            label = { Text("時刻") },
            singleLine = true,
            modifier = Modifier.weight(0.85f)
        )
    }
}

@Composable
private fun RatingEditorSection(
    rating: Int,
    onRatingChange: (Int) -> Unit
) {
    HistoryEditorCard {
        Text(
            text = "評価",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.Center
        ) {
            for (value in 1..5) {
                IconButton(onClick = { onRatingChange(value) }) {
                    Icon(
                        imageVector = if (value <= rating) Icons.Default.Star else Icons.Default.StarBorder,
                        contentDescription = "評価 $value",
                        tint = if (value <= rating) Color(0xFFE49B0F) else MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.65f),
                        modifier = Modifier.size(30.dp)
                    )
                }
            }
        }
        if (rating > 0) {
            Text(
                text = rating.toString(),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }
    }
}

@Composable
private fun ProblemEditorSection(
    problemCount: Int,
    records: List<ProblemSessionRecord>,
    problemStart: String,
    problemEnd: String,
    wrongProblemCount: String,
    material: Material?,
    onProblemCountChange: (Int) -> Unit,
    onRecordsChange: (List<ProblemSessionRecord>) -> Unit,
    onProblemStartChange: (String) -> Unit,
    onProblemEndChange: (String) -> Unit,
    onWrongProblemCountChange: (String) -> Unit
) {
    HistoryEditorCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                text = "問題集の記録",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.SemiBold
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = if (problemCount > 0) "全${problemCount}問" else "問題数未設定",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        ProblemCountControls(
            problemCount = problemCount,
            onProblemCountChange = onProblemCountChange
        )

        if (problemCount > 0) {
            ProblemRecordGrid(
                problemCount = problemCount,
                material = material,
                records = records,
                onRecordsChange = onRecordsChange
            )
            ProblemRecordSummary(records = records)
        } else {
            Text(
                text = "教材に問題数が未設定です。全問題数を入力すると、番号タップで記録できます。",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(
                value = problemStart,
                onValueChange = onProblemStartChange,
                label = { Text("開始") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
            OutlinedTextField(
                value = problemEnd,
                onValueChange = onProblemEndChange,
                label = { Text("終了") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
            OutlinedTextField(
                value = wrongProblemCount,
                onValueChange = onWrongProblemCountChange,
                label = { Text("不正解") },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
                singleLine = true,
                modifier = Modifier.weight(1f)
            )
        }
    }
}

@Composable
private fun ProblemCountControls(
    problemCount: Int,
    onProblemCountChange: (Int) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Button(
                onClick = { onProblemCountChange((problemCount - 1).coerceAtLeast(0)) },
                enabled = problemCount > 0
            ) {
                Text("-")
            }
            Text(
                text = "全${problemCount}問",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.weight(1f)
            )
            Button(onClick = { onProblemCountChange(problemCount + 1) }) {
                Text("+")
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            listOf(10, 20, 50).forEach { count ->
                FilterChip(
                    selected = problemCount == count,
                    onClick = { onProblemCountChange(count) },
                    label = { Text("${count}問") }
                )
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ProblemRecordGrid(
    problemCount: Int,
    material: Material?,
    records: List<ProblemSessionRecord>,
    onRecordsChange: (List<ProblemSessionRecord>) -> Unit
) {
    val recordsByNumber = records.associateBy { it.number }
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        (1..problemCount).chunked(5).forEach { rowNumbers ->
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                rowNumbers.forEach { number ->
                    val record = recordsByNumber[number]
                    ProblemRecordTile(
                        number = number,
                        label = material?.problemLabel(forNumber = number) ?: "${number}問",
                        record = record,
                        onClick = {
                            val nextRecords = records.nextProblemRecord(number)
                            onRecordsChange(nextRecords)
                        },
                        modifier = Modifier.weight(1f)
                    )
                }
                repeat(5 - rowNumbers.size) {
                    Spacer(modifier = Modifier.weight(1f))
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun ProblemRecordTile(
    number: Int,
    label: String,
    record: ProblemSessionRecord?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val color = when (record?.result) {
        ProblemResult.CORRECT -> MaterialTheme.colorScheme.primary
        ProblemResult.WRONG -> MaterialTheme.colorScheme.error
        ProblemResult.REVIEW_CORRECT -> Color(0xFFE49B0F)
        null -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    val icon = when (record?.result) {
        ProblemResult.CORRECT -> Icons.Default.CheckCircle
        ProblemResult.WRONG -> Icons.Default.Warning
        ProblemResult.REVIEW_CORRECT -> Icons.Default.Star
        null -> Icons.Default.RadioButtonUnchecked
    }

    Surface(
        modifier = modifier
            .height(52.dp)
            .combinedClickable(onClick = onClick),
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surface,
        border = androidx.compose.foundation.BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 4.dp, vertical = 5.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Medium,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Icon(
                imageVector = icon,
                contentDescription = "${number}問",
                tint = color,
                modifier = Modifier.size(18.dp)
            )
        }
    }
}

@Composable
private fun ProblemRecordSummary(records: List<ProblemSessionRecord>) {
    val done = records.size
    val correct = records.count { it.result == ProblemResult.CORRECT }
    val wrong = records.count { it.result == ProblemResult.WRONG }
    val review = records.count { it.result == ProblemResult.REVIEW_CORRECT }
    Text(
        text = "タップで未解答→正解→不正解→復習正解を切り替えます。選択 ${done}問 / 正解 ${correct}問 / 不正解 ${wrong}問 / 復習正解 ${review}問",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant
    )
}

@Composable
private fun NoteEditorSection(
    note: String,
    onNoteChange: (String) -> Unit
) {
    HistoryEditorCard {
        Text(
            text = "メモ",
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.SemiBold
        )
        OutlinedTextField(
            value = note,
            onValueChange = onNoteChange,
            modifier = Modifier
                .fillMaxWidth()
                .height(112.dp),
            maxLines = 4
        )
        Text(
            text = "${note.length}/300",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.align(Alignment.End)
        )
    }
}

@Composable
private fun HistoryEditorBottomBar(
    canSave: Boolean,
    disabledMessage: String?,
    onDelete: () -> Unit,
    onSave: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(width = 1.dp, color = MaterialTheme.colorScheme.outlineVariant)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        TextButton(
            onClick = onDelete,
            colors = ButtonDefaults.textButtonColors(
                contentColor = MaterialTheme.colorScheme.error
            )
        ) {
            Icon(Icons.Default.Delete, contentDescription = null, modifier = Modifier.size(18.dp))
            Text("削除")
        }
        Spacer(modifier = Modifier.weight(1f))
        if (!canSave && disabledMessage != null) {
            Text(
                text = disabledMessage,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Button(
            onClick = onSave,
            enabled = canSave,
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier
                .width(96.dp)
                .height(48.dp)
        ) {
            Text("保存")
        }
    }
}

@Composable
private fun HistoryEditorCard(
    content: @Composable ColumnScope.() -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.surface, RoundedCornerShape(8.dp))
            .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(8.dp))
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
        content = content
    )
}

private data class HistoryIntervalDraft(
    val startDate: String,
    val startTime: String,
    val endDate: String,
    val endTime: String
) {
    companion object {
        fun fromDateTimes(start: LocalDateTime, end: LocalDateTime): HistoryIntervalDraft =
            HistoryIntervalDraft(
                startDate = start.toLocalDate().format(HistoryDraftDateFormatter),
                startTime = start.toLocalTime().format(HistoryClockFormatter),
                endDate = end.toLocalDate().format(HistoryDraftDateFormatter),
                endTime = end.toLocalTime().format(HistoryClockFormatter)
            )
    }
}

private data class IntervalValidation(
    val isValid: Boolean,
    val intervals: List<StudySessionInterval>,
    val totalMinutes: Int,
    val message: String?
)

private fun StudySessionInterval.toDraft(): HistoryIntervalDraft {
    val start = Instant.ofEpochMilli(startTime).atZone(ZoneId.systemDefault()).toLocalDateTime()
    val end = Instant.ofEpochMilli(endTime).atZone(ZoneId.systemDefault()).toLocalDateTime()
    return HistoryIntervalDraft.fromDateTimes(start, end)
}

private fun validateIntervalDrafts(drafts: List<HistoryIntervalDraft>): IntervalValidation {
    if (drafts.isEmpty()) {
        return IntervalValidation(false, emptyList(), 0, "無効な区間があります")
    }
    val dateTimes = drafts.map { draft ->
        val start = parseDraftDateTime(draft.startDate, draft.startTime)
        val end = parseDraftDateTime(draft.endDate, draft.endTime)
        if (start == null || end == null) {
            return IntervalValidation(false, emptyList(), 0, "日付または時刻が無効です")
        }
        start to end
    }
    if (dateTimes.any { (start, end) -> !end.isAfter(start) }) {
        return IntervalValidation(false, emptyList(), 0, "終了は開始より後にしてください")
    }
    for (index in 1 until dateTimes.size) {
        if (dateTimes[index].first.isBefore(dateTimes[index - 1].second)) {
            return IntervalValidation(false, emptyList(), 0, "区間が重なっています")
        }
    }

    val zone = ZoneId.systemDefault()
    val intervals = dateTimes.map { (start, end) ->
        StudySessionInterval(
            startTime = start.atZone(zone).toInstant().toEpochMilli(),
            endTime = end.atZone(zone).toInstant().toEpochMilli()
        )
    }
    val totalMinutes = intervals.sumOf { (it.duration / 60_000L).toInt() }
    return IntervalValidation(true, intervals, totalMinutes, null)
}

private fun parseDraftDateTime(dateText: String, timeText: String): LocalDateTime? {
    val date = parseDraftDate(dateText) ?: return null
    val time = parseDraftTime(timeText) ?: return null
    return LocalDateTime.of(date, time)
}

private fun parseDraftDate(value: String): LocalDate? =
    try {
        LocalDate.parse(value.trim(), HistoryDraftDateFormatter)
    } catch (_: DateTimeParseException) {
        null
    }

private fun parseDraftTime(value: String): LocalTime? =
    try {
        LocalTime.parse(value.trim(), HistoryClockParser)
    } catch (_: DateTimeParseException) {
        null
    }

private fun StudySession.sessionLocalDate(): LocalDate =
    Instant.ofEpochMilli(sessionStartTime)
        .atZone(ZoneId.systemDefault())
        .toLocalDate()

private fun StudySession.historyTimeLabel(): String {
    val zone = ZoneId.systemDefault()
    val start = Instant.ofEpochMilli(sessionStartTime).atZone(zone).toLocalTime()
    val end = Instant.ofEpochMilli(sessionEndTime).atZone(zone).toLocalTime()
    return "${start.format(HistoryClockFormatter)} - ${end.format(HistoryClockFormatter)}"
}

private fun sessionColor(subject: Subject?, material: Material?): Color =
    material?.color?.toSubjectColor() ?: subject?.color?.toSubjectColor() ?: Color(0xFF2F80ED)

private fun List<Material>.matchingSession(session: StudySession): Material? =
    firstOrNull { material ->
        material.id == session.materialId ||
            (session.materialSyncId != null && material.syncId == session.materialSyncId)
    }

private fun StudySession.problemRangeDisplay(material: Material?): String {
    val text = when {
        problemRecords.isNotEmpty() -> {
            val numbers = problemRecords.map { it.number }.distinct().sorted()
            val first = numbers.firstOrNull() ?: return "範囲未入力"
            val last = numbers.lastOrNull() ?: return "範囲未入力"
            val range = if (first == last) {
                material.problemLabel(first)
            } else {
                "${material.problemLabel(first)} - ${material.problemLabel(last)}"
            }
            val subQuestionCount = problemRecords.count { it.normalizedSubNumber != null }
            if (subQuestionCount > 0) "$range（小問${subQuestionCount}件）" else range
        }
        problemStart != null && problemEnd != null -> {
            if (problemStart == problemEnd) {
                material.problemLabel(problemStart)
            } else {
                "${material.problemLabel(problemStart)} - ${material.problemLabel(problemEnd)}"
            }
        }
        else -> problemRangeText ?: "範囲未入力"
    }
    return if (text == "範囲未入力" || text.startsWith("p.")) text else "p.$text"
}

private fun Material?.problemLabel(number: Int?): String {
    val validNumber = number ?: return "範囲未入力"
    return this?.problemLabel(forNumber = validNumber) ?: "${validNumber}問"
}

private fun ProblemSessionRecord.compactLabel(material: Material?): String {
    val base = material.problemLabel(number)
    return normalizedSubNumber?.let { "$base($it)" } ?: base
}

private fun List<String>.compactProblemNumbers(): String {
    val visibleLimit = 8
    val visible = take(visibleLimit).joinToString(", ")
    val remaining = size - visibleLimit
    return if (remaining > 0) "$visible +$remaining" else visible
}

private fun List<ProblemSessionRecord>.nextProblemRecord(number: Int): List<ProblemSessionRecord> {
    val existing = firstOrNull { it.number == number }
    val nextResult = when (existing?.result) {
        null -> ProblemResult.CORRECT
        ProblemResult.CORRECT -> ProblemResult.WRONG
        ProblemResult.WRONG -> ProblemResult.REVIEW_CORRECT
        ProblemResult.REVIEW_CORRECT -> null
    }
    val nextRecords = if (nextResult == null) {
        filterNot { it.number == number }
    } else {
        filterNot { it.number == number } + ProblemSessionRecord(number = number, result = nextResult)
    }
    return nextRecords.sortedWith(compareBy<ProblemSessionRecord> { it.number }.thenBy { it.normalizedSubNumber ?: "" })
}
