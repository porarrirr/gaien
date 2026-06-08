import XCTest
@testable import StudyApp

/// Tests the pure decompose/assemble/changedSince logic that drives the
/// per-entity delta sync. These are the critical paths that determine what
/// gets pushed and how remote changes are merged locally.
final class SyncDeltaSerializerTests: XCTestCase {

    // MARK: - decompose

    func test_decompose_emitsOneEnvelopePerEntity() {
        let appData = makeAppData(
            subjects: [makeSubject(syncId: "s1"), makeSubject(syncId: "s2")],
            sessions: [makeSession(syncId: "x1")]
        )

        let envelopes = SyncDeltaSerializer.decompose(appData)

        XCTAssertEqual(envelopes.count, 3)
        XCTAssertEqual(envelopes.filter { $0.kind == .subject }.count, 2)
        XCTAssertEqual(envelopes.filter { $0.kind == .session }.count, 1)
    }

    func test_decompose_includesPlanAndPlanItemsSeparately() {
        let plan = StudyPlan(id: 1, syncId: "p1", name: "Plan", startDate: 0, endDate: 0, isActive: true, createdAt: 0, updatedAt: 100)
        let item = PlanItem(id: 2, syncId: "i1", planId: 1, planSyncId: "p1", subjectId: 1, dayOfWeek: .monday, targetMinutes: 60, createdAt: 0, updatedAt: 100)
        let appData = makeAppData(plans: [PlanData(plan: plan, items: [item])])

        let envelopes = SyncDeltaSerializer.decompose(appData)

        XCTAssertEqual(envelopes.filter { $0.kind == .plan }.count, 1)
        XCTAssertEqual(envelopes.filter { $0.kind == .planItem }.count, 1)
    }

    func test_decompose_documentIdIsKindDashSyncId() {
        let subject = makeSubject(syncId: "abc-123")
        let envelopes = SyncDeltaSerializer.decompose(makeAppData(subjects: [subject]))

        XCTAssertEqual(envelopes.first?.documentId, "subject-abc-123")
    }

    // MARK: - changedSince

    func test_changedSince_filtersOnUpdatedAt() {
        let old = makeSubject(syncId: "s1", updatedAt: 100)
        let new = makeSubject(syncId: "s2", updatedAt: 500)
        let appData = makeAppData(subjects: [old, new])

        let changed = SyncDeltaSerializer.changedSince(appData, cursor: 200)

        XCTAssertEqual(changed.count, 1)
        XCTAssertEqual(changed.first?.syncId, "s2")
    }

    func test_changedSince_includesExactlyAtCursorBoundary() {
        let atBoundary = makeSubject(syncId: "s1", updatedAt: 200)
        let appData = makeAppData(subjects: [atBoundary])

        let changed = SyncDeltaSerializer.changedSince(appData, cursor: SyncDeltaCursor.fromLegacy(200))

        XCTAssertEqual(changed.map(\.syncId), ["s1"])
    }

    func test_changedSince_usesDocumentIdTieBreakAtSameUpdatedAt() {
        let appData = makeAppData(subjects: [
            makeSubject(syncId: "a", updatedAt: 200),
            makeSubject(syncId: "z", updatedAt: 200)
        ])
        let cursor = SyncDeltaCursor(updatedAt: 200, documentId: "subject-a")

        let changed = SyncDeltaSerializer.changedSince(appData, cursor: cursor)

        XCTAssertEqual(changed.map(\.syncId), ["z"])
    }

    // MARK: - assemble

    func test_assemble_mergesEnvelopesOntoBase() {
        let base = makeAppData(
            subjects: [makeSubject(syncId: "s1", updatedAt: 100, color: 1)]
        )
        // Remote has a newer version of the same subject
        let newerSubject = makeSubject(syncId: "s1", updatedAt: 200, color: 5)
        let envelope = SyncEntityEnvelope(
            kind: .subject,
            syncId: "s1",
            updatedAt: 200,
            deletedAt: nil,
            json: String(data: try! JSONEncoder().encode(newerSubject), encoding: .utf8)!
        )

        let merged = SyncDeltaSerializer.assemble(envelopes: [envelope], onto: base)

        XCTAssertEqual(merged.subjects.count, 1)
        XCTAssertEqual(merged.subjects.first?.color, 5)
    }

    func test_assemble_addsNewEntitiesNotInBase() {
        let base = makeAppData()
        let subject = makeSubject(syncId: "s-new", updatedAt: 300)
        let envelope = SyncEntityEnvelope(
            kind: .subject,
            syncId: "s-new",
            updatedAt: 300,
            deletedAt: nil,
            json: String(data: try! JSONEncoder().encode(subject), encoding: .utf8)!
        )

        let merged = SyncDeltaSerializer.assemble(envelopes: [envelope], onto: base)

        XCTAssertEqual(merged.subjects.count, 1)
        XCTAssertEqual(merged.subjects.first?.syncId, "s-new")
    }

    func test_assemble_skipsMalformedEnvelopes() {
        let base = makeAppData()
        let badEnvelope = SyncEntityEnvelope(
            kind: .subject,
            syncId: "bad",
            updatedAt: 100,
            deletedAt: nil,
            json: "not valid json {"
        )

        let merged = SyncDeltaSerializer.assemble(envelopes: [badEnvelope], onto: base)

        XCTAssertTrue(merged.subjects.isEmpty)
    }

    // MARK: - Helpers

    private func makeAppData(
        subjects: [Subject] = [],
        sessions: [StudySession] = [],
        plans: [PlanData] = []
    ) -> AppData {
        AppData(
            subjects: subjects,
            materials: [],
            sessions: sessions,
            goals: [],
            exams: [],
            plans: plans,
            exportDate: 0
        )
    }

    private func makeSubject(syncId: String, updatedAt: Int64 = 100, color: Int = 1) -> Subject {
        Subject(id: 0, syncId: syncId, name: "s", color: color, createdAt: 0, updatedAt: updatedAt)
    }

    private func makeSession(syncId: String, updatedAt: Int64 = 100) -> StudySession {
        StudySession(id: 0, syncId: syncId, materialId: nil, subjectId: 1, startTime: 0, endTime: 60_000, createdAt: 0, updatedAt: updatedAt)
    }
}
