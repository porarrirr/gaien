import Combine
import Foundation

@MainActor
final class OnboardingViewModel: ScreenViewModel {
    func complete() {
        app.completeOnboarding()
    }
}
