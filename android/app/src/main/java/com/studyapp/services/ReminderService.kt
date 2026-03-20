package com.studyapp.services

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import android.content.pm.PackageManager
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.util.Calendar
import java.util.concurrent.TimeUnit

@HiltWorker
class ReminderWorker @AssistedInject constructor(
    @Assisted private val context: Context,
    @Assisted workerParams: WorkerParameters
) : CoroutineWorker(context, workerParams) {
    
    override suspend fun doWork(): Result {
        val notificationManager = NotificationManagerCompat.from(applicationContext)
        if (!hasNotificationPermission() || !notificationManager.areNotificationsEnabled()) {
            Log.i(TAG, "Skipping reminder notification because notifications are unavailable")
            return Result.success()
        }

        return if (showNotification(notificationManager)) {
            Result.success()
        } else {
            Result.failure()
        }
    }
    
    private fun showNotification(notificationManager: NotificationManagerCompat): Boolean {
        try {
            val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_agenda)
                .setContentTitle("学習時間です！")
                .setContentText("今日の学習を始めましょう")
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .build()
            
            notificationManager.notify(NOTIFICATION_ID, notification)
            return true
        } catch (e: SecurityException) {
            Log.w(TAG, "Reminder notification could not be shown due to missing permission", e)
            return false
        } catch (e: Exception) {
            Log.e(TAG, "Reminder notification failed", e)
            return false
        }
    }

    private fun hasNotificationPermission(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            ContextCompat.checkSelfPermission(
                applicationContext,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
    }
    
    companion object {
        private const val TAG = "ReminderWorker"
        const val CHANNEL_ID = "study_reminder"
        private const val WORK_NAME = "study_reminder_work"
        private const val NOTIFICATION_ID = 2001
        
        fun scheduleReminder(context: Context, hour: Int, minute: Int) {
            try {
                val now = Calendar.getInstance()
                val target = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                    if (before(now)) {
                        add(Calendar.DAY_OF_MONTH, 1)
                    }
                }
                
                val initialDelay = target.timeInMillis - now.timeInMillis
                
                val workRequest = PeriodicWorkRequestBuilder<ReminderWorker>(
                    1, TimeUnit.DAYS
                )
                    .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
                    .build()
                
                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    WORK_NAME,
                    ExistingPeriodicWorkPolicy.UPDATE,
                    workRequest
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule reminder at %02d:%02d".format(hour, minute), e)
            }
        }
        
        fun cancelReminder(context: Context) {
            try {
                WorkManager.getInstance(context).cancelUniqueWork(WORK_NAME)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel reminder", e)
            }
        }
    }
}
