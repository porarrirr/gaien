import Foundation

struct Subject: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var color: Int
    var icon: SubjectIcon?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?
}

struct Material: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var subjectId: Int64
    var subjectSyncId: String?
    var sortOrder: Int64 = Date().epochMilliseconds
    var totalPages: Int = 0
    var currentPage: Int = 0
    var totalProblems: Int = 0
    var problemChapters: [ProblemChapter] = []
    var problemRecords: [ProblemSessionRecord] = []
    var color: Int?
    var note: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    private enum CodingKeys: String, CodingKey {
        case id
        case syncId
        case name
        case subjectId
        case subjectSyncId
        case sortOrder
        case totalPages
        case currentPage
        case totalProblems
        case problemChapters
        case problemRecords
        case color
        case note
        case createdAt
        case updatedAt
        case deletedAt
        case lastSyncedAt
    }

    var progress: Double {
        guard totalPages > 0 else { return 0 }
        return min(max(Double(currentPage) / Double(totalPages), 0), 1)
    }

    var progressPercent: Int {
        Int(progress * 100)
    }

    var effectiveTotalProblems: Int {
        let chapterTotal = problemChapters.totalProblemCount
        return chapterTotal > 0 ? chapterTotal : totalProblems
    }

    func problemLabel(for number: Int) -> String {
        problemChapters.label(for: number)
    }

    init(
        id: Int64 = 0,
        syncId: String = UUID().uuidString.lowercased(),
        name: String,
        subjectId: Int64,
        subjectSyncId: String? = nil,
        sortOrder: Int64 = Date().epochMilliseconds,
        totalPages: Int = 0,
        currentPage: Int = 0,
        totalProblems: Int = 0,
        problemChapters: [ProblemChapter] = [],
        problemRecords: [ProblemSessionRecord] = [],
        color: Int? = nil,
        note: String? = nil,
        createdAt: Int64 = Date().epochMilliseconds,
        updatedAt: Int64 = Date().epochMilliseconds,
        deletedAt: Int64? = nil,
        lastSyncedAt: Int64? = nil
    ) {
        self.id = id
        self.syncId = syncId
        self.name = name
        self.subjectId = subjectId
        self.subjectSyncId = subjectSyncId
        self.sortOrder = sortOrder
        self.totalPages = totalPages
        self.currentPage = currentPage
        self.totalProblems = totalProblems
        self.problemChapters = problemChapters
        self.problemRecords = problemRecords
        self.color = color
        self.note = note
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
        self.lastSyncedAt = lastSyncedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedCreatedAt = try container.decodeIfPresent(Int64.self, forKey: .createdAt) ?? Date().epochMilliseconds
        id = try container.decodeIfPresent(Int64.self, forKey: .id) ?? 0
        syncId = try container.decodeIfPresent(String.self, forKey: .syncId) ?? UUID().uuidString.lowercased()
        name = try container.decode(String.self, forKey: .name)
        subjectId = try container.decode(Int64.self, forKey: .subjectId)
        subjectSyncId = try container.decodeIfPresent(String.self, forKey: .subjectSyncId)
        sortOrder = try container.decodeIfPresent(Int64.self, forKey: .sortOrder) ?? decodedCreatedAt
        totalPages = try container.decodeIfPresent(Int.self, forKey: .totalPages) ?? 0
        currentPage = try container.decodeIfPresent(Int.self, forKey: .currentPage) ?? 0
        totalProblems = try container.decodeIfPresent(Int.self, forKey: .totalProblems) ?? 0
        problemChapters = try container.decodeIfPresent([ProblemChapter].self, forKey: .problemChapters) ?? []
        problemRecords = try container.decodeIfPresent([ProblemSessionRecord].self, forKey: .problemRecords) ?? []
        color = try container.decodeIfPresent(Int.self, forKey: .color)
        note = try container.decodeIfPresent(String.self, forKey: .note)
        createdAt = decodedCreatedAt
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? decodedCreatedAt
        deletedAt = try container.decodeIfPresent(Int64.self, forKey: .deletedAt)
        lastSyncedAt = try container.decodeIfPresent(Int64.self, forKey: .lastSyncedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(syncId, forKey: .syncId)
        try container.encode(name, forKey: .name)
        try container.encode(subjectId, forKey: .subjectId)
        try container.encodeIfPresent(subjectSyncId, forKey: .subjectSyncId)
        try container.encode(sortOrder, forKey: .sortOrder)
        try container.encode(totalPages, forKey: .totalPages)
        try container.encode(currentPage, forKey: .currentPage)
        try container.encode(totalProblems, forKey: .totalProblems)
        try container.encode(problemChapters, forKey: .problemChapters)
        try container.encode(problemRecords, forKey: .problemRecords)
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
    }
}

struct ProblemChapter: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString.lowercased()
    var title: String
    var problemCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case problemCount
    }

    init(id: String = UUID().uuidString.lowercased(), title: String, problemCount: Int) {
        self.id = id
        self.title = title
        self.problemCount = problemCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "章"
        problemCount = try container.decodeIfPresent(Int.self, forKey: .problemCount) ?? 0
    }
}

struct ProblemNumberLocation: Hashable {
    var globalNumber: Int
    var chapterIndex: Int
    var chapterTitle: String
    var localNumber: Int

    var displayText: String {
        "\(chapterTitle) \(localNumber)問"
    }
}

extension Array where Element == ProblemChapter {
    var totalProblemCount: Int {
        reduce(0) { $0 + max($1.problemCount, 0) }
    }

    func location(for globalNumber: Int) -> ProblemNumberLocation? {
        guard globalNumber > 0 else { return nil }
        var offset = 0
        for (index, chapter) in enumerated() {
            let count = max(chapter.problemCount, 0)
            guard count > 0 else { continue }
            let range = (offset + 1)...(offset + count)
            if range.contains(globalNumber) {
                return ProblemNumberLocation(
                    globalNumber: globalNumber,
                    chapterIndex: index,
                    chapterTitle: chapter.title,
                    localNumber: globalNumber - offset
                )
            }
            offset += count
        }
        return nil
    }

    func label(for globalNumber: Int) -> String {
        location(for: globalNumber)?.displayText ?? "\(globalNumber)問"
    }
}

enum StudySessionType: String, Codable, CaseIterable, Hashable {
    case stopwatch = "STOPWATCH"
    case timer = "TIMER"
    case manual = "MANUAL"

    var title: String {
        switch self {
        case .stopwatch: return "ストップウォッチ"
        case .timer: return "タイマー"
        case .manual: return "手動"
        }
    }
}

enum ProblemResult: String, Codable, CaseIterable, Hashable {
    case correct
    case wrong
    case reviewCorrect

    var title: String {
        switch self {
        case .correct: return "正解"
        case .wrong: return "不正解"
        case .reviewCorrect: return "復習正解"
        }
    }
}

struct ProblemSessionRecord: Identifiable, Codable, Hashable {
    var number: Int
    var result: ProblemResult
    var detail: String?

    var id: Int { number }

    var isWrong: Bool {
        get { result == .wrong }
        set { result = newValue ? .wrong : .correct }
    }

    init(number: Int, result: ProblemResult, detail: String? = nil) {
        self.number = number
        self.result = result
        self.detail = detail
    }

    init(number: Int, isWrong: Bool, detail: String? = nil) {
        self.init(number: number, result: isWrong ? .wrong : .correct, detail: detail)
    }

    private enum CodingKeys: String, CodingKey {
        case number
        case result
        case isWrong
        case detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .number)
        result = try container.decodeIfPresent(ProblemResult.self, forKey: .result)
            ?? ((try container.decodeIfPresent(Bool.self, forKey: .isWrong) ?? false) ? .wrong : .correct)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(result, forKey: .result)
        try container.encode(isWrong, forKey: .isWrong)
        try container.encodeIfPresent(detail, forKey: .detail)
    }
}

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
            let numbers = problemRecords.map(\.number).sorted()
            guard let first = numbers.first, let last = numbers.last else { return nil }
            return first == last ? "\(first)問" : "\(first)-\(last)問"
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

struct Goal: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var type: GoalType
    var targetMinutes: Int
    var dayOfWeek: StudyWeekday?
    var weekStartDay: StudyWeekday = .monday
    var isActive: Bool = true
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var targetFormatted: String {
        Goal.format(minutes: targetMinutes)
    }

    static func format(minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 {
            return "\(hours)時間\(remainder)分"
        }
        if hours > 0 {
            return "\(hours)時間"
        }
        return "\(remainder)分"
    }
}

struct Exam: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var date: Int64
    var note: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var dateValue: Date {
        Date(epochDay: date)
    }

    func daysRemaining(from referenceDate: Date = Date()) -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.startOfDay(for: dateValue)
        return calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    func isPast(from referenceDate: Date = Date()) -> Bool {
        daysRemaining(from: referenceDate) < 0
    }
}

struct StudyPlan: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var name: String
    var startDate: Int64
    var endDate: Int64
    var isActive: Bool
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?

    var startDateValue: Date {
        Date(epochMilliseconds: startDate)
    }

    var endDateValue: Date {
        Date(epochMilliseconds: endDate)
    }
}

struct PlanItem: Identifiable, Codable, Hashable {
    var id: Int64 = 0
    var syncId: String = UUID().uuidString.lowercased()
    var planId: Int64
    var planSyncId: String?
    var subjectId: Int64
    var subjectSyncId: String?
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int = 0
    var timeSlot: String?
    var createdAt: Int64 = Date().epochMilliseconds
    var updatedAt: Int64 = Date().epochMilliseconds
    var deletedAt: Int64?
    var lastSyncedAt: Int64?
}
