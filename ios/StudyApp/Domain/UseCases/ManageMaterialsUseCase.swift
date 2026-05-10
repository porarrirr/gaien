import Foundation

struct ManageMaterialsUseCase {
    let materialRepository: MaterialRepository
    let subjectRepository: SubjectRepository
    let bookSearchRepository: BookSearchRepository

    func searchBook(isbn: String) async throws -> BookInfo {
        try await bookSearchRepository.searchByIsbn(isbn)
    }

    func addMaterial(
        name: String,
        subjectId: Int64,
        totalPages: Int,
        color: Int? = nil,
        note: String? = nil
    ) async throws {
        guard let subject = try await subjectRepository.getSubjectById(subjectId) else {
            throw ValidationError(message: "科目を選択してください")
        }
        try await materialRepository.insertMaterial(
            Material(
                name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                subjectId: subjectId,
                subjectSyncId: subject.syncId,
                totalPages: totalPages,
                currentPage: 0,
                color: color,
                note: note?.nilIfBlank
            )
        )
    }
}
