package com.studyapp.presentation.screentime

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.OpenInNew
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.HourglassEmpty
import androidx.compose.material.icons.filled.Lock
import androidx.compose.material.icons.filled.NotificationsOff
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.TrackChanges
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.presentation.settings.SettingsViewModel

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ScreenTimeSettingsScreen(
    viewModel: SettingsViewModel = hiltViewModel()
) {
    val uiState by viewModel.uiState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    var hasDndAccess by remember(notificationManager) {
        mutableStateOf(notificationManager.isNotificationPolicyAccessGranted)
    }
    val warningColor = Color(0xFFE89500)

    DisposableEffect(lifecycleOwner, notificationManager) {
        fun refreshDndAccess() {
            hasDndAccess = notificationManager.isNotificationPolicyAccessGranted
        }

        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                refreshDndAccess()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        refreshDndAccess()

        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    fun openPolicyAccessSettings() {
        context.openSettings(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS)
    }

    fun openDndPrioritySettings() {
        context.openSettings(Settings.ACTION_ZEN_MODE_PRIORITY_SETTINGS)
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Screen Time",
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
                .background(MaterialTheme.colorScheme.background)
                .padding(paddingValues)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 17.dp, vertical = 14.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp)
        ) {
            SettingsGroup(title = "利用状態") {
                InfoRow(
                    icon = Icons.Default.HourglassEmpty,
                    title = "Screen Time",
                    value = if (hasDndAccess) "許可済み" else "未許可",
                    color = if (hasDndAccess) MaterialTheme.colorScheme.primary else warningColor,
                    showsStatusDot = hasDndAccess
                )
                HorizontalDivider()
                ActionLine(
                    icon = if (hasDndAccess) Icons.Default.CheckCircle else Icons.Default.Lock,
                    title = if (hasDndAccess) "許可を更新" else "Screen Timeを許可",
                    color = MaterialTheme.colorScheme.primary,
                    onClick = ::openPolicyAccessSettings
                )
            }

            SettingsGroup(
                title = "集中制限",
                footer = "AndroidではDND設定を使います。タイマー開始時の制限は、DNDの許可や対象をシステム設定で管理します。"
            ) {
                ToggleRow(
                    icon = Icons.Default.Lock,
                    title = "集中制限を使用",
                    checked = uiState.focusModeEnabled,
                    onCheckedChange = viewModel::setFocusModeEnabled
                )
                HorizontalDivider()
                ToggleRow(
                    icon = Icons.Default.Timer,
                    title = "タイマー実行中に制限",
                    checked = uiState.focusModePromptOnTimerStart,
                    enabled = uiState.focusModeEnabled,
                    onCheckedChange = viewModel::setFocusModePromptOnTimerStart
                )
                HorizontalDivider()
                ActionLine(
                    icon = Icons.Default.CalendarMonth,
                    title = "時間指定で制限",
                    value = "システム設定で管理",
                    enabled = uiState.focusModeEnabled,
                    color = MaterialTheme.colorScheme.primary,
                    onClick = ::openDndPrioritySettings
                )
                HorizontalDivider()
                InfoRow(
                    icon = Icons.Default.TrackChanges,
                    title = "今日の目標達成で解除",
                    value = "iOSで利用可",
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }

            SettingsGroup(
                title = "許可する対象",
                footer = "Androidでは通知の許可対象や例外をDNDのシステム設定で管理します。"
            ) {
                ActionLine(
                    icon = Icons.Default.NotificationsOff,
                    title = "アプリ・Webサイト",
                    value = "DNDで管理",
                    enabled = uiState.focusModeEnabled,
                    color = MaterialTheme.colorScheme.primary,
                    onClick = ::openDndPrioritySettings
                )
            }

            SettingsGroup(title = "時間指定") {
                ActionLine(
                    icon = Icons.Default.Settings,
                    title = "スケジュール",
                    value = "システム設定",
                    enabled = uiState.focusModeEnabled,
                    color = MaterialTheme.colorScheme.primary,
                    onClick = ::openDndPrioritySettings
                )
            }
        }
    }
}

@Composable
private fun SettingsGroup(
    title: String,
    footer: String? = null,
    content: @Composable ColumnScope.() -> Unit
) {
    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleSmall,
            fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(start = 10.dp)
        )
        ElevatedCard(
            modifier = Modifier.fillMaxWidth(),
            shape = RoundedCornerShape(10.dp),
            colors = CardDefaults.elevatedCardColors(
                containerColor = MaterialTheme.colorScheme.surface
            ),
            elevation = CardDefaults.elevatedCardElevation(defaultElevation = 1.dp)
        ) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 10.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(0.dp),
                content = content
            )
        }
        if (footer != null) {
            Text(
                text = footer,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 18.dp)
            )
        }
    }
}

@Composable
private fun InfoRow(
    icon: ImageVector,
    title: String,
    value: String,
    color: Color,
    showsStatusDot: Boolean = false
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f)
        )
        if (showsStatusDot) {
            Box(
                modifier = Modifier
                    .size(8.dp)
                    .clip(CircleShape)
                    .background(color)
            )
        }
        Text(
            text = value,
            style = MaterialTheme.typography.bodySmall,
            fontWeight = FontWeight.Bold,
            color = color
        )
    }
}

@Composable
private fun ToggleRow(
    icon: ImageVector,
    title: String,
    checked: Boolean,
    enabled: Boolean = true,
    onCheckedChange: (Boolean) -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .height(48.dp)
            .alpha(if (enabled) 1f else 0.45f),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(icon, contentDescription = null, tint = MaterialTheme.colorScheme.onSurface)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f)
        )
        Switch(
            checked = checked,
            enabled = enabled,
            onCheckedChange = onCheckedChange
        )
    }
}

@Composable
private fun ActionLine(
    icon: ImageVector,
    title: String,
    color: Color,
    modifier: Modifier = Modifier,
    value: String? = null,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    Row(
        modifier = modifier
            .fillMaxWidth()
            .height(48.dp)
            .clip(RoundedCornerShape(8.dp))
            .clickable(enabled = enabled, onClick = onClick)
            .alpha(if (enabled) 1f else 0.45f)
            .padding(horizontal = 2.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Icon(icon, contentDescription = null, tint = color)
        Text(
            text = title,
            style = MaterialTheme.typography.bodyMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.weight(1f)
        )
        if (value != null) {
            Text(
                text = value,
                style = MaterialTheme.typography.bodySmall,
                fontWeight = FontWeight.Bold,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )
        }
        Icon(
            imageVector = Icons.AutoMirrored.Filled.OpenInNew,
            contentDescription = null,
            tint = color,
            modifier = Modifier.size(18.dp)
        )
    }
}

private fun Context.openSettings(action: String) {
    startActivity(Intent(action))
}
