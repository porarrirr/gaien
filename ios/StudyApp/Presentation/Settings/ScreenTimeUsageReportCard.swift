import SwiftUI

/// 直近7日間の利用実績。
///
/// 制限だけを掛けて実績を見せないと、効いているのか分からず行動が変わらない。
/// 使用時間の「目安」・持ち時間・チケット・制限にぶつかった回数を並べて、
/// 減っているかどうかが一目で分かるようにする。
struct ScreenTimeUsageReportCard: View {
    let summary: ScreenTimeUsageSummary
    /// 使用量の段間隔（分）。この幅の誤差があることを明示する。
    let resolutionMinutes: Int
    let isBudgetRuleEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近7日間")
                    .font(.callout.weight(.bold))
                    .foregroundStyle(AppColors.textSecondary)
                Spacer()
                if let delta = summary.usageDeltaMinutes {
                    deltaBadge(delta)
                }
            }
            .padding(.horizontal, 11)

            VStack(alignment: .leading, spacing: 14) {
                if summary.hasData {
                    averageRow
                    chart
                    Divider()
                    statGrid
                    if summary.interruptedDayCount > 0 {
                        interruptionNote
                    }
                    footnote
                } else {
                    emptyState
                }
            }
            .padding(13)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.cardBorder, lineWidth: 1)
            }
        }
    }

    // MARK: - 平均

    private var averageRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("1日あたりの使用")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(ScreenTimeUsageFormat.minutes(summary.averageUsageMinutes))
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                    Text("目安")
                        .font(.caption2)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text("記録した日数")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                Text("\(summary.recordedDayCount)日")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(AppColors.textPrimary)
            }
        }
    }

    private func deltaBadge(_ delta: Int) -> some View {
        let isDown = delta < 0
        let color = isDown ? AppColors.success : (delta == 0 ? AppColors.textSecondary : AppColors.danger)
        let symbol = isDown ? "arrow.down.right" : (delta == 0 ? "equal" : "arrow.up.right")
        let text = delta == 0
            ? "前の7日間と同じ"
            : "前の7日間より\(ScreenTimeUsageFormat.minutes(abs(delta)))\(isDown ? "少ない" : "多い")"
        return Label(text, systemImage: symbol)
            .font(.caption2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.13), in: Capsule())
    }

    // MARK: - グラフ

    /// 棒の高さの基準。使用量と持ち時間の最大値のうち大きい方に合わせる。
    private var chartScaleMinutes: Int {
        let maximum = summary.slots.reduce(0) { partial, slot in
            max(partial, slot.usageMinutes, slot.allowanceMinutes)
        }
        return max(maximum, 30)
    }

    private var chart: some View {
        HStack(alignment: .bottom, spacing: 6) {
            ForEach(summary.slots) { slot in
                dayColumn(slot)
            }
        }
        .frame(height: 108)
    }

    private func dayColumn(_ slot: ScreenTimeUsageDaySlot) -> some View {
        let scale = Double(chartScaleMinutes)
        let usageRatio = min(Double(slot.usageMinutes) / scale, 1)
        let allowanceRatio = min(Double(slot.allowanceMinutes) / scale, 1)
        let exceeded = slot.record?.exceededAllowance == true
        let barColor = exceeded ? AppColors.danger : AppColors.blue

        return VStack(spacing: 5) {
            GeometryReader { geometry in
                let height = geometry.size.height
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(AppColors.subtleBackground)

                    if slot.hasRecord {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(barColor.opacity(0.85))
                            .frame(height: max(height * usageRatio, slot.usageMinutes > 0 ? 3 : 0))
                    }

                    // 持ち時間の位置に目印を置く。棒がここを超えた日が使い切った日。
                    if slot.allowanceMinutes > 0 {
                        Rectangle()
                            .fill(AppColors.textSecondary.opacity(0.55))
                            .frame(height: 1.5)
                            .offset(y: -height * allowanceRatio)
                    }
                }
            }

            Text(ScreenTimeUsageFormat.weekdayInitial(slot.date))
                .font(.caption2.weight(slot.hasRecord ? .bold : .regular))
                .foregroundStyle(slot.hasRecord ? AppColors.textPrimary : AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(slot))
    }

    private func accessibilityLabel(_ slot: ScreenTimeUsageDaySlot) -> String {
        guard slot.hasRecord else {
            return "\(ScreenTimeUsageFormat.monthDay(slot.date)) 記録なし"
        }
        var text = "\(ScreenTimeUsageFormat.monthDay(slot.date)) 使用\(ScreenTimeUsageFormat.minutes(slot.usageMinutes))"
        if slot.allowanceMinutes > 0 {
            text += " 持ち時間\(ScreenTimeUsageFormat.minutes(slot.allowanceMinutes))"
        }
        return text
    }

    // MARK: - 内訳

    private var statGrid: some View {
        HStack(alignment: .top, spacing: 10) {
            statItem(
                title: "使い切った日",
                value: "\(summary.exceededDayCount)日",
                color: summary.exceededDayCount > 0 ? AppColors.danger : AppColors.success
            )
            statDivider
            statItem(
                title: "チケット",
                value: "\(summary.totalTicketsUsed)枚",
                color: AppColors.textPrimary
            )
            statDivider
            statItem(
                title: "制限に当たった",
                value: "\(summary.totalShieldInteractions)回",
                color: AppColors.textPrimary
            )
            statDivider
            statItem(
                title: "勉強",
                value: ScreenTimeUsageFormat.minutes(summary.totalStudyMinutes),
                color: AppColors.success
            )
        }
    }

    private func statItem(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statDivider: some View {
        Rectangle()
            .fill(AppColors.cardBorder)
            .frame(width: 1, height: 32)
    }

    private var interruptionNote: some View {
        Label(
            "\(summary.interruptedDayCount)日、Screen Timeの許可が外れて制限が効かない時間がありました。",
            systemImage: "exclamationmark.shield.fill"
        )
        .font(.caption2.weight(.semibold))
        .foregroundStyle(AppColors.danger)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var footnote: some View {
        Text(footnoteText)
            .font(.caption2)
            .foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var footnoteText: String {
        var parts: [String] = []
        if isBudgetRuleEnabled, resolutionMinutes > 0 {
            // 実使用はしきい値到達でしか分からないため、誤差を隠さず伝える。
            parts.append("使用時間はiOSから届く到達通知をもとにした目安で、最大\(resolutionMinutes)分ほど少なく出ます。")
        } else {
            parts.append("「時間を決めて使う」をオンにすると、使用時間が記録されます。")
        }
        parts.append("「制限に当たった」はブロック画面を操作した回数です。")
        return parts.joined(separator: " ")
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("まだ記録がありません")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
            Text("集中制限を使い始めると、ここに毎日の使用時間・チケット・制限に当たった回数が並びます。")
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 6)
    }
}

enum ScreenTimeUsageFormat {
    static func minutes(_ value: Int) -> String {
        guard value >= 60 else { return "\(value)分" }
        let hours = value / 60
        let remainder = value % 60
        return remainder == 0 ? "\(hours)時間" : "\(hours)時間\(remainder)分"
    }

    static func weekdayInitial(_ date: Date) -> String {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return "日"
        case 2: return "月"
        case 3: return "火"
        case 4: return "水"
        case 5: return "木"
        case 6: return "金"
        default: return "土"
        }
    }

    static func monthDay(_ date: Date) -> String {
        monthDayFormatter.string(from: date)
    }

    private static let monthDayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}
