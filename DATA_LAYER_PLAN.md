# データ保存・同期レイヤー改善プラン（iOS）

実装前に読む設計・移行プラン。最重要条件は **既存ユーザーのデータを壊さない・失わない** こと。
Firebase 同期ユーザーとローカル保存のみのユーザーが混在している前提で書く。

作成日: 2026-06-11 / 対象: `ios/StudyApp/Data/` 一帯

---

## 1. 現状整理（コードを読んだ結果の地図）

### 1.1 データの置き場所（iOS 端末上に7種類ある）

| 置き場所 | 内容 | 管理コード |
|---|---|---|
| Core Data (`StudyApp.sqlite`) | 本体データ12エンティティ | `PersistenceController` / `CoreDataSchema` |
| `studyapp-store.json(.migrated)` | 旧フラットファイル（移行済み） | `migrateLegacySnapshotIfNeeded` / `LegacySnapshotModels` |
| UserDefaults | preferences、lastSyncAt、owner、`deltaCursor.<uid>`、`deltaMigrationDone.<uid>`、autoSyncBlocked | 各所に分散 |
| `StudyApp/SyncBases/<uid>.json` | 3-way マージの base shadow | `SyncBaseShadowStore` |
| `StudyApp/SyncBaseRevisions/<uid>.json` | リビジョンマップ | 同上 |
| `StudyApp/SyncBackups/*.json` | 同期前自動バックアップ（30日保持） | `FirebaseSyncRepository.saveLocalBackup` |
| SyncConflicts ストア | 未解決競合 | `SyncConflictStore` |

### 1.2 Firestore 側のフォーマット世代（3世代がコード上に共存）

1. **第1世代**: `users/<uid>/sync/default` の `payload` 文字列（単一ドキュメント）
2. **第2世代**: chunked-v2（manifest + `chunks/` サブコレクション）
3. **第3世代（現行）**: `users/<uid>/sync_entities` のエンティティ単位デルタ + tombstone（90日保持）

クライアントは初回同期時に 1/2 → 3 へ一回限りの移行を行い（`migrateLegacyChunkedSnapshotIfNeeded`）、
`deltaMigrationDone.<uid>` フラグで再実行を防ぐ。第1・2世代の **読み取りコードは常駐**している。

### 1.3 起動時・同期時に毎回走る互換処理

- `LegacyDailyGoalNormalizer` — 起動後の初回アクセスで毎回チェック（dayOfWeek なしの daily goal を7曜日に展開）
- `SyncMetadataBackfiller` — **エクスポートのたび**（= 同期のたび）に全エンティティをフルスキャンして syncId / 非正規化フィールドを補完
- `SyncDeltaCursor.fromLegacy` — Int64 単独カーソルからの読み替え
- `SyncThreeWayMergeEngine` — base shadow がなければ 2-way (`SyncMergeEngine`) にフォールバック

### 1.4 同期の適用方法（ここが最大の構造問題）

`syncNow()` の1サイクル:

```
全件エクスポート(exportData) → バックアップ保存 → デルタ取得 → 3-wayマージ(AppData全体)
→ ensureNoProblemProgressLoss ガード → applyMergedSnapshotLocally
   = マージ結果を JSON にエンコード → importJSON → AppDataArchiver.replaceData
   = Core Data の全行を削除して全行を再 INSERT（ID 再割当てつき）
→ アウトバウンドデルタ書込み → カーソル・base shadow 更新
```

つまり **差分同期なのに、ローカル適用は毎回フルリプレース**。changeToken による楽観的リトライ（3回）で
同期中のローカル変更と競合検知している。

### 1.5 ID 体系

- `Int64 id`（ローカル主キー。`max+1` を**全12エンティティ横断**でスキャンして採番）
- `String syncId`（UUID。クラウド上の正体）
- 外部キーは `subjectId` + `subjectSyncId` + `subjectName` のように **3重に非正規化**され、
  update 時に手書きで伝播している（`updateSubject` がセッションの `subjectName` を書き換える等）

### 1.6 良くできている点（壊さないこと）

- 全エンティティに `syncId / createdAt / updatedAt / deletedAt(tombstone) / lastSyncedAt` が揃っている
- 同期前の自動ローカルバックアップ、問題進捗の減少を検知して同期を止めるガード
- マージエンジン・デルタシリアライザに単体テストがある
- アカウント所有権チェック（別アカウントのデータ上書き防止）
- ヘルパー分割（Archiver / Backfiller / Normalizer / Schema / Mappers）は既に進んでいる

---

## 2. 問題点の診断

### 2.1 保存設計

| # | 問題 | リスク |
|---|---|---|
| P1 | スキーマが「プログラム生成 + lightweight migration 推論」のみで、**ストアのバージョン番号がどこにも記録されない** | どの端末がどの形か分からない。フィールドのリネームや型変更をした瞬間に壊れる |
| P2 | 一回限りの正規化処理（LegacyDailyGoalNormalizer 等）が「実行済みか」をデータの形から推測 | 同期で旧形式が**復活すると再実行**される。特に Normalizer は旧レコードを**ハード削除**するため、リモートに残った旧 goal が同期のたびに復活→再展開を繰り返す可能性がある |
| P3 | `nextIdentifier` が全エンティティ横断 max+1 スキャン | 挿入のたび O(n)。データ増で遅くなる。ID は同期のたびに再割当てされるため永続性もない |
| P4 | `getSubjectById` だけ `deletedAt` を見ていない（他の getAll* は見ている） | 削除済み科目が参照経由で見える可能性 |

### 2.2 同期設計

| # | 問題 | リスク |
|---|---|---|
| S1 | デルタ同期なのに**ローカル適用がフルリプレース**（全行 DELETE→INSERT、ID 再割当て、JSON 二重エンコード経由） | データ量に比例して同期が重くなる。リプレース中の失敗＝全データの整合性をロールバックに依存。ID が安定しないため他機能（ウィジェット等）が古い ID を掴むと迷子 |
| S2 | `try? SyncBaseShadowStore.save(...)` が**失敗を黙殺** | base shadow が古いまま → 以後の 3-way マージの祖先が誤り → 偽の競合や誤マージ |
| S3 | Backfiller が同期のたびにフルスキャンし、補完時に `updatedAt = now` を書く | 補完対象が残っていると不要なデルタを毎回生成。スキャン自体も無駄 |
| S4 | 同期状態が UserDefaults・複数 JSON ファイル・Core Data に分散 | カーソルと base shadow の不整合（片方だけ消える/失敗する）を検知する仕組みがない |
| S5 | 第1・2世代の読み取り・移行コードが `FirebaseSyncRepository` に常駐（~150行） | 保守対象が3世代分。テスト・変更コストが膨らむ |

### 2.3 互換・フォールバック

| # | 問題 |
|---|---|
| F1 | 「一回限りの移行」「毎回走る補完」「フォールバック」が区別されずに散在し、**卒業条件（いつ消せるか）が定義されていない** |
| F2 | `AppData` の schemaVersion=2 はあるが、decode 時に黙ってデフォルト値で埋めるだけで、**バージョンごとの変換ステップが存在しない**（v3 を作るときの足場がない） |
| F3 | 新エンティティを1つ足すと、`CoreDataSchema` / `PersistenceMappers` / `AppData` / `AppDataArchiver`(export+replace) / `SyncDeltaSerializer`(decompose/assemble/partial) / `SyncThreeWayMergeEngine` / `SyncMergeEngine` / `SyncMetadataBackfiller` / `SyncConflictModels` / Android 側、と **10箇所以上**に手書きの並行実装が必要 — 「将来破綻しやすい」のはここ |

### 2.4 ユーザー区分ごとの露出

- **ローカルのみユーザー**: 同期コードには触れない。危険なのは (a) Core Data スキーマ変更、(b) 起動時の一回限り正規化、(c) JSON インポート。自動バックアップは**同期時にしか取られない**ので、ローカルユーザーは移行失敗時のセーフティネットがない。
- **Firebase ユーザー**: 上記すべて + 同期の3世代移行 + マージ。Android と iOS の両方が同じ Firestore フォーマットを読むため、**Firestore 側のフォーマットはクロスプラットフォーム契約**であり iOS 単独では変更できない。

---

## 3. 設計方針（原則）

1. **書き込みより先にバックアップ**: 破壊的になり得る処理（移行・リプレース・正規化）の直前に必ずローカルスナップショットを取る。これを同期時だけでなく全ユーザー共通にする。
2. **移行は「台帳方式」**: データの形から推測せず、ストアに記録されたバージョン番号と「実行済み移行リスト」で管理する。各移行は冪等・前進のみ。
3. **追加のみのスキーマ変更（additive-only）**: フィールドの削除・リネーム・型変更は禁止。旧バージョンのアプリが新データを読んでも壊れない状態を常に保つ（これがロールバック可能性の土台）。
4. **syncId を唯一の正体に**: Int64 id はローカル rowid 扱いに格下げし、同期・インポートでの ID 再割当てを段階的に廃止する。
5. **レガシーコードには卒業条件を付ける**: 「残存ユーザー数が計測できて、N ヶ月ゼロが続いたら削除」のように、消す条件を先に決めてから維持する。
6. **エンティティ定義の一元化**: 新しい記録項目を足すときに触る場所を 10+ → 2〜3 箇所に減らす。
7. **Firestore フォーマットは凍結**: Android との契約なので、本プランでは第3世代（sync_entities デルタ）を変更しない。変更が必要になったら別途両 OS 同時のプランを立てる。

---

## 4. 実行プラン

### Phase 0 — 安全網と現状計測（最初に着手。コード変更は最小限）

> 目的: 以降のどの変更で事故っても復元できる状態を先に作る。

- **0-1. 全ユーザー共通の自動バックアップ**
  既存の `saveLocalBackup`（同期前のみ）を `PersistenceController` 側に移し、
  「アプリ起動時に前回バックアップから24時間以上経過していたら `AppData` を JSON で保存」にする。
  保存先は既存の `StudyApp/SyncBackups` を `StudyApp/DataBackups` に一般化（同期ユーザー・ローカルユーザー共通）。
  ローカルユーザー向けには iCloud バックアップ除外（`isExcludedFromBackup`）を**外す**ことを検討
  （現在は除外されているため、端末紛失でローカルユーザーのデータは全損する）。
- **0-2. 設定画面に「バックアップから復元」**
  既にある JSON インポート経路（`importJSON`）にバックアップ一覧 UI を被せるだけ。移行事故時の復旧手段を
  ユーザー自身が持つ。
- **0-3. レガシー残存ユーザーの計測**
  - クライアント: `usedLegacyTwoWayFallback` / 「chunked 移行を実行した」/「Backfiller が実際に補完した」
    をログだけでなく Firestore のユーザードキュメント（例: `users/<uid>` の `clientFlags`）に記録。
  - サーバー: Firebase CLI で `users/*/sync/default` に `payload` または `chunks` が残っている uid を列挙
    （読み取り専用スクリプト）。→ 第1・2世代コードの卒業判定に使う。
- **0-4. characterization テスト（golden ファイル）**
  v1 形式・v2 形式・旧 `LegacySnapshot` 形式のサンプル JSON をテストリソースとして固定し、
  「decode → replaceData → export → 再エンコード」のラウンドトリップ結果をスナップショット比較。
  以降のリファクタリングはこのテストが緑であることを前提に進める。
- **0-5. 既知の小バグ修正（挙動を変えずに安全性だけ上げる）**
  - `try? SyncBaseShadowStore.save` → 失敗時にログ + 次回同期でフルベース再構築するリカバリ（S2）
  - `getSubjectById` の `deletedAt` フィルタ追加（P4）
  - `LegacyDailyGoalNormalizer` のハード削除を tombstone（`deletedAt` セット）に変更（P2 の復活ループ防止）

**工数感: 2〜4日。リリース1回。**

### Phase 1 — 短期: 移行台帳とレガシーの一回限り化

> 目的: 「毎回走る互換処理」をなくし、移行を制御可能にする。

- **1-1. 移行台帳（MigrationLedger）の導入**
  `NSPersistentStore` のメタデータ（`metadata(for:)`）に `dataSchemaVersion: Int` と
  `completedMigrations: [String]` を保存。起動時に一度だけ:

  ```swift
  struct DataMigration {
      let id: String            // 例: "2024-09-daily-goal-expansion"
      let run: (NSManagedObjectContext) throws -> Void  // 冪等であること
  }
  // 起動時: バックアップ → 未実行の migration を順に実行 → 台帳に記録 → save
  ```

  既存の一回限り処理をここへ移す:
  - 旧 JSON ファイル移行（`migrateLegacySnapshotIfNeeded`）
  - daily goal 展開（`LegacyDailyGoalNormalizer`）
  - **syncId / 非正規化フィールドの backfill（`SyncMetadataBackfiller`）← 同期のたびのフルスキャンを廃止**

  実行前に必ず 0-1 のバックアップを取る。失敗したら台帳に記録せず、アプリは旧挙動のまま動かす
  （= 移行失敗がデータ喪失にならない）。
- **1-2. 同期状態の一元化**
  UserDefaults に散らばる同期キーを `SyncStateStore`（1ファイル・1構造体）に集約し、
  「カーソル・base shadow・リビジョンマップの整合チェック」（どれかが欠けたら全部リセットして
  フル再同期）を入れる。S4 の不整合を構造的に防ぐ。
- **1-3. AppData のバージョン変換を明示化**
  `AppData.init(from:)` の黙ったデフォルト埋めをやめ、
  `AppDataUpgrader.upgrade(json) -> AppData`（v1→v2→…と順に変換、各ステップにテスト）に分離。
  v3 が必要になったときの足場を先に作る。

**工数感: 3〜5日。リリース1回（Phase 0 と分けること — 切り分けのため同時に出さない）。**

### Phase 2 — 中期: 同期適用のフルリプレース廃止（最大のリスク、最大のリターン）

> 目的: S1 の解消。「マージ結果を JSON 経由で全行リプレース」→「syncId キーの per-entity upsert」へ。

- **2-1. `applySyncedEntities(envelopes:)` を新設**
  マージ済みエンベロープを Core Data に **syncId で upsert / tombstone** する経路を作る。
  Int64 id は既存レコードのものを保持、新規のみ採番（ID 再割当ての廃止）。
  `importJSON`（手動インポート）は従来のリプレース経路を維持してよい — 意味的に「置き換え」だから。
- **2-2. シャドー比較で検証してから切替**
  フラグ（ビルド設定 or リモート設定）で新旧経路を切替可能にし、まず**新経路を計算だけして
  旧経路の結果と `SyncDataSummary` レベルで比較ログを出す**段階を1リリース挟む。
  乖離ゼロを確認してから新経路をデフォルトに。問題があれば旧経路へ即ロールバック（フラグだけ）。
- **2-3. ID 採番の安定化**
  `nextIdentifier` の横断 max+1 をエンティティごとのシーケンス（メタデータに保持）に変更。
  upsert 化で ID が安定するため、これ以降ウィジェット・参照系の ID 前提も信頼できる。
- **2-4. PersistenceController の分割（任意・余力があれば）**
  9 プロトコル実装の God object を、エンティティ群ごとのリポジトリ（Study系 / Timetable系 / Plan系）に分割。
  機能変更なしの純リファクタリングなので characterization テストの傘の下で安全に行える。

**工数感: 1〜2週間 + 検証リリース1回 + 切替リリース1回。**

### Phase 3 — 長期: エンティティ定義の一元化とレガシー削除

- **3-1. エンティティレジストリ**
  F3 の解消。エンティティごとに「Core Data 属性定義・Codable 型・syncKind・マージ規則（LWW or
  フィールド単位）」を1箇所で宣言し、`CoreDataSchema` / `SyncDeltaSerializer` / マージエンジン /
  Backfiller がレジストリを走査する形に書き換える。
  新しい記録項目の追加 = 「レジストリに1エントリ + ドメインモデル + Android 側」だけになる。
  一気にやらず、**新規エンティティから新方式で追加**し、既存はテストの傘の下で順次移す。
- **3-2. レガシーコードの削除（卒業条件つき）**

  | 対象 | 卒業条件 |
  |---|---|
  | 第1世代 `payload` 読み取り + chunked-v2 読み取り・移行（`loadSnapshot` ~150行） | 0-3 の計測で残存 uid が 0、または最終更新が12ヶ月以上前のみ。削除前に Firebase CLI のサーバーサイド一括移行スクリプトで残りを移行してもよい |
  | `SyncMergeEngine`（2-way フォールバック） | `usedLegacyTwoWayFallback=true` の報告が3ヶ月ゼロ。base shadow は初回同期で必ず bootstrap されるため、実質「一度でも同期した端末」には不要 |
  | `SyncDeltaCursor.fromLegacy` | デルタ移行完了フラグと同時に消せる（カーソルは composite 形式で再保存されるため2リリース後で十分） |
  | `LegacySnapshot` 系（旧 JSON ファイル） | `.json.migrated` の存在報告が一定期間ゼロ。最悪消し忘れても害は小さい（ファイルが無ければ即 return） |
  | `AppPreferences.onboardingCompleted` | 互換のためのキーのみ残し、参照コードは削除可 |

  削除は**1リリース1世代**ずつ。各削除リリースの直前に該当 golden テストを「削除されたことを確認する
  テスト」に置き換える。
- **3-3. SYNC_FORMAT.md の作成**
  Firestore エンベロープ仕様（フィールド・tombstone・カーソル規則・バージョン）を Android/iOS 共通の
  契約ドキュメントとしてリポジトリに置く。以後のフォーマット変更はここを先に更新してから両 OS 実装。

**工数感: レジストリ化 1〜2週間（分割可能）、レガシー削除は各1日未満 × 数回。**

---

## 5. データモデルのバージョニング方針（まとめ）

1. **3つのバージョン軸を区別して管理する**
   - ローカルストア: `dataSchemaVersion`（Phase 1 の台帳。Core Data メタデータに記録）
   - エクスポート/同期ペイロード: `AppData.schemaVersion`（現2。upgrader で前進変換）
   - Firestore コレクション形式: 世代1/2/3（凍結。変更時は Android と同時）
2. **additive-only ルール**: 新フィールドは optional + デフォルト値。旧クライアントは未知フィールドを
   無視できる（Codable も Firestore もこの性質を持つ）。削除・リネームは「2メジャーリリースの
   deprecation 期間 + 残存計測ゼロ」の後のみ。
3. **新バージョンの追加手順**: upgrader にステップ追加 → golden ファイル追加 → 台帳 migration 追加 →
   Android 対応確認 → リリース。

---

## 6. リリース・ロールバック手順（毎回のチェックリスト）

1. **リリース前**
   - golden ラウンドトリップテスト + 同期マージテストが緑
   - 手元で「v(現行) のデータが入った端末/シミュレータに新ビルドを上書きインストール → 起動 → 全画面表示 → 同期1往復」を確認
   - ローカルユーザー相当（未サインイン状態）でも同じ確認
   - データ層に触れる変更は **TestFlight で自分の実データ端末に数日入れてから** App Store へ
2. **段階的公開**: App Store の Phased Release を必ず使う（7日かけて自動拡大、問題があれば一時停止）
3. **ロールバック可能性の担保**
   - additive-only を守っている限り、ユーザーが旧バージョンに戻っても（審査経由の再リリースでも）データは読める
   - 挙動の切替（Phase 2 の新適用経路など）は必ずフラグで持ち、コード削除はフラグ安定後の次リリース
   - 万一の破損時はユーザー側の「バックアップから復元」（0-2）が最後の砦
4. **リリース後**: クラッシュ・`clientFlags` のレガシー残存数・同期エラーログ（destructiveSyncMessage 発火数）を1週間観測してから次のフェーズに進む

---

## 7. テスト・検証・バックアップの最低ライン

- **必須テスト（Phase 0 で揃える）**
  1. golden ラウンドトリップ（v1 / v2 / LegacySnapshot → store → export）
  2. 各 migration の冪等性（2回実行しても結果が同じ）
  3. 3-way マージ既存テストの維持 + 「base shadow 欠損時のリカバリ」ケース追加
  4. `replaceData` の preserve 系（problemProgress 保持）— 既存を golden 化
- **Phase 2 で追加**: upsert 適用経路 vs リプレース経路の同値性テスト（同じ入力 → 同じ `SyncDataSummary`）
- **バックアップ**: 起動時自動（24h 間隔・30日保持・全ユーザー）+ 移行直前の強制スナップショット +
  ユーザー手動エクスポート（既存）。Firebase ユーザーはクラウド側がもう1系統のバックアップとして機能。

---

## 8. 優先順位（個人開発として現実的な順）

| 優先 | 作業 | 効果 | 工数 |
|---|---|---|---|
| ★1 | Phase 0（バックアップ全ユーザー化・復元UI・計測・goldenテスト・小バグ修正） | 以降の全作業の保険。単体でもユーザー保護が向上 | 2〜4日 |
| ★2 | Phase 1（移行台帳・Backfiller の一回限り化・同期状態一元化） | 毎同期のフルスキャン廃止、移行が制御可能に | 3〜5日 |
| ★3 | Phase 2（同期適用の upsert 化） | 同期の最大の構造リスクとパフォーマンス問題を解消 | 1〜2週 |
| ★4 | Phase 3-2（レガシー削除、計測条件を満たしたものから順次） | コード量と認知負荷の削減 | 各<1日 |
| ★5 | Phase 3-1（エンティティレジストリ） | 将来の項目追加コストを1/5に | 1〜2週(分割可) |

急がないもの: PersistenceController の分割（2-4）、macOS コンパニオン（別データ系なので対象外）。

## 9. 最初の一歩（今日やること）

1. golden ファイル用に現行端末から `exportJSON` のサンプルを採取し、`StudyAppTests/Resources/` に固定
2. ラウンドトリップ characterization テストを書く（0-4）
3. `try?` 黙殺と `getSubjectById` と Normalizer ハード削除の3点修正（0-5）
4. Firebase CLI で第1・2世代の残存ユーザー数を数える読み取り専用スクリプトを作る（0-3）

ここまでは既存挙動を一切変えないので、いつでも出せるし、いつでも戻せる。
