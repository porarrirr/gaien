# Repository Guidelines

## Project Structure & Module Organization
This repository contains StudyApp, a cross-platform study-tracking app.

- `android/` contains the Kotlin Android app. Main code lives under `android/app/src/main/java/com/studyapp/`, with `data`, `domain`, `presentation`, `services`, `sync`, and `widgets` layers.
- `android/app/src/test/` contains JVM tests. Room schema snapshots are tracked in `android/app/schemas/`.
- `ios/StudyApp/` contains the SwiftUI app, split into `Data`, `Domain`, `Presentation`, `Services`, `Resources`, and `Widgets`.
- `ios/StudyAppWidgets/` contains the WidgetKit and Live Activity extension.
- `.github/workflows/ios-ipa-release.yml` builds and attaches unsigned iOS IPAs for release tags.
- `firestore.rules`, `firebase.json`, and `.firebaserc` define Firebase deployment/configuration.

## Build, Test, and Development Commands
Run commands from the repository root unless noted.

- `cd android; .\gradlew.bat assembleDebug` builds the Android debug APK.
- `cd android; .\gradlew.bat test` runs JVM unit tests.
- `cd android; .\gradlew.bat lint` runs Android lint.
- `xcodebuild -project ios/StudyApp.xcodeproj -scheme StudyApp -sdk iphoneos -configuration Release build` builds iOS on macOS/Xcode.
- Use the existing GitHub workflow for unsigned iOS IPA releases; do not replace it with a parallel release path.

## Coding Style & Naming Conventions
Use Kotlin idioms on Android: 4-space indentation, `PascalCase` types, `camelCase` members, and package paths under `com.studyapp`. Keep Compose UI in `presentation` and persistence/network code in `data`.

Use Swift conventions on iOS: 4-space indentation, `PascalCase` types, `camelCase` members, and one primary type per file when practical. Keep SwiftUI views and view models under `Presentation`, Core Data/Firebase code under `Data`, and app/domain models under `Domain`.

## Testing Guidelines
Prefer small unit tests beside the changed platform. Android tests use JUnit, MockK, coroutines-test, and Turbine; name files `*Test.kt`. For iOS, add XCTest targets/files when introducing testable pure Swift logic, and verify with `xcodebuild test` on macOS when available. Always mention when iOS verification was static-only on Windows.

## Commit & Pull Request Guidelines
Recent commits use short imperative summaries such as `Refine iOS study views` and `Fix iOS release build regressions`. Keep commits focused by platform or feature. PRs should describe user-visible changes, data migration impact, Firebase/config requirements, and include screenshots for UI changes.

## Agent-Specific Instructions
Do not implement chained fallbacks when the correct implementation path is known. Use the correct API or workflow, and fail clearly if it does not work. Before any Git operation, run `git rev-parse --show-toplevel` in this project and stop if the root resolves to `C:\Users\nmrhr`.
