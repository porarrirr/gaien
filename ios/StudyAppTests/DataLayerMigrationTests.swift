import CoreData
import XCTest
@testable import StudyApp

final class DataLayerMigrationTests: XCTestCase {
    func testV1GoldenUpgradesToCurrentSchema() throws {
        let data = try resourceData(named: "appdata-v1-golden")

        let upgraded = try AppDataUpgrader.decode(data)

        XCTAssertEqual(upgraded.schemaVersion, AppData.currentSchemaVersion)
        XCTAssertFalse(upgraded.supportsProblemRecords)
        XCTAssertEqual(upgraded.subjects.map(\.syncId), ["v1-subject"])
        XCTAssertTrue(upgraded.timetablePeriods.isEmpty)
        XCTAssertTrue(upgraded.problemReviewRecords.isEmpty)
    }

    func testUpgraderRejectsFutureAndNonIntegerSchemaVersions() {
        XCTAssertThrowsError(
            try AppDataUpgrader.decode(Data(#"{"schemaVersion":999}"#.utf8))
        )
        XCTAssertThrowsError(
            try AppDataUpgrader.decode(Data(#"{"schemaVersion":1.5}"#.utf8))
        )
        XCTAssertThrowsError(
            try AppDataUpgrader.decode(Data(#"{"schemaVersion":true}"#.utf8))
        )
    }

    func testV2GoldenRoundTripsThroughCoreData() throws {
        let input = try AppDataUpgrader.decode(resourceData(named: "appdata-v2-golden"))
        let context = try makeContext()

        try AppDataArchiver.replaceData(with: input, in: context)
        try context.save()
        let output = try AppDataArchiver.buildExport(in: context)

        XCTAssertEqual(Set(output.subjects.map(\.syncId)), Set(input.subjects.map(\.syncId)))
        XCTAssertEqual(output.materials.map(\.syncId), input.materials.map(\.syncId))
        XCTAssertEqual(output.sessions.first?.problemRecords, input.sessions.first?.problemRecords)
        XCTAssertEqual(output.problemReviewRecords.count, input.problemReviewRecords.count)
        XCTAssertEqual(output.timetablePeriods.count, input.timetablePeriods.count)
        XCTAssertEqual(output.timetableTerms.count, input.timetableTerms.count)
    }

    func testLegacySnapshotConvertsAndRoundTrips() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        let snapshot = try decoder.decode(
            LegacySnapshot.self,
            from: resourceData(named: "legacy-snapshot-golden")
        )
        let context = try makeContext()

        try AppDataArchiver.replaceData(with: AppDataArchiver.convert(legacy: snapshot), in: context)
        try context.save()
        let output = try AppDataArchiver.buildExport(in: context)

        XCTAssertEqual(output.subjects.count, 1)
        XCTAssertEqual(output.materials.count, 1)
        XCTAssertEqual(output.sessions.count, 1)
        XCTAssertEqual(output.sessions.first?.materialName, "Legacy Material")
    }

    func testDailyGoalMigrationIsIdempotentAndTombstonesLegacyRow() throws {
        let context = try makeContext()
        let record = NSEntityDescription.insertNewObject(forEntityName: "GoalRecord", into: context)
        PersistenceMappers.apply(
            Goal(
                id: 10,
                syncId: "legacy-goal",
                type: .daily,
                targetMinutes: 60,
                dayOfWeek: nil,
                isActive: true,
                createdAt: 100,
                updatedAt: 100
            ),
            assignedId: 10,
            now: 100,
            to: record
        )

        XCTAssertTrue(try LegacyDailyGoalNormalizer.normalize(in: context))
        XCTAssertFalse(try LegacyDailyGoalNormalizer.normalize(in: context))

        let goals = try CoreDataQuery.fetch("GoalRecord", in: context).map(PersistenceMappers.goal)
        XCTAssertEqual(goals.count, 8)
        XCTAssertNotNil(goals.first(where: { $0.syncId == "legacy-goal" })?.deletedAt)
        XCTAssertEqual(goals.filter { $0.deletedAt == nil && $0.dayOfWeek != nil }.count, 7)
    }

    func testSyncUpsertPreservesExistingIdsAndDoesNotDuplicateRows() throws {
        let context = try makeContext()
        let initial = AppData(
            subjects: [
                Subject(id: 100, syncId: "subject-1", name: "Old", color: 1, createdAt: 1, updatedAt: 1)
            ],
            materials: [
                Material(
                    id: 200,
                    syncId: "material-1",
                    name: "Book",
                    subjectId: 100,
                    subjectSyncId: "subject-1",
                    createdAt: 1,
                    updatedAt: 1
                )
            ],
            sessions: [],
            goals: [],
            exams: [],
            plans: [],
            exportDate: 1
        )
        try AppDataArchiver.replaceData(with: initial, in: context)
        try context.save()

        let merged = AppData(
            subjects: [
                Subject(id: 9_000, syncId: "subject-1", name: "New", color: 2, createdAt: 1, updatedAt: 2),
                Subject(id: 9_001, syncId: "subject-2", name: "Added", color: 3, createdAt: 2, updatedAt: 2)
            ],
            materials: [
                Material(
                    id: 9_002,
                    syncId: "material-1",
                    name: "Book Updated",
                    subjectId: 9_000,
                    subjectSyncId: "subject-1",
                    createdAt: 1,
                    updatedAt: 2
                )
            ],
            sessions: [],
            goals: [],
            exams: [],
            plans: [],
            exportDate: 2
        )

        try AppDataArchiver.applySyncedData(merged, in: context)
        try AppDataArchiver.applySyncedData(merged, in: context)
        try context.save()
        let output = try AppDataArchiver.buildExport(in: context)

        XCTAssertEqual(output.subjects.count, 2)
        XCTAssertEqual(output.subjects.first(where: { $0.syncId == "subject-1" })?.id, 100)
        XCTAssertEqual(output.subjects.first(where: { $0.syncId == "subject-2" })?.id, 101)
        XCTAssertEqual(output.materials.count, 1)
        XCTAssertEqual(output.materials.first?.id, 200)
        XCTAssertEqual(output.materials.first?.subjectId, 100)
        XCTAssertEqual(output.materials.first?.name, "Book Updated")
    }

    func testSyncUpsertAndLegacyReplaceProduceEquivalentSummaries() throws {
        let current = try AppDataUpgrader.decode(resourceData(named: "appdata-v2-golden"))
        var incoming = current
        incoming.subjects[0].name = "Updated Subject"
        incoming.subjects[0].updatedAt += 100
        incoming.materials.append(
            Material(
                id: 9_999,
                syncId: "new-material",
                name: "New Material",
                subjectId: incoming.subjects[0].id,
                subjectSyncId: incoming.subjects[0].syncId,
                createdAt: incoming.exportDate + 1,
                updatedAt: incoming.exportDate + 1
            )
        )

        let legacy = try AppDataArchiver.previewSyncApply(
            current: current,
            incoming: incoming,
            useUpsert: false
        )
        let upsert = try AppDataArchiver.previewSyncApply(
            current: current,
            incoming: incoming,
            useUpsert: true
        )

        XCTAssertEqual(Set(legacy.subjects.map(\.syncId)), Set(upsert.subjects.map(\.syncId)))
        XCTAssertEqual(Set(legacy.materials.map(\.syncId)), Set(upsert.materials.map(\.syncId)))
        XCTAssertEqual(legacy.sessions.count, upsert.sessions.count)
        XCTAssertEqual(legacy.problemReviewRecords.count, upsert.problemReviewRecords.count)
        XCTAssertEqual(
            legacy.materials.reduce(0) { $0 + $1.problemRecords.count },
            upsert.materials.reduce(0) { $0 + $1.problemRecords.count }
        )
    }

    func testSyncStateRecoveryResetsCursorAndRevisionsWithoutBase() {
        let inconsistent = PersistedSyncUserState(
            cursor: .fromLegacy(123),
            baseShadow: nil,
            revisions: ["subjects/subject-1": "revision-1"],
            legacyMigrationDone: true,
            lastSyncAt: 456
        )

        let result = SyncStateStore.repairInconsistentState(inconsistent)

        XCTAssertTrue(result.didRepair)
        XCTAssertEqual(result.state.cursor, .zero)
        XCTAssertNil(result.state.baseShadow)
        XCTAssertTrue(result.state.revisions.isEmpty)
        XCTAssertTrue(result.state.legacyMigrationDone)
        XCTAssertEqual(result.state.lastSyncAt, 456)
    }

    func testSyncStateRecoveryResetsDataBaseWithoutRevisions() {
        let base = AppData(
            subjects: [
                Subject(id: 1, syncId: "subject-1", name: "Subject", color: 1)
            ],
            materials: [],
            sessions: [],
            goals: [],
            exams: [],
            plans: [],
            exportDate: 1
        )
        let inconsistent = PersistedSyncUserState(
            cursor: .fromLegacy(123),
            baseShadow: base,
            revisions: [:]
        )

        let result = SyncStateStore.repairInconsistentState(inconsistent)

        XCTAssertTrue(result.didRepair)
        XCTAssertEqual(result.state.cursor, .zero)
        XCTAssertNil(result.state.baseShadow)
        XCTAssertTrue(result.state.revisions.isEmpty)
    }

    func testLegacySyncStateDecodingDefaultsServerCursorMigrationFields() throws {
        let data = Data(#"{"cursor":{"updatedAt":123,"documentId":"subject-a"},"revisions":{},"legacyMigrationDone":true}"#.utf8)

        let state = try JSONDecoder().decode(PersistedSyncUserState.self, from: data)

        XCTAssertEqual(state.serverCursor, .zero)
        XCTAssertFalse(state.serverCursorMigrationDone)
    }

    func testSyncMetadataBackfillIsIdempotent() throws {
        let context = try makeContext()
        let subject = NSEntityDescription.insertNewObject(forEntityName: "SubjectRecord", into: context)
        subject.setValue(Int64(40), forKey: "id")
        subject.setValue("", forKey: "syncId")
        subject.setValue("Legacy Subject", forKey: "name")
        subject.setValue(Int64(1), forKey: "createdAt")
        subject.setValue(Int64(1), forKey: "updatedAt")

        let material = NSEntityDescription.insertNewObject(forEntityName: "MaterialRecord", into: context)
        material.setValue(Int64(90), forKey: "id")
        material.setValue("", forKey: "syncId")
        material.setValue("Legacy Material", forKey: "name")
        material.setValue(Int64(40), forKey: "subjectId")
        material.setValue(Int64(1), forKey: "createdAt")
        material.setValue(Int64(1), forKey: "updatedAt")

        XCTAssertTrue(try SyncMetadataBackfiller.backfill(in: context))
        let firstSubjectSyncId = try XCTUnwrap(subject.value(forKey: "syncId") as? String)
        let firstMaterialSyncId = try XCTUnwrap(material.value(forKey: "syncId") as? String)
        XCTAssertEqual(material.value(forKey: "subjectSyncId") as? String, firstSubjectSyncId)

        XCTAssertFalse(try SyncMetadataBackfiller.backfill(in: context))
        XCTAssertEqual(subject.value(forKey: "syncId") as? String, firstSubjectSyncId)
        XCTAssertEqual(material.value(forKey: "syncId") as? String, firstMaterialSyncId)
    }

    @MainActor
    func testUpdateSessionPersistsScreenTimeUnlockExclusionForEditedTimerSession() async throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistenceControllerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let repository = PersistenceController(fileManager: TestFileManager(rootURL: rootURL))
        let start = Date(timeIntervalSince1970: 1_780_300_800).epochMilliseconds
        let session = StudySession(
            syncId: "session-1",
            materialId: nil,
            subjectId: 1,
            subjectName: "数学",
            sessionType: .timer,
            startTime: start,
            endTime: start + 30 * 60_000,
            intervals: [
                StudySessionInterval(startTime: start, endTime: start + 30 * 60_000)
            ],
            createdAt: start,
            updatedAt: start
        )
        let id = try await repository.insertSession(session)

        var edited = session
        edited.id = id
        edited.endTime = start + 45 * 60_000
        edited.intervals = [
            StudySessionInterval(startTime: start, endTime: start + 45 * 60_000)
        ]
        try await repository.updateSession(edited)

        let sessions = try await repository.getAllSessions()
        let saved = try XCTUnwrap(sessions.first)
        XCTAssertTrue(saved.screenTimeUnlockExcluded)
        XCTAssertFalse(saved.countsTowardScreenTimeDailyGoalUnlock)
    }

    func testRealDeviceBackupWhenProvided() throws {
        guard let path = ProcessInfo.processInfo.environment["STUDYAPP_REAL_BACKUP_PATH"] else {
            throw XCTSkip("Set STUDYAPP_REAL_BACKUP_PATH to validate a private device backup.")
        }
        let input = try AppDataUpgrader.decode(Data(contentsOf: URL(fileURLWithPath: path)))
        let context = try makeContext()

        try AppDataArchiver.replaceData(with: input, in: context)
        try context.save()
        let output = try AppDataArchiver.buildExport(in: context)

        XCTAssertEqual(output.schemaVersion, AppData.currentSchemaVersion)
        XCTAssertEqual(output.subjects.count, input.subjects.count)
        XCTAssertEqual(output.materials.count, input.materials.count)
        XCTAssertEqual(output.sessions.count, input.sessions.count)
        XCTAssertEqual(output.goals.count, input.goals.count)
        XCTAssertEqual(output.problemReviewRecords.count, input.problemReviewRecords.count)
    }

    private func resourceData(named name: String) throws -> Data {
        let bundle = Bundle(for: Self.self)
        let url = try XCTUnwrap(bundle.url(forResource: name, withExtension: "json"))
        return try Data(contentsOf: url)
    }

    private func makeContext() throws -> NSManagedObjectContext {
        let container = NSPersistentContainer(
            name: "DataLayerMigrationTests",
            managedObjectModel: CoreDataSchema.makeModel()
        )
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        var loadError: Error?
        container.loadPersistentStores { _, error in
            loadError = error
        }
        if let loadError {
            throw loadError
        }
        return container.viewContext
    }
}

private final class TestFileManager: FileManager {
    private let rootURL: URL

    init(rootURL: URL) {
        self.rootURL = rootURL
        super.init()
    }

    override func urls(
        for directory: FileManager.SearchPathDirectory,
        in domainMask: FileManager.SearchPathDomainMask
    ) -> [URL] {
        switch directory {
        case .applicationSupportDirectory, .documentDirectory:
            [rootURL]
        default:
            super.urls(for: directory, in: domainMask)
        }
    }
}
