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
/// The store is deliberately small: it owns the raw I/O (writes, reads,
/// batch commits) and nothing about domain-level merge. Higher layers
/// (`FirebaseSyncRepository`) do the merge through `SyncMergeEngine` and
/// decide *what* to push.
@MainActor
struct FirestoreDeltaSyncStore {
    struct FetchResult {
        var envelopes: [SyncEntityEnvelope]
        var cursor: SyncServerCursor
    }
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
            if let revisionId = envelope.revisionId { data["revisionId"] = revisionId }
            if let parentRevisionId = envelope.parentRevisionId { data["parentRevisionId"] = parentRevisionId }
            if let deviceId = envelope.deviceId { data["deviceId"] = deviceId }
            if let contentHash = envelope.contentHash { data["contentHash"] = contentHash }
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

    /// Fetches entities committed after the previous Firestore server cursor.
    ///
    /// Paginates by `serverUpdatedAt` plus document id so documents sharing the same
    /// millisecond timestamp are not skipped or fetched forever. Firestore's
    /// `documentID()` cursor validation is picky for nested collections, so
    /// page-to-page progress uses document snapshots instead of raw document id
    /// cursor values.
    func fetchEnvelopes(userId: String, changedSince cursor: SyncServerCursor) async throws -> FetchResult {
        let collection = entitiesCollection(userId: userId)
        let pageSize = 500
        var results: [SyncEntityEnvelope] = []
        var lastSeen = cursor
        var lastPageDocument: DocumentSnapshot?

        logger.log(
            category: .sync,
            message: "Delta envelope fetch started",
            details: "path=users/<uid>/sync_entities serverCursor=\(cursor.seconds).\(cursor.nanoseconds) cursorDoc=\(cursor.documentId) pageSize=\(pageSize)"
        )

        while true {
            let snapshot: QuerySnapshot
            do {
                var query: Query = collection
                    .whereField(
                        "serverUpdatedAt",
                        isGreaterThanOrEqualTo: Timestamp(
                            seconds: cursor.seconds,
                            nanoseconds: cursor.nanoseconds
                        )
                    )
                    .order(by: "serverUpdatedAt")
                    .order(by: FieldPath.documentID())
                if let lastPageDocument {
                    query = query.start(afterDocument: lastPageDocument)
                }
                snapshot = try await query.limit(to: pageSize).getDocuments()
            } catch {
                logFirestoreFailure(
                    operation: "fetchDeltaEnvelopes",
                    userId: userId,
                    details: "path=users/<uid>/sync_entities serverCursor=\(cursor.seconds).\(cursor.nanoseconds) lastSeen=\(lastSeen.seconds).\(lastSeen.nanoseconds) lastDoc=\(lastSeen.documentId) hasPageCursor=\(lastPageDocument != nil) pageSize=\(pageSize)",
                    error: error
                )
                throw error
            }

            if snapshot.documents.isEmpty {
                break
            }
            for document in snapshot.documents {
                guard let serverUpdatedAt = document.data()["serverUpdatedAt"] as? Timestamp else {
                    logger.log(
                        category: .sync,
                        level: .warning,
                        message: "Skipped delta document without server timestamp",
                        details: "docId=\(document.documentID)"
                    )
                    continue
                }
                let position = SyncServerCursor(
                    seconds: serverUpdatedAt.seconds,
                    nanoseconds: serverUpdatedAt.nanoseconds,
                    documentId: document.documentID
                )
                guard position > cursor else { continue }
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
            }
            if let lastDocument = snapshot.documents.last,
               let serverUpdatedAt = lastDocument.data()["serverUpdatedAt"] as? Timestamp {
                lastSeen = SyncServerCursor(
                    seconds: serverUpdatedAt.seconds,
                    nanoseconds: serverUpdatedAt.nanoseconds,
                    documentId: lastDocument.documentID
                )
                lastPageDocument = lastDocument
            } else {
                break
            }
            if snapshot.documents.count < pageSize {
                break
            }
        }

        logger.log(
            category: .sync,
            message: "Delta envelopes fetched",
            details: "count=\(results.count) cursorBefore=\(cursor.seconds).\(cursor.nanoseconds) cursorAfter=\(lastSeen.seconds).\(lastSeen.nanoseconds)"
        )
        return FetchResult(envelopes: results, cursor: lastSeen)
    }

    /// Reads every envelope under the user. Used during the one-time
    /// migration from legacy chunked-v2 snapshots so we can seed the local
    /// side even though we don't have a cursor.
    func fetchAllEnvelopes(userId: String) async throws -> [SyncEntityEnvelope] {
        let result = try await fetchEnvelopes(userId: userId, changedSince: .zero)
        return result.envelopes
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

    func recordClientFlags(_ flags: [String: Any], userId: String) async throws {
        let document = firestore.collection("users").document(userId)
        let snapshot = try await document.getDocument()
        var payload = snapshot.data()?["clientFlags"] as? [String: Any] ?? [:]
        for (key, value) in flags {
            payload[key] = value
        }
        payload["lastSeenAt"] = Date().epochMilliseconds
        payload["appDataSchemaVersion"] = AppData.currentSchemaVersion
        try await document.setData(
            [
                "clientFlags": payload,
                "clientFlagsUpdatedAt": FieldValue.serverTimestamp()
            ],
            merge: true
        )
    }

    /// Permanently deletes all cloud sync data owned by the user.
    func deleteAllUserData(userId: String) async throws {
        try await deleteDocuments(in: entitiesCollection(userId: userId), userId: userId, operation: "deleteDeltaUserData")

        let manifest = firestore
            .collection("users").document(userId)
            .collection("sync").document("default")
        try await deleteDocuments(in: manifest.collection("chunks"), userId: userId, operation: "deleteLegacyChunks")

        let batch = firestore.batch()
        batch.deleteDocument(manifest)
        batch.deleteDocument(firestore.collection("users").document(userId))
        do {
            try await batch.commit()
        } catch {
            logFirestoreFailure(
                operation: "deleteUserSyncRoot",
                userId: userId,
                details: "path=users/<uid>",
                error: error
            )
            throw error
        }

        logger.log(category: .sync, level: .warning, message: "Deleted cloud sync data", details: "path=users/<uid>")
    }

    // MARK: - Private

    private func entitiesCollection(userId: String) -> CollectionReference {
        firestore
            .collection("users").document(userId)
            .collection("sync_entities")
    }

    private func deleteDocuments(in collection: CollectionReference, userId: String, operation: String) async throws {
        while true {
            let snapshot: QuerySnapshot
            do {
                snapshot = try await collection.limit(to: maxBatchOperations).getDocuments()
            } catch {
                logFirestoreFailure(
                    operation: operation,
                    userId: userId,
                    details: "path=\(collection.path)",
                    error: error
                )
                throw error
            }
            guard !snapshot.documents.isEmpty else { return }

            let batch = firestore.batch()
            for document in snapshot.documents {
                batch.deleteDocument(document.reference)
            }
            do {
                try await batch.commit()
            } catch {
                logFirestoreFailure(
                    operation: operation,
                    userId: userId,
                    details: "path=\(collection.path) count=\(snapshot.documents.count)",
                    error: error
                )
                throw error
            }
        }
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
            json: json,
            revisionId: data["revisionId"] as? String,
            parentRevisionId: data["parentRevisionId"] as? String,
            deviceId: data["deviceId"] as? String,
            contentHash: data["contentHash"] as? String
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
