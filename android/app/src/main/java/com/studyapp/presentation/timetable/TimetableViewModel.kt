package com.studyapp.presentation.timetable

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.studyapp.domain.model.TimetableEntry
import com.studyapp.domain.model.TimetableLesson
import com.studyapp.domain.model.TimetablePeriod
import com.studyapp.domain.model.TimetableReviewRecord
import com.studyapp.domain.model.TimetableTerm
import com.studyapp.domain.model.StudyWeekday
import com.studyapp.domain.repository.TimetableRepository
import com.studyapp.domain.util.Clock
import dagger.hilt.android.lifecycle.HiltViewModel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import java.time.LocalDate
import java.time.temporal.ChronoUnit
import javax.inject.Inject

data class TimetableUiState(
    val isLoading: Boolean = true,
    val error: String? = null,
    val periods: List<TimetablePeriod> = emptyList(),
    val entries: List<TimetableEntry> = emptyList(),
    val terms: List<TimetableTerm> = emptyList(),
    val reviewRecords: List<TimetableReviewRecord> = emptyList(),
    val selectedTermId: Long? = null,
    val selectedDate: LocalDate = LocalDate.now(),
    val entriesBySlot: Map<Pair<StudyWeekday, Long>, TimetableEntry> = emptyMap(),
    val selectedDateOccurrences: List<TimetableReviewOccurrence> = emptyList(),
    val termSummary: TimetableReviewSummary = TimetableReviewSummary.empty
)

data class TimetableReviewOccurrence(
    val term: TimetableTerm,
    val entry: TimetableEntry,
    val period: TimetablePeriod,
    val occurrenceDate: Long,
    val record: TimetableReviewRecord?
) {
    val isReviewed: Boolean get() = record?.isReviewed == true
    val isExcluded: Boolean get() = record?.isExcluded == true
    val isPending: Boolean get() = !isReviewed && !isExcluded
    val isOverdue: Boolean get() = isPending && occurrenceDate < LocalDate.now().toEpochDay()
    val note: String? get() = record?.note
}

data class TimetableReviewSummary(
    val reviewed: Int,
    val pending: Int,
    val excluded: Int
) {
    val total: Int get() = reviewed + pending + excluded
    val completionRate: Float get() = if (total > 0) reviewed.toFloat() / total.toFloat() else 0f

    companion object {
        val empty = TimetableReviewSummary(reviewed = 0, pending = 0, excluded = 0)
    }
}

@HiltViewModel
class TimetableViewModel @Inject constructor(
    private val timetableRepository: TimetableRepository,
    private val clock: Clock
) : ViewModel() {

    private val _uiState = MutableStateFlow(TimetableUiState())
    val uiState: StateFlow<TimetableUiState> = _uiState.asStateFlow()

    init {
        loadData()
    }

    private fun loadData() {
        combine(
            timetableRepository.getAllPeriods(),
            timetableRepository.getAllEntries(),
            timetableRepository.getAllTerms(),
            timetableRepository.getAllReviewRecords()
        ) { periodsResult, entriesResult, termsResult, recordsResult ->
            val periods = periodsResult.getOrNull() ?: emptyList()
            val entries = entriesResult.getOrNull() ?: emptyList()
            val terms = termsResult.getOrNull() ?: emptyList()
            val records = recordsResult.getOrNull() ?: emptyList()
            Quad(periods, entries, terms, records)
        }
        .onEach { (periods, entries, terms, records) ->
            val currentState = _uiState.value
            val selectedTermId = currentState.selectedTermId
                ?: terms.firstOrNull { it.isActive && it.deletedAt == null }?.id
                ?: terms.firstOrNull { it.deletedAt == null }?.id

            if (periods.isEmpty()) {
                createDefaultPeriods()
                return@onEach
            }

            if (terms.isEmpty() && selectedTermId == null) {
                createDefaultTerm()
                return@onEach
            }

            val selectedTerm = terms.find { it.id == selectedTermId && it.deletedAt == null }
            val selectedDate = currentState.selectedDate.let { date ->
                if (selectedTerm != null && !selectedTerm.contains(date)) {
                    if (selectedTerm.contains(LocalDate.now())) LocalDate.now()
                    else LocalDate.ofEpochDay(selectedTerm.startDate)
                } else date
            }

            val activeEntries = entries.filter { it.deletedAt == null }
            val entriesBySlot = buildEntriesBySlot(activeEntries, selectedDate)
            val occurrences = if (selectedTerm != null) {
                buildOccurrences(selectedDate, selectedTerm, activeEntries, periods, records)
            } else emptyList()
            val termSummary = if (selectedTerm != null) {
                buildTermSummary(selectedTerm, activeEntries, periods, records)
            } else TimetableReviewSummary.empty

            _uiState.update { state ->
                state.copy(
                    isLoading = false,
                    error = null,
                    periods = periods.filter { it.deletedAt == null },
                    entries = activeEntries,
                    terms = terms.filter { it.deletedAt == null },
                    reviewRecords = records.filter { it.deletedAt == null },
                    selectedTermId = selectedTermId,
                    selectedDate = selectedDate,
                    entriesBySlot = entriesBySlot,
                    selectedDateOccurrences = occurrences,
                    termSummary = termSummary
                )
            }
        }
        .launchIn(viewModelScope)
    }

    private fun buildEntriesBySlot(
        entries: List<TimetableEntry>,
        referenceDate: LocalDate
    ): Map<Pair<StudyWeekday, Long>, TimetableEntry> {
        val epochDay = referenceDate.toEpochDay()
        return entries
            .filter { entry ->
                (entry.validFromDate?.let { epochDay >= it } ?: true) &&
                (entry.validToDate?.let { epochDay <= it } ?: true)
            }
            .groupBy { Pair(it.dayOfWeek, it.periodId) }
            .mapValues { (_, v) -> v.maxByOrNull { it.updatedAt }!! }
    }

    private fun buildOccurrences(
        date: LocalDate,
        term: TimetableTerm,
        entries: List<TimetableEntry>,
        periods: List<TimetablePeriod>,
        records: List<TimetableReviewRecord>
    ): List<TimetableReviewOccurrence> {
        val epochDay = date.toEpochDay()
        if (epochDay < term.startDate || epochDay > term.endDate) return emptyList()
        val weekday = StudyWeekday.fromDayOfWeek(date.dayOfWeek)
        if (!StudyWeekday.timetableDays.contains(weekday)) return emptyList()
        val periodMap = periods.associateBy { it.id }

        return entries
            .filter { entry ->
                entry.dayOfWeek == weekday &&
                (entry.termId == term.id || entry.termId == null) &&
                (entry.validFromDate?.let { epochDay >= it } ?: true) &&
                (entry.validToDate?.let { epochDay <= it } ?: true)
            }
            .mapNotNull { entry ->
                val period = periodMap[entry.periodId] ?: return@mapNotNull null
                val record = records.find {
                    it.termId == term.id &&
                    it.entryId == entry.id &&
                    it.periodId == period.id &&
                    it.occurrenceDate == epochDay &&
                    it.deletedAt == null
                }
                TimetableReviewOccurrence(
                    term = term,
                    entry = entry,
                    period = period,
                    occurrenceDate = epochDay,
                    record = record
                )
            }
            .sortedBy { it.period.startMinute }
    }

    private fun buildTermSummary(
        term: TimetableTerm,
        entries: List<TimetableEntry>,
        periods: List<TimetablePeriod>,
        records: List<TimetableReviewRecord>
    ): TimetableReviewSummary {
        val today = LocalDate.now()
        val endDate = minOf(LocalDate.ofEpochDay(term.endDate), today)
        val startDate = LocalDate.ofEpochDay(term.startDate)
        if (startDate > endDate) return TimetableReviewSummary.empty

        var reviewed = 0
        var pending = 0
        var excluded = 0
        var date = startDate

        while (!date.isAfter(endDate)) {
            val weekday = StudyWeekday.fromDayOfWeek(date.dayOfWeek)
            if (StudyWeekday.timetableDays.contains(weekday)) {
                val epochDay = date.toEpochDay()
                val dayEntries = entries.filter { entry ->
                    entry.dayOfWeek == weekday &&
                    (entry.termId == term.id || entry.termId == null) &&
                    (entry.validFromDate?.let { epochDay >= it } ?: true) &&
                    (entry.validToDate?.let { epochDay <= it } ?: true)
                }
                for (entry in dayEntries) {
                    val record = records.find {
                        it.termId == term.id &&
                        it.entryId == entry.id &&
                        it.periodId == entry.periodId &&
                        it.occurrenceDate == epochDay &&
                        it.deletedAt == null
                    }
                    when {
                        record?.isExcluded == true -> excluded++
                        record?.isReviewed == true -> reviewed++
                        else -> pending++
                    }
                }
            }
            date = date.plusDays(1)
        }
        return TimetableReviewSummary(reviewed = reviewed, pending = pending, excluded = excluded)
    }

    fun selectTerm(term: TimetableTerm) {
        _uiState.update { state ->
            val newDate = if (term.contains(state.selectedDate)) {
                state.selectedDate
            } else if (term.contains(LocalDate.now())) {
                LocalDate.now()
            } else {
                LocalDate.ofEpochDay(term.startDate)
            }
            state.copy(selectedTermId = term.id, selectedDate = newDate)
        }
        refreshDerivedData()
    }

    fun selectDate(date: LocalDate) {
        _uiState.update { it.copy(selectedDate = date) }
        refreshDerivedData()
    }

    fun saveEntry(entry: TimetableEntry) {
        viewModelScope.launch {
            timetableRepository.saveEntry(entry)
            loadData()
        }
    }

    fun deleteEntry(entry: TimetableEntry) {
        viewModelScope.launch {
            timetableRepository.deleteEntry(entry)
            loadData()
        }
    }

    fun saveTerm(term: TimetableTerm) {
        viewModelScope.launch {
            timetableRepository.saveTerm(term)
            loadData()
        }
    }

    fun savePeriods(periods: List<TimetablePeriod>) {
        viewModelScope.launch {
            periods.forEach { timetableRepository.savePeriod(it) }
            loadData()
        }
    }

    fun setReviewed(occurrence: TimetableReviewOccurrence, reviewed: Boolean, note: String?) {
        viewModelScope.launch {
            val now = clock.currentTimeMillis()
            val record = (occurrence.record ?: TimetableReviewRecord(
                id = 0,
                syncId = java.util.UUID.randomUUID().toString().lowercase(),
                termId = occurrence.term.id,
                termSyncId = occurrence.term.syncId,
                entryId = occurrence.entry.id,
                entrySyncId = occurrence.entry.syncId,
                periodId = occurrence.period.id,
                periodSyncId = occurrence.period.syncId,
                occurrenceDate = occurrence.occurrenceDate,
                dayOfWeek = occurrence.entry.dayOfWeek,
                periodName = occurrence.period.name,
                periodStartMinute = occurrence.period.startMinute,
                periodEndMinute = occurrence.period.endMinute,
                subjectName = occurrence.entry.subjectName,
                courseName = occurrence.entry.courseName,
                roomName = occurrence.entry.roomName,
                isReviewed = false,
                note = null,
                isExcluded = false,
                reviewedAt = null,
                createdAt = now,
                updatedAt = now,
                deletedAt = null,
                lastSyncedAt = null
            )).copy(
                isReviewed = reviewed,
                isExcluded = false,
                note = note?.takeIf { it.isNotBlank() },
                reviewedAt = if (reviewed) now else null,
                updatedAt = now
            )
            timetableRepository.saveReviewRecord(record)
            loadData()
        }
    }

    fun setExcluded(occurrence: TimetableReviewOccurrence, excluded: Boolean) {
        viewModelScope.launch {
            val now = clock.currentTimeMillis()
            val baseRecord = occurrence.record ?: TimetableReviewRecord(
                id = 0,
                syncId = java.util.UUID.randomUUID().toString().lowercase(),
                termId = occurrence.term.id,
                termSyncId = occurrence.term.syncId,
                entryId = occurrence.entry.id,
                entrySyncId = occurrence.entry.syncId,
                periodId = occurrence.period.id,
                periodSyncId = occurrence.period.syncId,
                occurrenceDate = occurrence.occurrenceDate,
                dayOfWeek = occurrence.entry.dayOfWeek,
                periodName = occurrence.period.name,
                periodStartMinute = occurrence.period.startMinute,
                periodEndMinute = occurrence.period.endMinute,
                subjectName = occurrence.entry.subjectName,
                courseName = occurrence.entry.courseName,
                roomName = occurrence.entry.roomName,
                isReviewed = false,
                note = null,
                isExcluded = false,
                reviewedAt = null,
                createdAt = now,
                updatedAt = now,
                deletedAt = null,
                lastSyncedAt = null
            )
            val updatedRecord = baseRecord.copy(
                isExcluded = excluded,
                isReviewed = if (excluded) false else baseRecord.isReviewed,
                reviewedAt = if (excluded) null else baseRecord.reviewedAt,
                updatedAt = now
            )
            timetableRepository.saveReviewRecord(updatedRecord)
            loadData()
        }
    }

    fun clearError() {
        _uiState.update { it.copy(error = null) }
    }

    private fun refreshDerivedData() {
        val state = _uiState.value
        val selectedTerm = state.terms.find { it.id == state.selectedTermId } ?: return
        val activeEntries = state.entries
        val entriesBySlot = buildEntriesBySlot(activeEntries, state.selectedDate)
        val occurrences = buildOccurrences(
            state.selectedDate, selectedTerm, activeEntries, state.periods, state.reviewRecords
        )
        val termSummary = buildTermSummary(selectedTerm, activeEntries, state.periods, state.reviewRecords)
        _uiState.update {
            it.copy(
                entriesBySlot = entriesBySlot,
                selectedDateOccurrences = occurrences,
                termSummary = termSummary
            )
        }
    }

    private suspend fun createDefaultPeriods() {
        TimetablePeriod.defaultPeriods.forEach { period ->
            timetableRepository.savePeriod(period)
        }
        loadData()
    }

    private suspend fun createDefaultTerm() {
        val now = LocalDate.now()
        val defaultTerm = TimetableTerm(
            id = 0,
            syncId = java.util.UUID.randomUUID().toString().lowercase(),
            name = "デフォルト",
            startDate = now.minusMonths(1).toEpochDay(),
            endDate = now.plusMonths(5).toEpochDay(),
            isActive = true,
            createdAt = clock.currentTimeMillis(),
            updatedAt = clock.currentTimeMillis(),
            deletedAt = null,
            lastSyncedAt = null
        )
        timetableRepository.saveTerm(defaultTerm)
        loadData()
    }

    private data class Quad<A, B, C, D>(val first: A, val second: B, val third: C, val fourth: D)
}
