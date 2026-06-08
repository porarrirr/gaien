package com.studyapp.presentation.settings

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.*
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.mutableStateMapOf
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
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
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
    var showAuthSheet by remember { mutableStateOf(false) }
    var showConflictResolution by remember { mutableStateOf(false) }

    LaunchedEffect(uiState.syncAuthenticated) {
        if (uiState.syncAuthenticated) {
            showAuthSheet = false
        }
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
                .padding(horizontal = 17.dp)
                .verticalScroll(rememberScrollState())
                .padding(top = 14.dp, bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            SettingsAppearanceGroup(
                selectedColorTheme = uiState.selectedColorTheme,
                selectedThemeMode = uiState.selectedThemeMode,
                onColorThemeChange = { viewModel.setColorTheme(it) },
                onThemeModeChange = { viewModel.setThemeMode(it) }
            )

            SettingsReminderGroup(
                reminderEnabled = uiState.reminderEnabled,
                reminderTime = uiState.reminderTime,
                onReminderEnabledChange = actions.onReminderEnabledChange,
                onReminderTimeClick = actions.onReminderTimeClick
            )

            SettingsLandscapeTimerGroup(
                landscapePreset = uiState.landscapeTimerDisplayPreset,
                onLandscapePresetChange = viewModel::setLandscapeTimerDisplayPreset
            )

            SettingsTimerNotificationGroup(
                notificationRichEnabled = uiState.timerNotificationRichEnabled,
                notificationPreset = uiState.timerNotificationDisplayPreset,
                onNotificationRichEnabledChange = viewModel::setTimerNotificationRichEnabled,
                onNotificationPresetChange = viewModel::setTimerNotificationDisplayPreset
            )

            SettingsDataSummaryGroup(
                totalSessions = uiState.totalSessions,
                totalStudyTime = uiState.totalStudyTime
            )

            SettingsCloudSyncGroup(
                syncAuthenticated = uiState.syncAuthenticated,
                syncAccountEmail = uiState.syncAccountEmail,
                syncInProgress = uiState.syncInProgress,
                lastSyncAt = uiState.lastSyncAt,
                syncError = uiState.syncError,
                pendingConflictCount = uiState.pendingConflictCount,
                onSignOut = viewModel::signOutOfSync,
                onDeleteAccount = { showDeleteAccountDialog = true },
                onSyncNow = viewModel::syncNow,
                onImportLocal = viewModel::importLocalDataToCloud,
                onResolveConflicts = { showConflictResolution = true },
                onOpenAuth = { showAuthSheet = true }
            )

            SettingsBackupGroup(
                onExport = { showExportDialog = true },
                onImport = { showImportDialog = true }
            )

            SettingsDangerGroup(onDeleteData = { showDeleteDataDialog = true })

            SettingsDiagnosticGroup(
                onShowDebugLog = { showDebugLog = true },
                onClearDebugLog = viewModel::clearDebugLogs
            )
        }
    }

    if (showConflictResolution) {
        SyncConflictResolutionSheet(
            conflicts = viewModel.pendingSyncConflicts(),
            onDismiss = { showConflictResolution = false },
            onApply = { resolutions ->
                viewModel.resolveSyncConflicts(resolutions)
                showConflictResolution = false
            }
        )
    }

    if (showAuthSheet) {
        CloudAuthSheet(
            uiState = uiState,
            onDismiss = { showAuthSheet = false },
            onSignInEmailChange = viewModel::setSignInEmail,
            onSignInPasswordChange = viewModel::setSignInPassword,
            onCreateEmailChange = viewModel::setCreateEmail,
            onCreatePasswordChange = viewModel::setCreatePassword,
            onSignIn = viewModel::signInToSync,
            onCreateAccount = viewModel::createSyncAccount,
            onSendPasswordReset = viewModel::sendPasswordReset
        )
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

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SettingsAppearanceGroup(
    selectedColorTheme: ColorTheme,
    selectedThemeMode: ThemeMode,
    onColorThemeChange: (ColorTheme) -> Unit,
    onThemeModeChange: (ThemeMode) -> Unit
) {
    var themeModeExpanded by remember { mutableStateOf(false) }
    var colorThemeExpanded by remember { mutableStateOf(false) }

    SettingsGroup(title = "テーマ設定") {
        Box {
            SettingsValueRow(
                icon = Icons.Default.Palette,
                title = "テーマ",
                value = selectedThemeMode.title,
                onClick = { themeModeExpanded = true }
            )
            DropdownMenu(
                expanded = themeModeExpanded,
                onDismissRequest = { themeModeExpanded = false }
            ) {
                ThemeMode.entries.forEach { mode ->
                    DropdownMenuItem(
                        text = { Text(mode.title) },
                        onClick = {
                            onThemeModeChange(mode)
                            themeModeExpanded = false
                        },
                        trailingIcon = {
                            if (selectedThemeMode == mode) {
                                Icon(Icons.Default.Check, contentDescription = null)
                            }
                        }
                    )
                }
            }
        }
        HorizontalDivider()
        Box {
            SettingsValueRow(
                icon = Icons.Default.Palette,
                title = "カラー",
                value = selectedColorTheme.title,
                color = Color(0xFF000000 or selectedColorTheme.hex),
                showsColorDot = true,
                onClick = { colorThemeExpanded = true }
            )
            DropdownMenu(
                expanded = colorThemeExpanded,
                onDismissRequest = { colorThemeExpanded = false }
            ) {
                ColorTheme.entries.forEach { theme ->
                    DropdownMenuItem(
                        text = { Text(theme.title) },
                        onClick = {
                            onColorThemeChange(theme)
                            colorThemeExpanded = false
                        },
                        leadingIcon = {
                            Box(
                                modifier = Modifier
                                    .size(14.dp)
                                    .clip(CircleShape)
                                    .background(Color(0xFF000000 or theme.hex))
                            )
                        },
                        trailingIcon = {
                            if (selectedColorTheme == theme) {
                                Icon(Icons.Default.Check, contentDescription = null)
                            }
                        }
                    )
                }
            }
        }
    }
}

@Composable
private fun SettingsReminderGroup(
    reminderEnabled: Boolean,
    reminderTime: String,
    onReminderEnabledChange: (Boolean) -> Unit,
    onReminderTimeClick: () -> Unit
) {
    SettingsGroup(title = "通知") {
        SettingsToggleRow(
            icon = Icons.Default.Notifications,
            title = "毎日のリマインダー",
            checked = reminderEnabled,
            onCheckedChange = onReminderEnabledChange
        )
        HorizontalDivider()
        SettingsValueRow(
            icon = Icons.Default.Schedule,
            title = "通知時刻",
            value = reminderTime,
            enabled = reminderEnabled,
            onClick = onReminderTimeClick
        )
    }
    Text(
        text = "※時間割の未復習が48時間を超えた場合に通知します",
        style = MaterialTheme.typography.bodySmall,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier.padding(horizontal = 18.dp)
    )
}

@Composable
private fun SettingsLandscapeTimerGroup(
    landscapePreset: LandscapeTimerDisplayPreset,
    onLandscapePresetChange: (LandscapeTimerDisplayPreset) -> Unit
) {
    SettingsGroup(title = "横向きタイマーの表示") {
        LandscapeTimerDisplayPreset.entries.forEachIndexed { index, preset ->
            SettingsSelectionRow(
                icon = if (preset == LandscapeTimerDisplayPreset.PROBLEM_PROGRESS) {
                    Icons.Default.GridView
                } else {
                    Icons.Default.Timer
                },
                title = settingsTitle(preset),
                selected = landscapePreset == preset,
                onClick = { onLandscapePresetChange(preset) }
            )
            if (index != LandscapeTimerDisplayPreset.entries.lastIndex) {
                HorizontalDivider()
            }
        }
    }
}

@Composable
private fun SettingsTimerNotificationGroup(
    notificationRichEnabled: Boolean,
    notificationPreset: TimerNotificationDisplayPreset,
    onNotificationRichEnabledChange: (Boolean) -> Unit,
    onNotificationPresetChange: (TimerNotificationDisplayPreset) -> Unit
) {
    SettingsGroup(title = "タイマー通知の表示") {
        SettingsToggleRow(
            icon = Icons.Default.Notifications,
            title = "リッチ通知を使用",
            checked = notificationRichEnabled,
            onCheckedChange = onNotificationRichEnabledChange
        )
        if (notificationRichEnabled) {
            HorizontalDivider()
            TimerNotificationDisplayPreset.entries.forEachIndexed { index, preset ->
                SettingsSelectionRow(
                    icon = Icons.Default.Description,
                    title = settingsTitle(preset),
                    selected = notificationPreset == preset,
                    onClick = { onNotificationPresetChange(preset) }
                )
                if (index != TimerNotificationDisplayPreset.entries.lastIndex) {
                    HorizontalDivider()
                }
            }
        }
    }
}

@Composable
private fun SettingsDataSummaryGroup(
    totalSessions: Int,
    totalStudyTime: Long
) {
    SettingsGroup(title = "データ概要") {
        SettingsInfoRow(
            icon = Icons.Default.BarChart,
            title = "学習記録数",
            value = "${totalSessions} 件"
        )
        HorizontalDivider()
        SettingsInfoRow(
            icon = Icons.Default.Schedule,
            title = "総学習時間",
            value = formatStudyTime(totalStudyTime)
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SyncConflictResolutionSheet(
    conflicts: List<com.studyapp.sync.SyncConflict>,
    onDismiss: () -> Unit,
    onApply: (List<com.studyapp.sync.SyncConflictResolution>) -> Unit
) {
    val selections = remember(conflicts) {
        mutableStateMapOf<String, com.studyapp.sync.SyncConflictResolutionStrategy>().apply {
            conflicts.forEach { put(it.documentId, com.studyapp.sync.SyncConflictResolutionStrategy.KEEP_MERGED) }
        }
    }

    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 17.dp)
                .padding(bottom = 28.dp),
            verticalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            Text("同期の競合", style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
            if (conflicts.isEmpty()) {
                Text("解決が必要な競合はありません", color = MaterialTheme.colorScheme.onSurfaceVariant)
            } else {
                Text(
                    "端末とクラウドで同じデータが異なる内容に更新されています。残す内容を選んでください。",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                LazyColumn(
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(max = 420.dp),
                    verticalArrangement = Arrangement.spacedBy(14.dp)
                ) {
                    items(conflicts, key = { it.documentId }) { conflict ->
                        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                            Text(conflict.summary, fontWeight = FontWeight.SemiBold)
                            SingleChoiceSegmentedButtonRow(modifier = Modifier.fillMaxWidth()) {
                                SegmentedButton(
                                    selected = selections[conflict.documentId] == com.studyapp.sync.SyncConflictResolutionStrategy.KEEP_LOCAL,
                                    onClick = { selections[conflict.documentId] = com.studyapp.sync.SyncConflictResolutionStrategy.KEEP_LOCAL },
                                    shape = SegmentedButtonDefaults.itemShape(index = 0, count = 3)
                                ) { Text("この端末") }
                                SegmentedButton(
                                    selected = selections[conflict.documentId] == com.studyapp.sync.SyncConflictResolutionStrategy.KEEP_REMOTE,
                                    onClick = { selections[conflict.documentId] = com.studyapp.sync.SyncConflictResolutionStrategy.KEEP_REMOTE },
                                    shape = SegmentedButtonDefaults.itemShape(index = 1, count = 3)
                                ) { Text("クラウド") }
                                SegmentedButton(
                                    selected = selections[conflict.documentId] == com.studyapp.sync.SyncConflictResolutionStrategy.KEEP_MERGED,
                                    onClick = { selections[conflict.documentId] = com.studyapp.sync.SyncConflictResolutionStrategy.KEEP_MERGED },
                                    shape = SegmentedButtonDefaults.itemShape(index = 2, count = 3)
                                ) { Text("自動統合") }
                            }
                        }
                    }
                }
                Button(
                    onClick = {
                        val resolutions = conflicts.mapNotNull { conflict ->
                            val strategy = selections[conflict.documentId] ?: return@mapNotNull null
                            com.studyapp.sync.SyncConflictResolution(conflict.kind, conflict.syncId, strategy)
                        }
                        onApply(resolutions)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    enabled = conflicts.isNotEmpty() && selections.size >= conflicts.size
                ) {
                    Text("適用")
                }
            }
        }
    }
}

@Composable
private fun SettingsCloudSyncGroup(
    syncAuthenticated: Boolean,
    syncAccountEmail: String?,
    syncInProgress: Boolean,
    lastSyncAt: Long?,
    syncError: String?,
    pendingConflictCount: Int,
    onSignOut: () -> Unit,
    onDeleteAccount: () -> Unit,
    onSyncNow: () -> Unit,
    onImportLocal: () -> Unit,
    onResolveConflicts: () -> Unit,
    onOpenAuth: () -> Unit
) {
    SettingsGroup(title = "クラウド同期") {
        if (syncAuthenticated) {
            SettingsInfoRow(
                icon = Icons.Default.Public,
                title = "接続中",
                value = "接続中",
                valueColor = MaterialTheme.colorScheme.primary,
                showsStatusDot = true
            )
            HorizontalDivider()
            SettingsInfoRow(
                icon = Icons.Default.Person,
                title = "メールアドレス",
                value = syncAccountEmail ?: "-"
            )
            HorizontalDivider()
            SettingsInfoRow(
                icon = Icons.Default.Schedule,
                title = "最終同期",
                value = lastSyncAt?.let { SimpleDateFormat("M/d HH:mm", Locale.JAPANESE).format(Date(it)) } ?: "未同期"
            )
            HorizontalDivider()
            SettingsActionLine(
                icon = Icons.Default.Refresh,
                title = if (syncInProgress) "同期中..." else "今すぐ同期",
                color = MaterialTheme.colorScheme.primary,
                enabled = !syncInProgress,
                action = onSyncNow
            )
            if (pendingConflictCount > 0) {
                HorizontalDivider()
                SettingsActionLine(
                    icon = Icons.Default.Warning,
                    title = "競合を解決（${pendingConflictCount}件）",
                    color = MaterialTheme.colorScheme.error,
                    enabled = !syncInProgress,
                    action = onResolveConflicts
                )
            }
            HorizontalDivider()
            SettingsActionLine(
                icon = Icons.Default.Upload,
                title = "ローカルデータをアップロード",
                color = MaterialTheme.colorScheme.primary,
                enabled = !syncInProgress,
                action = onImportLocal
            )
            HorizontalDivider()
            SettingsActionLine(
                icon = Icons.Default.Delete,
                title = "サインアウト",
                color = MaterialTheme.colorScheme.error,
                enabled = !syncInProgress,
                action = onSignOut
            )
            HorizontalDivider()
            SettingsActionLine(
                icon = Icons.Default.DeleteForever,
                title = "アカウントを削除",
                color = MaterialTheme.colorScheme.error,
                enabled = !syncInProgress,
                action = onDeleteAccount
            )
        } else {
            SettingsValueRow(
                icon = Icons.Default.Person,
                title = "サインイン / アカウント作成",
                value = "",
                onClick = onOpenAuth
            )
        }

        syncError?.takeIf { it.isNotBlank() }?.let { error ->
            HorizontalDivider()
            Text(
                text = error,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.padding(vertical = 8.dp, horizontal = 4.dp)
            )
        }
    }
}

@Composable
private fun SettingsBackupGroup(
    onExport: () -> Unit,
    onImport: () -> Unit
) {
    SettingsGroup(title = "バックアップ") {
        SettingsActionLine(
            icon = Icons.Default.Download,
            title = "エクスポート",
            color = MaterialTheme.colorScheme.primary,
            action = onExport
        )
        HorizontalDivider()
        SettingsActionLine(
            icon = Icons.Default.Upload,
            title = "インポート",
            color = MaterialTheme.colorScheme.primary,
            action = onImport
        )
    }
}

@Composable
private fun SettingsDangerGroup(onDeleteData: () -> Unit) {
    SettingsGroup(title = "危険な操作") {
        SettingsActionLine(
            icon = Icons.Default.DeleteForever,
            title = "全データを削除",
            color = MaterialTheme.colorScheme.error,
            action = onDeleteData
        )
    }
}

@Composable
private fun SettingsDiagnosticGroup(
    onShowDebugLog: () -> Unit,
    onClearDebugLog: () -> Unit
) {
    SettingsGroup(title = "診断ログ") {
        SettingsActionLine(
            icon = Icons.Default.Folder,
            title = "診断ログを開く",
            color = MaterialTheme.colorScheme.primary,
            action = onShowDebugLog
        )
        HorizontalDivider()
        SettingsActionLine(
            icon = Icons.Default.Delete,
            title = "診断ログをクリア",
            color = MaterialTheme.colorScheme.error,
            action = onClearDebugLog
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun CloudAuthSheet(
    uiState: SettingsUiState,
    onDismiss: () -> Unit,
    onSignInEmailChange: (String) -> Unit,
    onSignInPasswordChange: (String) -> Unit,
    onCreateEmailChange: (String) -> Unit,
    onCreatePasswordChange: (String) -> Unit,
    onSignIn: () -> Unit,
    onCreateAccount: () -> Unit,
    onSendPasswordReset: () -> Unit
) {
    ModalBottomSheet(onDismissRequest = onDismiss) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 26.dp)
                .padding(bottom = 26.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(18.dp)) {
                Icon(
                    Icons.Default.Upload,
                    contentDescription = null,
                    modifier = Modifier.size(54.dp),
                    tint = MaterialTheme.colorScheme.primary
                )
                Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(
                        text = "クラウド同期（オプション）",
                        style = MaterialTheme.typography.titleLarge,
                        fontWeight = FontWeight.Bold
                    )
                    Text(
                        text = "Firebase を使用してデータを同期します。同期はいつでも設定からオン／オフできます。",
                        style = MaterialTheme.typography.bodyMedium,
                        color = MaterialTheme.colorScheme.onSurfaceVariant
                    )
                }
            }

            AuthCard(title = "サインイン", description = "既存のアカウントでサインインしてデータを同期します。") {
                OutlinedTextField(
                    value = uiState.signInEmail,
                    onValueChange = onSignInEmailChange,
                    label = { Text("メールアドレス") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = uiState.signInPassword,
                    onValueChange = onSignInPasswordChange,
                    label = { Text("パスワード") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth()
                )
                TextButton(
                    onClick = onSendPasswordReset,
                    enabled = !uiState.syncInProgress && uiState.signInEmail.isNotBlank()
                ) {
                    Text("パスワードをお忘れですか？")
                }
                Button(
                    onClick = onSignIn,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(58.dp),
                    shape = RoundedCornerShape(8.dp),
                    enabled = !uiState.syncInProgress &&
                        uiState.signInEmail.isNotBlank() &&
                        uiState.signInPassword.isNotBlank()
                ) {
                    Text("サインイン", style = MaterialTheme.typography.titleMedium)
                }
            }

            AuthCard(title = "アカウント作成", description = "新しいアカウントを作成してクラウド同期を利用します。") {
                OutlinedTextField(
                    value = uiState.createEmail,
                    onValueChange = onCreateEmailChange,
                    label = { Text("メールアドレス") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                OutlinedTextField(
                    value = uiState.createPassword,
                    onValueChange = onCreatePasswordChange,
                    label = { Text("パスワード") },
                    singleLine = true,
                    visualTransformation = PasswordVisualTransformation(),
                    modifier = Modifier.fillMaxWidth()
                )
                Text(
                    text = "※ 8文字以上のパスワードを設定してください。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
                OutlinedButton(
                    onClick = onCreateAccount,
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(58.dp),
                    shape = RoundedCornerShape(8.dp),
                    enabled = !uiState.syncInProgress &&
                        uiState.createEmail.isNotBlank() &&
                        uiState.createPassword.isNotBlank()
                ) {
                    Text("アカウント作成", style = MaterialTheme.typography.titleMedium)
                }
            }

            uiState.syncError?.takeIf { it.isNotBlank() }?.let { error ->
                Text(
                    text = error,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.error,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(MaterialTheme.colorScheme.errorContainer.copy(alpha = 0.35f), RoundedCornerShape(8.dp))
                        .border(1.dp, MaterialTheme.colorScheme.error.copy(alpha = 0.35f), RoundedCornerShape(8.dp))
                        .padding(16.dp)
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.Center,
                verticalAlignment = Alignment.CenterVertically
            ) {
                Icon(
                    Icons.Default.Lock,
                    contentDescription = null,
                    modifier = Modifier.size(14.dp),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant
                )
                Spacer(modifier = Modifier.width(8.dp))
                Text(
                    text = "通信は暗号化され、安全に保護されています。",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
        }
    }
}

@Composable
private fun AuthCard(
    title: String,
    description: String,
    content: @Composable ColumnScope.() -> Unit
) {
    OutlinedCard(
        modifier = Modifier.fillMaxWidth(),
        shape = RoundedCornerShape(8.dp),
        colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surfaceVariant.copy(alpha = 0.35f))
    ) {
        Column(
            modifier = Modifier.padding(18.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.primary
            )
            Text(
                text = description,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurface
            )
            content()
        }
    }
}

@Composable
private fun SettingsGroup(
    title: String,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(modifier = Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.labelLarge,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 11.dp)
        )
        OutlinedCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(10.dp),
            colors = CardDefaults.outlinedCardColors(containerColor = MaterialTheme.colorScheme.surface)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp, vertical = 8.dp)
            ) {
                content()
            }
        }
    }
}

@Composable
private fun SettingsIcon(icon: androidx.compose.ui.graphics.vector.ImageVector, tint: Color = MaterialTheme.colorScheme.onSurface) {
    Icon(
        imageVector = icon,
        contentDescription = null,
        modifier = Modifier.size(28.dp),
        tint = tint
    )
}

@Composable
private fun SettingsValueRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    value: String,
    color: Color = MaterialTheme.colorScheme.primary,
    showsColorDot: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 46.dp)
            .clip(RoundedCornerShape(6.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SettingsIcon(icon, tint = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
            color = if (enabled) MaterialTheme.colorScheme.onSurface else MaterialTheme.colorScheme.onSurfaceVariant,
            maxLines = 1,
            modifier = Modifier.weight(1f)
        )
        if (showsColorDot) {
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(color)
            )
        }
        if (value.isNotEmpty()) {
            Text(
                text = value,
                style = MaterialTheme.typography.bodyLarge,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                textAlign = TextAlign.End,
                modifier = Modifier.widthIn(max = 190.dp)
            )
        }
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(24.dp)
        )
    }
}

@Composable
private fun SettingsToggleRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 46.dp)
            .padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SettingsIcon(icon)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
            maxLines = 1
        )
        Switch(checked = checked, onCheckedChange = onCheckedChange)
    }
}

@Composable
private fun SettingsSelectionRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    selected: Boolean,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 46.dp)
            .clip(RoundedCornerShape(6.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        SettingsIcon(icon)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyLarge,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        if (selected) {
            Icon(
                Icons.Default.Check,
                contentDescription = null,
                tint = MaterialTheme.colorScheme.primary,
                modifier = Modifier.size(24.dp)
            )
        }
    }
}

@Composable
private fun SettingsInfoRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    value: String,
    valueColor: Color = MaterialTheme.colorScheme.onSurfaceVariant,
    showsStatusDot: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 40.dp)
            .padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        SettingsIcon(icon)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onSurface,
            modifier = Modifier.weight(1f),
            maxLines = 1
        )
        if (showsStatusDot) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(valueColor)
            )
        }
        Text(
            text = value,
            style = MaterialTheme.typography.bodyMedium,
            color = valueColor,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.End,
            modifier = Modifier.widthIn(max = 210.dp)
        )
    }
}

@Composable
private fun SettingsActionLine(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    color: Color,
    enabled: Boolean = true,
    action: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 40.dp)
            .clip(RoundedCornerShape(6.dp))
            .clickable(enabled = enabled, onClick = action)
            .padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(10.dp)
    ) {
        SettingsIcon(icon, tint = if (enabled) color else MaterialTheme.colorScheme.onSurfaceVariant)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.Bold,
            color = if (enabled) color else MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            overflow = TextOverflow.Ellipsis
        )
        Icon(
            Icons.Default.ChevronRight,
            contentDescription = null,
            tint = MaterialTheme.colorScheme.outline,
            modifier = Modifier.size(22.dp)
        )
    }
}

private fun settingsTitle(preset: LandscapeTimerDisplayPreset): String {
    return when (preset) {
        LandscapeTimerDisplayPreset.PROBLEM_PROGRESS -> "問題集つき（推奨）"
        LandscapeTimerDisplayPreset.CLOCK_ONLY -> "時計のみ"
    }
}

private fun settingsTitle(preset: TimerNotificationDisplayPreset): String {
    return when (preset) {
        TimerNotificationDisplayPreset.STANDARD -> "シンプル"
        TimerNotificationDisplayPreset.FOCUS -> "集中"
        TimerNotificationDisplayPreset.PROGRESS -> "進捗"
        TimerNotificationDisplayPreset.SUBJECT_DETAIL -> "科目詳細"
    }
}

private fun formatStudyTime(totalStudyTime: Long): String {
    val hours = totalStudyTime / 60
    val minutes = totalStudyTime % 60
    return "${hours} 時間 ${minutes} 分"
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
