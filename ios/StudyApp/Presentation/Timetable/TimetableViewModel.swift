import Combine
import Foundation

@MainActor
final class TimetableViewModel: ScreenViewModel {
    @Published private(set) var periods: [TimetablePeriod] = []
    @Published private(set) var entries: [TimetableEntry] = []

    var entriesBySlot: [TimetableSlotKey: TimetableEntry] {
        entries.reduce(into: [TimetableSlotKey: TimetableEntry]()) { result, entry in
            let key = TimetableSlotKey(day: entry.dayOfWeek, periodId: entry.periodId)
            if let existing = result[key], existing.updatedAt > entry.updatedAt {
                return
            }
            result[key] = entry
        }
    }

    func load() async {
        do {
            var loadedPeriods = try await app.persistence.getAllTimetablePeriods()
            if loadedPeriods.isEmpty {
                for period in TimetablePeriod.defaultPeriods {
                    _ = try await app.persistence.saveTimetablePeriod(period)
                }
                loadedPeriods = try await app.persistence.getAllTimetablePeriods()
                app.bumpDataVersion()
            }
            periods = loadedPeriods
            entries = try await app.persistence.getAllTimetableEntries()
        } catch {
            app.present(error)
        }
    }

    func savePeriodDrafts(_ drafts: [TimetablePeriodDraft]) {
        perform {
            for draft in drafts {
                guard draft.startMinute < draft.endMinute else {
                    throw ValidationError(message: "\(draft.name) の終了時刻は開始時刻より後にしてください")
                }
            }
            for draft in drafts {
                try await self.app.persistence.saveTimetablePeriod(draft.period)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func saveEntry(_ entry: TimetableEntry) {
        perform {
            _ = try await self.app.persistence.saveTimetableEntry(entry)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteEntry(_ entry: TimetableEntry) {
        perform {
            try await self.app.persistence.deleteTimetableEntry(entry)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

struct TimetableSlotKey: Hashable {
    var day: StudyWeekday
    var periodId: Int64
}

struct TimetablePeriodDraft: Identifiable, Hashable {
    var period: TimetablePeriod

    var id: String { period.syncId }
    var name: String { period.name }
    var startMinute: Int { period.startMinute }
    var endMinute: Int { period.endMinute }

    var startDate: Date {
        get { Self.date(from: period.startMinute) }
        set { period.startMinute = Self.minute(from: newValue) }
    }

    var endDate: Date {
        get { Self.date(from: period.endMinute) }
        set { period.endMinute = Self.minute(from: newValue) }
    }

    private static func date(from minute: Int) -> Date {
        Calendar.current.date(
            bySettingHour: minute / 60,
            minute: minute % 60,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func minute(from date: Date) -> Int {
        let calendar = Calendar.current
        return calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
    }
}
