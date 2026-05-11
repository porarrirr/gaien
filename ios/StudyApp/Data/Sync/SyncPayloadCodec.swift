import Foundation

/// Off-main-actor helper for the sync path's heaviest work (JSON encoding of
/// the full `AppData` tree, remote-payload decoding, and the post-merge
/// `lastSyncedAt` stamping).
///
/// `FirebaseSyncRepository` is declared `@MainActor` to keep its `@Published`
/// status safe to publish without hops, but the encoding / decoding / merge
/// work can take tens of milliseconds (or more) as the data set grows, which
/// previously blocked UI. Running these through `Task.detached` hands them to
/// the global concurrency pool while the awaiting MainActor code yields.
enum SyncPayloadCodec {
    struct MergedPayload {
        let remote: AppData?
        let merged: AppData
        let payload: String
    }

    /// Decodes the remote JSON payload, merges it with the local snapshot,
    /// stamps `lastSyncedAt`, and returns the re-encoded payload plus the
    /// synced domain object. Runs entirely off the main actor.
    static func prepareMergedPayload(
        local: AppData,
        remotePayload: String?,
        syncedAt: Int64
    ) async throws -> MergedPayload {
        try await Task.detached(priority: .userInitiated) {
            let remote: AppData?
            let merged: AppData
            if let remotePayload {
                let decoded = try JSONDecoder().decode(AppData.self, from: Data(remotePayload.utf8))
                remote = decoded
                merged = SyncMergeEngine.merge(local: local, remote: decoded)
            } else {
                remote = nil
                merged = local
            }
            let synced = SyncMergeEngine.markSynced(merged, at: syncedAt)
            let data = try JSONEncoder().encode(synced)
            let payload = String(data: data, encoding: .utf8) ?? "{}"
            return MergedPayload(remote: remote, merged: synced, payload: payload)
        }.value
    }

    /// Stamps `lastSyncedAt` on the local snapshot and returns the encoded
    /// payload. Used by the "local → cloud" upload flow where no merge is
    /// required.
    static func prepareLocalPayload(local: AppData, syncedAt: Int64) async throws -> (synced: AppData, payload: String) {
        try await Task.detached(priority: .userInitiated) {
            let synced = SyncMergeEngine.markSynced(local, at: syncedAt)
            let data = try JSONEncoder().encode(synced)
            let payload = String(data: data, encoding: .utf8) ?? "{}"
            return (synced, payload)
        }.value
    }

    /// Decodes a remote payload off the main actor.
    static func decode(_ payload: String) async throws -> AppData {
        try await Task.detached(priority: .userInitiated) {
            try JSONDecoder().decode(AppData.self, from: Data(payload.utf8))
        }.value
    }

    /// Encodes an `AppData` snapshot off the main actor.
    static func encode(_ appData: AppData, prettyPrinted: Bool = false) async throws -> Data {
        try await Task.detached(priority: .userInitiated) {
            let encoder = JSONEncoder()
            if prettyPrinted {
                encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            }
            return try encoder.encode(appData)
        }.value
    }
}
