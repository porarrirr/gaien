package com.studyapp.sync

import com.google.firebase.auth.EmailAuthProvider
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

    override suspend fun sendPasswordReset(email: String) {
        val normalized = email.trim()
        require(normalized.isNotEmpty()) { "メールアドレスを入力してください" }
        firebaseAuth.sendPasswordResetEmail(normalized).await()
    }

    override suspend fun reauthenticate(password: String) {
        val user = firebaseAuth.currentUser
            ?: throw IllegalStateException("サインインしているアカウントがありません")
        val email = user.email?.trim().orEmpty()
        require(email.isNotEmpty()) { "メールアドレスが見つかりません" }
        require(password.isNotEmpty()) { "パスワードを入力してください" }
        val credential = EmailAuthProvider.getCredential(email, password)
        user.reauthenticate(credential).await()
    }

    override suspend fun deleteAccount(password: String) {
        val user = firebaseAuth.currentUser
            ?: throw IllegalStateException("サインインしているアカウントがありません")
        if (password.isNotEmpty()) {
            reauthenticate(password)
        }
        user.delete().await()
        _session.value = null
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
