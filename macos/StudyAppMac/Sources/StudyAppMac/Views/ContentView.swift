import SwiftUI

enum StudySection: String, CaseIterable, Identifiable {
    case dashboard
    case sessions
    case subjects
    case materials
    case goals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: "Dashboard"
        case .sessions: "Sessions"
        case .subjects: "Subjects"
        case .materials: "Materials"
        case .goals: "Goals"
        }
    }

    var systemImage: String {
        switch self {
        case .dashboard: "chart.bar.xaxis"
        case .sessions: "clock"
        case .subjects: "books.vertical"
        case .materials: "doc.text"
        case .goals: "target"
        }
    }
}

struct ContentView: View {
    @Bindable var store: StudyStore
    @SceneStorage("selectedStudySection") private var selectedSectionID: String = StudySection.dashboard.rawValue
    @State private var isShowingSessionSheet = false
    @State private var isShowingSubjectSheet = false
    @State private var isShowingMaterialSheet = false
    @State private var isShowingGoalSheet = false

    private var selection: Binding<StudySection> {
        Binding(
            get: { StudySection(rawValue: selectedSectionID) ?? .dashboard },
            set: { selectedSectionID = $0.rawValue }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                ForEach(StudySection.allCases) { section in
                    Label(section.title, systemImage: section.systemImage)
                        .tag(section)
                }
            }
            .listStyle(.sidebar)
            .navigationTitle("StudyApp")
        } detail: {
            DetailRouter(
                section: selection.wrappedValue,
                store: store,
                showSessionSheet: { isShowingSessionSheet = true },
                showSubjectSheet: { isShowingSubjectSheet = true },
                showMaterialSheet: { isShowingMaterialSheet = true },
                showGoalSheet: { isShowingGoalSheet = true }
            )
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    store.timer.isRunning ? store.stopTimer() : store.startTimer()
                } label: {
                    Label(store.timer.isRunning ? "Stop Timer" : "Start Timer", systemImage: store.timer.isRunning ? "stop.fill" : "play.fill")
                }

                Button {
                    isShowingSessionSheet = true
                } label: {
                    Label("Add Session", systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $isShowingSessionSheet) {
            SessionEditorSheet(store: store)
        }
        .sheet(isPresented: $isShowingSubjectSheet) {
            SubjectEditorSheet(store: store)
        }
        .sheet(isPresented: $isShowingMaterialSheet) {
            MaterialEditorSheet(store: store)
        }
        .sheet(isPresented: $isShowingGoalSheet) {
            GoalEditorSheet(store: store)
        }
    }
}

private struct DetailRouter: View {
    let section: StudySection
    @Bindable var store: StudyStore
    let showSessionSheet: () -> Void
    let showSubjectSheet: () -> Void
    let showMaterialSheet: () -> Void
    let showGoalSheet: () -> Void

    var body: some View {
        switch section {
        case .dashboard:
            DashboardView(store: store, showSessionSheet: showSessionSheet)
        case .sessions:
            SessionsView(store: store, showSessionSheet: showSessionSheet)
        case .subjects:
            SubjectsView(store: store, showSubjectSheet: showSubjectSheet)
        case .materials:
            MaterialsView(store: store, showMaterialSheet: showMaterialSheet)
        case .goals:
            GoalsView(store: store, showGoalSheet: showGoalSheet)
        }
    }
}
