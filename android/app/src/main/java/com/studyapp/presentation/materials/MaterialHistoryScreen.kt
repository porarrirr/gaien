package com.studyapp.presentation.materials

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Book
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.StudySession
import com.studyapp.presentation.components.EmptyState
import com.studyapp.presentation.components.LoadingState
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.YearMonth
import java.util.Date
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MaterialHistoryScreen(
    onNavigateBack: () -> Unit,
    viewModel: MaterialHistoryViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }

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
                        text = uiState.material?.name ?: "教材の履歴",
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                        fontWeight = FontWeight.Bold
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onNavigateBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "戻る")
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                )
            )
        },
        snackbarHost = { SnackbarHost(snackbarHostState) }
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                LoadingState(
                    modifier = Modifier.padding(paddingValues),
                    message = "読み込み中"
                )
            }
            uiState.material == null -> {
                EmptyState(
                    icon = Icons.Default.Book,
                    title = "教材が見つかりません",
                    description = "教材一覧からもう一度選択してください",
                    modifier = Modifier.padding(paddingValues)
                )
            }
            else -> {
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    item {
                        MaterialHistorySummary(uiState)
                    }
                    item {
                        MaterialHistoryCalendar(
                            displayedMonth = uiState.displayedMonth,
                            selectedDate = uiState.selectedDate,
                            studyMinutesByDay = uiState.studyMinutesByDay,
                            onPrevious = viewModel::previousMonth,
                            onNext = viewModel::nextMonth,
                            onDateSelect = viewModel::selectDate
                        )
                    }
                    item {
                        SelectedDateHeader(
                            selectedDate = uiState.selectedDate,
                            totalMinutes = uiState.selectedDateMinutes,
                            sessionCount = uiState.selectedDateSessions.size
                        )
                    }
                    if (uiState.selectedDateSessions.isEmpty()) {
                        item {
                            EmptySelectedDateCard()
                        }
                    } else {
                        items(uiState.selectedDateSessions, key = { it.id }) { session ->
                            MaterialSessionCard(session = session)
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MaterialHistorySummary(uiState: MaterialHistoryUiState) {
    val material = uiState.material ?: return
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                Text(
                    text = material.name,
                    style = MaterialTheme.typography.titleLarge,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = uiState.subject?.name ?: "科目未設定",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (material.totalPages > 0) {
                LinearProgressIndicator(
                    progress = { material.progress.coerceIn(0f, 1f) },
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(8.dp)
                        .clip(RoundedCornerShape(4.dp))
                )
                Text(
                    text = "${material.currentPage}/${material.totalPages}ページ ・ ${material.progressPercent}%",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                SummaryPill(label = "累計", value = formatDuration(uiState.totalMinutes))
                SummaryPill(label = "記録", value = "${uiState.sessions.size}回")
                SummaryPill(label = "最終", value = uiState.latestStudyDate?.formatJapaneseDate() ?: "なし")
            }
        }
    }
}

@Composable
private fun SummaryPill(label: String, value: String) {
    Surface(
        shape = RoundedCornerShape(10.dp),
        color = MaterialTheme.colorScheme.primaryContainer
    ) {
        Column(modifier = Modifier.padding(horizontal = 12.dp, vertical = 8.dp)) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onPrimaryContainer.copy(alpha = 0.75f)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onPrimaryContainer
            )
        }
    }
}

@Composable
private fun MaterialHistoryCalendar(
    displayedMonth: YearMonth,
    selectedDate: LocalDate,
    studyMinutesByDay: Map<Int, Long>,
    onPrevious: () -> Unit,
    onNext: () -> Unit,
    onDateSelect: (LocalDate) -> Unit
) {
    OutlinedCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
        Column(modifier = Modifier.padding(12.dp)) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = onPrevious) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "前月")
                }
                Text(
                    text = "${displayedMonth.year}年 ${displayedMonth.monthValue}月",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                IconButton(onClick = onNext) {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "翌月")
                }
            }

            val weekDays = listOf("日", "月", "火", "水", "木", "金", "土")
            Row(modifier = Modifier.fillMaxWidth()) {
                weekDays.forEach { day ->
                    Text(
                        text = day,
                        modifier = Modifier
                            .weight(1f)
                            .padding(vertical = 6.dp),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            val firstDayOffset = displayedMonth.atDay(1).dayOfWeek.value % 7
            val daysInMonth = displayedMonth.lengthOfMonth()
            val totalCells = firstDayOffset + daysInMonth
            val rows = ((totalCells + 6) / 7).coerceAtLeast(1)
            val maxMinutes = studyMinutesByDay.values.maxOrNull() ?: 0L

            Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                for (row in 0 until rows) {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        for (column in 0 until 7) {
                            val cellIndex = row * 7 + column
                            val day = cellIndex - firstDayOffset + 1
                            Box(modifier = Modifier.weight(1f)) {
                                if (day in 1..daysInMonth) {
                                    MaterialHistoryDayCell(
                                        date = displayedMonth.atDay(day),
                                        minutes = studyMinutesByDay[day] ?: 0,
                                        maxMinutes = maxMinutes,
                                        isSelected = displayedMonth.atDay(day) == selectedDate,
                                        onClick = { onDateSelect(displayedMonth.atDay(day)) }
                                    )
                                } else {
                                    Spacer(modifier = Modifier.aspectRatio(1f))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MaterialHistoryDayCell(
    date: LocalDate,
    minutes: Long,
    maxMinutes: Long,
    isSelected: Boolean,
    onClick: () -> Unit
) {
    val shape = RoundedCornerShape(8.dp)
    val level = heatmapLevel(minutes, maxMinutes)
    val background = if (isSelected) {
        MaterialTheme.colorScheme.primary
    } else {
        heatmapColor(level)
    }
    val textColor = when {
        isSelected -> MaterialTheme.colorScheme.onPrimary
        level >= 3 -> Color.White
        else -> MaterialTheme.colorScheme.onSurface
    }

    Box(
        modifier = Modifier
            .aspectRatio(1f)
            .padding(3.dp)
            .clip(shape)
            .background(background)
            .border(
                width = if (isSelected) 2.dp else 1.dp,
                color = if (isSelected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.outlineVariant,
                shape = shape
            )
            .clickable(onClick = onClick)
    ) {
        Text(
            text = date.dayOfMonth.toString(),
            color = textColor,
            fontSize = 12.sp,
            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
            modifier = Modifier
                .align(Alignment.TopStart)
                .padding(start = 6.dp, top = 5.dp)
        )
        if (minutes > 0) {
            Text(
                text = "${minutes}分",
                color = textColor,
                fontSize = 10.sp,
                maxLines = 1,
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 5.dp)
            )
        }
    }
}

@Composable
private fun SelectedDateHeader(
    selectedDate: LocalDate,
    totalMinutes: Long,
    sessionCount: Int
) {
    Column(modifier = Modifier.fillMaxWidth()) {
        Text(
            text = selectedDate.formatJapaneseDate(),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(4.dp))
        Text(
            text = "合計 ${formatDuration(totalMinutes)} ・ ${sessionCount}回",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
        HorizontalDivider(modifier = Modifier.padding(top = 10.dp))
    }
}

@Composable
private fun EmptySelectedDateCard() {
    OutlinedCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
        Text(
            text = "この日の記録はありません",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier
                .fillMaxWidth()
                .padding(24.dp)
        )
    }
}

@Composable
private fun MaterialSessionCard(session: StudySession) {
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.JAPANESE) }
    val intervalText = remember(session.effectiveIntervals) {
        session.effectiveIntervals.joinToString(separator = "\n") { interval ->
            "${timeFormat.format(Date(interval.startTime))} - ${timeFormat.format(Date(interval.endTime))}"
        }
    }

    OutlinedCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(14.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.Top
            ) {
                Text(
                    text = intervalText,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Surface(
                    shape = RoundedCornerShape(8.dp),
                    color = MaterialTheme.colorScheme.primaryContainer
                ) {
                    Text(
                        text = formatDuration(session.durationMinutes),
                        style = MaterialTheme.typography.labelMedium,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onPrimaryContainer,
                        modifier = Modifier.padding(horizontal = 10.dp, vertical = 5.dp)
                    )
                }
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))

            Text(
                text = session.note?.takeIf { it.isNotBlank() } ?: "メモはありません",
                style = MaterialTheme.typography.bodyMedium,
                color = if (session.note.isNullOrBlank()) {
                    MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.7f)
                } else {
                    MaterialTheme.colorScheme.onSurface
                }
            )
        }
    }
}

private fun heatmapLevel(minutes: Long, maxMinutes: Long): Int {
    if (minutes <= 0 || maxMinutes <= 0) return 0
    val ratio = minutes.toFloat() / maxMinutes.toFloat()
    return when {
        ratio >= 0.75f -> 4
        ratio >= 0.5f -> 3
        ratio >= 0.25f -> 2
        else -> 1
    }
}

private fun heatmapColor(level: Int): Color {
    return when (level.coerceIn(0, 4)) {
        1 -> Color(0xFFDDEEDB)
        2 -> Color(0xFF9BD58A)
        3 -> Color(0xFF5AAD5A)
        4 -> Color(0xFF2E7D32)
        else -> Color(0x00000000)
    }
}

private fun formatDuration(minutes: Long): String {
    val hours = minutes / 60
    val remainingMinutes = minutes % 60
    return when {
        hours > 0 && remainingMinutes > 0 -> "${hours}時間${remainingMinutes}分"
        hours > 0 -> "${hours}時間"
        else -> "${remainingMinutes}分"
    }
}

private fun LocalDate.formatJapaneseDate(): String {
    return "${monthValue}月${dayOfMonth}日"
}
