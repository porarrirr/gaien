package com.studyapp.sync

import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.auth.FirebaseUser
import com.google.firebase.firestore.CollectionReference
import com.google.firebase.firestore.DocumentReference
import com.google.firebase.firestore.FirebaseFirestore
import com.studyapp.domain.usecase.AppData
import com.studyapp.domain.usecase.ExportImportDataUseCase
import io.mockk.coEvery
import io.mockk.every
import io.mockk.mockk
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.test.runTest
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class FirebaseSyncRepositoryTest {

    @Test
    fun `syncNow returns helpful message when Firestore permission is denied`() = runTest {
        val repository = createRepositoryWithDeniedManifestRead()

        val error = runCatching { repository.syncNow() }.exceptionOrNull()

        requireNotNull(error)
        assertEquals(
            "クラウド同期に失敗しました。Firestoreルールが未反映か、このアカウントに十分な権限がありません。",
            error.message
        )
        assertEquals(error.message, repository.status.value.errorMessage)
    }

    @Test
    fun `importLocalDataToCloud returns helpful message when Firestore permission is denied`() = runTest {
        val repository = createRepositoryWithDeniedManifestRead()

        val error = runCatching { repository.importLocalDataToCloud() }.exceptionOrNull()

        requireNotNull(error)
        assertEquals(
            "クラウド同期に失敗しました。Firestoreルールが未反映か、このアカウントに十分な権限がありません。",
            error.message
        )
        assertEquals(error.message, repository.status.value.errorMessage)
    }

    @Test
    fun `syncNow returns helpful message when user is not signed in`() = runTest {
        val authRepository = object : AuthRepository {
            override val session = MutableStateFlow<AuthSession?>(null)

            override suspend fun signIn(email: String, password: String) = Unit

            override suspend fun signUp(email: String, password: String) = Unit

            override suspend fun signOut() = Unit
        }
        val firebaseAuth = mockk<FirebaseAuth> {
            every { currentUser } returns null
        }
        val repository = FirebaseSyncRepository(
            authRepository = authRepository,
            firebaseAuth = firebaseAuth,
            firebaseFirestore = mockk(relaxed = true),
            syncPreferences = mockk<SyncPreferences> {
                every { getLastSyncAt() } returns null
            },
            exportImportDataUseCase = mockk(relaxed = true),
            writeLock = AppDataWriteLock()
        )

        val error = runCatching { repository.syncNow() }.exceptionOrNull()

        requireNotNull(error)
        assertEquals("同期するには先にサインインしてください。", error.message)
        assertTrue(repository.status.value.errorMessage?.contains("サインイン") == true)
    }

    private fun createRepositoryWithDeniedManifestRead(): FirebaseSyncRepository {
        val authSession = AuthSession(
            localId = "uid-123",
            email = "user@example.com",
            idToken = "token",
            refreshToken = ""
        )
        val authRepository = object : AuthRepository {
            override val session = MutableStateFlow<AuthSession?>(authSession)

            override suspend fun signIn(email: String, password: String) = Unit

            override suspend fun signUp(email: String, password: String) = Unit

            override suspend fun signOut() = Unit
        }
        val firebaseUser = mockk<FirebaseUser>()
        val firebaseAuth = mockk<FirebaseAuth> {
            every { currentUser } returns firebaseUser
        }
        val usersCollection = mockk<CollectionReference>()
        val userDocument = mockk<DocumentReference>()
        val syncCollection = mockk<CollectionReference>()
        val manifestDocument = mockk<DocumentReference>()
        val firestore = mockk<FirebaseFirestore>()
        val permissionDenied = IllegalStateException("PERMISSION_DENIED: Missing or insufficient permissions.")

        every { firestore.collection("users") } returns usersCollection
        every { usersCollection.document("uid-123") } returns userDocument
        every { userDocument.collection("sync") } returns syncCollection
        every { syncCollection.document("default") } returns manifestDocument
        every { manifestDocument.get() } returns Tasks.forException(permissionDenied)

        val exportImportDataUseCase = mockk<ExportImportDataUseCase> {
            coEvery { exportAppDataWithoutWriteLock() } returns emptyAppData()
        }
        val syncPreferences = mockk<SyncPreferences> {
            every { getLastSyncAt() } returns null
        }

        return FirebaseSyncRepository(
            authRepository = authRepository,
            firebaseAuth = firebaseAuth,
            firebaseFirestore = firestore,
            syncPreferences = syncPreferences,
            exportImportDataUseCase = exportImportDataUseCase,
            writeLock = AppDataWriteLock()
        )
    }

    private fun emptyAppData(): AppData {
        return AppData(
            subjects = emptyList(),
            materials = emptyList(),
            sessions = emptyList(),
            goals = emptyList(),
            exams = emptyList(),
            plans = emptyList(),
            exportDate = 0L
        )
    }
}
