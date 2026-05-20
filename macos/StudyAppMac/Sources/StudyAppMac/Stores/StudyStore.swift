import Foundation
import Observation

@Observable
final class StudyStore {
    var subjects: [StudySubject]
    var materials: [StudyMaterial]
    var goals: [StudyGoal]
    var sessions: [StudySessionRecord]
    var timer: StudyTimerState

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultFileURL

        if let snapshot = Self.load(from: self.fileURL) {
            subjects = snapshot.subjects
            materials = snapshot.materials
            goals = snapshot.goals
            sessions = snapshot.sessions
            timer = snapshot.timer
        } else {
            let defaults = Self.defaultSnapshot
            subjects = defaults.subjects
            materials = defaults.materials
            goals = defaults.goals
            sessions = defaults.sessions
            timer = defaults.timer
            save()
        }
    }

    var todayMinutes: Int {
        sessions
            .filter { Calendar.current.isDateInToday($0.startedAt) }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var weekMinutes: Int {
        sessions
            .filter { $0.startedAt.isInCurrentWeek() }
            .reduce(0) { $0 + $1.durationMinutes }
    }

    var recentSessions: [StudySessionRecord] {
        sessions.sorted { $0.startedAt > $1.startedAt }
    }

    var activeDailyGoal: StudyGoal? {
        goals.first { $0.isActive && $0.cadence == .daily && $0.subjectID == nil }
    }

    var activeWeeklyGoal: StudyGoal? {
        goals.first { $0.isActive && $0.cadence == .weekly && $0.subjectID == nil }
    }

    func subject(for id: UUID?) -> StudySubject? {
        guard let id else { return nil }
        return subjects.first { $0.id == id }
    }

    func material(for id: UUID?) -> StudyMaterial? {
        guard let id else { return nil }
        return materials.first { $0.id == id }
    }

    func addSubject(name: String, colorHex: String) {
        subjects.append(StudySubject(name: name, colorHex: colorHex))
        save()
    }

    func addMaterial(title: String, subjectID: UUID, detail: String) {
        materials.append(StudyMaterial(title: title, subjectID: subjectID, detail: detail))
        save()
    }

    func addGoal(cadence: StudyGoal.Cadence, targetMinutes: Int, subjectID: UUID?) {
        goals.append(StudyGoal(cadence: cadence, targetMinutes: targetMinutes, subjectID: subjectID))
        save()
    }

    func addSession(subjectID: UUID, materialID: UUID?, minutes: Int, rating: Int, note: String) {
        let endedAt = Date()
        let startedAt = endedAt.addingTimeInterval(TimeInterval(-max(minutes, 1) * 60))
        sessions.append(
            StudySessionRecord(
                subjectID: subjectID,
                materialID: materialID,
                startedAt: startedAt,
                endedAt: endedAt,
                rating: min(max(rating, 1), 5),
                note: note
            )
        )
        save()
    }

    func startTimer(subjectID: UUID? = nil, materialID: UUID? = nil) {
        let fallbackSubject = subjectID ?? subjects.first?.id
        timer = StudyTimerState(startedAt: Date(), subjectID: fallbackSubject, materialID: materialID)
        save()
    }

    func stopTimer(rating: Int = 4) {
        guard let startedAt = timer.startedAt, let subjectID = timer.subjectID else { return }
        sessions.append(
            StudySessionRecord(
                subjectID: subjectID,
                materialID: timer.materialID,
                startedAt: startedAt,
                endedAt: Date(),
                rating: rating,
                note: timer.note
            )
        )
        timer = StudyTimerState()
        save()
    }

    func deleteSessions(at offsets: IndexSet) {
        let ordered = recentSessions
        let ids = offsets.map { ordered[$0].id }
        sessions.removeAll { ids.contains($0.id) }
        save()
    }

    func save() {
        let snapshot = StudySnapshot(
            subjects: subjects,
            materials: materials,
            goals: goals,
            sessions: sessions,
            timer: timer
        )
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(snapshot).write(to: fileURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save StudyAppMac data: \(error)")
        }
    }

    private static func load(from fileURL: URL) -> StudySnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(StudySnapshot.self, from: data)
    }

    private static var defaultFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appending(path: "StudyAppMac").appending(path: "study-data.json")
    }

    private static var defaultSnapshot: StudySnapshot {
        let math = StudySubject(name: "Mathematics", colorHex: "2F80ED")
        let english = StudySubject(name: "English", colorHex: "27AE60")
        let history = StudySubject(name: "History", colorHex: "C05621")
        return StudySnapshot(
            subjects: [math, english, history],
            materials: [
                StudyMaterial(title: "Algebra workbook", subjectID: math.id, detail: "Chapter review"),
                StudyMaterial(title: "Vocabulary deck", subjectID: english.id, detail: "Daily recall")
            ],
            goals: [
                StudyGoal(cadence: .daily, targetMinutes: 120, subjectID: nil),
                StudyGoal(cadence: .weekly, targetMinutes: 720, subjectID: nil)
            ],
            sessions: [],
            timer: StudyTimerState()
        )
    }
}
