import SwiftUI

struct SessionsView: View {
    @Bindable var store: StudyStore
    let showSessionSheet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "Sessions", subtitle: "Review and maintain your study history.") {
                Button(action: showSessionSheet) {
                    Label("Add Session", systemImage: "plus")
                }
            }
            .padding(24)

            List {
                ForEach(store.recentSessions) { session in
                    SessionRow(store: store, session: session)
                }
                .onDelete(perform: store.deleteSessions)
            }
            .listStyle(.inset)
        }
        .navigationTitle("Sessions")
    }
}

struct SubjectsView: View {
    @Bindable var store: StudyStore
    let showSubjectSheet: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(title: "Subjects", subtitle: "Organize study time by subject.") {
                    Button(action: showSubjectSheet) {
                        Label("Add Subject", systemImage: "plus")
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 210), spacing: 12)], spacing: 12) {
                    ForEach(store.subjects) { subject in
                        SectionCard(title: subject.name) {
                            HStack {
                                Circle()
                                    .fill(subject.color)
                                    .frame(width: 18, height: 18)
                                Text(subjectSessions(for: subject).studyDurationText)
                                    .font(.title3.weight(.semibold))
                                Spacer()
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Subjects")
    }

    private func subjectSessions(for subject: StudySubject) -> Int {
        store.sessions
            .filter { $0.subjectID == subject.id }
            .reduce(0) { $0 + $1.durationMinutes }
    }
}

struct MaterialsView: View {
    @Bindable var store: StudyStore
    let showMaterialSheet: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(title: "Materials", subtitle: "Keep books, decks, and resources tied to subjects.") {
                Button(action: showMaterialSheet) {
                    Label("Add Material", systemImage: "plus")
                }
            }
            .padding(24)

            List(store.materials) { material in
                VStack(alignment: .leading, spacing: 4) {
                    Text(material.title)
                        .font(.headline)
                    HStack {
                        if let subject = store.subject(for: material.subjectID) {
                            Label(subject.name, systemImage: "books.vertical")
                        }
                        if !material.detail.isEmpty {
                            Text(material.detail)
                        }
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .listStyle(.inset)
        }
        .navigationTitle("Materials")
    }
}

struct GoalsView: View {
    @Bindable var store: StudyStore
    let showGoalSheet: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HeaderView(title: "Goals", subtitle: "Set daily and weekly study targets.") {
                    Button(action: showGoalSheet) {
                        Label("Add Goal", systemImage: "plus")
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 12)], spacing: 12) {
                    ForEach(store.goals) { goal in
                        SectionCard(title: goal.cadence.title) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(goal.targetMinutes.studyDurationText)
                                    .font(.title2.weight(.semibold))
                                if let subject = store.subject(for: goal.subjectID) {
                                    Label(subject.name, systemImage: "books.vertical")
                                        .foregroundStyle(.secondary)
                                } else {
                                    Label("All subjects", systemImage: "tray.full")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .padding(24)
        }
        .navigationTitle("Goals")
    }
}
