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

    var id: Int { number }

    var isWrong: Bool {
        get { result == .wrong }
        set { result = newValue ? .wrong : .correct }
    }

    init(number: Int, result: ProblemResult, detail: String? = nil) {
        self.number = number
        self.result = result
        self.detail = detail
    }

    init(number: Int, isWrong: Bool, detail: String? = nil) {
        self.init(number: number, result: isWrong ? .wrong : .correct, detail: detail)
    }

    private enum CodingKeys: String, CodingKey {
        case number
        case result
        case isWrong
        case detail
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        number = try container.decode(Int.self, forKey: .number)
        result = try container.decodeIfPresent(ProblemResult.self, forKey: .result)
            ?? ((try container.decodeIfPresent(Bool.self, forKey: .isWrong) ?? false) ? .wrong : .correct)
        detail = try container.decodeIfPresent(String.self, forKey: .detail)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(number, forKey: .number)
        try container.encode(result, forKey: .result)
        try container.encode(isWrong, forKey: .isWrong)
        try container.encodeIfPresent(detail, forKey: .detail)
    }
}
