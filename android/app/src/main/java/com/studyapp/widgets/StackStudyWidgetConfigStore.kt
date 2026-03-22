package com.studyapp.widgets

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map

private val Context.stackStudyWidgetDataStore: DataStore<Preferences> by preferencesDataStore(
    name = "stack_study_widget_config"
)

data class StackWidgetConfig(
    val appWidgetId: Int,
    val enabledCards: List<StudyWidgetCardType>
) {
    companion object {
        fun default(appWidgetId: Int): StackWidgetConfig {
            return StackWidgetConfig(
                appWidgetId = appWidgetId,
                enabledCards = StudyWidgetCardType.defaultOrder()
            )
        }
    }
}

@Singleton
class StackStudyWidgetConfigStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    suspend fun saveConfig(config: StackWidgetConfig) {
        context.stackStudyWidgetDataStore.edit { prefs ->
            prefs[cardsKey(config.appWidgetId)] = serializeCards(config.enabledCards)
        }
    }

    suspend fun getConfig(appWidgetId: Int): StackWidgetConfig? {
        val cards = context.stackStudyWidgetDataStore.data.map { prefs ->
            prefs[cardsKey(appWidgetId)]?.let(::deserializeCards)
        }.first()
        return cards?.let { StackWidgetConfig(appWidgetId = appWidgetId, enabledCards = it) }
    }

    suspend fun getConfigOrDefault(appWidgetId: Int): StackWidgetConfig {
        return getConfig(appWidgetId) ?: StackWidgetConfig.default(appWidgetId)
    }

    suspend fun removeConfig(appWidgetId: Int) {
        context.stackStudyWidgetDataStore.edit { prefs ->
            prefs.remove(cardsKey(appWidgetId))
        }
    }

    companion object {
        internal fun cardsKey(appWidgetId: Int): Preferences.Key<String> {
            return stringPreferencesKey("stack_widget_${appWidgetId}_cards")
        }

        internal fun serializeCards(cards: List<StudyWidgetCardType>): String {
            return cards
                .distinct()
                .joinToString(separator = ",") { it.name }
        }

        internal fun deserializeCards(value: String): List<StudyWidgetCardType> {
            val parsed = value
                .split(",")
                .mapNotNull { token ->
                    StudyWidgetCardType.entries.firstOrNull { it.name == token.trim() }
                }
                .distinct()
            return parsed.ifEmpty { StudyWidgetCardType.defaultOrder() }
        }
    }
}
