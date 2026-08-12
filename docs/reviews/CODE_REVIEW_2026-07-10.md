# StudyApp 全体コードレビュー結果(2026-07-10)

- 対象: `ios/`(本体・Widget・DeviceActivity拡張)+ `android/app/src/main/` + `firestore.rules`
- 観点: セキュリティ / 導線 / UIバグ / バグ / 日時関連バグ
- 方法: 静的レビュー(全指摘はコード実引用に基づく。推測のみのものは「要確認」と明記)

**総評**: セキュリティは堅牢で重大な問題なし。一方で同期エンジンに、既存ユーザーのデータ整合性に関わる「高」2件(競合解決が他端末に伝わらない/教材削除で他端末の同期が恒久的に止まる)がある。

---

## 高(同期・データ整合性)

### 1. [高][バグ] 競合解決の結果がクラウドに一切アップロードされない(両OS)

- iOS: `ios/StudyApp/Data/FirebaseSyncRepository.swift:461` / Android: `android/app/src/main/java/com/studyapp/sync/FirebaseSyncRepository.kt:287`
- **再現**: 端末Aで同期競合が発生 → 設定の「競合を解決」で解決 → `resolveConflicts` が **baseShadow を解決後データで保存してから** `syncNow()` を呼ぶ。syncNow のアップロード対象は `changedComparedTo(ローカル, baseShadow)` の差分だが、両者が同一になるため**送信対象ゼロ**。端末Bは旧値のまま永久に分岐し、「解決したはずの競合」が実際には解決されない。
- **修正方針**: baseShadow の保存を syncNow 完了後に回すか、解決前の base を渡して差分検出させる。

### 2. [高][バグ] 問題記録つき教材/科目を削除すると、他の全端末の同期が恒久ブロック

- ガード: iOS `ios/StudyApp/Data/FirebaseSyncRepository.swift:680-698` / Android `FirebaseSyncRepository.kt:80,424`
- 削除カスケード: iOS `ios/StudyApp/Data/PersistenceController.swift:192-213, 322-330` / Android `data/repository/MaterialRepositoryImpl.kt:94-101`
- **再現**: 端末Bで問題記録(problemReviewRecords)を持つ教材を削除 → 復習記録が連鎖 tombstone → クラウドへ伝播 → 端末Aの syncNow はマージ後に `activeProblemReviewRecords` が減るため `ensureNoProblemProgressLoss` が**毎回例外を投げ、サーバーカーソルも進まない**。端末Aは「同期により問題集の進捗履歴が大きく減少するため停止しました」が出続け、同期不能のまま。回避的に「ローカルデータをアップロード」すると今度は削除が巻き戻る。
- **修正方針**: リモート由来の正規の tombstone による減少はガードの対象外にする(ガードは「ペイロード欠落・デコード失敗による消失」検出に限定する)。

### 3. [中][バグ] ページ数・問題数を「減らす」修正が同期のたびに巻き戻る(両OS)

- iOS `ios/StudyApp/Data/Sync/SyncThreeWayMergeEngine.swift:134-136,183` / Android `sync/SyncThreeWayMergeEngine.kt:154-156`
- currentPage / totalPages / totalProblems / wrongProblemCount を `max(local, remote, base)` でマージしているため、誤入力の訂正(500→50ページ等)が **base まで比較対象に入っている以上、絶対に伝播しない**。他端末が同期すると旧最大値が復活する。
- **修正方針**: base がある場合は「baseから変化した側」を採用する通常の3-wayに。単調増加は base 無しのフォールバック時のみに限定。

---

## 中(日時・クロスプラットフォーム不整合)

### 4. [中][日時] Android週間レポートの週区切りが日本ロケールで壊れている

- `android/app/src/main/java/com/studyapp/domain/usecase/GetReportsDataUseCase.kt:96-98`
- `localDate.with(WeekFields.of(locale).firstDayOfWeek)` は「同じISO週(月〜日)内のその曜日」へ動く TemporalAdjuster。日本(週始まり=日曜)では**水曜→次の日曜**になり、weekStart が未来日付になる。結果、日曜の学習だけが独立した週になり、月〜土は「次の日曜」ラベルの週に集計される。ホーム画面の `Clock.startOfWeek()`(java.util.Calendar、こちらは正しい)とも不一致。
- **修正方針**: `localDate.with(TemporalAdjusters.previousOrSame(firstDayOfWeek))` に変更。

### 5. [中][日時] iOSウィジェットが日付を跨いでも前日の値を表示し続ける

- `ios/StudyAppWidgets/StudyAppWidgets.swift:18-23` + `ios/StudyApp/Widgets/WidgetSnapshotSync.swift`
- スナップショット(今日の学習時間・ストリーク・試験までの残日数)は**アプリ側で焼き込み**で、ウィジェットは30分ごとに同じファイルを再表示するだけ。0時を過ぎてもアプリを開くまで「今日の学習 120分」等が前日の値のまま。Androidは表示ごとにDBから再計算しており、この問題はない。
- **修正方針**: 少なくとも generatedAt が今日でなければ today系をゼロ表示に。試験残日数は `epochDay` を持っているのでウィジェット側で計算可能。

### 6. [中][バグ] iOSの書籍検索クエリが二重パーセントエンコードされ、日本語タイトル検索が壊れる

- `ios/StudyApp/Data/GoogleBooksService.swift:135,179`
- `addingPercentEncoding` で事前エンコードした文字列を `URLQueryItem` に渡すため `%` が再エンコードされ、`intitle:%25E6...` のような壊れたクエリになる(日本語・記号を含む検索が不正/0件)。加えて `normalizeLookupToken`(:266)がタイトルからも空白を全除去するため複数語検索が劣化。Androidは生文字列を `addQueryParameter` に渡しており正常 → iOSのみの退行。
- **修正方針**: 事前エンコードをやめて URLComponents に任せる。空白除去は ISBN のみに。

### 7. [中][UIバグ] ストリークの定義が画面ごとに食い違う

- iOSレポート `ios/StudyApp/Domain/UseCases/GetReportsDataUseCase.swift:173-186` は「今日未学習でも昨日までの連続を維持」。iOSウィジェット `StudyWidgetSnapshotComputer.swift:126-134`、Androidレポート・ウィジェットは「今日未学習なら0」。同じ瞬間にアプリ=N日 / ウィジェット=0日と表示が割れる。どちらかの定義に統一を。

### 8. [中][日時] `Goal.weekStartDay` が全プラットフォームで無視されている

- iOS `ios/StudyApp/Domain/UseCases/Clock.swift:18-22`・`StudyWidgetSnapshotComputer.swift:56` / Android `domain/util/Clock.kt:41`
- 週間目標の集計窓はロケール既定(日本=日曜始まり)で、モデル・同期フォーマット・DBに存在する `weekStartDay`(既定=月曜)は一切参照されない。現状UIから設定できないため実害は「フィールドが死んでいる」ことだが、月曜始まりを意図したデータと日曜始まりの集計が既に食い違っている。仕様としてどちらかに確定させて片方を消すべき。

### 9. [中][バグ][要確認] レガシー日次目標の展開IDが両OSで異なり、重複目標が発生しうる

- Android `data/local/db/Migrations.kt` MIGRATION_4_5 は `syncId-1..7`、iOS `ios/StudyApp/Data/LegacyDailyGoalNormalizer.swift:41` は `syncId-monday..sunday` に展開。両OSを併用していたレガシーユーザーは同じ曜日の目標が2重化する。さらに Android は `UNIQUE(type, dayOfWeek, isActive)` + `REPLACE` 挿入(`GoalDao.kt:28`)のため、同期インポート時に重複目標の片方が **tombstoneなしで無言に消え**、クラウド/iOSとの永続差異になる。該当ユーザーが実在するかは Firestore の実データ確認が必要。

---

## 低

- [低][日時] iOSレポートの月次集計が `startTime <= interval.end` のため、月境界0:00:00.000ちょうど開始のセッションが両月に二重計上(`GetReportsDataUseCase.swift:95,112`)。
- [低][日時] Android週次/月次のフェッチ窓が `now-12*7日`/`now-6*30日` 固定幅で、表示上最古の週・月が過少集計(`GetReportsDataUseCase.kt:88-90,111`)。
- [低][時間] Androidのデイリーリマインダーが `PeriodicWorkRequest` なので通知時刻がドリフトする。`ExistingPeriodicWorkPolicy.UPDATE` での時刻変更の反映タイミングも要確認(`services/ReminderWorker.kt:141-170`)。時間割復習通知は iOS=毎日20時/Android=データ変更時に即時、と挙動不一致。
- [低][時間] iOSの時間割復習リマインダーはスケジュール時点の件数を毎日20時の繰り返し通知に焼き込むため、アプリを開かないと古い件数を通知し続ける(`ios/StudyApp/Services/ReminderScheduler.swift:43-63`)。
- [低][バグ] `ios/StudyApp/Data/TimetableOverdueCalculator.swift:49` で termId が nil のエントリが**アクティブな全学期に重複カウント**され、複数学期が同時アクティブだと未復習件数が水増しされる。
- [低][バグ] カウントダウンタイマーの自動停止はフォアグラウンドのtickerのみ(`ios/StudyApp/Presentation/Timer/TimerViewModel.swift:392`)。バックグラウンドで満了しても計測が続き、次回起動時に超過分まで記録される(意図した仕様なら対象外)。
- [低][日時] `ios/StudyApp/Domain/Scheduling/ProblemReviewScheduler.swift:36-51` が復習日をローカルTZの0時のepoch msで保存するため、TZの異なる端末間で復習日が±1日ずれる(日本国内利用なら実害なし)。
- [低][UIバグ] 「接続中」表示(iOS `SettingsScreen.swift:290` / Android `SettingsScreen.kt:511`)は認証セッションの有無だけで、実際の接続性・トークン有効性は見ていない。「サインイン済み」が正確。
- [低][導線] iOS `SettingsScreen.swift:17-18` の `versionTapCount`/`isDebugLogUnlocked`、`AppLogger.swift:48` の `isDebugToolsEnabled` は未使用の死にコード。診断ログUIは本番でも常時表示(redact済みなので実害小)。
- [低][バグ] `ios/StudyApp/Data/Sync/FirestoreDeltaSyncStore.swift:282` の clientFlags 書き込みが非トランザクションの read-modify-write で、2台同時同期時に後勝ち上書き。
- [低] Android `FirebaseSyncRepository.kt:204-209` の importLocalDataToCloud 内 localChangeToken チェックは取得直後に比較しており実質デッドコード。
- [低][セキュリティ] Firebase App Check 未導入(rulesで自己データに限定されるため実害は低い)。iOSのアカウント削除がレガシー `sync_snapshots` コレクションを消さない(現行コードは書き込まないため、旧バージョン利用者のみ残骸が残る)。
- [低] Google Books APIキーは両OSとも環境変数参照で、実機では常にnull(死にコード)。匿名クォータで動いている。

---

## セキュリティレビューの良い点(Round 1)

- `firestore.rules`: 全パスで `auth.uid == userId` のオーナー分離。書き込みはキーallowlist+型/範囲/サイズ検証(chunk 200KB、json 900KB、`serverUpdatedAt == request.time` 強制)まで揃っていて堅牢。
- `GoogleService-Info.plist` / `google-services.json` は git 未追跡(AGENTS.md 通り)。`FirebaseBootstrap` はプレースホルダ検出時に同期を無効化し状態を正直に表示。
- ログは email/uid/userId/localId を正規表現で redact。認証ログは boolean のみでPIIなし。
- 通信は全て HTTPS。ATS無効化・cleartextTraffic なし。entitlements / AndroidManifest は最小権限(exported は MainActivity と widget configure のみ、FGS は specialUse 宣言あり)。
- アカウント削除は両OSとも 再認証 → クラウドデータ削除 → 認証削除 → ローカル削除 の順で、クラウドに孤児データを残さない(iOSは削除前バックアップも作成)。

---

## 修正の推奨順

1. **#1 競合解決の未アップロード**(高・両OS)
2. **#2 削除による同期恒久ブロック**(高・両OS)
3. #3 max()マージの巻き戻り(中・両OS)
4. #4 Android週間レポートの週区切り(中)
5. #5 iOSウィジェットの日付跨ぎ(中)
6. 以降は 中→低 の順で随時

#1・#2 はリリース済みユーザーのデータが実際に分岐・停止する不具合。修正時は既存ユーザーのデータを壊さない前提で1件ずつ進めること。
