package com.studyapp.data.repository

import com.studyapp.data.service.GoogleBooksService
import com.studyapp.domain.model.BookInfo
import com.studyapp.domain.repository.BookSearchRepository
import com.studyapp.domain.util.Result
import javax.inject.Inject
import javax.inject.Singleton

@Singleton
class BookSearchRepositoryImpl @Inject constructor(
    private val googleBooksService: GoogleBooksService
) : BookSearchRepository {

    override suspend fun searchByIsbn(isbn: String): Result<BookInfo> {
        val serviceResult = googleBooksService.searchByIsbn(isbn)
        return if (serviceResult.isSuccess) {
            val bookInfo = serviceResult.getOrThrow()
            Result.Success(
                BookInfo(
                    title = bookInfo.title,
                    authors = bookInfo.authors,
                    publisher = bookInfo.publisher,
                    publishedDate = bookInfo.publishedDate,
                    pageCount = bookInfo.pageCount,
                    thumbnailUrl = bookInfo.thumbnailUrl
                )
            )
        } else {
            val exception = serviceResult.exceptionOrNull() ?: Exception("Book search failed")
            Result.Error(exception, exception.message ?: "Book search failed")
        }
    }
}
