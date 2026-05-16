import Foundation

struct StudySession: Identifiable, Codable, Hashable {
    static let allowedRatings = 1...5

    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var materialId: Int64?
    var materialSyncId: String?
    var materialName: String = ""
    var subjectId: Int64
    var subjectSyncId: String?
    var subjectName: String = ""
    var sessionType: StudySessionType = .stopwatch
    var startTime: Int64
    var endTime: Int64
    var intervals: [StudySessionInterval] = []
    var rating: Int?
    var note: String?
    var problemStart: Int?
    var problemEnd: Int?
    var wrongProblemCount: Int?
    var problemRecords: [ProblemSessionRecord] = []
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    private enum CodingKeys: String, CodingKey {
        case id
        case syncId
        case materialId
        case materialSyncId
        case materialName
        case subjectId
        case subjectSyncId
        case subjectName
        case sessionType
        case startTime
        case endTime
        case intervals
        case rating
        case note
        case problemStart
        case problemEnd
        case wrongProblemCount
        case problemRecords
        case createdAt
        case updatedAt
        case deletedAt
        case lastSyncedAt
    }

    var effectiveIntervals: [StudySessionInterval] {
        if intervals.isEmpty {
            return [StudySessionInterval(startTime: startTime, endTime: endTime)]
        }
        return intervals.sorted { $0.startTime < $1.startTime }
    }

    var duration: Int64 {
        if intervals.isEmpty {
            return max(endTime - startTime, 0)
        }
        return effectiveIntervals.reduce(0) { $0 + $1.duration }
    }

    var sessionStartTime: Int64 {
        effectiveIntervals.first?.startTime ?? startTime
    }

    var sessionEndTime: Int64 {
        effectiveIntervals.last?.endTime ?? endTime
    }

    var date: Int64 {
        Date(epochMilliseconds: sessionStartTime).epochDay
    }

    var durationMinutes: Int {
        Int(duration / 60_000)
    }

    var durationHours: Double {
        Double(duration) / 3_600_000
    }

    var durationFormatted: String {
        let totalSeconds = Int(duration / 1_000)
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var durationJapaneseText: String {
        Goal.format(minutes: durationMinutes)
    }

    var hasRating: Bool {
        rating != nil
    }

    var problemRangeText: String? {
        if !problemRecords.isEmpty {
            let numbers = Array(Set(problemRecords.map(\.number))).sorted()
            guard let first = numbers.first, let last = numbers.last else { return nil }
            let range = first == last ? "\(first)問" : "\(first)-\(last)問"
            let subQuestionCount = problemRecords.filter { $0.normalizedSubNumber != nil }.count
            return subQuestionCount > 0 ? "\(range)（小問\(subQuestionCount)件）" : range
        }
        guard let problemStart, let problemEnd else { return nil }
        if problemStart == problemEnd {
            return "\(problemStart)問"
        }
        return "\(problemStart)-\(problemEnd)問"
    }

    var effectiveWrongProblemCount: Int? {
        if !problemRecords.isEmpty {
            return problemRecords.filter(\.isWrong).count
        }
        return wrongProblemCount
    }

    var effectiveReviewCorrectProblemCount: Int {
        problemRecords.filter { $0.result == .reviewCorrect }.count
    }

    var startDate: Date {
        Date(epochMilliseconds: sessionStartTime)
    }

    var endDate: Date {
        Date(epochMilliseconds: sessionEndTime)
    }

    var dayOfWeek: StudyWeekday {
        StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: startDate))
    }

    init(
        id: Int64 = 0,
        syncId: String = UUID().uuidString.lowercased(),
        materialId: Int64?,
        materialSyncId: String? = nil,
        materialName: String = "",
        subjectId: Int64,
        subjectSyncId: String? = nil,
        subjectName: String = "",
        sessionType: StudySessionType = .stopwatch,
        startTime: Int64,
        endTime: Int64,
        intervals: [StudySessionInterval] = [],
        rating: Int? = nil,
        note: String? = nil,
        problemStart: Int? = nil,
        problemEnd: Int? = nil,
        wrongProblemCount: Int? = nil,
        problemRecords: [ProblemSessionRecord] = [],
        createdAt: Int64 = Date().epochMilliseconds,
        updatedAt: Int64 = Date().epochMilliseconds,
        deletedAt: Int64? = nil,
        lastSyncedAt: Int64? = nil
    ) {
        self.id = id
        self.syncId = syncId
        self.materialId = materialId
        self.materialSyncId = materialSyncId
        self.materialName = materialName
        self.subjectId = subjectId
        self.subjectSyncId = subjectSyncId
        self.subjectName = subjectName
        self.sessionType = sessionType
        self.startTime = startTime
        self.endTime = endTime
        self.intervals = intervals
        self.rating = rating
        self.note = note
        self.problemStart = problemStart
        self.problemEnd = problemEnd
        self.wrongProblemCount = wrongProblemCount
        self.problemRecords = problemRecords
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.lastSyncedAt = lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        syncId = try container.decodeIfPresent(String.self, forKey: .syncId) ?? UUID().uuidString.lowercased()
        materialId = try container.decodeIfPresent(Int64.self, forKey: .materialId)
        materialSyncId = try container.decodeIfPresent(String.self, forKey: .materialSyncId)
        materialName = try container.decodeIfPresent(String.self, forKey: .materialName) ?? ""
        subjectId = try container.decode(Int64.self, forKey: .subjectId)
        subjectSyncId = try container.decodeIfPresent(String.self, forKey: .subjectSyncId)
        subjectName = try container.decodeIfPresent(String.self, forKey: .subjectName) ?? ""
        sessionType = try container.decodeIfPresent(StudySessionType.self, forKey: .sessionType) ?? .stopwatch
        startTime = try container.decode(Int64.self, forKey: .startTime)
        endTime = try container.decode(Int64.self, forKey: .endTime)
        intervals = try container.decodeIfPresent([StudySessionInterval].self, forKey: .intervals) ?? []
        if let decodedRating = try container.decodeIfPresent(Int.self, forKey: .rating) {
            guard Self.allowedRatings.contains(decodedRating) else {
                throw DecodingError.dataCorruptedError(forKey: .rating, in: container, debugDescription: "rating must be 1...5")
            }
            rating = decodedRating
        } else {
            rating = nil
        }
        note = try container.decodeIfPresent(String.self, forKey: .note)
        problemStart = try container.decodeIfPresent(Int.self, forKey: .problemStart)
        problemEnd = try container.decodeIfPresent(Int.self, forKey: .problemEnd)
        wrongProblemCount = try container.decodeIfPresent(Int.self, forKey: .wrongProblemCount)
        problemRecords = try container.decodeIfPresent([ProblemSessionRecord].self, forKey: .problemRecords) ?? []
        createdAt = try container.decodeIfPresent(Int64.self, forKey: .createdAt) ?? Date().epochMilliseconds
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? createdAt
        deletedAt = try container.decodeIfPresent(Int64.self, forKey: .deletedAt)
        lastSyncedAt = try container.decodeIfPresent(Int64.self, forKey: .lastSyncedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(syncId, forKey: .syncId)
        try container.encodeIfPresent(materialId, forKey: .materialId)
        try container.encodeIfPresent(materialSyncId, forKey: .materialSyncId)
        try container.encode(materialName, forKey: .materialName)
        try container.encode(subjectId, forKey: .subjectId)
        try container.encodeIfPresent(subjectSyncId, forKey: .subjectSyncId)
        try container.encode(subjectName, forKey: .subjectName)
        try container.encode(sessionType, forKey: .sessionType)
        try container.encode(startTime, forKey: .startTime)
        try container.encode(endTime, forKey: .endTime)
        try container.encode(intervals, forKey: .intervals)
        if let rating {
            guard Self.allowedRatings.contains(rating) else {
                throw EncodingError.invalidValue(
                    rating,
                    EncodingError.Context(codingPath: container.codingPath + [CodingKeys.rating], debugDescription: "rating must be 1...5")
                )
            }
        }
        try container.encodeIfPresent(rating, forKey: .rating)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encodeIfPresent(problemStart, forKey: .problemStart)
        try container.encodeIfPresent(problemEnd, forKey: .problemEnd)
        try container.encodeIfPresent(wrongProblemCount, forKey: .wrongProblemCount)
        try container.encode(problemRecords, forKey: .problemRecords)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
    }
}

struct PendingSessionEvaluation: Identifiable, Hashable {
    let id = UUID()
    var session: StudySession
}
