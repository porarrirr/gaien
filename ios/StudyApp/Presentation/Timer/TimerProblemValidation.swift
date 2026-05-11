import Foundation

/// Pure validation rules for the problem-progress fields attached to a study
/// session. Extracted from `TimerViewModel` so the logic is unit-testable
/// without having to build up the full view model, container, and
/// repository chain.
enum TimerProblemValidation {

    /// Validates the problem range / wrong count triple that the timer
    /// evaluation sheet and manual entry sheet both pass in.
    ///
    /// Passing `nil` for all three is treated as "no progress recorded" and
    /// is always valid. Any other combination must satisfy:
    ///  * both `problemStart` and `problemEnd` are set,
    ///  * `problemStart > 0` and `problemEnd >= problemStart`,
    ///  * `wrongProblemCount` (if provided) is non-negative and no larger
    ///    than the range size.
    static func validate(
        problemStart: Int?,
        problemEnd: Int?,
        wrongProblemCount: Int?
    ) throws {
        if problemStart == nil && problemEnd == nil && wrongProblemCount == nil {
            return
        }
        guard let problemStart, let problemEnd else {
            throw ValidationError(message: "問題範囲は開始と終了を両方入力してください")
        }
        guard problemStart > 0, problemEnd >= problemStart else {
            throw ValidationError(message: "問題範囲を正しく入力してください")
        }
        if let wrongProblemCount {
            guard wrongProblemCount >= 0 else {
                throw ValidationError(message: "間違えた数は0以上で入力してください")
            }
            guard wrongProblemCount <= (problemEnd - problemStart + 1) else {
                throw ValidationError(message: "間違えた数は実施問題数以下にしてください")
            }
        }
    }

    /// Validates a session rating (1...5) that `TimerViewModel` and
    /// `SaveStudySessionUseCase` accept. Throws `ValidationError` when the
    /// value is outside the allowed range.
    static func validateRating(_ rating: Int) throws {
        guard StudySession.allowedRatings.contains(rating) else {
            throw ValidationError(message: "評価は1〜5で入力してください")
        }
    }

    /// Normalises a `ProblemSessionRecord` list into the canonical form used
    /// by the timer evaluation sheet: sorted by number, optionally clipped
    /// to the material's declared `totalProblems`.
    ///
    /// Passing `0` (or a negative) for `totalProblems` skips clipping,
    /// matching the previous behaviour when the material has no declared
    /// total.
    static func normalise(
        records: [ProblemSessionRecord],
        totalProblems: Int
    ) -> [ProblemSessionRecord] {
        records
            .filter { totalProblems <= 0 || $0.number <= totalProblems }
            .sorted { $0.number < $1.number }
    }
}
