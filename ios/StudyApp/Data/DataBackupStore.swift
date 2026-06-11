import Foundation

struct DataBackupDescriptor: Identifiable, Hashable {
    let fileName: String
    let createdAt: Date
    let reason: String
    let url: URL

    var id: String { fileName }
}

enum DataBackupStore {
    static let automaticBackupInterval: TimeInterval = 24 * 60 * 60
    static let retentionInterval: TimeInterval = 30 * 24 * 60 * 60

    static func shouldCreateAutomaticBackup(
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> Bool {
        guard let newest = try list(fileManager: fileManager).first else {
            return true
        }
        return now.timeIntervalSince(newest.createdAt) >= automaticBackupInterval
    }

    static func save(
        data: Data,
        reason: String,
        fileManager: FileManager = .default,
        now: Date = Date()
    ) throws -> DataBackupDescriptor {
        let directory = try backupDirectory(fileManager: fileManager)
        let safeReason = reason
            .lowercased()
            .replacingOccurrences(of: #"[^a-z0-9-]+"#, with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        let timestamp = StudyFormatters.fileSafeTimestamp.string(from: now)
        let fileName = "data-\(safeReason.isEmpty ? "backup" : safeReason)-\(timestamp).json"
        let url = directory.appendingPathComponent(fileName)

        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
        try prune(fileManager: fileManager, now: now)

        return DataBackupDescriptor(
            fileName: fileName,
            createdAt: now,
            reason: reason,
            url: url
        )
    }

    static func list(fileManager: FileManager = .default) throws -> [DataBackupDescriptor] {
        let directory = try backupDirectory(fileManager: fileManager)
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        return try urls.compactMap { url in
            guard url.pathExtension.lowercased() == "json" else { return nil }
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values.isRegularFile == true, let createdAt = values.contentModificationDate else {
                return nil
            }
            return DataBackupDescriptor(
                fileName: url.lastPathComponent,
                createdAt: createdAt,
                reason: reason(from: url.lastPathComponent),
                url: url
            )
        }
        .sorted { $0.createdAt > $1.createdAt }
    }

    private static func backupDirectory(fileManager: FileManager) throws -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("StudyApp/DataBackups", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private static func prune(fileManager: FileManager, now: Date) throws {
        let cutoff = now.addingTimeInterval(-retentionInterval)
        for backup in try listWithoutPruning(fileManager: fileManager) where backup.createdAt < cutoff {
            try fileManager.removeItem(at: backup.url)
        }
    }

    private static func listWithoutPruning(fileManager: FileManager) throws -> [DataBackupDescriptor] {
        let directory = try backupDirectory(fileManager: fileManager)
        let urls = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        return try urls.compactMap { url in
            guard url.pathExtension.lowercased() == "json" else { return nil }
            let values = try url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values.isRegularFile == true, let createdAt = values.contentModificationDate else {
                return nil
            }
            return DataBackupDescriptor(
                fileName: url.lastPathComponent,
                createdAt: createdAt,
                reason: reason(from: url.lastPathComponent),
                url: url
            )
        }
    }

    private static func reason(from fileName: String) -> String {
        guard fileName.hasPrefix("data-"), fileName.hasSuffix(".json") else {
            return "backup"
        }
        let body = String(fileName.dropFirst(5).dropLast(5))
        let components = body.split(separator: "-")
        guard components.count > 2 else { return body }
        return components.dropLast(2).joined(separator: "-")
    }
}
