package com.studyapp.presentation.timer

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Badge
import androidx.compose.material3.BadgedBox
import androidx.compose.material3.Button
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.LargeFloatingActionButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.ProblemResult
import com.studyapp.domain.model.ProblemSessionRecord
import com.studyapp.domain.model.Subject
import com.studyapp.domain.usecase.TimerMode
import com.studyapp.presentation.components.CircularProgressRing
import com.studyapp.presentation.components.PulsingEffect
import com.studyapp.presentation.components.SectionHeader
import com.studyapp.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimerScreen(
    viewModel: TimerViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    var showManualInputDialog by remember { mutableStateOf(false) }
    var showMaterialPicker by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.timer_screen_title),
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
                ),
                actions = {
                    IconButton(onClick = { showManualInputDialog = true }) {
                        Icon(
                            Icons.Default.Edit,
                            contentDescription = stringResource(R.string.timer_manual_input_title),
                            tint = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
            )
        }
    ) { paddingValues ->
        when {
            uiState.isLoading -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    CircularProgressIndicator()
                    Spacer(modifier = Modifier.height(16.dp))
                    Text(
                        text = stringResource(R.string.common_loading),
                        style = MaterialTheme.typography.bodyMedium
                    )
                }
            }
            uiState.error != null -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center
                ) {
                    Text(
                        text = uiState.error ?: stringResource(R.string.common_error),
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.error
                    )
                    Spacer(modifier = Modifier.height(16.dp))
                    Button(onClick = { viewModel.clearError() }) {
                        Text(stringResource(R.string.common_ok))
                    }
                }
            }
            else -> {
                Column(
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(paddingValues)
                        .padding(16.dp)
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    MaterialSelector(
                        selectedMaterial = uiState.selectedMaterial,
                        selectedSubject = uiState.selectedSubject,
                        onClick = { showMaterialPicker = true }
                    )

                    Spacer(modifier = Modifier.height(16.dp))

                    TimerModeSelector(
                        selectedMode = uiState.timerMode,
                        countdownMinutes = uiState.countdownMinutes,
                        isRunning = uiState.isRunning,
                        onSelectMode = viewModel::setTimerMode,
                        onSelectMinutes = viewModel::setCountdownMinutes
                    )

                    Spacer(modifier = Modifier.height(24.dp))

                    // Large CircularProgressRing with PulsingEffect
                    val displayTime = if (uiState.timerMode == TimerMode.TIMER) uiState.remainingTime else uiState.elapsedTime
                    val progress = when {
                        uiState.timerMode == TimerMode.TIMER -> {
                            val target = (uiState.countdownMinutes * 60_000L).coerceAtLeast(1L)
                            1f - (uiState.remainingTime.toFloat() / target.toFloat())
                        }
                        else -> {
                            val elapsedMinutes = uiState.elapsedTime / 60000f
                            (elapsedMinutes % 60f) / 60f
                        }
                    }

                    PulsingEffect(isPulsing = uiState.isRunning) {
                        CircularProgressRing(
                            progress = if (displayTime > 0L || uiState.isRunning) progress.coerceIn(0f, 1f) else 0f,
                            size = 280.dp,
                            strokeWidth = 14.dp,
                            showPercentage = false,
                            centerContent = {
                                TimerDisplay(
                                    time = displayTime,
                                    isRunning = uiState.isRunning,
                                    mode = uiState.timerMode
                                )
                            }
                        )
                    }

                    Spacer(modifier = Modifier.height(36.dp))

                    TimerControls(
                        isRunning = uiState.isRunning,
                        displayTime = displayTime,
                        onStart = { viewModel.startTimer() },
                        onPause = { viewModel.pauseTimer() },
                        onStop = { viewModel.stopTimer() }
                    )

                    if (!uiState.isRunning && uiState.selectedMaterial != null) {
                        Spacer(modifier = Modifier.height(24.dp))
                        ProblemProgressSection(
                            problemCount = uiState.problemCount,
                            problemStates = uiState.problemStates,
                            onSetCount = viewModel::setProblemCount,
                            onToggleState = viewModel::toggleProblemState
                        )
                    }

                    Spacer(modifier = Modifier.weight(1f))

                    val recentMaterials = uiState.recentMaterials
                    if (recentMaterials.isNotEmpty()) {
                        RecentMaterialsSection(
                            materials = recentMaterials,
                            onSelect = { material, subject ->
                                viewModel.selectMaterial(material, subject)
                            }
                        )
                    }
                }
            }
        }
    }

    if (showManualInputDialog) {
        ManualInputDialog(
            subjects = uiState.subjects,
            initialSubjectId = uiState.selectedSubject?.id,
            onDismiss = { showManualInputDialog = false },
            onConfirm = { subjectId, materialId, startTime, endTime ->
                viewModel.saveManualEntry(subjectId, materialId, startTime, endTime)
                showManualInputDialog = false
            }
        )
    }

    if (showMaterialPicker) {
        MaterialPickerDialog(
            subjects = uiState.subjects,
            materialsBySubject = uiState.materialsBySubject,
            initialSubjectId = uiState.selectedSubject?.id,
            onDismiss = { showMaterialPicker = false },
            onSelectSubject = { subject ->
                viewModel.selectSubject(subject)
                showMaterialPicker = false
            },
            onSelectMaterial = { material, subject ->
                viewModel.selectMaterial(material, subject)
                showMaterialPicker = false
            }
        )
    }

    uiState.pendingSessionEvaluation?.let { evaluation ->
        SessionEvaluationSheet(
            session = evaluation.session,
            initialProblemRecords = uiState.problemStates.toProblemSessionRecords(),
            onSave = { rating, note, problemRecords, problemStart, problemEnd, wrongCount ->
                viewModel.savePendingSessionEvaluation(
                    rating = rating,
                    note = note,
                    problemRecords = problemRecords,
                    problemStart = problemStart,
                    problemEnd = problemEnd,
                    wrongProblemCount = wrongCount
                )
            },
            onCancel = {
                viewModel.cancelPendingSessionEvaluation()
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MaterialSelector(
    selectedMaterial: Material?,
    selectedSubject: Subject?,
    onClick: () -> Unit
) {
    val borderColor = selectedSubject?.let { Color(it.color) }
        ?: MaterialTheme.colorScheme.outline

    ElevatedCard(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 2.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically
        ) {
            // Colored left border strip matching the selected subject
            Box(
                modifier = Modifier
                    .width(4.dp)
                    .height(64.dp)
                    .background(borderColor)
            )
            Row(
                modifier = Modifier
                    .weight(1f)
                    .padding(16.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Column {
                    Text(
                        text = selectedSubject?.name ?: stringResource(R.string.timer_select_subject),
                        style = MaterialTheme.typography.titleMedium,
                        fontWeight = FontWeight.Bold
                    )
                    if (selectedMaterial != null) {
                        Text(
                            text = selectedMaterial.name,
                            style = MaterialTheme.typography.bodyMedium,
                            color = MaterialTheme.colorScheme.onSurfaceVariant
                        )
                    }
                }
                Icon(
                    Icons.Default.ArrowDropDown,
                    contentDescription = stringResource(R.string.timer_dropdown)
                )
            }
        }
    }
}

@Composable
private fun TimerDisplay(
    time: Long,
    isRunning: Boolean,
    mode: TimerMode
) {
    val timeText = remember(time) {
        val hours = time / 3600000
        val minutes = (time % 3600000) / 60000
        val seconds = (time % 60000) / 1000

        when {
            hours > 0 -> String.format("%02d:%02d:%02d", hours, minutes, seconds)
            else -> String.format("%02d:%02d", minutes, seconds)
        }
    }

    Column(
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            text = timeText,
            fontSize = 48.sp,
            fontWeight = FontWeight.Light,
            color = if (isRunning) MaterialTheme.colorScheme.primary
                   else MaterialTheme.colorScheme.onSurface
        )

        if (isRunning) {
            Spacer(modifier = Modifier.height(4.dp))
            Text(
                text = if (mode == TimerMode.TIMER) "カウントダウン中" else stringResource(R.string.timer_studying),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun TimerControls(
    isRunning: Boolean,
    displayTime: Long,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onStop: () -> Unit
) {
    val primaryLabel = when {
        isRunning -> stringResource(R.string.timer_pause)
        displayTime > 0L -> stringResource(R.string.timer_resume)
        else -> stringResource(R.string.timer_start)
    }

    Row(
        horizontalArrangement = Arrangement.spacedBy(24.dp),
        verticalAlignment = Alignment.Top
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            if (isRunning) {
                LargeFloatingActionButton(
                    onClick = onPause,
                    containerColor = MaterialTheme.colorScheme.secondary,
                    modifier = Modifier.size(80.dp)
                ) {
                    Icon(
                        Icons.Default.Pause,
                        contentDescription = stringResource(R.string.timer_pause),
                        modifier = Modifier.size(36.dp)
                    )
                }
            } else {
                LargeFloatingActionButton(
                    onClick = onStart,
                    containerColor = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.size(80.dp)
                ) {
                    Icon(
                        Icons.Default.PlayArrow,
                        contentDescription = primaryLabel,
                        modifier = Modifier.size(36.dp)
                    )
                }
            }
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = primaryLabel,
                style = MaterialTheme.typography.labelLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }

        if (displayTime > 0) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                LargeFloatingActionButton(
                    onClick = onStop,
                    containerColor = MaterialTheme.colorScheme.error,
                    modifier = Modifier.size(80.dp)
                ) {
                    Icon(
                        Icons.Default.Stop,
                        contentDescription = stringResource(R.string.timer_stop),
                        modifier = Modifier.size(36.dp)
                    )
                }
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = stringResource(R.string.timer_stop),
                    style = MaterialTheme.typography.labelLarge,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun TimerModeSelector(
    selectedMode: TimerMode,
    countdownMinutes: Int,
    isRunning: Boolean,
    onSelectMode: (TimerMode) -> Unit,
    onSelectMinutes: (Int) -> Unit
) {
    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            FilterChip(
                selected = selectedMode == TimerMode.STOPWATCH,
                onClick = { onSelectMode(TimerMode.STOPWATCH) },
                label = { Text("ストップウォッチ") },
                enabled = !isRunning
            )
            FilterChip(
                selected = selectedMode == TimerMode.TIMER,
                onClick = { onSelectMode(TimerMode.TIMER) },
                label = { Text("タイマー") },
                enabled = !isRunning
            )
        }
        if (selectedMode == TimerMode.TIMER) {
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(15, 25, 45, 60).forEach { minutes ->
                    FilterChip(
                        selected = countdownMinutes == minutes,
                        onClick = { onSelectMinutes(minutes) },
                        label = { Text("${minutes}分") },
                        enabled = !isRunning
                    )
                }
            }
        }
    }
}

@Composable
private fun RecentMaterialsSection(
    materials: List<Pair<Material, Subject>>,
    onSelect: (Material, Subject) -> Unit
) {
    val displayMaterials = remember(materials) { materials.take(5) }

    Column {
        SectionHeader(
            title = stringResource(R.string.timer_recent_materials_title)
        )

        Spacer(modifier = Modifier.height(8.dp))

        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            items(displayMaterials) { (material, subject) ->
                AssistChip(
                    onClick = { onSelect(material, subject) },
                    label = { Text(material.name) },
                    leadingIcon = {
                        Box(
                            modifier = Modifier
                                .size(10.dp)
                                .clip(CircleShape)
                                .background(Color(subject.color))
                        )
                    }
                )
            }
        }
    }
}

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProblemProgressSection(
    problemCount: Int,
    problemStates: Map<Int, ProblemTileState>,
    onSetCount: (Int) -> Unit,
    onToggleState: (Int) -> Unit
) {
    val correctCount = problemStates.count { it.value == ProblemTileState.CORRECT }
    val wrongCount = problemStates.count { it.value == ProblemTileState.WRONG }
    val untouchedCount = problemCount - correctCount - wrongCount

    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp),
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
                Text(
                    text = "問題進捗",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                if (problemCount > 0) {
                    Badge(
                        containerColor = MaterialTheme.colorScheme.primary
                    ) {
                        Text(
                            text = "$problemCount",
                            modifier = Modifier.padding(horizontal = 4.dp)
                        )
                    }
                }
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically
            ) {
                listOf(10, 20, 50).forEach { preset ->
                    FilterChip(
                        selected = problemCount == preset,
                        onClick = { onSetCount(preset) },
                        label = { Text("$preset") }
                    )
                }
                Spacer(modifier = Modifier.weight(1f))
                IconButton(
                    onClick = { onSetCount((problemCount - 1).coerceAtLeast(0)) }
                ) {
                    Text(
                        text = "−",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                }
                Text(
                    text = "$problemCount",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                IconButton(
                    onClick = { onSetCount(problemCount + 1) }
                ) {
                    Text(
                        text = "+",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                }
            }

            if (problemCount > 0) {
                FlowRow(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    for (i in 1..problemCount) {
                        val state = problemStates[i] ?: ProblemTileState.UNTOUCHED
                        val bgColor = when (state) {
                            ProblemTileState.UNTOUCHED -> MaterialTheme.colorScheme.surfaceVariant
                            ProblemTileState.CORRECT -> Color(0xFF4CAF50)
                            ProblemTileState.WRONG -> Color(0xFFE53935)
                        }
                        val textColor = when (state) {
                            ProblemTileState.UNTOUCHED -> MaterialTheme.colorScheme.onSurfaceVariant
                            else -> Color.White
                        }
                        Box(
                            modifier = Modifier
                                .size(40.dp)
                                .clip(RoundedCornerShape(4.dp))
                                .background(bgColor)
                                .clickable { onToggleState(i) },
                            contentAlignment = Alignment.Center
                        ) {
                            Text(
                                text = "$i",
                                style = MaterialTheme.typography.labelSmall,
                                fontWeight = FontWeight.Bold,
                                color = textColor
                            )
                        }
                    }
                }

                Text(
                    text = "正解: $correctCount  不正解: $wrongCount  未着手: $untouchedCount",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SessionEvaluationSheet(
    session: com.studyapp.domain.model.StudySession,
    initialProblemRecords: List<ProblemSessionRecord>,
    onSave: (rating: Int, note: String?, problemRecords: List<ProblemSessionRecord>, problemStart: Int?, problemEnd: Int?, wrongCount: Int?) -> Unit,
    onCancel: () -> Unit
) {
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    var rating by remember { mutableStateOf(session.rating ?: 5) }
    var note by remember { mutableStateOf(session.note ?: "") }
    val effectiveProblemRecords = remember(initialProblemRecords, session.problemRecords) {
        session.problemRecords.ifEmpty { initialProblemRecords }
    }
    val subQuestionRecords = remember { mutableStateListOf<ProblemSessionRecord>() }
    val recordedNumbers = (effectiveProblemRecords + subQuestionRecords).map { it.number }
    var subQuestionNumber by remember { mutableStateOf("") }
    var subQuestionLabel by remember { mutableStateOf("") }
    var subQuestionDetail by remember { mutableStateOf("") }
    var subQuestionWrong by remember { mutableStateOf(false) }
    var problemStart by remember { mutableStateOf(session.problemStart?.toString() ?: recordedNumbers.minOrNull()?.toString().orEmpty()) }
    var problemEnd by remember { mutableStateOf(session.problemEnd?.toString() ?: recordedNumbers.maxOrNull()?.toString().orEmpty()) }
    var wrongCount by remember { mutableStateOf(session.wrongProblemCount?.toString() ?: effectiveProblemRecords.count { it.result == ProblemResult.WRONG }.takeIf { effectiveProblemRecords.isNotEmpty() }?.toString().orEmpty()) }

    ModalBottomSheet(
        onDismissRequest = onCancel,
        sheetState = sheetState
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(bottom = 32.dp)
                .verticalScroll(rememberScrollState()),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = "セッション評価",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold
            )

            Column {
                Text(
                    text = session.subjectName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                if (session.materialName.isNotBlank()) {
                    Text(
                        text = session.materialName,
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Text(
                    text = session.durationFormatted,
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "評価",
                    style = MaterialTheme.typography.labelLarge
                )
                Row(
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    for (i in 1..5) {
                        IconButton(
                            onClick = { rating = i }
                        ) {
                            Icon(
                                imageVector = if (i <= rating) Icons.Default.Star else Icons.Default.StarBorder,
                                contentDescription = "$i",
                                tint = if (i <= rating) MaterialTheme.colorScheme.primary
                                else MaterialTheme.colorScheme.onSurfaceVariant,
                                modifier = Modifier.size(32.dp)
                            )
                        }
                    }
                }
            }

            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text(
                    text = "問題進捗（任意）",
                    style = MaterialTheme.typography.labelLarge
                )
                if (effectiveProblemRecords.isNotEmpty()) {
                    Text(
                        text = "タイル入力から ${effectiveProblemRecords.size} 件を保存します",
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    OutlinedTextField(
                        value = problemStart,
                        onValueChange = { problemStart = it.filter { c -> c.isDigit() } },
                        label = { Text("開始") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = problemEnd,
                        onValueChange = { problemEnd = it.filter { c -> c.isDigit() } },
                        label = { Text("終了") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = wrongCount,
                        onValueChange = { wrongCount = it.filter { c -> c.isDigit() } },
                        label = { Text("不正解") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                }

                Text(
                    text = "小問を追加",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    OutlinedTextField(
                        value = subQuestionNumber,
                        onValueChange = { subQuestionNumber = it.filter { c -> c.isDigit() } },
                        label = { Text("大問") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                    OutlinedTextField(
                        value = subQuestionLabel,
                        onValueChange = { subQuestionLabel = it },
                        label = { Text("小問") },
                        modifier = Modifier.weight(1f),
                        singleLine = true
                    )
                }
                OutlinedTextField(
                    value = subQuestionDetail,
                    onValueChange = { subQuestionDetail = it },
                    label = { Text("小問メモ（任意）") },
                    modifier = Modifier.fillMaxWidth(),
                    singleLine = true
                )
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(
                        selected = !subQuestionWrong,
                        onClick = { subQuestionWrong = false },
                        label = { Text("正解") }
                    )
                    FilterChip(
                        selected = subQuestionWrong,
                        onClick = { subQuestionWrong = true },
                        label = { Text("不正解") }
                    )
                    Button(
                        onClick = {
                            val number = subQuestionNumber.toIntOrNull()
                            val subNumber = subQuestionLabel.trim().takeIf { it.isNotEmpty() }
                            if (number != null && number > 0 && subNumber != null) {
                                subQuestionRecords.removeAll { it.number == number && it.normalizedSubNumber == subNumber }
                                subQuestionRecords.add(
                                    ProblemSessionRecord(
                                        number = number,
                                        result = if (subQuestionWrong) ProblemResult.WRONG else ProblemResult.CORRECT,
                                        detail = subQuestionDetail.trim().takeIf { it.isNotEmpty() },
                                        subNumber = subNumber
                                    )
                                )
                                subQuestionRecords.sortWith(compareBy<ProblemSessionRecord> { it.number }.thenBy { it.normalizedSubNumber ?: "" })
                                if (problemStart.isBlank()) problemStart = number.toString()
                                if (problemEnd.isBlank() || number > (problemEnd.toIntOrNull() ?: 0)) problemEnd = number.toString()
                                if (subQuestionWrong) wrongCount = ((wrongCount.toIntOrNull() ?: 0) + 1).toString()
                                subQuestionNumber = ""
                                subQuestionLabel = ""
                                subQuestionDetail = ""
                            }
                        }
                    ) {
                        Text("追加")
                    }
                }
                if (subQuestionRecords.isNotEmpty()) {
                    Text(
                        text = subQuestionRecords.joinToString { "${it.displayNumber}:${it.result.title}" },
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            OutlinedTextField(
                value = note,
                onValueChange = { note = it },
                label = { Text("メモ（任意）") },
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp),
                maxLines = 4
            )

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = onCancel,
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("スキップ")
                }
                Button(
                    onClick = {
                        onSave(
                            rating,
                            note.takeIf { it.isNotBlank() },
                            (effectiveProblemRecords + subQuestionRecords).distinctBy { it.stableKey },
                            problemStart.toIntOrNull(),
                            problemEnd.toIntOrNull(),
                            wrongCount.toIntOrNull()
                        )
                    },
                    modifier = Modifier.weight(1f),
                    shape = RoundedCornerShape(12.dp)
                ) {
                    Text("保存")
                }
            }
        }
    }
}


private fun Map<Int, ProblemTileState>.toProblemSessionRecords(): List<ProblemSessionRecord> =
    entries.mapNotNull { (number, state) ->
        val result = when (state) {
            ProblemTileState.CORRECT -> ProblemResult.CORRECT
            ProblemTileState.WRONG -> ProblemResult.WRONG
            ProblemTileState.UNTOUCHED -> return@mapNotNull null
        }
        ProblemSessionRecord(number = number, result = result)
    }.sortedBy { it.number }
