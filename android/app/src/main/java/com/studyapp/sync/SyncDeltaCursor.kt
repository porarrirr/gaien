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

data class SyncServerCursor(
    val seconds: Long = 0L,
    val nanoseconds: Int = 0,
    val documentId: String = ""
) : Comparable<SyncServerCursor> {
    override fun compareTo(other: SyncServerCursor): Int {
        val timeCompare = seconds.compareTo(other.seconds)
        if (timeCompare != 0) return timeCompare
        val nanosCompare = nanoseconds.compareTo(other.nanoseconds)
        if (nanosCompare != 0) return nanosCompare
        return documentId.compareTo(other.documentId)
    }

    companion object {
        val ZERO = SyncServerCursor()
    }
}
