package com.studyapp.presentation.plans

import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.EventNote
import androidx.compose.material.icons.filled.AccessTime
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.MoreHoriz
import androidx.compose.material.icons.filled.Remove
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
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
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.PlanItem
import com.studyapp.domain.model.PlanItemWithSubject
import com.studyapp.domain.model.StudyPlan
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.model.Subject
import com.studyapp.presentation.components.CircularProgressRing
import com.studyapp.presentation.components.EmptyState
import com.studyapp.presentation.theme.toSubjectColor
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.ZoneId
import java.util.Calendar
import java.util.Date
import java.util.Locale

private val PlanDisplayDays = listOf(
    StudyWeekday.SUNDAY,
    StudyWeekday.MONDAY,
    StudyWeekday.TUESDAY,
    StudyWeekday.WEDNESDAY,
    StudyWeekday.THURSDAY,
    StudyWeekday.FRIDAY,
    StudyWeekday.SATURDAY
)
private val PlanDateFormatter = SimpleDateFormat("yyyy/M/d（E）", Locale.JAPANESE)
private val PlanDateRangeFormatter = SimpleDateFormat("M月d日 (E)", Locale.JAPANESE)
private val SuccessGreen = Color(0xFF2FA84F)
private val SoftGreen = Color(0xFFEAF7EE)
private val CardBorder = Color(0xFFE0E4E8)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PlanScreen(
    viewModel: PlanViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val snackbarHostState = remember { SnackbarHostState() }
    var showCreateSheet by remember { mutableStateOf(false) }
    var showAddItemSheet by remember { mutableStateOf(false) }
    var editingItem by remember { mutableStateOf<PlanItem?>(null) }
    var selectedDay by remember { mutableStateOf(StudyWeekday.MONDAY) }
    var showDeletePlanDialog by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.error) {
        val message = uiState.error ?: return@LaunchedEffect
        snackbarHostState.showSnackbar(message)
        viewModel.clearError()
    }

    LaunchedEffect(uiState.activePlan?.id) {
        selectedDay = StudyWeekday.MONDAY
    }

    Scaffold(
        snackbarHost = { SnackbarHost(snackbarHostState) },
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "計画",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    if (uiState.activePlan != null) {
                        IconButton(onClick = { showAddItemSheet = true }) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = "計画項目を追加",
                                tint = SuccessGreen,
                                modifier = Modifier.size(29.dp)
                            )
                        }
                        IconButton(onClick = { showDeletePlanDialog = true }) {
                            Icon(
                                imageVector = Icons.Default.Delete,
                                contentDescription = "計画を削除",
                                tint = SuccessGreen,
                                modifier = Modifier.size(28.dp)
                            )
                        }
                    } else {
                        IconButton(onClick = { showCreateSheet = true }) {
                            Icon(
                                imageVector = Icons.Default.Add,
                                contentDescription = "計画を作成",
                                tint = SuccessGreen,
                                modifier = Modifier.size(29.dp)
                            )
                        }
                    }
                }
            )
        },
        containerColor = MaterialTheme.colorScheme.background
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                Box(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentAlignment = Alignment.Center
                ) {
                    CircularProgressIndicator(color = SuccessGreen)
                }
            }

            uiState.activePlan == null -> {
                EmptyState(
                    icon = Icons.Default.CalendarMonth,
                    title = "学習計画がありません",
                    description = "1週間の学習計画を作成して、Android と同じ計画運用フローにそろえます。",
                    actionLabel = "計画を作成",
                    onAction = { showCreateSheet = true },
                    modifier = Modifier.padding(paddingValues)
                )
            }

            else -> {
                val activePlan = uiState.activePlan!!
                LazyColumn(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    contentPadding = PaddingValues(horizontal = 18.dp, vertical = 22.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    item {
                        PlanHeaderCard(
                            plan = activePlan,
                            totalTargetMinutes = uiState.totalTargetMinutes,
                            completionRate = viewModel.getCompletionRate()
                        )
                    }
                    item {
                        DaySelector(
                            selectedDay = selectedDay,
                            weekStartDate = activePlan.startDate,
                            onSelect = { selectedDay = it }
                        )
                    }
                    item {
                        DayScheduleSection(
                            day = selectedDay,
                            items = uiState.weeklySchedule[selectedDay].orEmpty(),
                            onEdit = { editingItem = it },
                            onDelete = { viewModel.deletePlanItem(it) }
                        )
                    }
                }
            }
        }
    }

    if (showCreateSheet) {
        CreatePlanSheet(
            subjects = uiState.subjects,
            onDismiss = { showCreateSheet = false },
            onCreate = { name, startDate, endDate, items ->
                viewModel.createPlan(name, startDate, endDate, items)
                showCreateSheet = false
            }
        )
    }

    if (showAddItemSheet && uiState.activePlan != null) {
        PlanItemEditorSheet(
            subjects = uiState.subjects,
            activePlanId = uiState.activePlan!!.id,
            item = null,
            onDismiss = { showAddItemSheet = false },
            onSave = { item ->
                viewModel.addPlanItem(item.subjectId, item.dayOfWeek, item.targetMinutes, item.timeSlot)
                showAddItemSheet = false
            }
        )
    }

    editingItem?.let { item ->
        PlanItemEditorSheet(
            subjects = uiState.subjects,
            activePlanId = item.planId,
            item = item,
            onDismiss = { editingItem = null },
            onSave = { updatedItem ->
                viewModel.updatePlanItem(updatedItem)
                editingItem = null
            },
            onDelete = {
                viewModel.deletePlanItem(item)
                editingItem = null
            }
        )
    }

    if (showDeletePlanDialog) {
        AlertDialog(
            onDismissRequest = { showDeletePlanDialog = false },
            title = { Text("計画を削除") },
            text = { Text("この学習計画を削除してもよろしいですか？\nこの操作は取り消せません。") },
            confirmButton = {
                TextButton(
                    onClick = {
                        viewModel.deletePlan()
                        showDeletePlanDialog = false
                    }
                ) {
                    Text("削除", color = MaterialTheme.colorScheme.error)
                }
            },
            dismissButton = {
                TextButton(onClick = { showDeletePlanDialog = false }) {
                    Text("キャンセル")
                }
            }
        )
    }
}

@Composable
private fun PlanHeaderCard(
    plan: StudyPlan,
    totalTargetMinutes: Int,
    completionRate: Float
) {
    val currentMinutes = (totalTargetMinutes * completionRate).toInt()

    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, CardBorder)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp)
        ) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(18.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Row(
                    modifier = Modifier.weight(1f),
                    horizontalArrangement = Arrangement.spacedBy(14.dp),
                    verticalAlignment = Alignment.Top
                ) {
                    Box(
                        modifier = Modifier
                            .size(64.dp)
                            .clip(RoundedCornerShape(14.dp))
                            .background(
                                Brush.linearGradient(
                                    listOf(Color(0xFF42C857), SuccessGreen)
                                )
                            ),
                        contentAlignment = Alignment.Center
                    ) {
                        Icon(
                            imageVector = Icons.Default.CalendarMonth,
                            contentDescription = null,
                            tint = Color.White,
                            modifier = Modifier.size(32.dp)
                        )
                    }
                    Column(verticalArrangement = Arrangement.spacedBy(7.dp)) {
                        Text(
                            text = plan.name,
                            fontSize = 24.sp,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.onSurface,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(
                            text = "${PlanDateRangeFormatter.format(Date(plan.startDate))} 〜 ${PlanDateRangeFormatter.format(Date(plan.endDate))}",
                            fontSize = 18.sp,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }

                CircularProgressRing(
                    progress = completionRate,
                    size = 112.dp,
                    strokeWidth = 14.dp,
                    progressColor = SuccessGreen,
                    trackColor = CardBorder.copy(alpha = 0.75f),
                    showPercentage = false,
                    centerContent = {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "${(completionRate * 100).toInt()}%",
                                fontSize = 32.sp,
                                fontWeight = FontWeight.Bold,
                                color = SuccessGreen
                            )
                            Text(
                                text = formatPlanMinutes(currentMinutes),
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                            Text(
                                text = "/ ${formatPlanMinutes(totalTargetMinutes)}",
                                fontSize = 15.sp,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                    }
                )
            }

            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = "目標:",
                    fontSize = 18.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(4.dp))
                Text(
                    text = formatPlanMinutes(totalTargetMinutes),
                    fontSize = 24.sp,
                    fontWeight = FontWeight.Bold,
                    color = SuccessGreen
                )
                Text(
                    text = "/ 週",
                    fontSize = 18.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun DaySelector(
    selectedDay: StudyWeekday,
    weekStartDate: Long,
    onSelect: (StudyWeekday) -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, CardBorder)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 10.dp, vertical = 8.dp),
            horizontalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            PlanDisplayDays.forEachIndexed { index, day ->
                val isSelected = day == selectedDay
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(12.dp))
                        .clickable { onSelect(day) }
                        .padding(vertical = 10.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        modifier = Modifier
                            .size(48.dp)
                            .clip(CircleShape)
                            .background(if (isSelected) SuccessGreen else Color.Transparent),
                        contentAlignment = Alignment.Center
                    ) {
                        Text(
                            text = day.japaneseShortTitle,
                            fontSize = 20.sp,
                            fontWeight = FontWeight.Bold,
                            color = if (isSelected) Color.White else MaterialTheme.colorScheme.onSurface
                        )
                    }
                    Text(
                        text = weekDateNumber(weekStartDate, index).toString(),
                        fontSize = 18.sp,
                        fontWeight = FontWeight.Medium,
                        color = if (isSelected) SuccessGreen else MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        }
    }
}

@Composable
private fun DayScheduleSection(
    day: StudyWeekday,
    items: List<PlanItemWithSubject>,
    onEdit: (PlanItem) -> Unit,
    onDelete: (PlanItem) -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, CardBorder)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = day.japaneseTitle,
                    fontSize = 22.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.weight(1f))
                Text(
                    text = "合計: ${items.sumOf { it.item.targetMinutes }}分",
                    fontSize = 20.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            if (items.isEmpty()) {
                OutlinedCard(
                    modifier = Modifier.fillMaxWidth(),
                    shape = RoundedCornerShape(12.dp),
                    colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
                    border = BorderStroke(1.dp, CardBorder)
                ) {
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.spacedBy(10.dp),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.EventNote,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                        Text(
                            text = "予定なし",
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                            fontSize = 17.sp
                        )
                    }
                }
            } else {
                items.forEach { wrapped ->
                    PlanScheduleRow(
                        wrapped = wrapped,
                        onEdit = { onEdit(wrapped.item) },
                        onDelete = { onDelete(wrapped.item) }
                    )
                }
            }
        }
    }
}

@Composable
private fun PlanScheduleRow(
    wrapped: PlanItemWithSubject,
    onEdit: () -> Unit,
    onDelete: () -> Unit
) {
    val subjectColor = wrapped.subject.color.toSubjectColor()
    var showMenu by remember { mutableStateOf(false) }

    ElevatedCard(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 118.dp),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.elevatedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .width(7.dp)
                    .height(118.dp)
                    .clip(RoundedCornerShape(3.dp))
                    .background(subjectColor)
            )
            Spacer(modifier = Modifier.width(16.dp))
            Column(
                modifier = Modifier
                    .weight(1f)
                    .padding(vertical = 20.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp)
            ) {
                Row(
                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Box(
                        modifier = Modifier
                            .size(20.dp)
                            .clip(CircleShape)
                            .background(subjectColor)
                    )
                    Text(
                        text = wrapped.subject.name,
                        fontSize = 22.sp,
                        fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurface,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
                Row(
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(
                        imageVector = Icons.Default.AccessTime,
                        contentDescription = null,
                        tint = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.size(18.dp)
                    )
                    Text(
                        text = wrapped.item.timeSlot?.takeIf { it.isNotBlank() } ?: "時間未設定",
                        fontSize = 18.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis
                    )
                }
            }
            Text(
                text = "${wrapped.item.targetMinutes}分",
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Box {
                IconButton(onClick = { showMenu = true }) {
                    Icon(
                        imageVector = Icons.Default.MoreHoriz,
                        contentDescription = "操作",
                        tint = Color(0xFF8B9099),
                        modifier = Modifier.size(28.dp)
                    )
                }
                DropdownMenu(
                    expanded = showMenu,
                    onDismissRequest = { showMenu = false }
                ) {
                    DropdownMenuItem(
                        text = { Text("編集") },
                        onClick = {
                            showMenu = false
                            onEdit()
                        }
                    )
                    DropdownMenuItem(
                        text = { Text("削除") },
                        onClick = {
                            showMenu = false
                            onDelete()
                        }
                    )
                }
            }
            Spacer(modifier = Modifier.width(8.dp))
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CreatePlanSheet(
    subjects: List<Subject>,
    onDismiss: () -> Unit,
    onCreate: (name: String, startDate: Long, endDate: Long, items: List<PlanItem>) -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var name by remember { mutableStateOf("") }
    var startDate by remember { mutableStateOf(defaultPlanStartMillis()) }
    var endDate by remember { mutableStateOf(defaultPlanEndMillis()) }
    val draftItems = remember(subjects) {
        mutableStateListOf<DraftPlanItem>().apply {
            addAll(initialDraftItems(subjects))
        }
    }
    val planItems = draftItems.mapNotNull { it.toPlanItem() }
    val canCreate = name.trim().isNotEmpty() && subjects.isNotEmpty() && planItems.isNotEmpty()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        containerColor = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 22.dp)
                .padding(top = 18.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            SheetHeader(
                title = "計画を作成",
                confirmText = "作成",
                isConfirmDisabled = !canCreate,
                onCancel = onDismiss,
                onConfirm = {
                    onCreate(name.trim(), startDate, endDate, planItems)
                }
            )

            Text(
                text = "新しい週次計画を作成します。",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp)
            )

            PlanFieldsCard(
                name = name,
                startDate = startDate,
                endDate = endDate,
                onNameChange = { name = it },
                onStartDateChange = { next ->
                    startDate = next
                    if (endDate < next) endDate = next
                },
                onEndDateChange = { next ->
                    if (next >= startDate) endDate = next
                }
            )

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                Text(
                    text = "初期項目",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Text(
                    text = "計画作成時に登録する初期の項目です。",
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            DraftItemsCard(
                subjects = subjects,
                draftItems = draftItems
            )

            ActionCardButton(
                icon = Icons.Default.Add,
                text = "項目を追加",
                enabled = subjects.isNotEmpty(),
                onClick = {
                    draftItems.add(
                        DraftPlanItem(
                            subjectId = subjects.first().id,
                            ordinal = draftItems.size + 1
                        )
                    )
                }
            )

            PlanAboutCard()
        }
    }
}

@Composable
private fun PlanFieldsCard(
    name: String,
    startDate: Long,
    endDate: Long,
    onNameChange: (String) -> Unit,
    onStartDateChange: (Long) -> Unit,
    onEndDateChange: (Long) -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, CardBorder)
    ) {
        Column {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(58.dp)
                    .padding(horizontal = 18.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "計画名",
                    modifier = Modifier.width(94.dp),
                    fontSize = 17.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.onSurface
                )
                OutlinedTextField(
                    value = name,
                    onValueChange = onNameChange,
                    placeholder = { Text("例）平日集中プラン") },
                    modifier = Modifier.weight(1f),
                    singleLine = true,
                    textStyle = MaterialTheme.typography.bodyMedium
                )
            }
            HorizontalDivider(color = CardBorder)
            PlanDateStepperRow(
                title = "開始日",
                dateMillis = startDate,
                onDateChange = onStartDateChange
            )
            HorizontalDivider(color = CardBorder)
            PlanDateStepperRow(
                title = "終了日",
                dateMillis = endDate,
                onDateChange = onEndDateChange
            )
        }
    }
}

@Composable
private fun PlanDateStepperRow(
    title: String,
    dateMillis: Long,
    onDateChange: (Long) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp)
            .padding(horizontal = 18.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = title,
            modifier = Modifier.width(94.dp),
            fontSize = 17.sp,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface
        )
        IconButton(onClick = { onDateChange(shiftDateByDays(dateMillis, -1)) }) {
            Icon(
                imageVector = Icons.Default.Remove,
                contentDescription = "前日",
                tint = SuccessGreen
            )
        }
        Text(
            text = PlanDateFormatter.format(Date(dateMillis)),
            modifier = Modifier.weight(1f),
            fontSize = 17.sp,
            fontWeight = FontWeight.Medium,
            color = SuccessGreen,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        IconButton(onClick = { onDateChange(shiftDateByDays(dateMillis, 1)) }) {
            Icon(
                imageVector = Icons.Default.Add,
                contentDescription = "翌日",
                tint = SuccessGreen
            )
        }
    }
}

@Composable
private fun DraftItemsCard(
    subjects: List<Subject>,
    draftItems: MutableList<DraftPlanItem>
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, CardBorder)
    ) {
        if (subjects.isEmpty()) {
            Text(
                text = "科目がありません。先に科目を追加してください。",
                modifier = Modifier.padding(18.dp),
                fontSize = 15.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        } else {
            Column(modifier = Modifier.padding(vertical = 14.dp)) {
                draftItems.forEachIndexed { index, item ->
                    DraftItemRow(
                        index = index,
                        subjects = subjects,
                        item = item,
                        canDelete = draftItems.size > 1,
                        onUpdate = { draftItems[index] = it },
                        onDelete = { draftItems.removeAt(index) }
                    )
                    if (index < draftItems.lastIndex) {
                        HorizontalDivider(
                            modifier = Modifier.padding(start = 64.dp, end = 18.dp),
                            color = CardBorder
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DraftItemRow(
    index: Int,
    subjects: List<Subject>,
    item: DraftPlanItem,
    canDelete: Boolean,
    onUpdate: (DraftPlanItem) -> Unit,
    onDelete: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(
            text = "${index + 1}",
            fontSize = 14.sp,
            fontWeight = FontWeight.SemiBold,
            color = SuccessGreen,
            modifier = Modifier
                .clip(RoundedCornerShape(8.dp))
                .background(SoftGreen)
                .padding(horizontal = 16.dp, vertical = 6.dp)
        )

        Column(
            modifier = Modifier.weight(1f),
            verticalArrangement = Arrangement.spacedBy(0.dp)
        ) {
            DraftMenuRow(
                title = "科目",
                value = subjects.firstOrNull { it.id == item.subjectId }?.name ?: "科目なし",
                menuItems = subjects.map { it.name },
                onSelect = { selected ->
                    subjects.firstOrNull { it.name == selected }?.let { subject ->
                        onUpdate(item.copy(subjectId = subject.id))
                    }
                }
            )
            HorizontalDivider(color = CardBorder)
            DraftMenuRow(
                title = "曜日",
                value = item.dayOfWeek.japaneseTitle,
                menuItems = StudyWeekday.entries.map { it.japaneseTitle },
                onSelect = { selected ->
                    StudyWeekday.entries.firstOrNull { it.japaneseTitle == selected }?.let { day ->
                        onUpdate(item.copy(dayOfWeek = day))
                    }
                }
            )
            HorizontalDivider(color = CardBorder)
            DraftMenuRow(
                title = "目標時間（分）",
                value = item.targetMinutes,
                menuItems = listOf("30", "45", "60", "90", "120", "150", "180"),
                onSelect = { onUpdate(item.copy(targetMinutes = it)) }
            )
            HorizontalDivider(color = CardBorder)
            DraftMenuRow(
                title = "時間帯",
                value = item.timeSlot.ifBlank { "未設定" },
                menuItems = listOf("未設定", "6:00 - 7:00", "7:00 - 8:00", "19:00 - 20:30", "19:00 - 21:00", "21:00 - 22:00"),
                onSelect = { onUpdate(item.copy(timeSlot = if (it == "未設定") "" else it)) }
            )
        }

        IconButton(
            enabled = canDelete,
            onClick = onDelete
        ) {
            Icon(
                imageVector = Icons.Default.Delete,
                contentDescription = "項目を削除",
                tint = if (canDelete) Color(0xFFFF2D20) else MaterialTheme.colorScheme.outlineVariant
            )
        }
    }
}

@Composable
private fun DraftMenuRow(
    title: String,
    value: String,
    menuItems: List<String>,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(46.dp)
                .clip(RoundedCornerShape(8.dp))
                .clickable(enabled = menuItems.isNotEmpty()) { expanded = true }
                .padding(horizontal = 16.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = value,
                fontSize = 16.sp,
                fontWeight = FontWeight.Medium,
                color = SuccessGreen,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = Color(0xFF8B9098),
                modifier = Modifier.size(18.dp)
            )
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            menuItems.forEach { item ->
                DropdownMenuItem(
                    text = { Text(item) },
                    onClick = {
                        expanded = false
                        onSelect(item)
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PlanItemEditorSheet(
    subjects: List<Subject>,
    activePlanId: Long,
    item: PlanItem?,
    onDismiss: () -> Unit,
    onSave: (PlanItem) -> Unit,
    onDelete: (() -> Unit)? = null
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var draft by remember(item, subjects) {
        mutableStateOf(DraftPlanItem(item = item, fallbackSubjectId = subjects.firstOrNull()?.id ?: 0L))
    }
    val targetMinutes = draft.targetMinutes.toIntOrNull()
    val canSave = subjects.isNotEmpty() && targetMinutes != null && targetMinutes > 0

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        dragHandle = null,
        containerColor = MaterialTheme.colorScheme.background
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp)
                .padding(top = 18.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp)
        ) {
            SheetHeader(
                title = if (item == null) "計画項目を追加" else "計画項目を編集",
                confirmText = "保存",
                isConfirmDisabled = !canSave,
                onCancel = onDismiss,
                onConfirm = {
                    val minutes = draft.targetMinutes.toInt()
                    onSave(
                        PlanItem(
                            id = item?.id ?: 0,
                            syncId = item?.syncId ?: java.util.UUID.randomUUID().toString().lowercase(),
                            planId = item?.planId ?: activePlanId,
                            planSyncId = item?.planSyncId,
                            subjectId = draft.subjectId,
                            subjectSyncId = item?.subjectSyncId,
                            dayOfWeek = draft.dayOfWeek,
                            targetMinutes = minutes,
                            actualMinutes = item?.actualMinutes ?: 0,
                            timeSlot = draft.timeSlot.ifBlank { null },
                            createdAt = item?.createdAt ?: System.currentTimeMillis(),
                            updatedAt = System.currentTimeMillis(),
                            deletedAt = item?.deletedAt,
                            lastSyncedAt = item?.lastSyncedAt
                        )
                    )
                }
            )

            Text(
                text = "計画項目の内容を編集します。",
                fontSize = 16.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            PlanItemEditorCard(
                subjects = subjects,
                draft = draft,
                onUpdate = { draft = it }
            )

            InputGuideCard()

            if (item != null && onDelete != null) {
                ActionCardButton(
                    icon = Icons.Default.Delete,
                    text = "計画項目を削除",
                    color = Color(0xFFFF3B30),
                    onClick = onDelete
                )
            }
        }
    }
}

@Composable
private fun PlanItemEditorCard(
    subjects: List<Subject>,
    draft: DraftPlanItem,
    onUpdate: (DraftPlanItem) -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, CardBorder)
    ) {
        Column(modifier = Modifier.padding(horizontal = 18.dp)) {
            EditorMenuRow(
                title = "科目",
                value = subjects.firstOrNull { it.id == draft.subjectId }?.name ?: "未設定",
                menuItems = subjects.map { it.name },
                onSelect = { selected ->
                    subjects.firstOrNull { it.name == selected }?.let { subject ->
                        onUpdate(draft.copy(subjectId = subject.id))
                    }
                }
            )
            HorizontalDivider(color = CardBorder)
            EditorMenuRow(
                title = "曜日",
                value = draft.dayOfWeek.japaneseTitle,
                menuItems = StudyWeekday.entries.map { it.japaneseTitle },
                onSelect = { selected ->
                    StudyWeekday.entries.firstOrNull { it.japaneseTitle == selected }?.let { day ->
                        onUpdate(draft.copy(dayOfWeek = day))
                    }
                }
            )
            HorizontalDivider(color = CardBorder)
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(78.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text(
                    text = "目標時間 （分）",
                    fontSize = 20.sp,
                    color = MaterialTheme.colorScheme.onSurface
                )
                Spacer(modifier = Modifier.weight(1f))
                OutlinedTextField(
                    value = draft.targetMinutes,
                    onValueChange = { value -> onUpdate(draft.copy(targetMinutes = value.filter(Char::isDigit))) },
                    modifier = Modifier.width(142.dp),
                    singleLine = true,
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number)
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text("分", color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            HorizontalDivider(color = CardBorder)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(103.dp),
                verticalArrangement = Arrangement.Center
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "時間帯",
                        fontSize = 20.sp,
                        color = MaterialTheme.colorScheme.onSurface
                    )
                    Spacer(modifier = Modifier.weight(1f))
                    OutlinedTextField(
                        value = draft.timeSlot,
                        onValueChange = { onUpdate(draft.copy(timeSlot = it)) },
                        modifier = Modifier.width(210.dp),
                        singleLine = true
                    )
                }
                Text(
                    text = "例：19:00-20:30",
                    modifier = Modifier.padding(start = 190.dp, top = 8.dp),
                    fontSize = 15.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun EditorMenuRow(
    title: String,
    value: String,
    menuItems: List<String>,
    onSelect: (String) -> Unit
) {
    var expanded by remember { mutableStateOf(false) }
    Box {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .height(76.dp)
                .clickable(enabled = menuItems.isNotEmpty()) { expanded = true },
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                text = title,
                fontSize = 20.sp,
                color = MaterialTheme.colorScheme.onSurface
            )
            Spacer(modifier = Modifier.weight(1f))
            Text(
                text = value,
                fontSize = 20.sp,
                color = MaterialTheme.colorScheme.onSurface,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis
            )
            Icon(
                imageVector = Icons.Default.ChevronRight,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.outlineVariant,
                modifier = Modifier.size(22.dp)
            )
        }
        DropdownMenu(
            expanded = expanded,
            onDismissRequest = { expanded = false }
        ) {
            menuItems.forEach { item ->
                DropdownMenuItem(
                    text = { Text(item) },
                    onClick = {
                        expanded = false
                        onSelect(item)
                    }
                )
            }
        }
    }
}

@Composable
private fun SheetHeader(
    title: String,
    confirmText: String,
    isConfirmDisabled: Boolean,
    onCancel: () -> Unit,
    onConfirm: () -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Box(
            modifier = Modifier
                .width(35.dp)
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
                enabled = !isConfirmDisabled,
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(
                    disabledContentColor = SuccessGreen.copy(alpha = 0.28f)
                )
            ) {
                Text(
                    text = confirmText,
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold
                )
            }
        }
    }
}

@Composable
private fun ActionCardButton(
    icon: ImageVector,
    text: String,
    enabled: Boolean = true,
    color: Color = SuccessGreen,
    onClick: () -> Unit
) {
    OutlinedCard(
        modifier = Modifier
            .fillMaxWidth()
            .height(58.dp)
            .clickable(enabled = enabled, onClick = onClick),
        shape = RoundedCornerShape(14.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface),
        border = BorderStroke(1.dp, CardBorder)
    ) {
        Row(
            modifier = Modifier.fillMaxSize(),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = if (enabled) color else MaterialTheme.colorScheme.outlineVariant,
                modifier = Modifier.size(22.dp)
            )
            Spacer(modifier = Modifier.width(10.dp))
            Text(
                text = text,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                color = if (enabled) color else MaterialTheme.colorScheme.outlineVariant
            )
        }
    }
}

@Composable
private fun PlanAboutCard() {
    InfoCard(
        title = "について",
        lines = listOf(
            "・ 作成後に各日の予定は編集できます。",
            "・ 目標時間は１日の合計目標として扱われます。",
            "・ 曜日や時間帯は後から変更できます。"
        )
    )
}

@Composable
private fun InputGuideCard() {
    InfoCard(
        title = "入力のガイド",
        lines = listOf(
            "・ 目標時間は 1 分以上で入力してください。",
            "・ 時間帯は 24 時間形式で入力してください。",
            "   例：19:00-20:30、07:30-08:15"
        )
    )
}

@Composable
private fun InfoCard(
    title: String,
    lines: List<String>
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(12.dp))
            .background(SoftGreen.copy(alpha = 0.5f))
            .padding(horizontal = 18.dp, vertical = 22.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp)
    ) {
        Row(
            horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Icon(
                imageVector = Icons.Default.Info,
                contentDescription = null,
                tint = SuccessGreen,
                modifier = Modifier.size(20.dp)
            )
            Text(
                text = title,
                fontSize = 17.sp,
                fontWeight = FontWeight.Bold,
                color = SuccessGreen
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            lines.forEach { line ->
                Text(
                    text = line,
                    fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

private data class DraftPlanItem(
    val subjectId: Long,
    val dayOfWeek: StudyWeekday = StudyWeekday.MONDAY,
    val targetMinutes: String = "120",
    val timeSlot: String = "19:00 - 21:00"
) {
    constructor(subjectId: Long, ordinal: Int) : this(
        subjectId = subjectId,
        dayOfWeek = if (ordinal == 2) StudyWeekday.TUESDAY else StudyWeekday.MONDAY,
        targetMinutes = if (ordinal == 2) "90" else "120",
        timeSlot = if (ordinal == 2) "19:00 - 20:30" else "19:00 - 21:00"
    )

    constructor(item: PlanItem?, fallbackSubjectId: Long) : this(
        subjectId = item?.subjectId ?: fallbackSubjectId,
        dayOfWeek = item?.dayOfWeek ?: StudyWeekday.MONDAY,
        targetMinutes = item?.targetMinutes?.toString() ?: "120",
        timeSlot = item?.timeSlot ?: "19:00 - 21:00"
    )

    fun toPlanItem(): PlanItem? {
        val minutes = targetMinutes.toIntOrNull()?.takeIf { it > 0 } ?: return null
        return PlanItem(
            planId = 0,
            subjectId = subjectId,
            dayOfWeek = dayOfWeek,
            targetMinutes = minutes,
            timeSlot = timeSlot.ifBlank { null }
        )
    }
}

private fun initialDraftItems(subjects: List<Subject>): List<DraftPlanItem> {
    val first = subjects.firstOrNull() ?: return emptyList()
    val second = subjects.drop(1).firstOrNull() ?: first
    return listOf(
        DraftPlanItem(subjectId = first.id, ordinal = 1),
        DraftPlanItem(subjectId = second.id, ordinal = 2)
    )
}

private fun defaultPlanStartMillis(): Long = makePlanDateMillis(2026, Calendar.MAY, 26)

private fun defaultPlanEndMillis(): Long = makePlanDateMillis(2026, Calendar.AUGUST, 31)

private fun makePlanDateMillis(year: Int, month: Int, day: Int): Long {
    return Calendar.getInstance(Locale.JAPANESE).apply {
        clear()
        set(year, month, day, 0, 0, 0)
    }.timeInMillis
}

private fun shiftDateByDays(dateMillis: Long, days: Int): Long {
    return Calendar.getInstance(Locale.JAPANESE).apply {
        timeInMillis = dateMillis
        add(Calendar.DAY_OF_MONTH, days)
    }.timeInMillis
}

private fun weekDateNumber(weekStartMillis: Long, offset: Int): Int {
    val localDate = Date(weekStartMillis).toInstant()
        .atZone(ZoneId.systemDefault())
        .toLocalDate()
    val sundayStart = localDate.minusDays((localDate.dayOfWeek.value % 7).toLong())
    return sundayStart.plusDays(offset.toLong()).dayOfMonth
}

private fun formatPlanMinutes(minutes: Int): String {
    val hours = minutes / 60
    val remainingMinutes = minutes % 60
    return when {
        hours == 0 -> "${remainingMinutes}分"
        remainingMinutes == 0 -> "${hours}時間"
        else -> "${hours}時間${remainingMinutes}分"
    }
}
