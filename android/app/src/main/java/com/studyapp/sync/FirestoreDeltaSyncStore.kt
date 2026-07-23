package com.studyapp.sync

import android.util.Log
import com.google.firebase.firestore.CollectionReference
import com.google.firebase.firestore.FieldPath
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.Timestamp
import com.google.android.gms.tasks.Task
import com.studyapp.domain.usecase.AppData
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeout
import javax.inject.Inject
import javax.inject.Singleton

internal const val SYNC_NETWORK_TIMEOUT_MESSAGE =
    "同期がタイムアウトしました。通信環境を確認してもう一度お試しください。"
private const val SYNC_NETWORK_TIMEOUT_MS = 60_000L

// Firestore の Task はオフライン時に完了しないことがある（特に batch.commit は
// サーバー ack まで完了しない）。締切なしで await すると isSyncing が立った
// ままスタックするため、同期のネットワーク呼び出しには必ず締切を設ける。
internal suspend fun <T> Task<T>.awaitSyncBounded(): T =
    try {
        withTimeout(SYNC_NETWORK_TIMEOUT_MS) { await() }
    } catch (t: TimeoutCancellationException) {
        throw IllegalStateException(SYNC_NETWORK_TIMEOUT_MESSAGE, t)
    }

@Singleton
class FirestoreDeltaSyncStore @Inject constructor(
    private val firestore: FirebaseFirestore
) {
    data class FetchResult(
        val envelopes: List<SyncEntityEnvelope>,
        val cursor: SyncServerCursor
    )

    // firestore.rules の制約（json ≤ 900KB・タイムスタンプ上限）をクライアント
    // 側で事前検証する。ルール違反のまま書き込むと PERMISSION_DENIED になり、
    // 「権限がありません」という原因の分からないエラーで恒久的に同期不能に
    // なるため、原因を特定できるメッセージで停止する。
    fun validateForUpload(envelopes: List<SyncEntityEnvelope>) {
        envelopes.forEach { envelope ->
            val bytes = envelope.json.toByteArray().size
            check(bytes <= MAX_RULE_JSON_BYTES) {
                "同期データ（${envelope.kind.rawValue}）が1件あたりの上限サイズ900KBを超えています（${bytes}バイト）。この項目を分割してから再度同期してください。"
            }
            val timestamps = listOfNotNull(envelope.updatedAt, envelope.deletedAt)
            check(timestamps.all { it in 0..MAX_RULE_TIMESTAMP_MILLIS }) {
                "端末の日時が不正なため同期を中止しました。設定で日付と時刻を確認してください。"
            }
        }
    }

    suspend fun writeEnvelopes(envelopes: List<SyncEntityEnvelope>, userId: String) {
        if (envelopes.isEmpty()) return
        validateForUpload(envelopes)
        val collection = entitiesCollection(userId)
        val operations = envelopes.map { envelope ->
            val ref = collection.document(envelope.documentId)
            val data = buildMap<String, Any?> {
                put("kind", envelope.kind.rawValue)
                put("syncId", envelope.syncId)
                put("updatedAt", envelope.updatedAt)
                put("serverUpdatedAt", FieldValue.serverTimestamp())
                put("json", envelope.json)
                // firestore.rules の validDeltaEntity は deletedAt キーの存在を
                // 要求する（値は null 可）。iOS と同じく常にキーを書く。
                put("deletedAt", envelope.deletedAt)
                envelope.revisionId?.let { put("revisionId", it) }
                envelope.parentRevisionId?.let { put("parentRevisionId", it) }
                envelope.deviceId?.let { put("deviceId", it) }
                envelope.contentHash?.let { put("contentHash", it) }
            }
            ref to data
        }

        var index = 0
        while (index < operations.size) {
            val batch = firestore.batch()
            val end = minOf(index + MAX_BATCH_OPERATIONS, operations.size)
            for (operation in operations.subList(index, end)) {
                batch.set(operation.first, operation.second)
            }
            batch.commit().awaitSyncBounded()
            index = end
        }
    }

    suspend fun fetchEnvelopes(userId: String, changedSince: SyncServerCursor): FetchResult {
        val collection = entitiesCollection(userId)
        val pageSize = 500
        val results = mutableListOf<SyncEntityEnvelope>()
        var lastSeen = changedSince
        var lastPageDocument: com.google.firebase.firestore.DocumentSnapshot? = null

        while (true) {
            var query = collection
                .whereGreaterThanOrEqualTo(
                    "serverUpdatedAt",
                    Timestamp(changedSince.seconds, changedSince.nanoseconds)
                )
                .orderBy("serverUpdatedAt")
                .orderBy(FieldPath.documentId())
            lastPageDocument?.let { query = query.startAfter(it) }
            val snapshot = query.limit(pageSize.toLong())
                .get()
                .awaitSyncBounded()

            if (snapshot.isEmpty) break

            snapshot.documents.forEach { document ->
                val serverUpdatedAt = document.getTimestamp("serverUpdatedAt")
                if (serverUpdatedAt == null) {
                    Log.w(TAG, "Skipped delta document without server timestamp: ${document.id}")
                    return@forEach
                }
                val position = SyncServerCursor(
                    seconds = serverUpdatedAt.seconds,
                    nanoseconds = serverUpdatedAt.nanoseconds,
                    documentId = document.id
                )
                if (position <= changedSince) return@forEach
                envelopeFrom(document.data)?.let { envelope ->
                    results += envelope
                } ?: Log.w(TAG, "Skipped malformed delta document: ${document.id}")
            }
            val lastDocument = snapshot.documents.last()
            val lastServerUpdatedAt = lastDocument.getTimestamp("serverUpdatedAt") ?: break
            lastSeen = SyncServerCursor(
                seconds = lastServerUpdatedAt.seconds,
                nanoseconds = lastServerUpdatedAt.nanoseconds,
                documentId = lastDocument.id
            )
            lastPageDocument = lastDocument

            if (snapshot.size() < pageSize) break
        }

        return FetchResult(results, lastSeen)
    }

    suspend fun purgeTombstonesOlderThan(retentionMillis: Long, now: Long, userId: String) {
        val cutoff = now - retentionMillis
        val collection = entitiesCollection(userId)
        val snapshot = collection
            .whereLessThan("deletedAt", cutoff)
            .limit(500)
            .get()
            .awaitSyncBounded()

        if (snapshot.isEmpty) return

        var index = 0
        val documents = snapshot.documents
        while (index < documents.size) {
            val batch = firestore.batch()
            val end = minOf(index + MAX_BATCH_OPERATIONS, documents.size)
            for (document in documents.subList(index, end)) {
                batch.delete(document.reference)
            }
            batch.commit().awaitSyncBounded()
            index = end
        }
    }

    // クラウド側の同期世代。deleteCloudDataForCurrentUser がデータ削除後に
    // 新しい世代を書き込み、他端末はこの値の変化で「クラウドがリセットされた」
    // ことを検出してローカルの同期状態（カーソル・base shadow）を破棄する。
    suspend fun fetchSyncGeneration(userId: String): String? {
        val snapshot = firestore.collection("users").document(userId).get().awaitSyncBounded()
        return snapshot.getString("syncGeneration")
    }

    suspend fun writeSyncGeneration(generation: String, userId: String) {
        firestore.collection("users").document(userId).set(
            mapOf(
                "syncGeneration" to generation,
                "syncGenerationUpdatedAt" to FieldValue.serverTimestamp()
            ),
            com.google.firebase.firestore.SetOptions.merge()
        ).awaitSyncBounded()
    }

    suspend fun recordClientFlags(flags: Map<String, Any>, userId: String) {
        val document = firestore.collection("users").document(userId)
        // iOS と同様にトランザクションで read-modify-write する。素の get/set
        // だと複数端末の同時書き込みでフラグが失われる。
        firestore.runTransaction { transaction ->
            val snapshot = transaction.get(document)
            val payload = (snapshot.get("clientFlags") as? Map<*, *>)
                ?.entries
                ?.mapNotNull { (key, value) -> (key as? String)?.let { it to value } }
                ?.toMap()
                ?.toMutableMap()
                ?: mutableMapOf()
            payload.putAll(flags)
            payload["lastSeenAt"] = System.currentTimeMillis()
            payload["appDataSchemaVersion"] = AppData.CURRENT_SCHEMA_VERSION
            transaction.set(
                document,
                mapOf(
                    "clientFlags" to payload,
                    "clientFlagsUpdatedAt" to FieldValue.serverTimestamp()
                ),
                com.google.firebase.firestore.SetOptions.merge()
            )
        }.awaitSyncBounded()
    }

    suspend fun clearLegacyChunkedSnapshot(userId: String) {
        val manifest = firestore.collection("users").document(userId).collection("sync").document("default")
        val chunks = manifest.collection("chunks").get().awaitSyncBounded()
        var batch = firestore.batch()
        var writeCount = 0
        for (chunk in chunks.documents) {
            batch.delete(chunk.reference)
            writeCount += 1
            if (writeCount >= MAX_BATCH_OPERATIONS) {
                batch.commit().awaitSyncBounded()
                batch = firestore.batch()
                writeCount = 0
            }
        }
        batch.delete(manifest)
        batch.commit().awaitSyncBounded()
    }

    suspend fun deleteAllUserData(userId: String) {
        deleteDocumentsInCollection(entitiesCollection(userId))

        val manifest = firestore.collection("users").document(userId).collection("sync").document("default")
        deleteDocumentsInCollection(manifest.collection("chunks"))

        val batch = firestore.batch()
        batch.delete(manifest)
        batch.delete(firestore.collection("users").document(userId))
        batch.commit().awaitSyncBounded()
    }

    private suspend fun deleteDocumentsInCollection(collection: CollectionReference) {
        while (true) {
            val page = collection.limit(MAX_BATCH_OPERATIONS.toLong()).get().awaitSyncBounded()
            if (page.isEmpty) return
            var batch = firestore.batch()
            var writeCount = 0
            page.documents.forEach { document ->
                batch.delete(document.reference)
                writeCount += 1
                if (writeCount >= MAX_BATCH_OPERATIONS) {
                    batch.commit().awaitSyncBounded()
                    batch = firestore.batch()
                    writeCount = 0
                }
            }
            if (writeCount > 0) {
                batch.commit().awaitSyncBounded()
            }
        }
    }

    private fun entitiesCollection(userId: String): CollectionReference {
        return firestore.collection("users").document(userId).collection("sync_entities")
    }

    private fun envelopeFrom(data: Map<String, Any>?): SyncEntityEnvelope? {
        if (data == null) return null
        val kindRaw = data["kind"] as? String ?: return null
        val kind = SyncEntityKind.fromRawValue(kindRaw) ?: return null
        val syncId = data["syncId"] as? String
        if (syncId.isNullOrEmpty()) return null
        val updatedAt = readInt64(data["updatedAt"]) ?: return null
        val json = data["json"] as? String ?: return null
        val deletedAt = readInt64(data["deletedAt"])
        return SyncEntityEnvelope(
            kind = kind,
            syncId = syncId,
            updatedAt = updatedAt,
            deletedAt = deletedAt,
            json = json,
            revisionId = data["revisionId"] as? String,
            parentRevisionId = data["parentRevisionId"] as? String,
            deviceId = data["deviceId"] as? String,
            contentHash = data["contentHash"] as? String
        )
    }

    private fun readInt64(value: Any?): Long? {
        return when (value) {
            is Number -> value.toLong()
            is String -> value.toLongOrNull()
            else -> null
        }
    }

    private companion object {
        private const val TAG = "FirestoreDeltaSyncStore"
        private const val MAX_BATCH_OPERATIONS = 450
        private const val MAX_RULE_JSON_BYTES = 900_000
        private const val MAX_RULE_TIMESTAMP_MILLIS = 4_102_444_800_000L
    }
}
