import Foundation

enum SubjectIcon: String, CaseIterable, Codable, Identifiable, Hashable {
    case book = "BOOK"
    case calculator = "CALCULATOR"
    case flask = "FLASK"
    case globe = "GLOBE"
    case palette = "PALETTE"
    case music = "MUSIC"
    case code = "CODE"
    case atom = "ATOM"
    case dna = "DNA"
    case brain = "BRAIN"
    case language = "LANGUAGE"
    case history = "HISTORY"
    case other = "OTHER"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .book: return "book.closed.fill"
        case .calculator: return "function"
        case .flask: return "testtube.2"
        case .globe: return "globe.asia.australia.fill"
        case .palette: return "paintpalette.fill"
        case .music: return "music.note"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .atom: return "atom"
        case .dna: return "cross.case.fill"
        case .brain: return "brain.head.profile"
        case .language: return "character.book.closed.fill"
        case .history: return "clock.arrow.circlepath"
        case .other: return "square.grid.2x2.fill"
        }
    }
}

enum GoalType: String, CaseIterable, Codable, Identifiable, Hashable {
    case daily = "DAILY"
    case weekly = "WEEKLY"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "1日の目標"
        case .weekly: return "週間目標"
        }
    }
}

enum StudyWeekday: String, CaseIterable, Codable, Identifiable, Hashable {
    case monday = "MONDAY"
    case tuesday = "TUESDAY"
    case wednesday = "WEDNESDAY"
    case thursday = "THURSDAY"
    case friday = "FRIDAY"
    case saturday = "SATURDAY"
    case sunday = "SUNDAY"

    var id: String { rawValue }

    var japaneseShortTitle: String {
        switch self {
        case .monday: return "月"
        case .tuesday: return "火"
        case .wednesday: return "水"
        case .thursday: return "木"
        case .friday: return "金"
        case .saturday: return "土"
        case .sunday: return "日"
        }
    }

    var japaneseTitle: String {
        japaneseShortTitle + "曜日"
    }

    var calendarWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    static func from(calendarWeekday: Int) -> StudyWeekday {
        switch calendarWeekday {
        case 1: return .sunday
        case 2: return .monday
        case 3: return .tuesday
        case 4: return .wednesday
        case 5: return .thursday
        case 6: return .friday
        default: return .saturday
        }
    }
}

enum ThemeMode: String, CaseIterable, Codable, Identifiable, Hashable {
    case light
    case dark
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: return "ライト"
        case .dark: return "ダーク"
        case .system: return "システム"
        }
    }

}

enum ColorTheme: String, CaseIterable, Codable, Identifiable, Hashable {
    case green
    case blue
    case orange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .green: return "グリーン"
        case .blue: return "ブルー"
        case .orange: return "オレンジ"
        }
    }

    var hex: Int {
        switch self {
        case .green: return 0x4CAF50
        case .blue: return 0x2196F3
        case .orange: return 0xFF9800
        }
    }

    var accentHex: Int {
        switch self {
        case .green: return 0x2196F3
        case .blue: return 0x4CAF50
        case .orange: return 0x2196F3
        }
    }
}

enum ExportFormat: String, CaseIterable, Identifiable {
    case json
    case csv

    var id: String { rawValue }
}

enum LiveActivityDisplayPreset: String, CaseIterable, Codable, Identifiable, Hashable {
    case standard
    case focus
    case progress
    case subjectDetail

    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "標準"
        case .focus: return "集中"
        case .progress: return "進捗"
        case .subjectDetail: return "科目詳細"
        }
    }

    var settingsDescription: String {
        switch self {
        case .standard: return "経過時間を大きく表示し、科目と教材を並べます。"
        case .focus: return "経過時間を最優先で表示し、補助情報を最小にします。"
        case .progress: return "経過時間に加えて今日の記録時間と目標を表示します。"
        case .subjectDetail: return "科目名を主役にして教材と開始時刻を表示します。"
        }
    }
}

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

    init(
        id: Int64 = 0,
        syncId: String = UUID().uuidString.lowercased(),
        name: String,
        subjectId: Int64,
        subjectSyncId: String? = nil,
        sortOrder: Int64 = Date().epochMilliseconds,
        totalPages: Int = 0,
        currentPage: Int = 0,
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
        try container.encodeIfPresent(color, forKey: .color)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
        try container.encodeIfPresent(lastSyncedAt, forKey: .lastSyncedAt)
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

struct MaterialWithSubject: Hashable {
    var material: Material
    var subjectName: String
}

struct PlanItemWithSubject: Identifiable, Hashable {
    var id: Int64 { item.id }
    var item: PlanItem
    var subject: Subject
}

struct DailyPlanSummary: Hashable {
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int

    var completionRate: Double {
        guard targetMinutes > 0 else { return 0 }
        return min(Double(actualMinutes) / Double(targetMinutes), 1)
    }
}

struct WeeklyPlanSummary: Hashable {
    var weekStart: Int64
    var weekEnd: Int64
    var totalTargetMinutes: Int
    var totalActualMinutes: Int
    var dailyBreakdown: [StudyWeekday: DailyPlanSummary]
}

struct DailyStudyData: Identifiable, Hashable {
    var id: Int64 { date }
    var date: Int64
    var dateLabel: String
    var minutes: Int
    var hours: Double
    var segments: [SubjectStudySegment] = []
}

struct WeeklyStudyData: Identifiable, Hashable {
    var id: Int64 { weekStart }
    var weekStart: Int64
    var weekLabel: String
    var hours: Int
    var minutes: Int
    var segments: [SubjectStudySegment] = []
}

struct SubjectStudySegment: Identifiable, Hashable {
    var id: Int64 { subjectId }
    var subjectId: Int64
    var subjectName: String
    var minutes: Int
    var color: Int
}

struct MonthlyStudyData: Identifiable, Hashable {
    var id: Int64 { monthStart }
    var monthStart: Int64
    var monthLabel: String
    var totalHours: Int
}

struct SubjectStudyData: Identifiable, Hashable {
    var id: String { subjectName }
    var subjectName: String
    var hours: Int
    var minutes: Int
    var color: Int
}

struct RatingAverageSummary: Hashable {
    var average: Double?
    var ratedMinutes: Int
}

struct RatingAveragesData: Hashable {
    var today: RatingAverageSummary
    var week: RatingAverageSummary
    var month: RatingAverageSummary
}

struct BookInfo: Codable, Hashable, Sendable {
    var title: String
    var authors: [String]
    var publisher: String?
    var publishedDate: String?
    var pageCount: Int?
    var thumbnailURL: String?
}

struct TimerSnapshot: Codable, Equatable {
    enum Mode: String, Codable, Equatable {
        case stopwatch = "STOPWATCH"
        case timer = "TIMER"
    }

    var subjectId: Int64
    var materialId: Int64?
    var startedAt: Int64?
    var accumulatedMilliseconds: Int64
    var completedIntervals: [StudySessionInterval] = []
    var mode: Mode = .stopwatch
    var targetDurationMilliseconds: Int64?
    var isRunning: Bool

    private enum CodingKeys: String, CodingKey {
        case subjectId
        case materialId
        case startedAt
        case accumulatedMilliseconds
        case completedIntervals
        case mode
        case targetDurationMilliseconds
        case isRunning
    }

    func elapsedTime(at now: Date = Date()) -> Int64 {
        if isRunning, let startedAt {
            return accumulatedMilliseconds + max(now.epochMilliseconds - startedAt, 0)
        }
        return accumulatedMilliseconds
    }

    func finalizedIntervals(at now: Date = Date()) -> [StudySessionInterval] {
        if isRunning, let startedAt {
            return completedIntervals + [StudySessionInterval(startTime: startedAt, endTime: now.epochMilliseconds)]
        }
        return completedIntervals
    }

    func remainingTime(at now: Date = Date()) -> Int64 {
        guard mode == .timer else { return 0 }
        return max((targetDurationMilliseconds ?? 0) - elapsedTime(at: now), 0)
    }

    var sessionType: StudySessionType {
        switch mode {
        case .stopwatch: return .stopwatch
        case .timer: return .timer
        }
    }

    init(
        subjectId: Int64,
        materialId: Int64?,
        startedAt: Int64?,
        accumulatedMilliseconds: Int64,
        completedIntervals: [StudySessionInterval] = [],
        mode: Mode = .stopwatch,
        targetDurationMilliseconds: Int64? = nil,
        isRunning: Bool
    ) {
        self.subjectId = subjectId
        self.materialId = materialId
        self.startedAt = startedAt
        self.accumulatedMilliseconds = accumulatedMilliseconds
        self.completedIntervals = completedIntervals
        self.mode = mode
        self.targetDurationMilliseconds = targetDurationMilliseconds
        self.isRunning = isRunning
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subjectId = try container.decode(Int64.self, forKey: .subjectId)
        materialId = try container.decodeIfPresent(Int64.self, forKey: .materialId)
        startedAt = try container.decodeIfPresent(Int64.self, forKey: .startedAt)
        accumulatedMilliseconds = try container.decodeIfPresent(Int64.self, forKey: .accumulatedMilliseconds) ?? 0
        completedIntervals = try container.decodeIfPresent([StudySessionInterval].self, forKey: .completedIntervals) ?? []
        mode = try container.decodeIfPresent(Mode.self, forKey: .mode) ?? .stopwatch
        targetDurationMilliseconds = try container.decodeIfPresent(Int64.self, forKey: .targetDurationMilliseconds)
        isRunning = try container.decode(Bool.self, forKey: .isRunning)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(subjectId, forKey: .subjectId)
        try container.encodeIfPresent(materialId, forKey: .materialId)
        try container.encodeIfPresent(startedAt, forKey: .startedAt)
        try container.encode(accumulatedMilliseconds, forKey: .accumulatedMilliseconds)
        try container.encode(completedIntervals, forKey: .completedIntervals)
        try container.encode(mode, forKey: .mode)
        try container.encodeIfPresent(targetDurationMilliseconds, forKey: .targetDurationMilliseconds)
        try container.encode(isRunning, forKey: .isRunning)
    }
}

struct AppPreferences: Codable, Equatable {
    var onboardingCompleted = false
    var reminderEnabled = false
    var reminderHour = 19
    var reminderMinute = 0
    var selectedColorTheme: ColorTheme = .green
    var selectedThemeMode: ThemeMode = .system
    var liveActivityEnabled = true
    var liveActivityDisplayPreset: LiveActivityDisplayPreset = .standard
    var activeTimer: TimerSnapshot?

    private enum CodingKeys: String, CodingKey {
        case onboardingCompleted
        case reminderEnabled
        case reminderHour
        case reminderMinute
        case selectedColorTheme
        case selectedThemeMode
        case liveActivityEnabled
        case liveActivityDisplayPreset
        case activeTimer
    }

    init(
        onboardingCompleted: Bool = false,
        reminderEnabled: Bool = false,
        reminderHour: Int = 19,
        reminderMinute: Int = 0,
        selectedColorTheme: ColorTheme = .green,
        selectedThemeMode: ThemeMode = .system,
        liveActivityEnabled: Bool = true,
        liveActivityDisplayPreset: LiveActivityDisplayPreset = .standard,
        activeTimer: TimerSnapshot? = nil
    ) {
        self.onboardingCompleted = onboardingCompleted
        self.reminderEnabled = reminderEnabled
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
        self.selectedColorTheme = selectedColorTheme
        self.selectedThemeMode = selectedThemeMode
        self.liveActivityEnabled = liveActivityEnabled
        self.liveActivityDisplayPreset = liveActivityDisplayPreset
        self.activeTimer = activeTimer
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 19
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        selectedColorTheme = try container.decodeIfPresent(ColorTheme.self, forKey: .selectedColorTheme) ?? .green
        selectedThemeMode = try container.decodeIfPresent(ThemeMode.self, forKey: .selectedThemeMode) ?? .system
        liveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? true
        liveActivityDisplayPreset = try container.decodeIfPresent(LiveActivityDisplayPreset.self, forKey: .liveActivityDisplayPreset) ?? .standard
        activeTimer = try container.decodeIfPresent(TimerSnapshot.self, forKey: .activeTimer)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(onboardingCompleted, forKey: .onboardingCompleted)
        try container.encode(reminderEnabled, forKey: .reminderEnabled)
        try container.encode(reminderHour, forKey: .reminderHour)
        try container.encode(reminderMinute, forKey: .reminderMinute)
        try container.encode(selectedColorTheme, forKey: .selectedColorTheme)
        try container.encode(selectedThemeMode, forKey: .selectedThemeMode)
        try container.encode(liveActivityEnabled, forKey: .liveActivityEnabled)
        try container.encode(liveActivityDisplayPreset, forKey: .liveActivityDisplayPreset)
        try container.encodeIfPresent(activeTimer, forKey: .activeTimer)
    }
}

struct StudySessionInterval: Codable, Hashable {
    var startTime: Int64
    var endTime: Int64

    var duration: Int64 {
        max(endTime - startTime, 0)
    }
}

extension Sequence where Element == Goal {
    func latestActiveDailyGoal(for dayOfWeek: StudyWeekday) -> Goal? {
        filter { $0.type == .daily && $0.isActive && $0.deletedAt == nil && $0.dayOfWeek == dayOfWeek }
            .max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    func latestActiveWeeklyGoal() -> Goal? {
        filter { $0.type == .weekly && $0.isActive && $0.deletedAt == nil }
            .max { lhs, rhs in
                if lhs.updatedAt == rhs.updatedAt {
                    return lhs.createdAt < rhs.createdAt
                }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    func latestActiveDailyGoalsByWeekday() -> [StudyWeekday: Goal] {
        reduce(into: [StudyWeekday: Goal]()) { result, goal in
            guard goal.type == .daily, goal.isActive, goal.deletedAt == nil, let dayOfWeek = goal.dayOfWeek else {
                return
            }
            guard let current = result[dayOfWeek] else {
                result[dayOfWeek] = goal
                return
            }
            let isNewer = goal.updatedAt > current.updatedAt
                || (goal.updatedAt == current.updatedAt && goal.createdAt > current.createdAt)
            if isNewer {
                result[dayOfWeek] = goal
            }
        }
    }
}

struct AuthSession: Codable, Equatable {
    var localId: String
    var email: String
    var idToken: String
    var refreshToken: String
}

struct SyncStatus: Equatable {
    var isAuthenticated = false
    var email: String?
    var isSyncing = false
    var lastSyncAt: Int64?
    var errorMessage: String?
}

struct HomeData: Hashable {
    var todayStudyMinutes: Int
    var todaySessions: [TodaySession]
    var todayGoal: Goal?
    var weeklyGoal: Goal?
    var weeklyStudyMinutes: Int
    var upcomingExams: [Exam]
}

struct TodaySession: Identifiable, Hashable {
    var id: Int64
    var subjectName: String
    var materialName: String
    var duration: Int64
    var startTime: Int64
}

struct ReportsData: Hashable {
    var daily: [DailyStudyData]
    var weekly: [WeeklyStudyData]
    var monthly: [MonthlyStudyData]
    var bySubject: [SubjectStudyData]
    var ratingAverages: RatingAveragesData
    var streakDays: Int
    var bestStreak: Int
}

struct SettingsSummary: Hashable {
    var totalSessions: Int
    var totalStudyMinutes: Int
}

struct PlanData: Codable, Hashable {
    var plan: StudyPlan
    var items: [PlanItem]
}

struct AppData: Codable, Hashable {
    var subjects: [Subject]
    var materials: [Material]
    var sessions: [StudySession]
    var goals: [Goal]
    var exams: [Exam]
    var plans: [PlanData]
    var exportDate: Int64
}

protocol SubjectRepository {
    func getAllSubjects() async throws -> [Subject]
    func getSubjectById(_ id: Int64) async throws -> Subject?
    func insertSubject(_ subject: Subject) async throws -> Int64
    func updateSubject(_ subject: Subject) async throws
    func deleteSubject(_ subject: Subject) async throws
}

protocol MaterialRepository {
    func getAllMaterials() async throws -> [Material]
    func getMaterialsBySubjectId(_ subjectId: Int64) async throws -> [Material]
    func insertMaterial(_ material: Material) async throws -> Int64
    func updateMaterial(_ material: Material) async throws
    func deleteMaterial(_ material: Material) async throws
}

protocol StudySessionRepository {
    func getAllSessions() async throws -> [StudySession]
    func getSessionsBetweenDates(start: Int64, end: Int64) async throws -> [StudySession]
    func insertSession(_ session: StudySession) async throws -> Int64
    func updateSession(_ session: StudySession) async throws
    func deleteSession(_ session: StudySession) async throws
}

protocol GoalRepository {
    func getAllGoals() async throws -> [Goal]
    func getActiveGoalByType(_ type: GoalType) async throws -> Goal?
    func insertGoal(_ goal: Goal) async throws -> Int64
    func updateGoal(_ goal: Goal) async throws
    func deleteGoal(_ goal: Goal) async throws
}

protocol ExamRepository {
    func getAllExams() async throws -> [Exam]
    func getUpcomingExams(now: Date) async throws -> [Exam]
    func insertExam(_ exam: Exam) async throws -> Int64
    func updateExam(_ exam: Exam) async throws
    func deleteExam(_ exam: Exam) async throws
}

protocol PlanRepository {
    func getAllPlans() async throws -> [StudyPlan]
    func getPlanItems(planId: Int64) async throws -> [PlanItem]
    func createPlan(_ plan: StudyPlan, items: [PlanItem]) async throws -> Int64
    func insertPlanItem(_ item: PlanItem) async throws -> Int64
    func updatePlanItem(_ item: PlanItem) async throws
    func deletePlanItem(_ item: PlanItem) async throws
    func deletePlan(_ plan: StudyPlan) async throws
}

protocol AppPreferencesRepository {
    func loadPreferences() -> AppPreferences
    func savePreferences(_ preferences: AppPreferences)
}

protocol BookSearchRepository {
    func searchByIsbn(_ isbn: String) async throws -> BookInfo
}

protocol AppDataRepository {
    func exportData() async throws -> AppData
    func exportJSON() async throws -> String
    func exportCSV() async throws -> String
    func importJSON(_ json: String, currentPreferences: AppPreferences) async throws -> AppPreferences
    func deleteAllData() async throws
    func migrateLegacySnapshotIfNeeded(preferencesRepository: AppPreferencesRepository) async throws
}

@MainActor
protocol AuthRepository {
    var session: AuthSession? { get }
    func signIn(email: String, password: String) async throws
    func signUp(email: String, password: String) async throws
    func signOut() async throws
}

@MainActor
protocol SyncRepository {
    var status: SyncStatus { get }
    func syncNow() async throws
    func importLocalDataToCloud() async throws
    func clearLocalSyncState() async
}

struct Clock {
    func now() -> Date {
        Date()
    }

    func startOfToday(reference: Date = Date()) -> Int64 {
        Calendar.current.startOfDay(for: reference).epochMilliseconds
    }

    func startOfWeek(reference: Date = Date()) -> Int64 {
        let interval = Calendar.current.dateInterval(of: .weekOfYear, for: reference)
        return (interval?.start ?? Calendar.current.startOfDay(for: reference)).epochMilliseconds
    }
}

struct GetHomeDataUseCase {
    let studySessionRepository: StudySessionRepository
    let goalRepository: GoalRepository
    let examRepository: ExamRepository
    let clock: Clock

    func execute() async throws -> HomeData {
        let todayStart = clock.startOfToday()
        let weekStart = clock.startOfWeek()
        let todayWeekday = StudyWeekday.from(calendarWeekday: Calendar.current.component(.weekday, from: clock.now()))
        let dayMs: Int64 = 86_400_000
        let weekMs = dayMs * 7

        async let todaySessionsTask = studySessionRepository.getSessionsBetweenDates(start: todayStart, end: todayStart + dayMs)
        async let goalsTask = goalRepository.getAllGoals()
        async let weeklySessionsTask = studySessionRepository.getSessionsBetweenDates(start: weekStart, end: weekStart + weekMs)
        async let upcomingExamsTask = examRepository.getUpcomingExams(now: clock.now())

        let todaySessions = try await todaySessionsTask
        let goals = try await goalsTask
        let weeklySessions = try await weeklySessionsTask
        let upcomingExams = try await upcomingExamsTask
        let todayGoal = goals.latestActiveDailyGoal(for: todayWeekday)
        let weeklyGoal = goals.latestActiveWeeklyGoal()

        return HomeData(
            todayStudyMinutes: todaySessions.reduce(0) { $0 + $1.durationMinutes },
            todaySessions: todaySessions
                .sorted { $0.startTime > $1.startTime }
                .map {
                    TodaySession(
                        id: $0.id,
                        subjectName: $0.subjectName,
                        materialName: $0.materialName,
                        duration: $0.duration,
                        startTime: $0.startTime
                    )
                },
            todayGoal: todayGoal,
            weeklyGoal: weeklyGoal,
            weeklyStudyMinutes: weeklySessions.reduce(0) { $0 + $1.durationMinutes },
            upcomingExams: upcomingExams.sorted { $0.date < $1.date }
        )
    }
}

struct GetRecentMaterialsUseCase {
    let materialRepository: MaterialRepository
    let studySessionRepository: StudySessionRepository
    let subjectRepository: SubjectRepository

    func execute(limit: Int = 5) async throws -> [(Material, Subject)] {
        async let materialsTask = materialRepository.getAllMaterials()
        async let sessionsTask = studySessionRepository.getAllSessions()
        async let subjectsTask = subjectRepository.getAllSubjects()

        let materials = try await materialsTask
        let sessions = try await sessionsTask
        let subjects = try await subjectsTask

        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        let materialMap = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
        var orderedIds = [Int64]()
        for materialId in sortedSessions.compactMap(\.materialId) where !orderedIds.contains(materialId) {
            orderedIds.append(materialId)
            if orderedIds.count == limit {
                break
            }
        }
        return orderedIds.compactMap { materialId in
            guard let material = materialMap[materialId], let subject = subjectMap[material.subjectId] else { return nil }
            return (material, subject)
        }
    }
}

struct GetUpcomingExamsUseCase {
    let examRepository: ExamRepository
    let clock: Clock

    func execute(limit: Int? = nil) async throws -> [Exam] {
        let exams = try await examRepository.getUpcomingExams(now: clock.now())
        if let limit {
            return Array(exams.prefix(limit))
        }
        return exams
    }
}

struct ManageGoalsUseCase {
    let repository: GoalRepository

    func updateGoal(
        type: GoalType,
        targetMinutes: Int,
        dayOfWeek: StudyWeekday? = nil,
        weekStartDay: StudyWeekday = .monday
    ) async throws {
        let goals = try await repository.getAllGoals()
        switch type {
        case .daily:
            if let current = goals.first(where: {
                $0.type == .daily &&
                $0.isActive &&
                $0.deletedAt == nil &&
                $0.dayOfWeek == dayOfWeek
            }) {
                var updated = current
                updated.targetMinutes = targetMinutes
                updated.dayOfWeek = dayOfWeek
                updated.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(updated)
            } else {
                try await repository.insertGoal(
                    Goal(
                        type: .daily,
                        targetMinutes: targetMinutes,
                        dayOfWeek: dayOfWeek,
                        weekStartDay: weekStartDay,
                        isActive: true
                    )
                )
            }
        case .weekly:
            for goal in goals where goal.type == .weekly && goal.isActive && goal.deletedAt == nil {
                var inactive = goal
                inactive.isActive = false
                inactive.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(inactive)
            }

            if let current = goals.first(where: {
                $0.type == .weekly &&
                $0.isActive &&
                $0.deletedAt == nil
            }) {
                var updated = current
                updated.targetMinutes = targetMinutes
                updated.weekStartDay = weekStartDay
                updated.isActive = true
                updated.updatedAt = Date().epochMilliseconds
                try await repository.updateGoal(updated)
            } else {
                try await repository.insertGoal(
                    Goal(
                        type: .weekly,
                        targetMinutes: targetMinutes,
                        weekStartDay: weekStartDay,
                        isActive: true
                    )
                )
            }
        }
    }
}

struct SaveStudySessionUseCase {
    let sessionRepository: StudySessionRepository
    let subjectRepository: SubjectRepository
    let materialRepository: MaterialRepository

    func saveManualSession(subjectId: Int64, materialId: Int64?, startTime: Int64, endTime: Int64, note: String?) async throws {
        guard let subject = try await subjectRepository.getSubjectById(subjectId) else {
            throw ValidationError(message: "科目を選択してください")
        }
        let duration = endTime - startTime
        guard duration > 0 else {
            throw ValidationError(message: "終了時刻は開始時刻より後にしてください")
        }
        let materials = try await materialRepository.getAllMaterials()
        let material = materials.first(where: { $0.id == materialId })
        let materialName = material?.name ?? ""
        try await sessionRepository.insertSession(
            StudySession(
                materialId: materialId,
                materialSyncId: material?.syncId,
                materialName: materialName,
                subjectId: subject.id,
                subjectSyncId: subject.syncId,
                subjectName: subject.name,
                sessionType: .manual,
                startTime: startTime,
                endTime: endTime,
                intervals: [StudySessionInterval(startTime: startTime, endTime: endTime)],
                note: note?.nilIfBlank
            )
        )
    }
}

struct ManageMaterialsUseCase {
    let materialRepository: MaterialRepository
    let subjectRepository: SubjectRepository
    let bookSearchRepository: BookSearchRepository

    func searchBook(isbn: String) async throws -> BookInfo {
        try await bookSearchRepository.searchByIsbn(isbn)
    }

    func addMaterial(
        name: String,
        subjectId: Int64,
        totalPages: Int,
        color: Int? = nil,
        note: String? = nil
    ) async throws {
        guard let subject = try await subjectRepository.getSubjectById(subjectId) else {
            throw ValidationError(message: "科目を選択してください")
        }
        try await materialRepository.insertMaterial(
            Material(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                subjectId: subjectId,
                subjectSyncId: subject.syncId,
                totalPages: totalPages,
                currentPage: 0,
                color: color,
                note: note?.nilIfBlank
            )
        )
    }
}

struct ManagePlansUseCase {
    let repository: PlanRepository

    func createPlan(name: String, startDate: Date, endDate: Date, items: [PlanItem]) async throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ValidationError(message: "プラン名を入力してください")
        }
        guard startDate < endDate else {
            throw ValidationError(message: "開始日は終了日より前に設定してください")
        }
        guard !items.isEmpty else {
            throw ValidationError(message: "少なくとも1つの学習項目を追加してください")
        }
        try await repository.createPlan(
            StudyPlan(
                name: trimmed,
                startDate: Calendar.current.startOfDay(for: startDate).epochMilliseconds,
                endDate: Calendar.current.startOfDay(for: endDate).epochMilliseconds,
                isActive: true
            ),
            items: items
        )
    }
}

struct GetReportsDataUseCase {
    let subjectRepository: SubjectRepository
    let sessionRepository: StudySessionRepository
    let clock: Clock

    func execute(reference: Date = Date()) async throws -> ReportsData {
        async let subjectsTask = subjectRepository.getAllSubjects()
        async let sessionsTask = sessionRepository.getAllSessions()
        let subjects = try await subjectsTask
        let sessions = try await sessionsTask

        let sortedSessions = sessions.sorted { $0.startTime < $1.startTime }
        let daily = reportDailyData(subjects: subjects, sessions: sortedSessions, reference: reference)
        let weekly = reportWeeklyData(subjects: subjects, sessions: sortedSessions, reference: reference)
        let monthly = reportMonthlyData(sessions: sortedSessions, reference: reference)
        let bySubject = subjectBreakdown(subjects: subjects, sessions: sortedSessions, reference: reference)

        return ReportsData(
            daily: daily,
            weekly: weekly,
            monthly: monthly,
            bySubject: bySubject,
            ratingAverages: ratingAverages(sessions: sortedSessions, reference: reference),
            streakDays: streakDays(sessions: sortedSessions, reference: reference),
            bestStreak: bestStreak(sessions: sortedSessions)
        )
    }

    private func reportDailyData(subjects: [Subject], sessions: [StudySession], reference: Date) -> [DailyStudyData] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d (E)"
        return (0..<7).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .day, value: -offset, to: reference) else { return nil }
            let start = Calendar.current.startOfDay(for: date).epochMilliseconds
            let end = start + 86_400_000
            let periodSessions = sessions.filter { $0.startTime >= start && $0.startTime < end }
            let segments = subjectSegments(subjects: subjects, sessions: periodSessions)
            let minutes = segments.reduce(0) { $0 + $1.minutes }
            return DailyStudyData(
                date: start,
                dateLabel: formatter.string(from: date),
                minutes: minutes,
                hours: Double(minutes) / 60,
                segments: segments
            )
        }
        .reversed()
    }

    private func reportWeeklyData(subjects: [Subject], sessions: [StudySession], reference: Date) -> [WeeklyStudyData] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M/d"
        return (0..<4).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .weekOfYear, value: -offset, to: reference) else { return nil }
            let interval = Calendar.current.dateInterval(of: .weekOfYear, for: date)
            let start = (interval?.start ?? date).epochMilliseconds
            let end = Int64((interval?.end ?? date).epochMilliseconds)
            let periodSessions = sessions.filter { $0.startTime >= start && $0.startTime < end }
            let segments = subjectSegments(subjects: subjects, sessions: periodSessions)
            let minutes = segments.reduce(0) { $0 + $1.minutes }
            return WeeklyStudyData(
                weekStart: start,
                weekLabel: "\(formatter.string(from: Date(epochMilliseconds: start)))週",
                hours: minutes / 60,
                minutes: minutes % 60,
                segments: segments
            )
        }
        .reversed()
    }

    private func subjectSegments(subjects: [Subject], sessions: [StudySession]) -> [SubjectStudySegment] {
        subjects.compactMap { subject in
            let minutes = sessions
                .filter { $0.subjectId == subject.id }
                .reduce(0) { $0 + $1.durationMinutes }
            guard minutes > 0 else { return nil }
            return SubjectStudySegment(
                subjectId: subject.id,
                subjectName: subject.name,
                minutes: minutes,
                color: subject.color
            )
        }
    }

    private func reportMonthlyData(sessions: [StudySession], reference: Date) -> [MonthlyStudyData] {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月"
        return (0..<6).compactMap { offset in
            guard let date = Calendar.current.date(byAdding: .month, value: -offset, to: reference),
                  let interval = Calendar.current.dateInterval(of: .month, for: date) else {
                return nil
            }
            let minutes = sessions.filter {
                $0.startTime >= interval.start.epochMilliseconds && $0.startTime <= interval.end.epochMilliseconds
            }
            .reduce(0) { $0 + $1.durationMinutes }
            return MonthlyStudyData(
                monthStart: interval.start.epochMilliseconds,
                monthLabel: formatter.string(from: interval.start),
                totalHours: minutes / 60
            )
        }
        .reversed()
    }

    private func subjectBreakdown(subjects: [Subject], sessions: [StudySession], reference: Date) -> [SubjectStudyData] {
        guard let monthAgo = Calendar.current.date(byAdding: .month, value: -1, to: reference) else { return [] }
        let lowerBound = monthAgo.epochMilliseconds
        return subjects.compactMap { subject in
            let totalMinutes = sessions
                .filter { $0.subjectId == subject.id && $0.startTime >= lowerBound && $0.startTime <= reference.epochMilliseconds }
                .reduce(0) { $0 + $1.durationMinutes }
            guard totalMinutes > 0 else { return nil }
            return SubjectStudyData(
                subjectName: subject.name,
                hours: totalMinutes / 60,
                minutes: totalMinutes % 60,
                color: subject.color
            )
        }
        .sorted { ($0.hours * 60 + $0.minutes) > ($1.hours * 60 + $1.minutes) }
    }

    private func ratingAverages(sessions: [StudySession], reference: Date) -> RatingAveragesData {
        let calendar = Calendar.current
        let todayStart = calendar.startOfDay(for: reference)
        let todayEnd = calendar.date(byAdding: .day, value: 1, to: todayStart) ?? reference
        let weekInterval = calendar.dateInterval(of: .weekOfYear, for: reference)
        let monthInterval = calendar.dateInterval(of: .month, for: reference)

        return RatingAveragesData(
            today: weightedAverageRating(
                sessions: sessions,
                start: todayStart.epochMilliseconds,
                end: todayEnd.epochMilliseconds
            ),
            week: weightedAverageRating(
                sessions: sessions,
                start: (weekInterval?.start ?? todayStart).epochMilliseconds,
                end: (weekInterval?.end ?? todayEnd).epochMilliseconds
            ),
            month: weightedAverageRating(
                sessions: sessions,
                start: (monthInterval?.start ?? todayStart).epochMilliseconds,
                end: (monthInterval?.end ?? todayEnd).epochMilliseconds
            )
        )
    }

    private func weightedAverageRating(sessions: [StudySession], start: Int64, end: Int64) -> RatingAverageSummary {
        let ratedSessions = sessions.filter {
            $0.startTime >= start &&
            $0.startTime < end &&
            $0.rating != nil
        }

        let ratedDuration = ratedSessions.reduce(Int64(0)) { $0 + $1.duration }
        guard ratedDuration > 0 else {
            return RatingAverageSummary(average: nil, ratedMinutes: 0)
        }

        let weightedTotal = ratedSessions.reduce(0.0) { partial, session in
            partial + (Double(session.rating ?? 0) * Double(session.duration))
        }

        return RatingAverageSummary(
            average: weightedTotal / Double(ratedDuration),
            ratedMinutes: Int(ratedDuration / 60_000)
        )
    }

    private func streakDays(sessions: [StudySession], reference: Date) -> Int {
        let days = Set(sessions.map { Date(epochMilliseconds: $0.startTime).startOfDay.epochDay })
        var streak = 0
        var current = reference.startOfDay
        for index in 0..<365 {
            if days.contains(current.epochDay) {
                streak += 1
            } else if index > 0 {
                break
            }
            current = Calendar.current.date(byAdding: .day, value: -1, to: current) ?? current
        }
        return streak
    }

    private func bestStreak(sessions: [StudySession]) -> Int {
        let sortedDays = Set(sessions.map { Date(epochMilliseconds: $0.startTime).startOfDay.epochDay }).sorted()
        guard var previous = sortedDays.first else { return 0 }
        var current = 1
        var best = 1
        for day in sortedDays.dropFirst() {
            if day - previous == 1 {
                current += 1
                best = max(best, current)
            } else {
                current = 1
            }
            previous = day
        }
        return best
    }
}

struct ExportImportDataUseCase {
    let repository: AppDataRepository

    func exportJSON() async throws -> String {
        try await repository.exportJSON()
    }

    func exportCSV() async throws -> String {
        try await repository.exportCSV()
    }

    func importJSON(_ json: String, currentPreferences: AppPreferences) async throws -> AppPreferences {
        try await repository.importJSON(json, currentPreferences: currentPreferences)
    }
}

struct GetSettingsSummaryUseCase {
    let sessionRepository: StudySessionRepository

    func execute() async throws -> SettingsSummary {
        let sessions = try await sessionRepository.getAllSessions()
        return SettingsSummary(
            totalSessions: sessions.count,
            totalStudyMinutes: sessions.reduce(0) { $0 + $1.durationMinutes }
        )
    }
}

struct ValidationError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}

extension Date {
    var epochMilliseconds: Int64 {
        Int64((timeIntervalSince1970 * 1_000).rounded())
    }

    var epochDay: Int64 {
        let calendar = Calendar.current
        guard let epochStart = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) else { return 0 }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: epochStart), to: calendar.startOfDay(for: self)).day ?? 0
        return Int64(days)
    }

    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    init(epochMilliseconds: Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(epochMilliseconds) / 1_000)
    }

    init(epochDay: Int64) {
        let calendar = Calendar.current
        guard let epochStart = calendar.date(from: DateComponents(year: 1970, month: 1, day: 1)) else {
            self = Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
            return
        }
        self = calendar.date(byAdding: .day, value: Int(epochDay), to: calendar.startOfDay(for: epochStart))
            ?? Date(timeIntervalSince1970: TimeInterval(epochDay) * 86_400)
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
