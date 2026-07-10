import CoreData
import Foundation

/// One-time normalizer that expands pre-schema daily goals (no `dayOfWeek`)
/// into a goal-per-weekday series so the newer scheduling pipeline can treat
/// them uniformly.
///
/// Extracted from `PersistenceController` so the legacy path has its own
/// small home and does not leak into the repository CRUD.
enum LegacyDailyGoalNormalizer {

    /// Tombstones each active `daily` goal with no `dayOfWeek` and creates
    /// seven per-day copies. Caller is responsible for saving the context.
    /// - Returns: `true` if any mutation occurred.
    @discardableResult
    static func normalize(in context: NSManagedObjectContext) throws -> Bool {
        let allRecords = try CoreDataQuery.fetch("GoalRecord", in: context)
        let activeDailyRecords = allRecords.filter {
            let goal = PersistenceMappers.goal($0)
            return goal.type == .daily && goal.isActive && goal.deletedAt == nil
        }
        let legacyRecords = activeDailyRecords.filter { PersistenceMappers.goal($0).dayOfWeek == nil }
        let namedSuffixRecords = activeDailyRecords.filter { record in
            let goal = PersistenceMappers.goal(record)
            guard let day = goal.dayOfWeek else { return false }
            return goal.syncId.hasSuffix("-\(day.rawValue.lowercased())")
        }

        guard !legacyRecords.isEmpty || !namedSuffixRecords.isEmpty else { return false }

        var nextGoalId = (allRecords
            .compactMap { $0.value(forKey: "id") as? Int64 }
            .max() ?? 0) + 1

        for record in legacyRecords {
            let baseGoal = PersistenceMappers.goal(record)
            let tombstoneAt = Date().epochMilliseconds
            record.setValue(tombstoneAt, forKey: "deletedAt")
            record.setValue(tombstoneAt, forKey: "updatedAt")

            for (index, day) in StudyWeekday.allCases.enumerated() {
                let newRecord = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: context)
                newRecord.setValue(nextGoalId, forKey: "id")
                // Android's v4→v5 migration established the cross-platform
                // wire ID as baseSyncId-1...7 (Monday...Sunday).
                newRecord.setValue("\(baseGoal.syncId)-\(index + 1)", forKey: "syncId")
                newRecord.setValue(baseGoal.type.rawValue, forKey: "type")
                newRecord.setValue(Int64(baseGoal.targetMinutes), forKey: "targetMinutes")
                newRecord.setValue(day.rawValue, forKey: "dayOfWeek")
                newRecord.setValue(baseGoal.weekStartDay.rawValue, forKey: "weekStartDay")
                newRecord.setValue(baseGoal.isActive, forKey: "isActive")
                newRecord.setValue(baseGoal.createdAt, forKey: "createdAt")
                newRecord.setValue(max(baseGoal.updatedAt, tombstoneAt), forKey: "updatedAt")
                newRecord.setValue(nil, forKey: "deletedAt")
                newRecord.setValue(baseGoal.lastSyncedAt, forKey: "lastSyncedAt")
                nextGoalId += 1
            }
        }

        // Older iOS builds used base-monday...base-sunday. Convert those
        // rows to Android's established base-1...base-7 IDs, retaining a
        // tombstone for the old ID so cloud state converges without ghosts.
        for record in namedSuffixRecords {
            let goal = PersistenceMappers.goal(record)
            guard let day = goal.dayOfWeek,
                  let dayIndex = StudyWeekday.allCases.firstIndex(of: day) else { continue }
            let suffix = "-\(day.rawValue.lowercased())"
            let baseSyncId = String(goal.syncId.dropLast(suffix.count))
            let canonicalSyncId = "\(baseSyncId)-\(dayIndex + 1)"
            let tombstoneAt = Date().epochMilliseconds
            record.setValue(tombstoneAt, forKey: "deletedAt")
            record.setValue(tombstoneAt, forKey: "updatedAt")

            let canonicalExists = allRecords.contains {
                let candidate = PersistenceMappers.goal($0)
                return candidate.syncId == canonicalSyncId && candidate.deletedAt == nil
            }
            guard !canonicalExists else { continue }

            let newRecord = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: context)
            newRecord.setValue(nextGoalId, forKey: "id")
            newRecord.setValue(canonicalSyncId, forKey: "syncId")
            newRecord.setValue(goal.type.rawValue, forKey: "type")
            newRecord.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
            newRecord.setValue(day.rawValue, forKey: "dayOfWeek")
            newRecord.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
            newRecord.setValue(goal.isActive, forKey: "isActive")
            newRecord.setValue(goal.createdAt, forKey: "createdAt")
            newRecord.setValue(max(goal.updatedAt, tombstoneAt), forKey: "updatedAt")
            newRecord.setValue(nil, forKey: "deletedAt")
            newRecord.setValue(goal.lastSyncedAt, forKey: "lastSyncedAt")
            nextGoalId += 1
        }

        return true
    }
}
