package com.studyapp.sync

import com.studyapp.domain.usecase.AppData
import java.security.MessageDigest
import java.util.UUID
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class SyncRevisionStamper @Inject constructor(
    private val deviceIdentity: SyncDeviceIdentity
) {
    fun stamp(
        envelopes: List<SyncEntityEnvelope>,
        previousBase: AppData?,
        previousRevisions: Map<String, String> = previousRevisionMap(previousBase)
    ): List<SyncEntityEnvelope> {
        val deviceId = deviceIdentity.current
        return envelopes.map { envelope ->
            envelope.copy(
                revisionId = UUID.randomUUID().toString().lowercase(),
                parentRevisionId = previousRevisions[envelope.documentId],
                deviceId = deviceId,
                contentHash = sha256(envelope.json)
            )
        }
    }

    private fun previousRevisionMap(base: AppData?): Map<String, String> {
        if (base == null) return emptyMap()
        return SyncDeltaSerializer.decompose(base).mapNotNull { envelope ->
            val revision = envelope.revisionId ?: envelope.contentHash
            if (revision.isNullOrEmpty()) null else envelope.documentId to revision
        }.toMap()
    }

    private fun sha256(json: String): String {
        val digest = MessageDigest.getInstance("SHA-256").digest(json.toByteArray())
        return digest.joinToString("") { "%02x".format(it) }
    }
}
