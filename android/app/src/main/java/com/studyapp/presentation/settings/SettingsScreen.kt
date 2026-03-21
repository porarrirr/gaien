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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.HorizontalDivider
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.input.PasswordVisualTransformation

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun SettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
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
                    containerColor = MaterialTheme.colorScheme.surface,
                    titleContentColor = MaterialTheme.colorScheme.onSurface
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
            
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            
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
            
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            SyncSection(
                syncAuthenticated = uiState.syncAuthenticated,
                syncAccountEmail = uiState.syncAccountEmail,
                syncEmail = uiState.syncEmail,
                syncPassword = uiState.syncPassword,
                syncInProgress = uiState.syncInProgress,
                lastSyncAt = uiState.lastSyncAt,
                syncError = uiState.syncError,
                onSyncEmailChange = viewModel::setSyncEmail,
                onSyncPasswordChange = viewModel::setSyncPassword,
                onSignIn = viewModel::signInToSync,
                onCreateAccount = viewModel::createSyncAccount,
                onSignOut = viewModel::signOutOfSync,
                onSyncNow = viewModel::syncNow,
                onImportLocal = viewModel::importLocalDataToCloud
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            
            DataSection(
                totalSessions = uiState.totalSessions,
                totalStudyTime = uiState.totalStudyTime,
                onExport = { showExportDialog = true },
                onImport = { showImportDialog = true },
                onDeleteData = { showDeleteDataDialog = true }
            )
            
            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            
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

@Composable
private fun SyncSection(
    syncAuthenticated: Boolean,
    syncAccountEmail: String?,
    syncEmail: String,
    syncPassword: String,
    syncInProgress: Boolean,
    lastSyncAt: Long?,
    syncError: String?,
    onSyncEmailChange: (String) -> Unit,
    onSyncPasswordChange: (String) -> Unit,
    onSignIn: () -> Unit,
    onCreateAccount: () -> Unit,
    onSignOut: () -> Unit,
    onSyncNow: () -> Unit,
    onImportLocal: () -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "クラウド同期",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )

        Spacer(modifier = Modifier.height(16.dp))

        Card(
            modifier = Modifier.fillMaxWidth(),
            elevation = CardDefaults.cardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                if (syncAuthenticated) {
                    Text("接続中: ${syncAccountEmail ?: "-"}")
                    Text("最終同期: ${lastSyncAt?.let { SimpleDateFormat("M/d HH:mm", Locale.JAPANESE).format(Date(it)) } ?: "未同期"}")
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = onSyncNow,
                            enabled = !syncInProgress,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text(if (syncInProgress) "同期中..." else "今すぐ同期")
                        }
                        OutlinedButton(
                            onClick = onImportLocal,
                            enabled = !syncInProgress,
                            modifier = Modifier.weight(1f)
                        ) {
                            Text("ローカルをアップロード")
                        }
                    }
                    OutlinedButton(
                        onClick = onSignOut,
                        enabled = !syncInProgress,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("サインアウト")
                    }
                } else {
                    OutlinedTextField(
                        value = syncEmail,
                        onValueChange = onSyncEmailChange,
                        label = { Text("メールアドレス") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = syncPassword,
                        onValueChange = onSyncPasswordChange,
                        label = { Text("パスワード") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Button(
                            onClick = onSignIn,
                            modifier = Modifier.weight(1f),
                            enabled = !syncInProgress && syncEmail.isNotBlank() && syncPassword.isNotBlank()
                        ) {
                            Text("サインイン")
                        }
                        OutlinedButton(
                            onClick = onCreateAccount,
                            modifier = Modifier.weight(1f),
                            enabled = !syncInProgress && syncEmail.isNotBlank() && syncPassword.isNotBlank()
                        ) {
                            Text("アカウント作成")
                        }
                    }
                }

                syncError?.takeIf { it.isNotBlank() }?.let { error ->
                    Text(
                        text = error,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall
                    )
                }

                Text(
                    text = "権限エラーが続く場合は、Firebase側のFirestoreルール反映状況も確認してください。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
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
                                        .size(28.dp)
                                        .clip(CircleShape)
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
                    HorizontalDivider()
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
