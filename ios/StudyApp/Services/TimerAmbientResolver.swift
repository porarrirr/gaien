import Foundation

enum TimerAmbientResolver {
    static func resolve(
        mode: TimerVisualMode,
        snapshot: TimerAmbientWeatherSnapshot?,
        now: Date = Date(),
        source: TimerAmbientSource? = nil,
        errorMessage: String? = nil
    ) -> TimerAmbientContext {
        switch mode {
        case .morning, .day, .night:
            return TimerAmbientContext(
                phase: mode.fixedPhase,
                weatherCondition: snapshot?.condition ?? .unknown,
                weatherCode: snapshot?.weatherCode,
                source: .manual,
                lastUpdatedAt: snapshot?.fetchedAt,
                errorMessage: nil
            )
        case .auto:
            let resolvedSource = source ?? (snapshot == nil ? .clock : .weather)
            return TimerAmbientContext(
                phase: automaticPhase(snapshot: snapshot, now: now),
                weatherCondition: snapshot?.condition ?? .unknown,
                weatherCode: snapshot?.weatherCode,
                source: resolvedSource,
                lastUpdatedAt: snapshot?.fetchedAt,
                errorMessage: errorMessage
            )
        }
    }

    static func automaticPhase(snapshot: TimerAmbientWeatherSnapshot?, now: Date = Date()) -> TimerAmbientPhase {
        guard let sunrise = snapshot?.sunrise,
              let sunset = snapshot?.sunset else {
            return clockPhase(at: now)
        }

        let morningEnd = sunrise.addingTimeInterval(3 * 60 * 60)
        let nightStart = sunset.addingTimeInterval(-30 * 60)

        if now >= sunrise && now < morningEnd {
            return .morning
        }
        if now >= morningEnd && now < nightStart {
            return .day
        }
        return .night
    }

    static func clockPhase(at date: Date, calendar: Calendar = .current) -> TimerAmbientPhase {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .morning
        case 11..<18:
            return .day
        default:
            return .night
        }
    }

    static func weatherCondition(for code: Int) -> TimerWeatherCondition {
        switch code {
        case 0:
            return .clear
        case 1:
            return .mainlyClear
        case 2:
            return .partlyCloudy
        case 3:
            return .overcast
        case 45, 48:
            return .fog
        case 51, 53, 55:
            return .drizzle
        case 56, 57:
            return .freezingDrizzle
        case 61, 63, 65:
            return .rain
        case 66, 67:
            return .freezingRain
        case 71, 73, 75:
            return .snow
        case 77:
            return .snowGrains
        case 80, 81, 82:
            return .rainShowers
        case 85, 86:
            return .snowShowers
        case 95:
            return .thunderstorm
        case 96, 99:
            return .thunderstormWithHail
        default:
            return .unknown
        }
    }
}

private extension TimerVisualMode {
    var fixedPhase: TimerAmbientPhase {
        switch self {
        case .auto:
            return .day
        case .morning:
            return .morning
        case .day:
            return .day
        case .night:
            return .night
        }
    }
}
