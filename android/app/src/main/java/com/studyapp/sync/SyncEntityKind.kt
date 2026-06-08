package com.studyapp.sync

enum class SyncEntityKind(val rawValue: String) {
    SUBJECT("subject"),
    MATERIAL("material"),
    SESSION("session"),
    GOAL("goal"),
    EXAM("exam"),
    PLAN("plan"),
    PLAN_ITEM("planItem"),
    TIMETABLE_PERIOD("timetablePeriod"),
    TIMETABLE_ENTRY("timetableEntry"),
    TIMETABLE_TERM("timetableTerm"),
    TIMETABLE_REVIEW_RECORD("timetableReviewRecord"),
    PROBLEM_REVIEW_RECORD("problemReviewRecord");

    companion object {
        fun fromRawValue(raw: String): SyncEntityKind? = entries.firstOrNull { it.rawValue == raw }
    }
}

data class SyncEntityEnvelope(
    val kind: SyncEntityKind,
    val syncId: String,
    val updatedAt: Long,
    val deletedAt: Long?,
    val json: String,
    val revisionId: String? = null,
    val parentRevisionId: String? = null,
    val deviceId: String? = null,
    val contentHash: String? = null
) {
    val documentId: String get() = "${kind.rawValue}-$syncId"
}
