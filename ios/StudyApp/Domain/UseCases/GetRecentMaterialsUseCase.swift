import Foundation

struct GetRecentMaterialsUseCase {
    let materialRepository: MaterialRepository
    let studySessionRepository: StudySessionRepository
    let subjectRepository: SubjectRepository

    func execute(limit: Int = 5) async throws -> [(Material, Subject)] {
        async let materialsTask = materialRepository.getAllMaterials()
        async let sessionsTask = studySessionRepository.getAllSessions()
        async let subjectsTask = subjectRepository.getAllSubjects()

        let materials = try await materialsTask
        let sessions = try await sessionsTask
        let subjects = try await subjectsTask

        let subjectMap = Dictionary(uniqueKeysWithValues: subjects.map { ($0.id, $0) })
        let materialMap = Dictionary(uniqueKeysWithValues: materials.map { ($0.id, $0) })
        let sortedSessions = sessions.sorted { $0.startTime > $1.startTime }
        var orderedIds = [Int64]()
        for materialId in sortedSessions.compactMap(\.materialId) where !orderedIds.contains(materialId) {
            orderedIds.append(materialId)
            if orderedIds.count == limit {
                break
            }
        }
        return orderedIds.compactMap { materialId in
            guard let material = materialMap[materialId], let subject = subjectMap[material.subjectId] else { return nil }
            return (material, subject)
        }
    }
}
