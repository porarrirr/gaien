import CoreData
import Foundation

actor PersistenceController: SubjectRepository, MaterialRepository, StudySessionRepository, GoalRepository, ExamRepository, PlanRepository, AppDataRepository {
    static let shared = PersistenceController()

    private let container: NSPersistentContainer
    private let fileManager: FileManager
    private let loadTask: Task<Void, Error>
    private let legacyURL: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.legacyURL = (fileManager.urls(for: .documentDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory)
            .appendingPathComponent("studyapp-store.json")

        let model = Self.makeManagedObjectModel()
        container = NSPersistentContainer(name: "StudyAppStore", managedObjectModel: model)
        let storeURL = (fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first ?? fileManager.temporaryDirectory)
            .appendingPathComponent("StudyApp.sqlite")
        let description = NSPersistentStoreDescription(url: storeURL)
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true
        container.persistentStoreDescriptions = [description]
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        loadTask = Task {
            try await withCheckedThrowingContinuation { continuation in
                container.loadPersistentStores { _, error in
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
        if fileManager.fileExists(atPath: migratedURL.path) {
            try? fileManager.removeItem(at: migratedURL)
        }
        try? fileManager.moveItem(at: legacyURL, to: migratedURL)
    }

    func getAllSubjects() async throws -> [Subject] {
        try await ensureLoaded()
        return try fetch(entity: "SubjectRecord", sort: [NSSortDescriptor(key: "name", ascending: true)]).map(Self.subject)
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
        record.setValue(subject.name, forKey: "name")
        record.setValue(Int64(subject.color), forKey: "color")
        record.setValue(subject.icon?.rawValue, forKey: "icon")
        record.setValue(subject.createdAt == 0 ? now : subject.createdAt, forKey: "createdAt")
        record.setValue(subject.updatedAt == 0 ? now : subject.updatedAt, forKey: "updatedAt")
        try saveContext()
        return id
    }

    func updateSubject(_ subject: Subject) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "SubjectRecord", id: subject.id) else { return }
        record.setValue(subject.name, forKey: "name")
        record.setValue(Int64(subject.color), forKey: "color")
        record.setValue(subject.icon?.rawValue, forKey: "icon")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")

        let sessions = try fetch(entity: "StudySessionRecord", predicate: NSPredicate(format: "subjectId == %lld", subject.id))
        for session in sessions {
            session.setValue(subject.name, forKey: "subjectName")
        }
        try saveContext()
    }

    func deleteSubject(_ subject: Subject) async throws {
        try await ensureLoaded()
        let relatedMaterials = try fetch(entity: "MaterialRecord", predicate: NSPredicate(format: "subjectId == %lld", subject.id))
        let materialIds = Set(relatedMaterials.compactMap { $0.value(forKey: "id") as? Int64 })
        let sessions = try fetch(entity: "StudySessionRecord")
        let planItems = try fetch(entity: "PlanItemRecord", predicate: NSPredicate(format: "subjectId == %lld", subject.id))

        for material in relatedMaterials {
            container.viewContext.delete(material)
        }
        for session in sessions {
            let subjectId = session.value(forKey: "subjectId") as? Int64
            let materialId = session.value(forKey: "materialId") as? Int64
            if subjectId == subject.id || (materialId.map(materialIds.contains) ?? false) {
                container.viewContext.delete(session)
            }
        }
        for item in planItems {
            container.viewContext.delete(item)
        }
        if let record = try fetchOne(entity: "SubjectRecord", id: subject.id) {
            container.viewContext.delete(record)
        }
        try saveContext()
    }

    func getAllMaterials() async throws -> [Material] {
        try await ensureLoaded()
        return try fetch(entity: "MaterialRecord", sort: [NSSortDescriptor(key: "id", ascending: false)]).map(Self.material)
    }

    func getMaterialsBySubjectId(_ subjectId: Int64) async throws -> [Material] {
        try await ensureLoaded()
        return try fetch(
            entity: "MaterialRecord",
            predicate: NSPredicate(format: "subjectId == %lld", subjectId),
            sort: [NSSortDescriptor(key: "id", ascending: false)]
        ).map(Self.material)
    }

    func insertMaterial(_ material: Material) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: material.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: container.viewContext)
        record.setValue(id, forKey: "id")
        record.setValue(material.name, forKey: "name")
        record.setValue(material.subjectId, forKey: "subjectId")
        record.setValue(Int64(material.totalPages), forKey: "totalPages")
        record.setValue(Int64(material.currentPage), forKey: "currentPage")
        record.setValue(material.color.map(Int64.init), forKey: "color")
        record.setValue(material.note, forKey: "note")
        record.setValue(material.createdAt == 0 ? now : material.createdAt, forKey: "createdAt")
        record.setValue(material.updatedAt == 0 ? now : material.updatedAt, forKey: "updatedAt")
        try saveContext()
        return id
    }

    func updateMaterial(_ material: Material) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "MaterialRecord", id: material.id) else { return }
        record.setValue(material.name, forKey: "name")
        record.setValue(material.subjectId, forKey: "subjectId")
        record.setValue(Int64(material.totalPages), forKey: "totalPages")
        record.setValue(Int64(material.currentPage), forKey: "currentPage")
        record.setValue(material.color.map(Int64.init), forKey: "color")
        record.setValue(material.note, forKey: "note")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")

        let subjectName = try await getSubjectById(material.subjectId)?.name ?? ""
        let sessions = try fetch(entity: "StudySessionRecord", predicate: NSPredicate(format: "materialId == %lld", material.id))
        for session in sessions {
            session.setValue(material.name, forKey: "materialName")
            session.setValue(material.subjectId, forKey: "subjectId")
            session.setValue(subjectName, forKey: "subjectName")
        }
        try saveContext()
    }

    func deleteMaterial(_ material: Material) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "MaterialRecord", id: material.id) {
            container.viewContext.delete(record)
        }
        let sessions = try fetch(entity: "StudySessionRecord", predicate: NSPredicate(format: "materialId == %lld", material.id))
        for session in sessions {
            container.viewContext.delete(session)
        }
        try saveContext()
    }

    func getAllSessions() async throws -> [StudySession] {
        try await ensureLoaded()
        return try fetch(entity: "StudySessionRecord", sort: [NSSortDescriptor(key: "startTime", ascending: false)]).map(Self.session)
    }

    func getSessionsBetweenDates(start: Int64, end: Int64) async throws -> [StudySession] {
        try await ensureLoaded()
        return try fetch(
            entity: "StudySessionRecord",
            predicate: NSPredicate(format: "startTime >= %lld AND startTime < %lld", start, end),
            sort: [NSSortDescriptor(key: "startTime", ascending: false)]
        ).map(Self.session)
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
        apply(sanitize(session: session, assignedId: session.id), to: record)
        try saveContext()
        try await recalculatePlanActualMinutes()
    }

    func deleteSession(_ session: StudySession) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "StudySessionRecord", id: session.id) {
            container.viewContext.delete(record)
            try saveContext()
            try await recalculatePlanActualMinutes()
        }
    }

    func getAllGoals() async throws -> [Goal] {
        try await ensureLoaded()
        return try fetch(entity: "GoalRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: true)]).map(Self.goal)
    }

    func getActiveGoalByType(_ type: GoalType) async throws -> Goal? {
        try await ensureLoaded()
        let predicate = NSPredicate(format: "type == %@ AND isActive == YES", type.rawValue)
        return try fetch(entity: "GoalRecord", predicate: predicate, sort: [NSSortDescriptor(key: "updatedAt", ascending: false)]).first.map(Self.goal)
    }

    func insertGoal(_ goal: Goal) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: goal.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: container.viewContext)
        record.setValue(id, forKey: "id")
        record.setValue(goal.type.rawValue, forKey: "type")
        record.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
        record.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
        record.setValue(goal.isActive, forKey: "isActive")
        record.setValue(goal.createdAt == 0 ? now : goal.createdAt, forKey: "createdAt")
        record.setValue(goal.updatedAt == 0 ? now : goal.updatedAt, forKey: "updatedAt")
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
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveContext()
    }

    func deleteGoal(_ goal: Goal) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "GoalRecord", id: goal.id) {
            container.viewContext.delete(record)
            try saveContext()
        }
    }

    func getAllExams() async throws -> [Exam] {
        try await ensureLoaded()
        return try fetch(entity: "ExamRecord", sort: [NSSortDescriptor(key: "date", ascending: true)]).map(Self.exam)
    }

    func getUpcomingExams(now: Date) async throws -> [Exam] {
        try await ensureLoaded()
        let currentDay = now.epochDay
        return try fetch(
            entity: "ExamRecord",
            predicate: NSPredicate(format: "date >= %lld", currentDay),
            sort: [NSSortDescriptor(key: "date", ascending: true)]
        ).map(Self.exam)
    }

    func insertExam(_ exam: Exam) async throws -> Int64 {
        try await ensureLoaded()
        let id = try nextIdentifier(ifNeeded: exam.id)
        let now = Date().epochMilliseconds
        let record = NSEntityDescription.insertNewObject(forEntityName: "ExamRecord", into: container.viewContext)
        record.setValue(id, forKey: "id")
        record.setValue(exam.name, forKey: "name")
        record.setValue(exam.date, forKey: "date")
        record.setValue(exam.note, forKey: "note")
        record.setValue(exam.createdAt == 0 ? now : exam.createdAt, forKey: "createdAt")
        record.setValue(exam.updatedAt == 0 ? now : exam.updatedAt, forKey: "updatedAt")
        try saveContext()
        return id
    }

    func updateExam(_ exam: Exam) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "ExamRecord", id: exam.id) else { return }
        record.setValue(exam.name, forKey: "name")
        record.setValue(exam.date, forKey: "date")
        record.setValue(exam.note, forKey: "note")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveContext()
    }

    func deleteExam(_ exam: Exam) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "ExamRecord", id: exam.id) {
            container.viewContext.delete(record)
            try saveContext()
        }
    }

    func getAllPlans() async throws -> [StudyPlan] {
        try await ensureLoaded()
        return try fetch(entity: "StudyPlanRecord", sort: [NSSortDescriptor(key: "createdAt", ascending: false)]).map(Self.plan)
    }

    func getPlanItems(planId: Int64) async throws -> [PlanItem] {
        try await ensureLoaded()
        return try fetch(
            entity: "PlanItemRecord",
            predicate: NSPredicate(format: "planId == %lld", planId),
            sort: [NSSortDescriptor(key: "dayOfWeek", ascending: true), NSSortDescriptor(key: "targetMinutes", ascending: false)]
        ).map(Self.planItem)
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
        record.setValue(plan.name, forKey: "name")
        record.setValue(plan.startDate, forKey: "startDate")
        record.setValue(plan.endDate, forKey: "endDate")
        record.setValue(plan.isActive, forKey: "isActive")
        record.setValue(plan.createdAt == 0 ? Date().epochMilliseconds : plan.createdAt, forKey: "createdAt")

        for item in items {
            let itemRecord = NSEntityDescription.insertNewObject(forEntityName: "PlanItemRecord", into: container.viewContext)
            let itemId = item.id > 0 ? item.id : nextLocalId
            if item.id == 0 {
                nextLocalId += 1
            }
            itemRecord.setValue(itemId, forKey: "id")
            itemRecord.setValue(planId, forKey: "planId")
            itemRecord.setValue(item.subjectId, forKey: "subjectId")
            itemRecord.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
            itemRecord.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
            itemRecord.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
            itemRecord.setValue(item.timeSlot, forKey: "timeSlot")
            itemRecord.setValue(Date().epochMilliseconds, forKey: "createdAt")
            itemRecord.setValue(Date().epochMilliseconds, forKey: "updatedAt")
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
        record.setValue(item.planId, forKey: "planId")
        record.setValue(item.subjectId, forKey: "subjectId")
        record.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
        record.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
        record.setValue(item.timeSlot, forKey: "timeSlot")
        record.setValue(item.createdAt == 0 ? Date().epochMilliseconds : item.createdAt, forKey: "createdAt")
        record.setValue(item.updatedAt == 0 ? Date().epochMilliseconds : item.updatedAt, forKey: "updatedAt")
        try saveContext()
        try await recalculatePlanActualMinutes()
        return itemId
    }

    func updatePlanItem(_ item: PlanItem) async throws {
        try await ensureLoaded()
        guard let record = try fetchOne(entity: "PlanItemRecord", id: item.id) else { return }
        record.setValue(item.subjectId, forKey: "subjectId")
        record.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
        record.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
        record.setValue(item.timeSlot, forKey: "timeSlot")
        record.setValue(Date().epochMilliseconds, forKey: "updatedAt")
        try saveContext()
        try await recalculatePlanActualMinutes()
    }

    func deletePlanItem(_ item: PlanItem) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "PlanItemRecord", id: item.id) {
            container.viewContext.delete(record)
            try saveContext()
            try await recalculatePlanActualMinutes()
        }
    }

    func deletePlan(_ plan: StudyPlan) async throws {
        try await ensureLoaded()
        if let record = try fetchOne(entity: "StudyPlanRecord", id: plan.id) {
            container.viewContext.delete(record)
        }
        let items = try fetch(entity: "PlanItemRecord", predicate: NSPredicate(format: "planId == %lld", plan.id))
        for item in items {
            container.viewContext.delete(item)
        }
        try saveContext()
    }

    func exportData() async throws -> AppData {
        try await ensureLoaded()
        let subjects = try await getAllSubjects()
        let materials = try await getAllMaterials()
        let sessions = try await getAllSessions()
        let goals = try await getAllGoals()
        let exams = try await getAllExams()
        let plans = try await getAllPlans()

        var planData = [PlanData]()
        for plan in plans {
            let items = try await getPlanItems(planId: plan.id)
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
        for entity in Self.entityNames {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: request)
            try container.viewContext.execute(deleteRequest)
        }
        try saveContext()
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
        try await deleteAllData()
        for subject in appData.subjects {
            _ = try await insertSubject(subject)
        }
        for material in appData.materials {
            _ = try await insertMaterial(material)
        }
        for session in appData.sessions {
            _ = try await insertSession(session)
        }
        for goal in appData.goals {
            _ = try await insertGoal(goal)
        }
        for exam in appData.exams {
            _ = try await insertExam(exam)
        }
        for planData in appData.plans.sorted(by: { $0.plan.isActive && !$1.plan.isActive }) {
            _ = try await createPlan(planData.plan, items: planData.items)
        }
        try await recalculatePlanActualMinutes()
    }

    private func recalculatePlanActualMinutes() async throws {
        let activePlans = try fetch(entity: "StudyPlanRecord", predicate: NSPredicate(format: "isActive == YES"))
        guard let activePlanRecord = activePlans.first else { return }
        let activePlan = Self.plan(activePlanRecord)
        let planItems = try fetch(entity: "PlanItemRecord", predicate: NSPredicate(format: "planId == %lld", activePlan.id))
        let sessions = try fetch(entity: "StudySessionRecord")

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

    private func sanitize(session: StudySession, assignedId: Int64) -> StudySession {
        let duration = max(session.endTime - session.startTime, 0)
        let end = session.startTime + duration
        return StudySession(
            id: assignedId,
            materialId: session.materialId,
            materialName: session.materialName,
            subjectId: session.subjectId,
            subjectName: session.subjectName,
            startTime: session.startTime,
            endTime: end,
            note: session.note,
            createdAt: session.createdAt == 0 ? Date().epochMilliseconds : session.createdAt
        )
    }

    private func apply(_ session: StudySession, to record: NSManagedObject) {
        record.setValue(session.id, forKey: "id")
        record.setValue(session.materialId, forKey: "materialId")
        record.setValue(session.materialName, forKey: "materialName")
        record.setValue(session.subjectId, forKey: "subjectId")
        record.setValue(session.subjectName, forKey: "subjectName")
        record.setValue(session.startTime, forKey: "startTime")
        record.setValue(session.endTime, forKey: "endTime")
        record.setValue(session.duration, forKey: "duration")
        record.setValue(session.date, forKey: "date")
        record.setValue(session.note, forKey: "note")
        record.setValue(session.createdAt, forKey: "createdAt")
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

    private func saveContext() throws {
        if container.viewContext.hasChanges {
            try container.viewContext.save()
        }
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
            name: record.value(forKey: "name") as? String ?? "",
            color: Int(record.value(forKey: "color") as? Int64 ?? 0),
            icon: (record.value(forKey: "icon") as? String).flatMap(SubjectIcon.init(rawValue:)),
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0
        )
    }

    private static func material(_ record: NSManagedObject) -> Material {
        Material(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            name: record.value(forKey: "name") as? String ?? "",
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            totalPages: Int(record.value(forKey: "totalPages") as? Int64 ?? 0),
            currentPage: Int(record.value(forKey: "currentPage") as? Int64 ?? 0),
            color: (record.value(forKey: "color") as? Int64).map(Int.init),
            note: record.value(forKey: "note") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0
        )
    }

    private static func session(_ record: NSManagedObject) -> StudySession {
        StudySession(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            materialId: record.value(forKey: "materialId") as? Int64,
            materialName: record.value(forKey: "materialName") as? String ?? "",
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            subjectName: record.value(forKey: "subjectName") as? String ?? "",
            startTime: record.value(forKey: "startTime") as? Int64 ?? 0,
            endTime: record.value(forKey: "endTime") as? Int64 ?? 0,
            note: record.value(forKey: "note") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0
        )
    }

    private static func goal(_ record: NSManagedObject) -> Goal {
        Goal(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            type: GoalType(rawValue: record.value(forKey: "type") as? String ?? GoalType.daily.rawValue) ?? .daily,
            targetMinutes: Int(record.value(forKey: "targetMinutes") as? Int64 ?? 0),
            weekStartDay: StudyWeekday(rawValue: record.value(forKey: "weekStartDay") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            isActive: record.value(forKey: "isActive") as? Bool ?? false,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0
        )
    }

    private static func exam(_ record: NSManagedObject) -> Exam {
        Exam(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            name: record.value(forKey: "name") as? String ?? "",
            date: record.value(forKey: "date") as? Int64 ?? 0,
            note: record.value(forKey: "note") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0
        )
    }

    private static func plan(_ record: NSManagedObject) -> StudyPlan {
        StudyPlan(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            name: record.value(forKey: "name") as? String ?? "",
            startDate: record.value(forKey: "startDate") as? Int64 ?? 0,
            endDate: record.value(forKey: "endDate") as? Int64 ?? 0,
            isActive: record.value(forKey: "isActive") as? Bool ?? false,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0
        )
    }

    private static func planItem(_ record: NSManagedObject) -> PlanItem {
        PlanItem(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            planId: record.value(forKey: "planId") as? Int64 ?? 0,
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            dayOfWeek: StudyWeekday(rawValue: record.value(forKey: "dayOfWeek") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            targetMinutes: Int(record.value(forKey: "targetMinutes") as? Int64 ?? 0),
            actualMinutes: Int(record.value(forKey: "actualMinutes") as? Int64 ?? 0),
            timeSlot: record.value(forKey: "timeSlot") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0
        )
    }

    private static func makeManagedObjectModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity(
                name: "SubjectRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "color", type: .integer64AttributeType),
                    attribute(name: "icon", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType)
                ]
            ),
            entity(
                name: "MaterialRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "totalPages", type: .integer64AttributeType),
                    attribute(name: "currentPage", type: .integer64AttributeType),
                    attribute(name: "color", type: .integer64AttributeType, optional: true),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType)
                ]
            ),
            entity(
                name: "StudySessionRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "materialId", type: .integer64AttributeType, optional: true),
                    attribute(name: "materialName", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "subjectName", type: .stringAttributeType),
                    attribute(name: "startTime", type: .integer64AttributeType),
                    attribute(name: "endTime", type: .integer64AttributeType),
                    attribute(name: "duration", type: .integer64AttributeType),
                    attribute(name: "date", type: .integer64AttributeType),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType)
                ]
            ),
            entity(
                name: "GoalRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "type", type: .stringAttributeType),
                    attribute(name: "targetMinutes", type: .integer64AttributeType),
                    attribute(name: "weekStartDay", type: .stringAttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType)
                ]
            ),
            entity(
                name: "ExamRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "date", type: .integer64AttributeType),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType)
                ]
            ),
            entity(
                name: "StudyPlanRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "startDate", type: .integer64AttributeType),
                    attribute(name: "endDate", type: .integer64AttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType),
                    attribute(name: "createdAt", type: .integer64AttributeType)
                ]
            ),
            entity(
                name: "PlanItemRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "planId", type: .integer64AttributeType),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "dayOfWeek", type: .stringAttributeType),
                    attribute(name: "targetMinutes", type: .integer64AttributeType),
                    attribute(name: "actualMinutes", type: .integer64AttributeType),
                    attribute(name: "timeSlot", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType)
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
    var activeTimer: LegacyTimerSnapshot?

    var preferences: AppPreferences {
        AppPreferences(
            onboardingCompleted: onboardingCompleted,
            reminderEnabled: reminderEnabled,
            reminderHour: reminderHour,
            reminderMinute: reminderMinute,
            selectedColorTheme: selectedColorTheme,
            selectedThemeMode: selectedThemeMode,
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
