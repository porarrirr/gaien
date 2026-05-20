import SwiftUI

@main
struct StudyAppMacApp: App {
    @State private var store = StudyStore()

    var body: some Scene {
        WindowGroup("StudyApp", id: "main") {
            ContentView(store: store)
                .frame(minWidth: 980, minHeight: 640)
        }
        .commands {
            SidebarCommands()
            CommandMenu("Study") {
                Button("Start Quick Session") {
                    store.startTimer()
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Stop Session") {
                    store.stopTimer()
                }
                .keyboardShortcut(".", modifiers: [.command])
                .disabled(!store.timer.isRunning)
            }
        }

        Settings {
            SettingsView(store: store)
        }
    }
}
