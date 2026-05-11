import CoreData
import Foundation

/// Snapshot export / JSON-round-trip import for the whole app data model.
///
/// Previously lived as ~400 lines of `PersistenceController` mixed in with the
/// per-entity CRUD methods. Separating it out lets:
///
/// 1. The full-store JSON encode and decode (the heaviest hot spot on the
///    main actor) run on a background `NSManagedObjectContext` through the
///    new executors below.
/// 2. Unit tests reach the export/replace logic without instantiating the
///    whole `PersistenceController`.
///
/// The executor functions do the Core Data work synchronously against the
/// supplied context. Callers that want off-main execution should invoke them
/// inside `context.perform { ... }`.
enum AppDataArchiver {

    // MARK: - Export

    /// Builds an `AppData` snapshot of everything persisted in `context`.
    /// Expects the caller to have already run sync-metadata backfill if
    /// required, so this is a pure read.
    static func buildExport(in context: NSManagedObjectContext) throws -> AppData {
        let subjects = try CoreDataQuery.fetch(
            "SubjectRecord",
            in: context,
            sort: [NSSortDescriptor(key: "name", ascending: true)]
        ).map(PersistenceMappers.subject)
        let materials = try CoreDataQuery.fetch(
            "MaterialRecord",
            in: context,
            sort: [NSSortDescriptor(key: "id", ascending: false)]
        ).map(PersistenceMappers.material)
        let sessions = try CoreDataQuery.fetch(
            "StudySessionRecord",
            in: context,
            sort: [NSSortDescriptor(key: "startTime", ascending: false)]
        ).map(PersistenceMappers.session)
        let goals = try CoreDataQuery.fetch(
            "GoalRecord",
            in: context,
            sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
        ).map(PersistenceMappers.goal)
        let exams = try CoreDataQuery.fetch(
            "ExamRecord",
            in: context,
            sort: [NSSortDescriptor(key: "date", ascending: true)]
        ).map(PersistenceMappers.exam)
        let plans = try CoreDataQuery.fetch(
            "StudyPlanRecord",
            in: context,
            sort: [NSSortDescriptor(key: "createdAt", ascending: false)]
        ).map(PersistenceMappers.plan)
        let timetablePeriods = try CoreDataQuery.fetch(
            "TimetablePeriodRecord",
            in: context,
            sort: [NSSortDescriptor(key: "sortOrder", ascending: true)]
        ).map(PersistenceMappers.timetablePeriod)
        let timetableEntries = try CoreDataQuery.fetch(
            "TimetableEntryRecord",
            in: context,
            sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true)]
        ).map(PersistenceMappers.timetableEntry)
        let timetableTerms = try CoreDataQuery.fetch(
            "TimetableTermRecord",
            in: context,
            sort: [NSSortDescriptor(key: "startDate", ascending: false)]
        ).map(PersistenceMappers.timetableTerm)
        let timetableReviewRecords = try CoreDataQuery.fetch(
            "TimetableReviewRecord",
            in: context,
            sort: [NSSortDescriptor(key: "occurrenceDate", ascending: false)]
        ).map(PersistenceMappers.timetableReviewRecord)
        let problemReviewRecords = try CoreDataQuery.fetch(
            "ProblemReviewRecord",
            in: context,
            sort: [NSSortDescriptor(key: "reviewedAt", ascending: false)]
        ).map(PersistenceMappers.problemReviewRecord)

        var planData = [PlanData]()
        planData.reserveCapacity(plans.count)
        for plan in plans {
            let items = try CoreDataQuery.fetch(
                "PlanItemRecord",
                in: context,
                predicate: NSPredicate(format: "planId == %lld", plan.id),
                sort: [
                    NSSortDescriptor(key: "dayOfWeek", ascending: true),
                    NSSortDescriptor(key: "targetMinutes", ascending: false)
                ]
            ).map(PersistenceMappers.planItem)
            planData.append(PlanData(plan: plan, items: items))
        }

        return AppData(
            subjects: subjects,
            materials: materials,
            sessions: sessions,
            goals: goals,
            exams: exams,
            plans: planData,
            timetablePeriods: timetablePeriods,
            timetableEntries: timetableEntries,
            timetableTerms: timetableTerms,
            timetableReviewRecords: timetableReviewRecords,
            problemReviewRecords: problemReviewRecords,
            exportDate: Date().epochMilliseconds
        )
    }

    // MARK: - CSV

    static func buildSessionsCSV(from sessions: [StudySession]) -> String {
        let dateFormatter = StudyFormatters.slashDate
        let timeFormatter = StudyFormatters.clock
        let header = "日付,科目,教材,開始時刻,終了時刻,時間(分),評価,メモ\n"
        let rows = sessions.map { session in
            [
                csvEscaped(dateFormatter.string(from: session.startDate)),
                csvEscaped(session.subjectName),
                csvEscaped(session.materialName),
                csvEscaped(timeFormatter.string(from: session.startDate)),
                csvEscaped(timeFormatter.string(from: session.endDate)),
                "\(session.durationMinutes)",
                session.rating.map { String($0) } ?? "",
                csvEscaped(session.note ?? "")
            ].joined(separator: ",")
        }
        return header + rows.joined(separator: "\n")
    }

    // MARK: - Replace (used by both JSON import and legacy snapshot import)

    /// Wipes every row in `context` (in-memory, not committed) and reinserts
    /// everything from `appData`, remapping IDs so foreign keys stay coherent
    /// and existing local data that references `syncId`s is preserved.
    ///
    /// Caller must invoke inside `context.perform { ... }` and is responsible
    /// for `try context.save()` / rollback on failure.
    static func replaceData(
        with appData: AppData,
        in context: NSManagedObjectContext
    ) throws {
        let existingSubjectIds = try CoreDataQuery.existingIdMap("SubjectRecord", in: context)
        let existingMaterialIds = try CoreDataQuery.existingIdMap("MaterialRecord", in: context)
        let existingSessionIds = try CoreDataQuery.existingIdMap("StudySessionRecord", in: context)
        let existingGoalIds = try CoreDataQuery.existingIdMap("GoalRecord", in: context)
        let existingExamIds = try CoreDataQuery.existingIdMap("ExamRecord", in: context)
        let existingPlanIds = try CoreDataQuery.existingIdMap("StudyPlanRecord", in: context)
        let existingPlanItemIds = try CoreDataQuery.existingIdMap("PlanItemRecord", in: context)
        let existingTimetablePeriodIds = try CoreDataQuery.existingIdMap("TimetablePeriodRecord", in: context)
        let existingTimetableEntryIds = try CoreDataQuery.existingIdMap("TimetableEntryRecord", in: context)
        let existingTimetableTermIds = try CoreDataQuery.existingIdMap("TimetableTermRecord", in: context)
        let existingTimetableReviewRecordIds = try CoreDataQuery.existingIdMap("TimetableReviewRecord", in: context)
        let existingProblemReviewRecordIds = try CoreDataQuery.existingIdMap("ProblemReviewRecord", in: context)
        let existingMaterialsBySyncId = try CoreDataQuery.fetch("MaterialRecord", in: context)
            .map(PersistenceMappers.material)
            .reduce(into: [String: Material]()) { result, material in
                result[material.syncId] = material
            }
        let existingSessionsBySyncId = try CoreDataQuery.fetch("StudySessionRecord", in: context)
            .map(PersistenceMappers.session)
            .reduce(into: [String: StudySession]()) { result, session in
                result[session.syncId] = session
            }

        // Delete all existing records in-memory (not yet committed)
        for entityName in CoreDataSchema.entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let records = try context.fetch(request)
            records.forEach { context.delete($0) }
        }

        let importedPlanIds = appData.plans.map { $0.plan.id }
        let importedPlanItemIds = appData.plans.flatMap { $0.items.map(\.id) }
        let importedIdCandidates: [Int64] = [
            appData.subjects.map(\.id).max() ?? 0,
            appData.materials.map(\.id).max() ?? 0,
            appData.sessions.map(\.id).max() ?? 0,
            appData.goals.map(\.id).max() ?? 0,
            appData.exams.map(\.id).max() ?? 0,
            importedPlanIds.max() ?? 0,
            importedPlanItemIds.max() ?? 0,
            appData.timetablePeriods.map(\.id).max() ?? 0,
            appData.timetableEntries.map(\.id).max() ?? 0,
            appData.timetableTerms.map(\.id).max() ?? 0,
            appData.timetableReviewRecords.map(\.id).max() ?? 0,
            appData.problemReviewRecords.map(\.id).max() ?? 0
        ]
        let maxImportedId = importedIdCandidates.max() ?? 0
        var nextId = maxImportedId + 1
        var usedIds = Set<Int64>()
        let now = Date().epochMilliseconds

        func allocateId(preferred: Int64) -> Int64 {
            if preferred > 0, !usedIds.contains(preferred) {
                usedIds.insert(preferred)
                return preferred
            }
            while nextId <= 0 || usedIds.contains(nextId) {
                nextId += 1
            }
            let allocated = nextId
            usedIds.insert(allocated)
            nextId += 1
            return allocated
        }

        // ID remap tables: syncId → freshLocalId, oldId → freshLocalId
        var subjectSyncMap: [String: Int64] = [:]
        var subjectOldMap:  [Int64: Int64]   = [:]
        var materialSyncMap: [String: Int64] = [:]
        var materialOldMap:  [Int64: Int64]   = [:]
        var planSyncMap: [String: Int64] = [:]
        var planOldMap:  [Int64: Int64]   = [:]
        var timetablePeriodSyncMap: [String: Int64] = [:]
        var timetablePeriodOldMap:  [Int64: Int64]   = [:]
        var timetableTermSyncMap: [String: Int64] = [:]
        var timetableTermOldMap:  [Int64: Int64]   = [:]
        var timetableEntrySyncMap: [String: Int64] = [:]
        var timetableEntryOldMap:  [Int64: Int64]   = [:]

        // --- Subjects ---
        for subject in appData.subjects {
            let localId = allocateId(preferred: existingSubjectIds[subject.syncId] ?? subject.id)
            subjectSyncMap[subject.syncId] = localId
            if subject.id > 0 { subjectOldMap[subject.id] = localId }

            let r = NSEntityDescription.insertNewObject(forEntityName: "SubjectRecord", into: context)
            PersistenceMappers.apply(subject, assignedId: localId, now: now, to: r)
        }

        // --- Materials ---
        for material in appData.materials {
            let localId = allocateId(preferred: existingMaterialIds[material.syncId] ?? material.id)
            let importedMaterial = preserveProblemProgress(in: material, existing: existingMaterialsBySyncId[material.syncId])
            materialSyncMap[material.syncId] = localId
            if material.id > 0 { materialOldMap[material.id] = localId }

            let subjectId: Int64 = resolveFK(
                syncId: importedMaterial.subjectSyncId, syncMap: subjectSyncMap,
                oldId: importedMaterial.subjectId, oldMap: subjectOldMap)

            let r = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: context)
            PersistenceMappers.apply(
                importedMaterial,
                assignedId: localId,
                subjectId: subjectId,
                subjectSyncId: importedMaterial.subjectSyncId,
                now: now,
                to: r
            )
        }

        // --- Sessions ---
        for session in appData.sessions {
            let localId = allocateId(preferred: existingSessionIds[session.syncId] ?? session.id)
            let importedSession = preserveProblemProgress(in: session, existing: existingSessionsBySyncId[session.syncId])

            let subjectId = resolveFK(
                syncId: importedSession.subjectSyncId, syncMap: subjectSyncMap,
                oldId: importedSession.subjectId, oldMap: subjectOldMap)
            let materialId = resolveOptFK(
                syncId: importedSession.materialSyncId, syncMap: materialSyncMap,
                oldId: importedSession.materialId, oldMap: materialOldMap)

            let r = NSEntityDescription.insertNewObject(forEntityName: "StudySessionRecord", into: context)
            PersistenceMappers.apply(
                importedSession,
                assignedId: localId,
                subjectId: subjectId,
                materialId: materialId,
                now: now,
                to: r
            )
        }

        // --- Goals ---
        for goal in appData.goals {
            let localId = allocateId(preferred: existingGoalIds[goal.syncId] ?? goal.id)
            let r = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: context)
            PersistenceMappers.apply(goal, assignedId: localId, now: now, to: r)
        }

        // --- Exams ---
        for exam in appData.exams {
            let localId = allocateId(preferred: existingExamIds[exam.syncId] ?? exam.id)
            let r = NSEntityDescription.insertNewObject(forEntityName: "ExamRecord", into: context)
            PersistenceMappers.apply(exam, assignedId: localId, now: now, to: r)
        }

        // --- Plans & PlanItems (preserve isActive as-is; no deactivation side-effects) ---
        for planData in appData.plans {
            let plan = planData.plan
            let localPlanId = allocateId(preferred: existingPlanIds[plan.syncId] ?? plan.id)
            planSyncMap[plan.syncId] = localPlanId
            if plan.id > 0 { planOldMap[plan.id] = localPlanId }

            let pr = NSEntityDescription.insertNewObject(forEntityName: "StudyPlanRecord", into: context)
            PersistenceMappers.apply(plan, assignedId: localPlanId, now: now, to: pr)

            for item in planData.items {
                let localItemId = allocateId(preferred: existingPlanItemIds[item.syncId] ?? item.id)
                let itemSubjectId = resolveFK(
                    syncId: item.subjectSyncId, syncMap: subjectSyncMap,
                    oldId: item.subjectId, oldMap: subjectOldMap)

                let ir = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: context)
                PersistenceMappers.apply(
                    item,
                    assignedId: localItemId,
                    planId: localPlanId,
                    planSyncId: item.planSyncId ?? plan.syncId,
                    subjectId: itemSubjectId,
                    now: now,
                    to: ir
                )
            }
        }

        // --- TimetablePeriods ---
        for period in appData.timetablePeriods {
            let localId = allocateId(preferred: existingTimetablePeriodIds[period.syncId] ?? period.id)
            timetablePeriodSyncMap[period.syncId] = localId
            if period.id > 0 { timetablePeriodOldMap[period.id] = localId }

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetablePeriodRecord", into: context)
            PersistenceMappers.apply(period, assignedId: localId, now: now, to: r)
        }

        // --- TimetableTerms ---
        for term in appData.timetableTerms {
            let localId = allocateId(preferred: existingTimetableTermIds[term.syncId] ?? term.id)
            timetableTermSyncMap[term.syncId] = localId
            if term.id > 0 { timetableTermOldMap[term.id] = localId }

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetableTermRecord", into: context)
            PersistenceMappers.apply(term, assignedId: localId, now: now, to: r)
        }

        // --- TimetableEntries ---
        for entry in appData.timetableEntries {
            let localId = allocateId(preferred: existingTimetableEntryIds[entry.syncId] ?? entry.id)
            timetableEntrySyncMap[entry.syncId] = localId
            if entry.id > 0 { timetableEntryOldMap[entry.id] = localId }
            let periodId = resolveFK(
                syncId: entry.periodSyncId,
                syncMap: timetablePeriodSyncMap,
                oldId: entry.periodId,
                oldMap: timetablePeriodOldMap
            )
            let termId = resolveOptFK(
                syncId: entry.termSyncId,
                syncMap: timetableTermSyncMap,
                oldId: entry.termId,
                oldMap: timetableTermOldMap
            )
            let periodSyncId = entry.periodSyncId ?? appData.timetablePeriods.first(where: { $0.id == entry.periodId })?.syncId
            let termSyncId = entry.termSyncId ?? entry.termId.flatMap { oldId in appData.timetableTerms.first(where: { $0.id == oldId })?.syncId }

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetableEntryRecord", into: context)
            PersistenceMappers.apply(entry, assignedId: localId, termId: termId, termSyncId: termSyncId, periodId: periodId, periodSyncId: periodSyncId, now: now, to: r)
        }

        // --- TimetableReviewRecords ---
        for review in appData.timetableReviewRecords {
            let localId = allocateId(preferred: existingTimetableReviewRecordIds[review.syncId] ?? review.id)
            var remapped = review
            remapped.termId = resolveFK(
                syncId: review.termSyncId,
                syncMap: timetableTermSyncMap,
                oldId: review.termId,
                oldMap: timetableTermOldMap
            )
            remapped.entryId = resolveFK(
                syncId: review.entrySyncId,
                syncMap: timetableEntrySyncMap,
                oldId: review.entryId,
                oldMap: timetableEntryOldMap
            )
            remapped.periodId = resolveFK(
                syncId: review.periodSyncId,
                syncMap: timetablePeriodSyncMap,
                oldId: review.periodId,
                oldMap: timetablePeriodOldMap
            )

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetableReviewRecord", into: context)
            PersistenceMappers.apply(remapped, assignedId: localId, now: now, to: r)
        }

        // --- ProblemReviewRecords ---
        for review in appData.problemReviewRecords {
            let localId = allocateId(preferred: existingProblemReviewRecordIds[review.syncId] ?? review.id)
            var remapped = review
            remapped.materialId = resolveFK(
                syncId: review.materialSyncId,
                syncMap: materialSyncMap,
                oldId: review.materialId,
                oldMap: materialOldMap
            )
            remapped.problemId = ProblemReviewRecord.problemId(
                materialId: remapped.materialId,
                problemNumber: remapped.problemNumber
            )

            let r = NSEntityDescription.insertNewObject(forEntityName: "ProblemReviewRecord", into: context)
            PersistenceMappers.apply(remapped, assignedId: localId, now: now, to: r)
        }
    }

    // MARK: - Legacy snapshot mapping

    /// Converts a `LegacySnapshot` decoded from the old JSON file into the
    /// structured `AppData` that `replaceData` understands.
    static func convert(legacy snapshot: LegacySnapshot) -> AppData {
        AppData(
            subjects: snapshot.subjects.map {
                Subject(id: $0.id, name: $0.name, color: $0.color, icon: $0.icon, createdAt: Date().epochMilliseconds, updatedAt: Date().epochMilliseconds)
            },
            materials: snapshot.materials.map {
                Material(
                    id: $0.id,
                    name: $0.name,
                    subjectId: $0.subjectId,
                    totalPages: $0.totalPages,
                    currentPage: $0.currentPage,
                    color: $0.color,
                    note: $0.note
                )
            },
            sessions: snapshot.sessions.map {
                StudySession(
                    id: $0.id,
                    materialId: $0.materialId,
                    materialName: $0.materialName,
                    subjectId: $0.subjectId,
                    subjectName: $0.subjectName,
                    startTime: $0.startTime.epochMilliseconds,
                    endTime: $0.endTime.epochMilliseconds,
                    note: $0.note
                )
            },
            goals: snapshot.goals.map {
                Goal(id: $0.id, type: $0.type, targetMinutes: $0.targetMinutes, dayOfWeek: $0.dayOfWeek, weekStartDay: $0.weekStartDay, isActive: $0.isActive)
            },
            exams: snapshot.exams.map {
                Exam(id: $0.id, name: $0.name, date: $0.date.epochDay, note: $0.note)
            },
            plans: snapshot.plans.map { plan in
                PlanData(
                    plan: StudyPlan(
                        id: plan.id,
                        name: plan.name,
                        startDate: plan.startDate.epochMilliseconds,
                        endDate: plan.endDate.epochMilliseconds,
                        isActive: plan.isActive,
                        createdAt: plan.createdAt.epochMilliseconds
                    ),
                    items: snapshot.planItems
                        .filter { $0.planId == plan.id }
                        .map {
                            PlanItem(
                                id: $0.id,
                                planId: $0.planId,
                                subjectId: $0.subjectId,
                                dayOfWeek: $0.dayOfWeek,
                                targetMinutes: $0.targetMinutes,
                                actualMinutes: $0.actualMinutes,
                                timeSlot: $0.timeSlot
                            )
                        }
                )
            },
            exportDate: Date().epochMilliseconds
        )
    }

    // MARK: - Private helpers

    private static func resolveFK(
        syncId: String?,
        syncMap: [String: Int64],
        oldId: Int64,
        oldMap: [Int64: Int64]
    ) -> Int64 {
        if let sid = syncId, let mapped = syncMap[sid] { return mapped }
        if let mapped = oldMap[oldId] { return mapped }
        return oldId
    }

    private static func resolveOptFK(
        syncId: String?,
        syncMap: [String: Int64],
        oldId: Int64?,
        oldMap: [Int64: Int64]
    ) -> Int64? {
        guard let oid = oldId else { return nil }
        return resolveFK(syncId: syncId, syncMap: syncMap, oldId: oid, oldMap: oldMap)
    }

    private static func preserveProblemProgress(in imported: Material, existing: Material?) -> Material {
        guard imported.deletedAt == nil, let existing else { return imported }
        var preserved = imported
        if preserved.problemChapters.isEmpty, !existing.problemChapters.isEmpty {
            preserved.problemChapters = existing.problemChapters
        }
        if preserved.problemRecords.isEmpty, !existing.problemRecords.isEmpty {
            preserved.problemRecords = existing.problemRecords
        }
        if preserved.totalProblems == 0, existing.totalProblems > 0 {
            preserved.totalProblems = existing.totalProblems
        }
        return preserved
    }

    private static func preserveProblemProgress(in imported: StudySession, existing: StudySession?) -> StudySession {
        guard imported.deletedAt == nil, let existing else { return imported }
        var preserved = imported
        if preserved.problemRecords.isEmpty, !existing.problemRecords.isEmpty {
            preserved.problemRecords = existing.problemRecords
        }
        if preserved.problemStart == nil {
            preserved.problemStart = existing.problemStart
        }
        if preserved.problemEnd == nil {
            preserved.problemEnd = existing.problemEnd
        }
        if preserved.wrongProblemCount == nil {
            preserved.wrongProblemCount = existing.wrongProblemCount
        }
        return preserved
    }

    private static func csvEscaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
