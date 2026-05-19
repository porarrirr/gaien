import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Color utility

extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    static func adaptive(light: Int, dark: Int, lightOpacity: Double = 1.0, darkOpacity: Double = 1.0) -> Color {
        #if canImport(UIKit)
        Color(
            UIColor { traits in
                let hex = traits.userInterfaceStyle == .dark ? dark : light
                let opacity = traits.userInterfaceStyle == .dark ? darkOpacity : lightOpacity
                return UIColor(
                    red: CGFloat((hex >> 16) & 0xFF) / 255.0,
                    green: CGFloat((hex >> 8) & 0xFF) / 255.0,
                    blue: CGFloat(hex & 0xFF) / 255.0,
                    alpha: opacity
                )
            }
        )
        #else
        Color(hex: light, opacity: lightOpacity)
        #endif
    }
}

extension ThemeMode {
    var colorScheme: ColorScheme? {
        switch self {
        case .light: return .light
        case .dark: return .dark
        case .system: return nil
        }
    }
}

extension ColorTheme {
    var primaryColor: Color {
        Color(hex: hex)
    }

    var accentColor: Color {
        Color(hex: accentHex)
    }
}

// MARK: - Spacing / Corner tokens

enum AppSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 7
    static let md: CGFloat = 12
    static let lg: CGFloat = 18
    static let xl: CGFloat = 24
    static let screenHorizontal: CGFloat = 10
}

enum AppCornerRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 8
    static let lg: CGFloat = 10
}

// MARK: - Color tokens

enum AppColors {
    static var cardBackground: Color {
        Color(.secondarySystemGroupedBackground)
    }
    static var subtleBackground: Color {
        Color(.systemGroupedBackground)
    }
    static var groupedBackground: Color {
        Color(.systemGroupedBackground)
    }
    static var cardBorder: Color {
        Color.adaptive(light: 0xE3E5EA, dark: 0x383C43)
    }
    static var green: Color {
        Color.accentColor
    }
    static var greenSoft: Color {
        Color.accentColor.opacity(0.16)
    }
    static var blue: Color {
        Color.adaptive(light: 0x1D7FEA, dark: 0x5EADF2)
    }
    static var blueSoft: Color {
        Color.adaptive(light: 0xEAF3FF, dark: 0x15324E)
    }
    static var orange: Color {
        Color.adaptive(light: 0xF59E0B, dark: 0xFFB340)
    }
    static var orangeSoft: Color {
        Color.adaptive(light: 0xFFF4D8, dark: 0x3E2B12)
    }
    static var redSoft: Color {
        Color.adaptive(light: 0xFDECEC, dark: 0x3D1F20)
    }
    static var textPrimary: Color {
        Color(.label)
    }
    static var textSecondary: Color {
        Color(.secondaryLabel)
    }
    static var success: Color {
        Color.accentColor
    }
    static var warning: Color {
        Color.adaptive(light: 0xF59E0B, dark: 0xFFB340)
    }
    static var danger: Color {
        Color.adaptive(light: 0xE53935, dark: 0xFF6B64)
    }
}

// MARK: - Strict (dense settings) layout tokens

enum StrictUI {
    static let screenPadding: CGFloat = 10
    static let cardPadding: CGFloat = 10
    static let sectionSpacing: CGFloat = 10
    static let rowHeight: CGFloat = 44
    static let hairline = AppColors.cardBorder
}
