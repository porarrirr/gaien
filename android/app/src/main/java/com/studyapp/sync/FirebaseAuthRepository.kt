package com.studyapp.sync

import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

@Singleton
class FirebaseAuthRepository @Inject constructor(
    private val firebaseRestClient: FirebaseRestClient,
    private val syncPreferences: SyncPreferences
) : AuthRepository {
    private val _session = MutableStateFlow(syncPreferences.loadSession())
    override val session: StateFlow<AuthSession?> = _session.asStateFlow()

    override suspend fun signIn(email: String, password: String) {
        val session = firebaseRestClient.signIn(email, password)
        syncPreferences.saveSession(session)
        _session.value = session
    }

    override suspend fun signUp(email: String, password: String) {
        val session = firebaseRestClient.signUp(email, password)
        syncPreferences.saveSession(session)
        _session.value = session
    }

    override suspend fun signOut() {
        syncPreferences.saveSession(null)
        _session.value = null
    }
}

