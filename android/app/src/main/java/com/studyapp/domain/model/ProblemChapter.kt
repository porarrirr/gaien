package com.studyapp.domain.model

import java.util.UUID

data class ProblemChapter(
    val id: String = UUID.randomUUID().toString().lowercase(),
    val title: String = "章",
    val problemCount: Int = 0
)

data class ProblemNumberLocation(
    val globalNumber: Int,
    val chapterIndex: Int,
    val chapterTitle: String,
    val localNumber: Int
) {
    val displayText: String
        get() = "$chapterTitle ${localNumber}問"
}

fun List<ProblemChapter>.totalProblemCount(): Int =
    fold(0) { acc, chapter -> acc + maxOf(chapter.problemCount, 0) }

fun List<ProblemChapter>.locationFor(globalNumber: Int): ProblemNumberLocation? {
    if (globalNumber <= 0) return null
    var offset = 0
    for ((index, chapter) in this.withIndex()) {
        val count = maxOf(chapter.problemCount, 0)
        if (count <= 0) continue
        val rangeStart = offset + 1
        val rangeEnd = offset + count
        if (globalNumber in rangeStart..rangeEnd) {
            return ProblemNumberLocation(
                globalNumber = globalNumber,
                chapterIndex = index,
                chapterTitle = chapter.title,
                localNumber = globalNumber - offset
            )
        }
        offset += count
    }
    return null
}

fun List<ProblemChapter>.labelFor(globalNumber: Int): String =
    locationFor(globalNumber)?.displayText ?: "${globalNumber}問"
