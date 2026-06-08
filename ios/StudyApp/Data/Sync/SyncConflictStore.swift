import Foundation

/// Local persistence for unresolved sync conflicts, keyed per signed-in user.
enum SyncConflictStore {
    private static let directoryName = "StudyApp/SyncConflicts"

    static func load(userId: String) -> [SyncConflict] {
        guard let url = try? fileURL(userId: userId),
              let data = try? Data(contentsOf: url),
              let conflicts = try? JSONDecoder().decode([SyncConflict].self, from: data) else {
            return []
        }
        return conflicts
    }

    static func save(_ conflicts: [SyncConflict], userId: String) throws {
        let url = try fileURL(userId: userId, createDirectory: true)
        if conflicts.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        let data = try JSONEncoder().encode(conflicts)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func delete(userId: String) {
        guard let url = try? fileURL(userId: userId) else { return }
        try? FileManager.default.removeItem(at: url)
    }

    static func clearAll() {
        guard let directory = baseDirectory() else { return }
        try? FileManager.default.removeItem(at: directory)
    }

    private static func baseDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func fileURL(userId: String, createDirectory: Bool = false) throws -> URL {
        guard let directory = baseDirectory() else {
            throw CocoaError(.fileNoSuchFile)
        }
        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let safeUserId = userId.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(safeUserId).json")
    }
}
