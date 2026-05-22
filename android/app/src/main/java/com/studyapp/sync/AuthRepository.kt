package com.studyapp.sync

import kotlinx.coroutines.flow.StateFlow

interface AuthRepository {
    val session: StateFlow<AuthSession?>

    suspend fun signIn(email: String, password: String)

    suspend fun signUp(email: String, password: String)

    suspend fun sendPasswordReset(email: String)

    suspend fun reauthenticate(password: String)

    suspend fun deleteAccount(password: String)

    suspend fun signOut()
}

