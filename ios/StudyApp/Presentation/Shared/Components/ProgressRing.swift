import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = 120
    var lineWidth: CGFloat = 12
    var ringColor: Color = .accentColor
    var trackColor: Color = Color.secondary.opacity(0.15)
    var showPercentage: Bool = true
    @State private var animatedProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(trackColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))

            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: min(animatedProgress, 1.0))
                .stroke(ringColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if showPercentage {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
        .frame(width: size, height: size)
        .aspectRatio(1, contentMode: .fit)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedProgress = progress
            }
        }
        .onChange(of: progress) { newValue in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedProgress = newValue
            }
        }
    }
}

struct AnimatedProgressBar: View {
    let value: Double
    var total: Double = 1.0
    var height: CGFloat = 10
    var barColor: Color = .accentColor
    var trackColor: Color = Color.secondary.opacity(0.15)
    @State private var animatedValue: Double = 0

    private var fraction: Double {
        total > 0 ? min(value / total, 1.0) : 0
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(trackColor)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(barColor)
                    .frame(width: geometry.size.width * animatedValue, height: height)
            }
        }
        .frame(height: height)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                animatedValue = fraction
            }
        }
        .onChange(of: value) { _ in
            withAnimation(.easeOut(duration: 0.5)) {
                animatedValue = fraction
            }
        }
    }
}
