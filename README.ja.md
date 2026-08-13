# StudyApp

[English](README.md) | 日本語

Android・iOS向けの学習記録アプリです。タイマー、教材進捗、時間割、目標、テスト、レポートをまとめ、学習時間だけでなく「何を学び、次に何へ取り組むべきか」まで把握できるようにします。

## 主な機能

- ストップウォッチ、カウントダウン、手動記録
- 科目・教材の管理とページ・問題進捗
- カレンダー、ヒートマップ、日別タイムライン、時間割
- 科目別の日・週・月レポート
- 連続学習日数、目標、テストカウントダウン、週間計画
- JSON・CSVエクスポート
- Androidのホーム画面ウィジェットとバックグラウンドタイマー
- iOSのウィジェット、Live Activity、iPad表示、横画面集中ビュー
- 学習実績とアプリ利用制限を結び付ける任意のiOS Screen Time機能
- Firebaseによるアカウント同期とアプリ内アカウント削除

## 対応プラットフォーム

- Android 8.0以降（`minSdk 26`）
- iOS 16以降
- `macos/StudyAppMac` に実験的なローカル専用macOSコンパニオンを含みます。モバイル版とはデータを共有しません。

iOSのScreen Time機能には、AppleのFamily Controls承認、App Group、署名済みの実機・配布ビルドが必要です。未署名のCI成果物ではScreen Time拡張を利用できません。

## データとプライバシー

設定した場合、モバイル版はFirebase AuthenticationとFirestoreを使って学習データを同期します。Firebase設定ファイルはリポジトリに含まれません。アプリ内からアカウントを削除できます。macOSコンパニオンのデータは別にローカル保存されます。

## ビルド

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

クラウド同期や保護されたApple機能を使うには、Firebase設定とプラットフォーム固有の署名設定が必要です。

## ライセンス

独自コードはプロプライエタリで、すべての権利を留保します。詳細は [LICENSE](LICENSE) を参照してください。第三者コンポーネントには個別のライセンスが適用されます。詳細は [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) を参照してください。
