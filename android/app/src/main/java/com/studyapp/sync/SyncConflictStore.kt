package com.studyapp.sync

import android.content.Context
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton
import org.json.JSONArray
import org.json.JSONObject

@Singleton
class SyncConflictStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun load(userId: String): List<SyncConflict> {
        val file = fileFor(userId) ?: return emptyList()
        if (!file.exists()) return emptyList()
        val array = JSONArray(file.readText())
        return buildList {
            for (index in 0 until array.length()) {
                array.optJSONObject(index)?.toSyncConflict()?.let(::add)
            }
        }
    }

    fun save(conflicts: List<SyncConflict>, userId: String) {
        val file = fileFor(userId, createDirectory = true) ?: return
        if (conflicts.isEmpty()) {
            file.delete()
            return
        }
        val array = JSONArray()
        conflicts.forEach { array.put(it.toJson()) }
        atomicWrite(file, array.toString())
    }

    fun delete(userId: String) {
        fileFor(userId)?.delete()
    }

    private fun fileFor(userId: String, createDirectory: Boolean = false): File? {
        val directory = File(context.filesDir, "sync_conflicts")
        if (createDirectory) directory.mkdirs()
        val safeUserId = userId.replace("/", "_")
        return File(directory, "$safeUserId.json")
    }

    private fun atomicWrite(file: File, contents: String) {
        val temp = File(file.parentFile, "${file.name}.tmp")
        temp.writeText(contents)
        if (!temp.renameTo(file)) {
            file.writeText(contents)
            temp.delete()
        }
    }
}

private fun SyncConflict.toJson(): JSONObject {
    return JSONObject().apply {
        put("kind", kind.rawValue)
        put("syncId", syncId)
        put("title", title)
        put("summary", summary)
        put("conflictFields", JSONArray(conflictFields.map { it.name }))
        put("baseJson", baseJson)
        put("localJson", localJson)
        put("remoteJson", remoteJson)
        put("suggestedMergedJson", suggestedMergedJson)
        put("detectedAt", detectedAt)
    }
}

private fun JSONObject.toSyncConflict(): SyncConflict? {
    val kindRaw = optString("kind")
    val kind = SyncEntityKind.fromRawValue(kindRaw) ?: return null
    val syncId = optString("syncId")
    if (syncId.isEmpty()) return null
    val fields = optJSONArray("conflictFields")?.let { array ->
        buildList {
            for (index in 0 until array.length()) {
                runCatching { SyncConflictField.valueOf(array.getString(index)) }.getOrNull()?.let(::add)
            }
        }
    }.orEmpty()
    return SyncConflict(
        kind = kind,
        syncId = syncId,
        title = optString("title"),
        summary = optString("summary"),
        conflictFields = fields,
        baseJson = optString("baseJson").takeIf { it.isNotEmpty() },
        localJson = optString("localJson"),
        remoteJson = optString("remoteJson"),
        suggestedMergedJson = optString("suggestedMergedJson"),
        detectedAt = optLong("detectedAt")
    )
}
