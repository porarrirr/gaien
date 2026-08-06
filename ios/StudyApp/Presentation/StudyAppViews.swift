import FamilyControls
import Foundation
import SwiftUI

// MARK: - Root

struct RootView: View {
    private enum RestoredPickerTarget {
        case allowedDuringRestriction
        case dailyBudget
    }

    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var app: StudyAppContainer
    @ObservedObject private var focusController: ScreenTimeFocusController
    @State private var restoredAllowedSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var restoredBudgetSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var restoredPickerSelection = FamilyActivitySelection(includeEntireCategory: true)
    @State private var restoredPickerTarget: RestoredPickerTarget = .allowedDuringRestriction
    @State private var isShowingRestoredSelectionPicker = false
    @State private var hasPresentedRestoredSelectionPrompt = false

    init(app: StudyAppContainer) {
        self.app = app
        _focusController = ObservedObject(wrappedValue: app.screenTimeFocusController)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.clearError() } }
        )
    }

    private var restoredSelectionPromptBinding: Binding<Bool> {
        Binding(
            get: {
                focusController.requiresRestoredActivitySelection
                    && !hasPresentedRestoredSelectionPrompt
                    && app.errorMessage == nil
            },
            set: { isPresented in
                if !isPresented {
                    hasPresentedRestoredSelectionPrompt = true
                }
            }
        )
    }

    var body: some View {
        Group {
            if let message = app.dataStorePreparationError {
                DataStorePreparationErrorView(
                    message: message,
                    isRetrying: app.isPreparingDataStore,
                    logger: app.logger,
                    retry: app.retryDataStorePreparation
                )
            } else if !app.isLoaded {
                LoadingSplash(logger: app.logger)
            } else {
                MainTabView(app: app)
            }
        }
        .preferredColorScheme(app.preferences.selectedThemeMode.colorScheme)
        .accentColor(app.preferences.selectedColorTheme.primaryColor)
        .tint(app.preferences.selectedColorTheme.primaryColor)
        .alert("エラー", isPresented: errorBinding) {
            Button("OK", role: .cancel) {
                app.clearError()
            }
        } message: {
            Text(app.errorMessage ?? "")
        }
        .alert("対象アプリを選択してください", isPresented: restoredSelectionPromptBinding) {
            Button("選択する") {
                beginRestoredSelection()
            }
            Button("あとで", role: .cancel) {
                hasPresentedRestoredSelectionPrompt = true
            }
        } message: {
            Text("ログインしたアカウントのScreen Time設定を復元しました。Appleの仕様によりアプリの選択は端末間で引き継げないため、この端末で選び直してください。")
        }
        .familyActivityPicker(
            headerText: restoredPickerHeaderText,
            footerText: restoredPickerFooterText,
            isPresented: $isShowingRestoredSelectionPicker,
            selection: $restoredPickerSelection
        )
        .onChange(of: restoredPickerSelection) { selection in
            switch restoredPickerTarget {
            case .allowedDuringRestriction:
                restoredAllowedSelection = selection
            case .dailyBudget:
                restoredBudgetSelection = selection
            }
        }
        .onChange(of: isShowingRestoredSelectionPicker) { isPresented in
            guard !isPresented else { return }
            continueRestoredSelection(afterDismissing: restoredPickerTarget)
        }
        .onChange(of: focusController.requiresRestoredActivitySelection) { required in
            if !required {
                hasPresentedRestoredSelectionPrompt = false
            }
        }
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            app.handleSceneDidBecomeActive()
        }
    }

    private func beginRestoredSelection() {
        hasPresentedRestoredSelectionPrompt = true
        Task {
            do {
                if !focusController.isAuthorized {
                    try await focusController.requestAuthorization()
                }
                restoredAllowedSelection = focusController.settings.activitySelection
                restoredBudgetSelection = focusController.settings.budgetSelection
                showNextRestoredPickerIfNeeded()
            } catch {
                app.present(error)
            }
        }
    }

    private var restoredPickerHeaderText: String {
        switch restoredPickerTarget {
        case .allowedDuringRestriction:
            return "集中制限中も使えるアプリとWebサイトを選択してください"
        case .dailyBudget:
            return "時間を決めて使うアプリとWebサイトを選択してください"
        }
    }

    private var restoredPickerFooterText: String {
        switch restoredPickerTarget {
        case .allowedDuringRestriction:
            return "壁のルール中も開けるものを選びます。この選択は端末固有です。"
        case .dailyBudget:
            return "使用時間を持ち時間から引く対象を選びます。この選択は端末固有です。"
        }
    }

    private func showRestoredPicker(_ target: RestoredPickerTarget) {
        restoredPickerTarget = target
        switch target {
        case .allowedDuringRestriction:
            restoredPickerSelection = restoredAllowedSelection
        case .dailyBudget:
            restoredPickerSelection = restoredBudgetSelection
        }
        isShowingRestoredSelectionPicker = true
    }

    private func showNextRestoredPickerIfNeeded() {
        let settings = focusController.settings
        if settings.requiresAllowedSelection, !hasAllowedRestoredSelection {
            showRestoredPicker(.allowedDuringRestriction)
        } else if settings.requiresBudgetSelection, !hasBudgetRestoredSelection {
            showRestoredPicker(.dailyBudget)
        } else {
            finishRestoredSelection()
        }
    }

    private func continueRestoredSelection(afterDismissing target: RestoredPickerTarget) {
        guard focusController.requiresRestoredActivitySelection else { return }
        switch target {
        case .allowedDuringRestriction:
            guard hasAllowedRestoredSelection else { return }
        case .dailyBudget:
            guard hasBudgetRestoredSelection else { return }
        }
        DispatchQueue.main.async {
            showNextRestoredPickerIfNeeded()
        }
    }

    private var hasAllowedRestoredSelection: Bool {
        !restoredAllowedSelection.applicationTokens.isEmpty
            || !restoredAllowedSelection.webDomainTokens.isEmpty
    }

    private var hasBudgetRestoredSelection: Bool {
        !restoredBudgetSelection.applicationTokens.isEmpty
            || !restoredBudgetSelection.categoryTokens.isEmpty
            || !restoredBudgetSelection.webDomainTokens.isEmpty
    }

    private func finishRestoredSelection() {
        do {
            try focusController.resolveRestoredActivitySelections(
                allowedSelection: restoredAllowedSelection,
                budgetSelection: restoredBudgetSelection
            )
        } catch {
            app.present(error)
        }
    }
}

private struct DataStorePreparationErrorView: View {
    let message: String
    let isRetrying: Bool
    let logger: AppLogger
    let retry: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "externaldrive.badge.exclamationmark")
                .font(.system(size: 52))
                .foregroundStyle(.red)
            Text("データを準備できませんでした")
                .font(.title3.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
            Button(action: retry) {
                if isRetrying {
                    ProgressView()
                } else {
                    Text("再試行")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRetrying)
            DiagnosticLogCopyButton(logger: logger)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.subtleBackground)
    }
}

private struct LoadingSplash: View {
    let logger: AppLogger
    @State private var pulse = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            Text("StudyTrail")
                .font(.title2.bold())
                .foregroundStyle(AppColors.textPrimary)
            ProgressView()
            DiagnosticLogCopyButton(logger: logger)
                .padding(.horizontal, AppSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.subtleBackground)
        .onAppear { pulse = true }
    }
}
