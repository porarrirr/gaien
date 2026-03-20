package com.studyapp.domain.util

sealed interface Result<out T> {
    data class Success<T>(val data: T) : Result<T>
    data class Error(val exception: Throwable, val message: String? = null) : Result<Nothing>
    
    val isSuccess: Boolean get() = this is Success
    val isFailure: Boolean get() = this is Error
    
    fun getOrNull(): T? = when (this) {
        is Success -> data
        is Error -> null
    }
    
    fun getOrThrow(): T = when (this) {
        is Success -> data
        is Error -> throw exception
    }
    
    fun getErrorMessage(): String? = when (this) {
        is Success -> null
        is Error -> message ?: exception.message
    }
    
    fun <R> map(transform: (T) -> R): Result<R> = when (this) {
        is Success -> Success(transform(data))
        is Error -> this
    }
    
    fun <R> flatMap(transform: (T) -> Result<R>): Result<R> = when (this) {
        is Success -> transform(data)
        is Error -> this
    }
    
    fun onSuccess(action: (T) -> Unit): Result<T> {
        if (this is Success) action(data)
        return this
    }
    
    fun onError(action: (Error) -> Unit): Result<T> {
        if (this is Error) action(this)
        return this
    }
    
    fun onFailure(action: (Throwable) -> Unit): Result<T> {
        if (this is Error) action(exception)
        return this
    }
    
    companion object {
        fun <T> of(block: () -> T): Result<T> = try {
            Success(block())
        } catch (e: Exception) {
            Error(e)
        }
    }
}