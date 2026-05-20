import SwiftUI

struct SettingsView: View {
    @Bindable var store: StudyStore

    var body: some View {
        Form {
            Section("Data") {
                LabeledContent("Subjects", value: "\(store.subjects.count)")
                LabeledContent("Materials", value: "\(store.materials.count)")
                LabeledContent("Sessions", value: "\(store.sessions.count)")
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .frame(width: 420, height: 260)
    }
}
