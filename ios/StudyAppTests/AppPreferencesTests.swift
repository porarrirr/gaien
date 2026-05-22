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
