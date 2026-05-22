package com.studyapp.services

import android.content.Context
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Result
import com.studyapp.presentation.settings.ReminderPreferences
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.first

@Singleton
class ReminderRefreshCoordinator @Inject constructor(
    @ApplicationContext private val context: Context,
    private val reminderPreferences: ReminderPreferences,
    private val timetableRepository: TimetableRepository
) {
    suspend fun refreshTimetableReviewReminder() {
        val enabled = reminderPreferences.isReminderEnabled().first()
        if (!enabled) {
            ReminderWorker.cancelTimetableReviewReminder(context)
            return
        }
        val overdueCount = when (val result = timetableRepository.getOverdueReviewCount()) {
            is Result.Success -> result.data
            is Result.Error -> return
        }
        ReminderWorker.scheduleTimetableReviewCheck(context, overdueCount)
    }
}
