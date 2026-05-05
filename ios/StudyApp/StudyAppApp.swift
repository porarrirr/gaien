import SwiftUI
import FirebaseAppCheck
import FirebaseCore

@main
struct StudyAppApp: App {
    @StateObject private var app: StudyAppContainer

    init() {
        AppCheck.setAppCheckProviderFactory(AppAttestProviderFactory())
        FirebaseBootstrap.configureIfAvailable()
        _app = StateObject(wrappedValue: StudyAppContainer())
    }

    var body: some Scene {
        WindowGroup {
            RootView(app: app)
        }
    }
}
