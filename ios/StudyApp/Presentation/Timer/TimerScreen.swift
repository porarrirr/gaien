import Foundation
import SwiftUI

// MARK: - TimerScreen

struct TimerScreen: View {
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
            let ambientTheme = TimerAmbientTheme.make(context: app.timerAmbientContext)
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
                        TimerAmbientBackgroundView(theme: ambientTheme)

                        ScrollView(showsIndicators: false) {
                            VStack(spacing: 10) {
                                ambientStatusHeader(theme: ambientTheme)
                                selectorSection
                                quickSelectionSection

                                VStack(spacing: 12) {
                                    timerModeSection

                                    VStack(spacing: 14) {
                                        ZStack {
                                            ProgressRing(
                                                progress: timerProgress,
                                                size: timerRingSize(for: geometry.size),
                                                lineWidth: 12,
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

                                        controlButtonsSection
                                            .padding(.horizontal, 8)
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
                                .strictCard(padding: 12)

                                timerProblemProgressSection
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 10)
                            .padding(.top, 10)
                            .padding(.bottom, 88)
                        }
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            VStack(spacing: 0) {
                                manualEntryButton
                                    .padding(.horizontal, 10)
                                    .padding(.top, 10)
                                    .padding(.bottom, 10)
                                Divider()
                            }
                            .background(ambientTheme.bottomBarBackground)
                        }
                    }
                    .environment(\.colorScheme, ambientTheme.colorScheme)
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
        .task(id: app.preferences.timerVisualMode) {
            app.refreshTimerAmbient(reason: "timer-screen")
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

    private var selectorSection: some View {
        VStack(spacing: 0) {
            selectionRow(icon: "circle.fill", title: "科目") {
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

            selectionRow(icon: "book", title: "教材") {
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
        .strictCard(padding: 0)
    }

    private var primaryTimerButtonLabel: String {
        viewModel.isRunning ? "一時停止" : (viewModel.displayMilliseconds > 0 ? "再開" : "開始")
    }

    private var controlButtonsSection: some View {
        HStack(spacing: 14) {
            primaryTimerButton

            Spacer(minLength: 0)

            timerControlButton(
                systemImage: "stop.fill",
                color: viewModel.displayMilliseconds > 0 ? AppColors.danger : Color.secondary.opacity(0.3),
                action: {
                    viewModel.stop()
                }
            )
            .disabled(viewModel.displayMilliseconds == 0)
        }
    }

    private var primaryTimerButton: some View {
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
            .frame(height: 58)
            .background(TimerAmbientTheme.make(context: app.timerAmbientContext).accent, in: Capsule())
            .shadow(color: TimerAmbientTheme.make(context: app.timerAmbientContext).accent.opacity(0.32), radius: 10, x: 0, y: 5)
        }
        .buttonStyle(.plain)
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
                                .foregroundStyle(viewModel.countdownMinutes == minutes ? Color.white : TimerAmbientTheme.make(context: app.timerAmbientContext).accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(viewModel.countdownMinutes == minutes ? TimerAmbientTheme.make(context: app.timerAmbientContext).accent : TimerAmbientTheme.make(context: app.timerAmbientContext).accentSoft)
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

    private func timerModeButton(title: String, mode: TimerSnapshot.Mode) -> some View {
        Button {
            viewModel.setMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(viewModel.mode == mode ? TimerAmbientTheme.make(context: app.timerAmbientContext).accent : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.mode == mode ? AppColors.cardBackground : Color(.secondarySystemFill).opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(viewModel.mode == mode ? TimerAmbientTheme.make(context: app.timerAmbientContext).accent : Color.clear, lineWidth: 1.5)
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
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(TimerAmbientTheme.make(context: app.timerAmbientContext).accent, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func ambientStatusHeader(theme: TimerAmbientTheme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: app.timerAmbientContext.weatherCondition.systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.accent)
                .frame(width: 34, height: 34)
                .background(theme.accent.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text("\(app.timerAmbientContext.phase.title)の集中モード")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text(ambientStatusText)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 8)
            Text(app.preferences.timerVisualMode.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 10)
                .frame(height: 28)
                .background(theme.accent.opacity(0.12), in: Capsule())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.panelStroke, lineWidth: 1)
        }
    }

    @ViewBuilder
    private var quickSelectionSection: some View {
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
                                    systemImage: "book",
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
        let theme = TimerAmbientTheme.make(context: app.timerAmbientContext)
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
            .frame(height: 34)
            .background(isSelected ? theme.accent : theme.accent.opacity(0.12), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(theme.accent.opacity(isSelected ? 0 : 0.30), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var timerProblemProgressSection: some View {
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
                    .padding(.vertical, AppSpacing.xs)
            }
        }
        .strictCard(padding: 12)
    }

    private var problemLegend: some View {
        HStack(spacing: 9) {
            problemLegendItem(color: AppColors.success, title: "正解")
            problemLegendItem(color: AppColors.danger, title: "不正解")
            problemLegendItem(color: AppColors.warning, title: "復習正解")
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

    private func selectionRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .foregroundStyle(title == "科目" ? AppColors.blue : AppColors.success)
                .font(.system(size: title == "科目" ? 28 : 26, weight: .regular))
                .frame(width: 36)
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(AppColors.textPrimary)
            content()
        }
        .padding(.horizontal, 14)
        .frame(height: 66)
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

    private var ambientStatusText: String {
        let context = app.timerAmbientContext
        let weather = context.weatherCondition.title
        if let error = context.errorMessage, context.source == .clock {
            return "\(context.source.title)で判定 ・ \(error)"
        }
        return "\(context.source.title)で判定 ・ \(weather)"
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
        HStack(spacing: AppSpacing.xs) {
            Spacer(minLength: 8)
            Text(text)
                .foregroundStyle(isPlaceholder ? AppColors.textSecondary : AppColors.textPrimary)
                .lineLimit(1)
                .font(.system(size: 18, weight: .regular))
            Image(systemName: "chevron.right")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
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

    private func timerControlButton(systemImage: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(color))
                .overlay {
                    Circle()
                        .stroke(Color(.systemGray4), lineWidth: 1)
                        .frame(width: 78, height: 78)
                }
        }
        .buttonStyle(.plain)
    }
}

