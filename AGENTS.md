# Repository Guidelines

StudyApp（学習記録）のモノレポ。Android / iOS が本番アプリ。macOS コンパニオン・GitHub Pages・Firebase 設定も同じリポジトリで管理する。人向けの概要は [README.md](README.md)。

## Project Structure

```
gaien/
├── android/                 # Kotlin + Jetpack Compose
│   └── app/src/main/java/com/studyapp/
│       ├── data/            # Room, repository impl, Google Books など
│       ├── di/              # Hilt
│       ├── domain/          # models, repository interfaces, use cases
│       ├── presentation/    # Compose screens, ViewModels
│       ├── services/        # ReminderService (WorkManager)
│       ├── sync/            # Firebase Auth / Firestore 同期
│       └── widgets/         # Glance ウィジェット
│   └── app/src/test/        # JVM 単体テスト
│   └── app/schemas/         # Room スキーマスナップショット（現在 DB version 12）
├── ios/
│   ├── StudyApp/            # SwiftUI 本体
│   │   ├── Data/            # Core Data, Firebase, Sync/（差分同期エンジン）
│   │   ├── Domain/          # models, protocols, use cases, Scheduling/
│   │   ├── Presentation/    # views, ViewModels, StudyAppContainer（DI ルート）
│   │   ├── Services/        # Live Activity, Screen Time, 通知, ログ
│   │   ├── Widgets/         # App Group 向けウィジェットスナップショット
│   │   └── Resources/
│   ├── StudyAppWidgets/     # WidgetKit + Live Activity
│   ├── StudyAppDeviceActivityMonitor/  # Screen Time (DeviceActivity) 拡張
│   └── StudyAppTests/       # XCTest（純粋ロジック中心）
├── macos/StudyAppMac/       # デスクトップ用 SwiftPM コンパニオン（ローカル JSON のみ）
├── docs/                    # GitHub Pages（index / privacy / support）
├── tools/                   # 開発用スクリプト（アイコン生成など）
├── firestore.rules
├── firebase.json
└── .github/workflows/       # iOS ビルド CI / 未署名 IPA リリース
```

### iOS ターゲットと共有

| ターゲット | 役割 |
|---|---|
| `StudyApp` | メインアプリ。`StudyAppContainer` がリポジトリ・同期・ウィジェット更新を束ねる |
| `StudyAppWidgets` | WidgetKit、Live Activity（`ActivityKit`） |
| `StudyAppDeviceActivityMonitor` | タイマー集中モード用 Device Activity 拡張 |
| `StudyAppTests` | 同期・スケジューラ・バリデーションなどの単体テスト |

App Group: `group.com.studyapp.ios.shared`（ウィジェット・Screen Time・スナップショット共有）。Bundle ID 例: `com.studyapp.ios`。

### macOS コンパニオン

`macos/StudyAppMac/` は Firebase 非連携のローカル JSON アプリ。本番データモデルと完全同期ではない。変更時は `swift build` と `scripts/build_and_run.sh --verify` で確認。

## Build & Test

リポジトリルートから実行。macOS / Linux では `./gradlew`、Windows では `gradlew.bat`。

### Android

```bash
cd android && ./gradlew assembleDebug   # デバッグ APK
cd android && ./gradlew test            # JVM 単体テスト
cd android && ./gradlew lint
```

前提: JDK 17、Android SDK。`android/app/google-services.json` はリポジトリ外（`.gitignore`）。リリース署名は `KEYSTORE_*` 環境変数（README 参照）。

### iOS

```bash
open ios/StudyApp.xcodeproj

# 未署名ビルド（CI と同様）
xcodebuild \
  -project ios/StudyApp.xcodeproj \
  -scheme StudyApp \
  -configuration Debug \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  build

# 単体テスト（シミュレータ。Xcode 26 以降は明示モジュール無効化を推奨）
xcodebuild \
  -project ios/StudyApp.xcodeproj \
  -scheme StudyApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  test
```

`ios/StudyApp/Resources/GoogleService-Info.plist` もリポジトリ外。ローカル・CI ではプレースホルダ plist を生成してビルドする（`.github/workflows/ios-build-check.yml` 参照）。本番相当の設定は GitHub Secret `IOS_GOOGLE_SERVICE_INFO_PLIST_B64` を IPA リリース workflow で使用。

未署名 IPA の配布は **既存** `.github/workflows/ios-ipa-release.yml` のみ使う。タグ `v*` または Release 公開で、Live Activity 無効版をアップロード（拡張は IPA から除去）。

### macOS コンパニオン

```bash
cd macos/StudyAppMac && swift build
./scripts/build_and_run.sh --verify
```

## Architecture Notes

- **共通**: MVVM + Clean Architecture。ドメイン層にビジネスルール、データ層に永続化・Firebase、プレゼン層に UI。
- **Android DI**: Hilt（`di/AppModule.kt`）。同期は `sync/` パッケージ（`AutoSyncManager`, `FirebaseSyncRepository` など）。
- **iOS DI**: `StudyAppContainer` が composition root。ViewModel は `container.subjectRepo` など **protocol 型**のリポジトリを受け取る（テスト容易性のため）。
- **同期**: Firestore 差分同期。iOS は `Data/Sync/`（`SyncMergeEngine`, `SyncDeltaSerializer`, `FirestoreDeltaSyncStore`）。Android は `sync/` パッケージ。
- **オンボーディング**: 初回フロー画面は削除済みだが、`AppPreferences.onboardingCompleted` と関連コードは残存。新規 UI を足すときは既存フラグとの整合を確認。
- **タイマー周辺（iOS）**: Live Activity、ランドスケープ専用ビュー、Screen Time 集中モード（Family Controls + Device Activity）。天気・WeatherKit 連携は削除済み—復活させない。
- **時間割**: Android / iOS 双方に `Timetable` 機能あり。

## Coding Conventions

- **Kotlin**: 4 スペース、`PascalCase` 型、`camelCase` メンバー、`com.studyapp` パッケージ。Compose は `presentation/`、Room/Firebase は `data/` / `sync/`。
- **Swift**: 4 スペース、型は `PascalCase`、ファイルは可能なら 1 型中心。SwiftUI / ViewModel は `Presentation/`、Core Data・Firebase・同期は `Data/`、モデル・ユースケースは `Domain/`。
- **テスト追加**: 意味のある純粋ロジックに限定。Android は `*Test.kt`（JUnit, MockK, coroutines-test, Turbine）。iOS は `ios/StudyAppTests/` に XCTest を追加し、macOS で `xcodebuild test` を回せない場合は静的レビューのみと明記。
- **UI 厳密モック**: iOS の画面対応表は `ios/StudyApp/Presentation/UI_TARGET_MAPPING.md`。

## CI

| Workflow | トリガー | 内容 |
|---|---|---|
| `ios-build-check.yml` | `main` への PR、`refactor/**` push | 未署名 Debug ビルド + シミュレータ単体テスト |
| `ios-ipa-release.yml` | タグ `v*`、Release、手動 | 未署名 Release IPA を GitHub Release に添付 |

Android 用 GitHub Actions は現状なし。Android 変更後はローカルで `test` / `lint` を実行すること。

## Firebase & Deploy

- ルールのみリポジトリ管理: `firestore.rules`（`firebase deploy --only firestore:rules`）。
- `google-services.json` / `GoogleService-Info.plist` はコミットしない。
- マーケティング・法務ページ: `docs/` → GitHub Pages。

## Commit & Pull Request

- コミットメッセージ: 短い英語の命令形（例: `Refine iOS study views`, `Fix iOS build regressions`, `Remove first-launch onboarding screens`）。プラットフォームまたは機能単位でまとめる。
- PR: ユーザーに見える変更、DB マイグレーション、Firebase/権限/entitlements の要否、UI スクショを記載。
- **コミットはユーザーが明示したときだけ**作成する。

## Agent-Specific Instructions

1. **正しい経路を使う**: 既知の API・workflow がある場合、連鎖フォールバックや「とりあえず動く」代替実装を足さない。失敗時は理由をはっきり出す。
2. **Git の安全確認**: 操作前に `git rev-parse --show-toplevel` を実行し、想定外のワークツリー（別マシンのミラーや `C:\Users\nmrhr` など）なら停止する。このリポジトリの正しいルートは `gaien` ディレクトリ（例: `/Users/porari/kaihatu/ios/gaien`）。
3. **設定ファイル**: Firebase の実設定をリポジトリにコミットしない。CI 用プレースホルダ生成ロジックを複製するより、既存 workflow を参照・再利用する。
4. **iOS リリース**: 未署名 IPA 用の独自スクリプトや workflow を増やさない。Live Activity 無効ビルドの扱いは `ios-ipa-release.yml` に合わせる。
5. **スコープ**: 依頼されていないプラットフォームや macOS コンパニオンまで広げない。クロスプラットフォームで挙動を揃える必要があるときだけ両方触る。
6. **検証**: iOS を変更したら可能なら `xcodebuild`（上記フラグ含む）。Android なら `./gradlew test`。実行できなかった環境ではその旨を返答に書く。
