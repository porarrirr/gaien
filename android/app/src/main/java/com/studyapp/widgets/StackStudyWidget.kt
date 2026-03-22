package com.studyapp.widgets

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.KeyboardArrowDown
import androidx.compose.material.icons.filled.KeyboardArrowUp
import androidx.compose.material3.Button
import androidx.compose.material3.Checkbox
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.res.stringResource
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.studyapp.MainActivity
import com.studyapp.R
import com.studyapp.presentation.settings.ColorTheme
import com.studyapp.presentation.settings.ThemeMode
import com.studyapp.presentation.settings.ThemePreferences
import com.studyapp.presentation.theme.StudyAppTheme
import dagger.hilt.android.AndroidEntryPoint
import dagger.hilt.android.EntryPointAccessors
import javax.inject.Inject
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking

class StackStudyWidgetReceiver : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        updateWidgets(context, appWidgetManager, appWidgetIds)
    }

    override fun onDeleted(context: Context, appWidgetIds: IntArray) {
        val entryPoint = context.studyWidgetEntryPoint()
        val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
        appWidgetIds.forEach { appWidgetId ->
            scope.launch {
                entryPoint.stackWidgetConfigStore().removeConfig(appWidgetId)
            }
        }
        super.onDeleted(context, appWidgetIds)
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val componentName = ComponentName(context, StackStudyWidgetReceiver::class.java)
            val appWidgetIds = manager.getAppWidgetIds(componentName)
            if (appWidgetIds.isNotEmpty()) {
                updateWidgets(context, manager, appWidgetIds)
            }
        }

        fun updateWidget(context: Context, appWidgetId: Int) {
            val manager = AppWidgetManager.getInstance(context)
            updateWidgets(context, manager, intArrayOf(appWidgetId))
        }

        private fun updateWidgets(
            context: Context,
            appWidgetManager: AppWidgetManager,
            appWidgetIds: IntArray
        ) {
            appWidgetIds.forEach { appWidgetId ->
                val views = buildRemoteViews(context, appWidgetId)
                appWidgetManager.updateAppWidget(appWidgetId, views)
            }
            appWidgetManager.notifyAppWidgetViewDataChanged(
                appWidgetIds,
                R.id.stack_widget_view
            )
        }

        private fun buildRemoteViews(context: Context, appWidgetId: Int): RemoteViews {
            val intent = Intent(context, StackStudyWidgetRemoteViewsService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }

            val layoutResId = StackStudyWidgetHostCompatibility.resolveCollectionLayout(
                manufacturer = Build.MANUFACTURER,
                brand = Build.BRAND
            )

            return RemoteViews(context.packageName, layoutResId).apply {
                setRemoteAdapter(R.id.stack_widget_view, intent)
                setEmptyView(R.id.stack_widget_view, R.id.stack_widget_empty)

                val clickIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val pendingIntent = android.app.PendingIntent.getActivity(
                    context,
                    appWidgetId,
                    clickIntent,
                    android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
                )
                setPendingIntentTemplate(R.id.stack_widget_view, pendingIntent)
            }
        }
    }
}

class StackStudyWidgetRemoteViewsService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory {
        return StackStudyWidgetRemoteViewsFactory(
            context = applicationContext,
            appWidgetId = intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID
            )
        )
    }
}

private class StackStudyWidgetRemoteViewsFactory(
    private val context: Context,
    private val appWidgetId: Int
) : RemoteViewsService.RemoteViewsFactory {
    private var cards: List<StackStudyWidgetCard> = emptyList()

    override fun onCreate() {
        loadCards()
    }

    override fun onDataSetChanged() {
        loadCards()
    }

    override fun onDestroy() = Unit

    override fun getCount(): Int = cards.size

    override fun getViewAt(position: Int): RemoteViews? {
        val card = cards.getOrNull(position) ?: return null
        val views = when (card) {
            is StackStudyWidgetCard.TextCard -> buildTextCard(context, card)
            is StackStudyWidgetCard.WeeklyActivity -> buildWeeklyActivityCard(context, card)
        }
        val fillInIntent = Intent().apply {
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
        }
        views.setOnClickFillInIntent(R.id.widget_item_root, fillInIntent)
        return views
    }

    override fun getLoadingView(): RemoteViews {
        return RemoteViews(context.packageName, R.layout.widget_loading)
    }

    override fun getViewTypeCount(): Int = 2

    override fun getItemId(position: Int): Long {
        return cards.getOrNull(position)?.type?.ordinal?.toLong() ?: position.toLong()
    }

    override fun hasStableIds(): Boolean = true

    private fun loadCards() {
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            cards = emptyList()
            return
        }
        val entryPoint = context.studyWidgetEntryPoint()
        cards = runBlocking {
            val config = entryPoint.stackWidgetConfigStore().getConfigOrDefault(appWidgetId)
            val snapshot = loadStudyWidgetSnapshot(context)
            entryPoint.stackStudyWidgetSnapshotMapper().map(snapshot, config.enabledCards)
        }
    }
}

@AndroidEntryPoint
class StackStudyWidgetConfigureActivity : ComponentActivity() {

    @Inject
    lateinit var themePreferences: ThemePreferences

    @Inject
    lateinit var configStore: StackStudyWidgetConfigStore

    private var appWidgetId: Int = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        setResult(Activity.RESULT_CANCELED)
        appWidgetId = intent?.getIntExtra(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID

        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val initialCards = runBlocking {
            configStore.getConfigOrDefault(appWidgetId).enabledCards
        }

        setContent {
            val colorTheme by themePreferences.getPrimaryColor()
                .collectAsStateWithLifecycle(initialValue = ColorTheme.GREEN)
            val themeMode by themePreferences.getThemeMode()
                .collectAsStateWithLifecycle(initialValue = ThemeMode.SYSTEM)

            StudyAppTheme(
                colorTheme = colorTheme,
                themeMode = themeMode
            ) {
                Surface(
                    modifier = Modifier.fillMaxSize(),
                    color = MaterialTheme.colorScheme.background
                ) {
                    StackStudyWidgetConfigureScreen(
                        initialCards = initialCards,
                        onCancel = { finish() },
                        onSave = { orderedCards ->
                            saveAndFinish(orderedCards)
                        }
                    )
                }
            }
        }
    }

    private fun saveAndFinish(orderedCards: List<StudyWidgetCardType>) {
        CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate).launch {
            configStore.saveConfig(
                StackWidgetConfig(
                    appWidgetId = appWidgetId,
                    enabledCards = orderedCards
                )
            )
            StackStudyWidgetReceiver.updateWidget(this@StackStudyWidgetConfigureActivity, appWidgetId)
            setResult(
                Activity.RESULT_OK,
                Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId)
            )
            finish()
        }
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StackStudyWidgetConfigureScreen(
    initialCards: List<StudyWidgetCardType>,
    onCancel: () -> Unit,
    onSave: (List<StudyWidgetCardType>) -> Unit
) {
    val cardStates = remember {
        mutableStateListOf<WidgetSelectionItem>().apply {
            addAll(
                StudyWidgetCardType.defaultOrder().map { type ->
                    WidgetSelectionItem(type = type, enabled = type in initialCards)
                }
            )
        }
    }
    val enabledCount = cardStates.count { it.enabled }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(stringResource(R.string.stack_widget_config_title)) }
            )
        }
    ) { paddingValues ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(paddingValues)
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp)
        ) {
            Text(
                text = stringResource(R.string.stack_widget_config_description),
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant
            )

            LazyColumn(
                modifier = Modifier.weight(1f),
                verticalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                itemsIndexed(
                    items = cardStates,
                    key = { _, item -> item.type.name }
                ) { index, item ->
                    WidgetSelectionRow(
                        item = item,
                        canMoveUp = index > 0,
                        canMoveDown = index < cardStates.lastIndex,
                        onToggle = { enabled ->
                            cardStates[index] = item.copy(enabled = enabled)
                        },
                        onMoveUp = {
                            cardStates.swap(index, index - 1)
                        },
                        onMoveDown = {
                            cardStates.swap(index, index + 1)
                        }
                    )
                }
            }

            if (enabledCount == 0) {
                Text(
                    text = stringResource(R.string.stack_widget_config_validation),
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall
                )
            }

            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                OutlinedButton(
                    onClick = onCancel,
                    modifier = Modifier.weight(1f)
                ) {
                    Text(stringResource(R.string.cancel))
                }
                Button(
                    onClick = {
                        onSave(cardStates.filter { it.enabled }.map { it.type })
                    },
                    enabled = enabledCount > 0,
                    modifier = Modifier.weight(1f)
                ) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = null
                    )
                    Spacer(modifier = Modifier.width(8.dp))
                    Text(stringResource(R.string.save))
                }
            }
        }
    }
}

@Composable
private fun WidgetSelectionRow(
    item: WidgetSelectionItem,
    canMoveUp: Boolean,
    canMoveDown: Boolean,
    onToggle: (Boolean) -> Unit,
    onMoveUp: () -> Unit,
    onMoveDown: () -> Unit
) {
    Surface(
        tonalElevation = 2.dp,
        shape = MaterialTheme.shapes.medium
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Checkbox(
                checked = item.enabled,
                onCheckedChange = onToggle
            )
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = item.type.displayName,
                    style = MaterialTheme.typography.titleMedium,
                    fontWeight = androidx.compose.ui.text.font.FontWeight.Medium
                )
                Text(
                    text = "ホーム画面でスワイプ表示します",
                    style = MaterialTheme.typography.bodySmall,
                    color = MaterialTheme.colorScheme.onSurfaceVariant
                )
            }
            Column {
                IconButton(onClick = onMoveUp, enabled = canMoveUp) {
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowUp,
                        contentDescription = null
                    )
                }
                IconButton(onClick = onMoveDown, enabled = canMoveDown) {
                    Icon(
                        imageVector = Icons.Default.KeyboardArrowDown,
                        contentDescription = null
                    )
                }
            }
        }
    }
}

private data class WidgetSelectionItem(
    val type: StudyWidgetCardType,
    val enabled: Boolean
)

private fun <T> MutableList<T>.swap(fromIndex: Int, toIndex: Int) {
    val fromItem = this[fromIndex]
    this[fromIndex] = this[toIndex]
    this[toIndex] = fromItem
}

private fun buildTextCard(context: Context, card: StackStudyWidgetCard.TextCard): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_stack_item_text).apply {
        setTextViewText(R.id.widget_item_title, card.title)
        setTextViewText(R.id.widget_item_value, card.value)
        setTextColor(R.id.widget_item_value, card.valueColor)
        setFloat(
            R.id.widget_item_value,
            "setTextSize",
            if (card.valueStyle == StackStudyWidgetCard.ValueStyle.HERO) 28f else 20f
        )

        if (card.body.isNullOrBlank()) {
            setViewVisibility(R.id.widget_item_body, View.GONE)
            setTextViewText(R.id.widget_item_body, "")
        } else {
            setViewVisibility(R.id.widget_item_body, View.VISIBLE)
            setTextViewText(R.id.widget_item_body, card.body)
            setInt(R.id.widget_item_body, "setMaxLines", card.bodyMaxLines)
        }

        if (card.caption.isNullOrBlank()) {
            setViewVisibility(R.id.widget_item_caption, View.GONE)
            setTextViewText(R.id.widget_item_caption, "")
        } else {
            setViewVisibility(R.id.widget_item_caption, View.VISIBLE)
            setTextViewText(R.id.widget_item_caption, card.caption)
        }

        if (card.progress == null) {
            setViewVisibility(R.id.widget_item_progress_row, View.GONE)
        } else {
            setViewVisibility(R.id.widget_item_progress_row, View.VISIBLE)
            applySegmentedProgress(this, card.progress)
        }

        val extraIds = listOf(R.id.widget_item_extra_one, R.id.widget_item_extra_two)
        extraIds.forEach { viewId ->
            setViewVisibility(viewId, View.GONE)
            setTextViewText(viewId, "")
        }
        card.extraLines.take(extraIds.size).forEachIndexed { index, line ->
            val viewId = extraIds[index]
            setViewVisibility(viewId, View.VISIBLE)
            setTextViewText(viewId, line)
        }
    }
}

private fun buildWeeklyActivityCard(context: Context, card: StackStudyWidgetCard.WeeklyActivity): RemoteViews {
    return RemoteViews(context.packageName, R.layout.widget_stack_item_weekly_activity).apply {
        setTextViewText(R.id.widget_item_title, card.title)
        setTextViewText(R.id.widget_item_total, card.total)

        val lineIds = listOf(
            R.id.widget_item_line_one,
            R.id.widget_item_line_two,
            R.id.widget_item_line_three,
            R.id.widget_item_line_four,
            R.id.widget_item_line_five,
            R.id.widget_item_line_six,
            R.id.widget_item_line_seven
        )
        lineIds.forEach { viewId ->
            setViewVisibility(viewId, View.GONE)
            setTextViewText(viewId, "")
        }
        card.lines.take(lineIds.size).forEachIndexed { index, line ->
            val viewId = lineIds[index]
            setViewVisibility(viewId, View.VISIBLE)
            setTextViewText(viewId, line)
        }

        if (card.caption.isNullOrBlank()) {
            setViewVisibility(R.id.widget_item_caption, View.GONE)
            setTextViewText(R.id.widget_item_caption, "")
        } else {
            setViewVisibility(R.id.widget_item_caption, View.VISIBLE)
            setTextViewText(R.id.widget_item_caption, card.caption)
        }
    }
}

private fun applySegmentedProgress(views: RemoteViews, progress: Float) {
    val filledSegments = (progress.coerceIn(0f, 1f) * 10f).toInt().coerceIn(0, 10)
    val segmentIds = listOf(
        R.id.widget_progress_segment_1,
        R.id.widget_progress_segment_2,
        R.id.widget_progress_segment_3,
        R.id.widget_progress_segment_4,
        R.id.widget_progress_segment_5,
        R.id.widget_progress_segment_6,
        R.id.widget_progress_segment_7,
        R.id.widget_progress_segment_8,
        R.id.widget_progress_segment_9,
        R.id.widget_progress_segment_10
    )
    segmentIds.forEachIndexed { index, viewId ->
        val colorRes = if (index < filledSegments) {
            R.color.widget_primary
        } else {
            R.color.widget_progress_background
        }
        views.setInt(viewId, "setBackgroundResource", colorRes)
    }
}

internal object StackStudyWidgetHostCompatibility {
    private val listFallbackManufacturers = setOf("xiaomi", "redmi", "poco")

    fun resolveCollectionLayout(
        manufacturer: String?,
        brand: String?
    ): Int {
        val normalizedManufacturer = manufacturer?.trim()?.lowercase().orEmpty()
        val normalizedBrand = brand?.trim()?.lowercase().orEmpty()
        val needsListFallback = normalizedManufacturer in listFallbackManufacturers ||
            normalizedBrand in listFallbackManufacturers

        return if (needsListFallback) {
            R.layout.widget_stack_root_list
        } else {
            R.layout.widget_stack_root
        }
    }
}

private fun Context.studyWidgetEntryPoint(): StudyWidgetEntryPoint {
    return EntryPointAccessors.fromApplication(
        applicationContext,
        StudyWidgetEntryPoint::class.java
    )
}
