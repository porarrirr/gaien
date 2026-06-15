import Foundation
import SwiftUI

// MARK: - TimerScreen

struct TimerScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject private var app: StudyAppContainer
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
    @State private var showTargetSelection = false
    @State private var isShowingClockOnlyFocus = false
    @State private var showSubjectCreator = false
    @State private var subjectCreationDraft = SubjectCreationDraft()
    @State private var isCreatingSubject = false

    init(app: StudyAppContainer) {
        _app = ObservedObject(wrappedValue: app)
        _viewModel = StateObject(wrappedValue: TimerViewModel(app: app))
    }

    var body: some View {
        GeometryReader { geometry in
            let isLandscapeFocus = shouldShowLandscapeFocus(size: geometry.size)
            Group {
                if isLandscapeFocus {
                    switch viewModel.app.preferences.landscapeTimerDisplayPreset {
                    case .problemProgress:
                        LandscapeTimerFocusView(
                            viewModel: viewModel,
                            material: selectedMaterial,
                            materialProblemCount: selectedMaterialTotalProblems,
                            materialProblemChapters: selectedMaterialProblemChapters,
                            totalProblems: timerProblemProgressTotalProblems,
                            timerText: durationString(milliseconds: viewModel.displayMilliseconds),
                            modeText: viewModel.mode == .timer ? "カウントダウン" : "記録中",
                            progress: timerProgress,
                            onPauseToggle: {
                                viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
                            },
                            onStop: {
                                viewModel.stop()
                            }
                        )
                    case .clockOnly:
                        clockOnlyFocusView {
                            viewModel.stop()
                        }
                    }
                } else {
                    portraitTimerContent(size: geometry.size)
                }
            }
            .toolbar(isLandscapeFocus ? .hidden : .visible, for: .navigationBar)
            .toolbar(isLandscapeFocus ? .hidden : .visible, for: .tabBar)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("タイマー")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showManualEntry) {
            NavigationStack {
                ManualEntrySheet(viewModel: viewModel, manualNote: $manualNote, isPresented: $showManualEntry)
            }
        }
        .sheet(isPresented: $showTargetSelection) {
            TimerTargetSelectionSheet(
                subjects: viewModel.subjects,
                materialsForSubject: { subject in
                    viewModel.materials.filter { $0.subjectId == subject.id }
                },
                recentMaterialPairs: viewModel.recentMaterialPairs,
                selectedSubjectId: viewModel.effectiveSelectedSubjectId,
                selectedMaterialId: viewModel.selectedMaterialId,
                onSelect: { subject, material in
                    viewModel.selectTimerTarget(subjectId: subject.id, materialId: material?.id)
                    showTargetSelection = false
                },
                onDismiss: {
                    showTargetSelection = false
                }
            )
        }
        .sheet(isPresented: $showSubjectCreator) {
            NavigationStack {
                SubjectCreationSheet(
                    draft: $subjectCreationDraft,
                    isSaving: isCreatingSubject,
                    onSave: createSubjectFromTimer,
                    onCancel: {
                        guard !isCreatingSubject else { return }
                        showSubjectCreator = false
                    }
                )
            }
        }
        .fullScreenCover(isPresented: $isShowingClockOnlyFocus) {
            clockOnlyFocusCover
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
                    materialProblemChapters: selectedMaterialProblemChapters,
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
                sessionProblemCountDraft = selectedMaterialTotalProblems > 0 ? "\(selectedMaterialTotalProblems)" : viewModel.timerProblemCountDraft
            }
        }
        .task(id: viewModel.app.dataVersion) {
            await viewModel.load()
        }
        .onChange(of: app.errorMessage) { message in
            guard message == nil else { return }
            guard viewModel.consumeSubjectCreatorRequestAfterMissingSubjectError() else { return }
            subjectCreationDraft = SubjectCreationDraft()
            showSubjectCreator = true
        }
        .keepScreenAwake(true)
    }

    private func createSubjectFromTimer() {
        guard !isCreatingSubject else { return }
        isCreatingSubject = true
        let name = subjectCreationDraft.name
        let color = subjectCreationDraft.colorInt
        let icon = subjectCreationDraft.icon

        Task { @MainActor in
            do {
                _ = try await viewModel.createSubject(name: name, color: color, icon: icon)
                showSubjectCreator = false
                subjectCreationDraft = SubjectCreationDraft()
            } catch {
                app.present(error)
            }
            isCreatingSubject = false
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

    // MARK: - Portrait layout

    private func portraitTimerContent(size: CGSize) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppSpacing.md) {
                targetLauncher()
                timerDisplayCard(size: size)
                controlsCard(size: size)
                timerProblemProgressSection()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, AppSpacing.screenHorizontal)
            .padding(.top, AppSpacing.md)
            .padding(.bottom, 92)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                manualEntryButton()
                    .padding(.horizontal, AppSpacing.screenHorizontal)
                    .padding(.vertical, 10)
            }
            .background(.bar)
        }
    }

    private func targetLauncher() -> some View {
        Button {
            showTargetSelection = true
        } label: {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(subjectColor.opacity(0.14))
                    Circle()
                        .fill(subjectColor)
                        .frame(width: 14, height: 14)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text("学習対象")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(selectedSubjectText)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(selectedMaterialText == "なし" ? "教材なしで記録" : selectedMaterialText)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .cardStyle(padding: AppSpacing.md)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("学習対象を選択")
    }

    private func timerDisplayCard(size: CGSize) -> some View {
        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 7) {
                    Circle()
                        .fill(viewModel.isRunning ? AppColors.success : AppColors.textSecondary.opacity(0.4))
                        .frame(width: 9, height: 9)
                    Text(viewModel.isRunning ? "記録中" : "待機中")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(viewModel.isRunning ? AppColors.success : AppColors.textSecondary)
                }

                Spacer()

                Text(targetEndText)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            VStack(spacing: 2) {
                Text(durationString(milliseconds: viewModel.displayMilliseconds))
                    .font(.system(size: focusTimerTextSize(for: size), weight: .medium, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(maxWidth: .infinity)

                Text(viewModel.isRunning ? "集中していきましょう" : "学習対象を選んで開始")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .padding(.vertical, 2)

            VStack(spacing: 6) {
                AnimatedProgressBar(
                    value: timerProgress,
                    total: 1.0,
                    height: 6,
                    barColor: AppColors.success,
                    trackColor: AppColors.cardBorder.opacity(0.65)
                )

                HStack {
                    Text("0")
                    Spacer()
                    Text(progressMidLabel)
                    Spacer()
                    Text(progressEndLabel)
                }
                .font(.caption2.weight(.medium))
                .monospacedDigit()
                .foregroundStyle(AppColors.textSecondary)
            }
        }
        .cardStyle(padding: AppSpacing.lg)
    }

    private func controlsCard(size: CGSize) -> some View {
        VStack(spacing: AppSpacing.md) {
            HStack(spacing: AppSpacing.sm) {
                primaryTimerButton()
                stopTimerButton {
                    viewModel.stop()
                }
            }

            if shouldShowManualClockOnlyFocusButton(size: size) {
                clockOnlyFocusButton()
            }

            Picker("計測モード", selection: modeBinding) {
                Text("ストップウォッチ").tag(TimerSnapshot.Mode.stopwatch)
                Text("タイマー").tag(TimerSnapshot.Mode.timer)
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.isRunning)

            if viewModel.mode == .timer {
                HStack(spacing: AppSpacing.sm) {
                    ForEach([15, 25, 45, 60], id: \.self) { minutes in
                        durationChip(minutes)
                    }
                }
            }
        }
        .cardStyle(padding: AppSpacing.md)
    }

    private var modeBinding: Binding<TimerSnapshot.Mode> {
        Binding(
            get: { viewModel.mode },
            set: { viewModel.setMode($0) }
        )
    }

    private func durationChip(_ minutes: Int) -> some View {
        let selected = viewModel.countdownMinutes == minutes
        return Button {
            viewModel.setCountdownMinutes(minutes)
        } label: {
            Text("\(minutes)分")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : AppColors.success)
                .frame(maxWidth: .infinity)
                .frame(height: 34)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                        .fill(selected ? AppColors.success : AppColors.greenSoft)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRunning)
    }

    private var primaryTimerButtonLabel: String {
        viewModel.isRunning ? "一時停止" : (viewModel.displayMilliseconds > 0 ? "再開" : "開始")
    }

    private var clockOnlyFocusButtonTitle: String {
        if viewModel.isRunning {
            return "シンプル表示"
        }
        if viewModel.displayMilliseconds > 0 {
            return "再開してシンプル表示"
        }
        return "開始してシンプル表示"
    }

    private func primaryTimerButton() -> some View {
        Button {
            viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                Text(primaryTimerButtonLabel)
            }
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(AppColors.success, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func stopTimerButton(action: @escaping () -> Void) -> some View {
        let enabled = viewModel.displayMilliseconds > 0
        return Button(action: action) {
            Image(systemName: "stop.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? AppColors.danger : AppColors.textSecondary.opacity(0.5))
                .frame(width: 50, height: 50)
                .background(
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                        .fill(enabled ? AppColors.redSoft : Color(.tertiarySystemFill))
                )
                .overlay {
                    RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                        .stroke(enabled ? AppColors.danger.opacity(0.3) : Color.clear, lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel("停止")
    }

    private func clockOnlyFocusButton() -> some View {
        Button {
            presentClockOnlyFocus()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "timer")
                Text(clockOnlyFocusButtonTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption.weight(.bold))
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.success)
            .padding(.horizontal, AppSpacing.md)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(clockOnlyFocusButtonTitle)
    }

    private func manualEntryButton() -> some View {
        Button {
            showManualEntry = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                Text("手動入力")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.success)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.lg, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func timerProblemProgressSection() -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                Text("問題進捗（仮）")
                    .font(.headline)
                Spacer()
                problemLegend
            }

            if let material = selectedMaterial {
                TimerProblemProgressEditor(
                    records: Binding(
                        get: { viewModel.timerProblemRecords },
                        set: { viewModel.updateTimerProblemRecords($0, totalProblems: timerProblemProgressTotalProblems) }
                    ),
                    problemCount: Binding(
                        get: { viewModel.timerProblemCountDraft },
                        set: { newValue in
                            let totalProblems = selectedMaterialTotalProblems > 0 ? selectedMaterialTotalProblems : parseDraftInt(newValue)
                            viewModel.updateTimerProblemCountDraft(newValue, totalProblems: totalProblems)
                        }
                    ),
                    material: material,
                    materialProblemCount: material.effectiveTotalProblems,
                    materialProblemChapters: material.problemChapters
                )
            } else {
                Text("教材を選択すると問題進捗を入力できます")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, AppSpacing.sm)
            }
        }
        .cardStyle(padding: AppSpacing.md)
    }

    private var problemLegend: some View {
        HStack(spacing: 9) {
            problemLegendItem(color: AppColors.success, title: "正解")
            problemLegendItem(color: AppColors.danger, title: "不正解")
            problemLegendItem(color: Color(.systemGray3), title: "未解答")
        }
        .minimumScaleFactor(0.82)
    }

    private func problemLegendItem(color: Color, title: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    // MARK: - Selection helpers

    private var selectedSubjectText: String {
        if let subjectId = viewModel.effectiveSelectedSubjectId,
           let subject = viewModel.subjects.first(where: { $0.id == subjectId }) {
            return subject.name
        }
        return viewModel.subjects.isEmpty ? "科目を追加してください" : "科目を選択"
    }

    private var selectedSubject: Subject? {
        guard let subjectId = viewModel.effectiveSelectedSubjectId else { return nil }
        return viewModel.subjects.first(where: { $0.id == subjectId })
    }

    private var subjectColor: Color {
        selectedSubject.map { Color(hex: $0.color) } ?? AppColors.success
    }

    private var selectedMaterialText: String {
        if let materialId = viewModel.selectedMaterialId,
           let material = viewModel.materialsForSelectedSubject().first(where: { $0.id == materialId }) {
            return material.name
        }
        return "なし"
    }

    private var selectedMaterialTotalProblems: Int {
        guard let material = selectedMaterial else {
            return 0
        }
        return material.effectiveTotalProblems
    }

    private var selectedMaterialProblemChapters: [ProblemChapter] {
        guard let material = selectedMaterial else {
            return []
        }
        return material.problemChapters
    }

    private var selectedMaterial: Material? {
        guard let materialId = viewModel.selectedMaterialId else { return nil }
        return viewModel.materials.first(where: { $0.id == materialId })
    }

    private var timerProblemProgressTotalProblems: Int {
        selectedMaterialTotalProblems > 0 ? selectedMaterialTotalProblems : parseDraftInt(viewModel.timerProblemCountDraft)
    }

    private var targetEndText: String {
        if viewModel.mode == .timer, viewModel.displayMilliseconds > 0 {
            let target = Date().addingTimeInterval(TimeInterval(viewModel.displayMilliseconds) / 1000)
            return "目標終了 \(Self.hourMinuteFormatter.string(from: target))"
        }
        return viewModel.mode == .timer ? "カウントダウン" : "経過を記録中"
    }

    private var progressMidLabel: String {
        if viewModel.mode == .timer {
            return "\(max(viewModel.countdownMinutes / 2, 1)):00"
        }
        return "30:00"
    }

    private var progressEndLabel: String {
        if viewModel.mode == .timer {
            return "\(viewModel.countdownMinutes):00"
        }
        return "60:00"
    }

    private static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    // MARK: - Clock-only focus

    private var clockOnlyFocusCover: some View {
        ZStack(alignment: .topTrailing) {
            clockOnlyFocusView {
                viewModel.stop()
                isShowingClockOnlyFocus = false
            }

            Button {
                isShowingClockOnlyFocus = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.white.opacity(0.1), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
            .padding(.top, 18)
            .padding(.trailing, 18)
        }
        .statusBarHidden(true)
    }

    private func clockOnlyFocusView(onStop: @escaping () -> Void) -> some View {
        LandscapeClockOnlyTimerView(
            viewModel: viewModel,
            subjectText: selectedSubjectText,
            materialText: selectedMaterialText,
            timerText: durationString(milliseconds: viewModel.displayMilliseconds),
            modeText: "記録中",
            progress: timerProgress,
            onPauseToggle: {
                viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
            },
            onStop: onStop
        )
    }

    private func presentClockOnlyFocus() {
        guard viewModel.effectiveSelectedSubjectId != nil else {
            viewModel.startOrResume()
            return
        }
        if !viewModel.isRunning {
            viewModel.startOrResume()
        }
        isShowingClockOnlyFocus = true
    }

    // MARK: - Layout metrics

    private func shouldShowManualClockOnlyFocusButton(size: CGSize) -> Bool {
        !shouldShowLandscapeFocus(size: size) && min(size.width, size.height) >= 520
    }

    private func shouldShowLandscapeFocus(size: CGSize) -> Bool {
        viewModel.isRunning && size.width > size.height && size.height < 520
    }

    private func focusTimerTextSize(for size: CGSize) -> CGFloat {
        let widthDriven = size.width * 0.2
        return min(max(widthDriven, 56), 76)
    }
}

private enum TimerTargetSelectionTab: String, CaseIterable, Identifiable, Hashable {
    case recent = "最近"
    case subjects = "科目"
    case materials = "教材"

    var id: String { rawValue }
}

private struct TimerTargetSelectionSheet: View {
    let subjects: [Subject]
    let materialsForSubject: (Subject) -> [Material]
    let recentMaterialPairs: [(Material, Subject)]
    let selectedSubjectId: Int64?
    let selectedMaterialId: Int64?
    let onSelect: (Subject, Material?) -> Void
    let onDismiss: () -> Void

    @State private var selectedTab: TimerTargetSelectionTab = .recent
    @State private var activeSubjectId: Int64?

    init(
        subjects: [Subject],
        materialsForSubject: @escaping (Subject) -> [Material],
        recentMaterialPairs: [(Material, Subject)],
        selectedSubjectId: Int64?,
        selectedMaterialId: Int64?,
        onSelect: @escaping (Subject, Material?) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.subjects = subjects
        self.materialsForSubject = materialsForSubject
        self.recentMaterialPairs = recentMaterialPairs
        self.selectedSubjectId = selectedSubjectId
        self.selectedMaterialId = selectedMaterialId
        self.onSelect = onSelect
        self.onDismiss = onDismiss
        _activeSubjectId = State(initialValue: selectedSubjectId ?? subjects.first?.id)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                Picker("選択方法", selection: $selectedTab) {
                    ForEach(TimerTargetSelectionTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        switch selectedTab {
                        case .recent:
                            recentContent
                        case .subjects:
                            subjectsContent
                        case .materials:
                            materialsContent
                        }
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .background(AppColors.groupedBackground)
            .navigationTitle("学習対象を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる", action: onDismiss)
                        .foregroundStyle(AppColors.success)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var recentContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("最近使った教材")
                .timerTargetSectionTitle()

            if recentMaterialPairs.isEmpty {
                Text("最近使った教材はまだありません。科目または教材から選んでください。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                ForEach(Array(recentMaterialPairs.prefix(8)).indices, id: \.self) { index in
                    let pair = recentMaterialPairs[index]
                    TimerTargetRow(
                        subject: pair.1,
                        material: pair.0,
                        subtitle: "最近使用",
                        isSelected: selectedSubjectId == pair.1.id && selectedMaterialId == pair.0.id
                    ) {
                        onSelect(pair.1, pair.0)
                    }
                }
            }

            if let subject = activeSubject {
                TimerTargetRow(
                    subject: subject,
                    material: nil,
                    subtitle: "時間だけを記録",
                    isSelected: selectedSubjectId == subject.id && selectedMaterialId == nil
                ) {
                    onSelect(subject, nil)
                }
            }
        }
    }

    private var subjectsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("科目")
                .timerTargetSectionTitle()

            if subjects.isEmpty {
                Text("科目を追加するとタイマーを開始できます。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(.vertical, 12)
            } else {
                ForEach(subjects) { subject in
                    TimerTargetRow(
                        subject: subject,
                        material: nil,
                        subtitle: "教材なしで記録",
                        isSelected: selectedSubjectId == subject.id && selectedMaterialId == nil
                    ) {
                        onSelect(subject, nil)
                    }
                }
            }
        }
    }

    private var materialsContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("教材")
                .timerTargetSectionTitle()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(subjects) { subject in
                        Button {
                            activeSubjectId = subject.id
                        } label: {
                            Text(subject.name)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(activeSubjectId == subject.id ? Color.white : Color(hex: subject.color))
                                .padding(.horizontal, 14)
                                .frame(height: 36)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(activeSubjectId == subject.id ? Color(hex: subject.color) : Color(hex: subject.color).opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if let subject = activeSubject {
                TimerTargetRow(
                    subject: subject,
                    material: nil,
                    subtitle: "教材なしで記録",
                    isSelected: selectedSubjectId == subject.id && selectedMaterialId == nil
                ) {
                    onSelect(subject, nil)
                }

                let materials = materialsForSubject(subject)
                if materials.isEmpty {
                    Text("この科目には教材がありません。")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.vertical, 10)
                } else {
                    ForEach(materials) { material in
                        TimerTargetRow(
                            subject: subject,
                            material: material,
                            subtitle: material.effectiveTotalProblems > 0 ? "\(material.effectiveTotalProblems)問" : nil,
                            isSelected: selectedSubjectId == subject.id && selectedMaterialId == material.id
                        ) {
                            onSelect(subject, material)
                        }
                    }
                }
            }
        }
    }

    private var activeSubject: Subject? {
        if let activeSubjectId,
           let subject = subjects.first(where: { $0.id == activeSubjectId }) {
            return subject
        }
        return subjects.first
    }
}

private struct TimerTargetRow: View {
    let subject: Subject
    let material: Material?
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: subject.color))
                    .frame(width: 14, height: 14)

                VStack(alignment: .leading, spacing: 3) {
                    Text(material?.name ?? "教材なしで記録")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text([subject.name, subtitle].compactMap(\.self).joined(separator: " / "))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(AppColors.success)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 58)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? AppColors.success.opacity(0.55) : AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

private extension Text {
    func timerTargetSectionTitle() -> some View {
        font(.system(size: 13, weight: .bold))
            .foregroundStyle(AppColors.textSecondary)
            .textCase(.uppercase)
    }
}
