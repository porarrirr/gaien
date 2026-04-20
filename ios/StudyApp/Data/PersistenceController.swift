import CoreData
import Foundation

@MainActor
final class PersistenceController: SubjectRepository, MaterialRepository, StudySessionRepository, GoalRepository, ExamRepository, PlanRepository, AppDataRepository {
    static let shared = PersistenceController()

    private let container: NSPersistentContainer
    private let fileManager: FileManager
    private let loadTask: Task<Void, Error>
    private let legacyURL: URL
    private(set) var changeToken: Int64 = 0

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
        record.setValue(id, forKey: "id")
        record.setValue(subject.syncId, forKey: "syncId")
        record.setValue(subject.name, forKey: "name")
        record.setValue(Int64(subject.color), forKey: "color")
        record.setValue(subject.icon?.rawValue, forKey: "icon")
        record.setValue(subject.createdAt == 0 ? now : subject.createdAt, forKey: "createdAt")
        record.setValue(subject.updatedAt == 0 ? now : subject.updatedAt, forKey: "updatedAt")
        record.setValue(subject.deletedAt, forKey: "deletedAt")
        record.setValue(subject.lastSyncedAt, forKey: "lastSyncedAt")
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
        if let record = try fetchOne(entity: "SubjectRecord", id: subject.id) {
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
        }
        try saveContext()
    }

    func getAllMaterials() async throws -> [Material] {
        try await ensureLoaded()
        return try fetch(entity: "MaterialRecord", sort: [NSSortDescriptor(key: "id", ascending: false)]).map(Self.material).filter { $0.deletedAt == nil }
    }

    func getMaterialsBySubjectId(_ subjectId: Int64) async throws -> [Material] {
        try await ensureLoaded()
        return try fetch(
            entity: "MaterialRecord",
            predicate: NSPredicate(format: "subjectId == %lld", subjectId),
            sort: [NSSortDescriptor(key: "id", ascending: false)]
        ).map(Self.material).filter { $0.deletedAt == nil }
    }

    func insertMaterial(_ material: Material) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: material.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: container.viewContext)
        record.setValue(id, forKey: "id")
        record.setValue(material.syncId, forKey: "syncId")
        record.setValue(material.name, forKey: "name")
        record.setValue(material.subjectId, forKey: "subjectId")
        record.setValue(material.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(Int64(material.totalPages), forKey: "totalPages")
        record.setValue(Int64(material.currentPage), forKey: "currentPage")
        record.setValue(material.color.map { Int64($0) }, forKey: "color")
        record.setValue(material.note, forKey: "note")
        record.setValue(material.createdAt == 0 ? now : material.createdAt, forKey: "createdAt")
        record.setValue(material.updatedAt == 0 ? now : material.updatedAt, forKey: "updatedAt")
        record.setValue(material.deletedAt, forKey: "deletedAt")
        record.setValue(material.lastSyncedAt, forKey: "lastSyncedAt")
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
        record.setValue(Int64(material.totalPages), forKey: "totalPages")
        record.setValue(Int64(material.currentPage), forKey: "currentPage")
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

    func updateSession(_ session: StudySession) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "StudySessionRecord", id: session.id) else { return }
        let sanitized = sanitize(
            session: session,
            assignedId: session.id,
            persistedSyncId: record.value(forKey: "syncId") as? String,
            persistedCreatedAt: record.value(forKey: "createdAt") as? Int64,
            persistedLastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
        apply(sanitized, to: record)
        try saveContext()
        try await recalculatePlanActualMinutes()
    }

    func deleteSession(_ session: StudySession) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "StudySessionRecord", id: session.id) {
            let now = Date().epochMilliseconds
            record.setValue(now, forKey: "deletedAt")
            record.setValue(now, forKey: "updatedAt")
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
        let predicate = NSPredicate(format: "type == %@ AND isActive == YES", type.rawValue)
        return try fetch(entity: "GoalRecord", predicate: predicate, sort: [NSSortDescriptor(key: "updatedAt", ascending: false)]).map(Self.goal).first(where: { $0.deletedAt == nil })
    }

    func insertGoal(_ goal: Goal) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: goal.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: container.viewContext)
        record.setValue(id, forKey: "id")
        record.setValue(goal.syncId, forKey: "syncId")
        record.setValue(goal.type.rawValue, forKey: "type")
        record.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
        record.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
        record.setValue(goal.isActive, forKey: "isActive")
        record.setValue(goal.createdAt == 0 ? now : goal.createdAt, forKey: "createdAt")
        record.setValue(goal.updatedAt == 0 ? now : goal.updatedAt, forKey: "updatedAt")
        record.setValue(goal.deletedAt, forKey: "deletedAt")
        record.setValue(goal.lastSyncedAt, forKey: "lastSyncedAt")
        try saveContext()
        return id
    }

    func updateGoal(_ goal: Goal) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "GoalRecord", id: goal.id) else { return }
        record.setValue(goal.type.rawValue, forKey: "type")
        record.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
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
        record.setValue(id, forKey: "id")
        record.setValue(exam.syncId, forKey: "syncId")
        record.setValue(exam.name, forKey: "name")
        record.setValue(exam.date, forKey: "date")
        record.setValue(exam.note, forKey: "note")
        record.setValue(exam.createdAt == 0 ? now : exam.createdAt, forKey: "createdAt")
        record.setValue(exam.updatedAt == 0 ? now : exam.updatedAt, forKey: "updatedAt")
        record.setValue(exam.deletedAt, forKey: "deletedAt")
        record.setValue(exam.lastSyncedAt, forKey: "lastSyncedAt")
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
        let record = NSEntityDescription.insertNewObject(forEntityName: "StudyPlanRecord", into: container.viewContext)
        record.setValue(planId, forKey: "id")
        record.setValue(plan.syncId, forKey: "syncId")
        record.setValue(plan.name, forKey: "name")
        record.setValue(plan.startDate, forKey: "startDate")
        record.setValue(plan.endDate, forKey: "endDate")
        record.setValue(plan.isActive, forKey: "isActive")
        record.setValue(plan.createdAt == 0 ? Date().epochMilliseconds : plan.createdAt, forKey: "createdAt")
        record.setValue(plan.updatedAt == 0 ? Date().epochMilliseconds : plan.updatedAt, forKey: "updatedAt")
        record.setValue(plan.deletedAt, forKey: "deletedAt")
        record.setValue(plan.lastSyncedAt, forKey: "lastSyncedAt")

        for item in items {
            let itemRecord = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: container.viewContext)
            let itemId = item.id > 0 ? item.id : nextLocalId
            if item.id == 0 {
                nextLocalId += 1
            }
            itemRecord.setValue(itemId, forKey: "id")
            itemRecord.setValue(item.syncId, forKey: "syncId")
            itemRecord.setValue(planId, forKey: "planId")
            itemRecord.setValue(item.planSyncId ?? plan.syncId, forKey: "planSyncId")
            itemRecord.setValue(item.subjectId, forKey: "subjectId")
            itemRecord.setValue(item.subjectSyncId, forKey: "subjectSyncId")
            itemRecord.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
            itemRecord.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
            itemRecord.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
            itemRecord.setValue(item.timeSlot, forKey: "timeSlot")
            itemRecord.setValue(item.createdAt == 0 ? Date().epochMilliseconds : item.createdAt, forKey: "createdAt")
            itemRecord.setValue(item.updatedAt == 0 ? Date().epochMilliseconds : item.updatedAt, forKey: "updatedAt")
            itemRecord.setValue(item.deletedAt, forKey: "deletedAt")
            itemRecord.setValue(item.lastSyncedAt, forKey: "lastSyncedAt")
        }

        try saveContext()
        try await recalculatePlanActualMinutes()
        return planId
    }

    func insertPlanItem(_ item: PlanItem) async throws -> Int64 {
        try await ensureLoaded()
        let itemId = try nextIdentifier(ifNeeded: item.id)
        let record = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: container.viewContext)
        record.setValue(itemId, forKey: "id")
        record.setValue(item.syncId, forKey: "syncId")
        record.setValue(item.planId, forKey: "planId")
        record.setValue(item.planSyncId, forKey: "planSyncId")
        record.setValue(item.subjectId, forKey: "subjectId")
        record.setValue(item.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
        record.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
        record.setValue(item.timeSlot, forKey: "timeSlot")
        record.setValue(item.createdAt == 0 ? Date().epochMilliseconds : item.createdAt, forKey: "createdAt")
        record.setValue(item.updatedAt == 0 ? Date().epochMilliseconds : item.updatedAt, forKey: "updatedAt")
        record.setValue(item.deletedAt, forKey: "deletedAt")
        record.setValue(item.lastSyncedAt, forKey: "lastSyncedAt")
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

    func exportData() async throws -> AppData {
        try await ensureLoaded()
        try backfillMissingSyncMetadataIfNeeded()
        let subjects = try fetch(entity: "SubjectRecord", sort: [NSSortDescriptor(key: "name", ascending: true)]).map(Self.subject)
        let materials = try fetch(entity: "MaterialRecord", sort: [NSSortDescriptor(key: "id", ascending: false)]).map(Self.material)
        let sessions = try fetch(entity: "StudySessionRecord", sort: [NSSortDescriptor(key: "startTime", ascending: false)]).map(Self.session)
        let goals = try fetch(entity: "GoalRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: true)]).map(Self.goal)
        let exams = try fetch(entity: "ExamRecord", sort: [NSSortDescriptor(key: "date", ascending: true)]).map(Self.exam)
        let plans = try fetch(entity: "StudyPlanRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: false)]).map(Self.plan)

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
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "ja_JP")
        dateFormatter.dateFormat = "yyyy/MM/dd"
        let timeFormatter = DateFormatter()
        timeFormatter.locale = Locale(identifier: "ja_JP")
        timeFormatter.dateFormat = "HH:mm"
        let header = "日付,科目,教材,開始時刻,終了時刻,時間(分),メモ\n"
        let rows = sessions.map { session in
            [
                csvEscaped(dateFormatter.string(from: session.startDate)),
                csvEscaped(session.subjectName),
                csvEscaped(session.materialName),
                csvEscaped(timeFormatter.string(from: session.startDate)),
                csvEscaped(timeFormatter.string(from: session.endDate)),
                "\(session.durationMinutes)",
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
                Goal(id: $0.id, type: $0.type, targetMinutes: $0.targetMinutes, weekStartDay: $0.weekStartDay, isActive: $0.isActive)
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
            importedPlanItemIds.max() ?? 0
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

        // --- Subjects ---
        for subject in appData.subjects {
            let localId = allocateId(preferred: existingSubjectIds[subject.syncId] ?? subject.id)
            subjectSyncMap[subject.syncId] = localId
            if subject.id > 0 { subjectOldMap[subject.id] = localId }

            let r = NSEntityDescription.insertNewObject(forEntityName: "SubjectRecord", into: ctx)
            r.setValue(localId, forKey: "id")
            r.setValue(subject.syncId, forKey: "syncId")
            r.setValue(subject.name, forKey: "name")
            r.setValue(Int64(subject.color), forKey: "color")
            r.setValue(subject.icon?.rawValue, forKey: "icon")
            r.setValue(subject.createdAt == 0 ? now : subject.createdAt, forKey: "createdAt")
            r.setValue(subject.updatedAt == 0 ? now : subject.updatedAt, forKey: "updatedAt")
            r.setValue(subject.deletedAt, forKey: "deletedAt")
            r.setValue(subject.lastSyncedAt, forKey: "lastSyncedAt")
        }

        // --- Materials ---
        for material in appData.materials {
            let localId = allocateId(preferred: existingMaterialIds[material.syncId] ?? material.id)
            materialSyncMap[material.syncId] = localId
            if material.id > 0 { materialOldMap[material.id] = localId }

            let subjectId: Int64 = Self.resolveFK(
                syncId: material.subjectSyncId, syncMap: subjectSyncMap,
                oldId: material.subjectId, oldMap: subjectOldMap)

            let r = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: ctx)
            r.setValue(localId, forKey: "id")
            r.setValue(material.syncId, forKey: "syncId")
            r.setValue(material.name, forKey: "name")
            r.setValue(subjectId, forKey: "subjectId")
            r.setValue(material.subjectSyncId, forKey: "subjectSyncId")
            r.setValue(Int64(material.totalPages), forKey: "totalPages")
            r.setValue(Int64(material.currentPage), forKey: "currentPage")
            r.setValue(material.color.map { Int64($0) }, forKey: "color")
            r.setValue(material.note, forKey: "note")
            r.setValue(material.createdAt == 0 ? now : material.createdAt, forKey: "createdAt")
            r.setValue(material.updatedAt == 0 ? now : material.updatedAt, forKey: "updatedAt")
            r.setValue(material.deletedAt, forKey: "deletedAt")
            r.setValue(material.lastSyncedAt, forKey: "lastSyncedAt")
        }

        // --- Sessions ---
        for session in appData.sessions {
            let localId = allocateId(preferred: existingSessionIds[session.syncId] ?? session.id)

            let subjectId = Self.resolveFK(
                syncId: session.subjectSyncId, syncMap: subjectSyncMap,
                oldId: session.subjectId, oldMap: subjectOldMap)
            let materialId = Self.resolveOptFK(
                syncId: session.materialSyncId, syncMap: materialSyncMap,
                oldId: session.materialId, oldMap: materialOldMap)

            let duration = max(session.endTime - session.startTime, 0)
            let endTime = session.startTime + duration
            let date = Date(epochMilliseconds: session.startTime).epochDay

            let r = NSEntityDescription.insertNewObject(forEntityName: "StudySessionRecord", into: ctx)
            r.setValue(localId, forKey: "id")
            r.setValue(session.syncId, forKey: "syncId")
            r.setValue(materialId, forKey: "materialId")
            r.setValue(session.materialSyncId, forKey: "materialSyncId")
            r.setValue(session.materialName, forKey: "materialName")
            r.setValue(subjectId, forKey: "subjectId")
            r.setValue(session.subjectSyncId, forKey: "subjectSyncId")
            r.setValue(session.subjectName, forKey: "subjectName")
            r.setValue(session.startTime, forKey: "startTime")
            r.setValue(endTime, forKey: "endTime")
            r.setValue(duration, forKey: "duration")
            r.setValue(date, forKey: "date")
            r.setValue(session.note, forKey: "note")
            r.setValue(session.createdAt == 0 ? now : session.createdAt, forKey: "createdAt")
            r.setValue(session.updatedAt == 0 ? now : session.updatedAt, forKey: "updatedAt")
            r.setValue(session.deletedAt, forKey: "deletedAt")
            r.setValue(session.lastSyncedAt, forKey: "lastSyncedAt")
        }

        // --- Goals ---
        for goal in appData.goals {
            let localId = allocateId(preferred: existingGoalIds[goal.syncId] ?? goal.id)
            let r = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: ctx)
            r.setValue(localId, forKey: "id")
            r.setValue(goal.syncId, forKey: "syncId")
            r.setValue(goal.type.rawValue, forKey: "type")
            r.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
            r.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
            r.setValue(goal.isActive, forKey: "isActive")
            r.setValue(goal.createdAt == 0 ? now : goal.createdAt, forKey: "createdAt")
            r.setValue(goal.updatedAt == 0 ? now : goal.updatedAt, forKey: "updatedAt")
            r.setValue(goal.deletedAt, forKey: "deletedAt")
            r.setValue(goal.lastSyncedAt, forKey: "lastSyncedAt")
        }

        // --- Exams ---
        for exam in appData.exams {
            let localId = allocateId(preferred: existingExamIds[exam.syncId] ?? exam.id)
            let r = NSEntityDescription.insertNewObject(forEntityName: "ExamRecord", into: ctx)
            r.setValue(localId, forKey: "id")
            r.setValue(exam.syncId, forKey: "syncId")
            r.setValue(exam.name, forKey: "name")
            r.setValue(exam.date, forKey: "date")
            r.setValue(exam.note, forKey: "note")
            r.setValue(exam.createdAt == 0 ? now : exam.createdAt, forKey: "createdAt")
            r.setValue(exam.updatedAt == 0 ? now : exam.updatedAt, forKey: "updatedAt")
            r.setValue(exam.deletedAt, forKey: "deletedAt")
            r.setValue(exam.lastSyncedAt, forKey: "lastSyncedAt")
        }

        // --- Plans & PlanItems (preserve isActive as-is; no deactivation side-effects) ---
        for planData in appData.plans {
            let plan = planData.plan
            let localPlanId = allocateId(preferred: existingPlanIds[plan.syncId] ?? plan.id)
            planSyncMap[plan.syncId] = localPlanId
            if plan.id > 0 { planOldMap[plan.id] = localPlanId }

            let pr = NSEntityDescription.insertNewObject(forEntityName: "StudyPlanRecord", into: ctx)
            pr.setValue(localPlanId, forKey: "id")
            pr.setValue(plan.syncId, forKey: "syncId")
            pr.setValue(plan.name, forKey: "name")
            pr.setValue(plan.startDate, forKey: "startDate")
            pr.setValue(plan.endDate, forKey: "endDate")
            pr.setValue(plan.isActive, forKey: "isActive")
            pr.setValue(plan.createdAt == 0 ? now : plan.createdAt, forKey: "createdAt")
            pr.setValue(plan.updatedAt == 0 ? now : plan.updatedAt, forKey: "updatedAt")
            pr.setValue(plan.deletedAt, forKey: "deletedAt")
            pr.setValue(plan.lastSyncedAt, forKey: "lastSyncedAt")

            for item in planData.items {
                let localItemId = allocateId(preferred: existingPlanItemIds[item.syncId] ?? item.id)
                let itemSubjectId = Self.resolveFK(
                    syncId: item.subjectSyncId, syncMap: subjectSyncMap,
                    oldId: item.subjectId, oldMap: subjectOldMap)

                let ir = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: ctx)
                ir.setValue(localItemId, forKey: "id")
                ir.setValue(item.syncId, forKey: "syncId")
                ir.setValue(localPlanId, forKey: "planId")
                ir.setValue(item.planSyncId ?? plan.syncId, forKey: "planSyncId")
                ir.setValue(itemSubjectId, forKey: "subjectId")
                ir.setValue(item.subjectSyncId, forKey: "subjectSyncId")
                ir.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
                ir.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
                ir.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
                ir.setValue(item.timeSlot, forKey: "timeSlot")
                ir.setValue(item.createdAt == 0 ? now : item.createdAt, forKey: "createdAt")
                ir.setValue(item.updatedAt == 0 ? now : item.updatedAt, forKey: "updatedAt")
                ir.setValue(item.deletedAt, forKey: "deletedAt")
                ir.setValue(item.lastSyncedAt, forKey: "lastSyncedAt")
            }
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
        let duration = max(session.endTime - session.startTime, 0)
        let end = session.startTime + duration
        return StudySession(
            id: assignedId,
            syncId: persistedSyncId ?? session.syncId,
            materialId: session.materialId,
            materialSyncId: session.materialSyncId,
            materialName: session.materialName,
            subjectId: session.subjectId,
            subjectSyncId: session.subjectSyncId,
            subjectName: session.subjectName,
            startTime: session.startTime,
            endTime: end,
            note: session.note,
            createdAt: persistedCreatedAt ?? (session.createdAt == 0 ? Date().epochMilliseconds : session.createdAt),
            updatedAt: Date().epochMilliseconds,
            deletedAt: session.deletedAt,
            lastSyncedAt: persistedLastSyncedAt ?? session.lastSyncedAt
        )
    }

    private func apply(_ session: StudySession, to record: NSManagedObject) {
        record.setValue(session.id, forKey: "id")
        record.setValue(session.syncId, forKey: "syncId")
        record.setValue(session.materialId, forKey: "materialId")
        record.setValue(session.materialSyncId, forKey: "materialSyncId")
        record.setValue(session.materialName, forKey: "materialName")
        record.setValue(session.subjectId, forKey: "subjectId")
        record.setValue(session.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(session.subjectName, forKey: "subjectName")
        record.setValue(session.startTime, forKey: "startTime")
        record.setValue(session.endTime, forKey: "endTime")
        record.setValue(session.duration, forKey: "duration")
        record.setValue(session.date, forKey: "date")
        record.setValue(session.note, forKey: "note")
        record.setValue(session.createdAt, forKey: "createdAt")
        record.setValue(session.updatedAt, forKey: "updatedAt")
        record.setValue(session.deletedAt, forKey: "deletedAt")
        record.setValue(session.lastSyncedAt, forKey: "lastSyncedAt")
    }

    private func ensureLoaded() async throws {
        try await loadTask.value
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
        return maxId + 1
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
            totalPages: Int(record.value(forKey: "totalPages") as? Int64 ?? 0),
            currentPage: Int(record.value(forKey: "currentPage") as? Int64 ?? 0),
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
            startTime: record.value(forKey: "startTime") as? Int64 ?? 0,
            endTime: record.value(forKey: "endTime") as? Int64 ?? 0,
            note: record.value(forKey: "note") as? String,
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
                    attribute(name: "totalPages", type: .integer64AttributeType),
                    attribute(name: "currentPage", type: .integer64AttributeType),
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
                    attribute(name: "startTime", type: .integer64AttributeType),
                    attribute(name: "endTime", type: .integer64AttributeType),
                    attribute(name: "duration", type: .integer64AttributeType),
                    attribute(name: "date", type: .integer64AttributeType),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
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

    private static func attribute(name: String, type: NSAttributeType, optional: Bool = false) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        return attribute
    }

    private static let entityNames = [
        "SubjectRecord",
        "MaterialRecord",
        "StudySessionRecord",
        "GoalRecord",
        "ExamRecord",
        "StudyPlanRecord",
        "PlanItemRecord"
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

private struct LegacySnapshot: Codable {
    var subjects: [LegacySubject] = []
    var materials: [LegacyMaterial] = []
    var sessions: [LegacySession] = []
    var goals: [LegacyGoal] = []
    var exams: [LegacyExam] = []
    var plans: [LegacyPlan] = []
    var planItems: [LegacyPlanItem] = []
    var onboardingCompleted = false
    var reminderEnabled = false
    var reminderHour = 19
    var reminderMinute = 0
    var selectedColorTheme: ColorTheme = .green
    var selectedThemeMode: ThemeMode = .system
    var liveActivityEnabled = true
    var liveActivityDisplayPreset: LiveActivityDisplayPreset = .standard
    var activeTimer: LegacyTimerSnapshot?

    private enum CodingKeys: String, CodingKey {
        case subjects
        case materials
        case sessions
        case goals
        case exams
        case plans
        case planItems
        case onboardingCompleted
        case reminderEnabled
        case reminderHour
        case reminderMinute
        case selectedColorTheme
        case selectedThemeMode
        case liveActivityEnabled
        case liveActivityDisplayPreset
        case activeTimer
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subjects = try container.decodeIfPresent([LegacySubject].self, forKey: .subjects) ?? []
        materials = try container.decodeIfPresent([LegacyMaterial].self, forKey: .materials) ?? []
        sessions = try container.decodeIfPresent([LegacySession].self, forKey: .sessions) ?? []
        goals = try container.decodeIfPresent([LegacyGoal].self, forKey: .goals) ?? []
        exams = try container.decodeIfPresent([LegacyExam].self, forKey: .exams) ?? []
        plans = try container.decodeIfPresent([LegacyPlan].self, forKey: .plans) ?? []
        planItems = try container.decodeIfPresent([LegacyPlanItem].self, forKey: .planItems) ?? []
        onboardingCompleted = try container.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        reminderEnabled = try container.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? false
        reminderHour = try container.decodeIfPresent(Int.self, forKey: .reminderHour) ?? 19
        reminderMinute = try container.decodeIfPresent(Int.self, forKey: .reminderMinute) ?? 0
        selectedColorTheme = try container.decodeIfPresent(ColorTheme.self, forKey: .selectedColorTheme) ?? .green
        selectedThemeMode = try container.decodeIfPresent(ThemeMode.self, forKey: .selectedThemeMode) ?? .system
        liveActivityEnabled = try container.decodeIfPresent(Bool.self, forKey: .liveActivityEnabled) ?? true
        liveActivityDisplayPreset = try container.decodeIfPresent(LiveActivityDisplayPreset.self, forKey: .liveActivityDisplayPreset) ?? .standard
        activeTimer = try container.decodeIfPresent(LegacyTimerSnapshot.self, forKey: .activeTimer)
    }

    var preferences: AppPreferences {
        AppPreferences(
            onboardingCompleted: onboardingCompleted,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            selectedColorTheme: selectedColorTheme,
            selectedThemeMode: selectedThemeMode,
            liveActivityEnabled: liveActivityEnabled,
            liveActivityDisplayPreset: liveActivityDisplayPreset,
            activeTimer: activeTimer?.model
        )
    }
}

private struct LegacySubject: Codable {
    var id: Int64
    var name: String
    var color: Int
    var icon: SubjectIcon?
}

private struct LegacyMaterial: Codable {
    var id: Int64
    var name: String
    var subjectId: Int64
    var totalPages: Int
    var currentPage: Int
    var color: Int?
    var note: String?
}

private struct LegacySession: Codable {
    var id: Int64
    var materialId: Int64?
    var materialName: String
    var subjectId: Int64
    var subjectName: String
    var startTime: Date
    var endTime: Date
    var note: String?
}

private struct LegacyGoal: Codable {
    var id: Int64
    var type: GoalType
    var targetMinutes: Int
    var weekStartDay: StudyWeekday
    var isActive: Bool
}

private struct LegacyExam: Codable {
    var id: Int64
    var name: String
    var date: Date
    var note: String?
}

private struct LegacyPlan: Codable {
    var id: Int64
    var name: String
    var startDate: Date
    var endDate: Date
    var isActive: Bool
    var createdAt: Date
}

private struct LegacyPlanItem: Codable {
    var id: Int64
    var planId: Int64
    var subjectId: Int64
    var dayOfWeek: StudyWeekday
    var targetMinutes: Int
    var actualMinutes: Int
    var timeSlot: String?
}

private struct LegacyTimerSnapshot: Codable {
    var subjectId: Int64
    var materialId: Int64?
    var startedAt: Date?
    var accumulatedSeconds: TimeInterval
    var isRunning: Bool

    var model: TimerSnapshot {
        TimerSnapshot(
            subjectId: subjectId,
            materialId: materialId,
            startedAt: startedAt?.epochMilliseconds,
            accumulatedMilliseconds: Int64(accumulatedSeconds * 1_000),
            isRunning: isRunning
        )
    }
}
