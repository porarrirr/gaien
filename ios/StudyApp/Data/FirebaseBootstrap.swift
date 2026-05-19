import FirebaseCore
import Foundation

enum FirebaseConfigurationStatus: Equatable {
    case configured
    case unavailable(String)

    var isConfigured: Bool {
        if case .configured = self { return true }
        return false
    }

    var logDescription: String {
        switch self {
        case .configured:
            return "configured=true"
        case .unavailable(let reason):
            return "configured=false reason=\(reason)"
        }
    }

    var unavailableMessage: String? {
        switch self {
        case .configured:
            return nil
        case .unavailable(let reason):
            switch reason {
            case "missing-google-service-info":
                return "Firebase 設定ファイルが見つからないため、クラウド同期は利用できません"
            case "unreadable-google-service-info":
                return "Firebase 設定ファイルを読み込めないため、クラウド同期は利用できません"
            case "invalid-google-service-info":
                return "Firebase 設定ファイルが未設定または無効なため、クラウド同期は利用できません"
            default:
                return "Firebase 設定が完了していないため、クラウド同期は利用できません"
            }
        }
    }
}

enum FirebaseBootstrap {
    private(set) static var status: FirebaseConfigurationStatus = .unavailable("not-started")

    static func configureIfAvailable() {
        if FirebaseApp.app() != nil {
            status = .configured
            return
        }

        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") else {
            status = .unavailable("missing-google-service-info")
            return
        }

        guard let plist = NSDictionary(contentsOfFile: path) as? [String: Any] else {
            status = .unavailable("unreadable-google-service-info")
            return
        }

        guard isUsableFirebasePlist(plist) else {
            status = .unavailable("invalid-google-service-info")
            return
        }

        FirebaseApp.configure()
        status = .configured
    }

    private static func isUsableFirebasePlist(_ plist: [String: Any]) -> Bool {
        guard
            let appId = plist["GOOGLE_APP_ID"] as? String,
            let apiKey = plist["API_KEY"] as? String,
            let projectId = plist["PROJECT_ID"] as? String,
            let senderId = plist["GCM_SENDER_ID"] as? String,
            !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !projectId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            !senderId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return false
        }

        let pattern = #"^1:[0-9]+:ios:[0-9a-fA-F]+$"#
        return appId.range(of: pattern, options: .regularExpression) != nil
    }
}
