package com.studyapp.data.service

import android.util.Log
import com.studyapp.BuildConfig
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.OkHttpClient
import okhttp3.HttpUrl.Companion.toHttpUrlOrNull
import okhttp3.Request
import org.json.JSONObject
import java.io.IOException
import javax.inject.Inject
import javax.inject.Singleton

private const val TAG = "GoogleBooksService"
private const val BASE_URL = "https://www.googleapis.com/books/v1/volumes"

sealed class BookApiError : Exception() {
    data object BookNotFound : BookApiError() {
        private fun readResolve(): Any = BookNotFound
        override val message: String = "書籍が見つかりませんでした"
    }
    data class HttpError(val statusCode: Int, override val message: String) : BookApiError()
    data class NetworkError(override val message: String, override val cause: Throwable?) : BookApiError()
    data class ParseError(override val message: String, override val cause: Throwable?) : BookApiError()
    data class UnknownError(override val message: String, override val cause: Throwable?) : BookApiError()
}

data class BookInfo(
    val title: String,
    val authors: List<String>,
    val publisher: String?,
    val publishedDate: String?,
    val pageCount: Int?,
    val thumbnailUrl: String?
)

@Singleton
class GoogleBooksService @Inject constructor(
    private val okHttpClient: OkHttpClient
) {
    private val apiKey: String? = try {
        System.getenv("GOOGLE_BOOKS_API_KEY")
    } catch (e: Exception) {
        if (BuildConfig.DEBUG) {
            Log.w(TAG, "Failed to access Google Books API key", e)
        }
        null
    }
    
    suspend fun searchByIsbn(isbn: String): Result<BookInfo> = withContext(Dispatchers.IO) {
        try {
            val url = buildUrl("isbn:$isbn")
            
            val request = Request.Builder().url(url).build()
            
            okHttpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    return@withContext Result.failure(
                        BookApiError.HttpError(response.code, "HTTP error: ${response.code}")
                    )
                }
                
                val responseBody = response.body?.string()
                    ?: return@withContext Result.failure(
                        BookApiError.ParseError("Empty response body", null)
                    )
                
                val json = parseJson(responseBody)
                    ?: return@withContext Result.failure(BookApiError.BookNotFound)
                
                val items = json.optJSONArray("items")
                if (items == null || items.length() == 0) {
                    return@withContext Result.failure(BookApiError.BookNotFound)
                }
                
                val firstItem = items.getJSONObject(0)
                val volumeInfo = firstItem.optJSONObject("volumeInfo")
                    ?: return@withContext Result.failure(
                        BookApiError.ParseError("Missing volumeInfo", null)
                    )
                
                Result.success(parseVolumeInfo(volumeInfo))
            }
        } catch (e: IOException) {
            logFailure("Network error while searching ISBN", e)
            Result.failure(BookApiError.NetworkError(e.message ?: "Network error", e))
        } catch (e: Exception) {
            logFailure("Unexpected error while searching ISBN", e)
            Result.failure(BookApiError.UnknownError(e.message ?: "Unknown error", e))
        }
    }
    
    suspend fun searchByTitle(title: String): Result<List<BookInfo>> = withContext(Dispatchers.IO) {
        try {
            val url = buildUrl("intitle:$title", maxResults = 10)
            
            val request = Request.Builder().url(url).build()
            
            okHttpClient.newCall(request).execute().use { response ->
                if (!response.isSuccessful) {
                    return@withContext Result.failure(
                        BookApiError.HttpError(response.code, "HTTP error: ${response.code}")
                    )
                }
                
                val responseBody = response.body?.string()
                    ?: return@withContext Result.failure(
                        BookApiError.ParseError("Empty response body", null)
                    )
                
                val json = parseJson(responseBody)
                    ?: return@withContext Result.success(emptyList())
                
                val totalItems = json.optInt("totalItems", 0)
                if (totalItems == 0) {
                    return@withContext Result.success(emptyList())
                }
                
                val items = json.optJSONArray("items")
                if (items == null || items.length() == 0) {
                    return@withContext Result.success(emptyList())
                }
                
                val books = mutableListOf<BookInfo>()
                for (i in 0 until items.length()) {
                    val item = items.getJSONObject(i)
                    val volumeInfo = item.optJSONObject("volumeInfo")
                    if (volumeInfo != null) {
                        books.add(parseVolumeInfo(volumeInfo))
                    }
                }
                
                Result.success(books)
            }
        } catch (e: IOException) {
            logFailure("Network error while searching title", e)
            Result.failure(BookApiError.NetworkError(e.message ?: "Network error", e))
        } catch (e: Exception) {
            logFailure("Unexpected error while searching title", e)
            Result.failure(BookApiError.UnknownError(e.message ?: "Unknown error", e))
        }
    }
    
    private fun buildUrl(query: String, maxResults: Int? = null): String {
        val builder = BASE_URL.toHttpUrlOrNull()?.newBuilder()
            ?: throw IllegalStateException("Invalid Google Books base URL")
        builder.addQueryParameter("q", query)
        maxResults?.let {
            builder.addQueryParameter("maxResults", it.toString())
        }
        apiKey?.let {
            builder.addQueryParameter("key", it)
        }
        return builder.build().toString()
    }
    
    private fun parseJson(jsonString: String): JSONObject? {
        return try {
            JSONObject(jsonString)
        } catch (e: Exception) {
            logFailure("Failed to parse Google Books response", e)
            null
        }
    }
    
    private fun parseVolumeInfo(volumeInfo: JSONObject): BookInfo {
        val title = volumeInfo.optString("title", "")
        val authors = if (volumeInfo.has("authors")) {
            val authorsArray = volumeInfo.getJSONArray("authors")
            (0 until authorsArray.length()).map { authorsArray.getString(it) }
        } else {
            emptyList()
        }
        val publisher = volumeInfo.optString("publisher", null)
        val publishedDate = volumeInfo.optString("publishedDate", null)
        val pageCount = volumeInfo.optInt("pageCount", 0)
        val thumbnailUrl = volumeInfo.optJSONObject("imageLinks")?.optString("thumbnail", null)
        
        return BookInfo(
            title = title,
            authors = authors,
            publisher = publisher,
            publishedDate = publishedDate,
            pageCount = if (pageCount > 0) pageCount else null,
            thumbnailUrl = thumbnailUrl
        )
    }

    private fun logFailure(message: String, throwable: Throwable) {
        if (BuildConfig.DEBUG) {
            Log.e(TAG, message, throwable)
        }
    }
}
