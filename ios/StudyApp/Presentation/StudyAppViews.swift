import Foundation
import SwiftUI

// MARK: - Root

struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var app = StudyAppContainer()

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { app.errorMessage != nil },
            set: { if !$0 { app.clearError() } }
        )
    }

    var body: some View {
        Group {
            if !app.isLoaded {
                LoadingSplash()
            } else if !app.preferences.onboardingCompleted {
                OnboardingScreen(app: app)
            } else {
                MainTabView(app: app)
            }
        }
        .preferredColorScheme(app.preferences.selectedThemeMode.colorScheme)
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
private struct LoadingSplash: View {
    @State private var pulse = false

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundStyle(.tint)
                .scaleEffect(pulse ? 1.08 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: pulse)
            Text("StudyApp")
                .font(.title2.bold())
                .foregroundStyle(AppColors.textPrimary)
            ProgressView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.subtleBackground)
        .onAppear { pulse = true }
    }
}
