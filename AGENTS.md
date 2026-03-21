# StudyApp - Cross-Platform Study Tracking App

A study tracking application with Android (Kotlin/Jetpack Compose) and iOS (Swift/SwiftUI) implementations.

## Project Structure

```
gaien/
├── android/           # Android app (Kotlin + Jetpack Compose)
│   ├── app/
│   │   └── src/main/java/com/studyapp/
│   │       ├── data/           # Data layer (Room DB, repositories)
│   │       ├── di/             # Hilt dependency injection
│   │       ├── domain/         # Domain layer (models, repository interfaces)
│   │       └── presentation/   # UI layer (Compose screens, ViewModels)
│   └── build.gradle.kts
└── ios/
    └── StudyApp/      # iOS app (Swift + SwiftUI)
        ├── Data/              # Data layer (Core Data, repositories)
        ├── Domain/            # Domain layer (entities, repositories)
        ├── Presentation/      # UI layer (SwiftUI views, ViewModels)
        └── Services/          # Services layer
```

## Build Commands

### Android

```bash
# Build the project (from android/ directory)
cd android && ./gradlew build

# Build debug APK
cd android && ./gradlew assembleDebug

# Build release APK
cd android && ./gradlew assembleRelease

# Clean build
cd android && ./gradlew clean

# Run lint
cd android && ./gradlew lint
```

### iOS

Open `ios/StudyApp.xcodeproj` in Xcode and build from there.
(No Xcode project file exists yet - create one using Xcode)

## Test Commands

### Android

```bash
# Run all unit tests
cd android && ./gradlew test

# Run a single test class
cd android && ./gradlew test --tests "com.studyapp.ExampleTest"

# Run a single test method
cd android && ./gradlew test --tests "com.studyapp.ExampleTest.testName"

# Run Android instrumentation tests
cd android && ./gradlew connectedAndroidTest

# Run with test coverage
cd android && ./gradlew testDebugUnitTestCoverage
```

### iOS

Run tests via Xcode: Cmd+U or Product > Test

## Code Style Guidelines

### Architecture

Both platforms follow Clean Architecture:
- **Presentation Layer**: Screens/Views + ViewModels
- **Domain Layer**: Business models + Repository interfaces
- **Data Layer**: Database + Repository implementations

### Android (Kotlin)

#### Imports
- Use explicit imports (avoid `.*` wildcards except for commonly used packages)
- Order: Android/Compose → Kotlin → Third-party → Local packages
- Separate import groups with blank lines

#### Naming Conventions
- **Classes**: PascalCase (`HomeViewModel`, `StudySessionRepository`)
- **Functions**: camelCase (`loadData`, `getSessionsByDate`)
- **Properties**: camelCase (`uiState`, `todayStudyMinutes`)
- **Composable functions**: PascalCase (`HomeScreen`, `TodayStudySection`)
- **Data classes**: PascalCase with `data class` keyword
- **DAO interfaces**: XxxxDao (`StudySessionDao`)
- **Entities**: XxxxEntity (`StudySessionEntity`)
- **Repositories**: XxxxRepository (interface), XxxxRepositoryImpl (implementation)

#### Formatting
- Use 4-space indentation
- Max line length: 120 characters
- Place opening brace on same line
- Use trailing lambdas for higher-order functions
- Break long parameter lists with one parameter per line

#### Types
- Use `val` for immutable properties (prefer immutability)
- Use `Long` for timestamps (milliseconds)
- Use `Flow<T>` for reactive data streams
- Use `StateFlow<T>` for UI state
- Mark nullable types explicitly with `?`

#### Compose UI
- Use `@Composable` annotation
- Use `@HiltViewModel` for ViewModels
- State flows: `val uiState by viewModel.uiState.collectAsState()`
- Private composables for internal components
- Use Material3 components

#### Dependency Injection (Hilt)
- Use `@Inject constructor()` for constructor injection
- Use `@Module` + `@Provides` for providing dependencies
- Use `@Singleton` for single-instance dependencies

#### Error Handling
- Use `Result<T>` for operations that can fail
- Handle null values with safe calls (`?.`) or elvis operator (`?:`)

### iOS (Swift)

#### Imports
- Import frameworks at top of file
- Order: Foundation → SwiftUI → Third-party → Local

#### Naming Conventions
- **Structs/Classes**: PascalCase (`HomeView`, `StudySession`)
- **Functions**: camelCase (`loadData`, `getDaysRemaining`)
- **Properties**: camelCase (`todayStudyMinutes`, `weeklyGoal`)
- **ViewModels**: XxxxViewModel (`HomeViewModel`)

#### Formatting
- Use 4-space indentation
- Place opening brace on same line
- Use trailing closure syntax for SwiftUI modifiers

#### Types
- Use `struct` for value types (models, views)
- Use `class` for ViewModels (with `@MainActor` and `ObservableObject`)
- Use `UUID` for identifiers
- Use `Date` for timestamps
- Use `TimeInterval` for durations

#### SwiftUI
- Use `@StateObject` for ViewModel ownership
- Use `@Published` for observable state
- Use `@ViewBuilder` for complex view builders
- Prefer `VStack`, `HStack`, `ZStack` for layouts

#### Error Handling
- Use `guard` for early returns
- Use `if let` or `guard let` for optional binding
- Handle errors with `do-catch` when necessary

## Platform Parity

Both platforms should implement the same features:
- Home screen with today's study summary
- Timer for study sessions
- Materials management
- Calendar view
- Reports with charts
- Goals tracking
- Exam scheduling

## Database

- **Android**: Room database (`StudyDatabase`)
- **iOS**: Core Data with `PersistenceController`
- **Cloud sync**: Firebase Authentication + Cloud Firestore are used for opt-in cloud sync.

Local storage remains the source of truth on device, and signed-in users can opt into Firebase-backed sync.

## Firebase Sync Notes

- Firebase project alias: `genshitekiapp`
- Firestore rules live in `firestore.rules`
- Firebase CLI config lives in `firebase.json` and `.firebaserc`
- Mobile app config files are intentionally **not** committed:
  - `android/app/google-services.json`
  - `ios/StudyApp/Resources/GoogleService-Info.plist`
- A fresh clone or CI environment must provision those files separately before running Firebase-backed builds

## Color Scheme

Primary color: Green (#4CAF50)
Secondary color: Blue (#2196F3)
Accent color: Orange (#FF9800)

## Testing Strategy

When tests are added:
- Unit tests for ViewModels and business logic
- Repository tests for data layer
- UI tests for critical user flows
- Test files mirror source file structure
