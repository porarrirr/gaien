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
    val detail: String? = null
) {
    val id: Int get() = number

    var isWrong: Boolean
        get() = result == ProblemResult.WRONG
        set(value) {
            // This is a computed property pattern - actual setting done via copy()
        }

    fun withIsWrong(value: Boolean): ProblemSessionRecord =
        copy(result = if (value) ProblemResult.WRONG else ProblemResult.CORRECT)
}
