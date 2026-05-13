import Combine
import Foundation

@MainActor
class ScreenViewModel: ObservableObject {
    let app: StudyAppContainer
    private var appChangeCancellable: AnyCancellable?

    init(app: StudyAppContainer) {
        self.app = app
        appChangeCancellable = app.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
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
