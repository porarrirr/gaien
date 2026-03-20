package com.studyapp.sync

import com.studyapp.BuildConfig
import javax.inject.Inject
import javax.inject.Singleton
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject

@Singleton
class FirebaseRestClient @Inject constructor(
    private val okHttpClient: OkHttpClient
) {
    private val jsonMediaType = "application/json; charset=utf-8".toMediaType()

    fun isConfigured(): Boolean {
        return BuildConfig.FIREBASE_API_KEY.isNotBlank() && BuildConfig.FIREBASE_PROJECT_ID.isNotBlank()
    }

    suspend fun signIn(email: String, password: String): AuthSession {
        ensureConfigured()
        val payload = JSONObject()
            .put("email", email)
            .put("password", password)
            .put("returnSecureToken", true)
        val url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${BuildConfig.FIREBASE_API_KEY}"
        return executeAuth(url, payload)
    }

    suspend fun signUp(email: String, password: String): AuthSession {
        ensureConfigured()
        val payload = JSONObject()
            .put("email", email)
            .put("password", password)
            .put("returnSecureToken", true)
        val url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=${BuildConfig.FIREBASE_API_KEY}"
        return executeAuth(url, payload)
    }

    suspend fun loadSnapshot(session: AuthSession): String? {
        ensureConfigured()
        val request = Request.Builder()
            .url("https://firestore.googleapis.com/v1/projects/${BuildConfig.FIREBASE_PROJECT_ID}/databases/(default)/documents/users/${session.localId}/sync/default")
            .get()
            .header("Authorization", "Bearer ${session.idToken}")
            .build()
        okHttpClient.newCall(request).execute().use { response ->
            if (response.code == 404) {
                return null
            }
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IllegalStateException(parseFirebaseError(body))
            }
            val json = JSONObject(body)
            return json.optJSONObject("fields")
                ?.optJSONObject("payload")
                ?.optString("stringValue")
                ?.takeIf { it.isNotBlank() }
        }
    }

    suspend fun saveSnapshot(session: AuthSession, payload: String, updatedAt: Long) {
        ensureConfigured()
        val body = JSONObject()
            .put(
                "fields",
                JSONObject()
                    .put("payload", JSONObject().put("stringValue", payload))
                    .put("updatedAt", JSONObject().put("integerValue", updatedAt.toString()))
            )
        val request = Request.Builder()
            .url("https://firestore.googleapis.com/v1/projects/${BuildConfig.FIREBASE_PROJECT_ID}/databases/(default)/documents/users/${session.localId}/sync/default")
            .patch(body.toString().toRequestBody(jsonMediaType))
            .header("Authorization", "Bearer ${session.idToken}")
            .build()
        okHttpClient.newCall(request).execute().use { response ->
            val responseBody = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IllegalStateException(parseFirebaseError(responseBody))
            }
        }
    }

    private fun executeAuth(url: String, payload: JSONObject): AuthSession {
        val request = Request.Builder()
            .url(url)
            .post(payload.toString().toRequestBody(jsonMediaType))
            .build()
        okHttpClient.newCall(request).execute().use { response ->
            val body = response.body?.string().orEmpty()
            if (!response.isSuccessful) {
                throw IllegalStateException(parseFirebaseError(body))
            }
            val json = JSONObject(body)
            return AuthSession(
                localId = json.getString("localId"),
                email = json.optString("email"),
                idToken = json.getString("idToken"),
                refreshToken = json.getString("refreshToken")
            )
        }
    }

    private fun ensureConfigured() {
        check(isConfigured()) {
            "Firebase configuration is missing. Set FIREBASE_API_KEY and FIREBASE_PROJECT_ID."
        }
    }

    private fun parseFirebaseError(body: String): String {
        return runCatching {
            JSONObject(body).getJSONObject("error").optString("message")
        }.getOrNull().takeIf { !it.isNullOrBlank() } ?: "Firebase request failed"
    }
}

