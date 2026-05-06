package com.studyapp.presentation.timetable

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
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
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableTerm
import java.time.LocalDate
import java.time.format.DateTimeFormatter

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimetableScreen(
    viewModel: TimetableViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var isShowingPeriodSettings by remember { mutableStateOf(false) }
    var isShowingTermEditor by remember { mutableStateOf(false) }
    var isCreatingTerm by remember { mutableStateOf(false) }
    var editingSlot by remember { mutableStateOf<Pair<StudyWeekday, TimetablePeriod>?>(null) }
    var reviewEditorOccurrence by remember { mutableStateOf<TimetableReviewOccurrence?>(null) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "時間割",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    IconButton(onClick = {
                        isCreatingTerm = true
                        isShowingTermEditor = true
                    }) {
                        Icon(
                            Icons.Default.CalendarMonth,
                            contentDescription = "学期設定",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                    IconButton(onClick = { isShowingPeriodSettings = true }) {
                        Icon(
                            Icons.Default.Schedule,
                            contentDescription = "時限設定",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
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
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(paddingValues),
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                item {
                    TermOverviewCard(
                        terms = uiState.terms,
                        selectedTerm = uiState.terms.find { it.id == uiState.selectedTermId },
                        termSummary = uiState.termSummary,
                        onSelectTerm = viewModel::selectTerm,
                        onCreateTerm = {
                            isCreatingTerm = true
                            isShowingTermEditor = true
                        }
                    )
                }

                item {
                    ReviewCalendarCard(
                        selectedDate = uiState.selectedDate,
                        selectedTerm = uiState.terms.find { it.id == uiState.selectedTermId },
                        onDateSelect = viewModel::selectDate
                    )
                }

                if (uiState.selectedDateOccurrences.isNotEmpty()) {
                    item {
                        SelectedDateLessonsCard(
                            date = uiState.selectedDate,
                            occurrences = uiState.selectedDateOccurrences,
                            onOccurrenceClick = { reviewEditorOccurrence = it }
                        )
                    }
                }

                item {
                    TimetableGridCard(
                        periods = uiState.periods,
                        entriesBySlot = uiState.entriesBySlot,
                        onCellClick = { weekday, period ->
                            editingSlot = Pair(weekday, period)
                        }
                    )
                }
            }
        }
    }

    if (isShowingPeriodSettings) {
        PeriodSettingsDialog(
            periods = uiState.periods,
            onDismiss = { isShowingPeriodSettings = false },
            onSave = { periods ->
                viewModel.savePeriods(periods)
                isShowingPeriodSettings = false
            }
        )
    }

    if (isShowingTermEditor) {
        TermEditorDialog(
            term = if (isCreatingTerm) null else uiState.terms.find { it.id == uiState.selectedTermId },
            onDismiss = {
                isShowingTermEditor = false
                isCreatingTerm = false
            },
            onSave = { term ->
                viewModel.saveTerm(term)
                isShowingTermEditor = false
                isCreatingTerm = false
            }
        )
    }

    editingSlot?.let { (weekday, period) ->
        val existingEntry = uiState.entriesBySlot[Pair(weekday, period.id)]
        EntryEditorDialog(
            weekday = weekday,
            period = period,
            existingEntry = existingEntry,
            onDismiss = { editingSlot = null },
            onSave = { entry ->
                viewModel.saveEntry(entry)
                editingSlot = null
            },
            onDelete = existingEntry?.let { entry ->
                {
                    viewModel.deleteEntry(entry)
                    editingSlot = null
                }
            }
        )
    }

    reviewEditorOccurrence?.let { occurrence ->
        ReviewEditorDialog(
            occurrence = occurrence,
            onDismiss = { reviewEditorOccurrence = null },
            onReviewed = { note ->
                viewModel.setReviewed(occurrence, reviewed = true, note = note)
                reviewEditorOccurrence = null
            },
            onUnreviewed = {
                viewModel.setReviewed(occurrence, reviewed = false, note = null)
                reviewEditorOccurrence = null
            },
            onExclude = {
                viewModel.setExcluded(occurrence, excluded = true)
                reviewEditorOccurrence = null
            },
            onRestore = {
                viewModel.setExcluded(occurrence, excluded = false)
                reviewEditorOccurrence = null
            }
        )
    }
}

@Composable
private fun TermOverviewCard(
    terms: List<TimetableTerm>,
    selectedTerm: TimetableTerm?,
    termSummary: TimetableReviewSummary,
    onSelectTerm: (TimetableTerm) -> Unit,
    onCreateTerm: () -> Unit
) {
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
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = selectedTerm?.name ?: "学期未設定",
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = selectedTerm?.dateRangeText ?: "学期を設定してください",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (terms.size > 1) {
                        var expanded by remember { mutableStateOf(false) }
                        Box {
                            OutlinedButton(onClick = { expanded = true }) {
                                Text("切替")
                                Icon(Icons.Default.ArrowDropDown, contentDescription = null)
                            }
                            DropdownMenu(
                                expanded = expanded,
                                onDismissRequest = { expanded = false }
                            ) {
                                terms.forEach { term ->
                                    DropdownMenuItem(
                                        text = { Text(term.name) },
                                        onClick = {
                                            onSelectTerm(term)
                                            expanded = false
                                        }
                                    )
                                }
                            }
                        }
                    }
                    OutlinedButton(onClick = onCreateTerm) {
                        Icon(Icons.Default.Add, contentDescription = null)
                        Spacer(modifier = Modifier.width(4.dp))
                        Text("追加")
                    }
                }
            }

            if (selectedTerm != null) {
                LinearProgressIndicator(
                    progress = { termSummary.completionRate },
                    modifier = Modifier.fillMaxWidth(),
                    color = if (termSummary.pending > 0) MaterialTheme.colorScheme.error
                    else MaterialTheme.colorScheme.primary,
                )

                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    SummaryBadge(
                        label = "復習済み",
                        value = termSummary.reviewed,
                        color = Color(0xFF4CAF50),
                        modifier = Modifier.weight(1f)
                    )
                    SummaryBadge(
                        label = "未復習",
                        value = termSummary.pending,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.weight(1f)
                    )
                    SummaryBadge(
                        label = "対象外",
                        value = termSummary.excluded,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.weight(1f)
                    )
                }
            }
        }
    }
}

@Composable
private fun SummaryBadge(
    label: String,
    value: Int,
    color: Color,
    modifier: Modifier = Modifier
) {
    Surface(
        modifier = modifier,
        shape = RoundedCornerShape(8.dp),
        color = color.copy(alpha = 0.1f)
    ) {
        Column(
            modifier = Modifier.padding(8.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = "$value",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                color = color
            )
            Text(
                text = label,
                style = MaterialTheme.typography.labelSmall,
                color = color.copy(alpha = 0.8f)
            )
        }
    }
}

@Composable
private fun ReviewCalendarCard(
    selectedDate: LocalDate,
    selectedTerm: TimetableTerm?,
    onDateSelect: (LocalDate) -> Unit
) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp)
        ) {
            val monthNames = listOf(
                "1月", "2月", "3月", "4月", "5月", "6月",
                "7月", "8月", "9月", "10月", "11月", "12月"
            )
            var displayMonth by remember { mutableStateOf(selectedDate.withDayOfMonth(1)) }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                IconButton(onClick = { displayMonth = displayMonth.minusMonths(1) }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "前月")
                }
                Text(
                    text = "${displayMonth.year}年 ${monthNames[displayMonth.monthValue - 1]}",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                IconButton(onClick = { displayMonth = displayMonth.plusMonths(1) }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowForward, contentDescription = "翌月")
                }
            }

            Spacer(modifier = Modifier.height(8.dp))

            val weekDays = listOf("月", "火", "水", "木", "金", "土")
            Row(modifier = Modifier.fillMaxWidth()) {
                weekDays.forEach { day ->
                    Text(
                        text = day,
                        modifier = Modifier.weight(1f),
                        textAlign = TextAlign.Center,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            Spacer(modifier = Modifier.height(4.dp))

            val firstDay = displayMonth.withDayOfMonth(1)
            val daysInMonth = displayMonth.lengthOfMonth()
            val firstDayOfWeek = firstDay.dayOfWeek.value // 1=Monday
            val startOffset = firstDayOfWeek - 1 // 0-based from Monday

            val totalCells = startOffset + daysInMonth
            val rows = (totalCells + 5) / 6

            for (row in 0 until rows) {
                Row(modifier = Modifier.fillMaxWidth()) {
                    for (col in 0 until 6) {
                        val cellIndex = row * 6 + col
                        val dayNumber = cellIndex - startOffset + 1

                        if (cellIndex < startOffset || dayNumber > daysInMonth) {
                            Spacer(modifier = Modifier.weight(1f))
                        } else {
                            val date = displayMonth.withDayOfMonth(dayNumber)
                            val isSelected = date == selectedDate
                            val isToday = date == LocalDate.now()
                            val isInTerm = selectedTerm?.contains(date) ?: false

                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .aspectRatio(1f)
                                    .padding(2.dp)
                                    .clip(RoundedCornerShape(6.dp))
                                    .background(
                                        when {
                                            isSelected -> MaterialTheme.colorScheme.primary
                                            isInTerm -> MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.3f)
                                            else -> Color.Transparent
                                        }
                                    )
                                    .border(
                                        width = if (isToday && !isSelected) 1.dp else 0.dp,
                                        color = if (isToday && !isSelected) MaterialTheme.colorScheme.outline else Color.Transparent,
                                        shape = RoundedCornerShape(6.dp)
                                    )
                                    .clickable { onDateSelect(date) },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = "$dayNumber",
                                    fontSize = 13.sp,
                                    fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Normal,
                                    color = when {
                                        isSelected -> MaterialTheme.colorScheme.onPrimary
                                        isInTerm -> MaterialTheme.colorScheme.onSurface
                                        else -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.5f)
                                    }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun SelectedDateLessonsCard(
    date: LocalDate,
    occurrences: List<TimetableReviewOccurrence>,
    onOccurrenceClick: (TimetableReviewOccurrence) -> Unit
) {
    val dateFormat = remember { DateTimeFormatter.ofPattern("M月d日 (E)", java.util.Locale.JAPANESE) }

    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            Text(
                text = dateFormat.format(date),
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )

            occurrences.forEach { occurrence ->
                ReviewOccurrenceRow(
                    occurrence = occurrence,
                    onClick = { onOccurrenceClick(occurrence) }
                )
            }
        }
    }
}

@Composable
private fun ReviewOccurrenceRow(
    occurrence: TimetableReviewOccurrence,
    onClick: () -> Unit
) {
    val statusColor = when {
        occurrence.isReviewed -> Color(0xFF4CAF50)
        occurrence.isExcluded -> MaterialTheme.colorScheme.onSurfaceVariant
        occurrence.isOverdue -> MaterialTheme.colorScheme.error
        else -> MaterialTheme.colorScheme.primary
    }
    val statusLabel = when {
        occurrence.isReviewed -> "復習済み"
        occurrence.isExcluded -> "対象外"
        occurrence.isOverdue -> "期限切れ"
        else -> "未復習"
    }

    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
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
                    .background(statusColor)
            )

            Spacer(modifier = Modifier.width(12.dp))

            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = occurrence.entry.subjectName,
                    style = MaterialTheme.typography.titleSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text(
                        text = occurrence.period.name,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    Text(
                        text = occurrence.period.timeRangeText,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                    occurrence.entry.roomName?.takeIf { it.isNotBlank() }?.let { room ->
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
                color = statusColor.copy(alpha = 0.1f)
            ) {
                Text(
                    text = statusLabel,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.SemiBold,
                    color = statusColor,
                    modifier = Modifier.padding(horizontal = 8.dp, vertical = 4.dp)
                )
            }
        }
    }
}

@Composable
private fun TimetableGridCard(
    periods: List<TimetablePeriod>,
    entriesBySlot: Map<Pair<StudyWeekday, Long>, TimetableEntry>,
    onCellClick: (StudyWeekday, TimetablePeriod) -> Unit
) {
    val timetableDays = listOf(
        StudyWeekday.MONDAY to "月",
        StudyWeekday.TUESDAY to "火",
        StudyWeekday.WEDNESDAY to "水",
        StudyWeekday.THURSDAY to "木",
        StudyWeekday.FRIDAY to "金",
        StudyWeekday.SATURDAY to "土"
    )
    val sortedPeriods = periods.sortedBy { it.sortOrder }

    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(8.dp)
        ) {
            Text(
                text = "時間割グリッド",
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.padding(8.dp)
            )

            Row(modifier = Modifier.horizontalScroll(rememberScrollState())) {
                Column {
                    Row {
                        Box(
                            modifier = Modifier.width(88.dp).height(36.dp),
                            contentAlignment = Alignment.Center
                        ) {}
                        timetableDays.forEach { (_, dayLabel) ->
                            Box(
                                modifier = Modifier.width(80.dp).height(36.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(
                                    text = dayLabel,
                                    style = MaterialTheme.typography.labelMedium,
                                    fontWeight = FontWeight.Bold
                                )
                            }
                        }
                    }

                    sortedPeriods.forEach { period ->
                        Row {
                            Box(
                                modifier = Modifier
                                    .width(88.dp)
                                    .height(56.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                                    Text(
                                        text = period.name,
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.Bold
                                    )
                                    Text(
                                        text = period.timeRangeText,
                                        style = MaterialTheme.typography.labelSmall,
                                        fontSize = 8.sp,
                                        color = MaterialTheme.colorScheme.onSurfaceVariant
                                    )
                                }
                            }
                            timetableDays.forEach { (weekday, _) ->
                                val entry = entriesBySlot[Pair(weekday, period.id)]
                                TimetableGridCell(
                                    entry = entry,
                                    onClick = { onCellClick(weekday, period) }
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun TimetableGridCell(
    entry: TimetableEntry?,
    onClick: () -> Unit
) {
    val cellColor = if (entry != null) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.5f)
    } else {
        MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f)
    }

    Box(
        modifier = Modifier
            .width(80.dp)
            .height(56.dp)
            .padding(1.dp)
            .clip(RoundedCornerShape(4.dp))
            .background(cellColor)
            .border(
                width = 0.5.dp,
                color = MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.5f),
                shape = RoundedCornerShape(4.dp)
            )
            .clickable(onClick = onClick)
            .padding(4.dp),
        contentAlignment = Alignment.Center
    ) {
        if (entry != null) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    text = entry.subjectName,
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center
                )
                entry.roomName?.takeIf { it.isNotBlank() }?.let { room ->
                    Text(
                        text = room,
                        style = MaterialTheme.typography.labelSmall,
                        fontSize = 9.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
        } else {
            Icon(
                Icons.Default.Add,
                contentDescription = "追加",
                modifier = Modifier.size(16.dp),
                tint = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.3f)
            )
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun EntryEditorDialog(
    weekday: StudyWeekday,
    period: TimetablePeriod,
    existingEntry: TimetableEntry?,
    onDismiss: () -> Unit,
    onSave: (TimetableEntry) -> Unit,
    onDelete: (() -> Unit)?
) {
    var subjectName by remember { mutableStateOf(existingEntry?.subjectName ?: "") }
    var courseName by remember { mutableStateOf(existingEntry?.courseName ?: "") }
    var roomName by remember { mutableStateOf(existingEntry?.roomName ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Text("${weekday.japaneseTitle} ${period.name}")
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = subjectName,
                    onValueChange = { subjectName = it },
                    label = { Text("科目名") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = courseName,
                    onValueChange = { courseName = it },
                    label = { Text("講座名（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                OutlinedTextField(
                    value = roomName,
                    onValueChange = { roomName = it },
                    label = { Text("教室（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (subjectName.isNotBlank()) {
                        val now = System.currentTimeMillis()
                        val entry = (existingEntry ?: TimetableEntry(
                            id = 0,
                            syncId = java.util.UUID.randomUUID().toString().lowercase(),
                            dayOfWeek = weekday,
                            periodId = period.id,
                            subjectName = subjectName.trim(),
                            createdAt = now
                        )).copy(
                            subjectName = subjectName.trim(),
                            courseName = courseName.trim().takeIf { it.isNotEmpty() },
                            roomName = roomName.trim().takeIf { it.isNotEmpty() },
                            updatedAt = now
                        )
                        onSave(entry)
                    }
                },
                enabled = subjectName.isNotBlank()
            ) {
                Text("保存")
            }
        },
        dismissButton = {
            Row {
                if (onDelete != null) {
                    TextButton(
                        onClick = onDelete,
                        colors = ButtonDefaults.textButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Text("削除")
                    }
                }
                TextButton(onClick = onDismiss) {
                    Text("キャンセル")
                }
            }
        }
    )
}

@Composable
private fun TermEditorDialog(
    term: TimetableTerm?,
    onDismiss: () -> Unit,
    onSave: (TimetableTerm) -> Unit
) {
    val isEditing = term != null
    var name by remember { mutableStateOf(term?.name ?: "") }
    var startDate by remember { mutableStateOf(term?.startDateValue ?: LocalDate.now()) }
    var endDate by remember { mutableStateOf(term?.endDateValue ?: LocalDate.now().plusMonths(5)) }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(if (isEditing) "学期を編集" else "学期を作成") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    label = { Text("学期名") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                Text(
                    text = "開始: ${startDate.format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))}",
                    style = MaterialTheme.typography.bodyMedium
                )
                Text(
                    text = "終了: ${endDate.format(DateTimeFormatter.ofPattern("yyyy/MM/dd"))}",
                    style = MaterialTheme.typography.bodyMedium
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedButton(onClick = { startDate = startDate.minusWeeks(1) }) {
                        Text("開始 -1週")
                    }
                    OutlinedButton(onClick = { endDate = endDate.plusWeeks(1) }) {
                        Text("終了 +1週")
                    }
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = {
                    if (name.isNotBlank()) {
                        val now = System.currentTimeMillis()
                        val termData = (term ?: TimetableTerm(
                            id = 0,
                            syncId = java.util.UUID.randomUUID().toString().lowercase(),
                            name = name.trim(),
                            startDate = startDate.toEpochDay(),
                            endDate = endDate.toEpochDay(),
                            isActive = true,
                            createdAt = now
                        )).copy(
                            name = name.trim(),
                            startDate = startDate.toEpochDay(),
                            endDate = endDate.toEpochDay(),
                            updatedAt = now
                        )
                        onSave(termData)
                    }
                },
                enabled = name.isNotBlank()
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

@Composable
private fun PeriodSettingsDialog(
    periods: List<TimetablePeriod>,
    onDismiss: () -> Unit,
    onSave: (List<TimetablePeriod>) -> Unit
) {
    var drafts by remember {
        mutableStateOf(
            periods.sortedBy { it.sortOrder }.map { period ->
                PeriodDraft(
                    id = period.id,
                    syncId = period.syncId,
                    name = period.name,
                    startText = String.format("%02d:%02d", period.startMinute / 60, period.startMinute % 60),
                    endText = String.format("%02d:%02d", period.endMinute / 60, period.endMinute % 60),
                    sortOrder = period.sortOrder,
                    isActive = period.isActive,
                    createdAt = period.createdAt
                )
            }
        )
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("時限設定") },
        text = {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.heightIn(max = 400.dp)
            ) {
                items(drafts.size) { index ->
                    val draft = drafts[index]
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text(
                            text = draft.name,
                            style = MaterialTheme.typography.labelMedium,
                            modifier = Modifier.width(32.dp)
                        )
                        OutlinedTextField(
                            value = draft.startText,
                            onValueChange = { newStart ->
                                drafts = drafts.toMutableList().apply {
                                    set(index, draft.copy(startText = newStart))
                                }
                            },
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                            textStyle = MaterialTheme.typography.bodySmall
                        )
                        Text("-", style = MaterialTheme.typography.bodySmall)
                        OutlinedTextField(
                            value = draft.endText,
                            onValueChange = { newEnd ->
                                drafts = drafts.toMutableList().apply {
                                    set(index, draft.copy(endText = newEnd))
                                }
                            },
                            modifier = Modifier.weight(1f),
                            singleLine = true,
                            textStyle = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = {
                val periods = drafts.map { draft ->
                    val startParts = draft.startText.split(":")
                    val endParts = draft.endText.split(":")
                    val startMinute = (startParts.getOrNull(0)?.toIntOrNull() ?: 0) * 60 +
                                     (startParts.getOrNull(1)?.toIntOrNull() ?: 0)
                    val endMinute = (endParts.getOrNull(0)?.toIntOrNull() ?: 0) * 60 +
                                   (endParts.getOrNull(1)?.toIntOrNull() ?: 0)
                    TimetablePeriod(
                        id = draft.id,
                        syncId = draft.syncId,
                        name = draft.name,
                        startMinute = startMinute,
                        endMinute = endMinute,
                        sortOrder = draft.sortOrder,
                        isActive = draft.isActive,
                        createdAt = draft.createdAt,
                        updatedAt = System.currentTimeMillis()
                    )
                }
                onSave(periods)
            }) {
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

private data class PeriodDraft(
    val id: Long,
    val syncId: String,
    val name: String,
    val startText: String,
    val endText: String,
    val sortOrder: Int,
    val isActive: Boolean,
    val createdAt: Long
)

@Composable
private fun ReviewEditorDialog(
    occurrence: TimetableReviewOccurrence,
    onDismiss: () -> Unit,
    onReviewed: (String?) -> Unit,
    onUnreviewed: () -> Unit,
    onExclude: () -> Unit,
    onRestore: () -> Unit
) {
    var note by remember { mutableStateOf(occurrence.note ?: "") }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Column {
                Text(occurrence.entry.subjectName)
                Text(
                    text = "${occurrence.period.name} ${occurrence.period.timeRangeText}",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                OutlinedTextField(
                    value = note,
                    onValueChange = { note = it },
                    label = { Text("メモ（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    maxLines = 3
                )

                if (occurrence.isExcluded) {
                    Text(
                        text = "この授業は対象外に設定されています",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        },
        confirmButton = {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                if (occurrence.isExcluded) {
                    TextButton(onClick = onRestore) {
                        Text("復元")
                    }
                } else {
                    if (occurrence.isReviewed) {
                        TextButton(onClick = onUnreviewed) {
                            Text("未復習に戻す")
                        }
                    }
                    TextButton(onClick = { onReviewed(note.takeIf { it.isNotBlank() }) }) {
                        Text(if (occurrence.isReviewed) "更新" else "復習済み")
                    }
                    if (!occurrence.isReviewed) {
                        TextButton(
                            onClick = onExclude,
                            colors = ButtonDefaults.textButtonColors(
                                contentColor = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        ) {
                            Text("対象外")
                        }
                    }
                }
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}
