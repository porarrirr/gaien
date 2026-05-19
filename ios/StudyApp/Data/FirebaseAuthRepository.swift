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
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            let token = try await result.user.getIDToken()
            session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
            logger?.log(category: .auth, message: "Firebase sign-in succeeded", details: "emailVerified=\(result.user.isEmailVerified)")
        } catch {
            logger?.log(category: .auth, level: .warning, message: "Firebase sign-in failed", details: Self.authErrorLogDetails(error))
            throw Self.mapAuthError(error, fallback: "サインインに失敗しました")
        }
    }

    func signUp(email: String, password: String) async throws {
        logger?.log(category: .auth, message: "Firebase sign-up started", details: "emailProvided=\(!email.isEmpty)")
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            let token = try await result.user.getIDToken()
            session = AuthSession(localId: result.user.uid, email: result.user.email ?? email, idToken: token, refreshToken: "")
            logger?.log(category: .auth, message: "Firebase sign-up succeeded", details: "emailVerified=\(result.user.isEmailVerified)")
        } catch {
            logger?.log(category: .auth, level: .warning, message: "Firebase sign-up failed", details: Self.authErrorLogDetails(error))
            throw Self.mapAuthError(error, fallback: "アカウント作成に失敗しました")
        }
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

    private static func mapAuthError(_ error: Error, fallback: String) -> ValidationError {
        if let validationError = error as? ValidationError {
            return validationError
        }

        let nsError = error as NSError
        let code = AuthErrorCode(rawValue: nsError.code)
        let message: String
        switch code {
        case .invalidEmail:
            message = "メールアドレスの形式が正しくありません"
        case .wrongPassword, .invalidCredential:
            message = "メールアドレスまたはパスワードが正しくありません"
        case .userNotFound:
            message = "このメールアドレスのアカウントが見つかりません"
        case .emailAlreadyInUse:
            message = "このメールアドレスはすでに使用されています"
        case .weakPassword:
            message = "パスワードは8文字以上で入力してください"
        case .networkError:
            message = "ネットワーク接続を確認して、もう一度お試しください"
        case .operationNotAllowed:
            message = "Firebase Authentication のメール/パスワード認証が有効になっていません"
        case .tooManyRequests:
            message = "試行回数が多すぎます。しばらくしてからもう一度お試しください"
        default:
            if nsError.localizedDescription.localizedCaseInsensitiveContains("auth credential") {
                message = "認証情報を確認できませんでした。アプリを再起動して、もう一度お試しください"
            } else {
                message = fallback
            }
        }
        return ValidationError(message: message)
    }

    private static func authErrorLogDetails(_ error: Error) -> String {
        let nsError = error as NSError
        return "domain=\(nsError.domain) code=\(nsError.code) description=\(nsError.localizedDescription)"
    }
}
