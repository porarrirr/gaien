# StudyApp（学習記録）

学習時間を記録・管理・分析するクロスプラットフォームアプリです（Android / iOS）。タイマーで学習時間を計測し、教材・科目ごとに進捗を管理。レポートやカレンダー、時間割で学習パターンを可視化し、目標設定やテスト管理も行えます。Firebase によるクラウド同期とアカウント削除に対応しています。

同リポジトリには macOS 向けローカルコンパニオン（`macos/StudyAppMac`）と GitHub Pages 用サイト（`docs/`）も含まれます。

## スクリーンショット

`screenshots/` に画像を置くと表示されます（開発用のため `.gitignore` 対象）。

| ホーム | タイマー | レポート |
|:---:|:---:|:---:|
| ![ホーム画面](screenshots/home.png) | ![タイマー画面](screenshots/timer.png) | ![レポート画面](screenshots/reports.png) |

## 主な機能

- **学習タイマー** — ストップウォッチ / カウントダウン。問題進捗・セッション評価・手動記録に対応
- **教材管理** — 教科書・問題集の登録、ページ進捗、問題ごとの正誤記録、ISBN バーコードスキャン（Google Books）
- **科目管理** — カラーコーディング、複数アイコン
- **カレンダー** — 月間カレンダーとヒートマップ、タイムライン表示
- **時間割** — 学期・コマ・授業の登録、復習期限の管理、期限超過リマインダー
- **レポート・分析** — 日別 / 週別 / 月別の学習時間、科目別分析、連続学習日数
- **目標設定** — 曜日ごとの学習時間目標と進捗リング
- **テスト管理** — テスト日の登録、カウントダウン、緊急度表示
- **学習計画** — 週間計画、実績時間の自動集計、達成率
- **ホームダッシュボード** — 今日のサマリー、週間目標、直近のテスト・教材
- **Firebase クラウド同期** — メール / パスワード認証、Firestore 差分同期、アカウント削除
- **ウィジェット** — Android 6 種（Glance）+ iOS WidgetKit
- **ダークモード / テーマカラー** — ライト・ダーク・システム追従、複数テーマ
- **データエクスポート** — JSON / CSV

> 初回起動のオンボーディング画面は廃止済みです（設定フラグ `onboardingCompleted` はデータ互換のため残存）。

### Android 独自

- **6 種のホーム画面ウィジェット** — 今日の学習、週間目標、連続日数、テストカウントダウン、週間アクティビティ、スタック学習
- **バーコードスキャン** — CameraX + ML Kit による ISBN スキャン
- **フォアグラウンドサービス** — バックグラウンドでもタイマー継続

### iOS 独自

- **Live Activity** — ロック画面 / Dynamic Island にタイマー表示（ビルド設定で ON/OFF 可能）
- **WidgetKit** — App Group 経由のスナップショット連携
- **Screen Time 集中モード** — Family Controls + Device Activity で許可アプリ以外を制限（`StudyAppDeviceActivityMonitor` 拡張）
- **iPad 向け UI** — `NavigationSplitView` によるサイドバー + 詳細の分割表示
- **ランドスケープタイマー** — 問題進捗専用 / 時計のみの集中レイアウト

### macOS コンパニオン（実験的）

`macos/StudyAppMac` は Firebase 非連携のデスクトップ用アプリです。ダッシュボード・タイマー・科目 / 教材管理をローカル JSON（`~/Library/Application Support/StudyAppMac/study-data.json`）に保存します。本番アプリとデータは共有しません。

## 技術スタック

### Android

| 項目 | 技術 |
|---|---|
| 言語 | Kotlin 1.9.22 |
| UI | Jetpack Compose (Material3) |
| アーキテクチャ | MVVM + Clean Architecture |
| DI | Hilt 2.50 |
| データベース | Room 2.6.1（スキーマ version **12**） |
| ナビゲーション | Navigation Compose 2.7.6 |
| 非同期 | Kotlin Coroutines + Flow |
| シリアライズ | Kotlinx Serialization |
| 設定保存 | DataStore |
| チャート | MPAndroidChart 3.1.0 |
| カレンダー | Kizitonwose Calendar Compose 2.4.1 |
| ウィジェット | Jetpack Glance 1.0.0 |
| カメラ | CameraX 1.3.1 + ML Kit Barcode 17.2.0 |
| クラウド | Firebase Auth + Firestore BOM 33.6.0 |
| 対応バージョン | minSdk 26 / targetSdk 34 |

### iOS

| 項目 | 技術 |
|---|---|
| 言語 | Swift |
| UI | SwiftUI |
| アーキテクチャ | MVVM + Clean Architecture（`StudyAppContainer` が composition root） |
| データベース | Core Data（プログラムマチックモデル） |
| 同期 | Firestore 差分同期（`Data/Sync/`） |
| クラウド | Firebase Auth + Firestore (SPM) |
| ウィジェット | WidgetKit（App Group: `group.com.studyapp.ios.shared`） |
| Live Activity | ActivityKit |
| 集中モード | Family Controls, Device Activity, Managed Settings |
| 通知 | UserNotifications |
| 対応バージョン | iOS **16.0** 以降（Bundle ID 例: `com.studyapp.ios`） |

### リポジトリその他

| 項目 | 内容 |
|---|---|
| CI | GitHub Actions（iOS ビルドチェック、未署名 IPA リリース） |
| 公開サイト | `docs/`（GitHub Pages: 製品紹介・プライバシー・サポート） |
| Firestore ルール | `firestore.rules` |
| エージェント向けガイド | [AGENTS.md](AGENTS.md) |

## ディレクトリ構成

```
gaien/
├── android/                          # Android アプリ
│   └── app/src/main/java/com/studyapp/
│       ├── data/                     # Room、リポジトリ実装
│       ├── di/                       # Hilt
│       ├── domain/                   # モデル、リポジトリ IF、ユースケース
│       ├── presentation/             # Compose 画面、ViewModel
│       ├── services/                 # リマインダー（WorkManager）
│       ├── sync/                     # Firebase 同期
│       └── widgets/                  # Glance ウィジェット
│   └── app/schemas/                  # Room スキーマスナップショット
├── ios/
│   ├── StudyApp/                     # SwiftUI 本体
│   │   ├── Data/                     # Core Data、Firebase、Sync/
│   │   ├── Domain/
│   │   ├── Presentation/             # StudyAppContainer 含む
│   │   ├── Services/                 # Live Activity、Screen Time、通知
│   │   └── Widgets/                  # スナップショット同期
│   ├── StudyAppWidgets/             # WidgetKit + Live Activity
│   ├── StudyAppDeviceActivityMonitor/  # Screen Time 拡張
│   └── StudyAppTests/                # XCTest
├── macos/StudyAppMac/                # macOS コンパニオン（SwiftPM）
├── docs/                             # GitHub Pages
├── tools/                            # 開発用スクリプト
├── .github/workflows/                # iOS CI / リリース
├── firestore.rules
├── firebase.json
├── AGENTS.md
└── README.md
```

## ビルド方法

### Android

```bash
# 前提: JDK 17、Android SDK (API 34)

cd android && ./gradlew assembleDebug    # デバッグ APK
cd android && ./gradlew assembleRelease  # リリース（署名設定が必要）
cd android && ./gradlew lint
```

リリース署名用の環境変数:

| 変数名 | 説明 |
|---|---|
| `KEYSTORE_FILE` | リリースキーストアのパス |
| `KEYSTORE_PASSWORD` | キーストアのパスワード |
| `KEY_ALIAS` | キーエイリアス |
| `KEY_PASSWORD` | キーのパスワード |

Windows では `gradlew.bat` を使用してください。

### iOS

```bash
open ios/StudyApp.xcodeproj

# コマンドライン（Release / 実機向け）
xcodebuild -project ios/StudyApp.xcodeproj -scheme StudyApp \
  -sdk iphoneos -configuration Release build

# 未署名 Debug（CI と同様）
xcodebuild -project ios/StudyApp.xcodeproj -scheme StudyApp \
  -configuration Debug -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO build
```

Screen Time・ウィジェット・Live Activity を使うビルドでは、Apple Developer の App Group と Family Controls  capability が必要です。

タグ `v*` の push または GitHub Release では、`.github/workflows/ios-ipa-release.yml` が未署名 IPA を生成します（Live Activity 無効ビルド。拡張は IPA から除去）。

### macOS コンパニオン

```bash
cd macos/StudyAppMac
swift build
./scripts/build_and_run.sh          # 起動
./scripts/build_and_run.sh --verify # ビルド検証のみ
```

### Firebase 設定

Firebase のアプリ設定ファイルはリポジトリに含めません。ビルド前に配置してください。

| ファイル | プラットフォーム | 配置先 |
|---|---|---|
| `google-services.json` | Android | `android/app/` |
| `GoogleService-Info.plist` | iOS | `ios/StudyApp/Resources/` |

- ローカル: Firebase コンソールからダウンロード
- CI（iOS）: Secret `IOS_GOOGLE_SERVICE_INFO_PLIST_B64`、または workflow 内のプレースホルダ plist（未署名ビルド用）

Firestore ルールのデプロイ:

```bash
firebase deploy --only firestore:rules
```

## テスト

### Android

```bash
cd android && ./gradlew test

# 特定クラスのみ
cd android && ./gradlew test --tests "com.studyapp.presentation.home.HomeViewModelTest"

# カバレッジ（Debug 単体テスト）
cd android && ./gradlew testDebugUnitTestCoverage
```

### iOS

Xcode で `Cmd + U`、または:

```bash
xcodebuild -project ios/StudyApp.xcodeproj -scheme StudyApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  SWIFT_ENABLE_EXPLICIT_MODULES=NO \
  test
```

`ios/StudyAppTests/` には同期マージ、復習スケジューラ、タイマー検証、ウィジェット計算などのテストがあります。

## CI

| Workflow | トリガー | 内容 |
|---|---|---|
| [ios-build-check.yml](.github/workflows/ios-build-check.yml) | `main` への PR、`refactor/**` push | 未署名 Debug ビルド + シミュレータ単体テスト |
| [ios-ipa-release.yml](.github/workflows/ios-ipa-release.yml) | タグ `v*`、Release、手動 | 未署名 Release IPA を GitHub Release に添付 |

Android 用の GitHub Actions は現時点ではありません。

## 開発者向け

コーディングエージェントや共同開発者向けの詳細（アーキテクチャの注意点、CI の扱い、変更時のスコープ）は [AGENTS.md](AGENTS.md) を参照してください。

## ライセンス

未定です。
