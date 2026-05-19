import CoreLocation
import Foundation
import WeatherKit

struct WeatherKitWeatherService {
    private let service: WeatherService

    init(service: WeatherService = .shared) {
        self.service = service
    }

    func fetch(for location: CLLocation) async throws -> TimerAmbientWeatherSnapshot {
        let (current, daily) = try await service.weather(for: location, including: .current, .daily)
        let today = daily.forecast.first

        return TimerAmbientWeatherSnapshot(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            weatherCode: current.condition.timerAmbientWeatherCode,
            isDaylight: current.isDaylight,
            sunrise: today?.sun.sunrise,
            sunset: today?.sun.sunset,
            fetchedAt: Date()
        )
    }
}

private extension WeatherCondition {
    var timerAmbientWeatherCode: Int {
        switch self {
        case .clear:
            return 0
        case .mostlyClear:
            return 1
        case .partlyCloudy:
            return 2
        case .cloudy, .mostlyCloudy:
            return 3
        case .blowingDust, .foggy, .haze, .smoky:
            return 45
        case .drizzle:
            return 51
        case .freezingDrizzle:
            return 56
        case .rain, .sunShowers:
            return 61
        case .heavyRain:
            return 65
        case .freezingRain, .sleet, .wintryMix:
            return 66
        case .flurries, .snow, .sunFlurries:
            return 71
        case .blizzard, .blowingSnow, .heavySnow:
            return 75
        case .isolatedThunderstorms, .scatteredThunderstorms, .thunderstorms, .strongStorms, .tropicalStorm, .hurricane:
            return 95
        case .hail:
            return 96
        case .breezy, .frigid, .hot, .windy:
            return 0
        @unknown default:
            return -1
        }
    }
}
