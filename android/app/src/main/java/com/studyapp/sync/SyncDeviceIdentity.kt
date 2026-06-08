package com.studyapp.sync

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SyncDeviceIdentity @Inject constructor(
    @ApplicationContext context: Context
) {
    private val preferences = context.getSharedPreferences("studyapp_sync", Context.MODE_PRIVATE)

    val current: String
        get() {
            val existing = preferences.getString(KEY_DEVICE_ID, null)
            if (!existing.isNullOrEmpty()) return existing
            val generated = UUID.randomUUID().toString().lowercase()
            preferences.edit().putString(KEY_DEVICE_ID, generated).apply()
            return generated
        }

    companion object {
        private const val KEY_DEVICE_ID = "sync_device_id"
    }
}
