import CoreData
import Foundation

@MainActor
final class PersistenceController: SubjectRepository, MaterialRepository, StudySessionRepository, GoalRepository, ExamRepository, PlanRepository, TimetableRepository, ProblemReviewRepository, AppDataRepository {
    static let shared = PersistenceController()

    private let container: NSPersistentContainer
    private let fileManager: FileManager
    private let loadTask: Task<Void, Error>
    private let legacyURL: URL
    private(set) var changeToken: Int64 = 0
    private var didNormalizeLegacyDailyGoals = false

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.legacyURL = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory)
            .appendingPathComponent("studyapp-store.json")

        let model = Self.makeManagedObjectModel()
        let persistentContainer = NSPersistentContainer(name: "StudyAppStore", managedObjectModel: model)
        let storeURL = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory)
            .appendingPathComponent("StudyApp.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        description.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject,
                              forKey: NSPersistentStoreFileProtectionKey)
        persistentContainer.persistentStoreDescriptions = [description]
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.container = persistentContainer

        loadTask = Task {
            try await withCheckedThrowingContinuation { continuation in
                persistentContainer.loadPersistentStores { _, error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
        }
    }

    func migrateLegacySnapshotIfNeeded(preferencesRepository: AppPreferencesRepository) async throws {
        try await ensureLoaded()
        guard try await isEmptyStore(), fileManager.fileExists(atPath: legacyURL.path) else {
            return
        }

        let data = try Data(contentsOf: legacyURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let snapshot = try decoder.decode(LegacySnapshot.self, from: data)
        try await importLegacySnapshot(snapshot)
        preferencesRepository.savePreferences(snapshot.preferences)

        let migratedURL = legacyURL.deletingPathExtension().appendingPathExtension("json.migrated")
        do {
            if fileManager.fileExists(atPath: migratedURL.path) {
                try fileManager.removeItem(at: migratedURL)
            }
            try fileManager.moveItem(at: legacyURL, to: migratedURL)
        } catch {
            print("[StudyApp] Failed to move legacy file after migration: \(error.localizedDescription)")
        }
    }

    func getAllSubjects() async throws -> [Subject] {
        try await ensureLoaded()
        return try fetch(entity: "SubjectRecord", sort: [NSSortDescriptor(key: "name", ascending: true)]).map(Self.subject).filter { $0.deletedAt == nil }
    }

    func getSubjectById(_ id: Int64) async throws -> Subject? {
        try await ensureLoaded()
        return try fetchOne(entity: "SubjectRecord", id: id).map(Self.subject)
    }

    func insertSubject(_ subject: Subject) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: subject.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "SubjectRecord", into: container.viewContext)
        Self.apply(subject, assignedId: id, now: now, to: record)
        try saveContext()
        return id
    }

    func updateSubject(_ subject: Subject) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "SubjectRecord", id: subject.id) else { return }
        let subjectSyncId = record.value(forKey: "syncId") as? String ?? subject.syncId
        if (record.value(forKey: "syncId") as? String)?.isEmpty != false {
            record.setValue(subjectSyncId, forKey: "syncId")
        }
        record.setValue(subject.name, forKey: "name")
        record.setValue(Int64(subject.color), forKey: "color")
        record.setValue(subject.icon?.rawValue, forKey: "icon")
        record.setValue(subject.deletedAt, forKey: "deletedAt")
        record.setValue(subject.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")

        let sessions = try fetch(entity: "StudySessionRecord", predicate: NSPredicate(format: "subjectId == %lld", subject.id))
        for session in sessions {
            session.setValue(subjectSyncId, forKey: "subjectSyncId")
            session.setValue(subject.name, forKey: "subjectName")
            session.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        }
        try saveContext()
    }

    func deleteSubject(_ subject: Subject) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        let relatedMaterials = try fetch(entity: "MaterialRecord", predicate: NSPredicate(format: "subjectId == %lld", subject.id))
        let materialIds = relatedMaterials.compactMap { $0.value(forKey: "id") as? Int64 }

        let sessionPredicate: NSPredicate
        if materialIds.isEmpty {
            sessionPredicate = NSPredicate(format: "subjectId == %lld", subject.id)
        } else {
            sessionPredicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
                NSPredicate(format: "subjectId == %lld", subject.id),
                NSPredicate(format: "materialId IN %@", materialIds.map { NSNumber(value: $0) })
            ])
        }
        let sessions = try fetch(entity: "StudySessionRecord", predicate: sessionPredicate)
        let planItems = try fetch(entity: "PlanItemRecord", predicate: NSPredicate(format: "subjectId == %lld", subject.id))
        let problemReviewRecords = materialIds.isEmpty ? [] : try fetch(
            entity: "ProblemReviewRecord",
            predicate: NSPredicate(format: "materialId IN %@ AND deletedAt == NIL", materialIds.map { NSNumber(value: $0) })
        )

        for material in relatedMaterials {
            material.setValue(now, forKey: "deletedAt")
            material.setValue(now, forKey: "updatedAt")
        }
        for session in sessions {
            session.setValue(now, forKey: "deletedAt")
            session.setValue(now, forKey: "updatedAt")
        }
        for item in planItems {
            item.setValue(now, forKey: "deletedAt")
            item.setValue(now, forKey: "updatedAt")
        }
        for review in problemReviewRecords {
            review.setValue(now, forKey: "deletedAt")
            review.setValue(now, forKey: "updatedAt")
        }
        if let record = try fetchOne(entity: "SubjectRecord", id: subject.id) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
        }
        try saveContext()
    }

    func getAllMaterials() async throws -> [Material] {
        try await ensureLoaded()
        return try fetch(
            entity: "MaterialRecord",
            sort: [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
        ).map(Self.material).filter { $0.deletedAt == nil }
    }

    func getMaterialsBySubjectId(_ subjectId: Int64) async throws -> [Material] {
        try await ensureLoaded()
        return try fetch(
            entity: "MaterialRecord",
            predicate: NSPredicate(format: "subjectId == %lld", subjectId),
            sort: [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
        ).map(Self.material).filter { $0.deletedAt == nil }
    }

    func insertMaterial(_ material: Material) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: material.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: container.viewContext)
        Self.apply(
            material,
            assignedId: id,
            subjectId: material.subjectId,
            subjectSyncId: material.subjectSyncId,
            now: now,
            to: record
        )
        try saveContext()
        return id
    }

    func updateMaterial(_ material: Material) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "MaterialRecord", id: material.id) else { return }
        let subject = try await getSubjectById(material.subjectId)
        let subjectName = subject?.name ?? ""
        let subjectSyncId = material.subjectSyncId ?? subject?.syncId
        let materialSyncId = record.value(forKey: "syncId") as? String
        if (record.value(forKey: "syncId") as? String)?.isEmpty != false {
            record.setValue(material.syncId, forKey: "syncId")
        }
        record.setValue(material.name, forKey: "name")
        record.setValue(material.subjectId, forKey: "subjectId")
        record.setValue(subjectSyncId, forKey: "subjectSyncId")
        record.setValue(material.sortOrder, forKey: "sortOrder")
        record.setValue(Int64(material.totalPages), forKey: "totalPages")
        record.setValue(Int64(material.currentPage), forKey: "currentPage")
        record.setValue(Int64(material.totalProblems), forKey: "totalProblems")
        record.setValue(Self.encodeProblemChapters(material.problemChapters), forKey: "problemChaptersData")
        record.setValue(Self.encodeProblemRecords(material.problemRecords), forKey: "problemRecordsData")
        record.setValue(material.color.map { Int64($0) }, forKey: "color")
        record.setValue(material.note, forKey: "note")
        record.setValue(material.deletedAt, forKey: "deletedAt")
        record.setValue(material.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")

        let sessions = try fetch(entity: "StudySessionRecord", predicate: NSPredicate(format: "materialId == %lld", material.id))
        for session in sessions {
            session.setValue(materialSyncId, forKey: "materialSyncId")
            session.setValue(material.name, forKey: "materialName")
            session.setValue(material.subjectId, forKey: "subjectId")
            session.setValue(subjectSyncId, forKey: "subjectSyncId")
            session.setValue(subjectName, forKey: "subjectName")
            session.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        }
        try saveContext()
    }

    func deleteMaterial(_ material: Material) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try fetchOne(entity: "MaterialRecord", id: material.id) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
        }
        let sessions = try fetch(entity: "StudySessionRecord", predicate: NSPredicate(format: "materialId == %lld", material.id))
        for session in sessions {
            session.setValue(now, forKey: "deletedAt")
            session.setValue(now, forKey: "updatedAt")
        }
        let problemReviewRecords = try fetch(
            entity: "ProblemReviewRecord",
            predicate: NSPredicate(format: "materialId == %lld AND deletedAt == NIL", material.id)
        )
        for review in problemReviewRecords {
            review.setValue(now, forKey: "deletedAt")
            review.setValue(now, forKey: "updatedAt")
        }
        try saveContext()
    }

    func getAllSessions() async throws -> [StudySession] {
        try await ensureLoaded()
        return try fetch(entity: "StudySessionRecord", sort: [NSSortDescriptor(key: "startTime", ascending: false)]).map(Self.session).filter { $0.deletedAt == nil }
    }

    func getSessionsBetweenDates(start: Int64, end: Int64) async throws -> [StudySession] {
        try await ensureLoaded()
        return try fetch(
            entity: "StudySessionRecord",
            predicate: NSPredicate(format: "startTime >= %lld AND startTime < %lld", start, end),
            sort: [NSSortDescriptor(key: "startTime", ascending: false)]
        ).map(Self.session).filter { $0.deletedAt == nil }
    }

    func insertSession(_ session: StudySession) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: session.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "StudySessionRecord", into: container.viewContext)
        let sanitized = sanitize(session: session, assignedId: id)
        apply(sanitized, to: record)
        try saveContext()
        try await recalculatePlanActualMinutes()
        return id
    }

    func insertSessionWithProblemReviews(_ session: StudySession) async throws -> Int64 {
        try await ensureLoaded()
        let ctx = container.viewContext
        let now = Date().epochMilliseconds
        var nextLocalId = try maxIdentifier() + 1

        func allocateId(_ requested: Int64) -> Int64 {
            if requested > 0 {
                nextLocalId = max(nextLocalId, requested + 1)
                return requested
            }
            defer { nextLocalId += 1 }
            return nextLocalId
        }

        let sessionId = allocateId(session.id)
        let sanitized = sanitize(session: session, assignedId: sessionId)

        let record = NSEntityDescription.insertNewObject(forEntityName: "StudySessionRecord", into: ctx)
        apply(sanitized, to: record)
        if let materialId = sanitized.materialId {
            try rebuildProblemReviewRecords(for: materialId, now: now, startingId: &nextLocalId)
        }

        do {
            try saveContext()
        } catch {
            ctx.rollback()
            throw error
        }

        try await recalculatePlanActualMinutes()
        return sessionId
    }

    func updateSession(_ session: StudySession) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "StudySessionRecord", id: session.id) else { return }
        let oldMaterialId = record.value(forKey: "materialId") as? Int64
        var nextLocalId = try maxIdentifier() + 1
        let now = Date().epochMilliseconds
        let sanitized = sanitize(
            session: session,
            assignedId: session.id,
            persistedSyncId: record.value(forKey: "syncId") as? String,
            persistedCreatedAt: record.value(forKey: "createdAt") as? Int64,
            persistedLastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
        apply(sanitized, to: record)
        var materialIdsToRebuild = Set<Int64>()
        if let oldMaterialId {
            materialIdsToRebuild.insert(oldMaterialId)
        }
        if let materialId = sanitized.materialId {
            materialIdsToRebuild.insert(materialId)
        }
        for materialId in materialIdsToRebuild {
            try rebuildProblemReviewRecords(for: materialId, now: now, startingId: &nextLocalId)
        }
        try saveContext()
        try await recalculatePlanActualMinutes()
    }

    func deleteSession(_ session: StudySession) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "StudySessionRecord", id: session.id) {
            let now = Date().epochMilliseconds
            let materialId = record.value(forKey: "materialId") as? Int64
            var nextLocalId = try maxIdentifier() + 1
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            if let materialId {
                try rebuildProblemReviewRecords(for: materialId, now: now, startingId: &nextLocalId)
            }
            try saveContext()
            try await recalculatePlanActualMinutes()
        }
    }

    func getAllGoals() async throws -> [Goal] {
        try await ensureLoaded()
        return try fetch(entity: "GoalRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: true)]).map(Self.goal).filter { $0.deletedAt == nil }
    }

    func getActiveGoalByType(_ type: GoalType) async throws -> Goal? {
        try await ensureLoaded()
        let predicate = NSPredicate(format: "type == %@ AND isActive == YES AND dayOfWeek == NIL", type.rawValue)
        return try fetch(entity: "GoalRecord", predicate: predicate, sort: [NSSortDescriptor(key: "updatedAt", ascending: false)]).map(Self.goal).first(where: { $0.deletedAt == nil })
    }

    func insertGoal(_ goal: Goal) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: goal.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: container.viewContext)
        Self.apply(goal, assignedId: id, now: now, to: record)
        try saveContext()
        return id
    }

    func updateGoal(_ goal: Goal) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "GoalRecord", id: goal.id) else { return }
        record.setValue(goal.type.rawValue, forKey: "type")
        record.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
        record.setValue(goal.dayOfWeek?.rawValue, forKey: "dayOfWeek")
        record.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
        record.setValue(goal.isActive, forKey: "isActive")
        record.setValue(goal.deletedAt, forKey: "deletedAt")
        record.setValue(goal.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveContext()
    }

    func deleteGoal(_ goal: Goal) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "GoalRecord", id: goal.id) {
            let now = Date().epochMilliseconds
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            try saveContext()
        }
    }

    func getAllExams() async throws -> [Exam] {
        try await ensureLoaded()
        return try fetch(entity: "ExamRecord", sort: [NSSortDescriptor(key: "date", ascending: true)]).map(Self.exam).filter { $0.deletedAt == nil }
    }

    func getUpcomingExams(now: Date) async throws -> [Exam] {
        try await ensureLoaded()
        let currentDay = now.epochDay
        return try fetch(
            entity: "ExamRecord",
            predicate: NSPredicate(format: "date >= %lld", currentDay),
            sort: [NSSortDescriptor(key: "date", ascending: true)]
        ).map(Self.exam).filter { $0.deletedAt == nil }
    }

    func insertExam(_ exam: Exam) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: exam.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "ExamRecord", into: container.viewContext)
        Self.apply(exam, assignedId: id, now: now, to: record)
        try saveContext()
        return id
    }

    func updateExam(_ exam: Exam) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "ExamRecord", id: exam.id) else { return }
        record.setValue(exam.name, forKey: "name")
        record.setValue(exam.date, forKey: "date")
        record.setValue(exam.note, forKey: "note")
        record.setValue(exam.deletedAt, forKey: "deletedAt")
        record.setValue(exam.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveContext()
    }

    func deleteExam(_ exam: Exam) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "ExamRecord", id: exam.id) {
            let now = Date().epochMilliseconds
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            try saveContext()
        }
    }

    func getAllPlans() async throws -> [StudyPlan] {
        try await ensureLoaded()
        return try fetch(entity: "StudyPlanRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: false)]).map(Self.plan).filter { $0.deletedAt == nil }
    }

    func getPlanItems(planId: Int64) async throws -> [PlanItem] {
        try await ensureLoaded()
        return try fetch(
            entity: "PlanItemRecord",
            predicate: NSPredicate(format: "planId == %lld", planId),
            sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true), NSSortDescriptor(key: "targetMinutes", ascending: false)]
        ).map(Self.planItem).filter { $0.deletedAt == nil }
    }

    func createPlan(_ plan: StudyPlan, items: [PlanItem]) async throws -> Int64 {
        try await ensureLoaded()
        let activePlans = try fetch(entity: "StudyPlanRecord", predicate: NSPredicate(format: "isActive == YES"))
        for record in activePlans {
            record.setValue(false, forKey: "isActive")
        }

        let planId = try nextIdentifier(ifNeeded: plan.id)
        var nextLocalId = planId + 1
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "StudyPlanRecord", into: container.viewContext)
        Self.apply(plan, assignedId: planId, now: now, to: record)

        for item in items {
            let itemRecord = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: container.viewContext)
            let itemId = item.id > 0 ? item.id : nextLocalId
            if item.id == 0 {
                nextLocalId += 1
            }
            Self.apply(
                item,
                assignedId: itemId,
                planId: planId,
                planSyncId: item.planSyncId ?? plan.syncId,
                subjectId: item.subjectId,
                now: now,
                to: itemRecord
            )
        }

        try saveContext()
        try await recalculatePlanActualMinutes()
        return planId
    }

    func insertPlanItem(_ item: PlanItem) async throws -> Int64 {
        try await ensureLoaded()
        let itemId = try nextIdentifier(ifNeeded: item.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: container.viewContext)
        Self.apply(
            item,
            assignedId: itemId,
            planId: item.planId,
            planSyncId: item.planSyncId,
            subjectId: item.subjectId,
            now: now,
            to: record
        )
        try saveContext()
        try await recalculatePlanActualMinutes()
        return itemId
    }

    func updatePlanItem(_ item: PlanItem) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "PlanItemRecord", id: item.id) else { return }
        if let planSyncId = item.planSyncId {
            record.setValue(planSyncId, forKey: "planSyncId")
        }
        record.setValue(item.subjectId, forKey: "subjectId")
        record.setValue(item.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
        record.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
        record.setValue(item.timeSlot, forKey: "timeSlot")
        record.setValue(item.deletedAt, forKey: "deletedAt")
        record.setValue(item.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveContext()
        try await recalculatePlanActualMinutes()
    }

    func deletePlanItem(_ item: PlanItem) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "PlanItemRecord", id: item.id) {
            let now = Date().epochMilliseconds
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            try saveContext()
            try await recalculatePlanActualMinutes()
        }
    }

    func deletePlan(_ plan: StudyPlan) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try fetchOne(entity: "StudyPlanRecord", id: plan.id) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            record.setValue(false, forKey: "isActive")
        }
        let items = try fetch(entity: "PlanItemRecord", predicate: NSPredicate(format: "planId == %lld", plan.id))
        for item in items {
            item.setValue(now, forKey: "deletedAt")
            item.setValue(now, forKey: "updatedAt")
        }
        try saveContext()
    }

    func getAllTimetablePeriods() async throws -> [TimetablePeriod] {
        try await ensureLoaded()
        return try fetch(
            entity: "TimetablePeriodRecord",
            sort: [NSSortDescriptor(key: "sortOrder", ascending: true), NSSortDescriptor(key: "startMinute", ascending: true)]
        ).map(Self.timetablePeriod).filter { $0.deletedAt == nil && $0.isActive }
    }

    func saveTimetablePeriod(_ period: TimetablePeriod) async throws -> Int64 {
        try await ensureLoaded()
        guard period.startMinute < period.endMinute else {
            throw ValidationError(message: "終了時刻は開始時刻より後にしてください")
        }
        let now = Date().epochMilliseconds
        if period.id > 0, let record = try fetchOne(entity: "TimetablePeriodRecord", id: period.id) {
            var updated = period
            updated.syncId = (record.value(forKey: "syncId") as? String)?.nilIfBlank ?? period.syncId
            updated.createdAt = record.value(forKey: "createdAt") as? Int64 ?? period.createdAt
            updated.updatedAt = now
            Self.apply(updated, assignedId: period.id, now: now, to: record)
            try saveContext()
            return period.id
        }

        let id = try nextIdentifier(ifNeeded: period.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "TimetablePeriodRecord", into: container.viewContext)
        Self.apply(period, assignedId: id, now: now, to: record)
        try saveContext()
        return id
    }

    func deleteTimetablePeriod(_ period: TimetablePeriod) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try fetchOne(entity: "TimetablePeriodRecord", id: period.id) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
        }
        let entries = try fetch(entity: "TimetableEntryRecord", predicate: NSPredicate(format: "periodId == %lld", period.id))
        for entry in entries {
            entry.setValue(now, forKey: "deletedAt")
            entry.setValue(now, forKey: "updatedAt")
        }
        try saveContext()
    }

    func getAllTimetableTerms() async throws -> [TimetableTerm] {
        try await ensureLoaded()
        return try fetch(
            entity: "TimetableTermRecord",
            sort: [NSSortDescriptor(key: "startDate", ascending: false), NSSortDescriptor(key: "endDate", ascending: false)]
        ).map(Self.timetableTerm).filter { $0.deletedAt == nil && $0.isActive }
    }

    func saveTimetableTerm(_ term: TimetableTerm) async throws -> Int64 {
        try await ensureLoaded()
        let name = term.name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            throw ValidationError(message: "学期名を入力してください")
        }
        guard term.startDate <= term.endDate else {
            throw ValidationError(message: "学期の終了日は開始日以降にしてください")
        }

        let now = Date().epochMilliseconds
        if term.id > 0, let record = try fetchOne(entity: "TimetableTermRecord", id: term.id) {
            var updated = term
            updated.syncId = (record.value(forKey: "syncId") as? String)?.nilIfBlank ?? term.syncId
            updated.name = name
            updated.createdAt = record.value(forKey: "createdAt") as? Int64 ?? term.createdAt
            updated.updatedAt = now
            Self.apply(updated, assignedId: term.id, now: now, to: record)
            try saveContext()
            return term.id
        }

        var inserted = term
        inserted.name = name
        let id = try nextIdentifier(ifNeeded: term.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "TimetableTermRecord", into: container.viewContext)
        Self.apply(inserted, assignedId: id, now: now, to: record)
        try saveContext()
        return id
    }

    func deleteTimetableTerm(_ term: TimetableTerm) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try fetchOne(entity: "TimetableTermRecord", id: term.id) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            record.setValue(false, forKey: "isActive")
        }
        let entries = try fetch(entity: "TimetableEntryRecord", predicate: NSPredicate(format: "termId == %lld", term.id))
        for entry in entries {
            entry.setValue(now, forKey: "deletedAt")
            entry.setValue(now, forKey: "updatedAt")
        }
        try saveContext()
    }

    func getAllTimetableEntries() async throws -> [TimetableEntry] {
        try await ensureLoaded()
        return try fetch(
            entity: "TimetableEntryRecord",
            sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true), NSSortDescriptor(key: "periodId", ascending: true)]
        ).map(Self.timetableEntry).filter { $0.deletedAt == nil }
    }

    func saveTimetableEntry(_ entry: TimetableEntry) async throws -> Int64 {
        try await ensureLoaded()
        let subjectName = entry.subjectName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !subjectName.isEmpty else {
            throw ValidationError(message: "科目名を入力してください")
        }
        guard StudyWeekday.timetableDays.contains(entry.dayOfWeek) else {
            throw ValidationError(message: "時間割は月曜から土曜の範囲で設定してください")
        }
        guard let period = try fetchOne(entity: "TimetablePeriodRecord", id: entry.periodId).map(Self.timetablePeriod),
              period.deletedAt == nil,
              period.isActive else {
            throw ValidationError(message: "有効な時限を選択してください")
        }
        let resolvedTermSyncId: String?
        if let termId = entry.termId {
            guard let term = try fetchOne(entity: "TimetableTermRecord", id: termId).map(Self.timetableTerm),
                  term.deletedAt == nil,
                  term.isActive else {
                throw ValidationError(message: "有効な学期を選択してください")
            }
            resolvedTermSyncId = term.syncId
        } else {
            resolvedTermSyncId = nil
        }

        let now = Date().epochMilliseconds
        let existing = try fetch(
            entity: "TimetableEntryRecord",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "termId == %lld", entry.termId ?? 0),
                NSPredicate(format: "dayOfWeek == %@", entry.dayOfWeek.rawValue),
                NSPredicate(format: "periodId == %lld", entry.periodId),
                NSPredicate(format: "validToDate == NIL"),
                NSPredicate(format: "deletedAt == NIL")
            ])
        ).first

        let currentRecord: NSManagedObject?
        if let existing {
            currentRecord = existing
        } else if entry.id > 0 {
            currentRecord = try fetchOne(entity: "TimetableEntryRecord", id: entry.id)
        } else {
            currentRecord = nil
        }

        if let record = currentRecord {
            let assignedId = record.value(forKey: "id") as? Int64 ?? entry.id
            var updated = entry
            updated.syncId = (record.value(forKey: "syncId") as? String)?.nilIfBlank ?? entry.syncId
            updated.periodSyncId = period.syncId
            updated.termSyncId = resolvedTermSyncId
            updated.subjectName = subjectName
            updated.courseName = entry.courseName?.nilIfBlank
            updated.roomName = entry.roomName?.nilIfBlank
            updated.createdAt = record.value(forKey: "createdAt") as? Int64 ?? entry.createdAt
            updated.updatedAt = now
            Self.apply(updated, assignedId: assignedId, termId: entry.termId, termSyncId: updated.termSyncId, periodId: period.id, periodSyncId: period.syncId, now: now, to: record)
            try saveContext()
            return assignedId
        }

        var inserted = entry
        inserted.subjectName = subjectName
        inserted.courseName = entry.courseName?.nilIfBlank
        inserted.roomName = entry.roomName?.nilIfBlank
        inserted.periodSyncId = period.syncId
        inserted.termSyncId = resolvedTermSyncId
        let id = try nextIdentifier(ifNeeded: entry.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "TimetableEntryRecord", into: container.viewContext)
        Self.apply(inserted, assignedId: id, termId: entry.termId, termSyncId: inserted.termSyncId, periodId: period.id, periodSyncId: period.syncId, now: now, to: record)
        try saveContext()
        return id
    }

    func deleteTimetableEntry(_ entry: TimetableEntry) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "TimetableEntryRecord", id: entry.id) else { return }
        let now = Date().epochMilliseconds
        record.setValue(now, forKey: "deletedAt")
        record.setValue(now, forKey: "updatedAt")
        try saveContext()
    }

    func getAllTimetableReviewRecords() async throws -> [TimetableReviewRecord] {
        try await ensureLoaded()
        return try fetch(
            entity: "TimetableReviewRecord",
            sort: [NSSortDescriptor(key: "occurrenceDate", ascending: false), NSSortDescriptor(key: "periodStartMinute", ascending: true)]
        ).map(Self.timetableReviewRecord).filter { $0.deletedAt == nil }
    }

    func saveTimetableReviewRecord(_ record: TimetableReviewRecord) async throws -> Int64 {
        try await ensureLoaded()
        guard record.termId > 0, record.entryId > 0, record.periodId > 0 else {
            throw ValidationError(message: "復習対象の授業が正しくありません")
        }
        let now = Date().epochMilliseconds
        let existing = try fetch(
            entity: "TimetableReviewRecord",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "termId == %lld", record.termId),
                NSPredicate(format: "entryId == %lld", record.entryId),
                NSPredicate(format: "periodId == %lld", record.periodId),
                NSPredicate(format: "occurrenceDate == %lld", record.occurrenceDate),
                NSPredicate(format: "deletedAt == NIL")
            ])
        ).first

        if let existing {
            let assignedId = existing.value(forKey: "id") as? Int64 ?? record.id
            var updated = record
            updated.syncId = (existing.value(forKey: "syncId") as? String)?.nilIfBlank ?? record.syncId
            updated.createdAt = existing.value(forKey: "createdAt") as? Int64 ?? record.createdAt
            updated.updatedAt = now
            Self.apply(updated, assignedId: assignedId, now: now, to: existing)
            try saveContext()
            return assignedId
        }

        let id = try nextIdentifier(ifNeeded: record.id)
        let object = NSEntityDescription.insertNewObject(forEntityName: "TimetableReviewRecord", into: container.viewContext)
        Self.apply(record, assignedId: id, now: now, to: object)
        try saveContext()
        return id
    }

    func deleteTimetableReviewRecord(_ record: TimetableReviewRecord) async throws {
        try await ensureLoaded()
        guard let object = try fetchOne(entity: "TimetableReviewRecord", id: record.id) else { return }
        let now = Date().epochMilliseconds
        object.setValue(now, forKey: "deletedAt")
        object.setValue(now, forKey: "updatedAt")
        try saveContext()
    }

    func overdueTimetableReviewCount(reference: Date = Date()) async throws -> Int {
        try await ensureLoaded()
        let terms = try fetch(entity: "TimetableTermRecord").map(Self.timetableTerm).filter { $0.deletedAt == nil && $0.isActive }
        let periods = try fetch(entity: "TimetablePeriodRecord").map(Self.timetablePeriod).filter { $0.deletedAt == nil && $0.isActive }
        let entries = try fetch(entity: "TimetableEntryRecord").map(Self.timetableEntry).filter { $0.deletedAt == nil }
        let reviews = try fetch(entity: "TimetableReviewRecord").map(Self.timetableReviewRecord).filter { $0.deletedAt == nil }
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

    func getAllProblemReviewRecords() async throws -> [ProblemReviewRecord] {
        try await ensureLoaded()
        return try fetch(
            entity: "ProblemReviewRecord",
            sort: [NSSortDescriptor(key: "reviewedAt", ascending: false)]
        ).map(Self.problemReviewRecord).filter { $0.deletedAt == nil }
    }

    func getTodayReviewProblems(reference: Date = Date()) async throws -> [TodayReviewProblem] {
        try await ensureLoaded()
        let calendar = Calendar.current
        let dueEnd = (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference)) ?? reference).epochMilliseconds - 1
        let reviews = try fetch(
            entity: "ProblemReviewRecord",
            predicate: NSPredicate(format: "deletedAt == NIL"),
            sort: [NSSortDescriptor(key: "reviewedAt", ascending: false)]
        ).map(Self.problemReviewRecord)
        let latestByProblem = Self.latestProblemReviews(from: reviews)
        guard !latestByProblem.isEmpty else { return [] }

        let materials = try await getAllMaterials()
        let subjects = try await getAllSubjects()
        let materialMap = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })

        return latestByProblem.values
            .filter { $0.nextReviewDate <= dueEnd && $0.deletedAt == nil }
            .compactMap { review -> TodayReviewProblem? in
                guard let material = materialMap[review.materialId], material.deletedAt == nil else { return nil }
                let subject = subjectMap[material.subjectId]
                return TodayReviewProblem(
                    materialId: material.id,
                    materialName: material.name,
                    subjectName: subject?.name ?? "",
                    problemNumber: review.problemNumber,
                    nextReviewDate: review.nextReviewDate,
                    consecutiveCorrectCount: review.consecutiveCorrectCount,
                    wrongCount: review.wrongCount
                )
            }
            .sorted {
                if $0.nextReviewDate != $1.nextReviewDate {
                    return $0.nextReviewDate < $1.nextReviewDate
                }
                if $0.materialName != $1.materialName {
                    return $0.materialName < $1.materialName
                }
                return $0.problemNumber < $1.problemNumber
            }
    }

    func exportData() async throws -> AppData {
        try await ensureLoaded()
        try backfillMissingSyncMetadataIfNeeded()
        let subjects = try fetch(entity: "SubjectRecord", sort: [NSSortDescriptor(key: "name", ascending: true)]).map(Self.subject)
        let materials = try fetch(entity: "MaterialRecord", sort: [NSSortDescriptor(key: "id", ascending: false)]).map(Self.material)
        let sessions = try fetch(entity: "StudySessionRecord", sort: [NSSortDescriptor(key: "startTime", ascending: false)]).map(Self.session)
        let goals = try fetch(entity: "GoalRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: true)]).map(Self.goal)
        let exams = try fetch(entity: "ExamRecord", sort: [NSSortDescriptor(key: "date", ascending: true)]).map(Self.exam)
        let plans = try fetch(entity: "StudyPlanRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: false)]).map(Self.plan)
        let timetablePeriods = try fetch(entity: "TimetablePeriodRecord", sort: [NSSortDescriptor(key: "sortOrder", ascending: true)]).map(Self.timetablePeriod)
        let timetableEntries = try fetch(entity: "TimetableEntryRecord", sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true)]).map(Self.timetableEntry)
        let timetableTerms = try fetch(entity: "TimetableTermRecord", sort: [NSSortDescriptor(key: "startDate", ascending: false)]).map(Self.timetableTerm)
        let timetableReviewRecords = try fetch(entity: "TimetableReviewRecord", sort: [NSSortDescriptor(key: "occurrenceDate", ascending: false)]).map(Self.timetableReviewRecord)
        let problemReviewRecords = try fetch(entity: "ProblemReviewRecord", sort: [NSSortDescriptor(key: "reviewedAt", ascending: false)]).map(Self.problemReviewRecord)

        var planData = [PlanData]()
        for plan in plans {
            let items = try fetch(
                entity: "PlanItemRecord",
                predicate: NSPredicate(format: "planId == %lld", plan.id),
                sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true), NSSortDescriptor(key: "targetMinutes", ascending: false)]
            ).map(Self.planItem)
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

    func exportJSON() async throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(try await exportData())
        guard let json = String(data: data, encoding: .utf8) else {
            throw CocoaError(.coderInvalidValue)
        }
        return json
    }

    func exportCSV() async throws -> String {
        let sessions = try await getAllSessions()
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

    func importJSON(_ json: String, currentPreferences: AppPreferences) async throws -> AppPreferences {
        try await ensureLoaded()
        let appData = try JSONDecoder().decode(AppData.self, from: Data(json.utf8))
        try await replaceData(with: appData)
        return currentPreferences
    }

    func deleteAllData() async throws {
        try await ensureLoaded()
        var deletedObjectIDs = [NSManagedObjectID]()
        for entity in Self.entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            deleteRequest.resultType = .resultTypeObjectIDs
            let result = try container.viewContext.execute(deleteRequest) as? NSBatchDeleteResult
            let objectIDs = result?.result as? [NSManagedObjectID] ?? []
            deletedObjectIDs.append(contentsOf: objectIDs)
        }
        guard !deletedObjectIDs.isEmpty else { return }
        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs],
            into: [container.viewContext]
        )
        changeToken += 1
    }

    private func importLegacySnapshot(_ snapshot: LegacySnapshot) async throws {
        let data = AppData(
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
        try await replaceData(with: data)
    }

    private func replaceData(with appData: AppData) async throws {
        let ctx = container.viewContext

        let existingSubjectIds = try existingIdMap(entity: "SubjectRecord")
        let existingMaterialIds = try existingIdMap(entity: "MaterialRecord")
        let existingSessionIds = try existingIdMap(entity: "StudySessionRecord")
        let existingGoalIds = try existingIdMap(entity: "GoalRecord")
        let existingExamIds = try existingIdMap(entity: "ExamRecord")
        let existingPlanIds = try existingIdMap(entity: "StudyPlanRecord")
        let existingPlanItemIds = try existingIdMap(entity: "PlanItemRecord")
        let existingTimetablePeriodIds = try existingIdMap(entity: "TimetablePeriodRecord")
        let existingTimetableEntryIds = try existingIdMap(entity: "TimetableEntryRecord")
        let existingTimetableTermIds = try existingIdMap(entity: "TimetableTermRecord")
        let existingTimetableReviewRecordIds = try existingIdMap(entity: "TimetableReviewRecord")
        let existingProblemReviewRecordIds = try existingIdMap(entity: "ProblemReviewRecord")
        let existingMaterialsBySyncId = try fetch(entity: "MaterialRecord")
            .map(Self.material)
            .reduce(into: [String: Material]()) { result, material in
                result[material.syncId] = material
            }
        let existingSessionsBySyncId = try fetch(entity: "StudySessionRecord")
            .map(Self.session)
            .reduce(into: [String: StudySession]()) { result, session in
                result[session.syncId] = session
            }

        // Delete all existing records in-memory (not yet committed)
        for entityName in Self.entityNames {
            let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
            let records = try ctx.fetch(request)
            records.forEach { ctx.delete($0) }
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

            let r = NSEntityDescription.insertNewObject(forEntityName: "SubjectRecord", into: ctx)
            Self.apply(subject, assignedId: localId, now: now, to: r)
        }

        // --- Materials ---
        for material in appData.materials {
            let localId = allocateId(preferred: existingMaterialIds[material.syncId] ?? material.id)
            let importedMaterial = Self.preserveProblemProgress(in: material, existing: existingMaterialsBySyncId[material.syncId])
            materialSyncMap[material.syncId] = localId
            if material.id > 0 { materialOldMap[material.id] = localId }

            let subjectId: Int64 = Self.resolveFK(
                syncId: importedMaterial.subjectSyncId, syncMap: subjectSyncMap,
                oldId: importedMaterial.subjectId, oldMap: subjectOldMap)

            let r = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: ctx)
            Self.apply(
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
            let importedSession = Self.preserveProblemProgress(in: session, existing: existingSessionsBySyncId[session.syncId])

            let subjectId = Self.resolveFK(
                syncId: importedSession.subjectSyncId, syncMap: subjectSyncMap,
                oldId: importedSession.subjectId, oldMap: subjectOldMap)
            let materialId = Self.resolveOptFK(
                syncId: importedSession.materialSyncId, syncMap: materialSyncMap,
                oldId: importedSession.materialId, oldMap: materialOldMap)

            let r = NSEntityDescription.insertNewObject(forEntityName: "StudySessionRecord", into: ctx)
            Self.apply(
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
            let r = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: ctx)
            Self.apply(goal, assignedId: localId, now: now, to: r)
        }

        // --- Exams ---
        for exam in appData.exams {
            let localId = allocateId(preferred: existingExamIds[exam.syncId] ?? exam.id)
            let r = NSEntityDescription.insertNewObject(forEntityName: "ExamRecord", into: ctx)
            Self.apply(exam, assignedId: localId, now: now, to: r)
        }

        // --- Plans & PlanItems (preserve isActive as-is; no deactivation side-effects) ---
        for planData in appData.plans {
            let plan = planData.plan
            let localPlanId = allocateId(preferred: existingPlanIds[plan.syncId] ?? plan.id)
            planSyncMap[plan.syncId] = localPlanId
            if plan.id > 0 { planOldMap[plan.id] = localPlanId }

            let pr = NSEntityDescription.insertNewObject(forEntityName: "StudyPlanRecord", into: ctx)
            Self.apply(plan, assignedId: localPlanId, now: now, to: pr)

            for item in planData.items {
                let localItemId = allocateId(preferred: existingPlanItemIds[item.syncId] ?? item.id)
                let itemSubjectId = Self.resolveFK(
                    syncId: item.subjectSyncId, syncMap: subjectSyncMap,
                    oldId: item.subjectId, oldMap: subjectOldMap)

                let ir = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: ctx)
                Self.apply(
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

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetablePeriodRecord", into: ctx)
            Self.apply(period, assignedId: localId, now: now, to: r)
        }

        // --- TimetableTerms ---
        for term in appData.timetableTerms {
            let localId = allocateId(preferred: existingTimetableTermIds[term.syncId] ?? term.id)
            timetableTermSyncMap[term.syncId] = localId
            if term.id > 0 { timetableTermOldMap[term.id] = localId }

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetableTermRecord", into: ctx)
            Self.apply(term, assignedId: localId, now: now, to: r)
        }

        // --- TimetableEntries ---
        for entry in appData.timetableEntries {
            let localId = allocateId(preferred: existingTimetableEntryIds[entry.syncId] ?? entry.id)
            timetableEntrySyncMap[entry.syncId] = localId
            if entry.id > 0 { timetableEntryOldMap[entry.id] = localId }
            let periodId = Self.resolveFK(
                syncId: entry.periodSyncId,
                syncMap: timetablePeriodSyncMap,
                oldId: entry.periodId,
                oldMap: timetablePeriodOldMap
            )
            let termId = Self.resolveOptFK(
                syncId: entry.termSyncId,
                syncMap: timetableTermSyncMap,
                oldId: entry.termId,
                oldMap: timetableTermOldMap
            )
            let periodSyncId = entry.periodSyncId ?? appData.timetablePeriods.first(where: { $0.id == entry.periodId })?.syncId
            let termSyncId = entry.termSyncId ?? entry.termId.flatMap { oldId in appData.timetableTerms.first(where: { $0.id == oldId })?.syncId }

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetableEntryRecord", into: ctx)
            Self.apply(entry, assignedId: localId, termId: termId, termSyncId: termSyncId, periodId: periodId, periodSyncId: periodSyncId, now: now, to: r)
        }

        // --- TimetableReviewRecords ---
        for review in appData.timetableReviewRecords {
            let localId = allocateId(preferred: existingTimetableReviewRecordIds[review.syncId] ?? review.id)
            var remapped = review
            remapped.termId = Self.resolveFK(
                syncId: review.termSyncId,
                syncMap: timetableTermSyncMap,
                oldId: review.termId,
                oldMap: timetableTermOldMap
            )
            remapped.entryId = Self.resolveFK(
                syncId: review.entrySyncId,
                syncMap: timetableEntrySyncMap,
                oldId: review.entryId,
                oldMap: timetableEntryOldMap
            )
            remapped.periodId = Self.resolveFK(
                syncId: review.periodSyncId,
                syncMap: timetablePeriodSyncMap,
                oldId: review.periodId,
                oldMap: timetablePeriodOldMap
            )

            let r = NSEntityDescription.insertNewObject(forEntityName: "TimetableReviewRecord", into: ctx)
            Self.apply(remapped, assignedId: localId, now: now, to: r)
        }

        // --- ProblemReviewRecords ---
        for review in appData.problemReviewRecords {
            let localId = allocateId(preferred: existingProblemReviewRecordIds[review.syncId] ?? review.id)
            var remapped = review
            remapped.materialId = Self.resolveFK(
                syncId: review.materialSyncId,
                syncMap: materialSyncMap,
                oldId: review.materialId,
                oldMap: materialOldMap
            )
            remapped.problemId = ProblemReviewRecord.problemId(
                materialId: remapped.materialId,
                problemNumber: remapped.problemNumber
            )

            let r = NSEntityDescription.insertNewObject(forEntityName: "ProblemReviewRecord", into: ctx)
            Self.apply(remapped, assignedId: localId, now: now, to: r)
        }

        // Commit atomically; rollback on failure preserves original data
        do {
            try saveContext()
        } catch {
            ctx.rollback()
            throw error
        }

        try await recalculatePlanActualMinutes()
    }

    private static func resolveFK(syncId: String?, syncMap: [String: Int64], oldId: Int64, oldMap: [Int64: Int64]) -> Int64 {
        if let sid = syncId, let mapped = syncMap[sid] { return mapped }
        if let mapped = oldMap[oldId] { return mapped }
        return oldId
    }

    private static func resolveOptFK(syncId: String?, syncMap: [String: Int64], oldId: Int64?, oldMap: [Int64: Int64]) -> Int64? {
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

    private func rebuildProblemReviewRecords(for materialId: Int64, now: Int64, startingId nextLocalId: inout Int64) throws {
        let existingReviews = try fetch(
            entity: "ProblemReviewRecord",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "materialId == %lld", materialId),
                NSPredicate(format: "deletedAt == NIL")
            ])
        )
        for review in existingReviews {
            review.setValue(now, forKey: "deletedAt")
            review.setValue(now, forKey: "updatedAt")
        }

        let sessions = try fetch(
            entity: "StudySessionRecord",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "materialId == %lld", materialId),
                NSPredicate(format: "deletedAt == NIL")
            ]),
            sort: [NSSortDescriptor(key: "startTime", ascending: true)]
        ).map(Self.session)

        var latestByProblem = [String: ProblemReviewRecord]()
        for session in sessions where !session.problemRecords.isEmpty {
            for problem in session.problemRecords.sorted(by: { $0.number < $1.number }) where problem.number > 0 {
                let rating: ProblemReviewRating = problem.result == .wrong ? .again : .good
                let problemId = ProblemReviewRecord.problemId(materialId: materialId, problemNumber: problem.number)
                let scheduled = ProblemReviewScheduler.schedule(
                    materialId: materialId,
                    materialSyncId: session.materialSyncId,
                    problemNumber: problem.number,
                    rating: rating,
                    reviewedAt: session.sessionEndTime,
                    previous: latestByProblem[problemId]
                )
                latestByProblem[problemId] = scheduled

                let reviewRecord = NSEntityDescription.insertNewObject(forEntityName: "ProblemReviewRecord", into: container.viewContext)
                Self.apply(scheduled, assignedId: allocateId(startingAt: &nextLocalId), now: now, to: reviewRecord)
            }
        }
    }

    private func allocateId(startingAt nextLocalId: inout Int64) -> Int64 {
        defer { nextLocalId += 1 }
        return nextLocalId
    }

    private static func latestProblemReviews(from reviews: [ProblemReviewRecord]) -> [String: ProblemReviewRecord] {
        reviews.reduce(into: [String: ProblemReviewRecord]()) { result, review in
            guard review.deletedAt == nil else { return }
            let key = ProblemReviewRecord.problemId(materialId: review.materialId, problemNumber: review.problemNumber)
            if let existing = result[key], existing.reviewedAt > review.reviewedAt {
                return
            }
            result[key] = review
        }
    }

    private func recalculatePlanActualMinutes() async throws {
        let activePlans = try fetch(
            entity: "StudyPlanRecord",
            predicate: NSPredicate(format: "isActive == YES AND deletedAt == NIL")
        )
        guard let activePlanRecord = activePlans.first else { return }
        let activePlan = Self.plan(activePlanRecord)
        let planItems = try fetch(
            entity: "PlanItemRecord",
            predicate: NSPredicate(format: "planId == %lld AND deletedAt == NIL", activePlan.id)
        )
        let sessions = try fetch(
            entity: "StudySessionRecord",
            predicate: NSPredicate(format: "deletedAt == NIL")
        )

        for itemRecord in planItems {
            let item = Self.planItem(itemRecord)
            let actualMinutes = sessions.map(Self.session).filter { session in
                session.subjectId == item.subjectId &&
                session.dayOfWeek == item.dayOfWeek &&
                session.startTime >= activePlan.startDate &&
                session.startTime <= activePlan.endDate
            }
            .reduce(0) { $0 + $1.durationMinutes }
            itemRecord.setValue(Int64(actualMinutes), forKey: "actualMinutes")
            itemRecord.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        }
        try saveContext()
    }

    private func sanitize(
        session: StudySession,
        assignedId: Int64,
        persistedSyncId: String? = nil,
        persistedCreatedAt: Int64? = nil,
        persistedLastSyncedAt: Int64? = nil
    ) -> StudySession {
        let effectiveIntervals = session.effectiveIntervals
        return StudySession(
            id: assignedId,
            syncId: persistedSyncId ?? session.syncId,
            materialId: session.materialId,
            materialSyncId: session.materialSyncId,
            materialName: session.materialName,
            subjectId: session.subjectId,
            subjectSyncId: session.subjectSyncId,
            subjectName: session.subjectName,
            sessionType: session.sessionType,
            startTime: effectiveIntervals.first?.startTime ?? session.startTime,
            endTime: effectiveIntervals.last?.endTime ?? session.endTime,
            intervals: effectiveIntervals,
            rating: session.rating,
            note: session.note,
            problemStart: session.problemStart,
            problemEnd: session.problemEnd,
            wrongProblemCount: session.wrongProblemCount,
            problemRecords: session.problemRecords,
            createdAt: persistedCreatedAt ?? (session.createdAt == 0 ? Date().epochMilliseconds : session.createdAt),
            updatedAt: Date().epochMilliseconds,
            deletedAt: session.deletedAt,
            lastSyncedAt: persistedLastSyncedAt ?? session.lastSyncedAt
        )
    }

    private static func apply(_ subject: Subject, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(subject.syncId, forKey: "syncId")
        record.setValue(subject.name, forKey: "name")
        record.setValue(Int64(subject.color), forKey: "color")
        record.setValue(subject.icon?.rawValue, forKey: "icon")
        record.setValue(subject.createdAt == 0 ? now : subject.createdAt, forKey: "createdAt")
        record.setValue(subject.updatedAt == 0 ? now : subject.updatedAt, forKey: "updatedAt")
        record.setValue(subject.deletedAt, forKey: "deletedAt")
        record.setValue(subject.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(
        _ material: Material,
        assignedId: Int64,
        subjectId: Int64,
        subjectSyncId: String?,
        now: Int64,
        to record: NSManagedObject
    ) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(material.syncId, forKey: "syncId")
        record.setValue(material.name, forKey: "name")
        record.setValue(subjectId, forKey: "subjectId")
        record.setValue(subjectSyncId, forKey: "subjectSyncId")
        record.setValue(material.sortOrder, forKey: "sortOrder")
        record.setValue(Int64(material.totalPages), forKey: "totalPages")
        record.setValue(Int64(material.currentPage), forKey: "currentPage")
        record.setValue(Int64(material.totalProblems), forKey: "totalProblems")
        record.setValue(encodeProblemChapters(material.problemChapters), forKey: "problemChaptersData")
        record.setValue(encodeProblemRecords(material.problemRecords), forKey: "problemRecordsData")
        record.setValue(material.color.map { Int64($0) }, forKey: "color")
        record.setValue(material.note, forKey: "note")
        record.setValue(material.createdAt == 0 ? now : material.createdAt, forKey: "createdAt")
        record.setValue(material.updatedAt == 0 ? now : material.updatedAt, forKey: "updatedAt")
        record.setValue(material.deletedAt, forKey: "deletedAt")
        record.setValue(material.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(
        _ session: StudySession,
        assignedId: Int64,
        subjectId: Int64,
        materialId: Int64?,
        now: Int64,
        to record: NSManagedObject
    ) {
        let effectiveIntervals = session.effectiveIntervals
        let startTime = effectiveIntervals.first?.startTime ?? session.startTime
        let endTime = effectiveIntervals.last?.endTime ?? session.endTime

        record.setValue(assignedId, forKey: "id")
        record.setValue(session.syncId, forKey: "syncId")
        record.setValue(materialId, forKey: "materialId")
        record.setValue(session.materialSyncId, forKey: "materialSyncId")
        record.setValue(session.materialName, forKey: "materialName")
        record.setValue(subjectId, forKey: "subjectId")
        record.setValue(session.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(session.subjectName, forKey: "subjectName")
        record.setValue(session.sessionType.rawValue, forKey: "sessionType")
        record.setValue(startTime, forKey: "startTime")
        record.setValue(endTime, forKey: "endTime")
        record.setValue(effectiveIntervals.reduce(0) { $0 + $1.duration }, forKey: "duration")
        record.setValue(Date(epochMilliseconds: startTime).epochDay, forKey: "date")
        record.setValue(encodeIntervals(effectiveIntervals), forKey: "intervalsData")
        record.setValue(session.rating, forKey: "rating")
        record.setValue(session.note, forKey: "note")
        record.setValue(session.problemStart.map { Int64($0) }, forKey: "problemStart")
        record.setValue(session.problemEnd.map { Int64($0) }, forKey: "problemEnd")
        record.setValue(session.wrongProblemCount.map { Int64($0) }, forKey: "wrongProblemCount")
        record.setValue(encodeProblemRecords(session.problemRecords), forKey: "problemRecordsData")
        record.setValue(session.createdAt == 0 ? now : session.createdAt, forKey: "createdAt")
        record.setValue(session.updatedAt == 0 ? now : session.updatedAt, forKey: "updatedAt")
        record.setValue(session.deletedAt, forKey: "deletedAt")
        record.setValue(session.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(_ goal: Goal, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(goal.syncId, forKey: "syncId")
        record.setValue(goal.type.rawValue, forKey: "type")
        record.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
        record.setValue(goal.dayOfWeek?.rawValue, forKey: "dayOfWeek")
        record.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
        record.setValue(goal.isActive, forKey: "isActive")
        record.setValue(goal.createdAt == 0 ? now : goal.createdAt, forKey: "createdAt")
        record.setValue(goal.updatedAt == 0 ? now : goal.updatedAt, forKey: "updatedAt")
        record.setValue(goal.deletedAt, forKey: "deletedAt")
        record.setValue(goal.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(_ exam: Exam, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(exam.syncId, forKey: "syncId")
        record.setValue(exam.name, forKey: "name")
        record.setValue(exam.date, forKey: "date")
        record.setValue(exam.note, forKey: "note")
        record.setValue(exam.createdAt == 0 ? now : exam.createdAt, forKey: "createdAt")
        record.setValue(exam.updatedAt == 0 ? now : exam.updatedAt, forKey: "updatedAt")
        record.setValue(exam.deletedAt, forKey: "deletedAt")
        record.setValue(exam.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(_ plan: StudyPlan, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(plan.syncId, forKey: "syncId")
        record.setValue(plan.name, forKey: "name")
        record.setValue(plan.startDate, forKey: "startDate")
        record.setValue(plan.endDate, forKey: "endDate")
        record.setValue(plan.isActive, forKey: "isActive")
        record.setValue(plan.createdAt == 0 ? now : plan.createdAt, forKey: "createdAt")
        record.setValue(plan.updatedAt == 0 ? now : plan.updatedAt, forKey: "updatedAt")
        record.setValue(plan.deletedAt, forKey: "deletedAt")
        record.setValue(plan.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(
        _ item: PlanItem,
        assignedId: Int64,
        planId: Int64,
        planSyncId: String?,
        subjectId: Int64,
        now: Int64,
        to record: NSManagedObject
    ) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(item.syncId, forKey: "syncId")
        record.setValue(planId, forKey: "planId")
        record.setValue(planSyncId, forKey: "planSyncId")
        record.setValue(subjectId, forKey: "subjectId")
        record.setValue(item.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
        record.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
        record.setValue(item.timeSlot, forKey: "timeSlot")
        record.setValue(item.createdAt == 0 ? now : item.createdAt, forKey: "createdAt")
        record.setValue(item.updatedAt == 0 ? now : item.updatedAt, forKey: "updatedAt")
        record.setValue(item.deletedAt, forKey: "deletedAt")
        record.setValue(item.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(_ period: TimetablePeriod, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(period.syncId, forKey: "syncId")
        record.setValue(period.name, forKey: "name")
        record.setValue(Int64(period.startMinute), forKey: "startMinute")
        record.setValue(Int64(period.endMinute), forKey: "endMinute")
        record.setValue(Int64(period.sortOrder), forKey: "sortOrder")
        record.setValue(period.isActive, forKey: "isActive")
        record.setValue(period.createdAt == 0 ? now : period.createdAt, forKey: "createdAt")
        record.setValue(period.updatedAt == 0 ? now : period.updatedAt, forKey: "updatedAt")
        record.setValue(period.deletedAt, forKey: "deletedAt")
        record.setValue(period.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(
        _ entry: TimetableEntry,
        assignedId: Int64,
        termId: Int64?,
        termSyncId: String?,
        periodId: Int64,
        periodSyncId: String?,
        now: Int64,
        to record: NSManagedObject
    ) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(entry.syncId, forKey: "syncId")
        record.setValue(termId, forKey: "termId")
        record.setValue(termSyncId, forKey: "termSyncId")
        record.setValue(entry.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(periodId, forKey: "periodId")
        record.setValue(periodSyncId, forKey: "periodSyncId")
        record.setValue(entry.subjectName, forKey: "subjectName")
        record.setValue(entry.courseName, forKey: "courseName")
        record.setValue(entry.roomName, forKey: "roomName")
        record.setValue(entry.validFromDate, forKey: "validFromDate")
        record.setValue(entry.validToDate, forKey: "validToDate")
        record.setValue(entry.createdAt == 0 ? now : entry.createdAt, forKey: "createdAt")
        record.setValue(entry.updatedAt == 0 ? now : entry.updatedAt, forKey: "updatedAt")
        record.setValue(entry.deletedAt, forKey: "deletedAt")
        record.setValue(entry.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(_ term: TimetableTerm, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(term.syncId, forKey: "syncId")
        record.setValue(term.name, forKey: "name")
        record.setValue(term.startDate, forKey: "startDate")
        record.setValue(term.endDate, forKey: "endDate")
        record.setValue(term.isActive, forKey: "isActive")
        record.setValue(term.createdAt == 0 ? now : term.createdAt, forKey: "createdAt")
        record.setValue(term.updatedAt == 0 ? now : term.updatedAt, forKey: "updatedAt")
        record.setValue(term.deletedAt, forKey: "deletedAt")
        record.setValue(term.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(_ review: TimetableReviewRecord, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(review.syncId, forKey: "syncId")
        record.setValue(review.termId, forKey: "termId")
        record.setValue(review.termSyncId, forKey: "termSyncId")
        record.setValue(review.entryId, forKey: "entryId")
        record.setValue(review.entrySyncId, forKey: "entrySyncId")
        record.setValue(review.periodId, forKey: "periodId")
        record.setValue(review.periodSyncId, forKey: "periodSyncId")
        record.setValue(review.occurrenceDate, forKey: "occurrenceDate")
        record.setValue(review.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(review.periodName, forKey: "periodName")
        record.setValue(Int64(review.periodStartMinute), forKey: "periodStartMinute")
        record.setValue(Int64(review.periodEndMinute), forKey: "periodEndMinute")
        record.setValue(review.subjectName, forKey: "subjectName")
        record.setValue(review.courseName, forKey: "courseName")
        record.setValue(review.roomName, forKey: "roomName")
        record.setValue(review.isReviewed, forKey: "isReviewed")
        record.setValue(review.note, forKey: "note")
        record.setValue(review.isExcluded, forKey: "isExcluded")
        record.setValue(review.reviewedAt, forKey: "reviewedAt")
        record.setValue(review.createdAt == 0 ? now : review.createdAt, forKey: "createdAt")
        record.setValue(review.updatedAt == 0 ? now : review.updatedAt, forKey: "updatedAt")
        record.setValue(review.deletedAt, forKey: "deletedAt")
        record.setValue(review.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private static func apply(_ review: ProblemReviewRecord, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(review.syncId, forKey: "syncId")
        record.setValue(review.problemId, forKey: "problemId")
        record.setValue(review.materialId, forKey: "materialId")
        record.setValue(review.materialSyncId, forKey: "materialSyncId")
        record.setValue(Int64(review.problemNumber), forKey: "problemNumber")
        record.setValue(review.reviewedAt, forKey: "reviewedAt")
        record.setValue(review.rating.rawValue, forKey: "rating")
        record.setValue(review.nextReviewDate, forKey: "nextReviewDate")
        record.setValue(Int64(review.consecutiveCorrectCount), forKey: "consecutiveCorrectCount")
        record.setValue(Int64(review.wrongCount), forKey: "wrongCount")
        record.setValue(review.createdAt == 0 ? now : review.createdAt, forKey: "createdAt")
        record.setValue(review.updatedAt == 0 ? now : review.updatedAt, forKey: "updatedAt")
        record.setValue(review.deletedAt, forKey: "deletedAt")
        record.setValue(review.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private func apply(_ session: StudySession, to record: NSManagedObject) {
        Self.apply(
            session,
            assignedId: session.id,
            subjectId: session.subjectId,
            materialId: session.materialId,
            now: Date().epochMilliseconds,
            to: record
        )
    }

    private func ensureLoaded() async throws {
        try await loadTask.value
        if !didNormalizeLegacyDailyGoals {
            try normalizeLegacyDailyGoalsIfNeeded()
            didNormalizeLegacyDailyGoals = true
        }
    }

    private func isEmptyStore() async throws -> Bool {
        for entity in Self.entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            request.fetchLimit = 1
            if try container.viewContext.count(for: request) > 0 {
                return false
            }
        }
        return true
    }

    private func nextIdentifier(ifNeeded requested: Int64) throws -> Int64 {
        if requested > 0 {
            return requested
        }
        return try maxIdentifier() + 1
    }

    private func maxIdentifier() throws -> Int64 {
        var maxId: Int64 = 0
        for entityName in Self.entityNames {
            let request = NSFetchRequest<NSDictionary>(entityName: entityName)
            request.resultType = .dictionaryResultType
            let expression = NSExpressionDescription()
            expression.name = "maxId"
            expression.expression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "id")])
            expression.expressionResultType = .integer64AttributeType
            request.propertiesToFetch = [expression]
            let result = try container.viewContext.fetch(request).first?["maxId"] as? Int64 ?? 0
            maxId = max(maxId, result)
        }
        return maxId
    }

    private func normalizeLegacyDailyGoalsIfNeeded() throws {
        let legacyRecords = try fetch(
            entity: "GoalRecord",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "type == %@", GoalType.daily.rawValue),
                NSPredicate(format: "isActive == YES"),
                NSPredicate(format: "deletedAt == NIL"),
                NSPredicate(format: "dayOfWeek == NIL")
            ])
        )

        guard !legacyRecords.isEmpty else { return }

        var nextGoalId = (try fetch(entity: "GoalRecord").compactMap { $0.value(forKey: "id") as? Int64 }.max() ?? 0) + 1
        for record in legacyRecords {
            let baseGoal = Self.goal(record)
            container.viewContext.delete(record)

            for day in StudyWeekday.allCases {
                let newRecord = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: container.viewContext)
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

        try saveContext()
    }

    private func fetch(
        entity: String,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor] = []
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.sortDescriptors = sort
        return try container.viewContext.fetch(request)
    }

    private func fetchOne(entity: String, id: Int64) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %lld", id)
        request.fetchLimit = 1
        return try container.viewContext.fetch(request).first
    }

    private func existingIdMap(entity: String) throws -> [String: Int64] {
        let records = try fetch(entity: entity)
        var result = [String: Int64]()
        result.reserveCapacity(records.count)
        for record in records {
            guard let syncId = record.value(forKey: "syncId") as? String, !syncId.isEmpty else { continue }
            guard let id = record.value(forKey: "id") as? Int64, id > 0 else { continue }
            result[syncId] = id
        }
        return result
    }

    private func saveContext() throws {
        if container.viewContext.hasChanges {
            try container.viewContext.save()
            changeToken += 1
        }
    }

    private func backfillMissingSyncMetadataIfNeeded() throws {
        var didChange = false

        let subjectRecords = try fetch(entity: "SubjectRecord")
        var subjectSyncIds = [Int64: String]()
        var subjectNames = [Int64: String]()
        for record in subjectRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            let syncId = ensureSyncId(on: record, didChange: &didChange)
            subjectSyncIds[id] = syncId
            subjectNames[id] = record.value(forKey: "name") as? String ?? ""
        }

        let planRecords = try fetch(entity: "StudyPlanRecord")
        var planSyncIds = [Int64: String]()
        for record in planRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            planSyncIds[id] = ensureSyncId(on: record, didChange: &didChange)
        }

        let materialRecords = try fetch(entity: "MaterialRecord")
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

        let sessionRecords = try fetch(entity: "StudySessionRecord")
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

        let planItemRecords = try fetch(entity: "PlanItemRecord")
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

        let timetablePeriodRecords = try fetch(entity: "TimetablePeriodRecord")
        var timetablePeriodSyncIds = [Int64: String]()
        for record in timetablePeriodRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            timetablePeriodSyncIds[id] = ensureSyncId(on: record, didChange: &didChange)
        }

        let timetableTermRecords = try fetch(entity: "TimetableTermRecord")
        var timetableTermSyncIds = [Int64: String]()
        for record in timetableTermRecords {
            let id = record.value(forKey: "id") as? Int64 ?? 0
            timetableTermSyncIds[id] = ensureSyncId(on: record, didChange: &didChange)
        }

        let timetableEntryRecords = try fetch(entity: "TimetableEntryRecord")
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

        let timetableReviewRecords = try fetch(entity: "TimetableReviewRecord")
        for record in timetableReviewRecords {
            _ = ensureSyncId(on: record, didChange: &didChange)
            let termId = record.value(forKey: "termId") as? Int64 ?? 0
            let entryId = record.value(forKey: "entryId") as? Int64 ?? 0
            let periodId = record.value(forKey: "periodId") as? Int64 ?? 0
            ensureStringValue(on: record, key: "termSyncId", value: timetableTermSyncIds[termId], didChange: &didChange)
            ensureStringValue(on: record, key: "entrySyncId", value: timetableEntrySyncIds[entryId], didChange: &didChange)
            ensureStringValue(on: record, key: "periodSyncId", value: timetablePeriodSyncIds[periodId], didChange: &didChange)
        }

        let problemReviewRecords = try fetch(entity: "ProblemReviewRecord")
        for record in problemReviewRecords {
            _ = ensureSyncId(on: record, didChange: &didChange)
            let materialId = record.value(forKey: "materialId") as? Int64 ?? 0
            let problemNumber = Int(record.value(forKey: "problemNumber") as? Int64 ?? 0)
            ensureStringValue(on: record, key: "materialSyncId", value: materialSyncIds[materialId], didChange: &didChange)
            ensureStringValue(
                on: record,
                key: "problemId",
                value: ProblemReviewRecord.problemId(materialId: materialId, problemNumber: problemNumber),
                didChange: &didChange
            )
        }

        for entity in ["GoalRecord", "ExamRecord"] {
            let records = try fetch(entity: entity)
            for record in records {
                _ = ensureSyncId(on: record, didChange: &didChange)
            }
        }

        if didChange {
            try saveContext()
        }
    }

    @discardableResult
    private func ensureSyncId(on record: NSManagedObject, didChange: inout Bool) -> String {
        if let existing = record.value(forKey: "syncId") as? String, !existing.isEmpty {
            return existing
        }
        let syncId = UUID().uuidString.lowercased()
        record.setValue(syncId, forKey: "syncId")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        didChange = true
        return syncId
    }

    private func ensureStringValue(
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

    private func csvEscaped(_ value: String) -> String {
        guard value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    private static func subject(_ record: NSManagedObject) -> Subject {
        Subject(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            color: Int(record.value(forKey: "color") as? Int64 ?? 0),
            icon: (record.value(forKey: "icon") as? String).flatMap(SubjectIcon.init(rawValue:)),
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func material(_ record: NSManagedObject) -> Material {
        Material(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            subjectSyncId: record.value(forKey: "subjectSyncId") as? String,
            sortOrder: record.value(forKey: "sortOrder") as? Int64 ?? 0,
            totalPages: Int(record.value(forKey: "totalPages") as? Int64 ?? 0),
            currentPage: Int(record.value(forKey: "currentPage") as? Int64 ?? 0),
            totalProblems: Int(record.value(forKey: "totalProblems") as? Int64 ?? 0),
            problemChapters: decodeProblemChapters(record.value(forKey: "problemChaptersData") as? String),
            problemRecords: decodeProblemRecords(record.value(forKey: "problemRecordsData") as? String),
            color: (record.value(forKey: "color") as? Int64).map(Int.init),
            note: record.value(forKey: "note") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func session(_ record: NSManagedObject) -> StudySession {
        StudySession(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            materialId: record.value(forKey: "materialId") as? Int64,
            materialSyncId: record.value(forKey: "materialSyncId") as? String,
            materialName: record.value(forKey: "materialName") as? String ?? "",
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            subjectSyncId: record.value(forKey: "subjectSyncId") as? String,
            subjectName: record.value(forKey: "subjectName") as? String ?? "",
            sessionType: StudySessionType(rawValue: record.value(forKey: "sessionType") as? String ?? "") ?? .stopwatch,
            startTime: record.value(forKey: "startTime") as? Int64 ?? 0,
            endTime: record.value(forKey: "endTime") as? Int64 ?? 0,
            intervals: decodeIntervals(record.value(forKey: "intervalsData") as? String),
            rating: (record.value(forKey: "rating") as? NSNumber)?.intValue,
            note: record.value(forKey: "note") as? String,
            problemStart: (record.value(forKey: "problemStart") as? Int64).map(Int.init),
            problemEnd: (record.value(forKey: "problemEnd") as? Int64).map(Int.init),
            wrongProblemCount: (record.value(forKey: "wrongProblemCount") as? Int64).map(Int.init),
            problemRecords: decodeProblemRecords(record.value(forKey: "problemRecordsData") as? String),
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func goal(_ record: NSManagedObject) -> Goal {
        Goal(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            type: GoalType(rawValue: record.value(forKey: "type") as? String ?? GoalType.daily.rawValue) ?? .daily,
            targetMinutes: Int(record.value(forKey: "targetMinutes") as? Int64 ?? 0),
            dayOfWeek: (record.value(forKey: "dayOfWeek") as? String).flatMap(StudyWeekday.init(rawValue:)),
            weekStartDay: StudyWeekday(rawValue: record.value(forKey: "weekStartDay") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            isActive: record.value(forKey: "isActive") as? Bool ?? false,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func exam(_ record: NSManagedObject) -> Exam {
        Exam(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            date: record.value(forKey: "date") as? Int64 ?? 0,
            note: record.value(forKey: "note") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func plan(_ record: NSManagedObject) -> StudyPlan {
        StudyPlan(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            startDate: record.value(forKey: "startDate") as? Int64 ?? 0,
            endDate: record.value(forKey: "endDate") as? Int64 ?? 0,
            isActive: record.value(forKey: "isActive") as? Bool ?? false,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func planItem(_ record: NSManagedObject) -> PlanItem {
        PlanItem(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            planId: record.value(forKey: "planId") as? Int64 ?? 0,
            planSyncId: record.value(forKey: "planSyncId") as? String,
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            subjectSyncId: record.value(forKey: "subjectSyncId") as? String,
            dayOfWeek: StudyWeekday(rawValue: record.value(forKey: "dayOfWeek") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            targetMinutes: Int(record.value(forKey: "targetMinutes") as? Int64 ?? 0),
            actualMinutes: Int(record.value(forKey: "actualMinutes") as? Int64 ?? 0),
            timeSlot: record.value(forKey: "timeSlot") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func timetablePeriod(_ record: NSManagedObject) -> TimetablePeriod {
        TimetablePeriod(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            startMinute: Int(record.value(forKey: "startMinute") as? Int64 ?? 0),
            endMinute: Int(record.value(forKey: "endMinute") as? Int64 ?? 0),
            sortOrder: Int(record.value(forKey: "sortOrder") as? Int64 ?? 0),
            isActive: record.value(forKey: "isActive") as? Bool ?? true,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func timetableEntry(_ record: NSManagedObject) -> TimetableEntry {
        TimetableEntry(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            termId: record.value(forKey: "termId") as? Int64,
            termSyncId: record.value(forKey: "termSyncId") as? String,
            dayOfWeek: StudyWeekday(rawValue: record.value(forKey: "dayOfWeek") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            periodId: record.value(forKey: "periodId") as? Int64 ?? 0,
            periodSyncId: record.value(forKey: "periodSyncId") as? String,
            subjectName: record.value(forKey: "subjectName") as? String ?? "",
            courseName: record.value(forKey: "courseName") as? String,
            roomName: record.value(forKey: "roomName") as? String,
            validFromDate: record.value(forKey: "validFromDate") as? Int64,
            validToDate: record.value(forKey: "validToDate") as? Int64,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func timetableTerm(_ record: NSManagedObject) -> TimetableTerm {
        TimetableTerm(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            startDate: record.value(forKey: "startDate") as? Int64 ?? 0,
            endDate: record.value(forKey: "endDate") as? Int64 ?? 0,
            isActive: record.value(forKey: "isActive") as? Bool ?? true,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func timetableReviewRecord(_ record: NSManagedObject) -> TimetableReviewRecord {
        TimetableReviewRecord(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            termId: record.value(forKey: "termId") as? Int64 ?? 0,
            termSyncId: record.value(forKey: "termSyncId") as? String,
            entryId: record.value(forKey: "entryId") as? Int64 ?? 0,
            entrySyncId: record.value(forKey: "entrySyncId") as? String,
            periodId: record.value(forKey: "periodId") as? Int64 ?? 0,
            periodSyncId: record.value(forKey: "periodSyncId") as? String,
            occurrenceDate: record.value(forKey: "occurrenceDate") as? Int64 ?? 0,
            dayOfWeek: StudyWeekday(rawValue: record.value(forKey: "dayOfWeek") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            periodName: record.value(forKey: "periodName") as? String ?? "",
            periodStartMinute: Int(record.value(forKey: "periodStartMinute") as? Int64 ?? 0),
            periodEndMinute: Int(record.value(forKey: "periodEndMinute") as? Int64 ?? 0),
            subjectName: record.value(forKey: "subjectName") as? String ?? "",
            courseName: record.value(forKey: "courseName") as? String,
            roomName: record.value(forKey: "roomName") as? String,
            isReviewed: record.value(forKey: "isReviewed") as? Bool ?? false,
            note: record.value(forKey: "note") as? String,
            isExcluded: record.value(forKey: "isExcluded") as? Bool ?? false,
            reviewedAt: record.value(forKey: "reviewedAt") as? Int64,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func problemReviewRecord(_ record: NSManagedObject) -> ProblemReviewRecord {
        let materialId = record.value(forKey: "materialId") as? Int64 ?? 0
        let problemNumber = Int(record.value(forKey: "problemNumber") as? Int64 ?? 0)
        return ProblemReviewRecord(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            problemId: record.value(forKey: "problemId") as? String ?? ProblemReviewRecord.problemId(materialId: materialId, problemNumber: problemNumber),
            materialId: materialId,
            materialSyncId: record.value(forKey: "materialSyncId") as? String,
            problemNumber: problemNumber,
            reviewedAt: record.value(forKey: "reviewedAt") as? Int64 ?? 0,
            rating: ProblemReviewRating(rawValue: record.value(forKey: "rating") as? String ?? "") ?? .again,
            nextReviewDate: record.value(forKey: "nextReviewDate") as? Int64 ?? 0,
            consecutiveCorrectCount: Int(record.value(forKey: "consecutiveCorrectCount") as? Int64 ?? 0),
            wrongCount: Int(record.value(forKey: "wrongCount") as? Int64 ?? 0),
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    private static func encodeIntervals(_ intervals: [StudySessionInterval]) -> String? {
        guard !intervals.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(intervals) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeIntervals(_ value: String?) -> [StudySessionInterval] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([StudySessionInterval].self, from: data)) ?? []
    }

    private static func encodeProblemRecords(_ records: [ProblemSessionRecord]) -> String? {
        guard !records.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(records.sorted(by: { $0.number < $1.number })) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeProblemRecords(_ value: String?) -> [ProblemSessionRecord] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ProblemSessionRecord].self, from: data)) ?? []
    }

    private static func encodeProblemChapters(_ chapters: [ProblemChapter]) -> String? {
        guard !chapters.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(chapters) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func decodeProblemChapters(_ value: String?) -> [ProblemChapter] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ProblemChapter].self, from: data)) ?? []
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity(
                name: "SubjectRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "color", type: .integer64AttributeType),
                    attribute(name: "icon", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "MaterialRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "subjectSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "sortOrder", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "totalPages", type: .integer64AttributeType),
                    attribute(name: "currentPage", type: .integer64AttributeType),
                    attribute(name: "totalProblems", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "problemChaptersData", type: .stringAttributeType, optional: true),
                    attribute(name: "problemRecordsData", type: .stringAttributeType, optional: true),
                    attribute(name: "color", type: .integer64AttributeType, optional: true),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "StudySessionRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "materialId", type: .integer64AttributeType, optional: true),
                    attribute(name: "materialSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "materialName", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "subjectSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectName", type: .stringAttributeType),
                    attribute(name: "sessionType", type: .stringAttributeType, defaultValue: StudySessionType.stopwatch.rawValue),
                    attribute(name: "startTime", type: .integer64AttributeType),
                    attribute(name: "endTime", type: .integer64AttributeType),
                    attribute(name: "duration", type: .integer64AttributeType),
                    attribute(name: "date", type: .integer64AttributeType),
                    attribute(name: "intervalsData", type: .stringAttributeType, optional: true),
                    attribute(name: "rating", type: .integer16AttributeType, optional: true),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "problemStart", type: .integer64AttributeType, optional: true),
                    attribute(name: "problemEnd", type: .integer64AttributeType, optional: true),
                    attribute(name: "wrongProblemCount", type: .integer64AttributeType, optional: true),
                    attribute(name: "problemRecordsData", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "GoalRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "type", type: .stringAttributeType),
                    attribute(name: "targetMinutes", type: .integer64AttributeType),
                    attribute(name: "dayOfWeek", type: .stringAttributeType, optional: true),
                    attribute(name: "weekStartDay", type: .stringAttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "ExamRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "date", type: .integer64AttributeType),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "StudyPlanRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "startDate", type: .integer64AttributeType),
                    attribute(name: "endDate", type: .integer64AttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "PlanItemRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "planId", type: .integer64AttributeType),
                    attribute(name: "planSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "subjectSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "dayOfWeek", type: .stringAttributeType),
                    attribute(name: "targetMinutes", type: .integer64AttributeType),
                    attribute(name: "actualMinutes", type: .integer64AttributeType),
                    attribute(name: "timeSlot", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetablePeriodRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "startMinute", type: .integer64AttributeType),
                    attribute(name: "endMinute", type: .integer64AttributeType),
                    attribute(name: "sortOrder", type: .integer64AttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType, defaultValue: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetableEntryRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "termId", type: .integer64AttributeType, optional: true),
                    attribute(name: "termSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "dayOfWeek", type: .stringAttributeType),
                    attribute(name: "periodId", type: .integer64AttributeType),
                    attribute(name: "periodSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectName", type: .stringAttributeType),
                    attribute(name: "courseName", type: .stringAttributeType, optional: true),
                    attribute(name: "roomName", type: .stringAttributeType, optional: true),
                    attribute(name: "validFromDate", type: .integer64AttributeType, optional: true),
                    attribute(name: "validToDate", type: .integer64AttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetableTermRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "startDate", type: .integer64AttributeType),
                    attribute(name: "endDate", type: .integer64AttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType, defaultValue: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetableReviewRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "termId", type: .integer64AttributeType),
                    attribute(name: "termSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "entryId", type: .integer64AttributeType),
                    attribute(name: "entrySyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "periodId", type: .integer64AttributeType),
                    attribute(name: "periodSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "occurrenceDate", type: .integer64AttributeType),
                    attribute(name: "dayOfWeek", type: .stringAttributeType),
                    attribute(name: "periodName", type: .stringAttributeType),
                    attribute(name: "periodStartMinute", type: .integer64AttributeType),
                    attribute(name: "periodEndMinute", type: .integer64AttributeType),
                    attribute(name: "subjectName", type: .stringAttributeType),
                    attribute(name: "courseName", type: .stringAttributeType, optional: true),
                    attribute(name: "roomName", type: .stringAttributeType, optional: true),
                    attribute(name: "isReviewed", type: .booleanAttributeType, defaultValue: false),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "isExcluded", type: .booleanAttributeType, defaultValue: false),
                    attribute(name: "reviewedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "ProblemReviewRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "problemId", type: .stringAttributeType),
                    attribute(name: "materialId", type: .integer64AttributeType),
                    attribute(name: "materialSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "problemNumber", type: .integer64AttributeType),
                    attribute(name: "reviewedAt", type: .integer64AttributeType),
                    attribute(name: "rating", type: .stringAttributeType),
                    attribute(name: "nextReviewDate", type: .integer64AttributeType),
                    attribute(name: "consecutiveCorrectCount", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "wrongCount", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            )
        ]
        return model
    }

    private static func entity(name: String, attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = attributes
        return entity
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }

    private static let entityNames = [
        "SubjectRecord",
        "MaterialRecord",
        "StudySessionRecord",
        "GoalRecord",
        "ExamRecord",
        "StudyPlanRecord",
        "PlanItemRecord",
        "TimetablePeriodRecord",
        "TimetableEntryRecord",
        "TimetableTermRecord",
        "TimetableReviewRecord",
        "ProblemReviewRecord"
    ]
}

struct UserDefaultsPreferencesRepository: AppPreferencesRepository {
    private let defaults: UserDefaults
    private let key = "studyapp.preferences"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func loadPreferences() -> AppPreferences {
        guard let data = defaults.data(forKey: key),
              let preferences = try? JSONDecoder().decode(AppPreferences.self, from: data) else {
            return AppPreferences()
        }
        return preferences
    }

    func savePreferences(_ preferences: AppPreferences) {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        defaults.set(data, forKey: key)
    }
}
