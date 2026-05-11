import CoreData
import Foundation

/// Computes the number of timetable lessons whose review is overdue.
///
/// Iterates every active term, walks each day in range, and cross-references
/// entries and review records. Extracted out of `PersistenceController` so it
/// can run on a background context and avoid blocking the UI while the
/// potentially hundreds of dates × entries are scanned.
enum TimetableOverdueCalculator {

    /// Counts lessons whose scheduled end is more than 48 hours before
    /// `reference` and for which no `isReviewed` or `isExcluded` review record
    /// exists.
    static func overdueCount(
        reference: Date,
        in context: NSManagedObjectContext
    ) throws -> Int {
        let terms = try CoreDataQuery.fetch("TimetableTermRecord", in: context)
            .map(PersistenceMappers.timetableTerm)
            .filter { $0.deletedAt == nil && $0.isActive }
        let periods = try CoreDataQuery.fetch("TimetablePeriodRecord", in: context)
            .map(PersistenceMappers.timetablePeriod)
            .filter { $0.deletedAt == nil && $0.isActive }
        let entries = try CoreDataQuery.fetch("TimetableEntryRecord", in: context)
            .map(PersistenceMappers.timetableEntry)
            .filter { $0.deletedAt == nil }
        let reviews = try CoreDataQuery.fetch("TimetableReviewRecord", in: context)
            .map(PersistenceMappers.timetableReviewRecord)
            .filter { $0.deletedAt == nil }

        let periodMap = Dictionary(uniqueKeysWithValues: periods.map { ($0.id, $0) })
        let reviewMap = reviews.reduce(into: [String: TimetableReviewRecord]()) { result, review in
            let key = "\(review.termId)-\(review.entryId)-\(review.periodId)-\(review.occurrenceDate)"
            if let existing = result[key], existing.updatedAt > review.updatedAt {
                return
            }
            result[key] = review
        }
        let calendar = Calendar.current
        var overdue = 0

        for term in terms {
            var date = term.startDateValue
            let lastDate = min(term.endDateValue, reference.startOfDay)
            while date <= lastDate {
                let occurrenceDate = date.epochDay
                let weekday = StudyWeekday.from(calendarWeekday: calendar.component(.weekday, from: date))
                for entry in entries where (entry.termId == term.id || entry.termId == nil) && entry.dayOfWeek == weekday {
                    if let validFromDate = entry.validFromDate, occurrenceDate < validFromDate { continue }
                    if let validToDate = entry.validToDate, occurrenceDate > validToDate { continue }
                    guard let period = periodMap[entry.periodId] else { continue }
                    let key = "\(term.id)-\(entry.id)-\(period.id)-\(occurrenceDate)"
                    if let review = reviewMap[key], review.isReviewed || review.isExcluded {
                        continue
                    }
                    let endDate = calendar.date(
                        bySettingHour: period.endMinute / 60,
                        minute: period.endMinute % 60,
                        second: 0,
                        of: date
                    ) ?? date
                    if reference >= endDate.addingTimeInterval(48 * 60 * 60) {
                        overdue += 1
                    }
                }
                guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
                date = next
            }
        }

        return overdue
    }
}
