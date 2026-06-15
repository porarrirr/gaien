import Foundation
import SwiftUI

struct LandscapeClockOnlyTimerView: View {
    @ObservedObject var viewModel: TimerViewModel
    let subjectText: String
    let materialText: String
    let timerText: String
    let modeText: String
    let progress: Double
    let onPauseToggle: () -> Void
    let onStop: () -> Void

    // 暗背景に映える落ち着いたアクセント（蛍光色を避けた抑えめのグリーン）。
    private let accent = Color(hex: 0x4CAF6E)
    private let stopColor = Color(hex: 0xD9534F)

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                clockOnlyBackground

                VStack(spacing: 0) {
                    materialPill
                        .padding(.top, max(10, geometry.size.height * 0.028))

                    Spacer(minLength: 0)

                    VStack(spacing: max(14, geometry.size.height * 0.032)) {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(accent)
                                .frame(width: 10, height: 10)
                            Text(modeText)
                                .font(.system(size: statusFontSize(for: geometry.size), weight: .semibold, design: .rounded))
                                .foregroundStyle(accent)
                        }

                        Text(timerText)
                            .font(.system(size: clockFontSize(for: geometry.size), weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.62)
                            .lineLimit(1)

                        progressLine
                            .frame(width: progressWidth(for: geometry.size), height: 5)

                        HStack(spacing: max(54, geometry.size.width * 0.11)) {
                            clockOnlyButton(
                                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                                title: viewModel.isRunning ? "一時停止" : "再開",
                                tint: accent,
                                action: onPauseToggle
                            )
                            clockOnlyButton(
                                systemImage: "stop.fill",
                                title: "停止",
                                tint: stopColor,
                                action: onStop
                            )
                        }
                    }
                    .padding(.bottom, max(26, geometry.size.height * 0.052))

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var materialPill: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(accent)
                .frame(width: 14, height: 14)

            Text(subjectText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("/")
                .foregroundStyle(.white.opacity(0.5))

            Text(materialText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.system(size: 18, weight: .medium, design: .rounded))
        .foregroundStyle(.white.opacity(0.9))
        .padding(.horizontal, 22)
        .frame(height: 50)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.05))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
        .frame(maxWidth: 420)
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.1))
                Capsule()
                    .fill(accent)
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 8))
            }
        }
    }

    private var clockOnlyBackground: some View {
        Color(hex: 0x101216)
            .ignoresSafeArea()
    }

    private func clockOnlyButton(systemImage: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 60, height: 60)
                    .background(
                        Circle()
                            .fill(tint.opacity(0.14))
                    )
                    .overlay {
                        Circle()
                            .stroke(tint.opacity(0.4), lineWidth: 1.5)
                    }
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .frame(width: 104)
        }
        .buttonStyle(.plain)
    }

    private func clockFontSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.3, 100), 156)
    }

    private func statusFontSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.072, 22), 32)
    }

    private func progressWidth(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.52, 480), 660)
    }
}
