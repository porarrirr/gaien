# StudyApp

English | [日本語](README.ja.md)

A cross-platform study tracker for Android and iOS. StudyApp combines a timer, learning-material progress, schedules, goals, tests, and reports so students can understand not only how long they studied, but what they worked on and what needs attention next.

## Highlights

- Stopwatch, countdown, and manual study records
- Subjects and learning materials with page or question progress
- Calendar, heatmap, daily timeline, and class timetable
- Daily, weekly, and monthly reports by subject
- Study streaks, goals, test countdowns, and weekly plans
- JSON and CSV export
- Android home-screen widgets and background timer
- iOS widgets, Live Activities, iPad layouts, and landscape focus views
- Optional iOS Screen Time controls that connect study progress with app-use limits
- Firebase account sync and in-app account deletion

## Platforms

- Android 8.0 or later (`minSdk 26`)
- iOS 16 or later
- An experimental local-only macOS companion is included under `macos/StudyAppMac`; it does not share data with the mobile apps.

Some iOS Screen Time features require Apple Family Controls approval, an App Group, and a signed physical-device or distribution build. Unsigned CI artifacts do not include usable Screen Time extensions.

## Data and privacy

The mobile apps can synchronize study data through Firebase Authentication and Firestore when configured. Firebase configuration files are not included in the repository. Users can delete their account from the app. The macOS companion stores its separate data locally.

## Build

Android:

```bash
cd android
./gradlew assembleDebug
./gradlew test
```

iOS:

```bash
open ios/StudyApp.xcodeproj
```

Firebase setup and platform-specific signing are required for cloud sync and protected Apple capabilities.

## License

A project license has not yet been selected.
