import Foundation

/// Stable per-installation device id used in sync revision metadata.
enum SyncDeviceIdentity {
    private static let key = "studyapp.sync.deviceId"

    static var current: String {
        if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
            return existing
        }
        let generated = UUID().uuidString.lowercased()
        UserDefaults.standard.set(generated, forKey: key)
        return generated
    }
}
