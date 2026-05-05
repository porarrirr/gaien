import SwiftUI
import FirebaseCore

@main
struct StudyAppApp: App {
    @StateObject private var app: StudyAppContainer

    init() {
        FirebaseBootstrap.configureIfAvailable()
        _app = StateObject(wrappedValue: StudyAppContainer())
    }

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
        }
    }
}
