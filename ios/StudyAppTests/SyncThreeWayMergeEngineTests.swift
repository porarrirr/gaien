import XCTest
@testable import StudyApp

final class SyncThreeWayMergeEngineTests: XCTestCase {
    func test_mergeWithoutBaseUsesLegacyTwoWayFallback() {
        let local = makeAppData(materials: [makeMaterial(syncId: "m1", updatedAt: 1_000, currentPage: 3)])
        let remote = [
            makeEnvelope(
                kind: .material,
                syncId: "m1",
                updatedAt: 2_000,
                json: encode(makeMaterial(syncId: "m1", updatedAt: 2_000, currentPage: 1))
            )
        ]

        let outcome = SyncThreeWayMergeEngine.merge(base: nil, local: local, remoteEnvelopes: remote)

        XCTAssertTrue(outcome.usedLegacyTwoWayFallback)
        XCTAssertTrue(outcome.conflicts.isEmpty)
        XCTAssertEqual(outcome.merged.materials.first?.currentPage, 1)
    }

    func test_mergeKeepsMonotonicCurrentPage() {
        let base = makeAppData(materials: [makeMaterial(syncId: "m1", updatedAt: 500, currentPage: 5)])
        let local = makeAppData(materials: [makeMaterial(syncId: "m1", updatedAt: 1_000, currentPage: 8)])
        let remote = [
            makeEnvelope(
                kind: .material,
                syncId: "m1",
                updatedAt: 1_100,
                json: encode(makeMaterial(syncId: "m1", updatedAt: 1_100, currentPage: 6))
            )
        ]

        let outcome = SyncThreeWayMergeEngine.merge(base: base, local: local, remoteEnvelopes: remote)

        XCTAssertFalse(outcome.usedLegacyTwoWayFallback)
        XCTAssertEqual(outcome.merged.materials.first?.currentPage, 8)
    }

    func test_mergeDetectsDeletionConflict() {
        let base = makeAppData(materials: [makeMaterial(syncId: "m1", updatedAt: 100, currentPage: 3)])
        let local = makeAppData(materials: [makeMaterial(syncId: "m1", updatedAt: 200, currentPage: 4)])
        let remote = [
            makeEnvelope(
                kind: .material,
                syncId: "m1",
                updatedAt: 250,
                deletedAt: 250,
                json: encode(makeMaterial(syncId: "m1", updatedAt: 250, currentPage: 3, deletedAt: 250))
            )
        ]

        let outcome = SyncThreeWayMergeEngine.merge(base: base, local: local, remoteEnvelopes: remote)

        XCTAssertEqual(outcome.conflicts.count, 1)
        XCTAssertEqual(outcome.conflicts.first?.conflictFields, [.deletion])
    }

    func test_changedSinceUsesCompositeCursorTieBreak() {
        let appData = makeAppData(subjects: [
            makeSubject(syncId: "a", updatedAt: 1_000),
            makeSubject(syncId: "z", updatedAt: 1_000)
        ])
        let cursor = SyncDeltaCursor(updatedAt: 1_000, documentId: "subject-a")

        let changed = SyncDeltaSerializer.changedSince(appData, cursor: cursor)

        XCTAssertEqual(changed.count, 1)
        XCTAssertEqual(changed.first?.syncId, "z")
    }

    func test_applyResolutionsBumpsUpdatedAtSoChoiceUploadsAfterCursor() {
        let local = makeAppData(subjects: [makeSubject(syncId: "s1", updatedAt: 1_000, color: 1)])
        let remote = makeSubject(syncId: "s1", updatedAt: 1_100, color: 2)
        let conflict = SyncConflict(
            kind: .subject,
            syncId: "s1",
            title: "subject conflict",
            summary: "subject conflict",
            conflictFields: [.other],
            baseJson: nil,
            localJson: encode(makeSubject(syncId: "s1", updatedAt: 1_000, color: 1)),
            remoteJson: encode(remote),
            suggestedMergedJson: encode(remote),
            detectedAt: 1_100
        )

        let resolved = SyncThreeWayMergeEngine.applyResolutions(
            [SyncConflictResolution(kind: .subject, syncId: "s1", strategy: .keepRemote)],
            to: local,
            conflicts: [conflict],
            resolvedAt: 2_000
        )

        XCTAssertEqual(resolved.subjects.first?.color, 2)
        XCTAssertEqual(resolved.subjects.first?.updatedAt, 2_000)
        XCTAssertEqual(SyncDeltaSerializer.changedSince(resolved, cursor: SyncDeltaCursor(updatedAt: 1_100, documentId: "subject-s1")).map(\.syncId), ["s1"])
    }

    func test_revisionStamperOmitsEmptyParentRevisionFromLegacyBase() {
        let base = makeAppData(subjects: [makeSubject(syncId: "s1", updatedAt: 1_000)])
        let outbound = SyncDeltaSerializer.decompose(makeAppData(subjects: [makeSubject(syncId: "s1", updatedAt: 2_000)]))

        let stamped = SyncRevisionStamper.stamp(outbound, previousBase: base, deviceId: "device")

        XCTAssertNil(stamped.first?.parentRevisionId)
        XCTAssertEqual(stamped.first?.deviceId, "device")
        XCTAssertNotNil(stamped.first?.revisionId)
    }

    private func makeEnvelope(
        kind: SyncEntityKind,
        syncId: String,
        updatedAt: Int64,
        deletedAt: Int64? = nil,
        json: String
    ) -> SyncEntityEnvelope {
        SyncEntityEnvelope(kind: kind, syncId: syncId, updatedAt: updatedAt, deletedAt: deletedAt, json: json)
    }

    private func encode<T: Encodable>(_ value: T) -> String {
        let data = try! JSONEncoder().encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private func makeAppData(
        subjects: [Subject] = [],
        materials: [Material] = []
    ) -> AppData {
        AppData(
            subjects: subjects,
            materials: materials,
            sessions: [],
            goals: [],
            exams: [],
            plans: [],
            exportDate: 0
        )
    }

    private func makeSubject(syncId: String, updatedAt: Int64, color: Int = 1) -> Subject {
        Subject(syncId: syncId, name: "Subject \(syncId)", color: color, updatedAt: updatedAt)
    }

    private func makeMaterial(
        syncId: String,
        updatedAt: Int64,
        currentPage: Int = 0,
        deletedAt: Int64? = nil
    ) -> Material {
        Material(
            syncId: syncId,
            name: "Material \(syncId)",
            subjectId: 1,
            currentPage: currentPage,
            updatedAt: updatedAt,
            deletedAt: deletedAt
        )
    }
}
