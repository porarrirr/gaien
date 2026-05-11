import Foundation

struct ProblemReviewScheduler {
    static func schedule(
        materialId: Int64,
        materialSyncId: String?,
        problemNumber: Int,
        rating: ProblemReviewRating,
        reviewedAt: Int64,
        previous: ProblemReviewRecord?
    ) -> ProblemReviewRecord {
        let previousCorrect = previous?.consecutiveCorrectCount ?? 0
        let previousWrong = previous?.wrongCount ?? 0
        let consecutiveCorrect: Int
        let wrongCount: Int
        let intervalDays: Int

        switch rating {
        case .again:
            consecutiveCorrect = 0
            wrongCount = previousWrong + 1
            intervalDays = 1
        case .good:
            consecutiveCorrect = previousCorrect + 1
            wrongCount = previousWrong
            switch consecutiveCorrect {
            case 1:
                intervalDays = 3
            case 2:
                intervalDays = 7
            default:
                intervalDays = 14
            }
        }

        let calendar = Calendar.current
        let reviewDate = Date(epochMilliseconds: reviewedAt)
        let nextReviewDay = calendar.date(
            byAdding: .day,
            value: intervalDays,
            to: calendar.startOfDay(for: reviewDate)
        ) ?? reviewDate

        return ProblemReviewRecord(
            problemId: ProblemReviewRecord.problemId(materialId: materialId, problemNumber: problemNumber),
            materialId: materialId,
            materialSyncId: materialSyncId,
            problemNumber: problemNumber,
            reviewedAt: reviewedAt,
            rating: rating,
            nextReviewDate: calendar.startOfDay(for: nextReviewDay).epochMilliseconds,
            consecutiveCorrectCount: consecutiveCorrect,
            wrongCount: wrongCount,
            createdAt: reviewedAt,
            updatedAt: reviewedAt
        )
    }
}
