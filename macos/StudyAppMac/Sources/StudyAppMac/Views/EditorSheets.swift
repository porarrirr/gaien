import SwiftUI

struct SessionEditorSheet: View {
    @Bindable var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSubjectID: UUID?
    @State private var selectedMaterialID: UUID?
    @State private var minutes = 45
    @State private var rating = 4
    @State private var note = ""

    var body: some View {
        Form {
            Picker("Subject", selection: $selectedSubjectID) {
                ForEach(store.subjects) { subject in
                    Text(subject.name).tag(Optional(subject.id))
                }
            }

            Picker("Material", selection: $selectedMaterialID) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(store.materials.filter { $0.subjectID == selectedSubjectID }) { material in
                    Text(material.title).tag(Optional(material.id))
                }
            }

            Stepper("Minutes: \(minutes)", value: $minutes, in: 1...720, step: 5)
            Stepper("Rating: \(rating)", value: $rating, in: 1...5)
            TextField("Note", text: $note, axis: .vertical)

            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save") {
                    if let selectedSubjectID {
                        store.addSession(
                            subjectID: selectedSubjectID,
                            materialID: selectedMaterialID,
                            minutes: minutes,
                            rating: rating,
                            note: note
                        )
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedSubjectID == nil)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            selectedSubjectID = selectedSubjectID ?? store.subjects.first?.id
        }
    }
}

struct SubjectEditorSheet: View {
    @Bindable var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var colorHex = "7B61FF"

    var body: some View {
        Form {
            TextField("Name", text: $name)
            Picker("Color", selection: $colorHex) {
                Text("Blue").tag("2F80ED")
                Text("Green").tag("27AE60")
                Text("Orange").tag("C05621")
                Text("Purple").tag("7B61FF")
                Text("Red").tag("EB5757")
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save") {
                    store.addSubject(name: name.trimmingCharacters(in: .whitespacesAndNewlines), colorHex: colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24)
        .frame(width: 360)
    }
}

struct MaterialEditorSheet: View {
    @Bindable var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var selectedSubjectID: UUID?
    @State private var detail = ""

    var body: some View {
        Form {
            TextField("Title", text: $title)
            Picker("Subject", selection: $selectedSubjectID) {
                ForEach(store.subjects) { subject in
                    Text(subject.name).tag(Optional(subject.id))
                }
            }
            TextField("Detail", text: $detail)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save") {
                    if let selectedSubjectID {
                        store.addMaterial(
                            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                            subjectID: selectedSubjectID,
                            detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                    }
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedSubjectID == nil)
            }
        }
        .padding(24)
        .frame(width: 420)
        .onAppear {
            selectedSubjectID = selectedSubjectID ?? store.subjects.first?.id
        }
    }
}

struct GoalEditorSheet: View {
    @Bindable var store: StudyStore
    @Environment(\.dismiss) private var dismiss
    @State private var cadence = StudyGoal.Cadence.daily
    @State private var targetMinutes = 120
    @State private var selectedSubjectID: UUID?

    var body: some View {
        Form {
            Picker("Cadence", selection: $cadence) {
                ForEach(StudyGoal.Cadence.allCases) { cadence in
                    Text(cadence.title).tag(cadence)
                }
            }
            Stepper("Target: \(targetMinutes.studyDurationText)", value: $targetMinutes, in: 15...4_200, step: 15)
            Picker("Subject", selection: $selectedSubjectID) {
                Text("All subjects").tag(Optional<UUID>.none)
                ForEach(store.subjects) { subject in
                    Text(subject.name).tag(Optional(subject.id))
                }
            }
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) {
                    dismiss()
                }
                Button("Save") {
                    store.addGoal(cadence: cadence, targetMinutes: targetMinutes, subjectID: selectedSubjectID)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 380)
    }
}
