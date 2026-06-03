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
    @State private var ringScale: CGFloat = 1.0

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
                            onStop: {
                                viewModel.stop()
                            }
                        )
                    }
                } else {
                    ZStack {
                        TimerAmbientBackgroundView(theme: ambientTheme, isRunning: viewModel.isRunning)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 12) {
                                selectorSection(theme: ambientTheme)
                                quickSelectionSection(theme: ambientTheme)

                                VStack(spacing: 12) {
                                    timerModeSection(theme: ambientTheme)

                                    VStack(spacing: 14) {
                                        ZStack {
                                            ProgressRing(
                                                progress: timerProgress,
                                                size: timerRingSize(for: geometry.size),
                                                lineWidth: 13,
                                                ringColor: viewModel.isRunning ? ambientTheme.accent : Color.secondary.opacity(0.42),
                                                trackColor: ambientTheme.ringTrack,
                                                showPercentage: false
                                            )
                                            .scaleEffect(ringScale)

                                            VStack(spacing: 5) {
                                                Text(viewModel.isRunning ? "記録中" : "待機中")
                                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                                    .foregroundStyle(viewModel.isRunning ? ambientTheme.accent : AppColors.textSecondary)
                                                Text(durationString(milliseconds: viewModel.displayMilliseconds))
                                                    .font(.system(size: timerTextFontSize(for: geometry.size), weight: .regular, design: .rounded))
                                                    .monospacedDigit()
                                                    .foregroundStyle(AppColors.textPrimary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.72)
                                                    .frame(width: timerTextWidth(for: geometry.size), alignment: .center)
                                                Text(targetEndText)
                                                    .font(.system(size: 13, weight: .medium))
                                                    .foregroundStyle(AppColors.textSecondary)
                                                    .lineLimit(1)
                                                    .minimumScaleFactor(0.82)
                                            }
                                            .animation(.easeOut(duration: 0.25), value: viewModel.isRunning)
                                        }

                                        controlButtonsSection(theme: ambientTheme)
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
                                }
                                .timerGlassPanel(theme: ambientTheme, padding: 12)

                                timerProblemProgressSection(theme: ambientTheme)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 12)
                            .padding(.top, 12)
                            .padding(.bottom, 92)
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            VStack(spacing: 0) {
                                manualEntryButton(theme: ambientTheme)
                                    .padding(.horizontal, 12)
                                    .padding(.top, 10)
                                    .padding(.bottom, 10)
                                Divider()
                            }
                            .background(ambientTheme.bottomBarBackground)
                        }
                    }
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
        .onChange(of: viewModel.selectedSubjectId) { _ in
            viewModel.handleSubjectSelectionChange()
        }
        .onChange(of: viewModel.selectedMaterialId) { _ in
            viewModel.handleMaterialSelectionChange()
        }
        .keepScreenAwake(true)
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

    private func controlButtonsSection(theme: TimerAmbientTheme) -> some View {
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

    private static let hourMinuteFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

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
