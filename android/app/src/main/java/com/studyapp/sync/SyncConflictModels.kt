package com.studyapp.sync

enum class SyncConflictField {
    NAME,
    NOTE,
    CURRENT_PAGE,
    TOTAL_PAGES,
    TOTAL_PROBLEMS,
    PROBLEM_RECORDS,
    PROBLEM_CHAPTERS,
    DELETION,
    PROBLEM_REVIEW_STATE,
    OTHER
}

enum class SyncConflictResolutionStrategy {
    KEEP_LOCAL,
    KEEP_REMOTE,
    KEEP_MERGED
}

data class SyncConflict(
    val kind: SyncEntityKind,
    val syncId: String,
    val title: String,
    val summary: String,
    val conflictFields: List<SyncConflictField>,
    val baseJson: String?,
    val localJson: String,
    val remoteJson: String,
    val suggestedMergedJson: String,
    val detectedAt: Long
) {
    val documentId: String get() = "${kind.rawValue}-$syncId"
}

data class SyncConflictResolution(
    val kind: SyncEntityKind,
    val syncId: String,
    val strategy: SyncConflictResolutionStrategy
)
