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
    case mainlyClear
    case partlyCloudy
    case overcast
    case fog
    case drizzle
    case freezingDrizzle
    case rain
    case freezingRain
    case snow
    case snowGrains
    case rainShowers
    case snowShowers
    case thunderstorm
    case thunderstormWithHail
    case unknown

    var title: String {
        switch self {
        case .clear: return "晴れ"
        case .mainlyClear: return "ほぼ晴れ"
        case .partlyCloudy: return "一部くもり"
        case .overcast: return "くもり"
        case .fog: return "霧"
        case .drizzle: return "霧雨"
        case .freezingDrizzle: return "着氷性の霧雨"
        case .rain: return "雨"
        case .freezingRain: return "着氷性の雨"
        case .snow: return "雪"
        case .snowGrains: return "細雪"
        case .rainShowers: return "にわか雨"
        case .snowShowers: return "にわか雪"
        case .thunderstorm: return "雷雨"
        case .thunderstormWithHail: return "雷雨とひょう"
        case .unknown: return "天気未取得"
        }
    }

    var systemImage: String {
        switch self {
        case .clear: return "sun.max.fill"
        case .mainlyClear: return "sun.min.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .overcast: return "cloud.fill"
        case .fog: return "cloud.fog.fill"
        case .drizzle: return "cloud.drizzle.fill"
        case .freezingDrizzle: return "cloud.sleet.fill"
        case .rain: return "cloud.rain.fill"
        case .freezingRain: return "cloud.sleet.fill"
        case .snow, .snowGrains: return "snowflake"
        case .rainShowers: return "cloud.heavyrain.fill"
        case .snowShowers: return "cloud.snow.fill"
        case .thunderstorm, .thunderstormWithHail: return "cloud.bolt.rain.fill"
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
    var weatherCode: Int?
    var source: TimerAmbientSource
    var lastUpdatedAt: Date?
    var errorMessage: String?

    static func clockFallback(now: Date = Date()) -> TimerAmbientContext {
        TimerAmbientContext(
            phase: TimerAmbientResolver.clockPhase(at: now),
            weatherCondition: .unknown,
            weatherCode: nil,
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
    let visualProfile: TimerWeatherVisualProfile

    static func make(context: TimerAmbientContext) -> TimerAmbientTheme {
        let profile = TimerWeatherVisualProfile.make(context: context)
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
                bottomBarBackground: Color(hex: 0xF3FBF8).opacity(0.94),
                visualProfile: profile
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
                bottomBarBackground: Color(hex: 0xF6FAFE).opacity(0.96),
                visualProfile: profile
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
                bottomBarBackground: Color(hex: 0x030A16).opacity(0.94),
                visualProfile: profile
            )
        }
    }
}

enum TimerWeatherBaseAsset: String, Equatable {
    case clear = "TimerWeatherClear"
    case partlyCloudy = "TimerWeatherPartlyCloudy"
    case overcast = "TimerWeatherOvercast"
    case fog = "TimerWeatherFog"
    case rain = "TimerWeatherRain"
    case snow = "TimerWeatherSnow"
    case thunder = "TimerWeatherThunder"
    case night = "TimerWeatherNight"
}

enum TimerWeatherPrecipitation: Equatable {
    case none
    case drizzle
    case rain
    case snow
}

struct TimerWeatherVisualProfile: Equatable {
    let baseAsset: TimerWeatherBaseAsset
    let precipitation: TimerWeatherPrecipitation
    let intensity: Double
    let cloudOpacity: Double
    let fogOpacity: Double
    let lightning: Bool

    var assetName: String { baseAsset.rawValue }

    static func make(context: TimerAmbientContext) -> TimerWeatherVisualProfile {
        let condition = context.weatherCondition
        let intensity = intensity(for: condition, code: context.weatherCode)
        let nightBase = context.phase == .night

        switch condition {
        case .clear:
            return TimerWeatherVisualProfile(
                baseAsset: nightBase ? .night : .clear,
                precipitation: .none,
                intensity: intensity,
                cloudOpacity: 0.10,
                fogOpacity: 0,
                lightning: false
            )
        case .mainlyClear:
            return TimerWeatherVisualProfile(
                baseAsset: nightBase ? .night : .clear,
                precipitation: .none,
                intensity: intensity,
                cloudOpacity: 0.18,
                fogOpacity: 0,
                lightning: false
            )
        case .partlyCloudy:
            return TimerWeatherVisualProfile(
                baseAsset: nightBase ? .night : .partlyCloudy,
                precipitation: .none,
                intensity: intensity,
                cloudOpacity: 0.42,
                fogOpacity: 0,
                lightning: false
            )
        case .overcast:
            return TimerWeatherVisualProfile(
                baseAsset: nightBase ? .night : .overcast,
                precipitation: .none,
                intensity: intensity,
                cloudOpacity: 0.70,
                fogOpacity: 0.05,
                lightning: false
            )
        case .fog:
            return TimerWeatherVisualProfile(
                baseAsset: .fog,
                precipitation: .none,
                intensity: intensity,
                cloudOpacity: 0.34,
                fogOpacity: context.weatherCode == 48 ? 0.82 : 0.62,
                lightning: false
            )
        case .drizzle, .freezingDrizzle:
            return TimerWeatherVisualProfile(
                baseAsset: .rain,
                precipitation: .drizzle,
                intensity: intensity,
                cloudOpacity: 0.62,
                fogOpacity: condition == .freezingDrizzle ? 0.34 : 0.16,
                lightning: false
            )
        case .rain, .freezingRain:
            return TimerWeatherVisualProfile(
                baseAsset: .rain,
                precipitation: .rain,
                intensity: intensity,
                cloudOpacity: 0.74,
                fogOpacity: condition == .freezingRain ? 0.24 : 0.10,
                lightning: false
            )
        case .rainShowers:
            return TimerWeatherVisualProfile(
                baseAsset: .rain,
                precipitation: .rain,
                intensity: intensity,
                cloudOpacity: 0.66,
                fogOpacity: 0.08,
                lightning: false
            )
        case .snow, .snowGrains, .snowShowers:
            return TimerWeatherVisualProfile(
                baseAsset: .snow,
                precipitation: .snow,
                intensity: intensity,
                cloudOpacity: 0.50,
                fogOpacity: condition == .snowGrains ? 0.20 : 0.10,
                lightning: false
            )
        case .thunderstorm, .thunderstormWithHail:
            return TimerWeatherVisualProfile(
                baseAsset: .thunder,
                precipitation: .rain,
                intensity: intensity,
                cloudOpacity: 0.88,
                fogOpacity: 0.10,
                lightning: true
            )
        case .unknown:
            return TimerWeatherVisualProfile(
                baseAsset: nightBase ? .night : .partlyCloudy,
                precipitation: .none,
                intensity: 0.18,
                cloudOpacity: 0.20,
                fogOpacity: 0,
                lightning: false
            )
        }
    }

    private static func intensity(for condition: TimerWeatherCondition, code: Int?) -> Double {
        guard let code else {
            return condition == .unknown ? 0.18 : 0.32
        }

        switch code {
        case 0: return 0.08
        case 1: return 0.16
        case 2: return 0.34
        case 3: return 0.54
        case 45: return 0.58
        case 48: return 0.76
        case 51: return 0.24
        case 53: return 0.34
        case 55: return 0.46
        case 56: return 0.36
        case 57: return 0.54
        case 61: return 0.42
        case 63: return 0.58
        case 65: return 0.76
        case 66: return 0.52
        case 67: return 0.72
        case 71: return 0.38
        case 73: return 0.54
        case 75: return 0.72
        case 77: return 0.30
        case 80: return 0.50
        case 81: return 0.66
        case 82: return 0.86
        case 85: return 0.56
        case 86: return 0.76
        case 95: return 0.72
        case 96: return 0.84
        case 99: return 0.94
        default: return 0.18
        }
    }
}

struct TimerAmbientBackgroundView: View {
    let theme: TimerAmbientTheme

    var body: some View {
        TimelineView(.animation) { timeline in
            GeometryReader { proxy in
                let progress = timeline.date.timeIntervalSinceReferenceDate
                let size = proxy.size
                ZStack {
                    Image(theme.visualProfile.assetName)
                        .resizable()
                        .scaledToFill()
                        .frame(width: size.width, height: size.height)
                        .clipped()

                    phaseTint
                    cloudLayer(size: size, progress: progress)
                    fogLayer(size: size, progress: progress)
                    precipitationLayer(size: size, progress: progress)
                    lightningLayer(progress: progress)
                    readabilityScrim
                }
                .frame(width: size.width, height: size.height)
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var phaseTint: some View {
        switch theme.phase {
        case .morning:
            LinearGradient(
                colors: [Color(hex: 0xFFF1D8).opacity(0.25), Color.clear, Color(hex: 0xA8E7FF).opacity(0.16)],
                startPoint: .bottomLeading,
                endPoint: .topTrailing
            )
        case .day:
            LinearGradient(
                colors: [Color.white.opacity(0.10), Color.clear, Color(hex: 0x68C7FF).opacity(0.10)],
                startPoint: .top,
                endPoint: .bottom
            )
        case .night:
            LinearGradient(
                colors: [Color(hex: 0x020817).opacity(0.54), Color(hex: 0x07182E).opacity(0.36)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    private func cloudLayer(size: CGSize, progress: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { index in
                let width = size.width * CGFloat(0.44 + Double(index % 3) * 0.10)
                let offset = movingOffset(
                    progress: progress,
                    speed: 16 + Double(index * 4),
                    span: size.width + width,
                    seed: Double(index) * 71
                )
                Capsule()
                    .fill(Color.white.opacity(cloudOpacity(for: index)))
                    .frame(width: width, height: 38 + CGFloat(index % 2) * 18)
                    .blur(radius: 12 + CGFloat(index % 3) * 4)
                    .offset(
                        x: offset,
                        y: CGFloat(index) * size.height * 0.13 - size.height * 0.34
                    )
            }
        }
        .opacity(theme.visualProfile.cloudOpacity)
    }

    private func fogLayer(size: CGSize, progress: TimeInterval) -> some View {
        ZStack {
            ForEach(0..<4, id: \.self) { index in
                let width = size.width * CGFloat(0.72 + Double(index) * 0.12)
                Capsule()
                    .fill(Color.white.opacity(0.22))
                    .frame(width: width, height: 54 + CGFloat(index) * 10)
                    .blur(radius: 20)
                    .offset(
                        x: movingOffset(progress: progress, speed: 9 + Double(index * 2), span: size.width + width, seed: Double(index) * 97),
                        y: size.height * (0.08 + CGFloat(index) * 0.16)
                    )
            }
        }
        .opacity(theme.visualProfile.fogOpacity)
    }

    @ViewBuilder
    private func precipitationLayer(size: CGSize, progress: TimeInterval) -> some View {
        switch theme.visualProfile.precipitation {
        case .none:
            EmptyView()
        case .drizzle:
            RainParticleLayer(
                size: size,
                progress: progress,
                count: particleCount(base: 22),
                intensity: theme.visualProfile.intensity,
                color: precipitationColor,
                length: 12,
                width: 1.2
            )
        case .rain:
            RainParticleLayer(
                size: size,
                progress: progress,
                count: particleCount(base: 34),
                intensity: theme.visualProfile.intensity,
                color: precipitationColor,
                length: 18 + CGFloat(theme.visualProfile.intensity) * 12,
                width: 1.6
            )
        case .snow:
            SnowParticleLayer(
                size: size,
                progress: progress,
                count: particleCount(base: 30),
                intensity: theme.visualProfile.intensity,
                color: precipitationColor
            )
        }
    }

    @ViewBuilder
    private func lightningLayer(progress: TimeInterval) -> some View {
        if theme.visualProfile.lightning {
            let flash = sin(progress * 2.7) > 0.985 || sin(progress * 1.4 + 1.1) > 0.992
            Color.white
                .opacity(flash ? 0.34 : 0)
                .animation(.easeOut(duration: 0.12), value: flash)
        }
    }

    private var readabilityScrim: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.black.opacity(theme.phase == .night ? 0.26 : 0.08),
                    Color.clear,
                    Color.black.opacity(theme.phase == .night ? 0.38 : 0.12)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            Color.white.opacity(theme.phase == .night ? 0 : 0.08)
                .blendMode(.screen)
        }
    }

    private var precipitationColor: Color {
        theme.phase == .night ? Color.white.opacity(0.64) : Color.white.opacity(0.72)
    }

    private func cloudOpacity(for index: Int) -> Double {
        max(0.08, 0.22 - Double(index) * 0.025)
    }

    private func particleCount(base: Int) -> Int {
        base + Int(theme.visualProfile.intensity * 34)
    }

    private func movingOffset(progress: TimeInterval, speed: Double, span: CGFloat, seed: Double) -> CGFloat {
        let cycle = (progress * speed + seed).truncatingRemainder(dividingBy: Double(span))
        return CGFloat(cycle) - span / 2
    }
}

private struct RainParticleLayer: View {
    let size: CGSize
    let progress: TimeInterval
    let count: Int
    let intensity: Double
    let color: Color
    let length: CGFloat
    let width: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(color.opacity(0.32 + intensity * 0.34))
                    .frame(width: width, height: length)
                    .rotationEffect(.degrees(14))
                    .offset(x: xPosition(index), y: yPosition(index))
            }
        }
    }

    private func xPosition(_ index: Int) -> CGFloat {
        let raw = CGFloat((index * 47) % 101) / 100
        return raw * (size.width + 90) - size.width / 2 - 45
    }

    private func yPosition(_ index: Int) -> CGFloat {
        let speed = 180 + intensity * 260
        let seed = Double((index * 83) % 127)
        let cycle = (progress * speed + seed).truncatingRemainder(dividingBy: Double(size.height + 160))
        return CGFloat(cycle) - size.height / 2 - 80
    }
}

private struct SnowParticleLayer: View {
    let size: CGSize
    let progress: TimeInterval
    let count: Int
    let intensity: Double
    let color: Color

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Circle()
                    .fill(color.opacity(0.42 + intensity * 0.28))
                    .frame(width: flakeSize(index), height: flakeSize(index))
                    .blur(radius: index.isMultiple(of: 5) ? 0.8 : 0)
                    .offset(x: xPosition(index), y: yPosition(index))
            }
        }
    }

    private func flakeSize(_ index: Int) -> CGFloat {
        CGFloat(2 + (index % 4))
    }

    private func xPosition(_ index: Int) -> CGFloat {
        let raw = CGFloat((index * 43) % 101) / 100
        let drift = sin(progress * 0.7 + Double(index)) * 18
        return raw * (size.width + 70) - size.width / 2 - 35 + CGFloat(drift)
    }

    private func yPosition(_ index: Int) -> CGFloat {
        let speed = 36 + intensity * 86
        let seed = Double((index * 89) % 137)
        let cycle = (progress * speed + seed).truncatingRemainder(dividingBy: Double(size.height + 120))
        return CGFloat(cycle) - size.height / 2 - 60
    }
}
}
