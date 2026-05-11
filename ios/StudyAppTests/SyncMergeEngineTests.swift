import XCTest
@testable import StudyApp

/// Pure-logic tests for `SyncMergeEngine`. The merge rules are the heart of
/// Firestore sync and are easy to get wrong in edge cases (tombstone wins,
/// problem-progress preservation on non-deleted winners, per-plan item
/// grouping), so this test suite exercises each of them independently.
final class SyncMergeEngineTests: XCTestCase {

    // MARK: - Generic merge conflict resolution

    func test_merge_keepsNewerUpdatedAt() {
        let local = [makeSubject(syncId: "s1", updatedAt: 1_000, color: 1)]
        let remote = [makeSubject(syncId: "s1", updatedAt: 2_000, color: 2)]

        let merged = SyncMergeEngine.merge(
            local: makeAppData(subjects: local),
            remote: makeAppData(subjects: remote)
        )

        XCTAssertEqual(merged.subjects.count, 1)
        XCTAssertEqual(merged.subjects.first?.color, 2)
    }

    func test_merge_tombstoneWinsOverNewerNonDeleted() {
        // A deletion on one side must override a newer-but-alive record on
        // the other side, otherwise a user's "delete" can be resurrected.
        let local = [makeSubject(syncId: "s1", updatedAt: 1_000, color: 1)]
        let remote = [makeSubject(syncId: "s1", updatedAt: 500, color: 2, deletedAt: 1_500)]

        let merged = SyncMergeEngine.merge(
            local: makeAppData(subjects: local),
            remote: makeAppData(subjects: remote)
        )

        XCTAssertEqual(merged.subjects.count, 1)
        XCTAssertNotNil(merged.subjects.first?.deletedAt)
    }

    func test_merge_nonDeletedWinsOverOlderTombstone() {
        // The reverse: an *update* after an older deletion must resurrect
        // the record (user re-added it).
        let local = [makeSubject(syncId: "s1", updatedAt: 2_000, color: 1)]
        let remote = [makeSubject(syncId: "s1", updatedAt: 500, color: 2, deletedAt: 1_000)]

        let merged = SyncMergeEngine.merge(
            local: makeAppData(subjects: local),
            remote: makeAppData(subjects: remote)
        )

        XCTAssertEqual(merged.subjects.count, 1)
        XCTAssertNil(merged.subjects.first?.deletedAt)
        XCTAssertEqual(merged.subjects.first?.color, 1)
    }

    // MARK: - Material problem-progress preservation

    func test_mergeMaterials_preservesProblemProgressFromOlderSide() {
        // Remote is newer but empty. Merge must keep the local problem data
        // so we don't wipe user-recorded progress that the remote side
        // simply didn't carry over yet.
        let localMaterial = makeMaterial(
            syncId: "m1",
            updatedAt: 1_000,
            problemRecords: [ProblemSessionRecord(number: 1, isWrong: true)],
            totalProblems: 50
        )
        let remoteMaterial = makeMaterial(
            syncId: "m1",
            updatedAt: 2_000,
            problemRecords: [],
            totalProblems: 0
        )

        let merged = SyncMergeEngine.mergeMaterials([localMaterial], [remoteMaterial])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.problemRecords.count, 1)
        XCTAssertEqual(merged.first?.totalProblems, 50)
    }

    func test_mergeMaterials_doesNotRevivePreservedProgressOnTombstone() {
        // When the winning record is a tombstone, we must not resurrect
        // problem progress from the other side, since the user deleted the
        // material.
        let localMaterial = makeMaterial(
            syncId: "m1",
            updatedAt: 500,
            problemRecords: [ProblemSessionRecord(number: 1, isWrong: false)],
            totalProblems: 10
        )
        let remoteMaterial = makeMaterial(
            syncId: "m1",
            updatedAt: 600,
            problemRecords: [],
            totalProblems: 0,
            deletedAt: 800
        )

        let merged = SyncMergeEngine.mergeMaterials([localMaterial], [remoteMaterial])

        XCTAssertEqual(merged.count, 1)
        XCTAssertNotNil(merged.first?.deletedAt)
        XCTAssertEqual(merged.first?.problemRecords.count, 0)
    }

    // MARK: - Session merge

    func test_mergeSessions_preservesProblemStartAndEndFromOlderSide() {
        let local = makeSession(
            syncId: "x1",
            startTime: 100,
            endTime: 200,
            updatedAt: 1_000,
            problemRecords: [],
            problemStart: 1,
            problemEnd: 5,
            wrongProblemCount: 2
        )
        let remote = makeSession(
            syncId: "x1",
            startTime: 100,
            endTime: 200,
            updatedAt: 2_000,
            problemRecords: [],
            problemStart: nil,
            problemEnd: nil,
            wrongProblemCount: nil
        )

        let merged = SyncMergeEngine.mergeSessions([local], [remote])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.problemStart, 1)
        XCTAssertEqual(merged.first?.problemEnd, 5)
        XCTAssertEqual(merged.first?.wrongProblemCount, 2)
    }

    // MARK: - Plan merge grouping

    func test_mergePlans_regroupsItemsByPlanSyncId() {
        let planA = makePlan(syncId: "pA", updatedAt: 1_000)
        let itemA1 = makePlanItem(syncId: "iA1", planSyncId: "pA")
        let itemA2 = makePlanItem(syncId: "iA2", planSyncId: "pA")

        let local = PlanData(plan: planA, items: [itemA1])
        let remote = PlanData(plan: planA, items: [itemA2])

        let merged = SyncMergeEngine.mergePlans([local], [remote])

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(Set(merged[0].items.map(\.syncId)), ["iA1", "iA2"])
    }

    // MARK: - markSynced

    func test_markSynced_stampsLastSyncedAtAndExportDate() {
        let appData = makeAppData(
            subjects: [makeSubject(syncId: "s1", updatedAt: 1_000)],
            materials: [makeMaterial(syncId: "m1", updatedAt: 1_000)]
        )

        let synced = SyncMergeEngine.markSynced(appData, at: 9_999)

        XCTAssertEqual(synced.exportDate, 9_999)
        XCTAssertEqual(synced.subjects.first?.lastSyncedAt, 9_999)
        XCTAssertEqual(synced.materials.first?.lastSyncedAt, 9_999)
    }

    // MARK: - SyncProgressGuard

    func test_progressGuard_flagsLossOfSessionProblemRecords() {
        let source = makeAppData(
            sessions: [
                makeSession(
                    syncId: "sess1",
                    startTime: 100,
                    endTime: 200,
                    updatedAt: 100,
                    problemRecords: [ProblemSessionRecord(number: 1, isWrong: true)]
                )
            ]
        )
        let destination = makeAppData(
            sessions: [
                makeSession(syncId: "sess1", startTime: 100, endTime: 200, updatedAt: 100, problemRecords: [])
            ]
        )

        XCTAssertTrue(SyncProgressGuard.wouldLoseProgress(from: source, to: destination))
    }

    func test_progressGuard_allowsWhenSourceHasNoProgress() {
        let source = makeAppData()
        let destination = makeAppData()

        XCTAssertFalse(SyncProgressGuard.wouldLoseProgress(from: source, to: destination))
    }

    // MARK: - Helpers

    private func makeAppData(
        subjects: [Subject] = [],
        materials: [Material] = [],
        sessions: [StudySession] = [],
        plans: [PlanData] = []
    ) -> AppData {
        AppData(
            subjects: subjects,
            materials: materials,
            sessions: sessions,
            goals: [],
            exams: [],
            plans: plans,
            exportDate: 0
        )
    }

    private func makeSubject(
        syncId: String,
        updatedAt: Int64,
        color: Int = 1,
        deletedAt: Int64? = nil
    ) -> Subject {
        Subject(
            id: 0,
            syncId: syncId,
            name: "s-\(syncId)",
            color: color,
            icon: nil,
            createdAt: 0,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            lastSyncedAt: nil
        )
    }

    private func makeMaterial(
        syncId: String,
        updatedAt: Int64,
        problemRecords: [ProblemSessionRecord] = [],
        totalProblems: Int = 0,
        deletedAt: Int64? = nil
    ) -> Material {
        Material(
            id: 0,
            syncId: syncId,
            name: "m-\(syncId)",
            subjectId: 1,
            subjectSyncId: nil,
            sortOrder: 0,
            totalPages: 0,
            currentPage: 0,
            totalProblems: totalProblems,
            problemChapters: [],
            problemRecords: problemRecords,
            color: nil,
            note: nil,
            createdAt: 0,
            updatedAt: updatedAt,
            deletedAt: deletedAt,
            lastSyncedAt: nil
        )
    }

    private func makeSession(
        syncId: String,
        startTime: Int64,
        endTime: Int64,
        updatedAt: Int64,
        problemRecords: [ProblemSessionRecord],
        problemStart: Int? = nil,
        problemEnd: Int? = nil,
        wrongProblemCount: Int? = nil
    ) -> StudySession {
        StudySession(
            id: 0,
            syncId: syncId,
            materialId: nil,
            startTime: startTime,
            endTime: endTime,
            intervals: [StudySessionInterval(startTime: startTime, endTime: endTime)],
            problemStart: problemStart,
            problemEnd: problemEnd,
            wrongProblemCount: wrongProblemCount,
            problemRecords: problemRecords,
            createdAt: 0,
            updatedAt: updatedAt
        )
    }

    private func makePlan(syncId: String, updatedAt: Int64) -> StudyPlan {
        StudyPlan(
            id: 0,
            syncId: syncId,
            name: "p-\(syncId)",
            startDate: 0,
            endDate: 0,
            isActive: true,
            createdAt: 0,
            updatedAt: updatedAt
        )
    }

    private func makePlanItem(syncId: String, planSyncId: String?) -> PlanItem {
        PlanItem(
            id: 0,
            syncId: syncId,
            planId: 1,
            planSyncId: planSyncId,
            subjectId: 1,
            subjectSyncId: nil,
            dayOfWeek: .monday,
            targetMinutes: 60,
            actualMinutes: 0,
            timeSlot: nil,
            createdAt: 0,
            updatedAt: 0
        )
    }
}
