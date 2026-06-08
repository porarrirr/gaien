import Foundation

enum SyncConflictField: String, Codable, CaseIterable {
    case name
    case note
    case currentPage
    case totalPages
    case totalProblems
    case problemRecords
    case problemChapters
    case deletion
    case problemReviewState
    case other
}

enum SyncConflictResolutionStrategy: String, Codable, CaseIterable {
    case keepLocal
    case keepRemote
    case keepMerged
}

/// A single unresolved entity-level sync conflict awaiting user choice.
struct SyncConflict: Identifiable, Codable, Equatable {
    var id: String { "\(kind.rawValue)-\(syncId)" }
    var kind: SyncEntityKind
    var syncId: String
    var title: String
    var summary: String
    var conflictFields: [SyncConflictField]
    var baseJson: String?
    var localJson: String
    var remoteJson: String
    var suggestedMergedJson: String
    var detectedAt: Int64

    var documentId: String { "\(kind.rawValue)-\(syncId)" }
}

struct SyncConflictResolution: Codable, Equatable {
    var kind: SyncEntityKind
    var syncId: String
    var strategy: SyncConflictResolutionStrategy
}
