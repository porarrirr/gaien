import Foundation

struct ProblemChapter: Identifiable, Codable, Hashable {
    var id: String = UUID().uuidString.lowercased()
    var title: String
    var problemCount: Int

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case problemCount
    }

    init(id: String = UUID().uuidString.lowercased(), title: String, problemCount: Int) {
        self.id = id
        self.title = title
        self.problemCount = problemCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString.lowercased()
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? "章"
        problemCount = try container.decodeIfPresent(Int.self, forKey: .problemCount) ?? 0
    }
}

struct ProblemNumberLocation: Hashable {
    var globalNumber: Int
    var chapterIndex: Int
    var chapterTitle: String
    var localNumber: Int

    var displayText: String {
        "\(chapterTitle) \(localNumber)問"
    }
}

extension Array where Element == ProblemChapter {
    var totalProblemCount: Int {
        reduce(0) { $0 + Swift.max($1.problemCount, 0) }
    }

    func location(for globalNumber: Int) -> ProblemNumberLocation? {
        guard globalNumber > 0 else { return nil }
        var offset = 0
        for (index, chapter) in enumerated() {
            let count = Swift.max(chapter.problemCount, 0)
            guard count > 0 else { continue }
            let range = (offset + 1)...(offset + count)
            if range.contains(globalNumber) {
                return ProblemNumberLocation(
                    globalNumber: globalNumber,
                    chapterIndex: index,
                    chapterTitle: chapter.title,
                    localNumber: globalNumber - offset
                )
            }
            offset += count
        }
        return nil
    }

    func label(for globalNumber: Int) -> String {
        location(for: globalNumber)?.displayText ?? "\(globalNumber)問"
    }
}
