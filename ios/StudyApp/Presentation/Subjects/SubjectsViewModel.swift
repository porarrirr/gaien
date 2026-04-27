import Combine
import Foundation

@MainActor
final class SubjectsViewModel: ScreenViewModel {
    @Published private(set) var subjects: [Subject] = []

    func load() async {
        do {
            subjects = try await app.persistence.getAllSubjects()
        } catch {
            app.present(error)
        }
    }

    func saveSubject(id: Int64? = nil, name: String, color: Int, icon: SubjectIcon?) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "科目名を入力してください") }
            if let id {
                try await self.app.persistence.updateSubject(
                    Subject(id: id, name: trimmed, color: color, icon: icon, createdAt: Date().epochMilliseconds, updatedAt: Date().epochMilliseconds)
                )
            } else {
                _ = try await self.app.persistence.insertSubject(Subject(name: trimmed, color: color, icon: icon))
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteSubject(_ subject: Subject) {
        perform {
            try await self.app.persistence.deleteSubject(subject)
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}
