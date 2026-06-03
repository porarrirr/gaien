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
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.GridView
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
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
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemChapter
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemReviewRating
import com.studyapp.domain.model.ProblemReviewRecord
import com.studyapp.domain.model.StudySession
import com.studyapp.presentation.components.EmptyState
import com.studyapp.presentation.components.LoadingState
import com.studyapp.presentation.theme.toSubjectColor
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
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    item {
                        MaterialHistorySummary(uiState)
                    }
                    item {
                        MaterialDetailTabSelector(
                            selectedTab = selectedTab,
                            onSelectTab = { selectedTab = it }
                        )
                    }
                    if (selectedTab == 0) {
                        item {
                            MaterialHistoryListSection(
                                sessions = uiState.sessions,
                                chapters = uiState.material?.problemChapters ?: emptyList()
                            )
                        }
                    } else {
                        item {
                            ProblemProgressSection(
                                material = uiState.material,
                                sessions = uiState.sessions,
                                reviewRecords = uiState.problemReviewRecords
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
    val subjectColor = (material.color ?: uiState.subject?.color ?: 0x1DBBE8).toSubjectColor()
    val answerRate = remember(material, uiState.sessions, uiState.problemReviewRecords) {
        calculateMaterialAnswerRate(
            material = material,
            sessions = uiState.sessions,
            reviewRecords = uiState.problemReviewRecords
        )
    }

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.Top
        ) {
            MaterialBookCover(
                material = material,
                modifier = Modifier.size(width = 64.dp, height = 90.dp)
            )

            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(11.dp)
                            .clip(CircleShape)
                            .background(subjectColor)
                    )
                    Text(
                        text = uiState.subject?.name ?: "科目未設定",
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                Text(
                    text = material.name,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis
                )

                Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                    Row(modifier = Modifier.fillMaxWidth()) {
                        Text(
                            text = "正誤率",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                        Spacer(modifier = Modifier.weight(1f))
                        Text(
                            text = "$answerRate%",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        LinearProgressIndicator(
                            progress = { answerRate / 100f },
                            modifier = Modifier
                                .weight(1f)
                                .height(4.dp)
                                .clip(RoundedCornerShape(2.dp)),
                            color = Color(0xFF1E88E5),
                            trackColor = MaterialTheme.colorScheme.surfaceVariant
                        )
                        Text(
                            text = "$answerRate%",
                            style = MaterialTheme.typography.labelMedium,
                            color = MaterialTheme.colorScheme.onSurface
                        )
                    }
                }

                Row(modifier = Modifier.fillMaxWidth()) {
                    Text(
                        text = "問題数（合計）",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    Text(
                        text = "${material.effectiveTotalProblems}問",
                        style = MaterialTheme.typography.labelMedium,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                }
            }
        }
    }
}

@Composable
private fun MaterialDetailTabSelector(
    selectedTab: Int,
    onSelectTab: (Int) -> Unit
) {
    Surface(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.75f)
    ) {
        Row(modifier = Modifier.padding(3.dp), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            listOf("履歴", "問題集").forEachIndexed { index, label ->
                val selected = selectedTab == index
                Surface(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(7.dp))
                        .clickable { onSelectTab(index) },
                    shape = RoundedCornerShape(7.dp),
                    color = if (selected) MaterialTheme.colorScheme.surface else Color.Transparent,
                    tonalElevation = if (selected) 1.dp else 0.dp
                ) {
                    Text(
                        text = label,
                        modifier = Modifier.padding(vertical = 8.dp),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.labelLarge,
                        fontWeight = FontWeight.Bold,
                        color = if (selected) {
                            MaterialTheme.colorScheme.onSurface
                        } else {
                            MaterialTheme.colorScheme.onSurfaceVariant
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun MaterialHistoryListSection(
    sessions: List<StudySession>,
    chapters: List<ProblemChapter>
) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 4.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = "学習履歴",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.width(4.dp))
            Text(
                text = "（新しい順）",
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Icon(
                    Icons.Default.Edit,
                    contentDescription = null,
                    modifier = Modifier.size(18.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                Text(
                    text = "編集",
                    style = MaterialTheme.typography.titleMedium,
                    color = MaterialTheme.colorScheme.primary
                )
            }
        }

        if (sessions.isEmpty()) {
            OutlinedCard(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Text(
                    text = "記録はありません",
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 24.dp, horizontal = 16.dp),
                    textAlign = TextAlign.Center,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        } else {
            OutlinedCard(
                modifier = Modifier.fillMaxWidth(),
                shape = RoundedCornerShape(16.dp),
                colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
            ) {
                Column(modifier = Modifier.fillMaxWidth()) {
                    sessions.forEachIndexed { index, session ->
                        MaterialHistorySessionRow(session = session, chapters = chapters)
                        if (index != sessions.lastIndex) {
                            HorizontalDivider(
                                modifier = Modifier.padding(start = 22.dp),
                                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.7f)
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun MaterialHistorySessionRow(
    session: StudySession,
    chapters: List<ProblemChapter>
) {
    val dateFormat = remember { SimpleDateFormat("yyyy/M/d（E）", Locale.JAPANESE) }
    val timeFormat = remember { SimpleDateFormat("HH:mm", Locale.JAPANESE) }
    val dateText = remember(session.sessionStartTime) { dateFormat.format(Date(session.sessionStartTime)) }
    val timeText = remember(session.sessionStartTime, session.sessionEndTime) {
        "${timeFormat.format(Date(session.sessionStartTime))} - ${timeFormat.format(Date(session.sessionEndTime))}"
    }
    val problemNumbers = remember(session.problemRecords) {
        session.problemRecords.map { it.number }.distinct().sorted()
    }
    val problemRangeDisplay = remember(problemNumbers, session.problemRangeText) {
        val rangeText = session.problemRangeText
        when {
            problemNumbers.isNotEmpty() -> {
                val first = problemNumbers.first()
                val last = problemNumbers.last()
                if (first == last) "$first" else "$first-$last"
            }
            rangeText != null -> rangeText.replace("問", "")
            else -> "未入力"
        }
    }
    val pageRangeDisplay = remember(problemRangeDisplay) {
        if (problemRangeDisplay == "未入力") "未入力" else "p.$problemRangeDisplay"
    }
    val chapterText = remember(problemNumbers, chapters) {
        val first = problemNumbers.firstOrNull() ?: return@remember ""
        val chapter = chapters.chapterFor(first) ?: return@remember ""
        "（${chapter.title}）"
    }
    val wrongNumbersText = remember(session.problemRecords) {
        session.problemRecords
            .filter { it.result == ProblemResult.WRONG }
            .map { it.number.toString() }
            .distinct()
            .joinToString(", ")
    }
    val correctCount = remember(session.problemRecords) {
        session.problemRecords.count { it.result == ProblemResult.CORRECT }
    }
    val wrongCount = remember(session.problemRecords, session.wrongProblemCount) {
        if (session.problemRecords.isNotEmpty()) {
            session.problemRecords.count { it.result == ProblemResult.WRONG }
        } else {
            session.wrongProblemCount ?: 0
        }
    }
    val reviewCorrectCount = remember(session.problemRecords) {
        session.problemRecords.count { it.result == ProblemResult.REVIEW_CORRECT }
    }

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 12.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(7.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = dateText,
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f)
                )
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    Icon(
                        Icons.Default.Schedule,
                        contentDescription = null,
                        modifier = Modifier.size(13.dp),
                        tint = MaterialTheme.colorScheme.onSurface
                    )
                    Text(
                        text = "${session.durationMinutes}分",
                        style = MaterialTheme.typography.labelSmall,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1
                    )
                }
            }

            Text(
                text = timeText,
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )

            if ((session.rating ?: 0) > 0) {
                Row(horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                    repeat(5) { index ->
                        Icon(
                            if (index < (session.rating ?: 0)) Icons.Default.Star else Icons.Default.StarBorder,
                            contentDescription = null,
                            modifier = Modifier.size(13.dp),
                            tint = if (index < (session.rating ?: 0)) Color(0xFFF59E0B) else MaterialTheme.colorScheme.outline
                        )
                    }
                }
            }

            Text(
                text = "範囲： $pageRangeDisplay $chapterText",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Text(
                text = "問題： $problemRangeDisplay",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            if (wrongNumbersText.isNotEmpty()) {
                Text(
                    text = "不正解： $wrongNumbersText",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.error,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                text = "メモ： ${session.note?.takeIf { it.isNotBlank() } ?: "メモはありません"}",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis
            )
        }

        Row(
            modifier = Modifier.width(150.dp),
            horizontalArrangement = Arrangement.spacedBy(6.dp),
            verticalAlignment = Alignment.Top
        ) {
            MaterialHistoryCountColumn("正解", correctCount, Color(0xFF2E9D45), Modifier.weight(1f))
            MaterialHistoryCountColumn("不正解", wrongCount, MaterialTheme.colorScheme.error, Modifier.weight(1f))
            MaterialHistoryCountColumn("復習正解", reviewCorrectCount, Color(0xFFF59E0B), Modifier.weight(1f))
        }

        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            modifier = Modifier.size(16.dp),
            tint = MaterialTheme.colorScheme.outline
        )
    }
}

@Composable
private fun MaterialHistoryCountColumn(
    title: String,
    value: Int,
    color: Color,
    modifier: Modifier = Modifier
) {
    Column(
        modifier = modifier,
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelSmall,
            color = MaterialTheme.colorScheme.onSurface,
            maxLines = 1,
            overflow = TextOverflow.Clip,
            fontSize = 10.sp
        )
        Text(
            text = "$value",
            style = MaterialTheme.typography.bodyMedium,
            color = color,
            maxLines = 1
        )
    }
}

@Composable
private fun MaterialBookCover(
    material: Material,
    modifier: Modifier = Modifier
) {
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(4.dp))
            .background(
                Brush.linearGradient(
                    listOf(
                        Color(0xFFFAFAF8),
                        Color(0xFFE6EBEC),
                        Color(0xFF004257)
                    )
                )
            )
            .border(
                width = 1.dp,
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.7f),
                shape = RoundedCornerShape(4.dp)
            )
    ) {
        Box(
            modifier = Modifier
                .width(24.dp)
                .height(130.dp)
                .align(Alignment.BottomEnd)
                .background(Color(0xFFD79B21))
        )
        Box(
            modifier = Modifier
                .width(12.dp)
                .height(110.dp)
                .align(Alignment.TopEnd)
                .padding(top = 8.dp)
                .background(Color(0xFF18A8C9))
        )
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(5.dp),
            verticalArrangement = Arrangement.spacedBy(2.dp)
        ) {
            Text(
                text = "Focus Gold",
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                fontSize = 8.sp,
                color = Color.Black,
                maxLines = 1
            )
            Text(
                text = material.name.replace("Focus Gold", "").trim().ifBlank { material.name },
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.SemiBold,
                fontSize = 6.sp,
                color = Color.Black,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis
            )
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
    material: Material?,
    sessions: List<StudySession>,
    reviewRecords: List<ProblemReviewRecord>
) {
    if (material == null) return
    val totalProblems = material.effectiveTotalProblems
    if (totalProblems <= 0) {
        OutlinedCard(modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) {
            EmptyState(
                icon = Icons.Default.Book,
                title = "全問題数が未設定です",
                description = "教材編集から問題数を設定すると、ここに進捗が表示されます。",
                modifier = Modifier.padding(16.dp)
            )
        }
        return
    }

    val latestRecords = remember(material, sessions, reviewRecords) {
        buildLatestProblemRecords(material, sessions, reviewRecords)
    }

    val correctCount = latestRecords.count { it.value == ProblemResult.CORRECT }
    val wrongCount = latestRecords.count { it.value == ProblemResult.WRONG }
    val reviewCorrectCount = latestRecords.count { it.value == ProblemResult.REVIEW_CORRECT }
    val unattemptedCount = (totalProblems - latestRecords.size).coerceAtLeast(0)

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(
                    Icons.Default.GridView,
                    contentDescription = null,
                    modifier = Modifier.size(20.dp),
                    tint = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "問題集の進捗",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                MaterialProblemMetricTile("正解", "$correctCount", Color(0xFF2E9D45), Modifier.weight(1f))
                MaterialProblemMetricTile("不正解", "$wrongCount", MaterialTheme.colorScheme.error, Modifier.weight(1f))
            }
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                MaterialProblemMetricTile("復習正解", "$reviewCorrectCount", Color(0xFFF59E0B), Modifier.weight(1f))
                MaterialProblemMetricTile("未実施", "$unattemptedCount", MaterialTheme.colorScheme.onSurfaceVariant, Modifier.weight(1f))
            }

            Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth()) {
                MaterialProblemLegendItem("未着手", MaterialTheme.colorScheme.surfaceVariant, MaterialTheme.colorScheme.onSurfaceVariant, Modifier.weight(1f))
                MaterialProblemLegendItem("正解", Color(0xFF2E9D45).copy(alpha = 0.18f), Color(0xFF2E9D45), Modifier.weight(1f))
                MaterialProblemLegendItem("不正解", MaterialTheme.colorScheme.error.copy(alpha = 0.18f), MaterialTheme.colorScheme.error, Modifier.weight(1f))
                MaterialProblemLegendItem("復習正解", Color(0xFFF59E0B).copy(alpha = 0.20f), Color(0xFFF59E0B), Modifier.weight(1f))
            }

            Text(
                text = "誤答履歴を含む問題は、赤から黄緑へ寄る5段階の色で復調度を表示します。",
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            val chapters = material.problemChapters.filter { it.problemCount > 0 }
            if (chapters.isNotEmpty()) {
                var startNumber = 1
                Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                    chapters.forEach { chapter ->
                        val chapterStart = startNumber
                        startNumber += chapter.problemCount
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                Text(
                                    text = chapter.title,
                                    style = MaterialTheme.typography.labelMedium,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurface
                                )
                                Spacer(modifier = Modifier.weight(1f))
                                Text(
                                    text = "${chapter.problemCount}問",
                                    style = MaterialTheme.typography.labelSmall,
                                    fontWeight = FontWeight.Bold,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            ProblemProgressRows(
                                rows = problemRows(start = chapterStart, count = chapter.problemCount),
                                latestRecords = latestRecords,
                                chapters = material.problemChapters,
                                showsGlobalNumber = true
                            )
                        }
                    }
                }
            } else {
                ProblemProgressRows(
                    rows = problemRows(start = 1, count = totalProblems),
                    latestRecords = latestRecords,
                    chapters = emptyList(),
                    showsGlobalNumber = false
                )
            }

            val wrongNumbers = latestRecords
                .filterValues { it == ProblemResult.WRONG }
                .keys
                .sorted()
            if (wrongNumbers.isNotEmpty()) {
                Text(
                    text = "不正解: ${wrongNumbers.take(30).joinToString(", ")}${if (wrongNumbers.size > 30) " ..." else ""}",
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun ProblemProgressRows(
    rows: List<List<Int>>,
    latestRecords: Map<Int, ProblemResult>,
    chapters: List<ProblemChapter>,
    showsGlobalNumber: Boolean
) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        rows.forEach { rowNumbers ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                rowNumbers.forEach { number ->
                    val location = chapters.chapterLocation(number)
                    ProblemTile(
                        label = if (showsGlobalNumber) {
                            location?.localNumber?.toString() ?: number.toString()
                        } else {
                            number.toString()
                        },
                        result = latestRecords[number],
                        modifier = Modifier.weight(1f)
                    )
                }
                repeat((5 - rowNumbers.size).coerceAtLeast(0)) {
                    Spacer(
                        modifier = Modifier
                            .weight(1f)
                            .aspectRatio(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun MaterialProblemMetricTile(
    label: String,
    value: String,
    color: Color,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(8.dp),
        color = MaterialTheme.colorScheme.surface
    ) {
        Row(
            modifier = Modifier
                .border(1.dp, MaterialTheme.colorScheme.outlineVariant, RoundedCornerShape(8.dp))
                .padding(11.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            Box(
                modifier = Modifier
                    .size(20.dp)
                    .clip(CircleShape)
                    .background(color.copy(alpha = 0.14f)),
                contentAlignment = Alignment.Center
            ) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(color)
                )
            }
            Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1
                )
                Text(
                    text = value,
                    style = MaterialTheme.typography.bodyMedium,
                    color = color,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1
                )
            }
        }
    }
}

@Composable
private fun MaterialProblemLegendItem(
    label: String,
    color: Color,
    textColor: Color,
    modifier: Modifier = Modifier
) {
    Row(
        modifier = modifier,
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(6.dp)
    ) {
        Box(
            modifier = Modifier
                .size(14.dp)
                .clip(RoundedCornerShape(4.dp))
                .background(color)
                .border(1.dp, textColor.copy(alpha = 0.45f), RoundedCornerShape(4.dp))
        )
        Text(
            text = label,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            color = textColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
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
    label: String,
    result: ProblemResult?,
    modifier: Modifier = Modifier
) {
    val backgroundColor = when (result) {
        ProblemResult.CORRECT -> Color(0xFF2E9D45).copy(alpha = 0.18f)
        ProblemResult.WRONG -> MaterialTheme.colorScheme.error.copy(alpha = 0.18f)
        ProblemResult.REVIEW_CORRECT -> Color(0xFFF59E0B).copy(alpha = 0.20f)
        null -> MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.75f)
    }
    val textColor = when (result) {
        ProblemResult.CORRECT -> Color(0xFF2E9D45)
        ProblemResult.WRONG -> MaterialTheme.colorScheme.error
        ProblemResult.REVIEW_CORRECT -> Color(0xFFF59E0B)
        null -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Box(
        modifier = modifier
            .aspectRatio(1f)
            .clip(RoundedCornerShape(8.dp))
            .background(backgroundColor)
            .border(
                width = 1.dp,
                color = textColor.copy(alpha = 0.35f),
                shape = RoundedCornerShape(8.dp)
            ),
        contentAlignment = Alignment.Center
    ) {
        Text(
            text = label,
            color = textColor,
            fontSize = 12.sp,
            fontWeight = FontWeight.Bold,
            maxLines = 1
        )
    }
}

private data class ProblemTimelineEntry(
    val number: Int,
    val timestamp: Long,
    val result: ProblemResult
)

private fun buildLatestProblemRecords(
    material: Material,
    sessions: List<StudySession>,
    reviewRecords: List<ProblemReviewRecord>
): Map<Int, ProblemResult> {
    val totalProblems = material.effectiveTotalProblems
    if (totalProblems <= 0) return emptyMap()

    val entries = buildList {
        sessions.forEach { session ->
            session.problemRecords.forEach { record ->
                if (record.number in 1..totalProblems) {
                    add(ProblemTimelineEntry(record.number, session.sessionStartTime, record.result))
                }
            }
        }
        material.problemRecords.forEach { record ->
            if (record.number in 1..totalProblems) {
                // Material-level records are baseline sync data; material metadata edits must not make them latest.
                add(ProblemTimelineEntry(record.number, Long.MIN_VALUE, record.result))
            }
        }
        reviewRecords.forEach { record ->
            if (record.problemNumber in 1..totalProblems) {
                add(ProblemTimelineEntry(record.problemNumber, record.reviewedAt, record.rating.toProblemResult()))
            }
        }
    }

    return entries
        .sortedByDescending { it.timestamp }
        .fold(linkedMapOf<Int, ProblemResult>()) { latest, entry ->
            if (entry.number !in latest) {
                latest[entry.number] = entry.result
            }
            latest
        }
}

private fun calculateMaterialAnswerRate(
    material: Material,
    sessions: List<StudySession>,
    reviewRecords: List<ProblemReviewRecord>
): Int {
    val totalProblems = material.effectiveTotalProblems
    if (totalProblems <= 0) return 0
    val latestRecords = buildLatestProblemRecords(material, sessions, reviewRecords)
    val correct = latestRecords.values.count { it == ProblemResult.CORRECT || it == ProblemResult.REVIEW_CORRECT }
    return ((correct.toDouble() / totalProblems.toDouble()) * 100.0).toInt()
}

private fun ProblemReviewRating.toProblemResult(): ProblemResult {
    return when (this) {
        ProblemReviewRating.AGAIN -> ProblemResult.WRONG
        ProblemReviewRating.GOOD -> ProblemResult.CORRECT
    }
}

private fun problemRows(start: Int, count: Int): List<List<Int>> {
    if (count <= 0) return emptyList()
    val end = start + count - 1
    return (start..end).chunked(5)
}

private data class ChapterLocation(
    val chapter: ProblemChapter,
    val localNumber: Int
)

private fun List<ProblemChapter>.chapterFor(globalNumber: Int): ProblemChapter? {
    return chapterLocation(globalNumber)?.chapter
}

private fun List<ProblemChapter>.chapterLocation(globalNumber: Int): ChapterLocation? {
    if (globalNumber <= 0) return null
    var offset = 0
    for (chapter in this) {
        val count = chapter.problemCount.coerceAtLeast(0)
        if (count <= 0) continue
        if (globalNumber in (offset + 1)..(offset + count)) {
            return ChapterLocation(chapter = chapter, localNumber = globalNumber - offset)
        }
        offset += count
    }
    return null
}
