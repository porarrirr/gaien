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
import androidx.compose.material.icons.filled.Star
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
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
import com.studyapp.domain.model.ProblemResult
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
                var selectedTab by remember { mutableIntStateOf(0) }
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
                        Row(
                            modifier = Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(8.dp)
                        ) {
                            FilterChip(
                                selected = selectedTab == 0,
                                onClick = { selectedTab = 0 },
                                label = { Text("履歴") }
                            )
                            FilterChip(
                                selected = selectedTab == 1,
                                onClick = { selectedTab = 1 },
                                label = { Text("問題集") }
                            )
                        }
                    }
                    if (selectedTab == 0) {
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
                        item {
                            DateJumpButtons { days ->
                                viewModel.selectDate(uiState.selectedDate.plusDays(days))
                            }
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
                    } else {
                        item {
                            ProblemProgressSection(
                                material = uiState.material,
                                sessions = uiState.sessions
                            )
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
                    progress = { material.progress.toFloat().coerceIn(0f, 1f) },
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
private fun DateJumpButtons(onJump: (Long) -> Unit) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        OutlinedButton(
            onClick = { onJump(-1) },
            modifier = Modifier.weight(1f)
        ) {
            Text("前日", style = MaterialTheme.typography.labelMedium)
        }
        OutlinedButton(
            onClick = { onJump(-7) },
            modifier = Modifier.weight(1f)
        ) {
            Text("1週間前", style = MaterialTheme.typography.labelMedium)
        }
        OutlinedButton(
            onClick = { onJump(-30) },
            modifier = Modifier.weight(1f)
        ) {
            Text("1か月前", style = MaterialTheme.typography.labelMedium)
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
                        text = formatDuration(session.durationMinutes.toLong()),
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

            val problemText = session.problemRangeText
            if (!problemText.isNullOrBlank()) {
                Text(
                    text = "問題: $problemText",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            val wrongCount = session.effectiveWrongProblemCount
            if (wrongCount != null && wrongCount > 0) {
                Text(
                    text = "不正解: $wrongCount",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.error
                )
            }
            if (session.rating != null && session.rating > 0) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    repeat(session.rating) {
                        Icon(
                            Icons.Default.Star,
                            contentDescription = null,
                            modifier = Modifier.size(14.dp),
                            tint = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
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

@Composable
private fun ProblemProgressSection(
    material: com.studyapp.domain.model.Material?,
    sessions: List<StudySession>
) {
    if (material == null) return
    val totalProblems = material.effectiveTotalProblems
    if (totalProblems <= 0) {
        OutlinedCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
            Text(
                text = "問題数が設定されていません",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(24.dp)
            )
        }
        return
    }

    val latestRecords = remember(material, sessions) {
        buildLatestProblemRecords(material, sessions)
    }

    val correctCount = latestRecords.count { it.value == ProblemResult.CORRECT }
    val wrongCount = latestRecords.count { it.value == ProblemResult.WRONG }
    val reviewCorrectCount = latestRecords.count { it.value == ProblemResult.REVIEW_CORRECT }
    val unattemptedCount = totalProblems - latestRecords.size

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
            Text(
                text = "問題集",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                ProblemStatPill(
                    label = "正解",
                    value = "$correctCount",
                    color = Color(0xFF4CAF50),
                    modifier = Modifier.weight(1f)
                )
                ProblemStatPill(
                    label = "不正解",
                    value = "$wrongCount",
                    color = Color(0xFFE53935),
                    modifier = Modifier.weight(1f)
                )
                ProblemStatPill(
                    label = "復習正解",
                    value = "$reviewCorrectCount",
                    color = Color(0xFF2196F3),
                    modifier = Modifier.weight(1f)
                )
                ProblemStatPill(
                    label = "未着手",
                    value = "$unattemptedCount",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.weight(1f)
                )
            }

            HorizontalDivider(color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.6f))

            Text(
                text = "問題一覧",
                style = MaterialTheme.typography.titleSmall,
                fontWeight = FontWeight.Bold
            )

            val columns = 6
            val rows = (totalProblems + columns - 1) / columns
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                for (row in 0 until rows) {
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(4.dp)
                    ) {
                        for (col in 0 until columns) {
                            val problemNum = row * columns + col + 1
                            if (problemNum <= totalProblems) {
                                val result = latestRecords[problemNum]
                                ProblemTile(
                                    number = problemNum,
                                    result = result,
                                    modifier = Modifier.weight(1f)
                                )
                            } else {
                                Spacer(modifier = Modifier.weight(1f))
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ProblemStatPill(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(10.dp),
        color = color.copy(alpha = 0.12f)
    ) {
        Column(
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 6.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = color.copy(alpha = 0.8f)
            )
            Text(
                text = value,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = color
            )
        }
    }
}

@Composable
private fun ProblemTile(
    number: Int,
    result: ProblemResult?,
    modifier: Modifier = Modifier
) {
    val backgroundColor = when (result) {
        ProblemResult.CORRECT -> Color(0xFF4CAF50)
        ProblemResult.WRONG -> Color(0xFFE53935)
        ProblemResult.REVIEW_CORRECT -> Color(0xFF2196F3)
        null -> MaterialTheme.colorScheme.surfaceVariant
    }
    val textColor = if (result != null) Color.White else MaterialTheme.colorScheme.onSurfaceVariant

    Box(
        modifier = modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(6.dp))
            .background(backgroundColor)
            .border(
                width = 1.dp,
                color = backgroundColor.copy(alpha = 0.5f),
                shape = RoundedCornerShape(6.dp)
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = "$number",
            color = textColor,
            fontSize = 11.sp,
            fontWeight = FontWeight.Medium
        )
    }
}

private fun buildLatestProblemRecords(
    material: com.studyapp.domain.model.Material,
    sessions: List<StudySession>
): Map<Int, ProblemResult> {
    val records = mutableMapOf<Int, ProblemResult>()
    val sortedSessions = sessions.sortedByDescending { it.startTime }
    for (session in sortedSessions) {
        for (record in session.problemRecords) {
            if (record.number !in records) {
                records[record.number] = record.result
            }
        }
        for (record in material.problemRecords) {
            if (record.number !in records) {
                records[record.number] = record.result
            }
        }
    }
    return records
}
