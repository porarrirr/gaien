import Foundation

enum DebugLogCategory: String, Codable, CaseIterable {
    case app
    case auth
    case sync
    case barcode
    case ui
}

enum DebugLogLevel: String, Codable, CaseIterable {
    case debug
    case info
    case warning
    case error
}

struct DebugLogEntry: Identifiable, Codable, Equatable {
    var id: String
    var timestamp: Date
    var category: DebugLogCategory
    var level: DebugLogLevel
    var message: String
    var details: String?
    var errorDescription: String?

    init(
        id: String = UUID().uuidString.lowercased(),
        timestamp: Date = Date(),
        category: DebugLogCategory,
        level: DebugLogLevel,
        message: String,
        details: String? = nil,
        errorDescription: String? = nil
    ) {
        self.id = id
        self.timestamp = timestamp
        self.category = category
        self.level = level
        self.message = message
        self.details = details
        self.errorDescription = errorDescription
    }
}

@MainActor
final class AppLogger: ObservableObject {
    static var isDebugToolsEnabled: Bool {
#if DEBUG
        true
#else
        false
#endif
    }

    private let fileManager: FileManager
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let maxEntries: Int

    @Published private(set) var entries: [DebugLogEntry] = []

    init(fileManager: FileManager = .default, maxEntries: Int = 500) {
        self.fileManager = fileManager
        self.maxEntries = maxEntries

        let baseURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directoryURL = baseURL.appendingPathComponent("StudyApp", isDirectory: true)
        self.fileURL = directoryURL.appendingPathComponent("debug-log.json")
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder.dateDecodingStrategy = .iso8601
        encoder.dateEncodingStrategy = .iso8601

        if Self.isDebugToolsEnabled {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            } catch {
                print("[StudyApp] Failed to create debug log directory: \(error.localizedDescription)")
            }
            loadEntries()
        } else {
            entries = []
        }
    }

    func log(
        category: DebugLogCategory,
        level: DebugLogLevel = .info,
        message: String,
        details: String? = nil,
        error: Error? = nil
    ) {
        let entry = DebugLogEntry(
            category: category,
            level: level,
            message: message,
            details: Self.redact(details),
            errorDescription: error.map { Self.redact(($0 as? LocalizedError)?.errorDescription ?? $0.localizedDescription) }
        )
        entries.insert(entry, at: 0)
        if entries.count > maxEntries {
            entries = Array(entries.prefix(maxEntries))
        }
        persistEntries()
    }

    func recentEntries() -> [DebugLogEntry] {
        entries
    }

    func exportText() -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return entries.map { entry in
            var parts = [
                "[\(formatter.string(from: entry.timestamp))]",
                "[\(entry.level.rawValue.uppercased())]",
                "[\(entry.category.rawValue)]",
                entry.message
            ]
            if let details = entry.details, !details.isEmpty {
                parts.append("details=\(details)")
            }
            if let errorDescription = entry.errorDescription, !errorDescription.isEmpty {
                parts.append("error=\(errorDescription)")
            }
            return parts.joined(separator: " ")
        }
        .joined(separator: "\n")
    }

    func clear() {
        entries = []
        persistEntries()
    }

    private func loadEntries() {
        guard Self.isDebugToolsEnabled else {
            entries = []
            return
        }
        guard fileManager.fileExists(atPath: fileURL.path) else {
            entries = []
            return
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let decoded = try decoder.decode([DebugLogEntry].self, from: data)
            entries = decoded.sorted { $0.timestamp > $1.timestamp }
        } catch {
            entries = []
            print("[StudyApp] Failed to load debug logs: \(error.localizedDescription)")
        }
    }

    private func persistEntries() {
        guard Self.isDebugToolsEnabled else { return }
        do {
            let data = try encoder.encode(entries)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[StudyApp] Failed to persist debug logs: \(error.localizedDescription)")
        }
    }

    private static func redact(_ value: String?) -> String? {
        guard var redacted = value, !redacted.isEmpty else { return value }

        let replacements = [
            (#"email=[^\s]+"#, "email=<redacted>"),
            (#"uid=[^\s]+"#, "uid=<redacted>"),
            (#"userId=[^\s]+"#, "userId=<redacted>"),
            (#"localId=[^\s]+"#, "localId=<redacted>")
        ]

        for (pattern, replacement) in replacements {
            redacted = redacted.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        return redacted
    }
}
