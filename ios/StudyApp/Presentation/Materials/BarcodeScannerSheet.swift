import Foundation
import SwiftUI
#if canImport(AVFoundation)
import AVFoundation
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(VisionKit)
import VisionKit
#endif

struct BarcodeScannerSheet: View {
    let onScanned: (String) -> Void
    let onFailure: (String) -> Void
    let logger: AppLogger
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        BarcodeScannerView(
            onScanned: { code in
                onScanned(code)
                dismiss()
            },
            onFailure: { message in
                logger.log(category: .barcode, level: .warning, message: "Scanner reported failure", details: message)
                onFailure(message)
                dismiss()
            },
            onClose: {
                dismiss()
            },
            logger: logger
        )
        .presentationDragIndicator(.hidden)
    }
}

private struct BarcodeScannerView: View {
    let onScanned: (String) -> Void
    let onFailure: (String) -> Void
    let onClose: () -> Void
    let logger: AppLogger
    @State private var scannedCode: String?
    @State private var hasDeliveredScan = false
    @State private var isTorchOn = false
    @State private var scanDeliveryTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 0) {
            BarcodeScannerHeader(onClose: onClose)
            scannerBody
        }
        .background(Color.black.ignoresSafeArea())
        .onDisappear {
            scanDeliveryTask?.cancel()
            turnOffTorchIfNeeded()
        }
    }

    @ViewBuilder
    private var scannerBody: some View {
        #if canImport(VisionKit)
        if #available(iOS 16.0, *), DataScannerViewController.isSupported, DataScannerViewController.isAvailable {
            ZStack {
                ScannerRepresentable(
                    onScanned: handleScannedCode,
                    onFailure: onFailure,
                    logger: logger
                )
                .ignoresSafeArea(edges: .bottom)

                BarcodeScannerCameraOverlay(
                    scannedCode: scannedCode,
                    isTorchOn: isTorchOn,
                    onToggleTorch: toggleTorch
                )
            }
        } else {
            scannerUnavailableState
                .onAppear {
                    logger.log(category: .barcode, level: .warning, message: "VisionKit scanner unavailable", details: "supported=\(DataScannerViewController.isSupported) available=\(DataScannerViewController.isAvailable)")
                }
        }
        #else
        scannerUnavailableState
            .onAppear {
                logger.log(category: .barcode, level: .warning, message: "VisionKit unavailable for barcode scanner")
            }
        #endif
    }

    private var scannerUnavailableState: some View {
        EmptyStateView(
            icon: "barcode.viewfinder",
            title: "バーコードを利用できません",
            description: "この端末ではバーコードスキャンを利用できません。"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private func handleScannedCode(_ code: String) {
        guard !hasDeliveredScan else { return }
        hasDeliveredScan = true
        scannedCode = code
        scanDeliveryTask?.cancel()
        scanDeliveryTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled else { return }
            onScanned(code)
        }
    }

    private func toggleTorch() {
        #if canImport(AVFoundation)
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if device.torchMode == .on {
                device.torchMode = .off
                isTorchOn = false
            } else {
                try device.setTorchModeOn(level: AVCaptureDevice.maxAvailableTorchLevel)
                isTorchOn = true
            }
        } catch {
            logger.log(category: .barcode, level: .warning, message: "Failed to toggle torch", error: error)
        }
        #endif
    }

    private func turnOffTorchIfNeeded() {
        #if canImport(AVFoundation)
        guard isTorchOn, let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            device.torchMode = .off
            isTorchOn = false
        } catch {
            logger.log(category: .barcode, level: .warning, message: "Failed to turn off torch", error: error)
        }
        #endif
    }
}

private struct BarcodeScannerHeader: View {
    let onClose: () -> Void
    @State private var isShowingHelp = false

    var body: some View {
        ZStack {
            Text("バーコード")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(Color(.label))

            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 28, weight: .light))
                        .foregroundStyle(AppColors.green)
                        .frame(width: 52, height: 52)
                }
                .accessibilityLabel("閉じる")

                Spacer()

                Button {
                    isShowingHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 30, weight: .regular))
                        .foregroundStyle(AppColors.green)
                        .frame(width: 52, height: 52)
                }
                .accessibilityLabel("ヘルプ")
            }
            .padding(.horizontal, 28)
        }
        .alert("バーコード読み取り", isPresented: $isShowingHelp) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("書籍の裏表紙にある ISBN バーコードを枠内に合わせてください。読み取り後、自動で検索結果へ進みます。")
        }
        .frame(height: 86)
        .background(
            TopRoundedRectangle(radius: 20)
                .fill(
                    LinearGradient(
                        colors: [AppColors.cardBackground, AppColors.subtleBackground],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
    }
}

private struct BarcodeScannerCameraOverlay: View {
    let scannedCode: String?
    let isTorchOn: Bool
    let onToggleTorch: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let width = min(geometry.size.width - 92, 594)
            let height = min(width * 1.08, geometry.size.height * 0.54)

            ZStack {
                Color.black.opacity(0.22)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    instructionPill
                        .padding(.top, 48)

                    Spacer(minLength: 28)

                    scannerFrame(width: width, height: height)

                    Spacer(minLength: 38)

                    Button(action: onToggleTorch) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 34, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 76, height: 76)
                            .background(Color.black.opacity(0.56), in: Circle())
                    }
                    .accessibilityLabel("ライト")

                    Spacer(minLength: 84)
                }

                if let scannedCode {
                    VStack {
                        Spacer()
                        BarcodeScanCompletePanel(code: scannedCode)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeOut(duration: 0.22), value: scannedCode)
        }
    }

    private var instructionPill: some View {
        Text("ISBNバーコードを枠内に合わせてください")
            .font(.system(size: 18, weight: .medium))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 28)
            .frame(height: 56)
            .background(Color.black.opacity(0.58), in: Capsule())
            .padding(.horizontal, 34)
    }

    private func scannerFrame(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(width: width, height: height)

            Rectangle()
                .fill(AppColors.green)
                .frame(width: width, height: 1.4)

            BarcodeScannerCornerShape()
                .stroke(AppColors.green, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                .frame(width: width, height: height)
        }
    }
}

private struct BarcodeScannerCornerShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cornerLength = min(rect.width, rect.height) * 0.12
        let radius: CGFloat = 28

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + radius + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + radius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + radius + cornerLength, y: rect.minY))

        path.move(to: CGPoint(x: rect.maxX - radius - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + radius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + radius + cornerLength))

        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - radius - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - radius - cornerLength, y: rect.maxY))

        path.move(to: CGPoint(x: rect.minX + radius + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - radius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius - cornerLength))

        return path
    }
}

private struct BarcodeScanCompletePanel: View {
    let code: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(AppColors.green)
                .frame(width: 62, height: 62)
                .overlay(Circle().stroke(AppColors.green, lineWidth: 3))
                .padding(.top, 18)

            VStack(alignment: .leading, spacing: 12) {
                Text("読み取り完了")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(AppColors.green)

                Text("ISBN: \(code)")
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text("検索結果画面に移動します...")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(Color.white.opacity(0.68))
                    .padding(.top, 22)
            }

            Spacer(minLength: 0)
        }
        .padding(.top, 28)
        .padding(.horizontal, 34)
        .padding(.bottom, 76)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            TopRoundedRectangle(radius: 20)
                .fill(Color(hex: 0x111820).opacity(0.96))
        )
    }
}

private struct TopRoundedRectangle: Shape {
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let clampedRadius = min(radius, rect.width / 2, rect.height / 2)

        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + clampedRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + clampedRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - clampedRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + clampedRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}

#if canImport(VisionKit)
@available(iOS 16.0, *)
private struct ScannerRepresentable: UIViewControllerRepresentable {
    let onScanned: (String) -> Void
    let onFailure: (String) -> Void
    let logger: AppLogger

    func makeCoordinator() -> Coordinator {
        Coordinator(onScanned: onScanned, onFailure: onFailure, logger: logger)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        controller.delegate = context.coordinator
        context.coordinator.attach(controller)
        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.attach(uiViewController)
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        coordinator.stopScanning()
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        let onScanned: (String) -> Void
        let onFailure: (String) -> Void
        let logger: AppLogger
        weak var controller: DataScannerViewController?
        private var hasCompletedScan = false
        private var hasStartedScanning = false

        init(onScanned: @escaping (String) -> Void, onFailure: @escaping (String) -> Void, logger: AppLogger) {
            self.onScanned = onScanned
            self.onFailure = onFailure
            self.logger = logger
        }

        func attach(_ controller: DataScannerViewController) {
            self.controller = controller
            guard !hasStartedScanning else { return }
            do {
                try controller.startScanning()
                hasStartedScanning = true
                logger.log(category: .barcode, message: "Barcode scanner started")
            } catch {
                logger.log(category: .barcode, level: .error, message: "Failed to start barcode scanner", error: error)
                onFailure("バーコードスキャナの起動に失敗しました。")
            }
        }

        func stopScanning() {
            guard hasStartedScanning else { return }
            controller?.stopScanning()
            hasStartedScanning = false
            logger.log(category: .barcode, message: "Barcode scanner stopped")
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasCompletedScan else { return }
            guard let first = addedItems.first else { return }
            if case .barcode(let barcode) = first, let payload = barcode.payloadStringValue {
                hasCompletedScan = true
                logger.log(category: .barcode, message: "Recognized barcode payload", details: "payload=\(payload)")
                stopScanning()
                onScanned(payload)
            }
        }
    }
}
#endif
