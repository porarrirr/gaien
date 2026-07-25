import FamilyControls
import Foundation
import SwiftUI

// MARK: - Root

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var app: StudyAppContainer
    @ObservedObject private var focusController: ScreenTimeFocusController
    @State private var restoredSelection = FamilyActivitySelection(includeEntireCategory: true)
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
        .alert("許可するアプリを選択してください", isPresented: restoredSelectionPromptBinding) {
            Button("選択する") {
                beginRestoredSelection()
            }
            Button("あとで", role: .cancel) {
                hasPresentedRestoredSelectionPrompt = true
            }
        } message: {
            Text("ログインしたアカウントのScreen Time設定を復元しました。Appleの仕様により許可アプリは端末間で引き継げないため、この端末で選び直してください。")
        }
        .familyActivityPicker(
            headerText: "集中制限中も使えるアプリとWebサイトを選択してください",
            footerText: "この選択は端末固有です。ほかのScreen Time設定はクラウドから復元済みです。",
            isPresented: $isShowingRestoredSelectionPicker,
            selection: $restoredSelection
        )
        .onChange(of: restoredSelection) { selection in
            let hasSelection = !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty
            guard hasSelection, focusController.requiresRestoredActivitySelection else { return }
            do {
                try focusController.resolveRestoredActivitySelection(selection)
            } catch {
                app.present(error)
            }
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
                restoredSelection = focusController.settings.activitySelection
                isShowingRestoredSelectionPicker = true
            } catch {
                app.present(error)
            }
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
