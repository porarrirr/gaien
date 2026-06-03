package com.studyapp.domain.model

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Test

class AppPreferencesTest {
    @Test
    fun `defaults match iOS post weather removal`() {
        val preferences = AppPreferences()

        assertFalse(preferences.onboardingCompleted)
        assertEquals(TimerNotificationDisplayPreset.STANDARD, preferences.timerNotificationDisplayPreset)
        assertEquals(LandscapeTimerDisplayPreset.PROBLEM_PROGRESS, preferences.landscapeTimerDisplayPreset)
    }

    @Test
    fun `color theme tokens match iOS color theme values`() {
        assertEquals(0x2E9D45, ColorTheme.GREEN.hex)
        assertEquals(0x1E88E5, ColorTheme.BLUE.hex)
        assertEquals(0xF59E0B, ColorTheme.ORANGE.hex)
        assertEquals(0x1E88E5, ColorTheme.GREEN.accentHex)
        assertEquals(0x2E9D45, ColorTheme.BLUE.accentHex)
        assertEquals(0x1E88E5, ColorTheme.ORANGE.accentHex)
    }
}
