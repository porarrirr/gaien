package com.studyapp.sync

data class SyncDeltaCursor(
    val updatedAt: Long = 0L,
    val documentId: String = ""
) : Comparable<SyncDeltaCursor> {
    override fun compareTo(other: SyncDeltaCursor): Int {
        val timeCompare = updatedAt.compareTo(other.updatedAt)
        if (timeCompare != 0) return timeCompare
        return documentId.compareTo(other.documentId)
    }

    fun isAfter(other: SyncDeltaCursor): Boolean = this > other

    fun absorb(envelope: SyncEntityEnvelope): SyncDeltaCursor {
        val candidate = envelope.cursorPosition
        return if (candidate > this) candidate else this
    }

    fun absorbAll(envelopes: Collection<SyncEntityEnvelope>): SyncDeltaCursor {
        return envelopes.fold(this) { cursor, envelope -> cursor.absorb(envelope) }
    }

    companion object {
        val ZERO = SyncDeltaCursor()

        fun fromLegacy(updatedAt: Long): SyncDeltaCursor = SyncDeltaCursor(updatedAt = updatedAt)
    }
}

val SyncEntityEnvelope.cursorPosition: SyncDeltaCursor
    get() = SyncDeltaCursor(updatedAt = updatedAt, documentId = documentId)
