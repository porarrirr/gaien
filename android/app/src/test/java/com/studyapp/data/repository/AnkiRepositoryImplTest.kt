package com.studyapp.data.repository

import com.studyapp.domain.model.AnkiIntegrationStatus
import com.studyapp.domain.util.Clock
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime

@OptIn(ExperimentalCoroutinesApi::class)
class AnkiRepositoryImplTest {
    private val ankiApiClient = mockk<AnkiApiClient>()
    private val usageStatsReader = mockk<AppUsageStatsReader>()
    private val clock = object : Clock {
        override fun currentTimeMillis(): Long = NOW

        override fun currentLocalDate(): LocalDate = LocalDate.of(2026, 3, 23)

        override fun currentLocalDateTime(): LocalDateTime = LocalDateTime.of(2026, 3, 23, 12, 0)

        override fun startOfDay(timestamp: Long): Long = START_OF_DAY

        override fun startOfToday(): Long = START_OF_DAY

        override fun startOfWeek(): Long = START_OF_DAY

        override fun startOfMonth(): Long = START_OF_DAY
    }

    @Test
    fun `reports not installed when ankidroid is missing`() = runTest {
        every { ankiApiClient.isAnkiInstalled() } returns false

        val repository = AnkiRepositoryImpl(ankiApiClient, usageStatsReader, clock)
        repository.refreshTodayStats()

        val stats = repository.observeTodayStats().first()
        assertEquals(AnkiIntegrationStatus.ANKI_NOT_INSTALLED, stats.status)
        assertNull(stats.answeredCards)
        assertNull(stats.usageMinutes)
    }

    @Test
    fun `reports available stats when both data sources are accessible`() = runTest {
        every { ankiApiClient.isAnkiInstalled() } returns true
        every { ankiApiClient.hasDatabasePermission() } returns true
        every { ankiApiClient.getTodayAnsweredCardCount() } returns 18
        every { usageStatsReader.hasUsageAccess() } returns true
        every { usageStatsReader.getUsageTimeMillis(ANKI_PACKAGE_NAME, START_OF_DAY, NOW) } returns 42 * 60_000L

        val repository = AnkiRepositoryImpl(ankiApiClient, usageStatsReader, clock)
        repository.refreshTodayStats()

        val stats = repository.observeTodayStats().first()
        assertEquals(AnkiIntegrationStatus.AVAILABLE, stats.status)
        assertEquals(18, stats.answeredCards)
        assertEquals(42L, stats.usageMinutes)
        assertFalse(stats.requiresAnkiPermission)
        assertFalse(stats.requiresUsageAccess)
    }

    @Test
    fun `reports usage access requirement while keeping answered cards`() = runTest {
        every { ankiApiClient.isAnkiInstalled() } returns true
        every { ankiApiClient.hasDatabasePermission() } returns true
        every { ankiApiClient.getTodayAnsweredCardCount() } returns 11
        every { usageStatsReader.hasUsageAccess() } returns false

        val repository = AnkiRepositoryImpl(ankiApiClient, usageStatsReader, clock)
        repository.refreshTodayStats()

        val stats = repository.observeTodayStats().first()
        assertEquals(AnkiIntegrationStatus.NEEDS_USAGE_ACCESS, stats.status)
        assertEquals(11, stats.answeredCards)
        assertNull(stats.usageMinutes)
        assertFalse(stats.requiresAnkiPermission)
        assertTrue(stats.requiresUsageAccess)
    }

    @Test
    fun `reports anki permission requirement while keeping usage time`() = runTest {
        every { ankiApiClient.isAnkiInstalled() } returns true
        every { ankiApiClient.hasDatabasePermission() } returns false
        every { usageStatsReader.hasUsageAccess() } returns true
        every { usageStatsReader.getUsageTimeMillis(ANKI_PACKAGE_NAME, START_OF_DAY, NOW) } returns 15 * 60_000L

        val repository = AnkiRepositoryImpl(ankiApiClient, usageStatsReader, clock)
        repository.refreshTodayStats()

        val stats = repository.observeTodayStats().first()
        assertEquals(AnkiIntegrationStatus.NEEDS_ANKI_PERMISSION, stats.status)
        assertNull(stats.answeredCards)
        assertEquals(15L, stats.usageMinutes)
        assertTrue(stats.requiresAnkiPermission)
        assertFalse(stats.requiresUsageAccess)
    }

    @Test
    fun `reports error state when anki query fails`() = runTest {
        every { ankiApiClient.isAnkiInstalled() } returns true
        every { ankiApiClient.hasDatabasePermission() } returns true
        every { ankiApiClient.getTodayAnsweredCardCount() } throws IllegalStateException("query failed")
        every { usageStatsReader.hasUsageAccess() } returns true
        every { usageStatsReader.getUsageTimeMillis(ANKI_PACKAGE_NAME, START_OF_DAY, NOW) } returns 0L

        val repository = AnkiRepositoryImpl(ankiApiClient, usageStatsReader, clock)
        repository.refreshTodayStats()

        val stats = repository.observeTodayStats().first()
        assertEquals(AnkiIntegrationStatus.ERROR, stats.status)
        assertEquals("query failed", stats.errorMessage)
    }

    private companion object {
        const val START_OF_DAY = 1_742_688_000_000L
        const val NOW = START_OF_DAY + 12 * 60 * 60 * 1000L
    }
}
