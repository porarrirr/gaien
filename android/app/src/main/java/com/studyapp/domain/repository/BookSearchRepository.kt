package com.studyapp.domain.repository

import com.studyapp.domain.model.BookInfo
import com.studyapp.domain.util.Result

interface BookSearchRepository {
    suspend fun searchByIsbn(isbn: String): Result<BookInfo>
}
