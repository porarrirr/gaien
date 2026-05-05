import SwiftUI
import FirebaseCore

@main
struct StudyAppApp: App {
    init() {
        FirebaseBootstrap.configureIfAvailable()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
