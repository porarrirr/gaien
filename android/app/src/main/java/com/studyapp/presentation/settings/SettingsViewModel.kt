package com.studyapp.presentation.settings

import android.content.Context
import android.net.Uri
import android.util.Log
import androidx.core.content.FileProvider
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.AnkiTodayStats
import com.studyapp.domain.repository.AnkiRepository
import com.studyapp.domain.repository.StudySessionRepository
import com.studyapp.domain.usecase.ExportImportDataUseCase
import com.studyapp.domain.util.Result
import com.studyapp.services.ReminderWorker
import com.studyapp.sync.AuthRepository
import com.studyapp.sync.SyncRepository
import com.studyapp.sync.SyncChangeNotifier
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.android.lifecycle.HiltViewModel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import javax.inject.Inject

data class SettingsUiState(
    val reminderEnabled: Boolean = false,
    val reminderTime: String = "19:00",
    val totalSessions: Int = 0,
    val totalStudyTime: Long = 0L,
    val selectedColorTheme: ColorTheme = ColorTheme.GREEN,
    val selectedThemeMode: ThemeMode = ThemeMode.SYSTEM,
    val syncEmail: String = "",
    val syncPassword: String = "",
    val syncAuthenticated: Boolean = false,
    val syncAccountEmail: String? = null,
    val syncInProgress: Boolean = false,
    val lastSyncAt: Long? = null,
    val syncError: String? = null,
    val ankiStats: AnkiTodayStats = AnkiTodayStats(),
    val isRefreshingAnkiStats: Boolean = true
)

@HiltViewModel
class SettingsViewModel @Inject constructor(
    private val studySessionRepository: StudySessionRepository,
    private val ankiRepository: AnkiRepository,
    private val themePreferences: ThemePreferences,
    private val reminderPreferences: ReminderPreferences,
    private val exportImportDataUseCase: ExportImportDataUseCase,
    private val authRepository: AuthRepository,
    private val syncRepository: SyncRepository,
    private val syncChangeNotifier: SyncChangeNotifier,
    @ApplicationContext private val appContext: Context
) : ViewModel() {
    
    private val _uiState = MutableStateFlow(SettingsUiState())
    val uiState = _uiState.asStateFlow()
    
    init {
        loadStatistics()
        loadThemePreferences()
        loadReminderPreferences()
        observeSyncState()
        observeAnkiState()
        refreshAnkiStats()
    }
    
    private fun loadThemePreferences() {
        viewModelScope.launch {
            themePreferences.getPrimaryColor().collect { color ->
                _uiState.update { it.copy(selectedColorTheme = color) }
            }
        }
        viewModelScope.launch {
            themePreferences.getThemeMode().collect { mode ->
                _uiState.update { it.copy(selectedThemeMode = mode) }
            }
        }
    }

    private fun loadReminderPreferences() {
        viewModelScope.launch {
            combine(
                reminderPreferences.isReminderEnabled(),
                reminderPreferences.getReminderTime()
            ) { enabled, time ->
                enabled to time
            }.collect { (enabled, time) ->
                _uiState.update {
                    it.copy(
                        reminderEnabled = enabled,
                        reminderTime = time
                    )
                }
            }
        }
    }
    
    private fun loadStatistics() {
        viewModelScope.launch {
            val sessionsResult = studySessionRepository.getAllSessions().first()
            val sessions = sessionsResult.getOrNull() ?: emptyList()
            val totalMinutes = sessions.sumOf { it.durationMinutes }
            
            _uiState.update { 
                it.copy(
                    totalSessions = sessions.size,
                    totalStudyTime = totalMinutes
                )
            }
        }
    }

    private fun observeSyncState() {
        viewModelScope.launch {
            authRepository.session.collect { session ->
                _uiState.update {
                    it.copy(
                        syncAuthenticated = session != null,
                        syncAccountEmail = session?.email
                    )
                }
            }
        }
        viewModelScope.launch {
            syncRepository.status.collect { status ->
                _uiState.update {
                    it.copy(
                        syncAuthenticated = status.isAuthenticated,
                        syncAccountEmail = status.email,
                        syncInProgress = status.isSyncing,
                        lastSyncAt = status.lastSyncAt,
                        syncError = status.errorMessage
                    )
                }
            }
        }
    }
    
    fun setReminderEnabled(enabled: Boolean) {
        viewModelScope.launch {
            reminderPreferences.setReminderEnabled(enabled)
            if (enabled) {
                scheduleReminder(_uiState.value.reminderTime)
            } else {
                ReminderWorker.cancelReminder(appContext)
            }
            _uiState.update { it.copy(reminderEnabled = enabled) }
        }
    }
    
    fun setReminderTime(time: String) {
        val parsedTime = parseReminderTime(time) ?: run {
            Log.w(TAG, "Ignoring invalid reminder time: $time")
            return
        }

        viewModelScope.launch {
            reminderPreferences.setReminderTime(parsedTime.first, parsedTime.second)
            if (_uiState.value.reminderEnabled) {
                ReminderWorker.scheduleReminder(appContext, parsedTime.first, parsedTime.second)
            }
            _uiState.update { it.copy(reminderTime = time) }
        }
    }
    
    fun setColorTheme(color: ColorTheme) {
        viewModelScope.launch {
            themePreferences.setPrimaryColor(color)
            _uiState.update { it.copy(selectedColorTheme = color) }
        }
    }
    
    fun setThemeMode(mode: ThemeMode) {
        viewModelScope.launch {
            themePreferences.setThemeMode(mode)
            _uiState.update { it.copy(selectedThemeMode = mode) }
        }
    }

    fun setSyncEmail(value: String) {
        _uiState.update { it.copy(syncEmail = value) }
    }

    fun setSyncPassword(value: String) {
        _uiState.update { it.copy(syncPassword = value) }
    }

    fun signInToSync() {
        viewModelScope.launch {
            runCatching {
                authRepository.signIn(_uiState.value.syncEmail.trim(), _uiState.value.syncPassword)
            }.onFailure {
                _uiState.update { state -> state.copy(syncError = it.message) }
            }
        }
    }

    fun createSyncAccount() {
        viewModelScope.launch {
            runCatching {
                authRepository.signUp(_uiState.value.syncEmail.trim(), _uiState.value.syncPassword)
            }.onFailure {
                _uiState.update { state -> state.copy(syncError = it.message) }
            }
        }
    }

    fun signOutOfSync() {
        viewModelScope.launch {
            authRepository.signOut()
        }
    }

    fun syncNow() {
        viewModelScope.launch {
            runCatching {
                syncRepository.syncNow()
                syncChangeNotifier.resumeAutoSync()
                loadStatistics()
            }.onFailure {
                _uiState.update { state -> state.copy(syncError = it.message) }
            }
        }
    }

    fun importLocalDataToCloud() {
        viewModelScope.launch {
            runCatching {
                syncRepository.importLocalDataToCloud()
                syncChangeNotifier.resumeAutoSync()
            }.onFailure {
                _uiState.update { state -> state.copy(syncError = it.message) }
            }
        }
    }

    private fun observeAnkiState() {
        viewModelScope.launch {
            ankiRepository.observeTodayStats().collect { stats ->
                _uiState.update {
                    it.copy(
                        ankiStats = stats,
                        isRefreshingAnkiStats = false
                    )
                }
            }
        }
    }
    
    fun exportData(context: Context, format: String) {
        viewModelScope.launch {
            when (val exportResult = exportImportDataUseCase.exportToJson()) {
                is Result.Success -> {
                    try {
                        val content = if (format == "json") {
                            exportResult.data
                        } else {
                            convertToCsv(exportResult.data)
                        }

                        val fileName = "studyapp_backup_${SimpleDateFormat("yyyyMMdd_HHmmss", Locale.getDefault()).format(Date())}.${format}"
                        val file = File(context.cacheDir, fileName)
                        FileOutputStream(file).use { it.write(content.toByteArray()) }

                        val uri = FileProvider.getUriForFile(
                            context,
                            "${context.packageName}.fileprovider",
                            file
                        )

                        val shareIntent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
                            type = if (format == "json") "application/json" else "text/csv"
                            putExtra(android.content.Intent.EXTRA_STREAM, uri)
                            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        val chooserIntent = android.content.Intent
                            .createChooser(shareIntent, "データをエクスポート")
                            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)

                        context.startActivity(chooserIntent)
                    } catch (e: Exception) {
                        Log.e(TAG, "Failed to export data as $format", e)
                    }
                }
                is Result.Error -> {
                    Log.e(TAG, "Failed to prepare export", exportResult.exception)
                }
            }
        }
    }
    
    fun importData(context: Context, uri: Uri) {
        viewModelScope.launch {
            try {
                val content = context.contentResolver.openInputStream(uri)?.use {
                    it.bufferedReader().readText()
                } ?: run {
                    Log.w(TAG, "Import aborted because the selected file could not be read")
                    return@launch
                }

                when (val importResult = exportImportDataUseCase.importFromJson(content)) {
                    is Result.Success -> {
                        syncChangeNotifier.notifyLocalDataChanged()
                        loadStatistics()
                    }
                    is Result.Error -> Log.e(TAG, "Failed to import data", importResult.exception)
                }
            } catch (e: Exception) {
                Log.e(TAG, "Failed to import data from $uri", e)
            }
        }
    }
    
    fun deleteAllData() {
        viewModelScope.launch {
            when (val deleteResult = exportImportDataUseCase.deleteAllData()) {
                is Result.Success -> {
                    runCatching {
                        if (authRepository.session.value != null) {
                            syncRepository.importLocalDataToCloud()
                        } else {
                            syncRepository.clearLocalSyncState()
                        }
                        syncChangeNotifier.resumeAutoSync()
                    }.onFailure {
                        _uiState.update { state -> state.copy(syncError = it.message) }
                    }
                    _uiState.update {
                        it.copy(
                            totalSessions = 0,
                            totalStudyTime = 0L,
                            lastSyncAt = null,
                            syncError = null
                        )
                    }
                }
                is Result.Error -> {
                    Log.e(TAG, "Failed to delete all study data", deleteResult.exception)
                }
            }
        }
    }

    fun refreshAnkiStats() {
        viewModelScope.launch {
            _uiState.update { it.copy(isRefreshingAnkiStats = true) }
            try {
                ankiRepository.refreshTodayStats()
            } finally {
                _uiState.update { it.copy(isRefreshingAnkiStats = false) }
            }
        }
    }

    private fun convertToCsv(json: String): String {
        val data = JSONObject(json)
        val sb = StringBuilder()
        val sessions = data.optJSONArray("sessions") ?: JSONArray()
        sb.append("日付,科目,教材,開始時刻,終了時刻,時間(分),メモ\n")
        val dateFormat = SimpleDateFormat("yyyy/MM/dd", Locale.getDefault())
        val timeFormat = SimpleDateFormat("HH:mm", Locale.getDefault())

        for (i in 0 until sessions.length()) {
            val session = sessions.getJSONObject(i)
            val startTime = session.optLong("startTime")
            val endTime = session.optLong("endTime")
            val intervals = session.optJSONArray("intervals")
            val durationMinutes = if (intervals != null && intervals.length() > 0) {
                (0 until intervals.length()).sumOf { index ->
                    val interval = intervals.optJSONObject(index) ?: return@sumOf 0L
                    (interval.optLong("endTime") - interval.optLong("startTime")).coerceAtLeast(0L) / 60000
                }
            } else {
                (endTime - startTime).coerceAtLeast(0L) / 60000
            }

            sb.append(escapeCsv(dateFormat.format(Date(startTime)))).append(',')
            sb.append(escapeCsv(session.optString("subjectName"))).append(',')
            sb.append(escapeCsv(session.optString("materialName"))).append(',')
            sb.append(escapeCsv(timeFormat.format(Date(startTime)))).append(',')
            sb.append(escapeCsv(timeFormat.format(Date(endTime)))).append(',')
            sb.append(durationMinutes).append(',')
            sb.append(escapeCsv(session.optString("note"))).append('\n')
        }

        return sb.toString()
    }

    private fun scheduleReminder(time: String) {
        val (hour, minute) = parseReminderTime(time) ?: run {
            Log.w(TAG, "Skipping reminder scheduling because the time is invalid: $time")
            return
        }
        ReminderWorker.scheduleReminder(appContext, hour, minute)
    }

    private fun parseReminderTime(time: String): Pair<Int, Int>? {
        val parts = time.split(":")
        if (parts.size != 2) {
            return null
        }

        val hour = parts[0].toIntOrNull()
        val minute = parts[1].toIntOrNull()
        if (hour == null || minute == null || hour !in 0..23 || minute !in 0..59) {
            return null
        }

        return hour to minute
    }

    private fun escapeCsv(value: String): String {
        if (value.none { it == ',' || it == '"' || it == '\n' || it == '\r' }) {
            return value
        }

        return buildString {
            append('"')
            value.forEach { character ->
                if (character == '"') {
                    append("\"\"")
                } else {
                    append(character)
                }
            }
            append('"')
        }
    }

    companion object {
        private const val TAG = "SettingsViewModel"
    }
}
