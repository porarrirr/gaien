package com.studyapp.domain.model

import kotlinx.serialization.Serializable

@Serializable
enum class ProblemResult {
    CORRECT,
    WRONG,
    REVIEW_CORRECT;

    val title: String
        get() = when (this) {
            CORRECT -> "正解"
            WRONG -> "不正解"
            REVIEW_CORRECT -> "復習正解"
        }
}

@Serializable
data class ProblemSessionRecord(
    val number: Int,
    val result: ProblemResult = ProblemResult.CORRECT,
    val detail: String? = null,
    val subNumber: String? = null
) {
    val normalizedSubNumber: String? get() = subNumber?.trim()?.takeIf { it.isNotEmpty() }
    val stableKey: String get() = normalizedSubNumber?.let { "$number:$it" } ?: number.toString()
    val id: String get() = stableKey
    val displayNumber: String get() = normalizedSubNumber?.let { "${number}問($it)" } ?: "${number}問"

    var isWrong: Boolean
        get() = result == ProblemResult.WRONG
        set(value) {
            // This is a computed property pattern - actual setting done via copy()
        }

    fun withIsWrong(value: Boolean): ProblemSessionRecord =
        copy(result = if (value) ProblemResult.WRONG else ProblemResult.CORRECT)
}
