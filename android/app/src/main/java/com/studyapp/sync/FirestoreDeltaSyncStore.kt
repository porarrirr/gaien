package com.studyapp.sync

import android.util.Log
import com.google.firebase.firestore.CollectionReference
import com.google.firebase.firestore.FieldPath
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FirestoreDeltaSyncStore @Inject constructor(
    private val firestore: FirebaseFirestore
) {
    suspend fun writeEnvelopes(envelopes: List<SyncEntityEnvelope>, userId: String) {
        if (envelopes.isEmpty()) return
        val collection = entitiesCollection(userId)
        val operations = envelopes.map { envelope ->
            val ref = collection.document(envelope.documentId)
            val data = buildMap<String, Any> {
                put("kind", envelope.kind.rawValue)
                put("syncId", envelope.syncId)
                put("updatedAt", envelope.updatedAt)
                put("serverUpdatedAt", FieldValue.serverTimestamp())
                put("json", envelope.json)
                envelope.deletedAt?.let { put("deletedAt", it) }
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
            batch.commit().await()
            index = end
        }
    }

    suspend fun fetchEnvelopes(userId: String, changedSince: SyncDeltaCursor): List<SyncEntityEnvelope> {
        val collection = entitiesCollection(userId)
        val pageSize = 500
        val results = mutableListOf<SyncEntityEnvelope>()
        var lastSeen = changedSince

        while (true) {
            val snapshot = collection
                .orderBy("updatedAt")
                .orderBy(FieldPath.documentId())
                .startAfter(lastSeen.updatedAt, lastSeen.documentId)
                .limit(pageSize.toLong())
                .get()
                .await()

            if (snapshot.isEmpty) break

            snapshot.documents.forEach { document ->
                envelopeFrom(document.data)?.let { envelope ->
                    if (envelope.cursorPosition > changedSince) {
                        results += envelope
                    }
                } ?: Log.w(TAG, "Skipped malformed delta document: ${document.id}")
            }
            val lastDocument = snapshot.documents.last()
            val lastUpdatedAt = readInt64(lastDocument.data?.get("updatedAt")) ?: break
            lastSeen = SyncDeltaCursor(updatedAt = lastUpdatedAt, documentId = lastDocument.id)

            if (snapshot.size() < pageSize) break
        }

        return results
    }

    suspend fun fetchEnvelopes(userId: String, changedSince: Long): List<SyncEntityEnvelope> {
        return fetchEnvelopes(userId, SyncDeltaCursor.fromLegacy(changedSince))
    }

    suspend fun purgeTombstonesOlderThan(retentionMillis: Long, now: Long, userId: String) {
        val cutoff = now - retentionMillis
        val collection = entitiesCollection(userId)
        val snapshot = collection
            .whereLessThan("deletedAt", cutoff)
            .limit(500)
            .get()
            .await()

        if (snapshot.isEmpty) return

        var index = 0
        val documents = snapshot.documents
        while (index < documents.size) {
            val batch = firestore.batch()
            val end = minOf(index + MAX_BATCH_OPERATIONS, documents.size)
            for (document in documents.subList(index, end)) {
                batch.delete(document.reference)
            }
            batch.commit().await()
            index = end
        }
    }

    suspend fun clearLegacyChunkedSnapshot(userId: String) {
        val manifest = firestore.collection("users").document(userId).collection("sync").document("default")
        val chunks = manifest.collection("chunks").get().await()
        var batch = firestore.batch()
        var writeCount = 0
        for (chunk in chunks.documents) {
            batch.delete(chunk.reference)
            writeCount += 1
            if (writeCount >= MAX_BATCH_OPERATIONS) {
                batch.commit().await()
                batch = firestore.batch()
                writeCount = 0
            }
        }
        batch.delete(manifest)
        batch.commit().await()
    }

    suspend fun deleteAllUserData(userId: String) {
        deleteDocumentsInCollection(entitiesCollection(userId))

        val manifest = firestore.collection("users").document(userId).collection("sync").document("default")
        deleteDocumentsInCollection(manifest.collection("chunks"))

        val batch = firestore.batch()
        batch.delete(manifest)
        batch.delete(firestore.collection("users").document(userId))
        batch.commit().await()
    }

    private suspend fun deleteDocumentsInCollection(collection: CollectionReference) {
        while (true) {
            val page = collection.limit(MAX_BATCH_OPERATIONS.toLong()).get().await()
            if (page.isEmpty) return
            var batch = firestore.batch()
            var writeCount = 0
            page.documents.forEach { document ->
                batch.delete(document.reference)
                writeCount += 1
                if (writeCount >= MAX_BATCH_OPERATIONS) {
                    batch.commit().await()
                    batch = firestore.batch()
                    writeCount = 0
                }
            }
            if (writeCount > 0) {
                batch.commit().await()
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
    }
}
