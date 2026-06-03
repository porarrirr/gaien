package com.studyapp.presentation.timer

import androidx.compose.foundation.BorderStroke
import android.content.Intent
import android.content.res.Configuration
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.StarBorder
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Badge
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.draw.clip
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
import com.studyapp.presentation.theme.toSubjectColor
import com.studyapp.R

private fun formatTimeMillis(time: Long): String {
    val hours = time / 3600000
    val minutes = (time % 3600000) / 60000
    val seconds = (time % 60000) / 1000
    return if (hours > 0) {
        String.format("%02d:%02d:%02d", hours, minutes, seconds)
    } else {
        String.format("%02d:%02d", minutes, seconds)
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimerScreen(
    viewModel: TimerViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val configuration = LocalConfiguration.current
    val context = LocalContext.current
    val theme = TimerAmbientTheme.current()
    var showManualInputDialog by remember { mutableStateOf(false) }
    var showMaterialPicker by remember { mutableStateOf(false) }

    LaunchedEffect(viewModel) {
        viewModel.openDndSettings.collect {
            context.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
        }
    }

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
    val showLandscape = configuration.orientation == Configuration.ORIENTATION_LANDSCAPE &&
        uiState.isRunning &&
        configuration.screenHeightDp < 520

    if (showLandscape && !uiState.isLoading && uiState.error == null) {
        LandscapeTimerContent(
            preset = uiState.landscapeTimerDisplayPreset,
            timeText = formatTimeMillis(displayTime),
            modeLabel = if (uiState.timerMode == TimerMode.TIMER) "タイマー" else "ストップウォッチ",
            progress = progress.coerceIn(0f, 1f),
            isRunning = uiState.isRunning,
            timerMode = uiState.timerMode,
            problemStates = uiState.problemStates,
            problemCount = uiState.problemCount,
            onPauseToggle = {
                if (uiState.isRunning) viewModel.pauseTimer() else viewModel.startTimer()
            },
            onStop = viewModel::stopTimer,
            onProblemToggle = viewModel::toggleProblemState
        )
        return
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(theme.backgroundTop, theme.backgroundBottom)
                )
            )
    ) {
    Scaffold(
        containerColor = Color.Transparent,
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = stringResource(R.string.timer_screen_title),
                        fontWeight = FontWeight.Bold,
                        color = theme.foreground
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Color.Transparent,
                    titleContentColor = theme.foreground
                )
            )
        },
        bottomBar = {
            ManualEntryButton(
                onClick = { showManualInputDialog = true },
                modifier = Modifier
                    .fillMaxWidth()
                    .background(theme.bottomBarBackground)
                    .padding(horizontal = 12.dp, vertical = 10.dp)
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
                        .padding(horizontal = 12.dp, vertical = 12.dp)
                        .verticalScroll(rememberScrollState()),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp)
                ) {
                    TimerSelectionPanel(
                        selectedMaterial = uiState.selectedMaterial,
                        selectedSubject = uiState.selectedSubject,
                        hasSubjects = uiState.subjects.isNotEmpty(),
                        onClick = { showMaterialPicker = true }
                    )

                    QuickSelectionSection(
                        subjects = uiState.subjects,
                        selectedSubject = uiState.selectedSubject,
                        recentMaterials = uiState.recentMaterials,
                        selectedMaterial = uiState.selectedMaterial,
                        onSelectSubject = viewModel::selectSubject,
                        onSelectMaterial = { material, subject ->
                            viewModel.selectMaterial(material, subject)
                        }
                    )

                    TimerPanel(
                        selectedMode = uiState.timerMode,
                        countdownMinutes = uiState.countdownMinutes,
                        isRunning = uiState.isRunning,
                        displayTime = displayTime,
                        progress = progress,
                        onSelectMode = viewModel::setTimerMode,
                        onSelectMinutes = viewModel::setCountdownMinutes,
                        onStart = viewModel::startTimer,
                        onPause = viewModel::pauseTimer,
                        onStop = viewModel::stopTimer
                    )

                    ProblemProgressSection(
                        problemCount = uiState.problemCount,
                        problemStates = uiState.problemStates,
                        selectedMaterial = uiState.selectedMaterial,
                        onSetCount = viewModel::setProblemCount,
                        onToggleState = viewModel::toggleProblemState
                    )

                    Spacer(modifier = Modifier.height(12.dp))
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

@Composable
private fun TimerSelectionPanel(
    selectedMaterial: Material?,
    selectedSubject: Subject?,
    hasSubjects: Boolean,
    onClick: () -> Unit
) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            TimerSelectionRow(
                label = "科目",
                value = selectedSubject?.name ?: if (hasSubjects) "科目を選択" else "科目を追加してください",
                accent = selectedSubject?.let { Color(it.color) } ?: Color(0xFF1D7FEA),
                icon = null,
                onClick = onClick
            )
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(1.dp)
                    .background(MaterialTheme.colorScheme.outlineVariant.copy(alpha = 0.65f))
            )
            TimerSelectionRow(
                label = "教材",
                value = selectedMaterial?.name ?: "なし",
                accent = MaterialTheme.colorScheme.primary,
                icon = Icons.Default.Book,
                onClick = onClick
            )
        }
    }
}

@Composable
private fun TimerSelectionRow(
    label: String,
    value: String,
    accent: Color,
    icon: androidx.compose.ui.graphics.vector.ImageVector?,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(62.dp)
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Box(
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(accent.copy(alpha = 0.13f)),
            contentAlignment = Alignment.Center
        ) {
            if (icon == null) {
                Box(
                    modifier = Modifier
                        .size(18.dp)
                        .clip(CircleShape)
                        .background(accent)
                )
            } else {
                Icon(
                    icon,
                    contentDescription = null,
                    tint = accent,
                    modifier = Modifier.size(22.dp)
                )
            }
        }
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = label,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = value,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = stringResource(R.string.timer_dropdown),
            tint = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.size(22.dp)
        )
    }
}

@Composable
private fun QuickSelectionSection(
    subjects: List<Subject>,
    selectedSubject: Subject?,
    recentMaterials: List<Pair<Material, Subject>>,
    selectedMaterial: Material?,
    onSelectSubject: (Subject) -> Unit,
    onSelectMaterial: (Material, Subject) -> Unit
) {
    if (subjects.isEmpty() && recentMaterials.isEmpty()) return

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        if (subjects.isNotEmpty()) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(subjects.take(5)) { subject ->
                    TimerQuickChip(
                        title = subject.name,
                        selected = selectedSubject?.id == subject.id,
                        leadingColor = subject.color.toSubjectColor(),
                        onClick = { onSelectSubject(subject) }
                    )
                }
            }
        }
        if (recentMaterials.isNotEmpty()) {
            LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                items(recentMaterials.take(4)) { (material, subject) ->
                    TimerQuickChip(
                        title = material.name,
                        selected = selectedMaterial?.id == material.id,
                        leadingColor = MaterialTheme.colorScheme.primary,
                        onClick = { onSelectMaterial(material, subject) }
                    )
                }
            }
        }
    }
}

@Composable
private fun TimerQuickChip(
    title: String,
    selected: Boolean,
    leadingColor: Color,
    onClick: () -> Unit
) {
    AssistChip(
        onClick = onClick,
        label = {
            Text(
                text = title,
                fontWeight = FontWeight.Bold,
                maxLines = 1
            )
        },
        leadingIcon = {
            Box(
                modifier = Modifier
                    .size(10.dp)
                    .clip(CircleShape)
                    .background(if (selected) Color.White else leadingColor)
            )
        },
        colors = androidx.compose.material3.AssistChipDefaults.assistChipColors(
            containerColor = if (selected) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surface,
            labelColor = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary,
            leadingIconContentColor = if (selected) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.primary
        ),
        border = BorderStroke(
            1.dp,
            MaterialTheme.colorScheme.primary.copy(alpha = if (selected) 0f else 0.3f)
        )
    )
}

@Composable
private fun TimerPanel(
    selectedMode: TimerMode,
    countdownMinutes: Int,
    isRunning: Boolean,
    displayTime: Long,
    progress: Float,
    onSelectMode: (TimerMode) -> Unit,
    onSelectMinutes: (Int) -> Unit,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onStop: () -> Unit
) {
    ElevatedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.elevatedCardColors(
            containerColor = MaterialTheme.colorScheme.surface
        ),
        elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)
    ) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            TimerModeSelector(
                selectedMode = selectedMode,
                countdownMinutes = countdownMinutes,
                isRunning = isRunning,
                onSelectMode = onSelectMode,
                onSelectMinutes = onSelectMinutes
            )
            PulsingEffect(isPulsing = isRunning) {
                CircularProgressRing(
                    progress = if (displayTime > 0L || isRunning) progress.coerceIn(0f, 1f) else 0f,
                    size = 204.dp,
                    strokeWidth = 13.dp,
                    showPercentage = false,
                    centerContent = {
                        TimerDisplay(
                            time = displayTime,
                            isRunning = isRunning,
                            mode = selectedMode
                        )
                    }
                )
            }
            TimerControls(
                isRunning = isRunning,
                displayTime = displayTime,
                onStart = onStart,
                onPause = onPause,
                onStop = onStop
            )
        }
    }
}

@Composable
private fun ManualEntryButton(
    onClick: () -> Unit,
    modifier: Modifier = Modifier
) {
    Button(
        onClick = onClick,
        modifier = modifier.height(54.dp),
        shape = RoundedCornerShape(8.dp),
        colors = ButtonDefaults.buttonColors(
            containerColor = Color(0xFF2563EB),
            contentColor = Color.White
        )
    ) {
        Icon(
            Icons.Default.Edit,
            contentDescription = null,
            modifier = Modifier.size(20.dp)
        )
        Spacer(modifier = Modifier.width(10.dp))
        Text(
            text = stringResource(R.string.timer_manual_input_title),
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
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
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(4.dp)
    ) {
        Text(
            text = if (isRunning) "記録中" else "待機中",
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
            color = if (isRunning) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurfaceVariant
        )
        Text(
            text = timeText,
            fontSize = 46.sp,
            fontWeight = FontWeight.Light,
            color = MaterialTheme.colorScheme.onSurface
        )
        Text(
            text = if (mode == TimerMode.TIMER) "カウントダウン" else "経過を記録中",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
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
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Button(
            onClick = if (isRunning) onPause else onStart,
            modifier = Modifier
                .weight(1f)
                .height(56.dp),
            shape = RoundedCornerShape(8.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.primary,
                contentColor = MaterialTheme.colorScheme.onPrimary
            )
        ) {
            Icon(
                if (isRunning) Icons.Default.Pause else Icons.Default.PlayArrow,
                contentDescription = primaryLabel,
                modifier = Modifier.size(22.dp)
            )
            Spacer(modifier = Modifier.width(10.dp))
            Text(
                text = primaryLabel,
                style = MaterialTheme.typography.titleMedium,
                fontWeight = FontWeight.Bold
            )
        }

        Button(
            onClick = onStop,
            enabled = displayTime > 0L,
            modifier = Modifier
                .width(66.dp)
                .height(56.dp),
            shape = RoundedCornerShape(8.dp),
            colors = ButtonDefaults.buttonColors(
                containerColor = MaterialTheme.colorScheme.error,
                contentColor = MaterialTheme.colorScheme.onError,
                disabledContainerColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.18f),
                disabledContentColor = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.42f)
            )
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Default.Stop,
                    contentDescription = stringResource(R.string.timer_stop),
                    modifier = Modifier.size(18.dp)
                )
                Text(
                    text = stringResource(R.string.timer_stop),
                    style = MaterialTheme.typography.labelSmall,
                    fontWeight = FontWeight.Bold
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

@OptIn(ExperimentalLayoutApi::class)
@Composable
private fun ProblemProgressSection(
    problemCount: Int,
    problemStates: Map<Int, ProblemTileState>,
    selectedMaterial: Material?,
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

            if (selectedMaterial == null) {
                Text(
                    text = "教材を選択すると問題進捗を入力できます",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth(),
                )
            } else {
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
