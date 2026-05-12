import CoreData
import Foundation

/// Core Data-backed implementation of every repository protocol the app uses.
///
/// This class focuses on two concerns now:
///
/// 1. Owning the `NSPersistentContainer`, `viewContext`, and a background
///    context for heavy work.
/// 2. Per-entity CRUD — short, on-main-actor operations the UI depends on.
///
/// Everything else (export snapshot building, JSON import, sync-metadata
/// backfill, overdue timetable calculations, legacy snapshot migration,
/// per-material problem review rebuild, plan actual-minutes recomputation)
/// has been extracted to focused helpers in this folder. Heavy operations
/// now run inside `backgroundContext.perform { ... }` so the main thread is
/// not blocked on JSON encode/decode or full-store scans.
@MainActor
final class PersistenceController: SubjectRepository, MaterialRepository, StudySessionRepository, GoalRepository, ExamRepository, PlanRepository, TimetableRepository, ProblemReviewRepository, AppDataRepository {
    static let shared = PersistenceController()

    private let container: NSPersistentContainer
    private let fileManager: FileManager
    private let loadTask: Task<Void, Error>
    private let legacyURL: URL
    private(set) var changeToken: Int64 = 0
    private var didNormalizeLegacyDailyGoals = false

    /// Main-queue context used for short repository CRUD that drives the UI.
    private var viewContext: NSManagedObjectContext { container.viewContext }

    /// Private-queue context used for heavy operations (exports, imports,
    /// full-store migrations, and sync-metadata backfill). Saves here
    /// automatically merge into `viewContext` via
    /// `automaticallyMergesChangesFromParent`.
    private lazy var backgroundContext: NSManagedObjectContext = {
        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        ctx.automaticallyMergesChangesFromParent = true
        return ctx
    }()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.legacyURL = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory)
            .appendingPathComponent("studyapp-store.json")

        let model = CoreDataSchema.makeModel()
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

    // MARK: - SubjectRepository

    func getAllSubjects() async throws -> [Subject] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "SubjectRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "name", ascending: true)]
        ).map(PersistenceMappers.subject).filter { $0.deletedAt == nil }
    }

    func getSubjectById(_ id: Int64) async throws -> Subject? {
        try await ensureLoaded()
        return try CoreDataQuery.fetchOne("SubjectRecord", id: id, in: viewContext).map(PersistenceMappers.subject)
    }

    func insertSubject(_ subject: Subject) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: subject.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "SubjectRecord", into: viewContext)
        PersistenceMappers.apply(subject, assignedId: id, now: now, to: record)
        try saveViewContext()
        return id
    }

    func updateSubject(_ subject: Subject) async throws {
        try await ensureLoaded()
        guard let record = try CoreDataQuery.fetchOne("SubjectRecord", id: subject.id, in: viewContext) else { return }
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

        let sessions = try CoreDataQuery.fetch(
            "StudySessionRecord",
            in: viewContext,
            predicate: NSPredicate(format: "subjectId == %lld", subject.id)
        )
        for session in sessions {
            session.setValue(subjectSyncId, forKey: "subjectSyncId")
            session.setValue(subject.name, forKey: "subjectName")
            session.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        }
        try saveViewContext()
    }

    func deleteSubject(_ subject: Subject) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        let relatedMaterials = try CoreDataQuery.fetch(
            "MaterialRecord",
            in: viewContext,
            predicate: NSPredicate(format: "subjectId == %lld", subject.id)
        )
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
        let sessions = try CoreDataQuery.fetch("StudySessionRecord", in: viewContext, predicate: sessionPredicate)
        let planItems = try CoreDataQuery.fetch(
            "PlanItemRecord",
            in: viewContext,
            predicate: NSPredicate(format: "subjectId == %lld", subject.id)
        )
        let problemReviewRecords = materialIds.isEmpty ? [] : try CoreDataQuery.fetch(
            "ProblemReviewRecord",
            in: viewContext,
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
        if let record = try CoreDataQuery.fetchOne("SubjectRecord", id: subject.id, in: viewContext) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
        }
        try saveViewContext()
    }

    // MARK: - MaterialRepository

    func getAllMaterials() async throws -> [Material] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "MaterialRecord",
            in: viewContext,
            sort: [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
        ).map(PersistenceMappers.material).filter { $0.deletedAt == nil }
    }

    func getMaterialsBySubjectId(_ subjectId: Int64) async throws -> [Material] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "MaterialRecord",
            in: viewContext,
            predicate: NSPredicate(format: "subjectId == %lld", subjectId),
            sort: [
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]
        ).map(PersistenceMappers.material).filter { $0.deletedAt == nil }
    }

    func insertMaterial(_ material: Material) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: material.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: viewContext)
        PersistenceMappers.apply(
            material,
            assignedId: id,
            subjectId: material.subjectId,
            subjectSyncId: material.subjectSyncId,
            now: now,
            to: record
        )
        try saveViewContext()
        return id
    }

    func updateMaterial(_ material: Material) async throws {
        try await ensureLoaded()
        guard let record = try CoreDataQuery.fetchOne("MaterialRecord", id: material.id, in: viewContext) else { return }
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
        record.setValue(PersistenceMappers.encodeProblemChapters(material.problemChapters), forKey: "problemChaptersData")
        record.setValue(PersistenceMappers.encodeProblemRecords(material.problemRecords), forKey: "problemRecordsData")
        record.setValue(material.color.map { Int64($0) }, forKey: "color")
        record.setValue(material.note, forKey: "note")
        record.setValue(material.deletedAt, forKey: "deletedAt")
        record.setValue(material.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")

        let sessions = try CoreDataQuery.fetch(
            "StudySessionRecord",
            in: viewContext,
            predicate: NSPredicate(format: "materialId == %lld", material.id)
        )
        for session in sessions {
            session.setValue(materialSyncId, forKey: "materialSyncId")
            session.setValue(material.name, forKey: "materialName")
            session.setValue(material.subjectId, forKey: "subjectId")
            session.setValue(subjectSyncId, forKey: "subjectSyncId")
            session.setValue(subjectName, forKey: "subjectName")
            session.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        }
        try saveViewContext()
    }

    func deleteMaterial(_ material: Material) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try CoreDataQuery.fetchOne("MaterialRecord", id: material.id, in: viewContext) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
        }
        let sessions = try CoreDataQuery.fetch(
            "StudySessionRecord",
            in: viewContext,
            predicate: NSPredicate(format: "materialId == %lld", material.id)
        )
        for session in sessions {
            session.setValue(now, forKey: "deletedAt")
            session.setValue(now, forKey: "updatedAt")
        }
        let problemReviewRecords = try CoreDataQuery.fetch(
            "ProblemReviewRecord",
            in: viewContext,
            predicate: NSPredicate(format: "materialId == %lld AND deletedAt == NIL", material.id)
        )
        for review in problemReviewRecords {
            review.setValue(now, forKey: "deletedAt")
            review.setValue(now, forKey: "updatedAt")
        }
        try saveViewContext()
    }

    // MARK: - StudySessionRepository

    func getAllSessions() async throws -> [StudySession] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "StudySessionRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "startTime", ascending: false)]
        ).map(PersistenceMappers.session).filter { $0.deletedAt == nil }
    }

    func getSessionsBetweenDates(start: Int64, end: Int64) async throws -> [StudySession] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "StudySessionRecord",
            in: viewContext,
            predicate: NSPredicate(format: "startTime >= %lld AND startTime < %lld", start, end),
            sort: [NSSortDescriptor(key: "startTime", ascending: false)]
        ).map(PersistenceMappers.session).filter { $0.deletedAt == nil }
    }

    /// Returns the distinct `epochDay` values on which the user has studied
    /// (tombstoned sessions excluded). Fetched as a dictionary with
    /// `returnsDistinctResults = true` to avoid materializing the entire
    /// session history just to compute streaks / study-day sets for the
    /// widget and reports screens.
    func getDistinctStudyDays() async throws -> [Int64] {
        try await ensureLoaded()
        let request = NSFetchRequest<NSDictionary>(entityName: "StudySessionRecord")
        request.predicate = NSPredicate(format: "deletedAt == NIL")
        request.resultType = .dictionaryResultType
        request.returnsDistinctResults = true
        request.propertiesToFetch = ["date"]
        let results = try viewContext.fetch(request)
        return results.compactMap { $0["date"] as? Int64 }
    }

    func insertSession(_ session: StudySession) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: session.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "StudySessionRecord", into: viewContext)
        let sanitized = sanitize(session: session, assignedId: id)
        applySession(sanitized, to: record)
        try saveViewContext()
        try recalculatePlanActualMinutesOnViewContext()
        return id
    }

    func insertSessionWithProblemReviews(_ session: StudySession) async throws -> Int64 {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        var nextLocalId = try CoreDataQuery.maxIdentifier(in: viewContext, entities: CoreDataSchema.entityNames) + 1

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

        let record = NSEntityDescription.insertNewObject(forEntityName: "StudySessionRecord", into: viewContext)
        applySession(sanitized, to: record)
        if let materialId = sanitized.materialId {
            try ProblemReviewRebuilder.rebuild(for: materialId, now: now, startingId: &nextLocalId, in: viewContext)
        }

        do {
            try saveViewContext()
        } catch {
            viewContext.rollback()
            throw error
        }

        try recalculatePlanActualMinutesOnViewContext()
        return sessionId
    }

    func updateSession(_ session: StudySession) async throws {
        try await ensureLoaded()
        guard let record = try CoreDataQuery.fetchOne("StudySessionRecord", id: session.id, in: viewContext) else { return }
        let oldMaterialId = record.value(forKey: "materialId") as? Int64
        var nextLocalId = try CoreDataQuery.maxIdentifier(in: viewContext, entities: CoreDataSchema.entityNames) + 1
        let now = Date().epochMilliseconds
        let sanitized = sanitize(
            session: session,
            assignedId: session.id,
            persistedSyncId: record.value(forKey: "syncId") as? String,
            persistedCreatedAt: record.value(forKey: "createdAt") as? Int64,
            persistedLastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
        applySession(sanitized, to: record)
        var materialIdsToRebuild = Set<Int64>()
        if let oldMaterialId {
            materialIdsToRebuild.insert(oldMaterialId)
        }
        if let materialId = sanitized.materialId {
            materialIdsToRebuild.insert(materialId)
        }
        for materialId in materialIdsToRebuild {
            try ProblemReviewRebuilder.rebuild(for: materialId, now: now, startingId: &nextLocalId, in: viewContext)
        }
        try saveViewContext()
        try recalculatePlanActualMinutesOnViewContext()
    }

    func deleteSession(_ session: StudySession) async throws {
        try await ensureLoaded()
        if let record = try CoreDataQuery.fetchOne("StudySessionRecord", id: session.id, in: viewContext) {
            let now = Date().epochMilliseconds
            let materialId = record.value(forKey: "materialId") as? Int64
            var nextLocalId = try CoreDataQuery.maxIdentifier(in: viewContext, entities: CoreDataSchema.entityNames) + 1
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            if let materialId {
                try ProblemReviewRebuilder.rebuild(for: materialId, now: now, startingId: &nextLocalId, in: viewContext)
            }
            try saveViewContext()
            try recalculatePlanActualMinutesOnViewContext()
        }
    }

    // MARK: - GoalRepository

    func getAllGoals() async throws -> [Goal] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "GoalRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
        ).map(PersistenceMappers.goal).filter { $0.deletedAt == nil }
    }

    func getActiveGoalByType(_ type: GoalType) async throws -> Goal? {
        try await ensureLoaded()
        let predicate = NSPredicate(format: "type == %@ AND isActive == YES AND dayOfWeek == NIL", type.rawValue)
        return try CoreDataQuery.fetch(
            "GoalRecord",
            in: viewContext,
            predicate: predicate,
            sort: [NSSortDescriptor(key: "updatedAt", ascending: false)]
        ).map(PersistenceMappers.goal).first(where: { $0.deletedAt == nil })
    }

    func insertGoal(_ goal: Goal) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: goal.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: viewContext)
        PersistenceMappers.apply(goal, assignedId: id, now: now, to: record)
        try saveViewContext()
        return id
    }

    func updateGoal(_ goal: Goal) async throws {
        try await ensureLoaded()
        guard let record = try CoreDataQuery.fetchOne("GoalRecord", id: goal.id, in: viewContext) else { return }
        record.setValue(goal.type.rawValue, forKey: "type")
        record.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
        record.setValue(goal.dayOfWeek?.rawValue, forKey: "dayOfWeek")
        record.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
        record.setValue(goal.isActive, forKey: "isActive")
        record.setValue(goal.deletedAt, forKey: "deletedAt")
        record.setValue(goal.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveViewContext()
    }

    func deleteGoal(_ goal: Goal) async throws {
        try await ensureLoaded()
        if let record = try CoreDataQuery.fetchOne("GoalRecord", id: goal.id, in: viewContext) {
            let now = Date().epochMilliseconds
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            try saveViewContext()
        }
    }

    // MARK: - ExamRepository

    func getAllExams() async throws -> [Exam] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "ExamRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "date", ascending: true)]
        ).map(PersistenceMappers.exam).filter { $0.deletedAt == nil }
    }

    func getUpcomingExams(now: Date) async throws -> [Exam] {
        try await ensureLoaded()
        let currentDay = now.epochDay
        return try CoreDataQuery.fetch(
            "ExamRecord",
            in: viewContext,
            predicate: NSPredicate(format: "date >= %lld", currentDay),
            sort: [NSSortDescriptor(key: "date", ascending: true)]
        ).map(PersistenceMappers.exam).filter { $0.deletedAt == nil }
    }

    func insertExam(_ exam: Exam) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: exam.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "ExamRecord", into: viewContext)
        PersistenceMappers.apply(exam, assignedId: id, now: now, to: record)
        try saveViewContext()
        return id
    }

    func updateExam(_ exam: Exam) async throws {
        try await ensureLoaded()
        guard let record = try CoreDataQuery.fetchOne("ExamRecord", id: exam.id, in: viewContext) else { return }
        record.setValue(exam.name, forKey: "name")
        record.setValue(exam.date, forKey: "date")
        record.setValue(exam.note, forKey: "note")
        record.setValue(exam.deletedAt, forKey: "deletedAt")
        record.setValue(exam.lastSyncedAt, forKey: "lastSyncedAt")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveViewContext()
    }

    func deleteExam(_ exam: Exam) async throws {
        try await ensureLoaded()
        if let record = try CoreDataQuery.fetchOne("ExamRecord", id: exam.id, in: viewContext) {
            let now = Date().epochMilliseconds
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            try saveViewContext()
        }
    }

    // MARK: - PlanRepository

    func getAllPlans() async throws -> [StudyPlan] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "StudyPlanRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "createdAt", ascending: false)]
        ).map(PersistenceMappers.plan).filter { $0.deletedAt == nil }
    }

    func getPlanItems(planId: Int64) async throws -> [PlanItem] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "PlanItemRecord",
            in: viewContext,
            predicate: NSPredicate(format: "planId == %lld", planId),
            sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true), NSSortDescriptor(key: "targetMinutes", ascending: false)]
        ).map(PersistenceMappers.planItem).filter { $0.deletedAt == nil }
    }

    func createPlan(_ plan: StudyPlan, items: [PlanItem]) async throws -> Int64 {
        try await ensureLoaded()
        let activePlans = try CoreDataQuery.fetch(
            "StudyPlanRecord",
            in: viewContext,
            predicate: NSPredicate(format: "isActive == YES")
        )
        for record in activePlans {
            record.setValue(false, forKey: "isActive")
        }

        let planId = try nextIdentifier(ifNeeded: plan.id)
        var nextLocalId = planId + 1
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "StudyPlanRecord", into: viewContext)
        PersistenceMappers.apply(plan, assignedId: planId, now: now, to: record)

        for item in items {
            let itemRecord = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: viewContext)
            let itemId = item.id > 0 ? item.id : nextLocalId
            if item.id == 0 {
                nextLocalId += 1
            }
            PersistenceMappers.apply(
                item,
                assignedId: itemId,
                planId: planId,
                planSyncId: item.planSyncId ?? plan.syncId,
                subjectId: item.subjectId,
                now: now,
                to: itemRecord
            )
        }

        try saveViewContext()
        try recalculatePlanActualMinutesOnViewContext()
        return planId
    }

    func insertPlanItem(_ item: PlanItem) async throws -> Int64 {
        try await ensureLoaded()
        let itemId = try nextIdentifier(ifNeeded: item.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: viewContext)
        PersistenceMappers.apply(
            item,
            assignedId: itemId,
            planId: item.planId,
            planSyncId: item.planSyncId,
            subjectId: item.subjectId,
            now: now,
            to: record
        )
        try saveViewContext()
        try recalculatePlanActualMinutesOnViewContext()
        return itemId
    }

    func updatePlanItem(_ item: PlanItem) async throws {
        try await ensureLoaded()
        guard let record = try CoreDataQuery.fetchOne("PlanItemRecord", id: item.id, in: viewContext) else { return }
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
        try saveViewContext()
        try recalculatePlanActualMinutesOnViewContext()
    }

    func deletePlanItem(_ item: PlanItem) async throws {
        try await ensureLoaded()
        if let record = try CoreDataQuery.fetchOne("PlanItemRecord", id: item.id, in: viewContext) {
            let now = Date().epochMilliseconds
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            try saveViewContext()
            try recalculatePlanActualMinutesOnViewContext()
        }
    }

    func deletePlan(_ plan: StudyPlan) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try CoreDataQuery.fetchOne("StudyPlanRecord", id: plan.id, in: viewContext) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            record.setValue(false, forKey: "isActive")
        }
        let items = try CoreDataQuery.fetch(
            "PlanItemRecord",
            in: viewContext,
            predicate: NSPredicate(format: "planId == %lld", plan.id)
        )
        for item in items {
            item.setValue(now, forKey: "deletedAt")
            item.setValue(now, forKey: "updatedAt")
        }
        try saveViewContext()
    }

    // MARK: - TimetableRepository

    func getAllTimetablePeriods() async throws -> [TimetablePeriod] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "TimetablePeriodRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "sortOrder", ascending: true), NSSortDescriptor(key: "startMinute", ascending: true)]
        ).map(PersistenceMappers.timetablePeriod).filter { $0.deletedAt == nil && $0.isActive }
    }

    func saveTimetablePeriod(_ period: TimetablePeriod) async throws -> Int64 {
        try await ensureLoaded()
        guard period.startMinute < period.endMinute else {
            throw ValidationError(message: "終了時刻は開始時刻より後にしてください")
        }
        let now = Date().epochMilliseconds
        if period.id > 0, let record = try CoreDataQuery.fetchOne("TimetablePeriodRecord", id: period.id, in: viewContext) {
            var updated = period
            updated.syncId = (record.value(forKey: "syncId") as? String)?.nilIfBlank ?? period.syncId
            updated.createdAt = record.value(forKey: "createdAt") as? Int64 ?? period.createdAt
            updated.updatedAt = now
            PersistenceMappers.apply(updated, assignedId: period.id, now: now, to: record)
            try saveViewContext()
            return period.id
        }

        let id = try nextIdentifier(ifNeeded: period.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "TimetablePeriodRecord", into: viewContext)
        PersistenceMappers.apply(period, assignedId: id, now: now, to: record)
        try saveViewContext()
        return id
    }

    func deleteTimetablePeriod(_ period: TimetablePeriod) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try CoreDataQuery.fetchOne("TimetablePeriodRecord", id: period.id, in: viewContext) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
        }
        let entries = try CoreDataQuery.fetch(
            "TimetableEntryRecord",
            in: viewContext,
            predicate: NSPredicate(format: "periodId == %lld", period.id)
        )
        for entry in entries {
            entry.setValue(now, forKey: "deletedAt")
            entry.setValue(now, forKey: "updatedAt")
        }
        try saveViewContext()
    }

    func getAllTimetableTerms() async throws -> [TimetableTerm] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "TimetableTermRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "startDate", ascending: false), NSSortDescriptor(key: "endDate", ascending: false)]
        ).map(PersistenceMappers.timetableTerm).filter { $0.deletedAt == nil && $0.isActive }
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
        if term.id > 0, let record = try CoreDataQuery.fetchOne("TimetableTermRecord", id: term.id, in: viewContext) {
            var updated = term
            updated.syncId = (record.value(forKey: "syncId") as? String)?.nilIfBlank ?? term.syncId
            updated.name = name
            updated.createdAt = record.value(forKey: "createdAt") as? Int64 ?? term.createdAt
            updated.updatedAt = now
            PersistenceMappers.apply(updated, assignedId: term.id, now: now, to: record)
            try saveViewContext()
            return term.id
        }

        var inserted = term
        inserted.name = name
        let id = try nextIdentifier(ifNeeded: term.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "TimetableTermRecord", into: viewContext)
        PersistenceMappers.apply(inserted, assignedId: id, now: now, to: record)
        try saveViewContext()
        return id
    }

    func deleteTimetableTerm(_ term: TimetableTerm) async throws {
        try await ensureLoaded()
        let now = Date().epochMilliseconds
        if let record = try CoreDataQuery.fetchOne("TimetableTermRecord", id: term.id, in: viewContext) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
            record.setValue(false, forKey: "isActive")
        }
        let entries = try CoreDataQuery.fetch(
            "TimetableEntryRecord",
            in: viewContext,
            predicate: NSPredicate(format: "termId == %lld", term.id)
        )
        for entry in entries {
            entry.setValue(now, forKey: "deletedAt")
            entry.setValue(now, forKey: "updatedAt")
        }
        try saveViewContext()
    }

    func getAllTimetableEntries() async throws -> [TimetableEntry] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "TimetableEntryRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true), NSSortDescriptor(key: "periodId", ascending: true)]
        ).map(PersistenceMappers.timetableEntry).filter { $0.deletedAt == nil }
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
        guard let period = try CoreDataQuery.fetchOne("TimetablePeriodRecord", id: entry.periodId, in: viewContext).map(PersistenceMappers.timetablePeriod),
              period.deletedAt == nil,
              period.isActive else {
            throw ValidationError(message: "有効な時限を選択してください")
        }
        let resolvedTermSyncId: String?
        if let termId = entry.termId {
            guard let term = try CoreDataQuery.fetchOne("TimetableTermRecord", id: termId, in: viewContext).map(PersistenceMappers.timetableTerm),
                  term.deletedAt == nil,
                  term.isActive else {
                throw ValidationError(message: "有効な学期を選択してください")
            }
            resolvedTermSyncId = term.syncId
        } else {
            resolvedTermSyncId = nil
        }

        let now = Date().epochMilliseconds
        let existing = try CoreDataQuery.fetch(
            "TimetableEntryRecord",
            in: viewContext,
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
            currentRecord = try CoreDataQuery.fetchOne("TimetableEntryRecord", id: entry.id, in: viewContext)
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
            PersistenceMappers.apply(updated, assignedId: assignedId, termId: entry.termId, termSyncId: updated.termSyncId, periodId: period.id, periodSyncId: period.syncId, now: now, to: record)
            try saveViewContext()
            return assignedId
        }

        var inserted = entry
        inserted.subjectName = subjectName
        inserted.courseName = entry.courseName?.nilIfBlank
        inserted.roomName = entry.roomName?.nilIfBlank
        inserted.periodSyncId = period.syncId
        inserted.termSyncId = resolvedTermSyncId
        let id = try nextIdentifier(ifNeeded: entry.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "TimetableEntryRecord", into: viewContext)
        PersistenceMappers.apply(inserted, assignedId: id, termId: entry.termId, termSyncId: inserted.termSyncId, periodId: period.id, periodSyncId: period.syncId, now: now, to: record)
        try saveViewContext()
        return id
    }

    func deleteTimetableEntry(_ entry: TimetableEntry) async throws {
        try await ensureLoaded()
        guard let record = try CoreDataQuery.fetchOne("TimetableEntryRecord", id: entry.id, in: viewContext) else { return }
        let now = Date().epochMilliseconds
        record.setValue(now, forKey: "deletedAt")
        record.setValue(now, forKey: "updatedAt")
        try saveViewContext()
    }

    func getAllTimetableReviewRecords() async throws -> [TimetableReviewRecord] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "TimetableReviewRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "occurrenceDate", ascending: false), NSSortDescriptor(key: "periodStartMinute", ascending: true)]
        ).map(PersistenceMappers.timetableReviewRecord).filter { $0.deletedAt == nil }
    }

    func saveTimetableReviewRecord(_ record: TimetableReviewRecord) async throws -> Int64 {
        try await ensureLoaded()
        guard record.termId > 0, record.entryId > 0, record.periodId > 0 else {
            throw ValidationError(message: "復習対象の授業が正しくありません")
        }
        let now = Date().epochMilliseconds
        let existing = try CoreDataQuery.fetch(
            "TimetableReviewRecord",
            in: viewContext,
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
            PersistenceMappers.apply(updated, assignedId: assignedId, now: now, to: existing)
            try saveViewContext()
            return assignedId
        }

        let id = try nextIdentifier(ifNeeded: record.id)
        let object = NSEntityDescription.insertNewObject(forEntityName: "TimetableReviewRecord", into: viewContext)
        PersistenceMappers.apply(record, assignedId: id, now: now, to: object)
        try saveViewContext()
        return id
    }

    func deleteTimetableReviewRecord(_ record: TimetableReviewRecord) async throws {
        try await ensureLoaded()
        guard let object = try CoreDataQuery.fetchOne("TimetableReviewRecord", id: record.id, in: viewContext) else { return }
        let now = Date().epochMilliseconds
        object.setValue(now, forKey: "deletedAt")
        object.setValue(now, forKey: "updatedAt")
        try saveViewContext()
    }

    /// Potentially expensive scan — offloaded to the background context so
    /// reminder refresh does not block the main thread.
    func overdueTimetableReviewCount(reference: Date = Date()) async throws -> Int {
        try await ensureLoaded()
        return try await backgroundRead { ctx in
            try TimetableOverdueCalculator.overdueCount(reference: reference, in: ctx)
        }
    }

    // MARK: - ProblemReviewRepository

    func getAllProblemReviewRecords() async throws -> [ProblemReviewRecord] {
        try await ensureLoaded()
        return try CoreDataQuery.fetch(
            "ProblemReviewRecord",
            in: viewContext,
            sort: [NSSortDescriptor(key: "reviewedAt", ascending: false)]
        ).map(PersistenceMappers.problemReviewRecord).filter { $0.deletedAt == nil }
    }

    func getTodayReviewProblems(reference: Date = Date()) async throws -> [TodayReviewProblem] {
        try await ensureLoaded()
        let calendar = Calendar.current
        let dueEnd = (calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: reference)) ?? reference).epochMilliseconds - 1
        let reviews = try CoreDataQuery.fetch(
            "ProblemReviewRecord",
            in: viewContext,
            predicate: NSPredicate(format: "deletedAt == NIL"),
            sort: [NSSortDescriptor(key: "reviewedAt", ascending: false)]
        ).map(PersistenceMappers.problemReviewRecord)
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
                    problemLabel: material.problemLabel(for: review.problemNumber),
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

    // MARK: - AppDataRepository

    /// Builds the full export on a background context. The backfill step may
    /// mutate records to populate missing sync metadata; the export itself is
    /// read-only.
    func exportData() async throws -> AppData {
        try await ensureLoaded()
        try await backgroundWrite { ctx in
            _ = try SyncMetadataBackfiller.backfill(in: ctx)
        }
        return try await backgroundRead { ctx in
            try AppDataArchiver.buildExport(in: ctx)
        }
    }

    /// Encodes the export as pretty-printed JSON entirely off the main thread.
    func exportJSON() async throws -> String {
        try await ensureLoaded()
        try await backgroundWrite { ctx in
            _ = try SyncMetadataBackfiller.backfill(in: ctx)
        }
        return try await backgroundContext.perform { [backgroundContext] in
            let appData = try AppDataArchiver.buildExport(in: backgroundContext)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let bytes = try encoder.encode(appData)
            guard let json = String(data: bytes, encoding: .utf8) else {
                throw CocoaError(.coderInvalidValue)
            }
            return json
        }
    }

    func exportCSV() async throws -> String {
        let sessions = try await getAllSessions()
        return AppDataArchiver.buildSessionsCSV(from: sessions)
    }

    /// Decodes JSON and replaces the persistent store on the background
    /// context, then recomputes plan actual minutes in the same pass so the
    /// saved data is immediately coherent.
    func importJSON(_ json: String, currentPreferences: AppPreferences) async throws -> AppPreferences {
        try await ensureLoaded()
        let jsonData = Data(json.utf8)
        try await backgroundContext.perform { [backgroundContext] in
            do {
                let appData = try JSONDecoder().decode(AppData.self, from: jsonData)
                try AppDataArchiver.replaceData(with: appData, in: backgroundContext)
                try PlanActualMinutesRecalculator.recalculate(in: backgroundContext)
                try backgroundContext.save()
            } catch {
                backgroundContext.rollback()
                throw error
            }
        }
        changeToken += 1
        return currentPreferences
    }

    /// Wipes every entity using batch deletes on the background context.
    /// Changes merge into `viewContext` automatically via the parent context.
    func deleteAllData() async throws {
        try await ensureLoaded()
        var deletedObjectIDs: [NSManagedObjectID] = []
        try await backgroundContext.perform { [backgroundContext] in
            for entity in CoreDataSchema.entityNames {
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
                let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
                deleteRequest.resultType = .resultTypeObjectIDs
                let result = try backgroundContext.execute(deleteRequest) as? NSBatchDeleteResult
                let objectIDs = result?.result as? [NSManagedObjectID] ?? []
                deletedObjectIDs.append(contentsOf: objectIDs)
            }
        }
        guard !deletedObjectIDs.isEmpty else { return }
        NSManagedObjectContext.mergeChanges(
            fromRemoteContextSave: [NSDeletedObjectsKey: deletedObjectIDs],
            into: [viewContext]
        )
        changeToken += 1
    }

    /// One-time migration from the legacy ``studyapp-store.json`` flat file.
    /// Decoding and the wholesale replace both happen on the background
    /// context.
    func migrateLegacySnapshotIfNeeded(preferencesRepository: AppPreferencesRepository) async throws {
        try await ensureLoaded()
        let alreadyPopulated = try await backgroundRead { ctx in
            !(try CoreDataQuery.isEmpty(in: ctx, entities: CoreDataSchema.entityNames))
        }
        guard !alreadyPopulated, fileManager.fileExists(atPath: legacyURL.path) else {
            return
        }

        let data = try Data(contentsOf: legacyURL)
        let capturedPreferences: AppPreferences = try await backgroundContext.perform { [backgroundContext] in
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .millisecondsSince1970
            let snapshot = try decoder.decode(LegacySnapshot.self, from: data)
            let appData = AppDataArchiver.convert(legacy: snapshot)
            do {
                try AppDataArchiver.replaceData(with: appData, in: backgroundContext)
                try PlanActualMinutesRecalculator.recalculate(in: backgroundContext)
                try backgroundContext.save()
            } catch {
                backgroundContext.rollback()
                throw error
            }
            return snapshot.preferences
        }
        preferencesRepository.savePreferences(capturedPreferences)
        changeToken += 1

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

    // MARK: - Private helpers

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

    private func recalculatePlanActualMinutesOnViewContext() throws {
        try PlanActualMinutesRecalculator.recalculate(in: viewContext)
        try saveViewContext()
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

    private func applySession(_ session: StudySession, to record: NSManagedObject) {
        PersistenceMappers.apply(
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
            let mutated = try LegacyDailyGoalNormalizer.normalize(in: viewContext)
            if mutated {
                try saveViewContext()
            }
            didNormalizeLegacyDailyGoals = true
        }
    }

    private func nextIdentifier(ifNeeded requested: Int64) throws -> Int64 {
        if requested > 0 {
            return requested
        }
        return try CoreDataQuery.maxIdentifier(in: viewContext, entities: CoreDataSchema.entityNames) + 1
    }

    private func saveViewContext() throws {
        if viewContext.hasChanges {
            try viewContext.save()
            changeToken += 1
        }
    }

    /// Runs a read-only block on the background context's private queue.
    private func backgroundRead<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let ctx = backgroundContext
        return try await ctx.perform {
            try block(ctx)
        }
    }

    /// Runs a mutating block on the background context and saves if there are
    /// changes. The view context picks up the merge automatically.
    private func backgroundWrite<T>(_ block: @escaping (NSManagedObjectContext) throws -> T) async throws -> T {
        let ctx = backgroundContext
        let result = try await ctx.perform {
            let value = try block(ctx)
            if ctx.hasChanges {
                try ctx.save()
            }
            return value
        }
        changeToken += 1
        return result
    }
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
