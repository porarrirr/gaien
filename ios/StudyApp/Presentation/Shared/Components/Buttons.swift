import SwiftUI

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .fill(AppColors.success)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct IconActionButton: View {
    let title: String
    let systemImage: String
    var color: Color = .accentColor
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.bold())
                .foregroundStyle(color)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: AppCornerRadius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct QuickNavButton<Destination: View>: View {
    let icon: String
    let label: String
    let destination: Destination

    init(icon: String, label: String, @ViewBuilder destination: () -> Destination) {
        self.icon = icon
        self.label = label
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppColors.success)
                    .frame(width: 42, height: 42)
                    .background(AppColors.greenSoft, in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppColors.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
    }
}

struct DiagnosticLogCopyButton: View {
    let logger: AppLogger
    @State private var copied = false

    var body: some View {
        Button {
            copyLogs()
        } label: {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                Text(copied ? "診断ログをコピーしました" : "診断ログをコピー")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: AppSpacing.sm)
            }
            .foregroundStyle(copied ? AppColors.success : AppColors.textPrimary)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.md, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func copyLogs() {
        #if canImport(UIKit)
        UIPasteboard.general.string = logger.exportText()
        #endif
        logger.log(category: .app, message: "Diagnostic logs copied from quick button", details: "entryCount=\(logger.recentEntries().count)")
        copied = true
    }
}
