package com.studyapp.data.repository

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.ContentResolver
import android.content.Context
import android.net.Uri
import android.os.Build
import android.os.Process
import androidx.core.content.ContextCompat
import com.ichi2.anki.FlashCardsContract
import com.ichi2.anki.api.AddContentApi
import com.studyapp.domain.model.AnkiIntegrationStatus
import com.studyapp.domain.model.AnkiTodayStats
import com.studyapp.domain.repository.AnkiRepository
import com.studyapp.domain.util.Clock
import dagger.hilt.android.qualifiers.ApplicationContext
import java.util.concurrent.TimeUnit
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

const val ANKI_PACKAGE_NAME = "com.ichi2.anki"

interface AnkiApiClient {
    fun isAnkiInstalled(): Boolean

    fun hasDatabasePermission(): Boolean

    fun getTodayAnsweredCardCount(): Int
}

interface AppUsageStatsReader {
    fun hasUsageAccess(): Boolean

    fun getUsageTimeMillis(packageName: String, startTime: Long, endTime: Long): Long
}

@Singleton
class AnkiDroidApiClient @Inject constructor(
    @ApplicationContext private val context: Context
) : AnkiApiClient {
    private val resolver: ContentResolver = context.contentResolver
    private val cardsContentUri: Uri = Uri.withAppendedPath(FlashCardsContract.AUTHORITY_URI, "cards")

    override fun isAnkiInstalled(): Boolean {
        return AddContentApi.getAnkiDroidPackageName(context) != null
    }

    override fun hasDatabasePermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            context,
            AddContentApi.READ_WRITE_PERMISSION
        ) == android.content.pm.PackageManager.PERMISSION_GRANTED
    }

    override fun getTodayAnsweredCardCount(): Int {
        return resolver.query(
            cardsContentUri,
            null,
            "prop:rated=0",
            null,
            null
        )?.use { cursor ->
            cursor.count
        } ?: 0
    }
}

@Singleton
class AndroidAppUsageStatsReader @Inject constructor(
    @ApplicationContext private val context: Context
) : AppUsageStatsReader {
    override fun hasUsageAccess(): Boolean {
        val appOpsManager = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOpsManager.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOpsManager.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS,
                Process.myUid(),
                context.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    override fun getUsageTimeMillis(packageName: String, startTime: Long, endTime: Long): Long {
        val usageStatsManager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        return usageStatsManager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            startTime,
            endTime
        )
            .orEmpty()
            .filter { it.packageName == packageName }
            .sumOf { it.totalTimeInForeground }
    }
}

@Singleton
class AnkiRepositoryImpl @Inject constructor(
    private val ankiApiClient: AnkiApiClient,
    private val usageStatsReader: AppUsageStatsReader,
    private val clock: Clock
) : AnkiRepository {
    private val stats = MutableStateFlow(AnkiTodayStats())
    private val refreshMutex = Mutex()

    override fun observeTodayStats(): Flow<AnkiTodayStats> = stats.asStateFlow()

    override suspend fun refreshTodayStats() {
        refreshMutex.withLock {
            val refreshedAt = clock.currentTimeMillis()
            val todayStart = clock.startOfToday()

            if (!ankiApiClient.isAnkiInstalled()) {
                stats.value = AnkiTodayStats(
                    lastUpdatedAt = refreshedAt,
                    status = AnkiIntegrationStatus.ANKI_NOT_INSTALLED
                )
                return
            }

            val hasAnkiPermission = ankiApiClient.hasDatabasePermission()
            val hasUsageAccess = usageStatsReader.hasUsageAccess()

            try {
                val answeredCards = if (hasAnkiPermission) {
                    ankiApiClient.getTodayAnsweredCardCount()
                } else {
                    null
                }
                val usageMinutes = if (hasUsageAccess) {
                    TimeUnit.MILLISECONDS.toMinutes(
                        usageStatsReader.getUsageTimeMillis(
                            packageName = ANKI_PACKAGE_NAME,
                            startTime = todayStart,
                            endTime = refreshedAt
                        )
                    )
                } else {
                    null
                }

                val status = when {
                    hasAnkiPermission && hasUsageAccess -> AnkiIntegrationStatus.AVAILABLE
                    !hasAnkiPermission -> AnkiIntegrationStatus.NEEDS_ANKI_PERMISSION
                    else -> AnkiIntegrationStatus.NEEDS_USAGE_ACCESS
                }

                stats.value = AnkiTodayStats(
                    answeredCards = answeredCards,
                    usageMinutes = usageMinutes,
                    lastUpdatedAt = refreshedAt,
                    status = status,
                    requiresAnkiPermission = !hasAnkiPermission,
                    requiresUsageAccess = !hasUsageAccess
                )
            } catch (_: SecurityException) {
                stats.value = AnkiTodayStats(
                    usageMinutes = if (hasUsageAccess) {
                        TimeUnit.MILLISECONDS.toMinutes(
                            usageStatsReader.getUsageTimeMillis(
                                packageName = ANKI_PACKAGE_NAME,
                                startTime = todayStart,
                                endTime = refreshedAt
                            )
                        )
                    } else {
                        null
                    },
                    lastUpdatedAt = refreshedAt,
                    status = AnkiIntegrationStatus.NEEDS_ANKI_PERMISSION,
                    requiresAnkiPermission = true,
                    requiresUsageAccess = !hasUsageAccess
                )
            } catch (e: Exception) {
                stats.value = AnkiTodayStats(
                    lastUpdatedAt = refreshedAt,
                    status = AnkiIntegrationStatus.ERROR,
                    requiresAnkiPermission = !hasAnkiPermission,
                    requiresUsageAccess = !hasUsageAccess,
                    errorMessage = e.message
                )
            }
        }
    }
}
