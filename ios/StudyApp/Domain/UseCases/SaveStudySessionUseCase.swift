import Foundation

struct SaveStudySessionUseCase {
    let sessionRepository: StudySessionRepository
    let subjectRepository: SubjectRepository
    let materialRepository: MaterialRepository

    func saveManualSession(subjectId: Int64, materialId: Int64?, startTime: Int64, endTime: Int64, note: String?) async throws {
        guard let subject = try await subjectRepository.getSubjectById(subjectId) else {
            throw ValidationError(message: "科目を選択してください")
        }
        let duration = endTime - startTime
        guard duration > 0 else {
            throw ValidationError(message: "終了時刻は開始時刻より後にしてください")
        }
        let materials = try await materialRepository.getAllMaterials()
        let material = materials.first(where: { $0.id == materialId })
        let materialName = material?.name ?? ""
        try await sessionRepository.insertSession(
            StudySession(
                materialId: materialId,
                materialSyncId: material?.syncId,
                materialName: materialName,
                subjectId: subject.id,
                subjectSyncId: subject.syncId,
                subjectName: subject.name,
                sessionType: .manual,
                startTime: startTime,
                endTime: endTime,
                intervals: [StudySessionInterval(startTime: startTime, endTime: endTime)],
                note: note?.nilIfBlank
            )
        )
    }
}
