import Foundation
import SwiftUI

// MARK: - TimerScreen

struct TimerScreen: View {
    @StateObject private var viewModel: TimerViewModel
    @State private var showManualEntry = false
    @State private var manualNote = ""
    @State private var sessionRatingDraft: Int?
    @State private var sessionNoteDraft = ""
    @State private var sessionProblemStartDraft = ""
    @State private var sessionProblemEndDraft = ""
    @State private var sessionWrongCountDraft = ""
    @State private var sessionProblemRecords: [ProblemSessionRecord] = []
    @State private var sessionProblemCountDraft = ""
    @State private var initializedEvaluationId: UUID?
    @State private var ringScale: CGFloat = 1.0

    init(app: StudyAppContainer) {
        _viewModel = StateObject(wrappedValue: TimerViewModel(app: app))
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppSpacing.xl) {
                    selectorSection

                    timerModeSection

                    ZStack {
                        ProgressRing(
                            progress: timerProgress,
                            size: timerRingSize(for: geometry.size),
                            lineWidth: 16,
                            ringColor: viewModel.isRunning ? Color.accentColor : Color.secondary.opacity(0.4),
                            showPercentage: false
                        )
                        .scaleEffect(ringScale)

                        VStack(spacing: AppSpacing.xs) {
                            Text(durationString(milliseconds: viewModel.displayMilliseconds))
                                .font(.system(size: 48, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(AppColors.textPrimary)
                            if viewModel.isRunning {
                                Text(viewModel.mode == .timer ? "カウントダウン中" : "記録中")
                                    .font(.caption.bold())
                                    .foregroundStyle(.tint)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(.tint.opacity(0.12), in: Capsule())
                                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
                            }
                        }
                        .animation(.easeOut(duration: 0.25), value: viewModel.isRunning)
                    }
                    .onChange(of: viewModel.isRunning) { running in
                        if running {
                            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                ringScale = 1.02
                            }
                        } else {
                            withAnimation(.easeOut(duration: 0.3)) {
                                ringScale = 1.0
                            }
                        }
                    }

                    controlButtonsSection
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, AppSpacing.md)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.xl)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    Divider()
                    manualEntryButton
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, 12)
                }
                .background(AppColors.subtleBackground)
            }
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("タイマー")
        .sheet(isPresented: $showManualEntry) {
            NavigationStack {
                ManualEntrySheet(viewModel: viewModel, manualNote: $manualNote, isPresented: $showManualEntry)
            }
        }
        .sheet(item: $viewModel.pendingSessionEvaluation, onDismiss: {
            sessionRatingDraft = nil
            initializedEvaluationId = nil
        }) { draft in
            NavigationStack {
                SessionEvaluationSheet(
                    session: draft.session,
                    rating: $sessionRatingDraft,
                    note: $sessionNoteDraft,
                    problemStart: $sessionProblemStartDraft,
                    problemEnd: $sessionProblemEndDraft,
                    wrongProblemCount: $sessionWrongCountDraft,
                    problemRecords: $sessionProblemRecords,
                    problemCount: $sessionProblemCountDraft,
                    materialProblemCount: selectedMaterialTotalProblems,
                    onSave: {
                        guard let rating = sessionRatingDraft else { return }
                        viewModel.savePendingSessionEvaluation(
                            rating: rating,
                            note: sessionNoteDraft,
                            problemRecords: sessionProblemRecords,
                            totalProblems: parseDraftInt(sessionProblemCountDraft),
                            problemStart: Int(sessionProblemStartDraft),
                            problemEnd: Int(sessionProblemEndDraft),
                            wrongProblemCount: Int(sessionWrongCountDraft)
                        )
                    },
                    onCancel: {
                        viewModel.cancelPendingSessionEvaluation()
                    }
                )
            }
            .onAppear {
                guard initializedEvaluationId != draft.id else { return }
                initializedEvaluationId = draft.id
                sessionRatingDraft = draft.session.rating
                sessionNoteDraft = draft.session.note ?? ""
                sessionProblemStartDraft = draft.session.problemStart.map(String.init) ?? ""
                sessionProblemEndDraft = draft.session.problemEnd.map(String.init) ?? ""
                sessionWrongCountDraft = draft.session.wrongProblemCount.map(String.init) ?? ""
                sessionProblemRecords = draft.session.problemRecords
                sessionProblemCountDraft = selectedMaterialTotalProblems > 0 ? "\(selectedMaterialTotalProblems)" : ""
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
        .onChange(of: viewModel.selectedSubjectId) { _ in
            viewModel.handleSubjectSelectionChange()
        }
        .onChange(of: viewModel.selectedMaterialId) { _ in
            viewModel.handleMaterialSelectionChange()
        }
    }

    private var timerProgress: Double {
        if viewModel.mode == .timer {
            let targetMs = Double(viewModel.countdownMinutes * 60 * 1000)
            guard targetMs > 0 else { return 0 }
            return min(max(1.0 - Double(viewModel.remainingMilliseconds) / targetMs, 0), 1.0)
        }
        let targetMs: Double = 60 * 60 * 1000
        return min(Double(viewModel.elapsedMilliseconds) / targetMs, 1.0)
    }

    private var selectorSection: some View {
        VStack(spacing: AppSpacing.sm) {
            selectionRow(icon: "book.fill", title: "科目") {
                Menu {
                    if viewModel.subjects.isEmpty {
                        Text("科目を追加してください")
                    } else {
                        ForEach(viewModel.subjects) { subject in
                            Button {
                                viewModel.selectedSubjectId = subject.id
                            } label: {
                                if viewModel.effectiveSelectedSubjectId == subject.id {
                                    Label(subject.name, systemImage: "checkmark")
                                } else {
                                    Text(subject.name)
                                }
                            }
                        }
                    }
                } label: {
                    selectionMenuLabel(
                        text: selectedSubjectText,
                        isPlaceholder: viewModel.subjects.isEmpty
                    )
                }
                .disabled(viewModel.subjects.isEmpty)
            }

            selectionRow(icon: "doc.fill", title: "教材") {
                Menu {
                    Button {
                        viewModel.selectedMaterialId = nil
                    } label: {
                        if viewModel.selectedMaterialId == nil {
                            Label("なし", systemImage: "checkmark")
                        } else {
                            Text("なし")
                        }
                    }

                    ForEach(viewModel.materialsForSelectedSubject()) { material in
                        Button {
                            viewModel.selectedMaterialId = material.id
                        } label: {
                            if viewModel.selectedMaterialId == material.id {
                                Label(material.name, systemImage: "checkmark")
                            } else {
                                Text(material.name)
                            }
                        }
                    }
                } label: {
                    selectionMenuLabel(
                        text: selectedMaterialText,
                        isPlaceholder: viewModel.effectiveSelectedSubjectId == nil
                    )
                }
                .disabled(viewModel.effectiveSelectedSubjectId == nil)
            }
        }
    }

    private var primaryTimerButtonLabel: String {
        viewModel.isRunning ? "一時停止" : (viewModel.displayMilliseconds > 0 ? "再開" : "開始")
    }

    private var controlButtonsSection: some View {
        HStack(spacing: AppSpacing.xl) {
            VStack(spacing: AppSpacing.xs) {
                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            Circle().fill(viewModel.displayMilliseconds > 0 ? AppColors.danger : Color.secondary.opacity(0.3))
                        )
                }
                .disabled(viewModel.displayMilliseconds == 0)

                Text("終了")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: AppSpacing.xs) {
                Button {
                    viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
                } label: {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.white)
                        .frame(width: 80, height: 80)
                        .background(
                            Circle().fill(Color.accentColor)
                        )
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 12, y: 4)
                }

                Text(primaryTimerButtonLabel)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .padding(.bottom, AppSpacing.sm)
    }

    private var timerModeSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                timerModeButton(title: "ストップウォッチ", mode: .stopwatch)
                timerModeButton(title: "タイマー", mode: .timer)
            }
            if viewModel.mode == .timer {
                HStack(spacing: AppSpacing.sm) {
                    ForEach([15, 25, 45, 60], id: \.self) { minutes in
                        Button {
                            viewModel.setCountdownMinutes(minutes)
                        } label: {
                            Text("\(minutes)分")
                                .font(.subheadline.bold())
                                .foregroundStyle(viewModel.countdownMinutes == minutes ? Color.white : Color.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(viewModel.countdownMinutes == minutes ? Color.accentColor : Color.accentColor.opacity(0.08))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRunning)
                    }
                }
            }
        }
    }

    private func timerModeButton(title: String, mode: TimerSnapshot.Mode) -> some View {
        Button {
            viewModel.setMode(mode)
        } label: {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(viewModel.mode == mode ? Color.white : Color.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.mode == mode ? Color.accentColor : Color.accentColor.opacity(0.08))
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRunning)
    }

    private var manualEntryButton: some View {
        Button {
            showManualEntry = true
        } label: {
            HStack {
                Image(systemName: "pencil.line")
                Text("手動入力")
            }
            .font(.subheadline.bold())
            .foregroundStyle(.tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private func selectionRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(.tint)
            content()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
    }

    private var selectedSubjectText: String {
        if let subjectId = viewModel.effectiveSelectedSubjectId,
           let subject = viewModel.subjects.first(where: { $0.id == subjectId }) {
            return subject.name
        }
        return viewModel.subjects.isEmpty ? "科目を追加してください" : "科目を選択"
    }

    private var selectedMaterialText: String {
        if let materialId = viewModel.selectedMaterialId,
           let material = viewModel.materialsForSelectedSubject().first(where: { $0.id == materialId }) {
            return material.name
        }
        return "なし"
    }

    private var selectedMaterialTotalProblems: Int {
        guard let materialId = viewModel.selectedMaterialId,
              let material = viewModel.materials.first(where: { $0.id == materialId }) else {
            return 0
        }
        return material.totalProblems
    }

    private func selectionMenuLabel(text: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: AppSpacing.xs) {
            Text(text)
                .foregroundStyle(isPlaceholder ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
            Spacer(minLength: AppSpacing.xs)
            Image(systemName: "chevron.up.chevron.down")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func timerRingSize(for size: CGSize) -> CGFloat {
        let widthLimited = min(size.width - (AppSpacing.md * 2), 300)
        let heightLimited = min(max(size.height * 0.34, 220), 300)
        return max(220, min(widthLimited, heightLimited))
    }
}

private struct ManualEntrySheet: View {
    let viewModel: TimerViewModel
    @Binding var manualNote: String
    @Binding var isPresented: Bool
    @State private var manualStartTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date()) ?? Date()
    @State private var manualEndTime = Date()

    var body: some View {
        Form {
            Section("学習対象") {
                HStack {
                    Text("科目")
                    Spacer()
                    Text(viewModel.subjects.first(where: { $0.id == viewModel.selectedSubjectId })?.name ?? "-")
                        .foregroundStyle(.secondary)
                }
            }
            Section("記録") {
                DatePicker("開始時刻", selection: $manualStartTime, displayedComponents: .hourAndMinute)
                DatePicker("終了時刻", selection: $manualEndTime, displayedComponents: .hourAndMinute)
                TextField("メモ", text: $manualNote, axis: .vertical)
            }
        }
        .navigationTitle("手動入力")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { isPresented = false }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    guard let subjectId = viewModel.selectedSubjectId else { return }
                    viewModel.saveManualSession(
                        subjectId: subjectId,
                        materialId: viewModel.selectedMaterialId,
                        startTime: manualStartTime.epochMilliseconds,
                        endTime: manualEndTime.epochMilliseconds,
                        note: manualNote
                    )
                    manualNote = ""
                    isPresented = false
                }
                .disabled(manualEndTime <= manualStartTime)
            }
        }
    }
}

private struct SessionEvaluationSheet: View {
    let session: StudySession
    @Binding var rating: Int?
    @Binding var note: String
    @Binding var problemStart: String
    @Binding var problemEnd: String
    @Binding var wrongProblemCount: String
    @Binding var problemRecords: [ProblemSessionRecord]
    @Binding var problemCount: String
    let materialProblemCount: Int
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("このセッションを評価")
                        .font(.title3.bold())
                    Text(session.subjectName)
                        .font(.headline)
                    if !session.materialName.isEmpty {
                        Text(session.materialName)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    Text("\(session.durationJapaneseText) ・ \(session.sessionType.title)")
                        .font(.subheadline)
                        .foregroundStyle(.tint)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("5段階で選択")
                        .font(.subheadline.bold())
                    SessionRatingSelector(rating: $rating)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("問題集の記録")
                        .font(.subheadline.bold())
                    if materialProblemCount > 0 {
                        Text("全\(materialProblemCount)問")
                            .font(.caption.bold())
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        problemCountControls
                    }
                    if effectiveProblemCount > 0 {
                        ProblemTileSelector(totalProblems: effectiveProblemCount, records: $problemRecords)
                        Text(problemRecordSummary)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    TextField("セッションメモ", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.default)
                }

                Spacer()
            }
        }
        .padding(AppSpacing.md)
        .navigationTitle("セッション評価")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
                    .disabled(rating == nil)
            }
        }
        .onChange(of: problemCount) { _ in
            let count = effectiveProblemCount
            guard count > 0 else { return }
            problemRecords.removeAll { $0.number > count }
        }
    }

    private var problemRecordSummary: String {
        let done = problemRecords.count
        let correct = problemRecords.filter { $0.result == .correct }.count
        let wrong = problemRecords.filter(\.isWrong).count
        let review = problemRecords.filter { $0.result == .reviewCorrect }.count
        return "タップで正解、ダブルタップで不正解、長押しで復習正解とメモを編集。選択 \(done)問 / 正解 \(correct)問 / 不正解 \(wrong)問 / 復習正解 \(review)問"
    }

    private var effectiveProblemCount: Int {
        materialProblemCount > 0 ? materialProblemCount : parseDraftInt(problemCount)
    }

    private var problemCountControls: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            HStack {
                Button {
                    decrementProblemCount()
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
                .disabled(effectiveProblemCount <= 0)

                Text("全\(effectiveProblemCount)問")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)

                Button {
                    setProblemCount(effectiveProblemCount + 1)
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.bordered)
            }

            HStack(spacing: AppSpacing.xs) {
                ForEach([10, 20, 50], id: \.self) { count in
                    Button("\(count)問") {
                        setProblemCount(count)
                    }
                    .buttonStyle(.bordered)
                    .font(.caption.bold())
                }
            }
        }
    }

    private func setProblemCount(_ count: Int) {
        problemCount = "\(max(count, 0))"
    }

    private func decrementProblemCount() {
        setProblemCount(max(effectiveProblemCount - 1, 0))
    }
}

private struct ProblemTileSelector: View {
    let totalProblems: Int
    @Binding var records: [ProblemSessionRecord]
    @State private var editingNumber: Int?
    @State private var editingStatus: ProblemTileEditStatus = .untouched
    @State private var detailText = ""

    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 10), count: 5)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(1...totalProblems, id: \.self) { number in
                ProblemTile(
                    number: number,
                    record: records.first(where: { $0.number == number }),
                    onCorrectTap: { toggleCorrect(number) },
                    onWrongDoubleTap: { toggleWrong(number) },
                    onLongPress: {
                        let record = records.first(where: { $0.number == number })
                        if let record {
                            editingStatus = record.result.editStatus
                        } else {
                            editingStatus = .untouched
                        }
                        detailText = record?.detail ?? ""
                        editingNumber = number
                    }
                )
            }
        }
        .sheet(item: Binding(
            get: { editingNumber.map(ProblemTileEditTarget.init(number:)) },
            set: { if $0 == nil { editingNumber = nil } }
        )) { target in
            NavigationStack {
                Form {
                    Picker("状態", selection: $editingStatus) {
                        Text("未着手").tag(ProblemTileEditStatus.untouched)
                        Text("正解").tag(ProblemTileEditStatus.correct)
                        Text("不正解").tag(ProblemTileEditStatus.wrong)
                        Text("復習正解").tag(ProblemTileEditStatus.reviewCorrect)
                    }
                    TextField("大問・小問メモ（例: 大問2の(4)、計算ミス）", text: $detailText, axis: .vertical)
                        .keyboardType(.default)
                }
                .navigationTitle("\(target.number)問目")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") { editingNumber = nil }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("保存") {
                            saveEditedRecord(number: target.number)
                            editingNumber = nil
                        }
                    }
                }
            }
        }
    }

    private func toggleCorrect(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            if records[index].result == .wrong {
                records[index].result = .correct
            } else {
                records.remove(at: index)
            }
        } else {
            records.append(ProblemSessionRecord(number: number, isWrong: false))
            records.sort { $0.number < $1.number }
        }
    }

    private func toggleWrong(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            if records[index].isWrong {
                records.remove(at: index)
            } else {
                records[index].isWrong = true
            }
        } else {
            records.append(ProblemSessionRecord(number: number, isWrong: true))
            records.sort { $0.number < $1.number }
        }
    }

    private func saveEditedRecord(number: Int) {
        let trimmed = detailText.trimmingCharacters(in: .whitespacesAndNewlines)
        records.removeAll { $0.number == number }
        guard editingStatus != .untouched else { return }
        records.append(
            ProblemSessionRecord(
                number: number,
                result: editingStatus.problemResult ?? .correct,
                detail: trimmed.isEmpty ? nil : trimmed
            )
        )
        records.sort { $0.number < $1.number }
    }
}

private enum ProblemTileEditStatus: Hashable {
    case untouched
    case correct
    case wrong
    case reviewCorrect

    var problemResult: ProblemResult? {
        switch self {
        case .untouched: return nil
        case .correct: return .correct
        case .wrong: return .wrong
        case .reviewCorrect: return .reviewCorrect
        }
    }
}

private extension ProblemResult {
    var editStatus: ProblemTileEditStatus {
        switch self {
        case .correct: return .correct
        case .wrong: return .wrong
        case .reviewCorrect: return .reviewCorrect
        }
    }
}

private struct ProblemTileEditTarget: Identifiable {
    let number: Int
    var id: Int { number }
}

private struct ProblemTile: View {
    let number: Int
    let record: ProblemSessionRecord?
    let onCorrectTap: () -> Void
    let onWrongDoubleTap: () -> Void
    let onLongPress: () -> Void

    @State private var pendingSingleTap: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 2) {
            Text("\(number)")
                .font(.callout.bold())
                .monospacedDigit()
            if record?.detail?.nilIfBlank != nil {
                Image(systemName: "text.bubble.fill")
                    .font(.system(size: 10, weight: .bold))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 52)
        .aspectRatio(1, contentMode: .fit)
        .foregroundStyle(foreground)
        .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(border, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture(count: 2, perform: handleDoubleTap)
        .onTapGesture(count: 1, perform: handleSingleTap)
        .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("タップで正解、ダブルタップで不正解、長押しで復習正解とメモを編集")
    }

    private func handleSingleTap() {
        pendingSingleTap?.cancel()
        let task = DispatchWorkItem {
            onCorrectTap()
        }
        pendingSingleTap = task
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22, execute: task)
    }

    private func handleDoubleTap() {
        pendingSingleTap?.cancel()
        pendingSingleTap = nil
        onWrongDoubleTap()
    }

    private var background: Color {
        guard let record else { return Color.secondary.opacity(0.08) }
        switch record.result {
        case .correct: return Color.accentColor.opacity(0.16)
        case .wrong: return AppColors.danger.opacity(0.18)
        case .reviewCorrect: return AppColors.warning.opacity(0.20)
        }
    }

    private var foreground: Color {
        guard let record else { return AppColors.textSecondary }
        switch record.result {
        case .correct: return Color.accentColor
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.warning
        }
    }

    private var border: Color {
        guard let record else { return Color.secondary.opacity(0.15) }
        switch record.result {
        case .correct: return Color.accentColor.opacity(0.45)
        case .wrong: return AppColors.danger.opacity(0.55)
        case .reviewCorrect: return AppColors.warning.opacity(0.60)
        }
    }

    private var accessibilityLabel: String {
        guard let record else { return "\(number)問目 未着手" }
        return "\(number)問目 \(record.result.title)"
    }
}

private func parseDraftInt(_ value: String) -> Int {
    let normalized = value.applyingTransform(.fullwidthToHalfwidth, reverse: false) ?? value
    return Int(normalized.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
}
