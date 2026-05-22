package com.studyapp.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AppPreferencesTest {
    @Test
    fun `defaults match iOS post weather removal`() {
        val preferences = AppPreferences()

        assertTrue(preferences.onboardingCompleted)
        assertTrue(preferences.timerNotificationRichEnabled)
        assertEquals(TimerNotificationDisplayPreset.STANDARD, preferences.timerNotificationDisplayPreset)
        assertEquals(LandscapeTimerDisplayPreset.PROBLEM_PROGRESS, preferences.landscapeTimerDisplayPreset)
    }
}
