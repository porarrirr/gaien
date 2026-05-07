import Foundation
import SwiftUI
import UIKit

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
    @State private var previousIdleTimerDisabled = false

    init(app: StudyAppContainer) {
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
                        LandscapeClockOnlyTimerView(
                            viewModel: viewModel,
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
                    }
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: AppSpacing.xl) {
                            selectorSection

                            timerModeSection

                            ZStack {
                                ProgressRing(
                                    progress: timerProgress,
                                    size: timerRingSize(for: geometry.size),
                                    lineWidth: 16,
                                    ringColor: viewModel.isRunning ? AppColors.success : Color.secondary.opacity(0.4),
                                    trackColor: AppColors.greenSoft,
                                    showPercentage: false
                                )
                                .scaleEffect(ringScale)

                                VStack(spacing: AppSpacing.xs) {
                                    Text(durationString(milliseconds: viewModel.displayMilliseconds))
                                        .font(.system(size: 52, weight: .regular, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundStyle(AppColors.textPrimary)
                                    if viewModel.isRunning {
                                        Text(viewModel.mode == .timer ? "カウントダウン中" : "記録中")
                                            .font(.caption.bold())
                                            .foregroundStyle(AppColors.success)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 4)
                                            .background(AppColors.greenSoft, in: Capsule())
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

                            timerProblemProgressSection
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, AppSpacing.screenHorizontal)
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
        .onAppear {
            previousIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = previousIdleTimerDisabled
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
                    viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
                } label: {
                    Image(systemName: viewModel.isRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            Circle().fill(AppColors.success)
                        )
                }

                Text(primaryTimerButtonLabel)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            VStack(spacing: AppSpacing.xs) {
                Button {
                    viewModel.stop()
                } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 58, height: 58)
                        .background(
                            Circle().fill(viewModel.displayMilliseconds > 0 ? AppColors.danger : Color.secondary.opacity(0.3))
                        )
                }
                .disabled(viewModel.displayMilliseconds == 0)

                Text("終了")
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
                                .foregroundStyle(viewModel.countdownMinutes == minutes ? Color.white : AppColors.success)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(viewModel.countdownMinutes == minutes ? AppColors.success : AppColors.greenSoft)
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
                .foregroundStyle(viewModel.mode == mode ? Color.white : AppColors.success)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.mode == mode ? AppColors.success : AppColors.greenSoft)
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
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(AppColors.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private var timerProblemProgressSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "checklist.checked")
                    .foregroundStyle(AppColors.success)
                Text("問題進捗（仮）")
                    .font(.headline)
                Spacer()
                if !viewModel.timerProblemRecords.isEmpty {
                    Text("\(viewModel.timerProblemRecords.count)問")
                        .font(.caption.bold())
                        .foregroundStyle(AppColors.success)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppColors.greenSoft, in: Capsule())
                }
            }

            if let material = selectedMaterial {
                ProblemProgressEditor(
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
        .cardStyle()
    }

    private func selectionRow<Content: View>(icon: String, title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(title == "科目" ? AppColors.blue : AppColors.success)
                .frame(width: 22)
            content()
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, 12)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
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

    private func shouldShowLandscapeFocus(size: CGSize) -> Bool {
        viewModel.isRunning && size.width > size.height && size.height < 520
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

private struct LandscapeTimerFocusView: View {
    @ObservedObject var viewModel: TimerViewModel
    let material: Material?
    let materialProblemCount: Int
    let materialProblemChapters: [ProblemChapter]
    let totalProblems: Int
    let timerText: String
    let modeText: String
    let progress: Double
    let onPauseToggle: () -> Void
    let onStop: () -> Void

    private var effectiveTotalProblems: Int {
        materialProblemCount > 0 ? materialProblemCount : totalProblems
    }

    private var completionText: String {
        let done = viewModel.timerProblemRecords.count
        let wrong = viewModel.timerProblemRecords.filter(\.isWrong).count
        let review = viewModel.timerProblemRecords.filter { $0.result == .reviewCorrect }.count
        if review > 0 {
            return "\(done)問 / 不正解 \(wrong) / 復習 \(review)"
        }
        return "\(done)問 / 不正解 \(wrong)"
    }

    var body: some View {
        HStack(spacing: 24) {
            problemInputPane
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            timerPane
                .frame(width: 230)
                .frame(maxHeight: .infinity)
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(landscapeBackground)
        .preferredColorScheme(.dark)
    }

    private var problemInputPane: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(material?.name ?? "問題集")
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    Text(materialProgressSubtitle)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(1)
                }
                Spacer()
                Text(completionText)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.76))
            }

            if effectiveTotalProblems > 0 {
                ScrollView(showsIndicators: false) {
                    ProblemTileSelector(
                        totalProblems: effectiveTotalProblems,
                        chapters: materialProblemChapters,
                        records: Binding(
                            get: { viewModel.timerProblemRecords },
                            set: { viewModel.updateTimerProblemRecords($0, totalProblems: effectiveTotalProblems) }
                        )
                    )
                    .tint(Color(hex: 0x4CAF50))
                    .padding(.top, 2)
                }
                .scrollDismissesKeyboard(.interactively)
            } else {
                VStack(alignment: .leading, spacing: 14) {
                    Spacer(minLength: 0)
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 46, height: 2)
                    Text("教材に問題数を設定すると、ここで番号タップ記録を使えます")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.42))
                        .lineLimit(2)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: 360, maxHeight: .infinity, alignment: .leading)
            }
        }
        .padding(.trailing, 4)
    }

    private var timerPane: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text(timerText)
                    .font(.system(size: 46, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .minimumScaleFactor(0.66)
                    .lineLimit(1)
                Text(modeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(hex: 0x8AB4F8).opacity(0.78))
            }

            progressLine
                .frame(width: 168)

            HStack(spacing: 12) {
                focusIconButton(
                    systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                    tint: Color(hex: 0x2196F3),
                    action: onPauseToggle
                )
                focusIconButton(
                    systemImage: "stop.fill",
                    tint: AppColors.danger,
                    action: onStop
                )
            }

            Spacer(minLength: 0)
        }
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(width: 1)
                .offset(x: -22)
        }
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                Capsule()
                    .fill(Color(hex: 0x4CAF50))
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 8))
            }
        }
        .frame(height: 3)
    }

    private var materialProgressSubtitle: String {
        if materialProblemCount > 0 {
            if materialProblemChapters.isEmpty {
                return "全\(materialProblemCount)問"
            }
            return "全\(materialProblemCount)問 ・ \(materialProblemChapters.count)章"
        }
        return "タップで正解、すばやく2回タップで不正解、長押しで詳細"
    }

    private var landscapeBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x05070A),
                Color(hex: 0x090D12),
                Color(hex: 0x07100B)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func focusIconButton(systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 44, height: 38)
                .background(.white.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
    }
}

private struct LandscapeClockOnlyTimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    let timerText: String
    let modeText: String
    let progress: Double
    let onPauseToggle: () -> Void
    let onStop: () -> Void

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 18) {
                Spacer(minLength: 0)

                VStack(spacing: 12) {
                    Text(timerText)
                        .font(.system(size: clockFontSize(for: geometry.size), weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(modeText)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(hex: 0x8AB4F8).opacity(0.78))
                }

                progressLine
                    .frame(width: min(geometry.size.width * 0.34, 360))

                HStack(spacing: 14) {
                    clockOnlyButton(
                        systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                        tint: Color(hex: 0x2196F3),
                        action: onPauseToggle
                    )
                    clockOnlyButton(
                        systemImage: "stop.fill",
                        tint: AppColors.danger,
                        action: onStop
                    )
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 18)
        .background(clockOnlyBackground)
        .preferredColorScheme(.dark)
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                Capsule()
                    .fill(Color(hex: 0x4CAF50))
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 10))
            }
        }
        .frame(height: 3)
    }

    private var clockOnlyBackground: some View {
        LinearGradient(
            colors: [
                Color(hex: 0x05070A),
                Color(hex: 0x0E1319),
                Color(hex: 0x07100C)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private func clockOnlyButton(systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 46, height: 40)
                .background(.white.opacity(0.06), in: Circle())
        }
        .buttonStyle(.plain)
    }

    private func clockFontSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.24, 54), 92)
    }
}

private struct ManualEntrySheet: View {
    let viewModel: TimerViewModel
    @Binding var manualNote: String
    @Binding var isPresented: Bool
    @State private var manualStartTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date()) ?? Date()
    @State private var manualEndTime = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "学習対象", icon: "book.fill")
                    HStack {
                        Text("科目")
                        Spacer()
                        Text(viewModel.subjects.first(where: { $0.id == viewModel.selectedSubjectId })?.name ?? "-")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("教材")
                        Spacer()
                        Text(viewModel.materials.first(where: { $0.id == viewModel.selectedMaterialId })?.name ?? "なし")
                            .foregroundStyle(.secondary)
                    }
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "記録", icon: "clock")
                    DatePicker("開始時刻", selection: $manualStartTime, displayedComponents: .hourAndMinute)
                    DatePicker("終了時刻", selection: $manualEndTime, displayedComponents: .hourAndMinute)
                    TextEditor(text: $manualNote)
                        .frame(minHeight: 130)
                        .scrollContentBackground(.hidden)
                        .padding(AppSpacing.sm)
                        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous))
                }
                .cardStyle()
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("手動入力")
        .navigationBarTitleDisplayMode(.inline)
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

private struct ProblemProgressEditor: View {
    @Binding var records: [ProblemSessionRecord]
    @Binding var problemCount: String
    let materialProblemCount: Int
    let materialProblemChapters: [ProblemChapter]

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            if materialProblemCount > 0 {
                Text(materialProblemChapters.isEmpty ? "全\(materialProblemCount)問" : "全\(materialProblemCount)問 ・ \(materialProblemChapters.count)章")
                    .font(.caption.bold())
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                problemCountControls
            }

            if effectiveProblemCount > 0 {
                ProblemTileSelector(
                    totalProblems: effectiveProblemCount,
                    chapters: materialProblemChapters,
                    records: $records
                )
                Text(problemRecordSummary)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .onChange(of: problemCount) { _ in
            let count = effectiveProblemCount
            guard count > 0 else { return }
            records.removeAll { $0.number > count }
        }
    }

    private var problemRecordSummary: String {
        let done = records.count
        let correct = records.filter { $0.result == .correct }.count
        let wrong = records.filter(\.isWrong).count
        let review = records.filter { $0.result == .reviewCorrect }.count
        return "タップで正解、すばやく2回タップで不正解、長押しで復習正解とメモを編集。選択 \(done)問 / 正解 \(correct)問 / 不正解 \(wrong)問 / 復習正解 \(review)問"
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
                        .frame(width: 44, height: 44)
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
                        .frame(width: 44, height: 44)
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
    let materialProblemChapters: [ProblemChapter]
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 46, height: 46)
                        .overlay {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.tint)
                        }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(session.subjectName.isEmpty ? "未設定" : session.subjectName)
                            .font(.headline)
                        if !session.materialName.isEmpty {
                            Text(session.materialName)
                                .font(.subheadline)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        Text("\(session.durationJapaneseText) ・ \(session.sessionType.title)")
                            .font(.caption.bold())
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "評価", icon: "star.fill")
                    SessionRatingSelector(rating: $rating)
                }
                .cardStyle()

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    SectionHeaderView(title: "問題集の記録", icon: "checklist.checked")
                    if materialProblemCount > 0 {
                        Text(materialProblemChapters.isEmpty ? "全\(materialProblemCount)問" : "全\(materialProblemCount)問 ・ \(materialProblemChapters.count)章")
                            .font(.caption.bold())
                            .foregroundStyle(AppColors.textSecondary)
                    } else {
                        problemCountControls
                    }
                    if effectiveProblemCount > 0 {
                        ProblemTileSelector(
                            totalProblems: effectiveProblemCount,
                            chapters: materialProblemChapters,
                            records: $problemRecords
                        )
                        Text(problemRecordSummary)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    TextField("セッションメモ", text: $note, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.default)
                }
                .cardStyle()
            }
            .padding(AppSpacing.md)
        }
        .background(AppColors.subtleBackground)
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
        return "タップで正解、すばやく2回タップで不正解、長押しで復習正解とメモを編集。選択 \(done)問 / 正解 \(correct)問 / 不正解 \(wrong)問 / 復習正解 \(review)問"
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
