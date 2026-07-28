// firestore.rules の回帰テスト。
// 実行方法:
//   npm install --no-save @firebase/rules-unit-testing firebase
//   firebase emulators:exec --only firestore --project demo-rules-test "node tools/test_firestore_rules.mjs"
// (firebase-tools は JDK 21+ が必要)
//
// 特に「deletedAt キーが無い書き込みは拒否される」ことを固定化している。
// クライアントは生存エンティティにも deletedAt: null を必ず書くこと。
import { initializeTestEnvironment, assertSucceeds, assertFails } from "@firebase/rules-unit-testing";
import { doc, setDoc, serverTimestamp } from "firebase/firestore";
import { readFileSync } from "node:fs";

const rules = readFileSync(new URL("../firestore.rules", import.meta.url), "utf8");

const env = await initializeTestEnvironment({
  projectId: "demo-rules-test",
  firestore: { rules, host: "127.0.0.1", port: 8080 },
});

const uid = "user-1";
const db = env.authenticatedContext(uid).firestore();

const results = [];
async function expect(name, expectation, promise) {
  try {
    if (expectation === "allow") {
      await assertSucceeds(promise);
    } else {
      await assertFails(promise);
    }
    results.push(`PASS ${name}`);
  } catch (error) {
    results.push(`FAIL ${name}: ${String(error).slice(0, 200)}`);
  }
}

const entityBase = {
  kind: "subject",
  syncId: "s1",
  updatedAt: 1000,
  serverUpdatedAt: serverTimestamp(),
  json: "{\"name\":\"x\"}",
};

// 1. Android旧実装の再現: deletedAt キー無し → 拒否されることの実証
const { deletedAt: _omit, ...noDeleted } = { ...entityBase, deletedAt: null };
await expect(
  "live entity WITHOUT deletedAt key is denied (old Android behavior)",
  "deny",
  setDoc(doc(db, `users/${uid}/sync_entities/subject-s1`), noDeleted)
);

// 2. 修正後: deletedAt: null 明示 → 許可
await expect(
  "live entity with explicit deletedAt null is allowed",
  "allow",
  setDoc(doc(db, `users/${uid}/sync_entities/subject-s1`), { ...entityBase, deletedAt: null })
);

// 3. tombstone → 許可
await expect(
  "tombstone entity is allowed",
  "allow",
  setDoc(doc(db, `users/${uid}/sync_entities/subject-s1`), { ...entityBase, deletedAt: 2000 })
);

// 4. Screen Time 設定エンティティ → 許可
await expect(
  "screen time settings entity is allowed",
  "allow",
  setDoc(doc(db, `users/${uid}/sync_entities/screenTimeSettings-screen-time-focus`), {
    ...entityBase,
    kind: "screenTimeSettings",
    syncId: "screen-time-focus",
    deletedAt: null,
    json: "{\"isEnabled\":true}",
  })
);

// 5. json 900KB 超 → 拒否（クライアント検証と同じ境界）
await expect(
  "oversized json is denied",
  "deny",
  setDoc(doc(db, `users/${uid}/sync_entities/subject-s1`), {
    ...entityBase,
    deletedAt: null,
    json: "a".repeat(900_001),
  })
);

// 6. updatedAt が2100年超 → 拒否
await expect(
  "far-future updatedAt is denied",
  "deny",
  setDoc(doc(db, `users/${uid}/sync_entities/subject-s1`), {
    ...entityBase,
    deletedAt: null,
    updatedAt: 4102444800001,
  })
);

// 7. 新ルール: syncGeneration のみのルートdoc → 許可
await expect(
  "generation-only user root write is allowed",
  "allow",
  setDoc(
    doc(db, `users/${uid}`),
    { syncGeneration: "gen-1", syncGenerationUpdatedAt: serverTimestamp() },
    { merge: true }
  )
);

// 8. clientFlags のみ（merge で generation と共存）→ 許可
await expect(
  "clientFlags merge onto generation doc is allowed",
  "allow",
  setDoc(
    doc(db, `users/${uid}`),
    {
      clientFlags: { serverUpdatedAtCursorMigrated: true, lastSeenAt: 1000, appDataSchemaVersion: 2 },
      clientFlagsUpdatedAt: serverTimestamp(),
    },
    { merge: true }
  )
);

// 9. 未知フィールドのルートdoc → 拒否
await expect(
  "unknown user-root field is denied",
  "deny",
  setDoc(doc(db, `users/${uid}`), { evil: true }, { merge: true })
);

// 10. 他人の uid への書き込み → 拒否
const otherDb = env.authenticatedContext("someone-else").firestore();
await expect(
  "cross-user write is denied",
  "deny",
  setDoc(doc(otherDb, `users/${uid}/sync_entities/subject-s1`), { ...entityBase, deletedAt: null })
);

await env.cleanup();
console.log(results.join("\n"));
process.exit(results.some((line) => line.startsWith("FAIL")) ? 1 : 0);
