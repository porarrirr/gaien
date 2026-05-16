import FirebaseFirestore
import Foundation

/// Firestore-backed implementation of the per-entity delta sync store.
///
/// Documents live under `users/{uid}/sync_entities/{kind}-{syncId}`.
/// Each document looks like:
///
/// ```
/// {
///   "kind": "session",
///   "syncId": "uuid-lower",
///   "updatedAt": 1700000000000,        // client clock, ms
///   "deletedAt": 1700000000000 | null,
///   "serverUpdatedAt": serverTimestamp(),
///   "json": "<domain-encoded-json>"
/// }
/// ```
///
/// We key the delta cursor off `updatedAt` (client clock) rather than
/// `serverUpdatedAt` so that two devices that are briefly offline still
/// converge without leaning on Firestore clock skew. `serverUpdatedAt` is
/// retained only for diagnostics and secondary indexing.
///
/// The store is deliberately small: it owns the raw I/O (writes, reads,
/// batch commits) and nothing about domain-level merge. Higher layers
/// (`FirebaseSyncRepository`) do the merge through `SyncMergeEngine` and
/// decide *what* to push.
@MainActor
struct FirestoreDeltaSyncStore {
    private let firestore: Firestore
    private let logger: AppLogger

    /// Firestore rejects batches with > 500 writes. We stay conservative.
    private let maxBatchOperations = 450

    init(firestore: Firestore, logger: AppLogger) {
        self.firestore = firestore
        self.logger = logger
    }

    /// Writes the given envelopes. Tombstoned envelopes (`deletedAt != nil`)
    /// are still *written* rather than deleted so the other device can
    /// observe the tombstone and propagate the deletion locally. They are
    /// purged by `purgeTombstonesOlderThan` once the retention window closes.
    func writeEnvelopes(_ envelopes: [SyncEntityEnvelope], userId: String) async throws {
        guard !envelopes.isEmpty else { return }

        let collection = entitiesCollection(userId: userId)
        logger.log(
            category: .sync,
            message: "Delta envelope write started",
            details: "path=users/<uid>/sync_entities count=\(envelopes.count) batches=\((envelopes.count + maxBatchOperations - 1) / maxBatchOperations)"
        )
        var operations: [(DocumentReference, [String: Any])] = []
        operations.reserveCapacity(envelopes.count)
        for envelope in envelopes {
            let ref = collection.document(envelope.documentId)
            var data: [String: Any] = [
                "kind": envelope.kind.rawValue,
                "syncId": envelope.syncId,
                "updatedAt": envelope.updatedAt,
                "serverUpdatedAt": FieldValue.serverTimestamp(),
                "json": envelope.json
            ]
            data["deletedAt"] = envelope.deletedAt ?? NSNull()
            operations.append((ref, data))
        }

        var index = 0
        while index < operations.count {
            let batch = firestore.batch()
            let end = min(index + maxBatchOperations, operations.count)
            for operation in operations[index..<end] {
                batch.setData(operation.1, forDocument: operation.0, merge: false)
            }
            do {
                try await batch.commit()
            } catch {
                logFirestoreFailure(
                    operation: "writeDeltaEnvelopes",
                    userId: userId,
                    details: "path=users/<uid>/sync_entities batchStart=\(index) batchEnd=\(end) total=\(operations.count)",
                    error: error
                )
                throw error
            }
            index = end
        }

        logger.log(
            category: .sync,
            message: "Delta envelopes written",
            details: "count=\(envelopes.count)"
        )
    }

    /// Fetches entities that changed (either `updatedAt > cursor` or a fresh
    /// tombstone) since the previous sync. `cursor` is the `updatedAt` that
    /// the last successful sync observed; pass `0` for a full initial load.
    ///
    /// Firestore rejects `whereField(_:isGreaterThan:)` on a numeric field
    /// when the index is missing, so we paginate by `updatedAt` ascending and
    /// stop reading once we consume a page shorter than the page size. This
    /// keeps us on the default single-field index.
    func fetchEnvelopes(userId: String, changedSince cursor: Int64) async throws -> [SyncEntityEnvelope] {
        let collection = entitiesCollection(userId: userId)
        let pageSize = 500
        var results: [SyncEntityEnvelope] = []
        var lastSeen: Int64 = cursor

        logger.log(
            category: .sync,
            message: "Delta envelope fetch started",
            details: "path=users/<uid>/sync_entities cursor=\(cursor) pageSize=\(pageSize)"
        )

        while true {
            let snapshot: QuerySnapshot
            do {
                snapshot = try await collection
                    .whereField("updatedAt", isGreaterThan: lastSeen)
                    .order(by: "updatedAt")
                    .limit(to: pageSize)
                    .getDocuments()
            } catch {
                logFirestoreFailure(
                    operation: "fetchDeltaEnvelopes",
                    userId: userId,
                    details: "path=users/<uid>/sync_entities cursor=\(cursor) lastSeen=\(lastSeen) pageSize=\(pageSize)",
                    error: error
                )
                throw error
            }

            if snapshot.documents.isEmpty {
                break
            }
            for document in snapshot.documents {
                guard let envelope = Self.envelope(from: document.data()) else {
                    logger.log(
                        category: .sync,
                        level: .warning,
                        message: "Skipped malformed delta document",
                        details: "docId=\(document.documentID)"
                    )
                    continue
                }
                results.append(envelope)
                if envelope.updatedAt > lastSeen {
                    lastSeen = envelope.updatedAt
                }
            }
            if snapshot.documents.count < pageSize {
                break
            }
        }

        logger.log(
            category: .sync,
            message: "Delta envelopes fetched",
            details: "count=\(results.count) cursorBefore=\(cursor) cursorAfter=\(lastSeen)"
        )
        return results
    }

    /// Reads every envelope under the user. Used during the one-time
    /// migration from legacy chunked-v2 snapshots so we can seed the local
    /// side even though we don't have a cursor.
    func fetchAllEnvelopes(userId: String) async throws -> [SyncEntityEnvelope] {
        try await fetchEnvelopes(userId: userId, changedSince: -1)
    }

    /// Permanently removes tombstones older than `retentionMillis`. Running
    /// this occasionally caps the delta collection's growth.
    func purgeTombstonesOlderThan(retentionMillis: Int64, now: Int64, userId: String) async throws {
        let cutoff = now - retentionMillis
        let collection = entitiesCollection(userId: userId)
        let snapshot: QuerySnapshot
        do {
            snapshot = try await collection
                .whereField("deletedAt", isLessThan: cutoff)
                .limit(to: 500)
                .getDocuments()
        } catch {
            logFirestoreFailure(
                operation: "fetchDeltaTombstonesForPurge",
                userId: userId,
                details: "path=users/<uid>/sync_entities cutoff=\(cutoff)",
                error: error
            )
            throw error
        }
        guard !snapshot.documents.isEmpty else { return }

        var index = 0
        while index < snapshot.documents.count {
            let batch = firestore.batch()
            let end = min(index + maxBatchOperations, snapshot.documents.count)
            for document in snapshot.documents[index..<end] {
                batch.deleteDocument(document.reference)
            }
            do {
                try await batch.commit()
            } catch {
                logFirestoreFailure(
                    operation: "purgeDeltaTombstones",
                    userId: userId,
                    details: "path=users/<uid>/sync_entities batchStart=\(index) batchEnd=\(end) total=\(snapshot.documents.count)",
                    error: error
                )
                throw error
            }
            index = end
        }
        logger.log(
            category: .sync,
            message: "Purged stale delta tombstones",
            details: "count=\(snapshot.documents.count) cutoff=\(cutoff)"
        )
    }

    /// Clears the sync manifest used by the legacy chunked-v2 path. Called
    /// once we have migrated a user to delta mode so the legacy code path
    /// doesn't try to resurrect old state on the next sync.
    func clearLegacyChunkedSnapshot(userId: String) async throws {
        let manifest = firestore
            .collection("users").document(userId)
            .collection("sync").document("default")
        let chunks = try await manifest.collection("chunks").getDocuments()
        var batch = firestore.batch()
        var writeCount = 0
        for chunk in chunks.documents {
            batch.deleteDocument(chunk.reference)
            writeCount += 1
            if writeCount >= maxBatchOperations {
                try await batch.commit()
                batch = firestore.batch()
                writeCount = 0
            }
        }
        batch.deleteDocument(manifest)
        try await batch.commit()
    }

    // MARK: - Private

    private func entitiesCollection(userId: String) -> CollectionReference {
        firestore
            .collection("users").document(userId)
            .collection("sync_entities")
    }

    /// Parses a Firestore document into an envelope. Returns nil when the
    /// document is missing the minimum required fields so the caller can log
    /// and skip instead of failing the whole sync.
    private static func envelope(from data: [String: Any]) -> SyncEntityEnvelope? {
        guard
            let kindRaw = data["kind"] as? String,
            let kind = SyncEntityKind(rawValue: kindRaw),
            let syncId = data["syncId"] as? String,
            !syncId.isEmpty,
            let updatedAt = readInt64(data["updatedAt"]),
            let json = data["json"] as? String
        else {
            return nil
        }
        let deletedAt = readInt64(data["deletedAt"])
        return SyncEntityEnvelope(
            kind: kind,
            syncId: syncId,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            json: json
        )
    }

    private func logFirestoreFailure(operation: String, userId: String, details: String, error: Error) {
        let nsError = error as NSError
        let permissionHint = error.localizedDescription.localizedCaseInsensitiveContains("permission")
            ? " hint=verify Firestore rules for users/{uid}/sync_entities and authenticated uid ownership"
            : ""
        logger.log(
            category: .sync,
            level: .error,
            message: "Firestore delta operation failed",
            details: "operation=\(operation) uid=\(userId) \(details) nsDomain=\(nsError.domain) nsCode=\(nsError.code)\(permissionHint)",
            error: error
        )
    }

    private static func readInt64(_ value: Any?) -> Int64? {
        switch value {
        case let number as NSNumber:
            return number.int64Value
        case let intValue as Int:
            return Int64(intValue)
        case let int64Value as Int64:
            return int64Value
        case let string as String:
            return Int64(string)
        default:
            return nil
        }
    }
}
