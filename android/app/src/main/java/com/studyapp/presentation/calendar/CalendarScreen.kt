package com.studyapp.presentation.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle

import com.studyapp.domain.model.StudySession

import kotlin.math.ceil
import java.text.SimpleDateFormat
import java.util.*

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(
    viewModel: CalendarViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var editingSession by remember { mutableStateOf<StudySession?>(null) }

    LaunchedEffect(uiState.error) {
        uiState.error?.let { error ->
            snackbarHostState.showSnackbar(error)
            viewModel.clearError()
        }
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "カレンダー",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        },
        snackbarHost = { SnackbarHost(hostState = snackbarHostState) }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            CalendarHeader(
                year = uiState.currentYear,
                month = uiState.currentMonth,
                onPrevious = { viewModel.previousMonth() },
                onNext = { viewModel.nextMonth() }
            )

            CalendarGrid(
                year = uiState.currentYear,
                month = uiState.currentMonth,
                studyData = uiState.studyDataByDate,
                maxStudyMinutes = uiState.studyDataByDate.values.maxOrNull() ?: 0L,
                selectedDate = uiState.selectedDate,
                onDateSelect = { viewModel.selectDate(it) }
            )

            if (uiState.selectedDate != null) {
                DayDetailPanel(
                    date = uiState.selectedDate!!,
                    sessions = uiState.selectedDateSessions,
                    totalMinutes = uiState.selectedDateMinutes,
                    isLoading = uiState.isDetailLoading,
                    updatingSessionId = uiState.updatingSessionId,
                    onEditMemo = { session -> editingSession = session },
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }

    if (editingSession != null) {
        MemoEditBottomSheet(
            session = editingSession!!,
            isUpdating = uiState.updatingSessionId == editingSession!!.id,
            onSave = { session, note -> viewModel.updateSessionNote(session, note) },
            onDismiss = { editingSession = null }
        )
    }
}

@Composable
private fun CalendarHeader(
    year: Int,
    month: Int,
    onPrevious: () -> Unit,
    onNext: () -> Unit
) {
    val monthNames = listOf(
        "1月", "2月", "3月", "4月", "5月", "6月",
        "7月", "8月", "9月", "10月", "11月", "12月"
    )
    
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        FilledTonalIconButton(onClick = onPrevious) {
            Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "前月")
        }
        
        Text(
            text = "${year}年 ${monthNames[month - 1]}",
            style = MaterialTheme.typography.headlineMedium,
            fontWeight = FontWeight.Bold
        )
        
        FilledTonalIconButton(onClick = onNext) {
            Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "翌月")
        }
    }
}

@Composable
private fun CalendarGrid(
    year: Int,
    month: Int,
    studyData: Map<Int, Long>,
    maxStudyMinutes: Long,
    selectedDate: Date?,
    onDateSelect: (Date) -> Unit
) {
    val calendar = Calendar.getInstance()
    calendar.set(year, month - 1, 1)
    
    val firstDayOfWeek = calendar.get(Calendar.DAY_OF_WEEK) - 1
    val daysInMonth = calendar.getActualMaximum(Calendar.DAY_OF_MONTH)
    val totalCells = firstDayOfWeek + daysInMonth
    val weekRows = ceil(totalCells / 7f).toInt()
    
    val weekDays = listOf("日", "月", "火", "水", "木", "金", "土")
    
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .testTag("calendar_grid")
    ) {
        Row(modifier = Modifier.fillMaxWidth()) {
            weekDays.forEach { day ->
                Text(
                    text = day,
                    modifier = Modifier
                        .weight(1f)
                        .padding(8.dp),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
        
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp)
        ) {
            for (row in 0 until weekRows) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    for (col in 0 until 7) {
                        val cellIndex = row * 7 + col
                        val dayNumber = cellIndex - firstDayOfWeek + 1
                        
                        if (cellIndex < firstDayOfWeek || dayNumber > daysInMonth) {
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .aspectRatio(1f)
                            )
                        } else {
                            val studyMinutes = studyData[dayNumber] ?: 0L
                            val isSelected = selectedDate?.let {
                                val cal = Calendar.getInstance()
                                cal.time = it
                                cal.get(Calendar.YEAR) == year &&
                                    cal.get(Calendar.MONTH) == month - 1 &&
                                    cal.get(Calendar.DAY_OF_MONTH) == dayNumber
                            } ?: false
                            
                            val isToday = run {
                                val today = Calendar.getInstance()
                                today.get(Calendar.YEAR) == year &&
                                    today.get(Calendar.MONTH) == month - 1 &&
                                    today.get(Calendar.DAY_OF_MONTH) == dayNumber
                            }
                            
                            Box(modifier = Modifier.weight(1f)) {
                                DayCell(
                                    day = dayNumber,
                                    studyMinutes = studyMinutes,
                                    maxStudyMinutes = maxStudyMinutes,
                                    isSelected = isSelected,
                                    isToday = isToday,
                                    onClick = {
                                        val cal = Calendar.getInstance()
                                        cal.set(year, month - 1, dayNumber)
                                        onDateSelect(cal.time)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }

        HeatmapLegend(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 12.dp),
            maxStudyMinutes = maxStudyMinutes
        )
    }
}

@Composable
private fun DayCell(
    day: Int,
    studyMinutes: Long,
    maxStudyMinutes: Long,
    isSelected: Boolean,
    isToday: Boolean,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(6.dp)
    val level = heatmapLevel(studyMinutes = studyMinutes, maxStudyMinutes = maxStudyMinutes)
    val heatmapColor = heatmapCellColor(level)
    val outlineColor = when {
        isSelected -> MaterialTheme.colorScheme.primary
        isToday -> MaterialTheme.colorScheme.outline
        else -> Color.Transparent
    }
    val textColor = when {
        isSelected -> MaterialTheme.colorScheme.onPrimary
        level >= 3 -> Color.White
        studyMinutes > 0 -> MaterialTheme.colorScheme.onSurface
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    
    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .padding(3.dp)
            .testTag("calendar_day_$day")
            .clip(shape)
            .background(if (isSelected) MaterialTheme.colorScheme.primary else heatmapColor)
            .border(
                width = if (isSelected || isToday) 2.dp else 1.dp,
                color = if (isSelected || isToday) outlineColor else MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
                shape = shape
            )
            .clickable(onClick = onClick)
    ) {
        Text(
            text = day.toString(),
            color = textColor,
            fontSize = 12.sp,
            fontWeight = if (isToday || isSelected) FontWeight.Bold else FontWeight.Medium,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 6.dp, top = 5.dp)
        )
    }
}

@Composable
private fun HeatmapLegend(
    modifier: Modifier = Modifier,
    maxStudyMinutes: Long
) {
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.End,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "少",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        Spacer(modifier = Modifier.width(8.dp))
        (0..4).forEach { level ->
            Box(
                modifier = Modifier
                    .padding(horizontal = 2.dp)
                    .size(12.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(heatmapCellColor(if (maxStudyMinutes == 0L) 0 else level))
                    .border(
                        width = 1.dp,
                        color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.45f),
                        shape = RoundedCornerShape(3.dp)
                    )
            )
        }
        Spacer(modifier = Modifier.width(8.dp))
        Text(
            text = "多",
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
}

@Composable
private fun heatmapCellColor(level: Int): Color {
    val palette = listOf(
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f),
        Color(0xFFDDEEDB),
        Color(0xFF9BD58A),
        Color(0xFF5AAD5A),
        Color(0xFF2E7D32)
    )
    return palette[level.coerceIn(0, palette.lastIndex)]
}

private fun heatmapLevel(studyMinutes: Long, maxStudyMinutes: Long): Int {
    if (studyMinutes <= 0 || maxStudyMinutes <= 0) return 0
    val ratio = studyMinutes.toFloat() / maxStudyMinutes.toFloat()
    return when {
        ratio >= 0.75f -> 4
        ratio >= 0.5f -> 3
        ratio >= 0.25f -> 2
        else -> 1
    }
}

@Composable
private fun DayDetailPanel(
    date: Date,
    sessions: List<StudySession>,
    totalMinutes: Long,
    isLoading: Boolean,
    updatingSessionId: Long?,
    onEditMemo: (StudySession) -> Unit,
    modifier: Modifier = Modifier
) {
    val dateFormat = remember { SimpleDateFormat("M月d日 (E)", Locale.JAPANESE) }

    LazyColumn(
        modifier = modifier.fillMaxWidth(),
        contentPadding = PaddingValues(start = 16.dp, end = 16.dp, top = 8.dp, bottom = 16.dp),
        verticalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        item(key = "header") {
            DayDetailHeader(
                dateText = dateFormat.format(date),
                totalMinutes = totalMinutes,
                sessionCount = sessions.size
            )
        }

        when {
            isLoading -> {
                item(key = "loading") {
                    Box(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(vertical = 32.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(28.dp),
                            strokeWidth = 3.dp
                        )
                    }
                }
            }
            sessions.isEmpty() -> {
                item(key = "empty") {
                    EmptySessionsPlaceholder()
                }
            }
            else -> {
                items(sessions, key = { it.id }) { session ->
                    SessionCard(
                        session = session,
                        isUpdating = updatingSessionId == session.id,
                        onEditMemo = { onEditMemo(session) }
                    )
                }
            }
        }
    }
}

@Composable
private fun DayDetailHeader(
    dateText: String,
    totalMinutes: Long,
    sessionCount: Int
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = dateText,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(10.dp))

        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
            SummaryChip(
                label = "学習時間",
                value = formatDurationCompact(totalMinutes),
                containerColor = MaterialTheme.colorScheme.primaryContainer,
                contentColor = MaterialTheme.colorScheme.onPrimaryContainer
            )
            SummaryChip(
                label = "セッション",
                value = "${sessionCount}回",
                containerColor = MaterialTheme.colorScheme.secondaryContainer,
                contentColor = MaterialTheme.colorScheme.onSecondaryContainer
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(top = 12.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )
    }
}

@Composable
private fun SummaryChip(
    label: String,
    value: String,
    containerColor: Color,
    contentColor: Color
) {
    Surface(
        shape = RoundedCornerShape(12.dp),
        color = containerColor
    ) {
        Column(modifier = Modifier.padding(horizontal = 16.dp, vertical = 8.dp)) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = contentColor.copy(alpha = 0.7f)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold,
                color = contentColor
            )
        }
    }
}

@Composable
private fun EmptySessionsPlaceholder() {
    Card(
        modifier = Modifier.fillMaxWidth(),
        colors = CardDefaults.cardColors(
            containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.4f)
        ),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 32.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text("📚", fontSize = 36.sp)
            Spacer(modifier = Modifier.height(10.dp))
            Text(
                text = "この日の記録はありません",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Spacer(modifier = Modifier.height(2.dp))
            Text(
                text = "タイマーから学習を記録しましょう",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
            )
        }
    }
}

@Composable
private fun SessionCard(
    session: StudySession,
    isUpdating: Boolean,
    onEditMemo: () -> Unit
) {
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    val startText = remember(session.startTime) { timeFormat.format(Date(session.startTime)) }
    val endText = remember(session.endTime) { timeFormat.format(Date(session.endTime)) }

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = session.subjectName.ifEmpty { "未設定" },
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f, fill = false)
                )

                Spacer(modifier = Modifier.width(8.dp))

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Text(
                        text = formatDurationCompact(session.durationMinutes),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                    )
                }
            }

            if (session.materialName.isNotEmpty()) {
                Text(
                    text = session.materialName,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(top = 2.dp)
                )
            }

            Text(
                text = "$startText – $endText",
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 4.dp)
            )

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 10.dp),
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(enabled = !isUpdating, onClick = onEditMemo)
                    .padding(4.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                if (isUpdating) {
                    CircularProgressIndicator(
                        modifier = Modifier.size(16.dp),
                        strokeWidth = 2.dp
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(
                        text = "保存中…",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                } else {
                    val hasNote = !session.note.isNullOrBlank()
                    Text(
                        text = if (hasNote) session.note!! else "メモはまだありません",
                        style = MaterialTheme.typography.bodySmall,
                        color = if (hasNote)
                            MaterialTheme.colorScheme.onSurface
                        else
                            MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f),
                        maxLines = 3,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f)
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Icon(
                        imageVector = Icons.Default.Edit,
                        contentDescription = "メモを編集",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MemoEditBottomSheet(
    session: StudySession,
    isUpdating: Boolean,
    onSave: (StudySession, String) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var memoText by remember(session.id) { mutableStateOf(session.note ?: "") }
    var hasSaved by remember { mutableStateOf(false) }

    LaunchedEffect(isUpdating, hasSaved) {
        if (hasSaved && !isUpdating) {
            onDismiss()
        }
    }

    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    val timeRange = remember(session.startTime, session.endTime) {
        "${timeFormat.format(Date(session.startTime))} – ${timeFormat.format(Date(session.endTime))}"
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
        ) {
            Text(
                text = "メモを編集",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = buildString {
                    append(session.subjectName.ifEmpty { "未設定" })
                    if (session.materialName.isNotEmpty()) append(" · ${session.materialName}")
                },
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = timeRange,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            Spacer(modifier = Modifier.height(20.dp))

            OutlinedTextField(
                value = memoText,
                onValueChange = { memoText = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 120.dp),
                placeholder = { Text("学習の振り返りやメモを入力…") },
                shape = RoundedCornerShape(12.dp),
                enabled = !isUpdating,
                maxLines = 8
            )

            Spacer(modifier = Modifier.height(20.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = onDismiss,
                    modifier = Modifier.weight(1f),
                    enabled = !isUpdating,
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("キャンセル")
                }
                Button(
                    onClick = {
                        onSave(session, memoText)
                        hasSaved = true
                    },
                    modifier = Modifier.weight(1f),
                    enabled = !isUpdating,
                    shape = RoundedCornerShape(12.dp)
                ) {
                    if (isUpdating) {
                        CircularProgressIndicator(
                            modifier = Modifier.size(18.dp),
                            strokeWidth = 2.dp,
                            color = MaterialTheme.colorScheme.onPrimary
                        )
                    } else {
                        Text("保存")
                    }
                }
            }
        }
    }
}

private fun formatDurationCompact(minutes: Long): String {
    val h = minutes / 60
    val m = minutes % 60
    return when {
        h > 0 && m > 0 -> "${h}時間${m}分"
        h > 0 -> "${h}時間"
        else -> "${m}分"
    }
}
