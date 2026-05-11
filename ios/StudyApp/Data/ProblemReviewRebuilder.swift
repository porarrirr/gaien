import CoreData
import Foundation

/// Rebuilds `ProblemReviewRecord` rows for a given material from its current
/// `StudySessionRecord` history.
///
/// Extracted from `PersistenceController` so the (expensive) replay over all
/// sessions for a material can be tested in isolation and shared between
/// insert/update/delete session flows.
enum ProblemReviewRebuilder {

    /// Soft-deletes existing review records for the material and reinserts a
    /// fresh series derived from every non-deleted session's `problemRecords`.
    /// - Parameters:
    ///   - materialId: Material whose reviews should be rebuilt.
    ///   - now: Epoch milliseconds to stamp onto soft-deletes and new rows.
    ///   - nextLocalId: Running identifier counter. Callers typically seed
    ///     this with `CoreDataQuery.maxIdentifier(...) + 1`.
    ///   - context: Managed object context to mutate. Caller is responsible
    ///     for saving.
    static func rebuild(
        for materialId: Int64,
        now: Int64,
        startingId nextLocalId: inout Int64,
        in context: NSManagedObjectContext
    ) throws {
        let existingReviews = try CoreDataQuery.fetch(
            "ProblemReviewRecord",
            in: context,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "materialId == %lld", materialId),
                NSPredicate(format: "deletedAt == NIL")
            ])
        )
        for review in existingReviews {
            review.setValue(now, forKey: "deletedAt")
            review.setValue(now, forKey: "updatedAt")
        }

        let sessions = try CoreDataQuery.fetch(
            "StudySessionRecord",
            in: context,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "materialId == %lld", materialId),
                NSPredicate(format: "deletedAt == NIL")
            ]),
            sort: [NSSortDescriptor(key: "startTime", ascending: true)]
        ).map(PersistenceMappers.session)

        var latestByProblem = [String: ProblemReviewRecord]()
        for session in sessions where !session.problemRecords.isEmpty {
            for problem in session.problemRecords.sorted(by: { $0.number < $1.number }) where problem.number > 0 {
                let rating: ProblemReviewRating = problem.result == .wrong ? .again : .good
                let problemId = ProblemReviewRecord.problemId(
                    materialId: materialId,
                    problemNumber: problem.number
                )
                let scheduled = ProblemReviewScheduler.schedule(
                    materialId: materialId,
                    materialSyncId: session.materialSyncId,
                    problemNumber: problem.number,
                    rating: rating,
                    reviewedAt: session.sessionEndTime,
                    previous: latestByProblem[problemId]
                )
                latestByProblem[problemId] = scheduled

                let reviewRecord = NSEntityDescription.insertNewObject(
                    forEntityName: "ProblemReviewRecord",
                    into: context
                )
                let allocated = nextLocalId
                nextLocalId += 1
                PersistenceMappers.apply(scheduled, assignedId: allocated, now: now, to: reviewRecord)
            }
        }
    }
}
