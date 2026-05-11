import FirebaseAuth
import Foundation

@MainActor
final class FirebaseAuthRepository: ObservableObject, AuthRepository {
    @Published private(set) var session: AuthSession?
    private let auth: Auth
    private let logger: AppLogger?
    private var stateDidChangeHandle: AuthStateDidChangeListenerHandle?

    init(logger: AppLogger? = nil) {
        self.auth = Auth.auth()
        self.logger = logger
        self.session = self.auth.currentUser.map(Self.makeSession(from:))
        self.stateDidChangeHandle = self.auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.applyAuthStateChange(user)
            }
        }
    }

    init(auth: Auth, logger: AppLogger? = nil) {
        self.auth = auth
        self.logger = logger
        self.session = auth.currentUser.map(Self.makeSession(from:))
        self.stateDidChangeHandle = auth.addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.applyAuthStateChange(user)
            }
        }
    }

    func signIn(email: String, password: String) async throws {
        logger?.log(category: .auth, message: "Firebase sign-in started", details: "emailProvided=\(!email.isEmpty)")
        let result = try await auth.signIn(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
        logger?.log(category: .auth, message: "Firebase sign-in succeeded", details: "emailVerified=\(result.user.isEmailVerified)")
    }

    func signUp(email: String, password: String) async throws {
        logger?.log(category: .auth, message: "Firebase sign-up started", details: "emailProvided=\(!email.isEmpty)")
        let result = try await auth.createUser(withEmail: email, password: password)
        let token = try await result.user.getIDToken()
        session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
        logger?.log(category: .auth, message: "Firebase sign-up succeeded", details: "emailVerified=\(result.user.isEmailVerified)")
    }

    func signOut() async throws {
        logger?.log(category: .auth, message: "Firebase sign-out started")
        try auth.signOut()
        session = nil
        logger?.log(category: .auth, message: "Firebase sign-out succeeded")
    }

    private static func makeSession(from user: User) -> AuthSession {
        AuthSession(localId: user.uid, email: user.email ?? "", idToken: "", refreshToken: "")
    }

    private func applyAuthStateChange(_ user: User?) {
        let nextSession = user.map(Self.makeSession(from:))
        guard session != nextSession else { return }
        session = nextSession
        logger?.log(
            category: .auth,
            message: "Firebase auth state changed",
            details: "authenticated=\(user != nil)"
        )
    }
}

