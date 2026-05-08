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
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 10) {
                            selectorSection

                            VStack(spacing: 12) {
                                timerModeSection

                                VStack(spacing: 14) {
                                    ZStack {
                                        ProgressRing(
                                            progress: timerProgress,
                                            size: timerRingSize(for: geometry.size),
                                            lineWidth: 12,
                                            ringColor: viewModel.isRunning ? AppColors.success : Color.secondary.opacity(0.4),
                                            trackColor: Color(.systemGray5),
                                            showPercentage: false
                                        )
                                        .scaleEffect(ringScale)

                                        VStack(spacing: 5) {
                                            Text(durationString(milliseconds: viewModel.displayMilliseconds))
                                                .font(.system(size: timerTextFontSize(for: geometry.size), weight: .regular, design: .rounded))
                                                .monospacedDigit()
                                                .foregroundStyle(AppColors.textPrimary)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.72)
                                                .frame(width: timerTextWidth(for: geometry.size), alignment: .center)
                                            Text(viewModel.isRunning ? "記録中" : "待機中")
                                                .font(.system(size: 20, weight: .bold))
                                                .foregroundStyle(viewModel.isRunning ? AppColors.success : AppColors.textSecondary)
                                            Text(viewModel.mode == .timer ? "カウントダウン" : "記録中")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(AppColors.textSecondary)
                                        }
                                        .animation(.easeOut(duration: 0.25), value: viewModel.isRunning)
                                    }

                                    controlButtonsSection
                                        .padding(.horizontal, 46)
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
        HStack {
            timerControlButton(
                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                color: AppColors.success,
                action: {
                    viewModel.isRunning ? viewModel.pause() : viewModel.startOrResume()
                }
            )

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
        .padding(.bottom, 2)
    }

    private func timerModeButton(title: String, mode: TimerSnapshot.Mode) -> some View {
        Button {
            viewModel.setMode(mode)
        } label: {
            Text(title)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(viewModel.mode == mode ? AppColors.success : AppColors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(viewModel.mode == mode ? AppColors.cardBackground : Color(.secondarySystemFill).opacity(0.72))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(viewModel.mode == mode ? AppColors.success : Color.clear, lineWidth: 1.5)
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
            .background(AppColors.blue, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
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
        GeometryReader { geometry in
            let leftWidth = min(max(geometry.size.width * 0.38, 330), 430)

            HStack(alignment: .top, spacing: 28) {
                timerPane(size: geometry.size)
                    .frame(width: leftWidth)
                    .frame(maxHeight: .infinity)

                problemInputPane(size: geometry.size)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(landscapeBackground)
        .preferredColorScheme(.dark)
    }

    private func problemInputPane(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Text("問題進捗（仮）")
                    .font(.system(size: 19, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Spacer(minLength: 10)
                progressLegend
            }
            .padding(.bottom, 2)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.16))
                    .frame(height: 1)
                    .offset(y: 9)
            }

            if effectiveTotalProblems > 0 {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 26) {
                        ForEach(landscapeSections.indices, id: \.self) { index in
                            let section = landscapeSections[index]
                            chapterProgressSection(section, availableWidth: rightPaneWidth(for: size))
                        }
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 6)
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
    }

    private func timerPane(size: CGSize) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            subjectCard
                .padding(.bottom, max(18, size.height * 0.08))

            Text(timerText)
                .font(.system(size: timerFontSize(for: size), weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(timerTextGradient)
                .shadow(color: .white.opacity(0.22), radius: 2, x: 0, y: 1)
                .minimumScaleFactor(0.58)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(modeText)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: 0x36E255))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 2)
                .padding(.bottom, 18)

            progressLine
                .frame(maxWidth: .infinity)

            Text(progressText)
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.86))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 14)

            Spacer(minLength: 16)

            HStack(alignment: .center, spacing: 38) {
                focusIconButton(
                    systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                    label: "一時停止",
                    tint: Color(hex: 0x43D648),
                    foreground: .white,
                    size: controlButtonSize(for: size),
                    action: onPauseToggle
                )

                Rectangle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 1, height: min(88, size.height * 0.24))

                focusIconButton(
                    systemImage: "stop.fill",
                    label: "停止",
                    tint: Color(hex: 0x2C2C2E),
                    foreground: .white,
                    size: controlButtonSize(for: size),
                    action: onStop
                )
            }
            .frame(maxWidth: .infinity)

            Spacer(minLength: 0)
        }
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.16))
                Capsule()
                    .fill(progressGradient)
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 10))
            }
        }
        .frame(height: 13)
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
        Color.black
        .ignoresSafeArea()
    }

    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Circle()
                    .fill(Color(hex: 0x40DB4E))
                    .frame(width: 22, height: 22)
                Text(selectedSubjectName)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(hex: 0x45EA57))
                    .lineLimit(1)
            }
            Text(material?.name ?? "教材なし")
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.86))
                .lineLimit(1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0x111113).opacity(0.74))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var selectedSubjectName: String {
        if let subjectId = viewModel.effectiveSelectedSubjectId,
           let subject = viewModel.subjects.first(where: { $0.id == subjectId }) {
            return subject.name
        }
        return "科目未選択"
    }

    private var progressText: String {
        guard materialProblemCount > 0 else {
            return "\(viewModel.timerProblemRecords.count) ページ"
        }
        let completed = Int((Double(materialProblemCount) * min(max(progress, 0), 1)).rounded())
        return "\(completed) / \(materialProblemCount) ページ"
    }

    private var progressLegend: some View {
        HStack(spacing: 18) {
            legendItem(color: resultColor(.correct), title: "正解")
            legendItem(color: resultColor(.wrong), title: "不正解")
            legendItem(color: resultColor(.reviewCorrect), title: "復習正解")
            legendItem(color: unansweredColor, title: "未解答")
        }
    }

    private func legendItem(color: Color, title: String) -> some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(color)
                .frame(width: 18, height: 18)
                .overlay(
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                )
            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
        }
    }

    private func chapterProgressSection(_ section: LandscapeProblemSection, availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(section.title)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(
                    Capsule(style: .continuous)
                        .fill(chapterLabelGradient)
                )

            LazyVGrid(columns: gridColumns(for: availableWidth), spacing: 8) {
                ForEach(1...section.count, id: \.self) { localNumber in
                    let globalNumber = section.startNumber + localNumber - 1
                    problemProgressTile(globalNumber: globalNumber, label: "\(localNumber)", chapterTitle: section.title)
                }
            }
        }
    }

    private func problemProgressTile(globalNumber: Int, label: String, chapterTitle: String) -> some View {
        let record = viewModel.timerProblemRecords.first { $0.number == globalNumber }

        return LandscapeProblemProgressTile(
            label: label,
            accessibilityLabel: "\(chapterTitle) \(label)問目 \(record?.result.title ?? "未解答")",
            fill: tileFill(for: record),
            border: tileBorder(for: record),
            shadow: tileShadow(for: record),
            borderWidth: record == nil ? 1.5 : 2,
            onCorrectTap: { toggleCorrect(globalNumber) },
            onWrongTap: { setResult(.wrong, for: globalNumber) },
            onLongPress: { cycleDetailedResult(for: globalNumber) }
        )
    }

    private var landscapeSections: [LandscapeProblemSection] {
        if materialProblemChapters.totalProblemCount > 0 {
            var start = 1
            return materialProblemChapters.filter { $0.problemCount > 0 }.map { chapter in
                defer { start += chapter.problemCount }
                return LandscapeProblemSection(
                    title: chapter.title,
                    startNumber: start,
                    count: chapter.problemCount
                )
            }
        }

        guard effectiveTotalProblems > 0 else { return [] }
        return stride(from: 1, through: effectiveTotalProblems, by: 50).map { start in
            let end = min(start + 49, effectiveTotalProblems)
            return LandscapeProblemSection(
                title: "\(start)〜\(end)",
                startNumber: start,
                count: end - start + 1
            )
        }
    }

    private func toggleCorrect(_ number: Int) {
        var records = viewModel.timerProblemRecords
        if let index = records.firstIndex(where: { $0.number == number }) {
            if records[index].result == .correct {
                records.remove(at: index)
            } else {
                records[index].result = .correct
            }
        } else {
            records.append(ProblemSessionRecord(number: number, result: .correct))
        }
        saveLandscapeRecords(records)
    }

    private func setResult(_ result: ProblemResult, for number: Int) {
        var records = viewModel.timerProblemRecords
        if let index = records.firstIndex(where: { $0.number == number }) {
            records[index].result = result
        } else {
            records.append(ProblemSessionRecord(number: number, result: result))
        }
        saveLandscapeRecords(records)
    }

    private func cycleDetailedResult(for number: Int) {
        let current = viewModel.timerProblemRecords.first { $0.number == number }?.result
        switch current {
        case .reviewCorrect:
            removeResult(for: number)
        default:
            setResult(.reviewCorrect, for: number)
        }
    }

    private func removeResult(for number: Int) {
        var records = viewModel.timerProblemRecords
        records.removeAll { $0.number == number }
        saveLandscapeRecords(records)
    }

    private func saveLandscapeRecords(_ records: [ProblemSessionRecord]) {
        viewModel.updateTimerProblemRecords(
            records.sorted { $0.number < $1.number },
            totalProblems: effectiveTotalProblems
        )
    }

    private func gridColumns(for availableWidth: CGFloat) -> [GridItem] {
        let minimumTileWidth: CGFloat = 54
        let spacing: CGFloat = 8
        let columnCount = max(4, min(7, Int((availableWidth + spacing) / (minimumTileWidth + spacing))))
        return Array(repeating: GridItem(.flexible(minimum: minimumTileWidth), spacing: spacing), count: columnCount)
    }

    private func rightPaneWidth(for size: CGSize) -> CGFloat {
        let leftWidth = min(max(size.width * 0.38, 330), 430)
        return max(280, size.width - leftWidth - 88)
    }

    private func timerFontSize(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.105, 72), 120)
    }

    private func controlButtonSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.22, 86), 112)
    }

    private func focusIconButton(
        systemImage: String,
        label: String,
        tint: Color,
        foreground: Color,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint)
                    Circle()
                        .stroke(.white.opacity(0.22), lineWidth: 2)
                    Image(systemName: systemImage)
                        .font(.system(size: size * 0.36, weight: .black))
                        .foregroundStyle(foreground)
                }
                .frame(width: size, height: size)
                .shadow(color: tint.opacity(0.44), radius: 7, x: 0, y: 0)

                Text(label)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
        .buttonStyle(.plain)
    }

    private var timerTextGradient: LinearGradient {
        LinearGradient(
            colors: [.white, Color(hex: 0xE9E9EA), .white],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var progressGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x58D957), Color(hex: 0x45C949)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private var chapterLabelGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0x148918), Color(hex: 0x0A4C12)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func tileFill(for record: ProblemSessionRecord?) -> LinearGradient {
        let baseColor = record.map { resultColor($0.result) } ?? unansweredColor
        return LinearGradient(
            colors: [
                baseColor.opacity(record == nil ? 0.70 : 0.92),
                baseColor.opacity(record == nil ? 0.42 : 0.70)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func tileBorder(for record: ProblemSessionRecord?) -> Color {
        guard let record else { return .white.opacity(0.22) }
        return resultColor(record.result).opacity(0.95)
    }

    private func tileShadow(for record: ProblemSessionRecord?) -> Color {
        guard let record else { return .clear }
        return resultColor(record.result).opacity(0.30)
    }

    private func resultColor(_ result: ProblemResult) -> Color {
        switch result {
        case .correct: return Color(hex: 0x22B52B)
        case .wrong: return Color(hex: 0xEF493D)
        case .reviewCorrect: return Color(hex: 0x2D83E6)
        }
    }

    private var unansweredColor: Color {
        Color(hex: 0x3A3A3C)
    }
}

private struct LandscapeProblemSection {
    let title: String
    let startNumber: Int
    let count: Int
}

private struct LandscapeProblemProgressTile: View {
    let label: String
    let accessibilityLabel: String
    let fill: LinearGradient
    let border: Color
    let shadow: Color
    let borderWidth: CGFloat
    let onCorrectTap: () -> Void
    let onWrongTap: () -> Void
    let onLongPress: () -> Void

    @State private var lastTapAt: Date?

    var body: some View {
        Text(label)
            .font(.system(size: 18, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.68)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .stroke(border, lineWidth: borderWidth)
            )
            .shadow(color: shadow, radius: 4, x: 0, y: 0)
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .onTapGesture(perform: handleTap)
            .onLongPressGesture(minimumDuration: 0.45, perform: onLongPress)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityHint("タップで正解、すばやく2回タップで不正解、長押しで復習正解")
    }

    private func handleTap() {
        let now = Date()
        if let lastTapAt, now.timeIntervalSince(lastTapAt) < 0.28 {
            self.lastTapAt = nil
            onWrongTap()
            return
        }
        lastTapAt = now
        onCorrectTap()
    }
}

private struct LandscapeClockOnlyTimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    let subjectText: String
    let materialText: String
    let timerText: String
    let modeText: String
    let progress: Double
    let onPauseToggle: () -> Void
    let onStop: () -> Void

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                clockOnlyBackground

                LandscapeClockArc(side: .left)
                    .stroke(
                        Color(hex: 0x47C96A),
                        style: StrokeStyle(lineWidth: arcLineWidth(for: geometry.size), lineCap: .round)
                    )
                    .shadow(color: Color(hex: 0x47C96A).opacity(0.18), radius: 10, y: 4)
                    .frame(
                        width: geometry.size.width * 0.42,
                        height: geometry.size.height * 0.88
                    )
                    .offset(x: -geometry.size.width * 0.28, y: geometry.size.height * 0.02)

                LandscapeClockArc(side: .right)
                    .stroke(
                        Color(hex: 0x47C96A),
                        style: StrokeStyle(lineWidth: arcLineWidth(for: geometry.size), lineCap: .round)
                    )
                    .shadow(color: Color(hex: 0x47C96A).opacity(0.18), radius: 10, y: 4)
                    .frame(
                        width: geometry.size.width * 0.42,
                        height: geometry.size.height * 0.88
                    )
                    .offset(x: geometry.size.width * 0.28, y: geometry.size.height * 0.02)

                VStack(spacing: 0) {
                    materialPill
                        .padding(.top, max(10, geometry.size.height * 0.028))

                    Spacer(minLength: 0)

                    VStack(spacing: max(14, geometry.size.height * 0.032)) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: 0x47C96A))
                                .frame(width: 12, height: 12)
                            Text(modeText)
                                .font(.system(size: statusFontSize(for: geometry.size), weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: 0x47C96A))
                        }

                        Text(timerText)
                            .font(.system(size: clockFontSize(for: geometry.size), weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.16), radius: 14, y: 4)
                            .minimumScaleFactor(0.62)
                            .lineLimit(1)

                        progressLine
                            .frame(width: progressWidth(for: geometry.size), height: 5)

                        HStack(spacing: max(54, geometry.size.width * 0.11)) {
                            clockOnlyButton(
                                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                                title: viewModel.isRunning ? "一時停止" : "再開",
                                tint: Color(hex: 0x47C96A),
                                action: onPauseToggle
                            )
                            clockOnlyButton(
                                systemImage: "stop.fill",
                                title: "停止",
                                tint: Color(hex: 0xFF3B30),
                                action: onStop
                            )
                        }
                    }
                    .padding(.bottom, max(26, geometry.size.height * 0.052))

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var materialPill: some View {
        HStack(spacing: 18) {
            Circle()
                .fill(Color(hex: 0x47C96A))
                .frame(width: 19, height: 19)
                .shadow(color: Color(hex: 0x47C96A).opacity(0.26), radius: 8, y: 2)

            Text(subjectText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("/")
                .foregroundStyle(.white.opacity(0.84))

            Text(materialText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.system(size: 20, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.94))
        .padding(.horizontal, 26)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .shadow(color: .black.opacity(0.42), radius: 18, y: 12)
        )
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
        .frame(maxWidth: 420)
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                Capsule()
                    .fill(Color(hex: 0x47C96A))
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 10))
            }
        }
    }

    private var clockOnlyBackground: some View {
        ZStack {
            Color(hex: 0x07090C)
            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color(hex: 0x101419).opacity(0.68),
                    Color.black.opacity(0.92)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 620
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func clockOnlyButton(systemImage: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(
                        Circle()
                            .fill(tint)
                            .shadow(color: tint.opacity(0.26), radius: 18, y: 8)
                    )
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            .frame(width: 116)
        }
        .buttonStyle(.plain)
    }

    private func clockFontSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.34, 112), 178)
    }

    private func statusFontSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.082, 24), 36)
    }

    private func progressWidth(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.52, 520), 700)
    }

    private func arcLineWidth(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.024, 10), 18)
    }
}

private enum LandscapeClockArcSide {
    case left
    case right
}

private struct LandscapeClockArc: Shape {
    let side: LandscapeClockArcSide

    func path(in rect: CGRect) -> Path {
        let angles: StrideThrough<Double>
        if side == .left {
            angles = stride(from: 220.0, through: 140.0, by: -1.0)
        } else {
            angles = stride(from: -40.0, through: 40.0, by: 1.0)
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width * 0.48
        let radiusY = rect.height * 0.47
        var path = Path()

        for (index, degrees) in angles.enumerated() {
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radiusX,
                y: center.y + CGFloat(sin(radians)) * radiusY
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

private struct TimerProblemProgressEditor: View {
    @Binding var records: [ProblemSessionRecord]
    @Binding var problemCount: String
    let material: Material
    let materialProblemCount: Int
    let materialProblemChapters: [ProblemChapter]
    @State private var selectedSectionId = 0

    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 8), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if effectiveProblemCount > 0 {
                sectionSelector

                if let section = selectedProblemSection {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(alignment: .firstTextBaseline) {
                            Text(section.title)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                            Spacer(minLength: 8)
                            Text(section.rangeText)
                                .font(.system(size: 15, weight: .regular))
                                .foregroundStyle(AppColors.textSecondary)
                                .monospacedDigit()
                        }

                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(section.start...section.end, id: \.self) { number in
                                timerProblemTile(number)
                            }
                        }
                    }
                }

                Text("※ 章の問題数に基づいて表示しています。")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                problemCountControls
            }
        }
        .onChange(of: problemCount) { _ in
            let count = effectiveProblemCount
            guard count > 0 else { return }
            records.removeAll { $0.number > count }
            clampSelectedSection()
        }
        .onAppear {
            clampSelectedSection()
        }
    }

    private var effectiveProblemCount: Int {
        materialProblemCount > 0 ? materialProblemCount : parseDraftInt(problemCount)
    }

    private var problemSections: [TimerProblemSection] {
        if !materialProblemChapters.isEmpty {
            var next = 1
            return materialProblemChapters
                .filter { $0.problemCount > 0 }
                .enumerated()
                .map { index, chapter in
                    let start = next
                    let end = next + chapter.problemCount - 1
                    next = end + 1
                    return TimerProblemSection(
                        id: index,
                        title: chapter.title,
                        start: start,
                        end: end,
                        total: effectiveProblemCount
                    )
                }
        }

        guard effectiveProblemCount > 0 else { return [] }
        return stride(from: 1, through: effectiveProblemCount, by: 25).enumerated().map { index, start in
            let end = min(start + 24, effectiveProblemCount)
            return TimerProblemSection(
                id: index,
                title: "第\(index + 1)章",
                start: start,
                end: end,
                total: effectiveProblemCount
            )
        }
    }

    private var selectedProblemSection: TimerProblemSection? {
        let sections = problemSections
        return sections.first { $0.id == selectedSectionId } ?? sections.first
    }

    @ViewBuilder
    private var sectionSelector: some View {
        let sections = problemSections
        if sections.count > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(sections) { section in
                        Button {
                            selectedSectionId = section.id
                        } label: {
                            VStack(spacing: 2) {
                                Text(section.title)
                                    .lineLimit(1)
                                Text("\(section.start)〜\(section.end)")
                                    .font(.system(size: 10, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .font(.caption.bold())
                            .foregroundStyle(selectedSectionId == section.id ? Color.white : AppColors.success)
                            .padding(.horizontal, 12)
                            .frame(height: 44)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(selectedSectionId == section.id ? AppColors.success : AppColors.success.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func timerProblemTile(_ number: Int) -> some View {
        Button {
            cycleRecord(number)
        } label: {
            Text("\(number)")
                .font(.system(size: 15, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(tileForeground(for: number))
                .lineLimit(1)
                .minimumScaleFactor(0.68)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(tileBackground(for: number), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(tileBorder(for: number), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(number)問目 \(records.first(where: { $0.number == number })?.result.title ?? "未解答")")
    }

    private func cycleRecord(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            switch records[index].result {
            case .correct:
                records[index].result = .wrong
            case .wrong:
                records[index].result = .reviewCorrect
            case .reviewCorrect:
                records.remove(at: index)
            }
        } else {
            records.append(ProblemSessionRecord(number: number, result: .correct))
        }
        records.sort { $0.number < $1.number }
    }

    private func tileBackground(for number: Int) -> Color {
        guard let result = records.first(where: { $0.number == number })?.result else {
            return AppColors.cardBackground
        }
        switch result {
        case .correct: return AppColors.success.opacity(0.11)
        case .wrong: return AppColors.danger.opacity(0.10)
        case .reviewCorrect: return AppColors.warning.opacity(0.12)
        }
    }

    private func tileForeground(for number: Int) -> Color {
        guard let result = records.first(where: { $0.number == number })?.result else {
            return AppColors.textPrimary
        }
        switch result {
        case .correct: return AppColors.success
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.warning
        }
    }

    private func tileBorder(for number: Int) -> Color {
        guard let result = records.first(where: { $0.number == number })?.result else {
            return Color(.systemGray5)
        }
        switch result {
        case .correct: return AppColors.success.opacity(0.62)
        case .wrong: return AppColors.danger.opacity(0.62)
        case .reviewCorrect: return AppColors.warning.opacity(0.68)
        }
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

    private func clampSelectedSection() {
        let sections = problemSections
        guard !sections.isEmpty else {
            selectedSectionId = 0
            return
        }
        if !sections.contains(where: { $0.id == selectedSectionId }) {
            selectedSectionId = sections[0].id
        }
    }
}

private struct TimerProblemSection: Identifiable {
    let id: Int
    let title: String
    let start: Int
    let end: Int
    let total: Int

    var rangeText: String {
        "\(start) - \(end) / \(total)問"
    }
}

private struct ManualEntrySheet: View {
    let viewModel: TimerViewModel
    @Binding var manualNote: String
    @Binding var isPresented: Bool
    @State private var manualEntryMode: ManualEntryTimeMode = .duration
    @State private var manualHours = "00"
    @State private var manualMinutes = "25"
    @State private var manualStartTime = Calendar.current.date(bySettingHour: Calendar.current.component(.hour, from: Date()), minute: 0, second: 0, of: Date()) ?? Date()
    @State private var manualEndTime = Date()
    @State private var manualRating: Int?
    @State private var correctCount = "0"
    @State private var wrongCount = "0"
    @State private var reviewCorrectCount = "0"
    @State private var unansweredCount = "0"

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 10) {
                selectionCard
                timeCard
                noteCard
                ratingCard
                problemCard
                Text("※ 問題の詳細な記録は、保存後に編集できます。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
                    .padding(.bottom, 8)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)
        }
        .background(AppColors.subtleBackground)
        .navigationTitle("手動入力")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル") { isPresented = false }
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColors.success)
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppColors.success)
                    .disabled(!canSave)
            }
        }
        .onChange(of: manualNote) { _ in
            if manualNote.count > 300 {
                manualNote = String(manualNote.prefix(300))
            }
        }
    }

    private var selectionCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("科目")
                    .manualSectionTitle()
                Menu {
                    ForEach(viewModel.subjects) { subject in
                        Button(subject.name) {
                            viewModel.selectedSubjectId = subject.id
                            viewModel.handleSubjectSelectionChange()
                        }
                    }
                } label: {
                    ManualSelectionRow(
                        title: selectedSubject?.name ?? "未設定",
                        subtitle: nil,
                        leading: {
                            Circle()
                                .fill(subjectColor)
                                .frame(width: 16, height: 16)
                        }
                    )
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("教材（任意）")
                        .manualSectionTitle()
                    Spacer()
                    if selectedMaterial != nil {
                        Button {
                            viewModel.selectedMaterialId = nil
                            viewModel.handleMaterialSelectionChange()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color(.systemGray3))
                        }
                        .buttonStyle(.plain)
                    }
                }
                Menu {
                    Button("教材なし") {
                        viewModel.selectedMaterialId = nil
                        viewModel.handleMaterialSelectionChange()
                    }
                    ForEach(viewModel.materialsForSelectedSubject()) { material in
                        Button(material.name) {
                            viewModel.selectedMaterialId = material.id
                            viewModel.handleMaterialSelectionChange()
                        }
                    }
                } label: {
                    ManualSelectionRow(
                        title: selectedMaterial?.name ?? "教材なし",
                        subtitle: selectedMaterialSubtitle,
                        leading: {
                            ManualBookThumbnail()
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .manualCard()
    }

    private var timeCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("学習時間")
                .manualSectionTitle()
            ManualSegmentedControl(
                selection: $manualEntryMode,
                items: [
                    (.duration, "時間を入力"),
                    (.range, "開始・終了時刻を入力")
                ]
            )

            if manualEntryMode == .duration {
                HStack(spacing: 12) {
                    Text("学習時間")
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 74, alignment: .leading)
                    manualNumberField(text: $manualHours, width: 64)
                    Text("時間")
                        .font(.subheadline.weight(.semibold))
                    manualNumberField(text: $manualMinutes, width: 64)
                    Text("分")
                        .font(.subheadline.weight(.semibold))
                }
                Text("5分〜12時間")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                DatePicker("開始時刻", selection: $manualStartTime, displayedComponents: .hourAndMinute)
                DatePicker("終了時刻", selection: $manualEndTime, displayedComponents: .hourAndMinute)
            }
        }
        .manualCard()
    }

    private var noteCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("メモ（任意）")
                .manualSectionTitle()
            ZStack(alignment: .topLeading) {
                TextEditor(text: $manualNote)
                    .frame(minHeight: 82)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                if manualNote.isEmpty {
                    Text("メモを入力（任意）")
                        .foregroundStyle(AppColors.textSecondary)
                        .padding(.horizontal, 17)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color(.systemBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            }
            Text("\(manualNote.count)/300")
                .font(.footnote)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, -6)
        }
        .manualCard()
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("評価（任意）")
                .manualSectionTitle()
            HStack(spacing: 22) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        manualRating = value
                    } label: {
                        Image(systemName: value <= (manualRating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(value <= (manualRating ?? 0) ? AppColors.warning : Color(.systemGray3))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            Text("タップして評価（1〜5）")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .manualCard()
    }

    private var problemCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("問題集の記録（任意）")
                .manualSectionTitle()
            problemSummary
            ManualSegmentedControl(
                selection: .constant(ManualProblemEntryMode.summary),
                items: [
                    (.summary, "まとめて入力"),
                    (.perProblem, "問題ごとに入力")
                ]
            )
            HStack(alignment: .top, spacing: 12) {
                problemCountField(title: "正解", text: $correctCount, color: AppColors.success)
                problemCountField(title: "不正解", text: $wrongCount, color: AppColors.danger)
                problemCountField(title: "復習正解", text: $reviewCorrectCount, color: AppColors.warning)
                problemCountField(title: "未解答", text: $unansweredCount, color: Color(.systemGray3))
            }
        }
        .manualCard()
    }

    private var problemSummary: some View {
        HStack(spacing: 0) {
            summaryColumn(title: "正解", value: correctTotal, color: AppColors.success)
            summaryColumn(title: "不正解", value: wrongTotal, color: AppColors.danger)
            summaryColumn(title: "復習正解", value: reviewCorrectTotal, color: AppColors.warning)
            summaryColumn(title: "未解答", value: unansweredTotal, color: AppColors.textSecondary)
            summaryColumn(title: "合計", value: totalProblemCount, color: AppColors.textPrimary)
        }
        .padding(.vertical, 10)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }

    private func summaryColumn(title: String, value: Int, color: Color) -> some View {
        VStack(spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(value)")
                .font(.title3.weight(.medium))
                .foregroundStyle(color)
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity)
    }

    private func problemCountField(title: String, text: Binding<String>, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            HStack(spacing: 5) {
                manualNumberField(text: text, width: 54)
                    .onChange(of: text.wrappedValue) { _ in
                        limitNumeric(text)
                    }
                Text("問")
                    .font(.caption.weight(.semibold))
            }
            HStack(spacing: 6) {
                Circle()
                    .fill(color)
                    .frame(width: 11, height: 11)
                Text(title)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func manualNumberField(text: Binding<String>, width: CGFloat) -> some View {
        TextField("0", text: text)
            .keyboardType(.numberPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 26, weight: .regular, design: .rounded))
            .monospacedDigit()
            .frame(width: width, height: 48)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
            .onChange(of: text.wrappedValue) { _ in
                limitNumeric(text)
            }
    }

    private var selectedSubject: Subject? {
        viewModel.subjects.first(where: { $0.id == viewModel.selectedSubjectId })
    }

    private var selectedMaterial: Material? {
        viewModel.materials.first(where: { $0.id == viewModel.selectedMaterialId })
    }

    private var subjectColor: Color {
        Color(hex: selectedSubject?.color ?? 0x1F5FD1)
    }

    private var selectedMaterialSubtitle: String? {
        guard let material = selectedMaterial else { return nil }
        let pageText = material.currentPage > 0 ? "p.\(material.currentPage)" : nil
        let problemText = material.effectiveTotalProblems > 0 ? "例題 \(material.effectiveTotalProblems)" : nil
        return [pageText, problemText].compactMap { $0 }.joined(separator: " ")
    }

    private var durationMinutes: Int {
        (Int(manualHours) ?? 0) * 60 + (Int(manualMinutes) ?? 0)
    }

    private var canSave: Bool {
        guard viewModel.selectedSubjectId != nil else { return false }
        if manualEntryMode == .duration {
            return durationMinutes >= 5 && durationMinutes <= 12 * 60
        }
        return manualEndTime > manualStartTime
    }

    private var correctTotal: Int { Int(correctCount) ?? 0 }
    private var wrongTotal: Int { Int(wrongCount) ?? 0 }
    private var reviewCorrectTotal: Int { Int(reviewCorrectCount) ?? 0 }
    private var unansweredTotal: Int { Int(unansweredCount) ?? 0 }
    private var totalProblemCount: Int {
        correctTotal + wrongTotal + reviewCorrectTotal + unansweredTotal
    }

    private var aggregateProblemRecords: [ProblemSessionRecord] {
        var nextNumber = 1
        var records: [ProblemSessionRecord] = []
        for _ in 0..<correctTotal {
            records.append(ProblemSessionRecord(number: nextNumber, result: .correct))
            nextNumber += 1
        }
        for _ in 0..<wrongTotal {
            records.append(ProblemSessionRecord(number: nextNumber, result: .wrong))
            nextNumber += 1
        }
        for _ in 0..<reviewCorrectTotal {
            records.append(ProblemSessionRecord(number: nextNumber, result: .reviewCorrect))
            nextNumber += 1
        }
        return records
    }

    private func save() {
        guard let subjectId = viewModel.selectedSubjectId else { return }
        let endDate: Date
        let startDate: Date
        if manualEntryMode == .duration {
            endDate = Date()
            startDate = endDate.addingTimeInterval(TimeInterval(-durationMinutes * 60))
        } else {
            startDate = manualStartTime
            endDate = manualEndTime
        }
        viewModel.saveManualSession(
            subjectId: subjectId,
            materialId: viewModel.selectedMaterialId,
            startTime: startDate.epochMilliseconds,
            endTime: endDate.epochMilliseconds,
            note: manualNote,
            rating: manualRating,
            problemRecords: aggregateProblemRecords,
            problemStart: totalProblemCount > 0 ? 1 : nil,
            problemEnd: totalProblemCount > 0 ? totalProblemCount : nil,
            wrongProblemCount: totalProblemCount > 0 ? wrongTotal : nil
        )
        manualNote = ""
        isPresented = false
    }

    private func limitNumeric(_ text: Binding<String>) {
        let filtered = text.wrappedValue.filter(\.isNumber)
        if filtered != text.wrappedValue {
            text.wrappedValue = filtered
        }
    }
}

private enum ManualEntryTimeMode: Hashable {
    case duration
    case range
}

private enum ManualProblemEntryMode: Hashable {
    case summary
    case perProblem
}

private struct ManualSegmentedControl<Selection: Hashable>: View {
    @Binding var selection: Selection
    let items: [(Selection, String)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Button {
                    selection = item.0
                } label: {
                    Text(item.1)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(selection == item.0 ? AppColors.success : AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                        .frame(height: 38)
                        .background {
                            if selection == item.0 {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(AppColors.success, lineWidth: 1.5)
                            }
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(1)
        .background(Color(.secondarySystemFill), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct ManualSelectionRow<Leading: View>: View {
    let title: String
    let subtitle: String?
    private let leading: () -> Leading

    init(title: String, subtitle: String?, @ViewBuilder leading: @escaping () -> Leading) {
        self.title = title
        self.subtitle = subtitle
        self.leading = leading
    }

    var body: some View {
        HStack(spacing: 12) {
            leading()
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.title3.weight(.regular))
                .foregroundStyle(Color(.systemGray2))
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 56)
        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

private struct ManualBookThumbnail: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color(hex: 0x0F3D91), Color(hex: 0x1A5CC8)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 34, height: 48)
            .overlay(alignment: .top) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(.white.opacity(0.88))
                    .frame(width: 22, height: 6)
                    .padding(.top, 8)
            }
    }
}

private extension View {
    func manualCard() -> some View {
        self
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
    }

    func manualSectionTitle() -> some View {
        self
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppColors.textPrimary)
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
            VStack(alignment: .leading, spacing: 12) {
                sessionInfoCard
                ratingCard
                problemRecordCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 22)
        }
        .background(Color(hex: 0xF7F8FA))
        .navigationTitle("セッション評価")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("キャンセル", action: onCancel)
                    .font(.headline.weight(.semibold))
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: onSave)
                    .font(.headline.weight(.semibold))
                    .disabled(rating == nil)
            }
        }
        .onChange(of: problemCount) { _ in
            let count = effectiveProblemCount
            guard count > 0 else { return }
            problemRecords.removeAll { $0.number > count }
        }
        .onChange(of: note) { newValue in
            if newValue.count > 300 {
                note = String(newValue.prefix(300))
            }
        }
    }

    private var sessionInfoCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 0) {
                SessionInfoColumn(
                    icon: "circle.fill",
                    iconColor: AppColors.blue,
                    title: "科目",
                    value: session.subjectName.isEmpty ? "未設定" : session.subjectName
                )
                verticalDivider
                SessionInfoColumn(
                    icon: "book",
                    iconColor: AppColors.orange,
                    title: "教材",
                    value: session.materialName.isEmpty ? "未設定" : session.materialName
                )
                verticalDivider
                SessionInfoColumn(
                    icon: "clock",
                    iconColor: AppColors.success,
                    title: "学習時間",
                    value: session.durationJapaneseText
                )
            }

            Divider()

            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(width: 24)
                Text("学習区間")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text(sessionPeriodText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Spacer(minLength: 0)
            }
        }
        .evaluationPanel()
    }

    private var ratingCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("評価")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 22) {
                ForEach(1...5, id: \.self) { value in
                    Button {
                        rating = value
                    } label: {
                        Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                            .font(.system(size: 34, weight: .regular))
                            .foregroundStyle(value <= (rating ?? 0) ? AppColors.warning : Color(hex: 0x8F9299))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("評価 \(value)")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)

            Text("1〜5 の星で評価してください")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .frame(maxWidth: .infinity)
        }
        .evaluationPanel()
    }

    private var problemRecordCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("問題集の記録")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 26) {
                ProblemLegendItem(symbol: "○", title: "正解", color: AppColors.success)
                ProblemLegendItem(symbol: "×", title: "不正解", color: AppColors.danger)
                ProblemLegendItem(symbol: "△", title: "復習正解", color: AppColors.orange)
                ProblemLegendItem(symbol: "−", title: "未解答", color: Color(hex: 0x9A9DA3))
            }
            .frame(maxWidth: .infinity)

            problemGrid

            Divider()
                .padding(.horizontal, -16)

            NumericEvaluationRow(title: "問題数（合計）", text: $problemCount, valueIfLocked: materialProblemCount > 0 ? "\(materialProblemCount)" : nil)
            NumericEvaluationRow(title: "開始問題", text: $problemStart)
            NumericEvaluationRow(title: "終了問題", text: $problemEnd)
            NumericEvaluationRow(title: "不正解数", text: $wrongProblemCount)

            VStack(alignment: .leading, spacing: 10) {
                Text("メモ")
                    .font(.headline.weight(.semibold))
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $note)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(Color.white)
                    if note.isEmpty {
                        Text("メモを入力してください（任意）")
                            .font(.subheadline)
                            .foregroundStyle(Color(hex: 0x9A9DA3))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                    Text("\(note.count)/300")
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 14)
                        .padding(.bottom, 12)
                        .allowsHitTesting(false)
                }
                .frame(height: 132)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color(hex: 0xCDD0D6), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
        }
        .evaluationPanel()
    }

    private var effectiveProblemCount: Int {
        materialProblemCount > 0 ? materialProblemCount : parseDraftInt(problemCount)
    }

    private var problemGrid: some View {
        VStack(spacing: 0) {
            ForEach(problemSections) { section in
                ProblemChapterRecordRow(
                    section: section,
                    records: $problemRecords
                )
                if section.id != problemSections.last?.id {
                    Divider()
                }
            }
        }
        .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        )
    }

    private var problemSections: [EvaluationProblemSection] {
        let chapters = materialProblemChapters.filter { $0.problemCount > 0 }
        if !chapters.isEmpty {
            var start = 1
            return chapters.map { chapter in
                defer { start += chapter.problemCount }
                return EvaluationProblemSection(title: chapter.title, problemCount: chapter.problemCount, startNumber: start)
            }
        }

        let total = max(effectiveProblemCount, 0)
        guard total > 0 else { return [] }
        return [EvaluationProblemSection(title: "問題", problemCount: total, startNumber: 1)]
    }

    private var verticalDivider: some View {
        Rectangle()
            .fill(AppColors.cardBorder)
            .frame(width: 1, height: 58)
            .padding(.horizontal, 10)
    }

    private var sessionPeriodText: String {
        "\(Self.periodDateFormatter.string(from: session.startDate)) \(Self.timeFormatter.string(from: session.startDate)) 〜 \(Self.timeFormatter.string(from: session.endDate))"
    }

    private static let periodDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd (E)"
        return formatter
    }()

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

private struct SessionInfoColumn: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(iconColor)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }
            Text(value)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ProblemLegendItem: View {
    let symbol: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 7) {
            Text(symbol)
                .font(.system(size: 23, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 20)
            Text(title)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.72)
    }
}

private struct NumericEvaluationRow: View {
    let title: String
    @Binding var text: String
    var valueIfLocked: String?

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Group {
                if let valueIfLocked {
                    Text(valueIfLocked)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .frame(width: 118, height: 44)
                        .background(Color.white)
                } else {
                    TextField("", text: $text)
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .frame(width: 118, height: 44)
                        .background(Color.white)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
            Text("問")
                .font(.headline.weight(.medium))
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.vertical, 4)
    }
}

private struct EvaluationProblemSection: Identifiable, Hashable {
    let title: String
    let problemCount: Int
    let startNumber: Int

    var id: Int {
        startNumber
    }

    var endNumber: Int {
        startNumber + problemCount - 1
    }
}

private struct ProblemChapterRecordRow: View {
    let section: EvaluationProblemSection
    @Binding var records: [ProblemSessionRecord]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 48), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(section.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Spacer()
                Text("p.\(section.startNumber)-\(section.endNumber)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(section.startNumber...section.endNumber, id: \.self) { number in
                    EvaluationProblemTile(
                        number: number,
                        record: records.first(where: { $0.number == number }),
                        onTap: { advanceRecord(number) }
                    )
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
    }

    private func advanceRecord(_ number: Int) {
        if let index = records.firstIndex(where: { $0.number == number }) {
            switch records[index].result {
            case .correct:
                records[index].result = .wrong
            case .wrong:
                records[index].result = .reviewCorrect
            case .reviewCorrect:
                records.remove(at: index)
            }
        } else {
            records.append(ProblemSessionRecord(number: number, result: .correct))
            records.sort { $0.number < $1.number }
        }
    }
}

private struct EvaluationProblemTile: View {
    let number: Int
    let record: ProblemSessionRecord?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text("\(number)")
                    .font(.system(size: 13, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
                Text(symbol)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(height: 22)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(number)問 \(accessibilityStatus)")
    }

    private var symbol: String {
        guard let record else { return "−" }
        switch record.result {
        case .correct: return "○"
        case .wrong: return "×"
        case .reviewCorrect: return "△"
        }
    }

    private var tint: Color {
        guard let record else { return Color(hex: 0x9A9DA3) }
        switch record.result {
        case .correct: return AppColors.success
        case .wrong: return AppColors.danger
        case .reviewCorrect: return AppColors.orange
        }
    }

    private var background: Color {
        guard let record else { return Color(hex: 0xF8F9FB) }
        switch record.result {
        case .correct: return AppColors.greenSoft
        case .wrong: return AppColors.redSoft
        case .reviewCorrect: return AppColors.orangeSoft
        }
    }

    private var border: Color {
        guard let record else { return AppColors.cardBorder }
        switch record.result {
        case .correct: return AppColors.success.opacity(0.35)
        case .wrong: return AppColors.danger.opacity(0.35)
        case .reviewCorrect: return AppColors.orange.opacity(0.35)
        }
    }

    private var accessibilityStatus: String {
        record?.result.title ?? "未解答"
    }
}

private extension View {
    func evaluationPanel() -> some View {
        padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            )
    }
}
