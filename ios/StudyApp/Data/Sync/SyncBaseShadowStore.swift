import Foundation

/// Persists the last successfully synced `AppData` snapshot per user as the
/// three-way merge base (common ancestor after each successful sync).
enum SyncBaseShadowStore {
    private static let directoryName = "StudyApp/SyncBases"

    static func load(userId: String) throws -> AppData? {
        guard let url = try fileURL(userId: userId),
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return try AppDataUpgrader.decode(Data(contentsOf: url))
    }

    static func save(_ appData: AppData, userId: String) throws {
        guard let url = try fileURL(userId: userId, createDirectory: true) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONEncoder().encode(appData)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func delete(userId: String) throws {
        if let url = try fileURL(userId: userId), FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }
        if let revisionURL = try revisionFileURL(userId: userId),
           FileManager.default.fileExists(atPath: revisionURL.path) {
            try FileManager.default.removeItem(at: revisionURL)
        }
    }

    static func clearAll() throws {
        if let directory = baseDirectory(), FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }
        if let revisionDirectory = revisionBaseDirectory(),
           FileManager.default.fileExists(atPath: revisionDirectory.path) {
            try FileManager.default.removeItem(at: revisionDirectory)
        }
    }

    /// First sync after upgrade: treat current local state as base when none exists.
    static func bootstrapIfNeeded(userId: String, local: AppData) throws {
        guard try load(userId: userId) == nil else { return }
        try save(local, userId: userId)
    }

    private static func baseDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func fileURL(userId: String, createDirectory: Bool = false) throws -> URL? {
        guard let directory = baseDirectory() else { return nil }
        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let safeUserId = userId.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(safeUserId).json")
    }

    static func loadRevisionMap(userId: String) throws -> [String: String] {
        guard let url = try revisionFileURL(userId: userId),
              FileManager.default.fileExists(atPath: url.path) else {
            return [:]
        }
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    static func saveRevisionMap(_ revisions: [String: String], userId: String) throws {
        guard let url = try revisionFileURL(userId: userId, createDirectory: true) else {
            throw CocoaError(.fileNoSuchFile)
        }
        let data = try JSONEncoder().encode(revisions)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    static func mergeRevisionMap(envelopes: [SyncEntityEnvelope], userId: String) throws {
        var revisions = try loadRevisionMap(userId: userId)
        for envelope in envelopes {
            if let revision = envelope.revisionId ?? envelope.contentHash, !revision.isEmpty {
                revisions[envelope.documentId] = revision
            }
        }
        try saveRevisionMap(revisions, userId: userId)
    }

    private static func revisionFileURL(userId: String, createDirectory: Bool = false) throws -> URL? {
        guard let directory = revisionBaseDirectory() else {
            return nil
        }
        if createDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        let safeUserId = userId.replacingOccurrences(of: "/", with: "_")
        return directory.appendingPathComponent("\(safeUserId).json")
    }

    private static func revisionBaseDirectory() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("StudyApp/SyncBaseRevisions", isDirectory: true)
    }
}
