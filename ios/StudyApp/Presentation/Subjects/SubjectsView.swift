import SwiftUI

struct SubjectsScreen: View {
    @StateObject private var viewModel: SubjectsViewModel
    @State private var name = ""
    @State private var color = "5025616"
    @State private var icon: SubjectIcon = .book

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: SubjectsViewModel(app: app))
    }

    var body: some View {
        List {
            Section("科目を追加") {
                TextField("科目名", text: $name)
                TextField("色(10進数)", text: $color)
                    .keyboardType(.numberPad)
                Picker("アイコン", selection: $icon) {
                    ForEach(SubjectIcon.allCases) { icon in
                        Label(icon.rawValue, systemImage: icon.systemImage).tag(icon)
                    }
                }
                Button("保存") {
                    viewModel.saveSubject(name: name, color: Int(color) ?? 0x4CAF50, icon: icon)
                    name = ""
                }
            }

            Section("一覧") {
                ForEach(viewModel.subjects) { subject in
                    HStack {
                        Image(systemName: subject.icon?.systemImage ?? SubjectIcon.book.systemImage)
                        Text(subject.name)
                        Spacer()
                        Circle()
                            .fill(Color(hex: subject.color))
                            .frame(width: 18, height: 18)
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            viewModel.deleteSubject(subject)
                        } label: {
                            Label("削除", systemImage: "trash")
                        }
                    }
                }
            }
        }
        .navigationTitle("科目")
        .task(id: viewModel.app.dataVersion) { await viewModel.load() }
    }
}
