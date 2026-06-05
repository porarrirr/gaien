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
            let ambientTheme = TimerAmbientTheme.make(colorScheme: colorScheme)
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
                    portraitTimerContent(theme: ambientTheme, size: geometry.size)
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

    private func portraitTimerContent(theme: TimerAmbientTheme, size: CGSize) -> some View {
        ZStack {
            TimerAmbientBackgroundView(theme: theme, isRunning: viewModel.isRunning)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    targetLauncher(theme: theme)

                    VStack(spacing: 16) {
                        focusStatusRow(theme: theme)
                        focusTimeField(size: size)
                        focusProgressRail(theme: theme)
                    }
                    .padding(.top, 18)

                    VStack(spacing: 12) {
                        controlButtonsSection(theme: theme, size: size)
                        focusModeControls(theme: theme)
                    }
                    .timerGlassPanel(theme: theme, padding: 12)

                    timerProblemProgressSection(theme: theme)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 14)
                .padding(.top, 16)
                .padding(.bottom, 92)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 0) {
                    manualEntryButton(theme: theme)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 10)
                    Divider()
                }
                .background(theme.bottomBarBackground)
            }
        }
    }

    private func targetLauncher(theme: TimerAmbientTheme) -> some View {
        Button {
            showTargetSelection = true
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(subjectColor.opacity(0.14))
                    Circle()
                        .fill(subjectColor)
                        .frame(width: 14, height: 14)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 3) {
                    Text("学習対象")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text(selectedSubjectText)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                    Text(selectedMaterialText == "なし" ? "教材なしで記録" : selectedMaterialText)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.down")
                    .font(.system(size: 15, weight: .heavy))
                    .foregroundStyle(theme.accent)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .frame(height: 72)
            .background(theme.panelOverlay, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.panelStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("学習対象を選択")
    }

    private func focusStatusRow(theme: TimerAmbientTheme) -> some View {
        HStack {
            HStack(spacing: 8) {
                Circle()
                    .fill(viewModel.isRunning ? theme.accent : AppColors.textSecondary.opacity(0.42))
                    .frame(width: 10, height: 10)
                Text(viewModel.isRunning ? "記録中" : "待機中")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(viewModel.isRunning ? theme.accent : AppColors.textSecondary)
            }

            Spacer()

            Text(targetEndText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
    }

    private func focusTimeField(size: CGSize) -> some View {
        VStack(spacing: 8) {
            Text(durationString(milliseconds: viewModel.displayMilliseconds))
                .font(.system(size: focusTimerTextSize(for: size), weight: .light, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.58)
                .frame(maxWidth: .infinity, alignment: .center)

            Text(viewModel.isRunning ? "集中していきましょう" : "学習対象を選んで開始")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 4)
    }

    private func focusProgressRail(theme: TimerAmbientTheme) -> some View {
        VStack(spacing: 8) {
            GeometryReader { proxy in
                let width = proxy.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(theme.ringTrack)
                        .frame(height: 7)
                    Capsule()
                        .fill(theme.accent)
                        .frame(width: max(8, width * timerProgress), height: 7)
                }
            }
            .frame(height: 7)

            HStack {
                Text("0")
                Spacer()
                Text(progressMidLabel)
                Spacer()
                Text(progressEndLabel)
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(AppColors.textSecondary)
        }
    }

    private func focusModeControls(theme: TimerAmbientTheme) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                timerModeButton(title: "ストップウォッチ", mode: .stopwatch, theme: theme)
                timerModeButton(title: "タイマー", mode: .timer, theme: theme)
            }

            if viewModel.mode == .timer {
                HStack(spacing: 8) {
                    ForEach([15, 25, 45, 60], id: \.self) { minutes in
                        Button {
                            viewModel.setCountdownMinutes(minutes)
                        } label: {
                            Text("\(minutes)分")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(viewModel.countdownMinutes == minutes ? Color.white : theme.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 34)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(viewModel.countdownMinutes == minutes ? theme.accent : theme.accent.opacity(0.12))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRunning)
                    }
                }
            }
        }
    }

    private func selectorSection(theme: TimerAmbientTheme) -> some View {
        VStack(spacing: 0) {
            selectionRow(icon: "circle.fill", title: "科目", tint: AppColors.blue) {
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
            Divider()

            selectionRow(icon: "book.closed", title: "教材", tint: theme.accent) {
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
        .timerGlassPanel(theme: theme, padding: 0)
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

    private func controlButtonsSection(theme: TimerAmbientTheme, size: CGSize) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                primaryTimerButton(theme: theme)

                stopTimerButton(
                    systemImage: "stop.fill",
                    title: "停止",
                    color: viewModel.displayMilliseconds > 0 ? AppColors.danger : Color.secondary.opacity(0.3),
                    action: {
                        viewModel.stop()
                    }
                )
                .disabled(viewModel.displayMilliseconds == 0)
            }

            if shouldShowManualClockOnlyFocusButton(size: size) {
                clockOnlyFocusButton(theme: theme)
            }
        }
    }

    private func primaryTimerButton(theme: TimerAmbientTheme) -> some View {
        Button {
            viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                    .font(.system(size: 20, weight: .bold))
                Text(primaryTimerButtonLabel)
                    .font(.system(size: 20, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(theme.accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: theme.accent.opacity(0.26), radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func clockOnlyFocusButton(theme: TimerAmbientTheme) -> some View {
        Button {
            presentClockOnlyFocus()
        } label: {
            HStack(spacing: 9) {
                Image(systemName: "timer")
                    .font(.system(size: 16, weight: .bold))
                Text(clockOnlyFocusButtonTitle)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 13, weight: .heavy))
            }
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.accent.opacity(0.28), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(clockOnlyFocusButtonTitle)
    }

    private func timerModeSection(theme: TimerAmbientTheme) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.sm) {
                timerModeButton(title: "ストップウォッチ", mode: .stopwatch, theme: theme)
                timerModeButton(title: "タイマー", mode: .timer, theme: theme)
            }
            if viewModel.mode == .timer {
                HStack(spacing: AppSpacing.sm) {
                    ForEach([15, 25, 45, 60], id: \.self) { minutes in
                        Button {
                            viewModel.setCountdownMinutes(minutes)
                        } label: {
                            Text("\(minutes)分")
                                .font(.subheadline.bold())
                                .foregroundStyle(viewModel.countdownMinutes == minutes ? Color.white : theme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(viewModel.countdownMinutes == minutes ? theme.accent : theme.accent.opacity(0.14))
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(viewModel.isRunning)
                    }
                }
            }
        }
        .padding(.bottom, 2)
    }

    private func timerModeButton(title: String, mode: TimerSnapshot.Mode, theme: TimerAmbientTheme) -> some View {
        Button {
            viewModel.setMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(viewModel.mode == mode ? Color.white : theme.secondaryForeground)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(viewModel.mode == mode ? theme.accent : Color.white.opacity(theme.colorScheme == .dark ? 0.08 : 0.64))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(viewModel.mode == mode ? Color.white.opacity(0.22) : theme.panelStroke, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isRunning)
    }

    private func manualEntryButton(theme: TimerAmbientTheme) -> some View {
        Button {
            showManualEntry = true
        } label: {
            HStack {
                Image(systemName: "pencil.line")
                Text("手動入力")
            }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Color(hex: 0x2563EB), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .shadow(color: Color.black.opacity(theme.colorScheme == .dark ? 0.28 : 0.12), radius: 12, x: 0, y: 6)
        }
    }

    @ViewBuilder
    private func quickSelectionSection(theme: TimerAmbientTheme) -> some View {
        if !viewModel.subjects.isEmpty || !viewModel.recentMaterialPairs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if !viewModel.subjects.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(viewModel.subjects.prefix(5)) { subject in
                                quickChip(
                                    title: subject.name,
                                    systemImage: "circle.fill",
                                    isSelected: viewModel.effectiveSelectedSubjectId == subject.id
                                ) {
                                    viewModel.selectedSubjectId = subject.id
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }

                if !viewModel.recentMaterialPairs.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        let pairs = Array(viewModel.recentMaterialPairs.prefix(4))
                        HStack(spacing: 8) {
                            ForEach(pairs.indices, id: \.self) { index in
                                let pair = pairs[index]
                                quickChip(
                                    title: pair.0.name,
                                    systemImage: "book.closed",
                                    isSelected: viewModel.selectedMaterialId == pair.0.id
                                ) {
                                    viewModel.selectedSubjectId = pair.1.id
                                    viewModel.selectedMaterialId = pair.0.id
                                }
                            }
                        }
                        .padding(.vertical, 1)
                    }
                }
            }
        }
    }

    private func quickChip(title: String, systemImage: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        let theme = TimerAmbientTheme.make(colorScheme: colorScheme)
        return Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.caption.weight(.bold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? Color.white : theme.accent)
            .padding(.horizontal, 11)
            .frame(height: 32)
            .background(isSelected ? theme.accent : theme.panelOverlay, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.accent.opacity(isSelected ? 0 : 0.30), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func timerProblemProgressSection(theme: TimerAmbientTheme) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("問題進捗（仮）")
                    .font(.system(size: 17, weight: .bold))
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
        .timerGlassPanel(theme: theme, padding: 12)
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
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
        }
    }

    private func selectionRow<Content: View>(icon: String, title: String, tint: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: title == "科目" ? 18 : 20, weight: .semibold))
                .frame(width: 36, height: 36)
                .background(tint.opacity(0.13), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(AppColors.textSecondary)
                Text(title == "科目" ? selectedSubjectText : selectedMaterialText)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            content()
        }
        .padding(.horizontal, 12)
        .frame(height: 62)
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
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(Color.white.opacity(0.12), in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
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

    private func shouldShowManualClockOnlyFocusButton(size: CGSize) -> Bool {
        !shouldShowLandscapeFocus(size: size) && min(size.width, size.height) >= 520
    }

    private func shouldShowLandscapeFocus(size: CGSize) -> Bool {
        viewModel.isRunning && size.width > size.height && size.height < 520
    }

    private func selectionMenuLabel(text: String, isPlaceholder: Bool) -> some View {
        HStack(spacing: 6) {
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .trailing)
        .contentShape(Rectangle())
    }

    private func timerRingSize(for size: CGSize) -> CGFloat {
        let widthLimited = min(size.width - 92, 262)
        let heightLimited = min(max(size.height * 0.24, 188), 238)
        return max(188, min(widthLimited, heightLimited))
    }

    private func timerTextWidth(for size: CGSize) -> CGFloat {
        max(timerRingSize(for: size) - 36, 132)
    }

    private func timerTextFontSize(for size: CGSize) -> CGFloat {
        let ringSize = timerRingSize(for: size)
        return min(max(ringSize * 0.22, 38), 46)
    }

    private func focusTimerTextSize(for size: CGSize) -> CGFloat {
        let compactHeight = size.height < 720
        let widthDriven = size.width * 0.24
        return min(max(widthDriven, compactHeight ? 64 : 72), compactHeight ? 88 : 104)
    }

    private func stopTimerButton(systemImage: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .bold))
                Text(title)
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(width: 66, height: 56)
            .background(color, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
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

private struct TimerGlassPanelModifier: ViewModifier {
    let theme: TimerAmbientTheme
    let padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.panelOverlay, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.panelStroke, lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(theme.colorScheme == .dark ? 0.18 : 0.08), radius: 14, x: 0, y: 8)
    }
}

private extension View {
    func timerGlassPanel(theme: TimerAmbientTheme, padding: CGFloat) -> some View {
        modifier(TimerGlassPanelModifier(theme: theme, padding: padding))
    }
}
