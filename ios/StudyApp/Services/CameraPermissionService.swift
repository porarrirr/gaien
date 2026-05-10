import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// Result of a camera permission request, framed in product terms instead
/// of raw `AVAuthorizationStatus`.
enum CameraPermissionResult {
    case authorized
    /// Permission is missing and the user should be directed to Settings.
    case denied(message: String)
    /// The device can't use the camera at all (no AVFoundation, restricted hardware, unknown state).
    case unavailable(message: String)
}

@MainActor
struct CameraPermissionService {
    let logger: AppLogger

    init(logger: AppLogger) {
        self.logger = logger
    }

    /// Requests access to the camera, prompting the user if the authorization
    /// status is still undetermined. Safe to call off-main-thread callers via `await`.
    func requestAccess() async -> CameraPermissionResult {
        #if canImport(AVFoundation)
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            logger.log(category: .barcode, message: "Camera permission already authorized")
            return .authorized
        case .notDetermined:
            logger.log(category: .barcode, message: "Requesting camera permission")
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            if granted {
                logger.log(category: .barcode, message: "Camera permission granted")
                return .authorized
            }
            logger.log(category: .barcode, level: .warning, message: "Camera permission denied by user")
            return .denied(message: Self.deniedMessage)
        case .denied, .restricted:
            logger.log(
                category: .barcode,
                level: .warning,
                message: "Camera permission unavailable",
                details: "status=\(AVCaptureDevice.authorizationStatus(for: .video).rawValue)"
            )
            return .denied(message: Self.deniedMessage)
        @unknown default:
            logger.log(category: .barcode, level: .warning, message: "Unknown camera authorization status")
            return .unavailable(message: "この端末ではバーコード読み取りを開始できませんでした。")
        }
        #else
        logger.log(category: .barcode, level: .warning, message: "AVFoundation unavailable for barcode scanner")
        return .unavailable(message: "この端末ではバーコード読み取りを利用できません。")
        #endif
    }

    private static let deniedMessage = "カメラへのアクセスが許可されていません。設定アプリでカメラを許可してください。"
}
