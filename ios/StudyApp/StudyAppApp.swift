import SwiftUI
import FirebaseCore
import UIKit

final class StudyAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseBootstrap.configureIfAvailable()
        return true
    }
}

@main
struct StudyAppApp: App {
    @UIApplicationDelegateAdaptor(StudyAppDelegate.self) private var appDelegate
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
