package com.studyapp.presentation.timer

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDropDown
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material3.AssistChip
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedCard
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.hilt.navigation.compose.hiltViewModel
import com.studyapp.domain.model.Material
import com.studyapp.domain.model.Subject
import com.studyapp.R

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun TimerScreen(
    viewModel: TimerViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
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
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                ),
                actions = {
                    IconButton(onClick = { showManualInputDialog = true }) {
                        Icon(
                            Icons.Default.Edit,
                            contentDescription = stringResource(R.string.timer_manual_input_title),
                            tint = MaterialTheme.colorScheme.onPrimary
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
                        .padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    MaterialSelector(
                        selectedMaterial = uiState.selectedMaterial,
                        selectedSubject = uiState.selectedSubject,
                        onClick = { showMaterialPicker = true }
                    )
                    
                    Spacer(modifier = Modifier.height(32.dp))
                    
                    TimerDisplay(
                        time = uiState.elapsedTime,
                        isRunning = uiState.isRunning
                    )
                    
                    Spacer(modifier = Modifier.height(48.dp))
                    
                    TimerControls(
                        isRunning = uiState.isRunning,
                        elapsedTime = uiState.elapsedTime,
                        onStart = { viewModel.startTimer() },
                        onPause = { viewModel.pauseTimer() },
                        onStop = { viewModel.stopTimer() }
                    )
                    
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
            onDismiss = { showManualInputDialog = false },
            onConfirm = { subjectId, materialId, durationMinutes ->
                viewModel.saveManualEntry(subjectId, materialId, durationMinutes)
                showManualInputDialog = false
            }
        )
    }
    
    if (showMaterialPicker) {
        MaterialPickerDialog(
            subjects = uiState.subjects,
            materialsBySubject = uiState.materialsBySubject,
            onDismiss = { showMaterialPicker = false },
            onSelect = { material, subject ->
                viewModel.selectMaterial(material, subject)
                showMaterialPicker = false
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
    OutlinedCard(
        onClick = onClick,
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(12.dp)
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
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

@Composable
private fun TimerDisplay(
    time: Long,
    isRunning: Boolean
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
            fontSize = 72.sp,
            fontWeight = FontWeight.Light,
            color = if (isRunning) MaterialTheme.colorScheme.primary
                   else MaterialTheme.colorScheme.onSurface
        )
        
        if (isRunning) {
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = stringResource(R.string.timer_studying),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.primary
            )
        }
    }
}

@Composable
private fun TimerControls(
    isRunning: Boolean,
    elapsedTime: Long,
    onStart: () -> Unit,
    onPause: () -> Unit,
    onStop: () -> Unit
) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        if (isRunning) {
            FloatingActionButton(
                onClick = onPause,
                containerColor = MaterialTheme.colorScheme.secondary,
                modifier = Modifier.size(72.dp)
            ) {
                Icon(
                    Icons.Default.Pause,
                    contentDescription = stringResource(R.string.timer_pause),
                    modifier = Modifier.size(32.dp)
                )
            }
        } else {
            FloatingActionButton(
                onClick = onStart,
                containerColor = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(72.dp)
            ) {
                Icon(
                    Icons.Default.PlayArrow,
                    contentDescription = stringResource(R.string.timer_start),
                    modifier = Modifier.size(32.dp)
                )
            }
        }
        
        if (elapsedTime > 0) {
            FloatingActionButton(
                onClick = onStop,
                containerColor = MaterialTheme.colorScheme.error,
                modifier = Modifier.size(72.dp)
            ) {
                Icon(
                    Icons.Default.Stop,
                    contentDescription = stringResource(R.string.timer_stop),
                    modifier = Modifier.size(32.dp)
                )
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
        Text(
            text = stringResource(R.string.timer_recent_materials_title),
            style = MaterialTheme.typography.titleSmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
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
                                .size(12.dp)
                                .padding(2.dp)
                        )
                    }
                )
            }
        }
    }
}