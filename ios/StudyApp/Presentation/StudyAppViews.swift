import Foundation
import SwiftUI

// MARK: - Root

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var app: StudyAppContainer

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.clearError() } }
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
        .onChange(of: scenePhase) { newPhase in
            guard newPhase == .active else { return }
            app.handleSceneDidBecomeActive()
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
