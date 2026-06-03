import XCTest
@testable import StudyApp

/// Pure validation tests for the problem-progress fields the timer evaluates
/// when a session ends (or when the user manually enters one). Previously
/// lived as a private method on `TimerViewModel` and was hard to reach from
/// tests. The rules matter because they are the only gate that prevents a
/// corrupted problem range from getting saved.
final class TimerProblemValidationTests: XCTestCase {

    // MARK: - validate(problemStart:problemEnd:wrongProblemCount:)

    func test_validate_allowsNilTriple() {
        XCTAssertNoThrow(
            try TimerProblemValidation.validate(
                problemStart: nil,
                problemEnd: nil,
                wrongProblemCount: nil
            )
        )
    }

    func test_validate_rejectsPartialRange() {
        // `problemStart` set but no `problemEnd` is ambiguous.
        XCTAssertThrowsError(
            try TimerProblemValidation.validate(
                problemStart: 1,
                problemEnd: nil,
                wrongProblemCount: nil
            )
        )
    }

    func test_validate_rejectsNegativeStart() {
        XCTAssertThrowsError(
            try TimerProblemValidation.validate(
                problemStart: 0,
                problemEnd: 5,
                wrongProblemCount: nil
            )
        )
    }

    func test_validate_rejectsInvertedRange() {
        XCTAssertThrowsError(
            try TimerProblemValidation.validate(
                problemStart: 10,
                problemEnd: 5,
                wrongProblemCount: nil
            )
        )
    }

    func test_validate_rejectsNegativeWrongCount() {
        XCTAssertThrowsError(
            try TimerProblemValidation.validate(
                problemStart: 1,
                problemEnd: 10,
                wrongProblemCount: -1
            )
        )
    }

    func test_validate_rejectsWrongCountExceedingRangeSize() {
        // Range 1...3 is 3 problems; 4 wrong is impossible.
        XCTAssertThrowsError(
            try TimerProblemValidation.validate(
                problemStart: 1,
                problemEnd: 3,
                wrongProblemCount: 4
            )
        )
    }

    func test_validate_allowsWrongCountEqualToRangeSize() {
        XCTAssertNoThrow(
            try TimerProblemValidation.validate(
                problemStart: 1,
                problemEnd: 3,
                wrongProblemCount: 3
            )
        )
    }

    // MARK: - validateRating

    func test_validateRating_acceptsOneThroughFive() {
        for value in 1...5 {
            XCTAssertNoThrow(try TimerProblemValidation.validateRating(value))
        }
    }

    func test_validateRating_rejectsZero() {
        XCTAssertThrowsError(try TimerProblemValidation.validateRating(0))
    }

    func test_validateRating_rejectsSix() {
        XCTAssertThrowsError(try TimerProblemValidation.validateRating(6))
    }

    // MARK: - normalise

    func test_normalise_sortsByNumber() {
        let records = [
            ProblemSessionRecord(number: 3, isWrong: false),
            ProblemSessionRecord(number: 1, isWrong: true),
            ProblemSessionRecord(number: 2, isWrong: false)
        ]
        let normalised = TimerProblemValidation.normalise(records: records, totalProblems: 0)
        XCTAssertEqual(normalised.map(\.number), [1, 2, 3])
    }

    func test_normalise_clipsToTotalProblemsWhenProvided() {
        let records = [
            ProblemSessionRecord(number: 1, isWrong: false),
            ProblemSessionRecord(number: 5, isWrong: true),
            ProblemSessionRecord(number: 10, isWrong: false)
        ]
        let normalised = TimerProblemValidation.normalise(records: records, totalProblems: 5)
        XCTAssertEqual(normalised.map(\.number), [1, 5])
    }

    func test_normalise_doesNotClipWhenTotalProblemsIsZero() {
        let records = [
            ProblemSessionRecord(number: 1, isWrong: false),
            ProblemSessionRecord(number: 10_000, isWrong: true)
        ]
        let normalised = TimerProblemValidation.normalise(records: records, totalProblems: 0)
        XCTAssertEqual(normalised.count, 2)
    }

    func test_normalise_keepsSubQuestionsAsSeparateRecords() {
        let records = [
            ProblemSessionRecord(number: 1, result: .correct),
            ProblemSessionRecord(number: 1, result: .wrong, subNumber: "2"),
            ProblemSessionRecord(number: 1, result: .correct, subNumber: "1")
        ]
        let normalised = TimerProblemValidation.normalise(records: records, totalProblems: 0)

        XCTAssertEqual(normalised.map(\.stableKey), ["1", "1:1", "1:2"])
    }

    func test_problemSessionRecord_decodesOldMainProblemPayload() throws {
        let data = #"[{"number":3,"result":"WRONG"}]"#.data(using: .utf8)!
        let records = try JSONDecoder().decode([ProblemSessionRecord].self, from: data)

        XCTAssertEqual(records.first?.number, 3)
        XCTAssertEqual(records.first?.normalizedSubNumber, nil)
        XCTAssertEqual(records.first?.result, .wrong)
    }

    func test_reviewResolver_treatsManualReviewCorrectAsCorrectInput() {
        let records = ProblemSessionReviewResolver.canonicalInputRecords([
            ProblemSessionRecord(number: 1, result: .reviewCorrect)
        ])

        XCTAssertEqual(records.map(\.result), [.correct])
    }

    func test_reviewResolver_marksCorrectAfterPreviousWrongAsReviewCorrect() {
        var previousResults = [String: ProblemResult]()
        let first = ProblemSessionReviewResolver.applyingAutomaticReviewCorrect(
            to: makeSession(
                startTime: 1_000,
                records: [ProblemSessionRecord(number: 4, result: .wrong)]
            ),
            previousResults: &previousResults
        )
        let second = ProblemSessionReviewResolver.applyingAutomaticReviewCorrect(
            to: makeSession(
                startTime: 2_000,
                records: [ProblemSessionRecord(number: 4, result: .correct)]
            ),
            previousResults: &previousResults
        )
        let third = ProblemSessionReviewResolver.applyingAutomaticReviewCorrect(
            to: makeSession(
                startTime: 3_000,
                records: [ProblemSessionRecord(number: 4, result: .correct)]
            ),
            previousResults: &previousResults
        )

        XCTAssertEqual(first.problemRecords.map(\.result), [.wrong])
        XCTAssertEqual(second.problemRecords.map(\.result), [.reviewCorrect])
        XCTAssertEqual(third.problemRecords.map(\.result), [.correct])
        XCTAssertEqual(second.wrongProblemCount, 0)
    }

    private func makeSession(startTime: Int64, records: [ProblemSessionRecord]) -> StudySession {
        StudySession(
            materialId: 10,
            subjectId: 1,
            startTime: startTime,
            endTime: startTime + 600_000,
            problemRecords: records
        )
    }
}
