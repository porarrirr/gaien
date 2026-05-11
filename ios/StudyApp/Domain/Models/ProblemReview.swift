import Foundation

enum ProblemReviewRating: String, Codable, CaseIterable, Hashable {
    case again
    case good

    var title: String {
        switch self {
        case .again: return "もう一度"
        case .good: return "できた"
        }
    }
}

struct ProblemReviewRecord: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var problemId: String
    var materialId: Int64
    var materialSyncId: String?
    var problemNumber: Int
    var reviewedAt: Int64
    var rating: ProblemReviewRating
    var nextReviewDate: Int64
    var consecutiveCorrectCount: Int
    var wrongCount: Int
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    init(
        id: Int64 = 0,
        syncId: String = UUID().uuidString.lowercased(),
        problemId: String,
        materialId: Int64,
        materialSyncId: String? = nil,
        problemNumber: Int,
        reviewedAt: Int64,
        rating: ProblemReviewRating,
        nextReviewDate: Int64,
        consecutiveCorrectCount: Int,
        wrongCount: Int,
        createdAt: Int64 = Date().epochMilliseconds,
        updatedAt: Int64 = Date().epochMilliseconds,
        deletedAt: Int64? = nil,
        lastSyncedAt: Int64? = nil
    ) {
        self.id = id
        self.syncId = syncId
        self.problemId = problemId
        self.materialId = materialId
        self.materialSyncId = materialSyncId
        self.problemNumber = problemNumber
        self.reviewedAt = reviewedAt
        self.rating = rating
        self.nextReviewDate = nextReviewDate
        self.consecutiveCorrectCount = consecutiveCorrectCount
        self.wrongCount = wrongCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.lastSyncedAt = lastSyncedAt
    }

    static func problemId(materialId: Int64, problemNumber: Int) -> String {
        "\(materialId)-\(problemNumber)"
    }
}

struct TodayReviewProblem: Identifiable, Hashable {
    var materialId: Int64
    var materialName: String
    var subjectName: String
    var problemNumber: Int
    var nextReviewDate: Int64
    var consecutiveCorrectCount: Int
    var wrongCount: Int

    var id: String {
        ProblemReviewRecord.problemId(materialId: materialId, problemNumber: problemNumber)
    }
}
