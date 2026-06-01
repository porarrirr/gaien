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
