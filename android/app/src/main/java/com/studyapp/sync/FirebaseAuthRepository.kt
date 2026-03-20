package com.studyapp.sync

import com.google.firebase.auth.FirebaseAuth
import javax.inject.Inject
import javax.inject.Singleton
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.tasks.await

@Singleton
class FirebaseAuthRepository @Inject constructor(
    private val firebaseAuth: FirebaseAuth
) : AuthRepository {
    private val _session = MutableStateFlow(firebaseAuth.currentUser?.toSession())
    override val session: StateFlow<AuthSession?> = _session.asStateFlow()

    init {
        firebaseAuth.addAuthStateListener { auth ->
            _session.value = auth.currentUser?.toSession()
        }
    }

    override suspend fun signIn(email: String, password: String) {
        firebaseAuth.signInWithEmailAndPassword(email, password).await()
        val user = firebaseAuth.currentUser
        val token = user?.getIdToken(true)?.await()?.token.orEmpty()
        _session.value = user?.toSession(token)
    }

    override suspend fun signUp(email: String, password: String) {
        firebaseAuth.createUserWithEmailAndPassword(email, password).await()
        val user = firebaseAuth.currentUser
        val token = user?.getIdToken(true)?.await()?.token.orEmpty()
        _session.value = user?.toSession(token)
    }

    override suspend fun signOut() {
        firebaseAuth.signOut()
        _session.value = null
    }

    private fun com.google.firebase.auth.FirebaseUser.toSession(idToken: String = ""): AuthSession {
        return AuthSession(
            localId = uid,
            email = email.orEmpty(),
            idToken = idToken,
            refreshToken = ""
        )
    }
}
