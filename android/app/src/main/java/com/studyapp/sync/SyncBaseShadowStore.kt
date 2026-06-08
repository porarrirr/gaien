package com.studyapp.sync

import android.content.Context
import com.studyapp.domain.usecase.AppData
import dagger.hilt.android.qualifiers.ApplicationContext
import java.io.File
import javax.inject.Inject
import javax.inject.Singleton
import org.json.JSONObject

@Singleton
class SyncBaseShadowStore @Inject constructor(
    @ApplicationContext private val context: Context
) {
    fun load(userId: String): AppData? {
        val file = fileFor(userId) ?: return null
        if (!file.exists()) return null
        return AppData.fromJson(JSONObject(file.readText()))
    }

    fun save(appData: AppData, userId: String) {
        val file = fileFor(userId, createDirectory = true) ?: return
        atomicWrite(file, appData.toJson().toString())
    }

    fun delete(userId: String) {
        fileFor(userId)?.delete()
        revisionFileFor(userId)?.delete()
    }

    fun bootstrapIfNeeded(userId: String, local: AppData) {
        if (load(userId) == null) {
            save(local, userId)
        }
    }

    private fun fileFor(userId: String, createDirectory: Boolean = false): File? {
        val directory = File(context.filesDir, "sync_bases")
        if (createDirectory) directory.mkdirs()
        val safeUserId = userId.replace("/", "_")
        return File(directory, "$safeUserId.json")
    }

    fun loadRevisionMap(userId: String): Map<String, String> {
        val file = revisionFileFor(userId) ?: return emptyMap()
        if (!file.exists()) return emptyMap()
        val json = JSONObject(file.readText())
        return buildMap {
            json.keys().forEach { key ->
                val revision = json.optString(key)
                if (revision.isNotEmpty()) put(key, revision)
            }
        }
    }

    fun saveRevisionMap(userId: String, revisions: Map<String, String>) {
        val file = revisionFileFor(userId, createDirectory = true) ?: return
        atomicWrite(file, JSONObject(revisions).toString())
    }

    fun mergeRevisionMap(userId: String, envelopes: Collection<SyncEntityEnvelope>) {
        val revisions = loadRevisionMap(userId).toMutableMap()
        envelopes.forEach { envelope ->
            val revision = envelope.revisionId ?: envelope.contentHash
            if (!revision.isNullOrEmpty()) revisions[envelope.documentId] = revision
        }
        saveRevisionMap(userId, revisions)
    }

    private fun revisionFileFor(userId: String, createDirectory: Boolean = false): File? {
        val directory = File(context.filesDir, "sync_base_revisions")
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
