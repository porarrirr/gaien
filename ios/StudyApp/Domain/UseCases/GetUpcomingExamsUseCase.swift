import Foundation

struct GetUpcomingExamsUseCase {
    let examRepository: ExamRepository
    let clock: Clock

    func execute(limit: Int? = nil) async throws -> [Exam] {
        let exams = try await examRepository.getUpcomingExams(now: clock.now())
        if let limit {
            return Array(exams.prefix(limit))
        }
        return exams
    }
}
