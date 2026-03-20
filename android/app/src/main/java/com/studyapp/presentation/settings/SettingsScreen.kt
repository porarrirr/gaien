package com.studyapp.presentation.settings

import android.Manifest
import android.app.TimePickerDialog
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import androidx.hilt.navigation.compose.hiltViewModel
import java.util.Locale

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsState()
    val context = LocalContext.current
    var showExportDialog by remember { mutableStateOf(false) }
    var showImportDialog by remember { mutableStateOf(false) }
    var showDeleteDataDialog by remember { mutableStateOf(false) }
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            viewModel.setReminderEnabled(true)
        }
    }
    val reminderTimeParts = remember(uiState.reminderTime) {
        val parts = uiState.reminderTime.split(":")
        val hour = parts.getOrNull(0)?.toIntOrNull() ?: 19
        val minute = parts.getOrNull(1)?.toIntOrNull() ?: 0
        hour to minute
    }
    val reminderTimePickerDialog = remember(context, reminderTimeParts) {
        TimePickerDialog(
            context,
            { _, hour, minute ->
                viewModel.setReminderTime(
                    String.format(Locale.ROOT, "%02d:%02d", hour, minute)
                )
            },
            reminderTimeParts.first,
            reminderTimeParts.second,
            true
        )
    }
    
    Scaffold(
        topBar = {
            TopAppBar(
                title = { 
                    Text(
                        text = "設定",
                        fontWeight = FontWeight.Bold
                    )
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = MaterialTheme.colorScheme.primary,
                    titleContentColor = MaterialTheme.colorScheme.onPrimary
                )
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
        ) {
            ThemeSection(
                selectedColorTheme = uiState.selectedColorTheme,
                selectedThemeMode = uiState.selectedThemeMode,
                onColorThemeChange = { viewModel.setColorTheme(it) },
                onThemeModeChange = { viewModel.setThemeMode(it) }
            )
            
            Divider(modifier = Modifier.padding(vertical = 8.dp))
            
            NotificationSection(
                reminderEnabled = uiState.reminderEnabled,
                reminderTime = uiState.reminderTime,
                onReminderEnabledChange = { enabled ->
                    val shouldRequestNotificationPermission =
                        enabled &&
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
                            ContextCompat.checkSelfPermission(
                                context,
                                Manifest.permission.POST_NOTIFICATIONS
                            ) != PackageManager.PERMISSION_GRANTED

                    if (shouldRequestNotificationPermission) {
                        notificationPermissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                    } else {
                        viewModel.setReminderEnabled(enabled)
                    }
                },
                onReminderTimeClick = {
                    reminderTimePickerDialog.show()
                }
            )
            
            Divider(modifier = Modifier.padding(vertical = 8.dp))
            
            DataSection(
                totalSessions = uiState.totalSessions,
                totalStudyTime = uiState.totalStudyTime,
                onExport = { showExportDialog = true },
                onImport = { showImportDialog = true },
                onDeleteData = { showDeleteDataDialog = true }
            )
            
            Divider(modifier = Modifier.padding(vertical = 8.dp))
            
            AboutSection(
                context = context
            )
        }
    }
    
    if (showExportDialog) {
        ExportDialog(
            onDismiss = { showExportDialog = false },
            onExport = { format ->
                viewModel.exportData(context, format)
                showExportDialog = false
            }
        )
    }
    
    if (showImportDialog) {
        ImportDialog(
            onDismiss = { showImportDialog = false },
            onImport = { uri ->
                viewModel.importData(context, uri)
                showImportDialog = false
            }
        )
    }
    
    if (showDeleteDataDialog) {
        DeleteDataDialog(
            onDismiss = { showDeleteDataDialog = false },
            onConfirm = {
                viewModel.deleteAllData()
                showDeleteDataDialog = false
            }
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ThemeSection(
    selectedColorTheme: ColorTheme,
    selectedThemeMode: ThemeMode,
    onColorThemeChange: (ColorTheme) -> Unit,
    onThemeModeChange: (ThemeMode) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "テーマ設定",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Text(
                    text = "カラーテーマ",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    ColorTheme.entries.forEach { theme ->
                        FilterChip(
                            selected = selectedColorTheme == theme,
                            onClick = { onColorThemeChange(theme) },
                            label = { Text(theme.displayName) },
                            leadingIcon = {
                                Box(
                                    modifier = Modifier
                                        .size(12.dp)
                                        .background(androidx.compose.ui.graphics.Color(theme.colorValue))
                                )
                            }
                        )
                    }
                }
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Text(
                    text = "表示モード",
                    style = MaterialTheme.typography.labelMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.height(8.dp))
                
                ThemeMode.entries.forEach { mode ->
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        RadioButton(
                            selected = selectedThemeMode == mode,
                            onClick = { onThemeModeChange(mode) }
                        )
                        Spacer(modifier = Modifier.width(8.dp))
                        Text(
                            text = when (mode) {
                                ThemeMode.LIGHT -> "ライトモード"
                                ThemeMode.DARK -> "ダークモード"
                                ThemeMode.SYSTEM -> "システム設定に従う"
                            }
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun NotificationSection(
    reminderEnabled: Boolean,
    reminderTime: String,
    onReminderEnabledChange: (Boolean) -> Unit,
    onReminderTimeClick: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "通知設定",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column {
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(16.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Icon(
                            Icons.Default.Notifications,
                            contentDescription = null,
                            tint = MaterialTheme.colorScheme.primary
                        )
                        Spacer(modifier = Modifier.width(16.dp))
                        Text("学習リマインダー")
                    }
                    Switch(
                        checked = reminderEnabled,
                        onCheckedChange = onReminderEnabledChange
                    )
                }
                
                if (reminderEnabled) {
                    Divider()
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable(onClick = onReminderTimeClick)
                            .padding(16.dp),
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Text("通知時刻")
                        Text(
                            text = reminderTime,
                            fontWeight = FontWeight.Bold,
                            color = MaterialTheme.colorScheme.primary
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun DataSection(
    totalSessions: Int,
    totalStudyTime: Long,
    onExport: () -> Unit,
    onImport: () -> Unit,
    onDeleteData: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "データ管理",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("学習記録数")
                    Text(
                        text = "${totalSessions}件",
                        fontWeight = FontWeight.Bold
                    )
                }
                
                Spacer(modifier = Modifier.height(8.dp))
                
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Text("総学習時間")
                    val hours = totalStudyTime / 60
                    val minutes = totalStudyTime % 60
                    Text(
                        text = "${hours}時間${minutes}分",
                        fontWeight = FontWeight.Bold
                    )
                }
            }
        }
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            OutlinedButton(
                onClick = onExport,
                modifier = Modifier.weight(1f)
            ) {
                Icon(Icons.Default.Upload, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("エクスポート")
            }
            
            OutlinedButton(
                onClick = onImport,
                modifier = Modifier.weight(1f)
            ) {
                Icon(Icons.Default.Download, contentDescription = null)
                Spacer(modifier = Modifier.width(8.dp))
                Text("インポート")
            }
        }
        
        Spacer(modifier = Modifier.height(8.dp))
        
        OutlinedButton(
            onClick = onDeleteData,
            modifier = Modifier.fillMaxWidth(),
            colors = ButtonDefaults.outlinedButtonColors(
                contentColor = MaterialTheme.colorScheme.error
            )
        ) {
            Icon(Icons.Default.DeleteForever, contentDescription = null)
            Spacer(modifier = Modifier.width(8.dp))
            Text("全データを削除")
        }
    }
}

@Composable
private fun AboutSection(
    context: Context
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "このアプリについて",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        
        Spacer(modifier = Modifier.height(16.dp))
        
        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp)
            ) {
                Text(
                    text = "StudyApp",
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    text = "バージョン 1.0.0",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                
                Spacer(modifier = Modifier.height(16.dp))
                
                Text(
                    text = "学習記録管理アプリ。学習時間の記録、目標設定、テスト管理をサポートします。",
                    style = MaterialTheme.typography.bodyMedium
                )
            }
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ExportDialog(
    onDismiss: () -> Unit,
    onExport: (String) -> Unit
) {
    var selectedFormat by remember { mutableStateOf("json") }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("データをエクスポート") },
        text = {
            Column {
                Text("出力形式を選択してください")
                Spacer(modifier = Modifier.height(16.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    FilterChip(
                        selected = selectedFormat == "json",
                        onClick = { selectedFormat = "json" },
                        label = { Text("JSON") }
                    )
                    FilterChip(
                        selected = selectedFormat == "csv",
                        onClick = { selectedFormat = "csv" },
                        label = { Text("CSV") }
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = { onExport(selectedFormat) }) {
                Text("エクスポート")
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
private fun ImportDialog(
    onDismiss: () -> Unit,
    onImport: (Uri) -> Unit
) {
    var selectedUri by remember { mutableStateOf<Uri?>(null) }
    val openDocumentLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.OpenDocument()
    ) { uri ->
        selectedUri = uri
    }
    
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("データをインポート") },
        text = {
            Column {
                Text("JSONファイルを選択してください")
                Spacer(modifier = Modifier.height(16.dp))
                Button(
                    onClick = {
                        openDocumentLauncher.launch(arrayOf("application/json"))
                    }
                ) {
                    Text("ファイルを選択")
                }
                selectedUri?.let { uri ->
                    Spacer(modifier = Modifier.height(12.dp))
                    Text(
                        text = uri.lastPathSegment ?: uri.toString(),
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }
        },
        confirmButton = {
            TextButton(
                onClick = { selectedUri?.let { onImport(it) } },
                enabled = selectedUri != null
            ) {
                Text("インポート")
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
private fun DeleteDataDialog(
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("データ削除") },
        text = { 
            Text("すべての学習記録、教材、科目、テスト予定が削除されます。この操作は取り消せません。") 
        },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = MaterialTheme.colorScheme.error
                )
            ) {
                Text("削除")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss) {
                Text("キャンセル")
            }
        }
    )
}
