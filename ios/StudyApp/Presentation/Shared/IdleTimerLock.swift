import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// A view modifier that disables the system idle timer (auto-lock) while the
/// modified view is on screen. Resets to the system default on disappear.
///
/// Use to keep the screen awake during long-running activities such as the
/// study timer. Replaces direct mutation of `UIApplication.shared.isIdleTimerDisabled`
/// from inside SwiftUI views.
struct IdleTimerLock: ViewModifier {
    let isActive: Bool

    func body(content: Content) -> some View {
        content
            .onAppear { apply(disabled: isActive) }
            .onDisappear { apply(disabled: false) }
            .onChange(of: isActive) { newValue in
                apply(disabled: newValue)
            }
    }

    private func apply(disabled: Bool) {
        #if canImport(UIKit)
        UIApplication.shared.isIdleTimerDisabled = disabled
        #endif
    }
}

extension View {
    /// Keep the screen awake while `isActive == true`.
    func keepScreenAwake(_ isActive: Bool = true) -> some View {
        modifier(IdleTimerLock(isActive: isActive))
    }
}
