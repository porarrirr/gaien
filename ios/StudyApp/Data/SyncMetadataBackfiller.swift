import CoreData
import Foundation

/// Backfills missing `syncId` / denormalised `*SyncId` / display-name fields
/// onto Core Data records that pre-date schema version 2.
///
/// Old installations created records without these columns populated. The
/// export path needs them so a Firebase round-trip does not lose cross-device
/// identity. This logic was previously ~200 lines of ``PersistenceController``
/// and ran on the main thread before every export.
enum SyncMetadataBackfiller {

    /// Scans every entity, adds missing sync metadata in place, and returns
    /// whether any mutation happened (so the caller knows whether to save).
    @discardableResult
    static func backfill(in context: NSManagedObjectContext) throws -> Bool {
        var didChange = false

        let subjectRecords = try CoreDataQuery.fetch("SubjectRecord", in: context)
        var subjectSyncIds = [Int64: String]()
        var subjectNames = [Int64: String]()
        for record in subjectRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            let syncId = ensureSyncId(on: record, didChange: &didChange)
            subjectSyncIds[id] = syncId
            subjectNames[id] = record.value(forKey: "name") as? String ?? ""
        }

        let planRecords = try CoreDataQuery.fetch("StudyPlanRecord", in: context)
        var planSyncIds = [Int64: String]()
        for record in planRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            planSyncIds[id] = ensureSyncId(on: record, didChange: &didChange)
        }

        let materialRecords = try CoreDataQuery.fetch("MaterialRecord", in: context)
        var materialSyncIds = [Int64: String]()
        var materialNames = [Int64: String]()
        for record in materialRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            let syncId = ensureSyncId(on: record, didChange: &didChange)
            materialSyncIds[id] = syncId
            materialNames[id] = record.value(forKey: "name") as? String ?? ""
            let subjectId = record.value(forKey: "subjectId") as? Int64 ?? 0
            ensureStringValue(
                on: record,
                key: "subjectSyncId",
                value: subjectSyncIds[subjectId],
                didChange: &didChange
            )
        }

        let sessionRecords = try CoreDataQuery.fetch("StudySessionRecord", in: context)
        for record in sessionRecords {
            _ = ensureSyncId(on: record, didChange: &didChange)
            let subjectId = record.value(forKey: "subjectId") as? Int64 ?? 0
            ensureStringValue(
                on: record,
                key: "subjectSyncId",
                value: subjectSyncIds[subjectId],
                didChange: &didChange
            )
            ensureStringValue(
                on: record,
                key: "subjectName",
                value: subjectNames[subjectId],
                didChange: &didChange
            )
            if let materialId = record.value(forKey: "materialId") as? Int64 {
                ensureStringValue(
                    on: record,
                    key: "materialSyncId",
                    value: materialSyncIds[materialId],
                    didChange: &didChange
                )
                ensureStringValue(
                    on: record,
                    key: "materialName",
                    value: materialNames[materialId],
                    didChange: &didChange
                )
            }
        }

        let planItemRecords = try CoreDataQuery.fetch("PlanItemRecord", in: context)
        for record in planItemRecords {
            _ = ensureSyncId(on: record, didChange: &didChange)
            let planId = record.value(forKey: "planId") as? Int64 ?? 0
            let subjectId = record.value(forKey: "subjectId") as? Int64 ?? 0
            ensureStringValue(
                on: record,
                key: "planSyncId",
                value: planSyncIds[planId],
                didChange: &didChange
            )
            ensureStringValue(
                on: record,
                key: "subjectSyncId",
                value: subjectSyncIds[subjectId],
                didChange: &didChange
            )
        }

        let timetablePeriodRecords = try CoreDataQuery.fetch("TimetablePeriodRecord", in: context)
        var timetablePeriodSyncIds = [Int64: String]()
        for record in timetablePeriodRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            timetablePeriodSyncIds[id] = ensureSyncId(on: record, didChange: &didChange)
        }

        let timetableTermRecords = try CoreDataQuery.fetch("TimetableTermRecord", in: context)
        var timetableTermSyncIds = [Int64: String]()
        for record in timetableTermRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            timetableTermSyncIds[id] = ensureSyncId(on: record, didChange: &didChange)
        }

        let timetableEntryRecords = try CoreDataQuery.fetch("TimetableEntryRecord", in: context)
        var timetableEntrySyncIds = [Int64: String]()
        for record in timetableEntryRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            timetableEntrySyncIds[id] = ensureSyncId(on: record, didChange: &didChange)
            let periodId = record.value(forKey: "periodId") as? Int64 ?? 0
            ensureStringValue(
                on: record,
                key: "periodSyncId",
                value: timetablePeriodSyncIds[periodId],
                didChange: &didChange
            )
            if let termId = record.value(forKey: "termId") as? Int64 {
                ensureStringValue(
                    on: record,
                    key: "termSyncId",
                    value: timetableTermSyncIds[termId],
                    didChange: &didChange
                )
            }
        }

        let timetableReviewRecords = try CoreDataQuery.fetch("TimetableReviewRecord", in: context)
        for record in timetableReviewRecords {
            _ = ensureSyncId(on: record, didChange: &didChange)
            let termId = record.value(forKey: "termId") as? Int64 ?? 0
            let entryId = record.value(forKey: "entryId") as? Int64 ?? 0
            let periodId = record.value(forKey: "periodId") as? Int64 ?? 0
            ensureStringValue(on: record, key: "termSyncId", value: timetableTermSyncIds[termId], didChange: &didChange)
            ensureStringValue(on: record, key: "entrySyncId", value: timetableEntrySyncIds[entryId], didChange: &didChange)
            ensureStringValue(on: record, key: "periodSyncId", value: timetablePeriodSyncIds[periodId], didChange: &didChange)
        }

        let problemReviewRecords = try CoreDataQuery.fetch("ProblemReviewRecord", in: context)
        for record in problemReviewRecords {
            _ = ensureSyncId(on: record, didChange: &didChange)
            let materialId = record.value(forKey: "materialId") as? Int64 ?? 0
            let problemNumber = Int(record.value(forKey: "problemNumber") as? Int64 ?? 0)
            ensureStringValue(
                on: record,
                key: "materialSyncId",
                value: materialSyncIds[materialId],
                didChange: &didChange
            )
            ensureStringValue(
                on: record,
                key: "problemId",
                value: ProblemReviewRecord.problemId(materialId: materialId, problemNumber: problemNumber),
                didChange: &didChange
            )
        }

        for entity in ["GoalRecord", "ExamRecord"] {
            let records = try CoreDataQuery.fetch(entity, in: context)
            for record in records {
                _ = ensureSyncId(on: record, didChange: &didChange)
            }
        }

        return didChange
    }

    @discardableResult
    private static func ensureSyncId(on record: NSManagedObject, didChange: inout Bool) -> String {
        if let existing = record.value(forKey: "syncId") as? String, !existing.isEmpty {
            return existing
        }
        let syncId = UUID().uuidString.lowercased()
        record.setValue(syncId, forKey: "syncId")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        didChange = true
        return syncId
    }

    private static func ensureStringValue(
        on record: NSManagedObject,
        key: String,
        value: String?,
        didChange: inout Bool
    ) {
        guard let value, !value.isEmpty else { return }
        if let existing = record.value(forKey: key) as? String, !existing.isEmpty {
            return
        }
        record.setValue(value, forKey: key)
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        didChange = true
    }
}
