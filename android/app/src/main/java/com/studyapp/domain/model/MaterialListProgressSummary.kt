package com.studyapp.domain.model

import java.util.Calendar

data class MaterialListProgressSummary(
    val totalProblems: Int = 0,
    val correctCount: Int = 0,
    val wrongCount: Int = 0,
    val reviewCorrectCount: Int = 0,
    val untouchedCount: Int = 0,
    val latestStudyDate: Long? = null
) {
    val progressedCount: Int get() = correctCount + wrongCount + reviewCorrectCount

    val progressedRatio: Double
        get() = if (totalProblems > 0) {
            minOf(maxOf(progressedCount.toDouble() / totalProblems.toDouble(), 0.0), 1.0)
        } else {
            0.0
        }

    val progressedPercent: Int get() = (progressedRatio * 100).toInt()

    val answerAccuracyPercent: Int
        get() = if (totalProblems > 0) {
            ((correctCount + reviewCorrectCount).toDouble() / totalProblems.toDouble() * 100).toInt()
        } else {
            0
        }

    val correctPercent: Int get() = percentFor(correctCount)
    val wrongPercent: Int get() = percentFor(wrongCount)
    val reviewCorrectPercent: Int get() = percentFor(reviewCorrectCount)
    val untouchedPercent: Int get() = percentFor(untouchedCount)

    private fun percentFor(count: Int): Int {
        if (totalProblems <= 0) return 0
        return ((count.toDouble() / totalProblems.toDouble()) * 100).toInt()
    }

    companion object {
        fun from(material: Material, sessions: List<StudySession>): MaterialListProgressSummary {
            val total = maxOf(material.effectiveTotalProblems, 0)
            if (total <= 0) return MaterialListProgressSummary()

            val resultsByNumber = sessions
                .sortedBy { it.startTime }
                .flatMap { session ->
                    session.problemRecords
                        .filter { it.number in 1..total }
                        .map { it.number to it.result }
                }
                .groupBy({ it.first }, { it.second })

            var correct = 0
            var wrong = 0
            var reviewCorrect = 0
            for (number in 1..total) {
                when (resultsByNumber[number]?.lastOrNull()) {
                    ProblemResult.CORRECT -> correct += 1
                    ProblemResult.WRONG -> wrong += 1
                    ProblemResult.REVIEW_CORRECT -> reviewCorrect += 1
                    else -> Unit
                }
            }

            return MaterialListProgressSummary(
                totalProblems = total,
                correctCount = correct,
                wrongCount = wrong,
                reviewCorrectCount = reviewCorrect,
                untouchedCount = maxOf(total - correct - wrong - reviewCorrect, 0),
                latestStudyDate = sessions.maxOfOrNull { it.startTime }?.let { startTime ->
                    Calendar.getInstance().apply {
                        timeInMillis = startTime
                        set(Calendar.HOUR_OF_DAY, 0)
                        set(Calendar.MINUTE, 0)
                        set(Calendar.SECOND, 0)
                        set(Calendar.MILLISECOND, 0)
                    }.timeInMillis
                }
            )
        }
    }
}
