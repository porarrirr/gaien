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

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                clockOnlyBackground

                LandscapeClockArc(side: .left)
                    .stroke(
                        Color(hex: 0x47C96A),
                        style: StrokeStyle(lineWidth: arcLineWidth(for: geometry.size), lineCap: .round)
                    )
                    .shadow(color: Color(hex: 0x47C96A).opacity(0.18), radius: 10, y: 4)
                    .frame(
                        width: geometry.size.width * 0.42,
                        height: geometry.size.height * 0.88
                    )
                    .offset(x: -geometry.size.width * 0.28, y: geometry.size.height * 0.02)

                LandscapeClockArc(side: .right)
                    .stroke(
                        Color(hex: 0x47C96A),
                        style: StrokeStyle(lineWidth: arcLineWidth(for: geometry.size), lineCap: .round)
                    )
                    .shadow(color: Color(hex: 0x47C96A).opacity(0.18), radius: 10, y: 4)
                    .frame(
                        width: geometry.size.width * 0.42,
                        height: geometry.size.height * 0.88
                    )
                    .offset(x: geometry.size.width * 0.28, y: geometry.size.height * 0.02)

                VStack(spacing: 0) {
                    materialPill
                        .padding(.top, max(10, geometry.size.height * 0.028))

                    Spacer(minLength: 0)

                    VStack(spacing: max(14, geometry.size.height * 0.032)) {
                        HStack(spacing: 14) {
                            Circle()
                                .fill(Color(hex: 0x47C96A))
                                .frame(width: 12, height: 12)
                            Text(modeText)
                                .font(.system(size: statusFontSize(for: geometry.size), weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: 0x47C96A))
                        }

                        Text(timerText)
                            .font(.system(size: clockFontSize(for: geometry.size), weight: .heavy, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .shadow(color: .white.opacity(0.16), radius: 14, y: 4)
                            .minimumScaleFactor(0.62)
                            .lineLimit(1)

                        progressLine
                            .frame(width: progressWidth(for: geometry.size), height: 5)

                        HStack(spacing: max(54, geometry.size.width * 0.11)) {
                            clockOnlyButton(
                                systemImage: viewModel.isRunning ? "pause.fill" : "play.fill",
                                title: viewModel.isRunning ? "一時停止" : "再開",
                                tint: Color(hex: 0x47C96A),
                                action: onPauseToggle
                            )
                            clockOnlyButton(
                                systemImage: "stop.fill",
                                title: "停止",
                                tint: Color(hex: 0xFF3B30),
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
        HStack(spacing: 18) {
            Circle()
                .fill(Color(hex: 0x47C96A))
                .frame(width: 19, height: 19)
                .shadow(color: Color(hex: 0x47C96A).opacity(0.26), radius: 8, y: 2)

            Text(subjectText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text("/")
                .foregroundStyle(.white.opacity(0.84))

            Text(materialText)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .font(.system(size: 20, weight: .semibold, design: .rounded))
        .foregroundStyle(.white.opacity(0.94))
        .padding(.horizontal, 26)
        .frame(height: 54)
        .background(
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(Color.white.opacity(0.035))
                .shadow(color: .black.opacity(0.42), radius: 18, y: 12)
        )
        .overlay(alignment: .bottom) {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
        .frame(maxWidth: 420)
    }

    private var progressLine: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.08))
                Capsule()
                    .fill(Color(hex: 0x47C96A))
                    .frame(width: max(geometry.size.width * min(max(progress, 0), 1), 10))
            }
        }
    }

    private var clockOnlyBackground: some View {
        ZStack {
            Color(hex: 0x07090C)
            RadialGradient(
                colors: [
                    Color.white.opacity(0.08),
                    Color(hex: 0x101419).opacity(0.68),
                    Color.black.opacity(0.92)
                ],
                center: .center,
                startRadius: 20,
                endRadius: 620
            )
            LinearGradient(
                colors: [
                    Color.white.opacity(0.04),
                    Color.clear,
                    Color.black.opacity(0.24)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private func clockOnlyButton(systemImage: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 78, height: 78)
                    .background(
                        Circle()
                            .fill(tint)
                            .shadow(color: tint.opacity(0.26), radius: 18, y: 8)
                    )
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(tint)
            }
            .frame(width: 116)
        }
        .buttonStyle(.plain)
    }

    private func clockFontSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.34, 112), 178)
    }

    private func statusFontSize(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.082, 24), 36)
    }

    private func progressWidth(for size: CGSize) -> CGFloat {
        min(max(size.width * 0.52, 520), 700)
    }

    private func arcLineWidth(for size: CGSize) -> CGFloat {
        min(max(size.height * 0.024, 10), 18)
    }
}

private enum LandscapeClockArcSide {
    case left
    case right
}

private struct LandscapeClockArc: Shape {
    let side: LandscapeClockArcSide

    func path(in rect: CGRect) -> Path {
        let angles: StrideThrough<Double>
        if side == .left {
            angles = stride(from: 220.0, through: 140.0, by: -1.0)
        } else {
            angles = stride(from: -40.0, through: 40.0, by: 1.0)
        }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = rect.width * 0.48
        let radiusY = rect.height * 0.47
        var path = Path()

        for (index, degrees) in angles.enumerated() {
            let radians = degrees * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(radians)) * radiusX,
                y: center.y + CGFloat(sin(radians)) * radiusY
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }

        return path
    }
}

