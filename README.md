# StudyApp（学習記録）

学習時間を記録・管理・分析するクロスプラットフォーム（Android / iOS）アプリです。タイマーで学習時間を計測し、教材・科目ごとに進捗を管理。レポートやカレンダーで学習パターンを可視化し、目標設定やテスト管理も可能です。Firebaseによるクラウド同期にも対応しています。

## スクリーンショット

<!-- 画像を screenshots/ ディレクトリに配置してください -->

| ホーム | タイマー | レポート |
|:---:|:---:|:---:|
| ![ホーム画面](screenshots/home.png) | ![タイマー画面](screenshots/timer.png) | ![レポート画面](screenshots/reports.png) |

## 主な機能

- **学習タイマー** — ストップウォッチ / カウントダウンの2モード。バックグラウンド動作対応（Android）
- **教材管理** — 教科書・問題集の登録、ページ進捗、問題ごとの正誤記録、ISBNバーコードスキャンで自動メタデータ取得
- **科目管理** — カラーコーディング、13種類のアイコン
- **カレンダー** — 月間カレンダーにヒートマップ表示で学習量を可視化
- **レポート・分析** — 日別 / 週別 / 月別の学習時間内訳、科目別分析、連続学習日数
- **目標設定** — 曜日ごとの学習時間目標、進捗リングで達成率を表示
- **テスト管理** — テスト日の登録、カウントダウン表示、緊急度バッジ
- **学習計画** — 週間計画の作成、実績時間の自動集計、達成率トラッキング
- **ホームダッシュボード** — 今日のサマリー、週間目標進捗、直近のテスト・教材を一覧表示
- **Firebase クラウド同期** — メール / パスワード認証、Firestore によるデータ同期
- **ウィジェット** — Android 6種 + iOS WidgetKit によるホーム画面ウィジェット
- **ダークモード** — ライト / ダーク / システム設定に追従
- **テーマカラー** — 複数のカラーテーマから選択可能
- **データエクスポート** — JSON / CSV 形式でデータを書き出し
- **オンボーディング** — 初回起動時の機能紹介フロー

### Android 独自機能

- **AnkiDroid 連携** — AnkiDroid の学習データ（カード数、学習時間）をアプリに取り込み
- **6種のウィジェット** — 今日の学習、週間目標、連続日数、テストカウントダウン、週間アクティビティ、スタック学習（Glance ベース）
- **バーコードスキャン** — CameraX + ML Kit による ISBN スキャン
- **フォアグラウンドサービス** — アプリをバックグラウンドにしてもタイマーが継続

### iOS 独自機能

- **Live Activity**（iOS 18+）— ロック画面 / Dynamic Island にタイマーを表示。4種の表示プリセット
- **WidgetKit ウィジェット** — タイムラインベースのウィジェット

## 技術スタック

### Android

| 項目 | 技術 |
|---|---|
| 言語 | Kotlin 1.9.22 |
| UI | Jetpack Compose (Material3) |
| アーキテクチャ | MVVM + Clean Architecture |
| DI | Hilt 2.50 |
| データベース | Room 2.6.1（スキーマ v7） |
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
| アーキテクチャ | MVVM + Clean Architecture |
| データベース | Core Data（プログラムマチックモデル） |
| クラウド | Firebase Auth + Firestore (SPM) |
| ウィジェット | WidgetKit |
| Live Activity | ActivityKit（iOS 18+） |
| 通知 | UserNotifications |

## ディレクトリ構成

```
gaien/
├── android/                          # Android アプリ
│   └── app/src/main/java/com/studyapp/
│       ├── data/                     # データ層（Room DB、リポジトリ実装、サービス）
│       ├── di/                       # Hilt 依存性注入モジュール
│       ├── domain/                   # ドメイン層（モデル、リポジトリインターフェース、ユースケース）
│       ├── presentation/             # プレゼンテーション層（Compose 画面、ViewModel）
│       ├── services/                 # リマインダーサービス（WorkManager）
│       ├── sync/                     # Firebase 同期
│       └── widgets/                  # Glance ウィジェット
├── ios/
│   └── StudyApp/
│       ├── Data/                     # データ層（Core Data、Firebase リポジトリ）
│       ├── Domain/                   # ドメイン層（エンティティ、リポジトリプロトコル、ユースケース）
│       ├── Presentation/             # プレゼンテーション層（SwiftUI ビュー、ViewModel）
│       ├── Services/                 # サービス層（通知、Live Activity）
│       └── Widgets/                  # WidgetKit ウィジェット
├── StudyAppWidgets/                  # iOS ウィジェットエクステンション
├── firestore.rules                   # Firestore セキュリティルール
└── AGENTS.md                         # 開発者ガイド
```

## ビルド方法

### Android

```bash
# 前提条件: JDK 17、Android SDK (API 34)

# デバッグビルド
cd android && ./gradlew assembleDebug

# リリースビルド（署名用の環境変数が必要）
cd android && ./gradlew assembleRelease

# リント
cd android && ./gradlew lint
```

リリースビルド時に必要な環境変数:

| 変数名 | 説明 |
|---|---|
| `KEYSTORE_FILE` | リリースキーストアのパス |
| `KEYSTORE_PASSWORD` | キーストアのパスワード |
| `KEY_ALIAS` | キーエイリアス |
| `KEY_PASSWORD` | キーのパスワード |

### iOS

```bash
# Xcode で開く
open ios/StudyApp.xcodeproj

# コマンドラインでビルド
xcodebuild -project ios/StudyApp.xcodeproj -scheme StudyApp -sdk iphoneos -configuration Release
```

### Firebase 設定

Firebase 設定ファイルはリポジトリに含まれていません。ビルド前にそれぞれ配置してください。

| ファイル | プラットフォーム | 配置先 |
|---|---|---|
| `google-services.json` | Android | `android/app/` |
| `GoogleService-Info.plist` | iOS | `ios/StudyApp/Resources/` |

Firebase コンソールからダウンロードするか、CI 環境では GitHub Secrets（`IOS_GOOGLE_SERVICE_INFO_PLIST_B64`）を使用してください。

## テスト実行方法

### Android

```bash
# 全テスト実行
cd android && ./gradlew test

# 特定のテストクラスを実行
cd android && ./gradlew test --tests "com.studyapp.presentation.home.HomeViewModelTest"

# テストカバレッジレポート
cd android && ./gradlew testDebugUnitTestCoverage
```

### iOS

Xcode で `Cmd + U`、または Product > Test を実行してください。

## ライセンス

未定です。
