package com.studyapp.presentation.calendar

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
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
import com.studyapp.domain.model.StudySessionType
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.presentation.calendar.TimelineItem

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
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
        ) {
            item(key = "header") {
                CalendarHeader(
                    year = uiState.currentYear,
                    month = uiState.currentMonth,
                    onPrevious = { viewModel.previousMonth() },
                    onNext = { viewModel.nextMonth() }
                )
            }

            item(key = "grid") {
                CalendarGrid(
                    year = uiState.currentYear,
                    month = uiState.currentMonth,
                    studyData = uiState.studyDataByDate,
                    maxStudyMinutes = uiState.studyDataByDate.values.maxOrNull() ?: 0L,
                    selectedDate = uiState.selectedDate,
                    onDateSelect = { viewModel.selectDate(it) }
                )
            }

            if (uiState.selectedDate != null) {
                if (uiState.selectedDateSessions.isNotEmpty()) {
                    item(key = "detail_mode_toggle") {
                        DetailModeToggle(
                            currentMode = uiState.detailMode,
                            onModeChange = { viewModel.setDetailMode(it) }
                        )
                    }
                }

                item(key = "day_detail") {
                    DayDetailPanel(
                        date = uiState.selectedDate!!,
                        sessions = uiState.selectedDateSessions,
                        timeline = uiState.selectedDateTimeline,
                        totalMinutes = uiState.selectedDateMinutes,
                        isLoading = uiState.isDetailLoading,
                        updatingSessionId = uiState.updatingSessionId,
                        detailMode = uiState.detailMode,
                        onEditSession = { session -> editingSession = session },
                        onDeleteSession = { session -> viewModel.deleteSession(session) },
                        modifier = Modifier.fillMaxWidth()
                    )
                }
            }

            item(key = "monthly_summary") {
                MonthlySummarySection(
                    month = uiState.currentMonth,
                    daysInMonth = daysInMonth(uiState.currentYear, uiState.currentMonth),
                    totalMinutes = uiState.monthlyTotalMinutes,
                    studyDays = uiState.monthlyStudyDays,
                    averageRating = uiState.monthlyAverageRating
                )
            }

            item(key = "bottom_spacer") {
                Spacer(modifier = Modifier.height(16.dp))
            }
        }
    }

    if (editingSession != null) {
        SessionEditBottomSheet(
            session = editingSession!!,
            isUpdating = uiState.updatingSessionId == editingSession!!.id,
            onSave = { session -> viewModel.updateSession(session) },
            onDelete = { session ->
                viewModel.deleteSession(session)
                editingSession = null
            },
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
            text = String.format(Locale.JAPANESE, "%d年 %s", year, monthNames[month - 1]),
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
            weekDays.forEachIndexed { index, day ->
                val textColor = when (index) {
                    0 -> Color(0xFFE53935) // Sunday = red
                    6 -> Color(0xFF1E88E5) // Saturday = blue
                    else -> MaterialTheme.colorScheme.onSurfaceVariant
                }
                Text(
                    text = day,
                    modifier = Modifier
                        .weight(1f)
                        .padding(8.dp),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodySmall,
                    color = textColor
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
private fun MonthlySummarySection(
    month: Int,
    daysInMonth: Int,
    totalMinutes: Long,
    studyDays: Int,
    averageRating: Double?
) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier.padding(12.dp),
            verticalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "${month}月のまとめ",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = "(1〜${daysInMonth}日)",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                MonthlyStatCard(
                    title = "合計学習時間",
                    value = formatDurationCompact(totalMinutes),
                    modifier = Modifier.weight(1f)
                )
                MonthlyStatCard(
                    title = "学習日数",
                    value = "${studyDays}日",
                    modifier = Modifier.weight(1f)
                )
                MonthlyStatCard(
                    title = "平均評価（5段階）",
                    value = averageRating?.let { String.format(Locale.JAPANESE, "%.1f", it) } ?: "-",
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }
}

@Composable
private fun MonthlyStatCard(
    title: String,
    value: String,
    modifier: Modifier = Modifier
) {
    OutlinedCard(
        modifier = modifier.defaultMinSize(minHeight = 78.dp),
        shape = RoundedCornerShape(8.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
            Text(
                text = value,
                fontSize = 25.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.Center
            )
        }
    }
}

private fun daysInMonth(year: Int, month: Int): Int {
    return Calendar.getInstance().run {
        set(year, month - 1, 1)
        getActualMaximum(Calendar.DAY_OF_MONTH)
    }
}

@Composable
private fun DetailModeToggle(
    currentMode: CalendarDetailMode,
    onModeChange: (CalendarDetailMode) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        FilterChip(
            selected = currentMode == CalendarDetailMode.SUMMARY,
            onClick = { onModeChange(CalendarDetailMode.SUMMARY) },
            label = { Text("まとめ") },
            shape = RoundedCornerShape(20.dp)
        )
        FilterChip(
            selected = currentMode == CalendarDetailMode.TIMELINE,
            onClick = { onModeChange(CalendarDetailMode.TIMELINE) },
            label = { Text("時系列") },
            shape = RoundedCornerShape(20.dp)
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
    timeline: List<TimelineItem>,
    totalMinutes: Long,
    isLoading: Boolean,
    updatingSessionId: Long?,
    detailMode: CalendarDetailMode,
    onEditSession: (StudySession) -> Unit,
    onDeleteSession: (StudySession) -> Unit,
    modifier: Modifier = Modifier
) {
    val dateFormat = remember { SimpleDateFormat("M月d日 (E)", Locale.JAPANESE) }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
    ) {
        DayDetailHeader(
            dateText = dateFormat.format(date),
            totalMinutes = totalMinutes,
            sessionCount = sessions.size
        )

        Spacer(modifier = Modifier.height(12.dp))

        when {
            isLoading -> {
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
            sessions.isEmpty() && timeline.isEmpty() -> {
                EmptySessionsPlaceholder()
            }
            detailMode == CalendarDetailMode.SUMMARY -> {
                SummaryModeContent(
                    sessions = sessions,
                    onEditSession = onEditSession
                )
            }
            else -> {
                TimelineModeContent(
                    sessions = sessions,
                    timeline = timeline,
                    updatingSessionId = updatingSessionId,
                    onEditSession = onEditSession
                )
            }
        }
    }
}

@Composable
private fun SummaryModeContent(
    sessions: List<StudySession>,
    onEditSession: (StudySession) -> Unit
) {
    data class SubjectGroup(
        val subjectName: String,
        val materialName: String,
        val sessions: List<StudySession>
    ) {
        val totalMinutes: Long get() = sessions.sumOf { it.durationMinutes.toLong() }
        val totalCount: Int get() = sessions.size
        val intervals: List<String>
            get() = sessions.flatMap { session ->
                session.effectiveIntervals.map { interval ->
                    val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())
                    "${timeFormat.format(Date(interval.startTime))}~${timeFormat.format(Date(interval.endTime))}"
                }
            }
        val notes: List<String> get() = sessions.mapNotNull { it.note?.takeIf { n -> n.isNotBlank() } }
        val problemRange: String?
            get() = sessions.firstNotNullOfOrNull { it.problemRangeText }
        val wrongCount: Int?
            get() = sessions.sumOf { it.effectiveWrongProblemCount ?: 0 }.takeIf { it > 0 }
    }

    val grouped = sessions
        .groupBy { "${it.subjectName}_${it.materialName}" }
        .map { (_, group) ->
            SubjectGroup(
                subjectName = group.first().subjectName.ifEmpty { "未設定" },
                materialName = group.first().materialName,
                sessions = group
            )
        }
        .sortedByDescending { it.totalMinutes }

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        grouped.forEach { group ->
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
                            text = group.subjectName,
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
                                text = formatDurationCompact(group.totalMinutes),
                                style = MaterialTheme.typography.labelMedium,
                                fontWeight = FontWeight.SemiBold,
                                color = MaterialTheme.colorScheme.onPrimaryContainer,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                            )
                        }
                    }

                    if (group.materialName.isNotEmpty()) {
                        Text(
                            text = group.materialName,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier.padding(top = 2.dp)
                        )
                    }

                    Row(
                        modifier = Modifier.padding(top = 4.dp),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text(
                            text = "${group.totalCount}回",
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        group.problemRange?.let { range ->
                            Text(
                                text = range,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        group.wrongCount?.let { count ->
                            Text(
                                text = "✗${count}",
                                style = MaterialTheme.typography.bodySmall,
                                color = Color(0xFFE53935)
                            )
                        }
                    }

                    if (group.notes.isNotEmpty()) {
                        HorizontalDivider(
                            modifier = Modifier.padding(vertical = 8.dp),
                            color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
                        )
                        group.notes.forEach { note ->
                            Text(
                                text = note,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurface,
                                maxLines = 2,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(bottom = 4.dp)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TimelineModeContent(
    sessions: List<StudySession>,
    timeline: List<TimelineItem>,
    updatingSessionId: Long?,
    onEditSession: (StudySession) -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
        if (timeline.isNotEmpty()) {
            timeline.forEach { item ->
                when (item) {
                    is TimelineItem.Lesson -> {
                        TimelineLessonCard(entry = item.entry, period = item.period)
                    }
                    is TimelineItem.Session -> {
                        SessionCard(
                            session = item.session,
                            isUpdating = updatingSessionId == item.session.id,
                            onEdit = { onEditSession(item.session) }
                        )
                    }
                    is TimelineItem.Gap -> {
                        TimelineGapItem(startMinute = item.startMinute, endMinute = item.endMinute)
                    }
                }
            }
        } else {
            sessions.forEach { session ->
                SessionCard(
                    session = session,
                    isUpdating = updatingSessionId == session.id,
                    onEdit = { onEditSession(session) }
                )
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
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = dateText,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = "合計 ${formatDurationCompact(totalMinutes)} ・ ${sessionCount}セッション",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
        }

        HorizontalDivider(
            modifier = Modifier.padding(top = 12.dp),
            color = MaterialTheme.colorScheme.outlineVariant
        )
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
            Icon(
                Icons.Default.Book,
                contentDescription = null,
                modifier = Modifier.size(36.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.45f)
            )
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
    onEdit: () -> Unit
) {
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    val intervalTexts = remember(session.effectiveIntervals) {
        session.effectiveIntervals.map { interval ->
            "${timeFormat.format(Date(interval.startTime))}~${timeFormat.format(Date(interval.endTime))}"
        }
    }

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

                SessionTypeChip(session.sessionType)

                Spacer(modifier = Modifier.width(8.dp))

                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Text(
                        text = formatDurationCompact(session.durationMinutes.toLong()),
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

            Row(
                modifier = Modifier.padding(top = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column(
                    verticalArrangement = Arrangement.spacedBy(2.dp)
                ) {
                    intervalTexts.forEach { intervalText ->
                        Text(
                            text = intervalText,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                Spacer(modifier = Modifier.weight(1f))

                if (session.rating != null && session.rating > 0) {
                    RatingBadge(rating = session.rating)
                }
            }

            val problemRange = session.problemRangeText
            val wrongCount = session.effectiveWrongProblemCount
            if (problemRange != null || (wrongCount != null && wrongCount > 0)) {
                Row(
                    modifier = Modifier.padding(top = 4.dp),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    if (problemRange != null) {
                        Text(
                            text = problemRange,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    if (wrongCount != null && wrongCount > 0) {
                        Text(
                            text = "✗${wrongCount}",
                            style = MaterialTheme.typography.bodySmall,
                            color = Color(0xFFE53935)
                        )
                    }
                }
            }

            HorizontalDivider(
                modifier = Modifier.padding(vertical = 10.dp),
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f)
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(enabled = !isUpdating, onClick = onEdit)
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
                        contentDescription = "編集",
                        modifier = Modifier.size(16.dp),
                        tint = MaterialTheme.colorScheme.primary
                    )
                }
            }
        }
    }
}

@Composable
private fun RatingBadge(rating: Int) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(1.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        (1..5).forEach { star ->
            Icon(
                imageVector = if (star <= rating) Icons.Default.Star else Icons.Default.StarBorder,
                contentDescription = null,
                modifier = Modifier.size(14.dp),
                tint = if (star <= rating) Color(0xFFFFB300) else MaterialTheme.colorScheme.outlineVariant
            )
        }
    }
}

@Composable
private fun SessionTypeChip(sessionType: StudySessionType) {
    val (label, containerColor, contentColor) = when (sessionType) {
        StudySessionType.STOPWATCH -> Triple(
            "ストップウォッチ",
            MaterialTheme.colorScheme.tertiaryContainer,
            MaterialTheme.colorScheme.onTertiaryContainer
        )
        StudySessionType.TIMER -> Triple(
            "タイマー",
            MaterialTheme.colorScheme.secondaryContainer,
            MaterialTheme.colorScheme.onSecondaryContainer
        )
        StudySessionType.MANUAL -> Triple(
            "手動",
            MaterialTheme.colorScheme.surfaceVariant,
            MaterialTheme.colorScheme.onSurfaceVariant
        )
    }
    Surface(
        shape = RoundedCornerShape(8.dp),
        color = containerColor
    ) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = contentColor,
            modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SessionEditBottomSheet(
    session: StudySession,
    isUpdating: Boolean,
    onSave: (StudySession) -> Unit,
    onDelete: (StudySession) -> Unit,
    onDismiss: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var rating by remember(session.id) { mutableStateOf(session.rating ?: 0) }
    var problemStart by remember(session.id) { mutableStateOf(session.problemStart?.toString() ?: "") }
    var problemEnd by remember(session.id) { mutableStateOf(session.problemEnd?.toString() ?: "") }
    var wrongCount by remember(session.id) { mutableStateOf(session.wrongProblemCount?.toString() ?: "") }
    var noteText by remember(session.id) { mutableStateOf(session.note ?: "") }
    var hasSaved by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }

    LaunchedEffect(isUpdating, hasSaved) {
        if (hasSaved && !isUpdating) {
            onDismiss()
        }
    }

    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.getDefault()) }
    val timeRange = remember(session.effectiveIntervals) {
        session.effectiveIntervals.joinToString(separator = "\n") { interval ->
            "${timeFormat.format(Date(interval.startTime))}~${timeFormat.format(Date(interval.endTime))}"
        }
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
                text = "セッションを編集",
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

            Text(
                text = "評価",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                (1..5).forEach { star ->
                    IconButton(
                        onClick = { rating = if (rating == star) 0 else star },
                        modifier = Modifier.size(40.dp)
                    ) {
                        Icon(
                            imageVector = if (star <= rating) Icons.Default.Star else Icons.Default.StarBorder,
                            contentDescription = "評価 $star",
                            tint = if (star <= rating) Color(0xFFFFB300) else MaterialTheme.colorScheme.outlineVariant,
                            modifier = Modifier.size(32.dp)
                        )
                    }
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "問題記録",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium
            )
            Spacer(modifier = Modifier.height(8.dp))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedTextField(
                    value = problemStart,
                    onValueChange = { problemStart = it.filter { c -> c.isDigit() } },
                    modifier = Modifier.weight(1f),
                    label = { Text("開始") },
                    placeholder = { Text("1") },
                    shape = RoundedCornerShape(12.dp),
                    enabled = !isUpdating,
                    singleLine = true
                )
                OutlinedTextField(
                    value = problemEnd,
                    onValueChange = { problemEnd = it.filter { c -> c.isDigit() } },
                    modifier = Modifier.weight(1f),
                    label = { Text("終了") },
                    placeholder = { Text("10") },
                    shape = RoundedCornerShape(12.dp),
                    enabled = !isUpdating,
                    singleLine = true
                )
                OutlinedTextField(
                    value = wrongCount,
                    onValueChange = { wrongCount = it.filter { c -> c.isDigit() } },
                    modifier = Modifier.weight(1f),
                    label = { Text("不正解") },
                    placeholder = { Text("0") },
                    shape = RoundedCornerShape(12.dp),
                    enabled = !isUpdating,
                    singleLine = true
                )
            }

            Spacer(modifier = Modifier.height(16.dp))

            Text(
                text = "メモ",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Medium
            )
            Spacer(modifier = Modifier.height(8.dp))
            OutlinedTextField(
                value = noteText,
                onValueChange = { noteText = it },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 100.dp),
                placeholder = { Text("学習の振り返りやメモを入力…") },
                shape = RoundedCornerShape(12.dp),
                enabled = !isUpdating,
                maxLines = 6
            )

            Spacer(modifier = Modifier.height(24.dp))

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = { showDeleteConfirm = true },
                    modifier = Modifier.weight(1f),
                    enabled = !isUpdating,
                    shape = RoundedCornerShape(12.dp),
                    colors = ButtonDefaults.outlinedButtonColors(
                        contentColor = Color(0xFFE53935)
                    )
                ) {
                    Icon(
                        imageVector = Icons.Default.Delete,
                        contentDescription = null,
                        modifier = Modifier.size(18.dp)
                    )
                    Spacer(modifier = Modifier.width(4.dp))
                    Text("削除")
                }
                Button(
                    onClick = {
                        val updatedSession = session.copy(
                            rating = rating.takeIf { it > 0 },
                            problemStart = problemStart.toIntOrNull(),
                            problemEnd = problemEnd.toIntOrNull(),
                            wrongProblemCount = wrongCount.toIntOrNull(),
                            note = noteText.trim().takeIf { it.isNotEmpty() }
                        )
                        onSave(updatedSession)
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

    if (showDeleteConfirm) {
        AlertDialog(
            onDismissRequest = { showDeleteConfirm = false },
            title = { Text("セッションを削除") },
            text = { Text("この学習記録を削除しますか？この操作は取り消せません。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showDeleteConfirm = false
                        onDelete(session)
                    },
                    colors = ButtonDefaults.textButtonColors(
                        contentColor = Color(0xFFE53935)
                    )
                ) {
                    Text("削除")
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

private fun formatDurationCompact(minutes: Long): String {
    val h = minutes / 60
    val m = minutes % 60
    return when {
        h > 0 && m > 0 -> "${h}時間${m}分"
        h > 0 -> "${h}時間"
        else -> "${m}分"
    }
}

@Composable
private fun TimelineLessonCard(
    entry: com.studyapp.domain.model.TimetableEntry,
    period: com.studyapp.domain.model.TimetablePeriod
) {
    val timeFormat = remember { java.text.SimpleDateFormat("HH:mm", Locale.getDefault()) }

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(40.dp)
                    .clip(RoundedCornerShape(2.dp))
                    .background(MaterialTheme.colorScheme.secondary)
            )

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = entry.subjectName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = period.name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = "${TimetablePeriod.timeText(period.startMinute)}-${TimetablePeriod.timeText(period.endMinute)}",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    entry.roomName?.takeIf { it.isNotBlank() }?.let { room ->
                        Text(
                            text = room,
                            style = MaterialTheme.typography.bodySmall,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            }

            Surface(
                shape = RoundedCornerShape(8.dp),
                color = MaterialTheme.colorScheme.secondaryContainer
            ) {
                Text(
                    text = "授業",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSecondaryContainer,
                    modifier = Modifier.padding(horizontal = 10.dp, vertical = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun TimelineGapItem(startMinute: Int, endMinute: Int) {
    val duration = endMinute - startMinute
    if (duration <= 0) return

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 2.dp, horizontal = 16.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            modifier = Modifier
                .width(4.dp)
                .height(16.dp)
                .clip(RoundedCornerShape(2.dp))
                .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.4f))
        )
        Spacer(modifier = Modifier.width(12.dp))
        Text(
            text = "${formatDurationCompact(duration.toLong())} の空き時間",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.6f)
        )
    }
}
