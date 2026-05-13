import XCTest
@testable import StudyApp

final class TimerAmbientResolverTests: XCTestCase {
    func testAutomaticPhaseUsesSunriseMorningWindow() {
        let sunrise = date(hour: 6, minute: 0)
        let sunset = date(hour: 18, minute: 0)
        let snapshot = snapshot(sunrise: sunrise, sunset: sunset)

        XCTAssertEqual(TimerAmbientResolver.automaticPhase(snapshot: snapshot, now: date(hour: 8, minute: 59)), .morning)
        XCTAssertEqual(TimerAmbientResolver.automaticPhase(snapshot: snapshot, now: date(hour: 9, minute: 0)), .day)
    }

    func testAutomaticPhaseStartsNightThirtyMinutesBeforeSunset() {
        let sunrise = date(hour: 6, minute: 0)
        let sunset = date(hour: 18, minute: 0)
        let snapshot = snapshot(sunrise: sunrise, sunset: sunset)

        XCTAssertEqual(TimerAmbientResolver.automaticPhase(snapshot: snapshot, now: date(hour: 17, minute: 29)), .day)
        XCTAssertEqual(TimerAmbientResolver.automaticPhase(snapshot: snapshot, now: date(hour: 17, minute: 30)), .night)
    }

    func testAutomaticPhaseFallsBackToClockWhenSunDataIsMissing() {
        XCTAssertEqual(TimerAmbientResolver.automaticPhase(snapshot: nil, now: date(hour: 6, minute: 30)), .morning)
        XCTAssertEqual(TimerAmbientResolver.automaticPhase(snapshot: nil, now: date(hour: 12, minute: 0)), .day)
        XCTAssertEqual(TimerAmbientResolver.automaticPhase(snapshot: nil, now: date(hour: 22, minute: 0)), .night)
    }

    func testWeatherCodeMapping() {
        XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: 0), .clear)
        XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: 3), .cloudy)
        XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: 61), .rain)
        XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: 71), .snow)
        XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: 95), .thunder)
        XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: -1), .unknown)
    }

    func testLegacyPreferencesDecodeDefaultsTimerVisualModeToAuto() throws {
        let json = """
        {
          "onboardingCompleted": true,
          "selectedColorTheme": "green",
          "selectedThemeMode": "system",
          "liveActivityEnabled": true,
          "liveActivityDisplayPreset": "standard",
          "landscapeTimerDisplayPreset": "problemProgress"
        }
        """

        let preferences = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))

        XCTAssertEqual(preferences.timerVisualMode, .auto)
    }

    private func snapshot(sunrise: Date?, sunset: Date?) -> TimerAmbientWeatherSnapshot {
        TimerAmbientWeatherSnapshot(
            latitude: 35.0,
            longitude: 139.0,
            weatherCode: 0,
            isDaylight: true,
            sunrise: sunrise,
            sunset: sunset,
            fetchedAt: date(hour: 5, minute: 0)
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: hour, minute: minute))!
    }
}
