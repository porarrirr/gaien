import Combine
import Foundation

@MainActor
final class MaterialsViewModel: ScreenViewModel {
    @Published private(set) var subjects: [Subject] = []
    @Published private(set) var materials: [Material] = []
    @Published private(set) var progressSummaries: [Int64: MaterialListProgressSummary] = [:]
    @Published var bookSearchResult: BookInfo?
    @Published var isShowingBookResult = false
    @Published private(set) var isSearchingBook = false

    private var lastRequestedIsbn = ""

    func load() async {
        do {
            async let subjectsTask = app.persistence.getAllSubjects()
            async let materialsTask = app.persistence.getAllMaterials()
            async let sessionsTask = app.persistence.getAllSessions()
            subjects = try await subjectsTask
            materials = try await materialsTask
            let sessions = try await sessionsTask
            let sessionsByMaterialId = sessions.reduce(into: [Int64: [StudySession]]()) { result, session in
                guard let materialId = session.materialId else { return }
                result[materialId, default: []].append(session)
            }
            progressSummaries = Dictionary(
                uniqueKeysWithValues: materials
                    .filter { $0.totalProblems > 0 }
                    .map { material in
                        (
                            material.id,
                            MaterialListProgressSummary(
                                material: material,
                                sessions: sessionsByMaterialId[material.id] ?? []
                            )
                        )
                    }
            )
        } catch {
            app.present(error)
        }
    }

    func materials(for subjectId: Int64) -> [Material] {
        materials.filter { $0.subjectId == subjectId }
    }

    func searchBook(isbn: String) {
        let normalizedIsbn = isbn
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        guard !normalizedIsbn.isEmpty else {
            app.present("ISBNを入力してください")
            return
        }
        guard !(isSearchingBook && lastRequestedIsbn == normalizedIsbn) else { return }

        isSearchingBook = true
        lastRequestedIsbn = normalizedIsbn
        perform {
            defer { self.isSearchingBook = false }
            let useCase = ManageMaterialsUseCase(materialRepository: self.app.persistence, subjectRepository: self.app.persistence, bookSearchRepository: self.app.googleBooksService)
            self.bookSearchResult = try await useCase.searchBook(isbn: normalizedIsbn)
            self.isShowingBookResult = self.bookSearchResult != nil
        }
    }

    func clearSearchResult() {
        bookSearchResult = nil
        isShowingBookResult = false
    }

    func saveMaterial(
        id: Int64? = nil,
        name: String,
        subjectId: Int64,
        totalPages: Int,
        currentPage: Int = 0,
        totalProblems: Int = 0,
        note: String?
    ) {
        perform {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { throw ValidationError(message: "教材名を入力してください") }
            guard totalPages >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard currentPage >= 0 else { throw ValidationError(message: "ページ数は0以上で入力してください") }
            guard totalProblems >= 0 else { throw ValidationError(message: "全問題数は0以上で入力してください") }
            guard totalPages == 0 || currentPage <= totalPages else { throw ValidationError(message: "現在のページは総ページ数以下にしてください") }
            if let id {
                let existing = try await self.app.persistence.getAllMaterials().first(where: { $0.id == id })
                guard let subject = try await self.app.persistence.getSubjectById(subjectId) else {
                    throw ValidationError(message: "科目を選択してください")
                }
                try await self.app.persistence.updateMaterial(
                    Material(
                        id: id,
                        name: trimmed,
                        subjectId: subjectId,
                        subjectSyncId: subject.syncId,
                        sortOrder: existing?.sortOrder ?? Date().epochMilliseconds,
                        totalPages: totalPages,
                        currentPage: currentPage,
                        totalProblems: totalProblems,
                        problemRecords: existing?.problemRecords ?? [],
                        color: nil,
                        note: note?.nilIfBlank
                    )
                )
            } else {
                let useCase = ManageMaterialsUseCase(materialRepository: self.app.persistence, subjectRepository: self.app.persistence, bookSearchRepository: self.app.googleBooksService)
                let nextOrder = (try await self.app.persistence.getAllMaterials().map(\.sortOrder).max() ?? -1) + 1
                guard let subject = try await self.app.persistence.getSubjectById(subjectId) else {
                    throw ValidationError(message: "科目を選択してください")
                }
                try await self.app.persistence.insertMaterial(
                    Material(
                        name: trimmed,
                        subjectId: subjectId,
                        subjectSyncId: subject.syncId,
                        sortOrder: nextOrder,
                        totalPages: totalPages,
                        currentPage: 0,
                        totalProblems: totalProblems,
                        color: nil,
                        note: note?.nilIfBlank
                    )
                )
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func updateProgress(materialId: Int64, currentPage: Int) {
        perform {
            let materials = try await self.app.persistence.getAllMaterials()
            guard let material = materials.first(where: { $0.id == materialId }) else {
                throw ValidationError(message: "教材が見つかりません")
            }
            var updated = material
            updated.currentPage = currentPage
            try await self.app.persistence.updateMaterial(updated)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func deleteMaterial(_ material: Material) {
        perform {
            try await self.app.persistence.deleteMaterial(material)
            await self.load()
            self.app.bumpDataVersion()
        }
    }

    func moveMaterial(_ materialId: Int64, direction: Int) {
        perform {
            var materials = try await self.app.persistence.getAllMaterials()
            guard let currentIndex = materials.firstIndex(where: { $0.id == materialId }) else { return }
            let targetIndex = currentIndex + direction
            guard materials.indices.contains(targetIndex) else { return }
            let item = materials.remove(at: currentIndex)
            materials.insert(item, at: targetIndex)
            for (index, material) in materials.enumerated() {
                var updated = material
                updated.sortOrder = Int64(index)
                try await self.app.persistence.updateMaterial(updated)
            }
            await self.load()
            self.app.bumpDataVersion()
        }
    }
}

struct MaterialListProgressSummary: Hashable {
    let totalProblems: Int
    let correctCount: Int
    let mixedCount: Int
    let untouchedCount: Int
    let latestStudyDate: Date?

    var progressedCount: Int {
        correctCount + mixedCount
    }

    var progressedRatio: Double {
        guard totalProblems > 0 else { return 0 }
        return min(max(Double(progressedCount) / Double(totalProblems), 0), 1)
    }

    var progressedPercent: Int {
        Int((progressedRatio * 100).rounded())
    }

    init(material: Material, sessions: [StudySession]) {
        let totalProblems = max(material.totalProblems, 0)
        self.totalProblems = totalProblems
        latestStudyDate = sessions.max(by: { $0.sessionStartTime < $1.sessionStartTime })?.startDate.startOfDay

        guard totalProblems > 0 else {
            correctCount = 0
            mixedCount = 0
            untouchedCount = 0
            return
        }

        let resultsByNumber = sessions.reduce(into: [Int: [ProblemResult]]()) { result, session in
            for record in session.problemRecords where (1...totalProblems).contains(record.number) {
                result[record.number, default: []].append(record.result)
            }
        }

        var correct = 0
        var mixed = 0
        for number in 1...totalProblems {
            let results = resultsByNumber[number] ?? []
            guard !results.isEmpty else { continue }
            if results.contains(.wrong) {
                mixed += 1
            } else {
                correct += 1
            }
        }

        correctCount = correct
        mixedCount = mixed
        untouchedCount = max(totalProblems - correct - mixed, 0)
    }
}
