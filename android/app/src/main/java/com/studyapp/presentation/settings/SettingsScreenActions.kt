package com.studyapp.presentation.settings

import android.Manifest
import android.app.TimePickerDialog
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.ichi2.anki.api.AddContentApi
import java.util.Locale

internal data class SettingsScreenActions(
    val onReminderEnabledChange: (Boolean) -> Unit,
    val onReminderTimeClick: () -> Unit,
    val onGrantAnkiPermission: () -> Unit,
    val onOpenUsageAccess: () -> Unit,
    val onRefreshAnkiStats: () -> Unit
)

@Composable
internal fun rememberSettingsScreenActions(
    uiState: SettingsUiState,
    viewModel: SettingsViewModel
): SettingsScreenActions {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    val notificationPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) { granted ->
        if (granted) {
            viewModel.setReminderEnabled(true)
        }
    }
    val ankiPermissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestPermission()
    ) {
        viewModel.refreshAnkiStats()
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

    DisposableEffect(lifecycleOwner, viewModel) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                viewModel.refreshAnkiStats()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
        }
    }

    return remember(context, notificationPermissionLauncher, ankiPermissionLauncher, reminderTimePickerDialog, viewModel) {
        SettingsScreenActions(
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
            },
            onGrantAnkiPermission = {
                ankiPermissionLauncher.launch(AddContentApi.READ_WRITE_PERMISSION)
            },
            onOpenUsageAccess = {
                context.startActivity(
                    Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    }
                )
            },
            onRefreshAnkiStats = viewModel::refreshAnkiStats
        )
    }
}
