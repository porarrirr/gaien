import Combine
import Foundation

@MainActor
final class HomeViewModel: ScreenViewModel {
    @Published private(set) var homeData = HomeData(todayStudyMinutes: 0, todaySessions: [], todayGoal: nil, weeklyGoal: nil, weeklyStudyMinutes: 0, upcomingExams: [])
    @Published private(set) var recentMaterials: [(Material, Subject)] = []

    func load() async {
        do {
            let homeUseCase = GetHomeDataUseCase(studySessionRepository: app.persistence, goalRepository: app.persistence, examRepository: app.persistence, clock: app.clock)
            let recentUseCase = GetRecentMaterialsUseCase(materialRepository: app.persistence, studySessionRepository: app.persistence, subjectRepository: app.persistence)
            homeData = try await homeUseCase.execute()
            recentMaterials = try await recentUseCase.execute()
        } catch {
            app.present(error)
        }
    }
}
