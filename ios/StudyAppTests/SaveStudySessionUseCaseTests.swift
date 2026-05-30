import XCTest
@testable import StudyApp

final class SaveStudySessionUseCaseTests: XCTestCase {
    func test_saveManualSession_insertsResolvedSubjectMaterialAndNilBlankNote() async throws {
        let subjectRepo = TestSubjectRepository([Subject(id: 1, syncId: "subject-1", name: "数学", color: 1)])
        let materialRepo = TestMaterialRepository([Material(id: 10, syncId: "material-10", name: "問題集", subjectId: 1, subjectSyncId: "subject-1")])
        let sessionRepo = TestStudySessionRepository()
        let useCase = SaveStudySessionUseCase(
            sessionRepository: sessionRepo,
            subjectRepository: subjectRepo,
            materialRepository: materialRepo
        )

        try await useCase.saveManualSession(
            subjectId: 1,
            materialId: 10,
            startTime: 1_000,
            endTime: 61_000,
            note: "   "
        )

        let saved = try XCTUnwrap(sessionRepo.insertedSessions.single)
        XCTAssertEqual(saved.subjectId, 1)
        XCTAssertEqual(saved.subjectSyncId, "subject-1")
        XCTAssertEqual(saved.subjectName, "数学")
        XCTAssertEqual(saved.materialId, 10)
        XCTAssertEqual(saved.materialSyncId, "material-10")
        XCTAssertEqual(saved.materialName, "問題集")
        XCTAssertEqual(saved.sessionType, .manual)
        XCTAssertEqual(saved.duration, 60_000)
        XCTAssertEqual(saved.intervals, [StudySessionInterval(startTime: 1_000, endTime: 61_000)])
        XCTAssertNil(saved.note)
    }

    func test_saveManualSession_allowsMissingMaterialButKeepsSubject() async throws {
        let subjectRepo = TestSubjectRepository([Subject(id: 1, syncId: "subject-1", name: "数学", color: 1)])
        let sessionRepo = TestStudySessionRepository()
        let useCase = SaveStudySessionUseCase(
            sessionRepository: sessionRepo,
            subjectRepository: subjectRepo,
            materialRepository: TestMaterialRepository()
        )

        try await useCase.saveManualSession(subjectId: 1, materialId: nil, startTime: 1_000, endTime: 2_000, note: "memo")

        let saved = try XCTUnwrap(sessionRepo.insertedSessions.single)
        XCTAssertNil(saved.materialId)
        XCTAssertNil(saved.materialSyncId)
        XCTAssertEqual(saved.materialName, "")
        XCTAssertEqual(saved.note, "memo")
    }

    func test_saveManualSession_rejectsMissingSubject() async {
        let useCase = SaveStudySessionUseCase(
            sessionRepository: TestStudySessionRepository(),
            subjectRepository: TestSubjectRepository(),
            materialRepository: TestMaterialRepository()
        )

        do {
            try await useCase.saveManualSession(subjectId: 404, materialId: nil, startTime: 1_000, endTime: 2_000, note: nil)
            XCTFail("Expected missing subject validation error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "科目を選択してください")
        }
    }

    func test_saveManualSession_rejectsInvalidTimeRangeBeforeSaving() async {
        let sessionRepo = TestStudySessionRepository()
        let useCase = SaveStudySessionUseCase(
            sessionRepository: sessionRepo,
            subjectRepository: TestSubjectRepository([Subject(id: 1, name: "数学", color: 1)]),
            materialRepository: TestMaterialRepository()
        )

        do {
            try await useCase.saveManualSession(subjectId: 1, materialId: nil, startTime: 2_000, endTime: 1_000, note: nil)
            XCTFail("Expected invalid range validation error")
        } catch {
            XCTAssertEqual(error.localizedDescription, "終了時刻は開始時刻より後にしてください")
            XCTAssertTrue(sessionRepo.insertedSessions.isEmpty)
        }
    }
}

private extension Array {
    var single: Element? {
        count == 1 ? self[0] : nil
    }
}
