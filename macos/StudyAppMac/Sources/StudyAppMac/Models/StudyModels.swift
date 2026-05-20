import Foundation
import SwiftUI

struct StudySubject: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var colorHex: String

    var color: Color {
        Color(hex: colorHex)
    }
}

struct StudyMaterial: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var title: String
    var subjectID: UUID
    var detail: String = ""
}

struct StudyGoal: Identifiable, Codable, Hashable {
    enum Cadence: String, CaseIterable, Codable, Identifiable {
        case daily
        case weekly

        var id: String { rawValue }

        var title: String {
            switch self {
            case .daily: "Daily"
            case .weekly: "Weekly"
            }
        }
    }

    var id: UUID = UUID()
    var cadence: Cadence
    var targetMinutes: Int
    var subjectID: UUID?
    var isActive: Bool = true
}

struct StudySessionRecord: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var subjectID: UUID
    var materialID: UUID?
    var startedAt: Date
    var endedAt: Date
    var rating: Int
    var note: String = ""

    var durationMinutes: Int {
        max(Int(endedAt.timeIntervalSince(startedAt) / 60), 1)
    }
}

struct StudyTimerState: Codable, Hashable {
    var startedAt: Date?
    var subjectID: UUID?
    var materialID: UUID?
    var note: String = ""

    var isRunning: Bool {
        startedAt != nil
    }

    var elapsed: TimeInterval {
        guard let startedAt else { return 0 }
        return Date().timeIntervalSince(startedAt)
    }
}

struct StudySnapshot: Codable {
    var subjects: [StudySubject]
    var materials: [StudyMaterial]
    var goals: [StudyGoal]
    var sessions: [StudySessionRecord]
    var timer: StudyTimerState
}
