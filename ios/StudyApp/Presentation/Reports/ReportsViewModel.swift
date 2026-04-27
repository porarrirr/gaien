import Combine
import Foundation

@MainActor
final class ReportsViewModel: ScreenViewModel {
    @Published private(set) var reports = ReportsData(
        daily: [],
        weekly: [],
        monthly: [],
        bySubject: [],
        ratingAverages: RatingAveragesData(
            today: RatingAverageSummary(average: nil, ratedMinutes: 0),
            week: RatingAverageSummary(average: nil, ratedMinutes: 0),
            month: RatingAverageSummary(average: nil, ratedMinutes: 0)
        ),
        streakDays: 0,
        bestStreak: 0
    )

    func load() async {
        do {
            let useCase = GetReportsDataUseCase(subjectRepository: app.persistence, sessionRepository: app.persistence, clock: app.clock)
            reports = try await useCase.execute()
        } catch {
            app.present(error)
        }
    }
}
