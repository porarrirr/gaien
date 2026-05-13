import Foundation
import SwiftUI

enum TimerAmbientPhase: String, Codable, Equatable {
    case morning
    case day
    case night

    var title: String {
        switch self {
        case .morning: return "朝"
        case .day: return "昼"
        case .night: return "夜"
        }
    }
}

enum TimerWeatherCondition: String, Codable, Equatable {
    case clear
    case cloudy
    case rain
    case snow
    case thunder
    case unknown

    var title: String {
        switch self {
        case .clear: return "晴れ"
        case .cloudy: return "くもり"
        case .rain: return "雨"
        case .snow: return "雪"
        case .thunder: return "雷"
        case .unknown: return "天気未取得"
        }
    }

    var systemImage: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .cloudy: return "cloud.fill"
        case .rain: return "cloud.rain.fill"
        case .snow: return "snowflake"
        case .thunder: return "cloud.bolt.rain.fill"
        case .unknown: return "location.slash"
        }
    }
}

struct TimerAmbientWeatherSnapshot: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var weatherCode: Int
    var isDaylight: Bool?
    var sunrise: Date?
    var sunset: Date?
    var fetchedAt: Date

    var condition: TimerWeatherCondition {
        TimerAmbientResolver.weatherCondition(for: weatherCode)
    }
}

enum TimerAmbientSource: String, Equatable {
    case manual
    case weather
    case cache
    case clock

    var title: String {
        switch self {
        case .manual: return "手動"
        case .weather: return "現在地"
        case .cache: return "キャッシュ"
        case .clock: return "時刻"
        }
    }
}

struct TimerAmbientContext: Equatable {
    var phase: TimerAmbientPhase
    var weatherCondition: TimerWeatherCondition
    var source: TimerAmbientSource
    var lastUpdatedAt: Date?
    var errorMessage: String?

    static func clockFallback(now: Date = Date()) -> TimerAmbientContext {
        TimerAmbientContext(
            phase: TimerAmbientResolver.clockPhase(at: now),
            weatherCondition: .unknown,
            source: .clock,
            lastUpdatedAt: nil,
            errorMessage: nil
        )
    }
}

struct TimerAmbientTheme {
    let phase: TimerAmbientPhase
    let weatherCondition: TimerWeatherCondition
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

    static func make(context: TimerAmbientContext) -> TimerAmbientTheme {
        switch context.phase {
        case .morning:
            return TimerAmbientTheme(
                phase: .morning,
                weatherCondition: context.weatherCondition,
                colorScheme: .light,
                accent: Color(hex: 0x27B56A),
                accentSoft: Color(hex: 0xE5F8EC),
                ringTrack: Color(hex: 0xCFE9E8),
                backgroundTop: Color(hex: 0xDDF6FF),
                backgroundBottom: Color(hex: 0xFFF1DD),
                foreground: Color(hex: 0x16302B),
                secondaryForeground: Color(hex: 0x54706C),
                panelOverlay: Color.white.opacity(0.74),
                panelStroke: Color.white.opacity(0.82),
                bottomBarBackground: Color(hex: 0xF3FBF8).opacity(0.94)
            )
        case .day:
            return TimerAmbientTheme(
                phase: .day,
                weatherCondition: context.weatherCondition,
                colorScheme: .light,
                accent: Color(hex: 0x209B58),
                accentSoft: Color(hex: 0xE7F6ED),
                ringTrack: Color(hex: 0xD6E7EF),
                backgroundTop: Color(hex: 0xDDF1FF),
                backgroundBottom: Color(hex: 0xF6FAFE),
                foreground: Color(hex: 0x152332),
                secondaryForeground: Color(hex: 0x5C6976),
                panelOverlay: Color.white.opacity(0.80),
                panelStroke: Color.white.opacity(0.88),
                bottomBarBackground: Color(hex: 0xF6FAFE).opacity(0.96)
            )
        case .night:
            return TimerAmbientTheme(
                phase: .night,
                weatherCondition: context.weatherCondition,
                colorScheme: .dark,
                accent: Color(hex: 0x69E07A),
                accentSoft: Color(hex: 0x12331E),
                ringTrack: Color.white.opacity(0.14),
                backgroundTop: Color(hex: 0x07152D),
                backgroundBottom: Color(hex: 0x020814),
                foreground: Color.white,
                secondaryForeground: Color.white.opacity(0.72),
                panelOverlay: Color(hex: 0x07101F).opacity(0.70),
                panelStroke: Color.white.opacity(0.12),
                bottomBarBackground: Color(hex: 0x030A16).opacity(0.94)
            )
        }
    }
}

struct TimerAmbientBackgroundView: View {
    let theme: TimerAmbientTheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [theme.backgroundTop, theme.backgroundBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            weatherTexture

            if theme.phase == .night {
                nightDetails
            } else {
                dayDetails
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var weatherTexture: some View {
        switch theme.weatherCondition {
        case .rain:
            VStack(spacing: 24) {
                ForEach(0..<8, id: \.self) { index in
                    HStack(spacing: 46) {
                        ForEach(0..<6, id: \.self) { column in
                            Capsule()
                                .fill(theme.secondaryForeground.opacity(theme.phase == .night ? 0.12 : 0.18))
                                .frame(width: 2, height: 16)
                                .rotationEffect(.degrees(16))
                                .offset(x: CGFloat((index + column) % 3) * 12)
                        }
                    }
                }
            }
            .offset(y: -40)
        case .snow:
            VStack(spacing: 30) {
                ForEach(0..<7, id: \.self) { index in
                    HStack(spacing: 52) {
                        ForEach(0..<5, id: \.self) { column in
                            Circle()
                                .fill(theme.foreground.opacity(theme.phase == .night ? 0.16 : 0.26))
                                .frame(width: CGFloat(2 + ((index + column) % 3)), height: CGFloat(2 + ((index + column) % 3)))
                        }
                    }
                }
            }
            .offset(y: -30)
        default:
            EmptyView()
        }
    }

    private var dayDetails: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.38))
                .frame(width: 190, height: 190)
                .blur(radius: 12)
                .offset(x: 130, y: -300)

            ForEach(0..<3, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.34 - Double(index) * 0.06))
                    .frame(width: 148 + CGFloat(index * 34), height: 28 + CGFloat(index * 3))
                    .blur(radius: 5)
                    .offset(x: CGFloat(index * 74 - 120), y: CGFloat(index * 82 - 160))
            }
        }
    }

    private var nightDetails: some View {
        ZStack {
            ForEach(0..<22, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index.isMultiple(of: 3) ? 0.55 : 0.28))
                    .frame(width: index.isMultiple(of: 4) ? 3 : 2, height: index.isMultiple(of: 4) ? 3 : 2)
                    .offset(
                        x: CGFloat((index * 37) % 320) - 160,
                        y: CGFloat((index * 53) % 360) - 300
                    )
            }

            VStack {
                Spacer()
                RoundedRectangle(cornerRadius: 90, style: .continuous)
                    .fill(Color.black.opacity(0.34))
                    .frame(height: 118)
                    .offset(y: 52)
            }
        }
    }
}
