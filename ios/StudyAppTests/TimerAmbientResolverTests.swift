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
        let expected: [Int: TimerWeatherCondition] = [
            0: .clear,
            1: .mainlyClear,
            2: .partlyCloudy,
            3: .overcast,
            45: .fog,
            48: .fog,
            51: .drizzle,
            53: .drizzle,
            55: .drizzle,
            56: .freezingDrizzle,
            57: .freezingDrizzle,
            61: .rain,
            63: .rain,
            65: .rain,
            66: .freezingRain,
            67: .freezingRain,
            71: .snow,
            73: .snow,
            75: .snow,
            77: .snowGrains,
            80: .rainShowers,
            81: .rainShowers,
            82: .rainShowers,
            85: .snowShowers,
            86: .snowShowers,
            95: .thunderstorm,
            96: .thunderstormWithHail,
            99: .thunderstormWithHail
        ]

        for (code, condition) in expected {
            XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: code), condition, "Unexpected condition for WMO code \(code)")
        }

        XCTAssertEqual(TimerAmbientResolver.weatherCondition(for: -1), .unknown)
    }

    func testWeatherVisualProfileUsesIntensityAndAssets() {
        let lightRain = visualProfile(code: 61, phase: .day)
        let heavyRain = visualProfile(code: 65, phase: .day)
        let slightShower = visualProfile(code: 80, phase: .day)
        let violentShower = visualProfile(code: 82, phase: .day)
        let thunder = visualProfile(code: 95, phase: .night)
        let hailThunder = visualProfile(code: 99, phase: .night)

        XCTAssertEqual(lightRain.baseAsset, .rain)
        XCTAssertEqual(lightRain.precipitation, .rain)
        XCTAssertGreaterThan(heavyRain.intensity, lightRain.intensity)
        XCTAssertGreaterThan(violentShower.intensity, slightShower.intensity)
        XCTAssertEqual(thunder.baseAsset, .thunder)
        XCTAssertTrue(thunder.lightning)
        XCTAssertGreaterThan(hailThunder.intensity, thunder.intensity)
    }

    func testNightClearUsesNightAsset() {
        let profile = TimerWeatherVisualProfile.make(
            context: TimerAmbientContext(
                phase: .night,
                weatherCondition: .clear,
                weatherCode: 0,
                source: .weather,
                lastUpdatedAt: nil,
                errorMessage: nil
            )
        )

        XCTAssertEqual(profile.baseAsset, .night)
        XCTAssertEqual(profile.precipitation, .none)
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

    private func visualProfile(code: Int, phase: TimerAmbientPhase) -> TimerWeatherVisualProfile {
        TimerWeatherVisualProfile.make(
            context: TimerAmbientContext(
                phase: phase,
                weatherCondition: TimerAmbientResolver.weatherCondition(for: code),
                weatherCode: code,
                source: .weather,
                lastUpdatedAt: nil,
                errorMessage: nil
            )
        )
    }

    private func date(hour: Int, minute: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: 2026, month: 5, day: 13, hour: hour, minute: minute))!
    }
}
