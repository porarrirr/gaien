import Combine
import Foundation

@MainActor
final class HomeViewModel: ScreenViewModel {
    @Published private(set) var homeData = HomeData(todayStudyMinutes: 0, todaySessions: [], todayGoal: nil, weeklyGoal: nil, weeklyStudyMinutes: 0, upcomingExams: [])
    @Published private(set) var recentMaterials: [(Material, Subject)] = []

    func load() async {
        do {
            let homeUseCase = GetHomeDataUseCase(
                studySessionRepository: app.sessionRepo,
                goalRepository: app.goalRepo,
                examRepository: app.examRepo,
                timetableRepository: app.timetableRepo,
                problemReviewRepository: app.problemReviewRepo,
                clock: app.clock
            )
            let recentUseCase = GetRecentMaterialsUseCase(materialRepository: app.materialRepo, studySessionRepository: app.sessionRepo, subjectRepository: app.subjectRepo)
            homeData = try await homeUseCase.execute()
            recentMaterials = try await recentUseCase.execute()
        } catch {
            app.present(error)
        }
    }
}
