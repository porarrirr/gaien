package com.studyapp.sync

import android.util.Log
import com.google.firebase.firestore.CollectionReference
import com.google.firebase.firestore.FieldPath
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.Timestamp
import com.studyapp.domain.usecase.AppData
import kotlinx.coroutines.tasks.await
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class FirestoreDeltaSyncStore @Inject constructor(
    private val firestore: FirebaseFirestore
) {
    data class FetchResult(
        val envelopes: List<SyncEntityEnvelope>,
        val cursor: SyncServerCursor
    )

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
                .await()

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

    suspend fun recordClientFlags(flags: Map<String, Any>, userId: String) {
        val document = firestore.collection("users").document(userId)
        val snapshot = document.get().await()
        val payload = (snapshot.get("clientFlags") as? Map<*, *>)
            ?.entries
            ?.mapNotNull { (key, value) -> (key as? String)?.let { it to value } }
            ?.toMap()
            ?.toMutableMap()
            ?: mutableMapOf()
        payload.putAll(flags)
        payload["lastSeenAt"] = System.currentTimeMillis()
        payload["appDataSchemaVersion"] = AppData.CURRENT_SCHEMA_VERSION
        document.set(
            mapOf(
                "clientFlags" to payload,
                "clientFlagsUpdatedAt" to FieldValue.serverTimestamp()
            ),
            com.google.firebase.firestore.SetOptions.merge()
        ).await()
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
