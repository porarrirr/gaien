import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DebugLogSheet: View {
    @ObservedObject var viewModel: SettingsViewModel
    let isClearUnlocked: Bool
    @Environment(\.dismiss) private var dismiss
    @State private var copyConfirmationMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                DebugLogSummaryCard(
                    count: displayedEntries.count,
                    lastUpdatedText: lastUpdatedText
                )

                debugLogList

                Rectangle()
                    .fill(AppColors.cardBorder)
                    .frame(height: 1)
                    .padding(.top, 2)

                HStack(spacing: 9) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppColors.textSecondary)
                    Text("ロックを解除すると操作できます")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .padding(.horizontal, 30)
                .padding(.top, 8)

                VStack(spacing: 6) {
                    DebugLogActionRow(title: "診断ログをコピー", systemImage: "doc.text", color: AppColors.success) {
                        copyLogs()
                    }
                    DebugLogActionRow(title: "診断ログを共有", systemImage: "square.and.arrow.up", color: AppColors.success) {
                        viewModel.exportDebugLogs()
                    }
                    DebugLogActionRow(title: "診断ログをクリア", systemImage: "trash", color: AppColors.danger) {
                        viewModel.clearDebugLogs()
                    }
                    .disabled(!isClearUnlocked)
                    .opacity(isClearUnlocked ? 1 : 0.72)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
        .strictScreen()
        .navigationTitle("デバッグログ")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
                    .font(.title3.weight(.medium))
                    .foregroundStyle(AppColors.success)
            }
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    viewModel.refreshDebugLogs()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                Button {
                    copyLogs()
                } label: {
                    Image(systemName: "doc.text")
                }
                Button {
                    viewModel.exportDebugLogs()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .tint(AppColors.success)
        .alert("デバッグログ", isPresented: Binding(get: { copyConfirmationMessage != nil }, set: { if !$0 { copyConfirmationMessage = nil } })) {
            Button("OK", role: .cancel) {
                copyConfirmationMessage = nil
            }
        } message: {
            Text(copyConfirmationMessage ?? "")
        }
        .onAppear {
            viewModel.refreshDebugLogs()
        }
    }

    @ViewBuilder
    private var debugLogList: some View {
        if displayedEntries.isEmpty {
            VStack(alignment: .center, spacing: 8) {
                Image(systemName: "doc.text")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("ログはまだありません")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("アプリの動作記録と診断情報がここに表示されます。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 34)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        } else {
            LazyVStack(spacing: 0) {
                ForEach(Array(displayedEntries.enumerated()), id: \.element.id) { index, entry in
                    DebugLogRow(entry: entry, categoryColor: color(for: entry))
                    if index < displayedEntries.count - 1 {
                        Divider()
                            .padding(.leading, 214)
                    }
                }
            }
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
    }

    private var lastUpdatedText: String {
        guard let latest = displayedEntries.first?.timestamp else {
            return "--:--:--"
        }
        return StudyFormatters.clockWithSeconds.string(from: latest)
    }

    private var displayedEntries: [DebugLogEntry] {
        Array(viewModel.debugLogEntries.prefix(200))
    }

    private func copyLogs() {
        viewModel.copyDebugLogs()
        copyConfirmationMessage = "デバッグログをコピーしました"
    }

    private func color(for entry: DebugLogEntry) -> Color {
        switch entry.level {
        case .warning:
            return AppColors.warning
        case .error:
            return AppColors.danger
        case .debug, .info:
            switch entry.category {
            case .sync:
                return AppColors.success
            case .barcode:
                return AppColors.blue
            case .app, .auth, .ui:
                return AppColors.blue
            }
        }
    }
}

private struct DebugLogSummaryCard: View {
    let count: Int
    let lastUpdatedText: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(AppColors.success)
                    .frame(width: 62, height: 62)
                Image(systemName: "doc.text")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("デバッグログ")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)
                Text("アプリの動作記録と診断情報を表示します。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text("最新 200 件を表示しています。")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 16) {
                Text("最終更新: \(lastUpdatedText)")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(count)件")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppColors.success)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 26)
        .frame(minHeight: 112)
        .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppColors.cardBorder, lineWidth: 1)
        }
    }
}

private struct DebugLogRow: View {
    let entry: DebugLogEntry
    let categoryColor: Color

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text(StudyFormatters.logTimestamp.string(from: entry.timestamp))
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(AppColors.textPrimary)
                    .lineLimit(1)
                Text(dayLabel)
                    .font(.system(size: 15))
                    .foregroundStyle(AppColors.textSecondary)
            }
            .frame(width: 170, alignment: .leading)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .center, spacing: 12) {
                    Text(entry.category.rawValue)
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(categoryColor, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                    Text(entry.message)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Text(detailText)
                    .font(.system(size: 16))
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 4)

            Image(systemName: "chevron.right")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color(.tertiaryLabel))
        }
        .padding(.horizontal, 24)
        .frame(minHeight: 84)
        .contentShape(Rectangle())
    }

    private var detailText: String {
        if let details = entry.details, !details.isEmpty {
            return "詳細: \(details)"
        }
        if let errorDescription = entry.errorDescription, !errorDescription.isEmpty {
            return "詳細: \(errorDescription)"
        }
        return "詳細: -"
    }

    private var dayLabel: String {
        Calendar.current.isDateInToday(entry.timestamp) ? "今日" : StudyFormatters.shortDate.string(from: entry.timestamp)
    }
}

private struct DebugLogActionRow: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 22) {
                Image(systemName: systemImage)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(color)
                    .frame(width: 30)
                Text(title)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(color)
                Spacer()
            }
            .padding(.horizontal, 26)
            .frame(height: 54)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

