import Foundation

/// Composite delta cursor: `updatedAt` plus `documentId` tie-breaker so entities
/// sharing the same millisecond timestamp are not skipped during pagination.
struct SyncDeltaCursor: Codable, Equatable, Comparable {
    var updatedAt: Int64
    var documentId: String

    static let zero = SyncDeltaCursor(updatedAt: 0, documentId: "")

    static func < (lhs: SyncDeltaCursor, rhs: SyncDeltaCursor) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt < rhs.updatedAt
        }
        return lhs.documentId < rhs.documentId
    }

    func isAfter(_ other: SyncDeltaCursor) -> Bool {
        self > other
    }

    /// Advances the cursor to at least the given envelope position.
    mutating func absorb(_ envelope: SyncEntityEnvelope) {
        let candidate = SyncDeltaCursor(updatedAt: envelope.updatedAt, documentId: envelope.documentId)
        if candidate > self {
            self = candidate
        }
    }

    /// Legacy migration from Int64-only cursor stored before composite cursors.
    static func fromLegacy(_ updatedAt: Int64) -> SyncDeltaCursor {
        SyncDeltaCursor(updatedAt: updatedAt, documentId: "")
    }
}

extension SyncEntityEnvelope {
    var cursorPosition: SyncDeltaCursor {
        SyncDeltaCursor(updatedAt: updatedAt, documentId: documentId)
    }
}

/// Firestore read position. This cursor is intentionally independent from
/// entity `updatedAt`, which remains a client timestamp used only for merges.
struct SyncServerCursor: Codable, Equatable, Comparable {
    var seconds: Int64
    var nanoseconds: Int32
    var documentId: String

    static let zero = SyncServerCursor(seconds: 0, nanoseconds: 0, documentId: "")

    static func < (lhs: SyncServerCursor, rhs: SyncServerCursor) -> Bool {
        if lhs.seconds != rhs.seconds {
            return lhs.seconds < rhs.seconds
        }
        if lhs.nanoseconds != rhs.nanoseconds {
            return lhs.nanoseconds < rhs.nanoseconds
        }
        return lhs.documentId < rhs.documentId
    }
}
