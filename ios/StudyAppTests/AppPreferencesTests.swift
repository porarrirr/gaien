import XCTest
@testable import StudyApp

final class AppPreferencesTests: XCTestCase {
    func testLegacyPreferencesDecodeAfterTimerAppearanceSettingRemoval() throws {
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

        XCTAssertTrue(preferences.onboardingCompleted)
        XCTAssertEqual(preferences.selectedThemeMode, .system)
    }
}

final class ScreenTimeFocusSettingsTests: XCTestCase {
    func testLegacyScreenTimeSettingsDecodeDefaultsGoalUnlockOff() throws {
        let json = """
        {
          "isEnabled": true,
          "timerRestrictionEnabled": true,
          "scheduledRestrictionEnabled": false,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.isEnabled)
        XCTAssertTrue(settings.timerRestrictionEnabled)
        XCTAssertFalse(settings.unlockRestrictionsWhenDailyGoalReached)
        XCTAssertNil(settings.settingsLockedUntilEpochMilliseconds)
        XCTAssertFalse(settings.isSettingsLocked)
    }

    func testSettingsLockDecodeAndEncodeRoundTrip() throws {
        let expiry = testDate(2026, 9, 1, hour: 0).epochMilliseconds
        let json = """
        {
          "isEnabled": true,
          "timerRestrictionEnabled": true,
          "scheduledRestrictionEnabled": false,
          "unlockRestrictionsWhenDailyGoalReached": true,
          "scheduleSlots": [],
          "settingsLockedUntilEpochMilliseconds": \(expiry)
        }
        """

        let decoded = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.settingsLockedUntilEpochMilliseconds, expiry)

        let encoded = try JSONEncoder().encode(decoded)
        let roundTripped = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: encoded)
        XCTAssertEqual(roundTripped.settingsLockedUntilEpochMilliseconds, expiry)
    }

    func testSettingsLockExpiryCalculationRejectsZeroDuration() {
        let start = testDate(2026, 6, 1, hour: 12)
        XCTAssertNil(ScreenTimeFocusSettings.lockExpiryDate(from: start, months: 0, days: 0))
    }

    func testSettingsLockExpiryCalculationAddsMonthsAndDays() {
        let start = testDate(2026, 6, 1, hour: 12)
        let expiry = ScreenTimeFocusSettings.lockExpiryDate(from: start, months: 2, days: 10)
        XCTAssertEqual(expiry, testDate(2026, 8, 11, hour: 12))
    }

    func testSettingsLockIsActiveBeforeExpiry() {
        let expiry = testDate(2026, 9, 1, hour: 0)
        let settings = ScreenTimeFocusSettings(settingsLockedUntilEpochMilliseconds: expiry.epochMilliseconds)
        XCTAssertTrue(settings.isSettingsLocked(at: testDate(2026, 6, 1, hour: 12)))
        XCTAssertFalse(settings.isSettingsLocked(at: expiry))
        XCTAssertFalse(settings.isSettingsLocked(at: testDate(2026, 10, 1, hour: 12)))
    }

    func testDailyGoalUnlockRequiresReachedTargetOnSameDay() {
        let reference = testDate(2026, 6, 1, hour: 12)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )
        let progress = ScreenTimeDailyGoalProgress(
            dayStart: reference.startOfDay.epochMilliseconds,
            studyMinutes: 90,
            targetMinutes: 60,
            updatedAt: reference.epochMilliseconds
        )

        XCTAssertTrue(settings.shouldUnlockRestrictionsForDailyGoal(progress: progress, referenceDate: reference))
    }

    func testDailyGoalUnlockIgnoresStaleProgress() {
        let reference = testDate(2026, 6, 1, hour: 12)
        let yesterday = testDate(2026, 5, 31, hour: 12)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )
        let progress = ScreenTimeDailyGoalProgress(
            dayStart: yesterday.startOfDay.epochMilliseconds,
            studyMinutes: 90,
            targetMinutes: 60,
            updatedAt: yesterday.epochMilliseconds
        )

        XCTAssertFalse(settings.shouldUnlockRestrictionsForDailyGoal(progress: progress, referenceDate: reference))
    }
}
