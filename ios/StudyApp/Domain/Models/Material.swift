import Foundation

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
