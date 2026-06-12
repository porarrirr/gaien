import CoreData
import Foundation

/// Recomputes `actualMinutes` on the active plan's items from the current set
/// of study sessions.
///
/// Extracted from `PersistenceController.recalculatePlanActualMinutes` so the
/// logic can be unit-tested independently and reused from either the main or
/// a background `NSManagedObjectContext`.
enum PlanActualMinutesRecalculator {

    /// Refreshes `actualMinutes` for each item of the single active plan. If
    /// no active plan exists this is a no-op. The caller is responsible for
    /// saving the context afterwards.
    static func recalculate(in context: NSManagedObjectContext) throws {
        let activePlans = try CoreDataQuery.fetch(
            "StudyPlanRecord",
            in: context,
            predicate: NSPredicate(format: "isActive == YES AND deletedAt == NIL")
        )
        guard let activePlanRecord = activePlans.first else { return }
        let activePlan = PersistenceMappers.plan(activePlanRecord)

        let planItems = try CoreDataQuery.fetch(
            "PlanItemRecord",
            in: context,
            predicate: NSPredicate(format: "planId == %lld AND deletedAt == NIL", activePlan.id)
        )
        for itemRecord in planItems {
            let item = PersistenceMappers.planItem(itemRecord)
            let sessions = try CoreDataQuery.fetch(
                "StudySessionRecord",
                in: context,
                predicate: NSPredicate(
                    format: "subjectId == %lld AND startTime >= %lld AND startTime <= %lld AND deletedAt == NIL",
                    item.subjectId,
                    activePlan.startDate,
                    activePlan.endDate
                )
            ).map(PersistenceMappers.session)
            let actualMinutes = sessions
                .filter { $0.dayOfWeek == item.dayOfWeek }
                .reduce(0) { $0 + $1.durationMinutes }
            guard actualMinutes != item.actualMinutes else { continue }
            itemRecord.setValue(Int64(actualMinutes), forKey: "actualMinutes")
            itemRecord.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        }
    }
}
