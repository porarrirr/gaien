import Foundation

actor PersistenceController {
    static let shared = PersistenceController()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL? = nil) {
        let baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        self.fileURL = fileURL ?? baseURL.appendingPathComponent("studyapp-store.json")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        self.encoder = encoder

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        self.decoder = decoder
    }

    func load() throws -> AppSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .empty
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppSnapshot.self, from: data)
    }

    func save(snapshot: AppSnapshot) throws {
        let data = try encoder.encode(snapshot)
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: fileURL, options: .atomic)
    }

    func exportJSON(from snapshot: AppSnapshot) throws -> String {
        let backup = AppBackup.make(from: snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(backup)
        guard let string = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return string
    }

    func importJSON(_ json: String, into current: AppSnapshot) throws -> AppSnapshot {
        let data = Data(json.utf8)
        let backup = try JSONDecoder().decode(AppBackup.self, from: data)
        return backup.asSnapshot(preserving: current)
    }

    func exportCSV(from snapshot: AppSnapshot) -> String {
        let header = "日付,科目,教材,開始時刻,終了時刻,時間(分),メモ\n"
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy/MM/dd"

        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "HH:mm"

        let rows = snapshot.sessions.sorted { $0.startTime > $1.startTime }.map { session in
            [
                csvEscaped(dateFormatter.string(from: session.startTime)),
                csvEscaped(session.subjectName),
                csvEscaped(session.materialName),
                csvEscaped(timeFormatter.string(from: session.startTime)),
                csvEscaped(timeFormatter.string(from: session.endTime)),
                "\(session.durationMinutes)",
                csvEscaped(session.note ?? "")
            ].joined(separator: ",")
        }

        return header + rows.joined(separator: "\n")
    }

    private func csvEscaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
