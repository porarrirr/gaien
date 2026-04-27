import Combine
import Foundation

@MainActor
class ScreenViewModel: ObservableObject {
    unowned let app: StudyAppContainer

    init(app: StudyAppContainer) {
        self.app = app
    }

    func perform(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                app.present(error)
            }
        }
    }
}
