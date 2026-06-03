package com.studyapp.presentation.exams

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Description
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Event
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import com.studyapp.domain.model.Exam
import com.studyapp.presentation.components.EmptyState
import java.time.LocalDate
import java.time.YearMonth
import java.time.format.DateTimeFormatter
import java.util.Locale

private val ExamListDateFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("yyyy/M/d（E）", Locale.JAPANESE)
private val ExamEditorDateFormatter: DateTimeFormatter =
    DateTimeFormatter.ofPattern("yyyy年 M月 d日（E）", Locale.JAPANESE)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExamsScreen(
    viewModel: ExamsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var showAddSheet by remember { mutableStateOf(false) }
    var editingExam by remember { mutableStateOf<Exam?>(null) }

    LaunchedEffect(uiState.error) {
        val message = uiState.error ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(message)
        viewModel.clearError()
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "試験",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    IconButton(onClick = { showAddSheet = true }) {
                        Icon(
                            imageVector = Icons.Default.Add,
                            contentDescription = "テストを追加",
                            tint = MaterialTheme.colorScheme.primary,
                            modifier = Modifier.size(29.dp)
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        if (uiState.exams.isEmpty()) {
            EmptyState(
                icon = Icons.Default.Description,
                title = "テストがありません",
                description = "右上の＋ボタンからテストを追加してください。",
                actionLabel = "テストを追加",
                onAction = { showAddSheet = true },
                modifier = Modifier.padding(paddingValues)
            )
        } else {
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .background(MaterialTheme.colorScheme.background)
                    .padding(paddingValues),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
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

    if (showAddSheet) {
        AddEditExamSheet(
            title = "テストを追加",
            onDismiss = { showAddSheet = false },
            onConfirm = { name, date, note ->
                viewModel.addExam(name, date, note)
                showAddSheet = false
            }
        )
    }

    editingExam?.let { exam ->
        AddEditExamSheet(
            title = "テストを編集",
            exam = exam,
            onDismiss = { editingExam = null },
            onConfirm = { name, date, note ->
                viewModel.updateExam(
                    exam.copy(
                        name = name,
                        date = date.toEpochDay(),
                        note = note
                    )
                )
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
    var showMenu by remember { mutableStateOf(false) }
    var showDeleteConfirm by remember { mutableStateOf(false) }
    val daysRemaining = exam.daysRemaining(LocalDate.now())
    val badgeColor = if (daysRemaining < 0) Color(0xFFFF3B30) else Color(0xFFFF9500)

    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 84.dp),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(start = 16.dp, end = 13.dp, top = 14.dp, bottom = 14.dp),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top
        ) {
            Column(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                Text(
                    text = exam.name,
                    fontSize = 21.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )

                Row(
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.CalendarMonth,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(19.dp)
                    )
                    Text(
                        text = exam.dateValue.format(ExamListDateFormatter),
                        fontSize = 18.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }

                if (!exam.note.isNullOrBlank()) {
                    Text(
                        text = exam.note,
                        fontSize = 17.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }

            Row(
                horizontalArrangement = Arrangement.spacedBy(16.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = examBadgeText(daysRemaining),
                    fontSize = 16.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                    maxLines = 1,
                    modifier = Modifier
                        .clip(RoundedCornerShape(8.dp))
                        .background(badgeColor)
                        .padding(horizontal = 10.dp, vertical = 6.dp)
                )
                Box {
                    IconButton(
                        onClick = { showMenu = true },
                        modifier = Modifier.size(28.dp)
                    ) {
                        Icon(
                            imageVector = Icons.Default.MoreHoriz,
                            contentDescription = "操作",
                            tint = MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.size(28.dp)
                        )
                    }
                    DropdownMenu(
                        expanded = showMenu,
                        onDismissRequest = { showMenu = false }
                    ) {
                        DropdownMenuItem(
                            text = { Text("編集") },
                            leadingIcon = { Icon(Icons.Default.Edit, contentDescription = null) },
                            onClick = {
                                showMenu = false
                                onEdit()
                            }
                        )
                        DropdownMenuItem(
                            text = { Text("削除") },
                            leadingIcon = {
                                Icon(
                                    imageVector = Icons.Default.Delete,
                                    contentDescription = null,
                                    tint = MaterialTheme.colorScheme.error
                                )
                            },
                            onClick = {
                                showMenu = false
                                showDeleteConfirm = true
                            }
                        )
                    }
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
private fun AddEditExamSheet(
    title: String,
    exam: Exam? = null,
    onDismiss: () -> Unit,
    onConfirm: (name: String, date: LocalDate, note: String?) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var name by remember { mutableStateOf(exam?.name ?: "") }
    var selectedDate by remember { mutableStateOf(exam?.dateValue ?: LocalDate.now()) }
    var note by remember { mutableStateOf(exam?.note ?: "") }
    val trimmedName = name.trim()
    val isSaveDisabled = trimmedName.isEmpty()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        containerColor = MaterialTheme.colorScheme.surface
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 14.dp)
                .padding(top = 18.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            SheetHeader(
                title = title,
                isSaveDisabled = isSaveDisabled,
                onCancel = onDismiss,
                onSave = {
                    onConfirm(
                        trimmedName,
                        selectedDate,
                        note.trim().ifBlank { null }
                    )
                }
            )

            Text(
                text = "テストの予定を追加します。",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 12.dp, start = 10.dp, end = 10.dp)
            )

            ExamTextCard(
                title = "テスト名",
                placeholder = "テスト名を入力してください",
                text = name,
                maxLength = 100,
                minHeight = 128.dp,
                singleLine = false,
                onTextChange = { next -> name = next.take(100) }
            )

            DateCard(
                selectedDate = selectedDate,
                onDateChange = { selectedDate = it }
            )

            ExamTextCard(
                title = "メモ（任意）",
                placeholder = "メモを入力してください",
                text = note,
                maxLength = 500,
                minHeight = 146.dp,
                singleLine = false,
                onTextChange = { next -> note = next.take(500) }
            )

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .clip(RoundedCornerShape(8.dp))
                    .background(Color(0x1A1E88E5))
                    .padding(horizontal = 16.dp, vertical = 14.dp),
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.Info,
                    contentDescription = null,
                    tint = Color(0xFF1E88E5),
                    modifier = Modifier.size(20.dp)
                )
                Text(
                    text = "リマインダーや通知は設定で管理できます。",
                    fontSize = 14.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color(0xFF1E88E5),
                    modifier = Modifier.weight(1f)
                )
            }
        }
    }

}

@Composable
private fun SheetHeader(
    title: String,
    isSaveDisabled: Boolean,
    onCancel: () -> Unit,
    onSave: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 10.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = Modifier
                .width(34.dp)
                .height(5.dp)
                .clip(RoundedCornerShape(50))
                .background(MaterialTheme.colorScheme.outlineVariant)
        )
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(onClick = onCancel) {
                Text(
                    text = "キャンセル",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = title,
                fontSize = 20.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            TextButton(
                enabled = !isSaveDisabled,
                onClick = onSave,
                colors = ButtonDefaults.textButtonColors(
                    disabledContentColor = MaterialTheme.colorScheme.primary.copy(alpha = 0.28f)
                )
            ) {
                Text(
                    text = "保存",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
private fun ExamTextCard(
    title: String,
    placeholder: String,
    text: String,
    maxLength: Int,
    minHeight: androidx.compose.ui.unit.Dp,
    singleLine: Boolean,
    onTextChange: (String) -> Unit
) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = minHeight),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.outlinedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 22.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = title,
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            OutlinedTextField(
                value = text,
                onValueChange = onTextChange,
                placeholder = { Text(placeholder) },
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = if (singleLine) 56.dp else 70.dp),
                singleLine = singleLine,
                maxLines = if (singleLine) 1 else 4,
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Text)
            )
            Text(
                text = "${text.length} / $maxLength",
                fontSize = 15.sp,
                fontWeight = FontWeight.Medium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.align(Alignment.End)
            )
        }
    }
}

@Composable
private fun DateCard(
    selectedDate: LocalDate,
    onDateChange: (LocalDate) -> Unit
) {
    var visibleMonth by remember(selectedDate) { mutableStateOf(YearMonth.from(selectedDate)) }
    val today = LocalDate.now()

    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.outlinedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        border = BorderStroke(1.dp, MaterialTheme.colorScheme.outlineVariant)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 22.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            Text(
                text = "日付",
                fontSize = 18.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    imageVector = Icons.Default.CalendarMonth,
                    contentDescription = null,
                    modifier = Modifier.size(28.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                Spacer(modifier = Modifier.width(18.dp))
                Text(
                    text = selectedDate.format(ExamEditorDateFormatter),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.primary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                Icon(
                    imageVector = Icons.Default.ChevronRight,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.outlineVariant,
                    modifier = Modifier.size(26.dp)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = { visibleMonth = visibleMonth.minusMonths(1) }) {
                    Text("前月")
                }
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = "${visibleMonth.year}年 ${visibleMonth.monthValue}月",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.weight(1f))
                TextButton(onClick = { visibleMonth = visibleMonth.plusMonths(1) }) {
                    Text("翌月")
                }
            }

            WeekdayHeaderRow()
            MonthDayGrid(
                visibleMonth = visibleMonth,
                selectedDate = selectedDate,
                today = today,
                onSelect = onDateChange
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "選択中: ${selectedDate.format(ExamEditorDateFormatter)}",
                    style = MaterialTheme.typography.bodyMedium,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.weight(1f)
                )
                TextButton(
                    onClick = {
                        onDateChange(today)
                        visibleMonth = YearMonth.from(today)
                    }
                ) {
                    Text("今日")
                }
            }
        }
    }
}

@Composable
private fun WeekdayHeaderRow() {
    Row(modifier = Modifier.fillMaxWidth()) {
        JapaneseWeekdayLabels.forEachIndexed { index, label ->
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = weekdayLabelColor(index),
                modifier = Modifier.weight(1f),
                textAlign = androidx.compose.ui.text.style.TextAlign.Center
            )
        }
    }
}

@Composable
private fun MonthDayGrid(
    visibleMonth: YearMonth,
    selectedDate: LocalDate,
    today: LocalDate,
    onSelect: (LocalDate) -> Unit
) {
    val firstDayOffset = visibleMonth.atDay(1).dayOfWeek.value % 7
    val daysInMonth = visibleMonth.lengthOfMonth()
    val rowCount = ((firstDayOffset + daysInMonth + 6) / 7).coerceAtLeast(5)

    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        repeat(rowCount) { rowIndex ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                repeat(7) { columnIndex ->
                    val dayNumber = rowIndex * 7 + columnIndex - firstDayOffset + 1
                    if (dayNumber in 1..daysInMonth) {
                        val date = visibleMonth.atDay(dayNumber)
                        DayCell(
                            date = date,
                            isSelected = date == selectedDate,
                            isToday = date == today,
                            columnIndex = columnIndex,
                            onClick = { onSelect(date) },
                            modifier = Modifier.weight(1f)
                        )
                    } else {
                        Spacer(
                            modifier = Modifier
                                .weight(1f)
                                .height(40.dp)
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DayCell(
    date: LocalDate,
    isSelected: Boolean,
    isToday: Boolean,
    columnIndex: Int,
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    val background = if (isSelected) {
        MaterialTheme.colorScheme.primary
    } else if (isToday) {
        MaterialTheme.colorScheme.primaryContainer.copy(alpha = 0.65f)
    } else {
        Color.Transparent
    }
    val contentColor = if (isSelected) {
        MaterialTheme.colorScheme.onPrimary
    } else {
        weekdayLabelColor(columnIndex)
    }

    TextButton(
        onClick = onClick,
        modifier = modifier.height(40.dp),
        contentPadding = PaddingValues(0.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(background),
            contentAlignment = Alignment.Center
        ) {
            Text(
                text = date.dayOfMonth.toString(),
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (isSelected || isToday) FontWeight.Bold else FontWeight.Normal,
                color = contentColor
            )
        }
    }
}

@Composable
private fun weekdayLabelColor(columnIndex: Int): Color {
    return when (columnIndex) {
        0 -> Color(0xFFFF3B30)
        6 -> Color(0xFF1E88E5)
        else -> MaterialTheme.colorScheme.onSurface
    }
}

private fun examBadgeText(daysRemaining: Int): String {
    return when {
        daysRemaining < 0 -> "終了"
        daysRemaining == 0 -> "今日"
        else -> "あと${daysRemaining}日"
    }
}

private val JapaneseWeekdayLabels = listOf("日", "月", "火", "水", "木", "金", "土")
