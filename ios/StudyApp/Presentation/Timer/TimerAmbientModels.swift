import Foundation
import SwiftUI

struct TimerAmbientTheme {
    let colorScheme: ColorScheme
    let accent: Color
    let accentSoft: Color
    let ringTrack: Color
    let backgroundTop: Color
    let backgroundBottom: Color
    let foreground: Color
    let secondaryForeground: Color
    let panelOverlay: Color
    let panelStroke: Color
    let bottomBarBackground: Color

    static func make(colorScheme: ColorScheme) -> TimerAmbientTheme {
        switch colorScheme {
        case .light:
            return TimerAmbientTheme(
                colorScheme: .light,
                accent: Color.accentColor,
                accentSoft: Color(hex: 0xE7F6ED),
                ringTrack: Color(hex: 0xD8DEE8),
                backgroundTop: Color.white,
                backgroundBottom: Color.white,
                foreground: Color(hex: 0x152332),
                secondaryForeground: Color(hex: 0x5C6976),
                panelOverlay: Color.white.opacity(0.92),
                panelStroke: Color(hex: 0xE5E7EB),
                bottomBarBackground: Color.white.opacity(0.96)
            )
        case .dark:
            return TimerAmbientTheme(
                colorScheme: .dark,
                accent: Color(hex: 0x69E07A),
                accentSoft: Color(hex: 0x12331E),
                ringTrack: Color.white.opacity(0.14),
                backgroundTop: Color(hex: 0x090B10),
                backgroundBottom: Color.black,
                foreground: Color.white,
                secondaryForeground: Color.white.opacity(0.72),
                panelOverlay: Color(hex: 0x111827).opacity(0.72),
                panelStroke: Color.white.opacity(0.12),
                bottomBarBackground: Color.black.opacity(0.94)
            )
        @unknown default:
            return make(colorScheme: .light)
        }
    }
}

struct TimerAmbientBackgroundView: View {
    let theme: TimerAmbientTheme
    let isRunning: Bool

    var body: some View {
        LinearGradient(
            colors: [theme.backgroundTop, theme.backgroundBottom],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
