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

object ProblemSessionReviewResolver {
    fun canonicalInputSession(session: StudySession): StudySession {
        return session.withProblemRecords(canonicalInputRecords(session.problemRecords))
    }

    fun applyingAutomaticReviewCorrect(
        session: StudySession,
        previousResults: MutableMap<String, ProblemResult>
    ): StudySession {
        val resolved = canonicalInputRecords(session.problemRecords).map { record ->
            val inputResult = userInputResult(record.result)
            val resolvedResult = if (
                inputResult == ProblemResult.CORRECT &&
                previousResults[record.stableKey] == ProblemResult.WRONG
            ) {
                ProblemResult.REVIEW_CORRECT
            } else {
                inputResult
            }
            previousResults[record.stableKey] = inputResult
            record.copy(result = resolvedResult)
        }
        return session.withProblemRecords(resolved)
    }

    fun canonicalInputRecords(records: List<ProblemSessionRecord>): List<ProblemSessionRecord> {
        return records
            .map { record ->
                ProblemSessionRecord(
                    number = record.number,
                    result = userInputResult(record.result),
                    detail = record.detail?.trim()?.takeIf { it.isNotEmpty() },
                    subNumber = record.normalizedSubNumber
                )
            }
            .associateBy { it.stableKey }
            .values
            .sortedWith(compareBy<ProblemSessionRecord> { it.number }.thenBy { it.normalizedSubNumber ?: "" })
    }

    private fun userInputResult(result: ProblemResult): ProblemResult {
        return if (result == ProblemResult.WRONG) ProblemResult.WRONG else ProblemResult.CORRECT
    }

    private fun StudySession.withProblemRecords(records: List<ProblemSessionRecord>): StudySession {
        if (records.isEmpty()) {
            return copy(problemRecords = emptyList())
        }
        return copy(
            problemRecords = records,
            problemStart = records.minOf { it.number },
            problemEnd = records.maxOf { it.number },
            wrongProblemCount = records.count { it.result == ProblemResult.WRONG }
        )
    }
}
