package com.studyapp.services

import android.Manifest
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import androidx.hilt.work.HiltWorker
import androidx.work.CoroutineWorker
import androidx.work.Data
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.WorkerParameters
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Result
import com.studyapp.presentation.settings.ReminderPreferences
import dagger.assisted.Assisted
import dagger.assisted.AssistedInject
import java.util.Calendar
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.flow.first

@HiltWorker
class ReminderWorker @AssistedInject constructor(
    @Assisted private val context: Context,
    @Assisted workerParams: WorkerParameters,
    private val reminderPreferences: ReminderPreferences,
    private val timetableRepository: TimetableRepository
) : CoroutineWorker(context, workerParams) {

    override suspend fun doWork(): Result {
        val workType = inputData.getString(KEY_WORK_TYPE)
        if (workType == null && reminderPreferences.isReminderEnabled().first()) {
            scheduleReminderInternal(
                applicationContext,
                inputData.getInt(KEY_REMINDER_HOUR, 20),
                inputData.getInt(KEY_REMINDER_MINUTE, 0),
                cancelExisting = false
            )
        } else if (workType == WORK_TYPE_TIMETABLE_REVIEW) {
            scheduleTimetableReviewInternal(applicationContext, cancelExisting = false)
        }
        val notificationManager = NotificationManagerCompat.from(applicationContext)
        if (!hasNotificationPermission() || !notificationManager.areNotificationsEnabled()) {
            Log.i(TAG, "Skipping reminder notification because notifications are unavailable")
            return Result.success()
        }

        return when (inputData.getString(KEY_WORK_TYPE)) {
            WORK_TYPE_TIMETABLE_REVIEW -> showTimetableReviewNotification(notificationManager)
            else -> showStudyReminderNotification(notificationManager)
        }
    }

    private suspend fun showStudyReminderNotification(
        notificationManager: NotificationManagerCompat
    ): Result {
        val enabled = reminderPreferences.isReminderEnabled().first()
        if (!enabled) return Result.success()
        return try {
            val notification = NotificationCompat.Builder(applicationContext, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_agenda)
                .setContentTitle("学習時間です！")
                .setContentText("今日の学習を始めましょう")
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .build()
            notificationManager.notify(STUDY_NOTIFICATION_ID, notification)
            Result.success()
        } catch (e: SecurityException) {
            Log.w(TAG, "Reminder notification could not be shown due to missing permission", e)
            Result.failure()
        } catch (e: Exception) {
            Log.e(TAG, "Reminder notification failed", e)
            Result.failure()
        }
    }

    private suspend fun showTimetableReviewNotification(
        notificationManager: NotificationManagerCompat
    ): Result {
        val overdueCount = when (val result = timetableRepository.getOverdueReviewCount()) {
            is com.studyapp.domain.util.Result.Success -> result.data
            is com.studyapp.domain.util.Result.Error -> return Result.failure()
        }
        if (overdueCount <= 0) {
            notificationManager.cancel(TIMETABLE_REVIEW_NOTIFICATION_ID)
            return Result.success()
        }
        return try {
            val notification = NotificationCompat.Builder(applicationContext, TIMETABLE_REVIEW_CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_menu_today)
                .setContentTitle("時間割の復習")
                .setContentText("48時間を超えた未復習の授業が${overdueCount}件あります。時間割で確認しましょう。")
                .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                .setAutoCancel(true)
                .build()
            notificationManager.notify(TIMETABLE_REVIEW_NOTIFICATION_ID, notification)
            Result.success()
        } catch (e: SecurityException) {
            Log.w(TAG, "Timetable review notification could not be shown", e)
            Result.failure()
        } catch (e: Exception) {
            Log.e(TAG, "Timetable review notification failed", e)
            Result.failure()
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
        const val TIMETABLE_REVIEW_CHANNEL_ID = "timetable_review_reminder"
        private const val WORK_NAME = "study_reminder_work"
        private const val TIMETABLE_REVIEW_WORK_NAME = "timetable_review_reminder_work"
        private const val STUDY_NOTIFICATION_ID = 2001
        private const val TIMETABLE_REVIEW_NOTIFICATION_ID = 2002
        private const val KEY_WORK_TYPE = "work_type"
        private const val KEY_REMINDER_HOUR = "reminder_hour"
        private const val KEY_REMINDER_MINUTE = "reminder_minute"
        private const val WORK_TYPE_TIMETABLE_REVIEW = "timetable_review"
        private const val DAILY_REMINDER_TAG = "study_daily_reminder"
        private const val TIMETABLE_REVIEW_TAG = "timetable_review_reminder"

        fun scheduleReminder(context: Context, hour: Int, minute: Int) {
            scheduleReminderInternal(context, hour, minute, cancelExisting = true)
        }

        private fun scheduleReminderInternal(context: Context, hour: Int, minute: Int, cancelExisting: Boolean) {
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

                val workManager = WorkManager.getInstance(context)
                if (cancelExisting) workManager.cancelAllWorkByTag(DAILY_REMINDER_TAG)
                val workRequest = OneTimeWorkRequestBuilder<ReminderWorker>()
                    .setInitialDelay(initialDelay, TimeUnit.MILLISECONDS)
                    .setInputData(
                        Data.Builder()
                            .putInt(KEY_REMINDER_HOUR, hour)
                            .putInt(KEY_REMINDER_MINUTE, minute)
                            .build()
                    )
                    .addTag(DAILY_REMINDER_TAG)
                    .build()

                workManager.enqueueUniqueWork(
                    "$WORK_NAME-${target.timeInMillis}",
                    ExistingWorkPolicy.KEEP,
                    workRequest
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule reminder at %02d:%02d".format(hour, minute), e)
            }
        }

        fun scheduleTimetableReviewCheck(context: Context, overdueCount: Int) {
            if (overdueCount <= 0) {
                cancelTimetableReviewReminder(context)
                return
            }
            scheduleTimetableReviewInternal(context, cancelExisting = true)
        }

        private fun scheduleTimetableReviewInternal(context: Context, cancelExisting: Boolean) {
            try {
                val now = Calendar.getInstance()
                val target = Calendar.getInstance().apply {
                    set(Calendar.HOUR_OF_DAY, 20)
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                    if (before(now)) add(Calendar.DAY_OF_MONTH, 1)
                }
                val workManager = WorkManager.getInstance(context)
                if (cancelExisting) workManager.cancelAllWorkByTag(TIMETABLE_REVIEW_TAG)
                val request = OneTimeWorkRequestBuilder<ReminderWorker>()
                    .setInitialDelay(target.timeInMillis - now.timeInMillis, TimeUnit.MILLISECONDS)
                    .setInputData(
                        Data.Builder()
                            .putString(KEY_WORK_TYPE, WORK_TYPE_TIMETABLE_REVIEW)
                            .build()
                    )
                    .addTag(TIMETABLE_REVIEW_TAG)
                    .build()
                workManager.enqueueUniqueWork(
                    "$TIMETABLE_REVIEW_WORK_NAME-${target.timeInMillis}",
                    ExistingWorkPolicy.KEEP,
                    request
                )
            } catch (e: Exception) {
                Log.e(TAG, "Failed to schedule timetable review reminder", e)
            }
        }

        fun cancelReminder(context: Context) {
            try {
                WorkManager.getInstance(context).cancelAllWorkByTag(DAILY_REMINDER_TAG)
                cancelTimetableReviewReminder(context)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel reminder", e)
            }
        }

        fun cancelTimetableReviewReminder(context: Context) {
            try {
                WorkManager.getInstance(context).cancelAllWorkByTag(TIMETABLE_REVIEW_TAG)
                NotificationManagerCompat.from(context).cancel(TIMETABLE_REVIEW_NOTIFICATION_ID)
            } catch (e: Exception) {
                Log.e(TAG, "Failed to cancel timetable review reminder", e)
            }
        }
    }
}
