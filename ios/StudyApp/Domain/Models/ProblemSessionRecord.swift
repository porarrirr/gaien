import Foundation

enum StudySessionType: String, Codable, CaseIterable, Hashable {
    case stopwatch = "STOPWATCH"
    case timer = "TIMER"
    case manual = "MANUAL"

    var title: String {
        switch self {
        case .stopwatch: return "ストップウォッチ"
        case .timer: return "タイマー"
        case .manual: return "手動"
        }
    }
}

enum ProblemResult: String, Codable, CaseIterable, Hashable {
    case correct
    case wrong
    case reviewCorrect

    var title: String {
        switch self {
        case .correct: return "正解"
        case .wrong: return "不正解"
        case .reviewCorrect: return "復習正解"
        }
    }
}

struct ProblemSessionRecord: Identifiable, Codable, Hashable {
    var number: Int
    var result: ProblemResult
    var detail: String?
    var subNumber: String?

    var normalizedSubNumber: String? {
        subNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    var stableKey: String {
        if let normalizedSubNumber {
            return "\(number):\(normalizedSubNumber)"
        }
        return "\(number)"
    }

    var id: String { stableKey }

    var displayNumber: String {
        if let normalizedSubNumber {
            return "\(number)問(\(normalizedSubNumber))"
        }
        return "\(number)問"
    }

    var isWrong: Bool {
        get { result == .wrong }
        set { result = newValue ? .wrong : .correct }
    }

    init(number: Int, result: ProblemResult, detail: String? = nil, subNumber: String? = nil) {
        self.number = number
        self.result = result
        self.detail = detail
        self.subNumber = subNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    init(number: Int, isWrong: Bool, detail: String? = nil, subNumber: String? = nil) {
        self.init(number: number, result: isWrong ? .wrong : .correct, detail: detail, subNumber: subNumber)
    }

    private enum CodingKeys: String, CodingKey {
        case number
        case result
        case isWrong
        case detail
        case subNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .number)
        if let resultValue = try container.decodeIfPresent(String.self, forKey: .result) {
            switch resultValue {
            case ProblemResult.correct.rawValue, "CORRECT":
                result = .correct
            case ProblemResult.wrong.rawValue, "WRONG":
                result = .wrong
            case ProblemResult.reviewCorrect.rawValue, "REVIEW_CORRECT":
                result = .reviewCorrect
            default:
                result = (try container.decodeIfPresent(Bool.self, forKey: .isWrong) ?? false) ? .wrong : .correct
            }
        } else {
            result = (try container.decodeIfPresent(Bool.self, forKey: .isWrong) ?? false) ? .wrong : .correct
        }
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
        subNumber = try container.decodeIfPresent(String.self, forKey: .subNumber)
        subNumber = subNumber?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(result, forKey: .result)
        try container.encode(isWrong, forKey: .isWrong)
        try container.encodeIfPresent(detail, forKey: .detail)
        try container.encodeIfPresent(normalizedSubNumber, forKey: .subNumber)
    }
}

enum ProblemSessionReviewResolver {
    static func canonicalInputSession(_ session: StudySession) -> StudySession {
        replacingProblemRecords(in: session, with: canonicalInputRecords(session.problemRecords))
    }

    static func applyingAutomaticReviewCorrect(
        to session: StudySession,
        previousResults: inout [String: ProblemResult]
    ) -> StudySession {
        let resolved = canonicalInputRecords(session.problemRecords).map { record in
            let inputResult = userInputResult(record.result)
            let resolvedResult: ProblemResult = if inputResult == .correct, previousResults[record.stableKey] == .wrong {
                .reviewCorrect
            } else {
                inputResult
            }
            previousResults[record.stableKey] = inputResult
            return ProblemSessionRecord(
                number: record.number,
                result: resolvedResult,
                detail: record.detail,
                subNumber: record.normalizedSubNumber
            )
        }
        return replacingProblemRecords(in: session, with: resolved)
    }

    static func canonicalInputRecords(_ records: [ProblemSessionRecord]) -> [ProblemSessionRecord] {
        var latestByKey = [String: ProblemSessionRecord]()
        for record in records {
            let normalized = ProblemSessionRecord(
                number: record.number,
                result: userInputResult(record.result),
                detail: record.detail?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfBlank,
                subNumber: record.normalizedSubNumber
            )
            latestByKey[normalized.stableKey] = normalized
        }
        return latestByKey.values.sorted { lhs, rhs in
            lhs.number == rhs.number
                ? (lhs.normalizedSubNumber ?? "") < (rhs.normalizedSubNumber ?? "")
                : lhs.number < rhs.number
        }
    }

    private static func userInputResult(_ result: ProblemResult) -> ProblemResult {
        result == .wrong ? .wrong : .correct
    }

    private static func replacingProblemRecords(
        in session: StudySession,
        with records: [ProblemSessionRecord]
    ) -> StudySession {
        guard !records.isEmpty else {
            var updated = session
            updated.problemRecords = []
            return updated
        }
        var updated = session
        updated.problemRecords = records
        updated.problemStart = records.map(\.number).min()
        updated.problemEnd = records.map(\.number).max()
        updated.wrongProblemCount = records.filter(\.isWrong).count
        return updated
    }
}
