package com.studyapp.sync

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import org.json.JSONObject

@Singleton
class SyncPreferences @Inject constructor(
    @ApplicationContext context: Context
) {
    private val preferences = context.getSharedPreferences("studyapp_sync", Context.MODE_PRIVATE)

    fun loadSession(): AuthSession? {
        val raw = preferences.getString(KEY_SESSION, null) ?: return null
        val json = JSONObject(raw)
        return AuthSession(
            localId = json.getString("localId"),
            email = json.optString("email"),
            idToken = json.getString("idToken"),
            refreshToken = json.getString("refreshToken")
        )
    }

    fun saveSession(session: AuthSession?) {
        preferences.edit().apply {
            if (session == null) {
                remove(KEY_SESSION)
            } else {
                putString(
                    KEY_SESSION,
                    JSONObject()
                        .put("localId", session.localId)
                        .put("email", session.email)
                        .put("idToken", session.idToken)
                        .put("refreshToken", session.refreshToken)
                        .toString()
                )
            }
        }.apply()
    }

    fun getLastSyncAt(): Long? {
        return if (preferences.contains(KEY_LAST_SYNC_AT)) preferences.getLong(KEY_LAST_SYNC_AT, 0L) else null
    }

    fun setLastSyncAt(timestamp: Long?) {
        preferences.edit().apply {
            if (timestamp == null) remove(KEY_LAST_SYNC_AT) else putLong(KEY_LAST_SYNC_AT, timestamp)
        }.apply()
    }

    companion object {
        private const val KEY_SESSION = "session"
        private const val KEY_LAST_SYNC_AT = "last_sync_at"
    }
}

