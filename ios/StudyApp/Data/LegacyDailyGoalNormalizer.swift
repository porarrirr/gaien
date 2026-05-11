import CoreData
import Foundation

/// One-time normalizer that expands pre-schema daily goals (no `dayOfWeek`)
/// into a goal-per-weekday series so the newer scheduling pipeline can treat
/// them uniformly.
///
/// Extracted from `PersistenceController` so the legacy path has its own
/// small home and does not leak into the repository CRUD.
enum LegacyDailyGoalNormalizer {

    /// Replaces each active `daily` goal with no `dayOfWeek` by seven per-day
    /// copies. Caller is responsible for saving the context.
    /// - Returns: `true` if any mutation occurred.
    @discardableResult
    static func normalize(in context: NSManagedObjectContext) throws -> Bool {
        let legacyRecords = try CoreDataQuery.fetch(
            "GoalRecord",
            in: context,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "type == %@", GoalType.daily.rawValue),
                NSPredicate(format: "isActive == YES"),
                NSPredicate(format: "deletedAt == NIL"),
                NSPredicate(format: "dayOfWeek == NIL")
            ])
        )

        guard !legacyRecords.isEmpty else { return false }

        var nextGoalId = (try CoreDataQuery.fetch("GoalRecord", in: context)
            .compactMap { $0.value(forKey: "id") as? Int64 }
            .max() ?? 0) + 1

        for record in legacyRecords {
            let baseGoal = PersistenceMappers.goal(record)
            context.delete(record)

            for day in StudyWeekday.allCases {
                let newRecord = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: context)
                newRecord.setValue(nextGoalId, forKey: "id")
                newRecord.setValue("\(baseGoal.syncId)-\(day.rawValue.lowercased())", forKey: "syncId")
                newRecord.setValue(baseGoal.type.rawValue, forKey: "type")
                newRecord.setValue(Int64(baseGoal.targetMinutes), forKey: "targetMinutes")
                newRecord.setValue(day.rawValue, forKey: "dayOfWeek")
                newRecord.setValue(baseGoal.weekStartDay.rawValue, forKey: "weekStartDay")
                newRecord.setValue(baseGoal.isActive, forKey: "isActive")
                newRecord.setValue(baseGoal.createdAt, forKey: "createdAt")
                newRecord.setValue(baseGoal.updatedAt, forKey: "updatedAt")
                newRecord.setValue(baseGoal.deletedAt, forKey: "deletedAt")
                newRecord.setValue(baseGoal.lastSyncedAt, forKey: "lastSyncedAt")
                nextGoalId += 1
            }
        }

        return true
    }
}
