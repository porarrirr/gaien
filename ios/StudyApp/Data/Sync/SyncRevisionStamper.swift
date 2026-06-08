import Foundation
import CryptoKit

/// Stamps revision metadata onto outbound envelopes. Optional fields remain
/// absent when unchanged so legacy clients can still read documents.
enum SyncRevisionStamper {
    static func stamp(
        _ envelopes: [SyncEntityEnvelope],
        previousBase: AppData?,
        previousRevisions: [String: String] = [:],
        deviceId: String = SyncDeviceIdentity.current
    ) -> [SyncEntityEnvelope] {
        let previousRevisions = previousRevisions.isEmpty ? previousRevisionMap(from: previousBase) : previousRevisions
        return envelopes.map { envelope in
            var stamped = envelope
            let parent = previousRevisions[envelope.documentId]
            stamped.revisionId = UUID().uuidString.lowercased()
            stamped.parentRevisionId = parent
            stamped.deviceId = deviceId
            stamped.contentHash = sha256(envelope.json)
            return stamped
        }
    }

    private static func previousRevisionMap(from base: AppData?) -> [String: String] {
        guard let base else { return [:] }
        return Dictionary(
            uniqueKeysWithValues: SyncDeltaSerializer.decompose(base).compactMap { envelope in
                guard let revision = envelope.revisionId ?? envelope.contentHash, !revision.isEmpty else {
                    return nil
                }
                return (envelope.documentId, revision)
            }
        )
    }

    private static func sha256(_ json: String) -> String {
        let digest = SHA256.hash(data: Data(json.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
