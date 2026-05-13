import Foundation

struct OpenMeteoService {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetch(latitude: Double, longitude: Double) async throws -> TimerAmbientWeatherSnapshot {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "current", value: "weather_code,is_day"),
            URLQueryItem(name: "daily", value: "sunrise,sunset"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "1")
        ]

        guard let url = components?.url else {
            throw OpenMeteoError.invalidURL
        }

        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw OpenMeteoError.badResponse
        }

        let decoded = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)
        return TimerAmbientWeatherSnapshot(
            latitude: latitude,
            longitude: longitude,
            weatherCode: decoded.current.weatherCode,
            isDaylight: decoded.current.isDay.map { $0 == 1 },
            sunrise: decoded.daily.sunrise.first.flatMap(Self.parseLocalDate),
            sunset: decoded.daily.sunset.first.flatMap(Self.parseLocalDate),
            fetchedAt: Date()
        )
    }

    private static func parseLocalDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
        return formatter.date(from: value)
    }
}

enum OpenMeteoError: LocalizedError {
    case invalidURL
    case badResponse

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "天気取得URLを作成できませんでした"
        case .badResponse:
            return "天気情報を取得できませんでした"
        }
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    var current: Current
    var daily: Daily

    struct Current: Decodable {
        var weatherCode: Int
        var isDay: Int?

        private enum CodingKeys: String, CodingKey {
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        var sunrise: [String]
        var sunset: [String]
    }
}
