package com.studyapp.presentation.settings

import android.net.Uri
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
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.domain.model.ColorTheme
import com.studyapp.domain.model.LandscapeTimerDisplayPreset
import com.studyapp.domain.model.ThemeMode
import com.studyapp.domain.model.TimerNotificationDisplayPreset
import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
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
    val actions = rememberSettingsScreenActions(uiState, viewModel)
    var showExportDialog by remember { mutableStateOf(false) }
    var showImportDialog by remember { mutableStateOf(false) }
    var showDeleteDataDialog by remember { mutableStateOf(false) }
    var showDeleteAccountDialog by remember { mutableStateOf(false) }
    var showDebugLog by remember { mutableStateOf(false) }

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

            TimerDisplaySection(
                landscapePreset = uiState.landscapeTimerDisplayPreset,
                notificationRichEnabled = uiState.timerNotificationRichEnabled,
                notificationPreset = uiState.timerNotificationDisplayPreset,
                onLandscapePresetChange = viewModel::setLandscapeTimerDisplayPreset,
                onNotificationRichEnabledChange = viewModel::setTimerNotificationRichEnabled,
                onNotificationPresetChange = viewModel::setTimerNotificationDisplayPreset
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            FocusModeSection(
                promptOnTimerStart = uiState.focusModePromptOnTimerStart,
                onPromptOnTimerStartChange = viewModel::setFocusModePromptOnTimerStart
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))
            
            NotificationSection(
                reminderEnabled = uiState.reminderEnabled,
                reminderTime = uiState.reminderTime,
                onReminderEnabledChange = actions.onReminderEnabledChange,
                onReminderTimeClick = actions.onReminderTimeClick
            )

            HorizontalDivider(modifier = Modifier.padding(vertical = 8.dp))

            SyncSection(
                syncAuthenticated = uiState.syncAuthenticated,
                syncAccountEmail = uiState.syncAccountEmail,
                signInEmail = uiState.signInEmail,
                signInPassword = uiState.signInPassword,
                createEmail = uiState.createEmail,
                createPassword = uiState.createPassword,
                syncInProgress = uiState.syncInProgress,
                lastSyncAt = uiState.lastSyncAt,
                syncError = uiState.syncError,
                onSignInEmailChange = viewModel::setSignInEmail,
                onSignInPasswordChange = viewModel::setSignInPassword,
                onCreateEmailChange = viewModel::setCreateEmail,
                onCreatePasswordChange = viewModel::setCreatePassword,
                onSignIn = viewModel::signInToSync,
                onCreateAccount = viewModel::createSyncAccount,
                onSendPasswordReset = viewModel::sendPasswordReset,
                onSignOut = viewModel::signOutOfSync,
                onDeleteAccount = { showDeleteAccountDialog = true },
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
            
            AboutSection(onShowDebugLog = { showDebugLog = true })
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

    if (showDeleteAccountDialog) {
        DeleteAccountDialog(
            password = uiState.accountDeletionPassword,
            onPasswordChange = viewModel::setAccountDeletionPassword,
            onDismiss = {
                viewModel.setAccountDeletionPassword("")
                showDeleteAccountDialog = false
            },
            onConfirm = {
                viewModel.deleteSyncAccount()
                showDeleteAccountDialog = false
            }
        )
    }

    if (showDebugLog) {
        DebugLogSheet(
            logs = uiState.debugLogs,
            onDismiss = { showDebugLog = false },
            onClear = { viewModel.clearDebugLogs() }
        )
    }
}

@Composable
private fun SyncSection(
    syncAuthenticated: Boolean,
    syncAccountEmail: String?,
    signInEmail: String,
    signInPassword: String,
    createEmail: String,
    createPassword: String,
    syncInProgress: Boolean,
    lastSyncAt: Long?,
    syncError: String?,
    onSignInEmailChange: (String) -> Unit,
    onSignInPasswordChange: (String) -> Unit,
    onCreateEmailChange: (String) -> Unit,
    onCreatePasswordChange: (String) -> Unit,
    onSignIn: () -> Unit,
    onCreateAccount: () -> Unit,
    onSendPasswordReset: () -> Unit,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
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
                    OutlinedButton(
                        onClick = onDeleteAccount,
                        enabled = !syncInProgress,
                        modifier = Modifier.fillMaxWidth(),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = MaterialTheme.colorScheme.error
                        )
                    ) {
                        Text("アカウントを削除")
                    }
                } else {
                    Text(
                        text = "サインイン",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                    OutlinedTextField(
                        value = signInEmail,
                        onValueChange = onSignInEmailChange,
                        label = { Text("メールアドレス") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = signInPassword,
                        onValueChange = onSignInPasswordChange,
                        label = { Text("パスワード") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                    TextButton(
                        onClick = onSendPasswordReset,
                        enabled = !syncInProgress && signInEmail.isNotBlank()
                    ) {
                        Text("パスワードをお忘れですか？")
                    }
                    Button(
                        onClick = onSignIn,
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !syncInProgress && signInEmail.isNotBlank() && signInPassword.isNotBlank()
                    ) {
                        Text("サインイン")
                    }

                    HorizontalDivider()

                    Text(
                        text = "アカウント作成",
                        style = MaterialTheme.typography.titleSmall,
                        fontWeight = FontWeight.SemiBold
                    )
                    OutlinedTextField(
                        value = createEmail,
                        onValueChange = onCreateEmailChange,
                        label = { Text("メールアドレス") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedTextField(
                        value = createPassword,
                        onValueChange = onCreatePasswordChange,
                        label = { Text("パスワード") },
                        singleLine = true,
                        visualTransformation = PasswordVisualTransformation(),
                        modifier = Modifier.fillMaxWidth()
                    )
                    OutlinedButton(
                        onClick = onCreateAccount,
                        modifier = Modifier.fillMaxWidth(),
                        enabled = !syncInProgress && createEmail.isNotBlank() && createPassword.isNotBlank()
                    ) {
                        Text("アカウント作成")
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
                            label = { Text(theme.title) },
                            leadingIcon = {
                                Box(
                                    modifier = Modifier
                                        .size(28.dp)
                                        .clip(CircleShape)
                                        .background(androidx.compose.ui.graphics.Color(0xFF000000 or theme.hex))
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
private fun TimerDisplaySection(
    landscapePreset: LandscapeTimerDisplayPreset,
    notificationRichEnabled: Boolean,
    notificationPreset: TimerNotificationDisplayPreset,
    onLandscapePresetChange: (LandscapeTimerDisplayPreset) -> Unit,
    onNotificationRichEnabledChange: (Boolean) -> Unit,
    onNotificationPresetChange: (TimerNotificationDisplayPreset) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "横向きタイマーの表示",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                LandscapeTimerDisplayPreset.entries.forEach { preset ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onLandscapePresetChange(preset) },
                        horizontalArrangement = Arrangement.SpaceBetween,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(preset.title, fontWeight = FontWeight.SemiBold)
                            Text(
                                preset.settingsDescription,
                                style = MaterialTheme.typography.bodySmall,
                                color = MaterialTheme.colorScheme.onSurfaceVariant
                            )
                        }
                        RadioButton(
                            selected = landscapePreset == preset,
                            onClick = { onLandscapePresetChange(preset) }
                        )
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "タイマー通知の表示",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("リッチ通知を使用")
                    Switch(
                        checked = notificationRichEnabled,
                        onCheckedChange = onNotificationRichEnabledChange
                    )
                }
                if (notificationRichEnabled) {
                    TimerNotificationDisplayPreset.entries.forEach { preset ->
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable { onNotificationPresetChange(preset) },
                            horizontalArrangement = Arrangement.SpaceBetween,
                            verticalAlignment = Alignment.CenterVertically
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(preset.title, fontWeight = FontWeight.SemiBold)
                                Text(
                                    preset.settingsDescription,
                                    style = MaterialTheme.typography.bodySmall,
                                    color = MaterialTheme.colorScheme.onSurfaceVariant
                                )
                            }
                            RadioButton(
                                selected = notificationPreset == preset,
                                onClick = { onNotificationPresetChange(preset) }
                            )
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun FocusModeSection(
    promptOnTimerStart: Boolean,
    onPromptOnTimerStartChange: (Boolean) -> Unit
) {
    val context = LocalContext.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp)
    ) {
        Text(
            text = "集中モード",
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.Bold
        )
        Spacer(modifier = Modifier.height(8.dp))
        Card(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    text = "Android では Screen Time によるアプリ遮断は利用できません。代わりに、おやすみモード（DND）の設定へ誘導できます。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Text("タイマー開始時に DND 設定を開く")
                    Switch(
                        checked = promptOnTimerStart,
                        onCheckedChange = onPromptOnTimerStartChange
                    )
                }
                OutlinedButton(
                    onClick = {
                        context.startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("おやすみモードの設定")
                }
                Text(
                    text = "許可するアプリはシステム設定で手動で選んでください。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
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

        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "※時間割の未復習が48時間を超えた場合に通知します",
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onSurfaceVariant
        )
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
    onShowDebugLog: () -> Unit = {}
) {
    val context = LocalContext.current
    var tapCount by remember { mutableIntStateOf(0) }

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
                    text = try {
                        val pInfo = context.packageManager.getPackageInfo(context.packageName, 0)
                        "バージョン ${pInfo.versionName}"
                    } catch (e: Exception) {
                        "バージョン 1.0.0"
                    },
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.clickable {
                        tapCount++
                        if (tapCount >= 5) {
                            tapCount = 0
                            onShowDebugLog()
                        }
                    }
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

@Composable
private fun DebugLogSheet(
    logs: List<DebugLogEntry>,
    onDismiss: () -> Unit,
    onClear: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Text("デバッグログ (${logs.size})")
                Row {
                    TextButton(onClick = onClear) {
                        Text("クリア", color = MaterialTheme.colorScheme.error)
                    }
                }
            }
        },
        text = {
            if (logs.isEmpty()) {
                Text(
                    text = "ログエントリがありません",
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.fillMaxWidth().padding(32.dp),
                    textAlign = TextAlign.Center
                )
            } else {
                LazyColumn(
                    modifier = Modifier.heightIn(max = 400.dp),
                    verticalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    items(logs.reversed()) { entry ->
                        LogEntryRow(entry)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) {
                Text("閉じる")
            }
        }
    )
}

@Composable
private fun LogEntryRow(entry: DebugLogEntry) {
    val timeFormat = remember { SimpleDateFormat("HH:mm:ss", Locale.JAPANESE) }
    val levelColor = when (entry.level) {
        "ERROR" -> MaterialTheme.colorScheme.error
        "WARN" -> Color(0xFFFF9800)
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.3f),
                RoundedCornerShape(4.dp)
            )
            .padding(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text(
                text = timeFormat.format(Date(entry.timestamp)),
                style = MaterialTheme.typography.labelSmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
            Text(
                text = entry.level,
                style = MaterialTheme.typography.labelSmall,
                fontWeight = FontWeight.Bold,
                color = levelColor
            )
        }
        Text(
            text = "[${entry.category}] ${entry.message}",
            style = MaterialTheme.typography.bodySmall
        )
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
private fun DeleteAccountDialog(
    password: String,
    onPasswordChange: (String) -> Unit,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("アカウントを削除しますか？") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                Text(
                    "クラウド同期アカウント、クラウド上の同期データ、この端末の学習データを削除します。この操作は元に戻せません。"
                )
                OutlinedTextField(
                    value = password,
                    onValueChange = onPasswordChange,
                    label = { Text("現在のパスワード") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            TextButton(
                onClick = onConfirm,
                colors = ButtonDefaults.textButtonColors(
                    contentColor = MaterialTheme.colorScheme.error
                )
            ) {
                Text("削除する")
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
