import SwiftUI

// MARK: - Color utility

extension Color {
    init(hex: Int, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
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
        Color(.systemBackground)
    }
    static var subtleBackground: Color {
        Color(hex: 0xF4F5F7)
    }
    static let groupedBackground = Color(hex: 0xF4F5F7)
    static let cardBorder = Color(hex: 0xE3E5EA)
    static let green = Color(hex: 0x2BA247)
    static let greenSoft = Color(hex: 0xEAF8EF)
    static let blue = Color(hex: 0x1D7FEA)
    static let blueSoft = Color(hex: 0xEAF3FF)
    static let orange = Color(hex: 0xF59E0B)
    static let orangeSoft = Color(hex: 0xFFF4D8)
    static let redSoft = Color(hex: 0xFDECEC)
    static var textPrimary: Color {
        Color(.label)
    }
    static var textSecondary: Color {
        Color(.secondaryLabel)
    }
    static let success = Color(hex: 0x2E9D45)
    static let warning = Color(hex: 0xF59E0B)
    static let danger = Color(hex: 0xE53935)
}

// MARK: - Strict (dense settings) layout tokens

enum StrictUI {
    static let screenPadding: CGFloat = 10
    static let cardPadding: CGFloat = 10
    static let sectionSpacing: CGFloat = 10
    static let rowHeight: CGFloat = 44
    static let hairline = AppColors.cardBorder
}
