package com.studyapp.sync

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SyncPreferences @Inject constructor(
    @ApplicationContext context: Context
) {
    private val appContext = context.applicationContext
    private val preferences = context.getSharedPreferences("studyapp_sync", Context.MODE_PRIVATE)

    fun getLastSyncAt(): Long? {
        return if (preferences.contains(KEY_LAST_SYNC_AT)) preferences.getLong(KEY_LAST_SYNC_AT, 0L) else null
    }

    fun setLastSyncAt(timestamp: Long?) {
        preferences.edit().apply {
            if (timestamp == null) remove(KEY_LAST_SYNC_AT) else putLong(KEY_LAST_SYNC_AT, timestamp)
        }.apply()
    }

    fun getLocalSyncOwnerUserId(): String? {
        return preferences.getString(KEY_LOCAL_SYNC_OWNER_USER_ID, null)
    }

    fun setLocalSyncOwnerUserId(userId: String?) {
        preferences.edit().apply {
            if (userId.isNullOrBlank()) {
                remove(KEY_LOCAL_SYNC_OWNER_USER_ID)
            } else {
                putString(KEY_LOCAL_SYNC_OWNER_USER_ID, userId)
            }
        }.apply()
    }

    fun clearLocalSyncState() {
        preferences.edit().apply {
            remove(KEY_LAST_SYNC_AT)
            remove(KEY_LOCAL_SYNC_OWNER_USER_ID)
        }.apply()
    }

    fun isAutoSyncBlockedUntilLocalChange(): Boolean {
        return preferences.getBoolean(KEY_AUTO_SYNC_BLOCKED_UNTIL_LOCAL_CHANGE, false)
    }

    fun setAutoSyncBlockedUntilLocalChange(blocked: Boolean) {
        preferences.edit().putBoolean(KEY_AUTO_SYNC_BLOCKED_UNTIL_LOCAL_CHANGE, blocked).apply()
    }

    fun saveLocalBackup(payload: String, timestamp: Long, reason: String) {
        val directory = File(appContext.filesDir, "sync_backups")
        directory.mkdirs()
        val formatter = SimpleDateFormat("yyyyMMdd-HHmmss", Locale.US)
        val safeReason = reason.replace(Regex("[^A-Za-z0-9_-]"), "_")
        File(directory, "sync-$safeReason-${formatter.format(Date(timestamp))}.json").writeText(payload)
        pruneLocalBackups(directory, timestamp)
    }

    private fun pruneLocalBackups(directory: File, now: Long) {
        val cutoff = now - BACKUP_RETENTION_MILLIS
        directory.listFiles { file -> file.isFile && file.extension == "json" }
            ?.filter { it.lastModified() < cutoff }
            ?.forEach { it.delete() }
    }

    companion object {
        private const val KEY_LAST_SYNC_AT = "last_sync_at"
        private const val KEY_LOCAL_SYNC_OWNER_USER_ID = "local_sync_owner_user_id"
        private const val KEY_AUTO_SYNC_BLOCKED_UNTIL_LOCAL_CHANGE = "auto_sync_blocked_until_local_change"
        private const val BACKUP_RETENTION_MILLIS = 30L * 24L * 60L * 60L * 1000L
    }
}
