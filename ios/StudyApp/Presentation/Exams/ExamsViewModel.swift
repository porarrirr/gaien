import Combine
import Foundation

@MainActor
final class ExamsViewModel: ScreenViewModel {
    @Published private(set) var exams: [Exam] = []

    func load() async {
        do {
            exams = try await app.persistence.getAllExams()
        } catch {
            app.present(error)
        }
    }

    func saveExam(id: Int64? = nil, name: String, date: Date, note: String?) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "テスト名を入力してください") }
            let exam = Exam(id: id ?? 0, name: trimmed, date: date.startOfDay.epochDay, note: note?.nilIfBlank)
            if id == nil {
                _ = try await self.app.persistence.insertExam(exam)
            } else {
                try await self.app.persistence.updateExam(exam)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteExam(_ exam: Exam) {
        perform {
            try await self.app.persistence.deleteExam(exam)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}
