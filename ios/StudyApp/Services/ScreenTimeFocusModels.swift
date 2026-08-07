import CryptoKit
import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

enum ScreenTimeDateMath {
    static func epochMilliseconds(for date: Date) -> Int64 {
        Int64(date.timeIntervalSince1970 * 1_000)
    }

    static func date(fromEpochMilliseconds value: Int64) -> Date {
        Date(timeIntervalSince1970: TimeInterval(value) / 1_000)
    }

    /// `DeviceActivitySchedule` は分粒度でしか境界を扱えない。
    /// 期限を分境界へ切り上げておくことで、台帳の期限とスケジュールの境界が一致し、
    /// 期限コールバックが実際の期限より前に届くことがなくなる。
    static func ceilingToMinute(_ date: Date, calendar: Calendar = .current) -> Date {
        let truncated = calendar.date(
            from: calendar.dateComponents([.era, .year, .month, .day, .hour, .minute], from: date)
        )
        guard let truncated else { return date }
        guard truncated < date else { return truncated }
        return truncated.addingTimeInterval(60)
    }

    /// 端末の時計やタイムゾーンが巻き戻っても同じ日を二重に開始しないための
    /// ローカル日付序数（yyyyMMdd）。
    static func localDayOrdinal(for date: Date, calendar: Calendar = .current) -> Int {
        var localGregorianCalendar = Calendar(identifier: .gregorian)
        localGregorianCalendar.timeZone = calendar.timeZone
        let components = localGregorianCalendar.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0) * 10_000
            + (components.month ?? 0) * 100
            + (components.day ?? 0)
    }
}

enum FocusScheduleBehavior: String, Codable, CaseIterable, Hashable {
    case allow
    case block

    var title: String {
        switch self {
        case .allow:
            return "無料開放"
        case .block:
            return "使用禁止"
        }
    }
}

struct FocusScheduleSlot: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var isEnabled: Bool
    var behavior: FocusScheduleBehavior
    var startHour: Int
    var startMinute: Int
    var endHour: Int
    var endMinute: Int
    /// Calendar weekday values (1 = Sunday … 7 = Saturday) the slot applies to.
    var weekdays: Set<Int>
    /// 使用禁止時間帯をチケットで開けられるかどうか。
    /// `false` の枠は「交渉不可」で、チケットも無料開放も効かない。
    var allowsTicketBypass: Bool

    static let allWeekdays: Set<Int> = [1, 2, 3, 4, 5, 6, 7]

    init(
        id: String = UUID().uuidString,
        title: String = "時間帯",
        isEnabled: Bool = true,
        behavior: FocusScheduleBehavior = .block,
        startHour: Int = 19,
        startMinute: Int = 0,
        endHour: Int = 21,
        endMinute: Int = 0,
        weekdays: Set<Int> = FocusScheduleSlot.allWeekdays,
        allowsTicketBypass: Bool = true
    ) {
        self.id = id
        self.title = title
        self.isEnabled = isEnabled
        self.behavior = behavior
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.weekdays = weekdays.intersection(FocusScheduleSlot.allWeekdays)
        self.allowsTicketBypass = allowsTicketBypass
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case isEnabled
        case behavior
        case startHour
        case startMinute
        case endHour
        case endMinute
        case weekdays
        case allowsTicketBypass
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
        behavior = try container.decodeIfPresent(FocusScheduleBehavior.self, forKey: .behavior) ?? .block
        startHour = try container.decode(Int.self, forKey: .startHour)
        startMinute = try container.decode(Int.self, forKey: .startMinute)
        endHour = try container.decode(Int.self, forKey: .endHour)
        endMinute = try container.decode(Int.self, forKey: .endMinute)
        if let decodedWeekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) {
            weekdays = decodedWeekdays.intersection(FocusScheduleSlot.allWeekdays)
        } else {
            weekdays = FocusScheduleSlot.allWeekdays
        }
        // 旧データはチケットで開けられる挙動だったため、既定は true のままにする。
        allowsTicketBypass = try container.decodeIfPresent(Bool.self, forKey: .allowsTicketBypass) ?? true
    }

    var activityName: DeviceActivityName {
        DeviceActivityName("\(ScreenTimeFocusShared.scheduleActivityNamePrefix)\(id)")
    }

    var startDateComponents: DateComponents {
        DateComponents(hour: startHour, minute: startMinute)
    }

    var endDateComponents: DateComponents {
        DateComponents(hour: endHour, minute: endMinute)
    }

    var durationMinutes: Int {
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        guard start != end else { return 0 }
        return end > start ? end - start : 24 * 60 - start + end
    }

    var hasSelectedWeekday: Bool {
        !weekdays.isEmpty
    }

    /// 交渉不可の使用禁止枠かどうか。無料開放枠には意味を持たない。
    var isNonNegotiableBlock: Bool {
        behavior == .block && !allowsTicketBypass
    }

    func isActive(onWeekday weekday: Int) -> Bool {
        weekdays.contains(weekday)
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let currentMinute = calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)
        let startMinuteOfDay = startHour * 60 + startMinute
        let endMinuteOfDay = endHour * 60 + endMinute
        let weekday = calendar.component(.weekday, from: date)

        guard startMinuteOfDay != endMinuteOfDay else { return false }
        if startMinuteOfDay < endMinuteOfDay {
            guard isActive(onWeekday: weekday) else { return false }
            return currentMinute >= startMinuteOfDay && currentMinute < endMinuteOfDay
        }
        if currentMinute >= startMinuteOfDay {
            return isActive(onWeekday: weekday)
        }
        if currentMinute < endMinuteOfDay {
            return isActive(onWeekday: Self.previousWeekday(weekday))
        }
        return false
    }

    func nextStart(after date: Date, calendar: Calendar = .current) -> Date? {
        let today = calendar.startOfDay(for: date)
        for dayOffset in 0...7 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let candidate = calendar.date(
                    bySettingHour: startHour,
                    minute: startMinute,
                    second: 0,
                    of: day
                  ) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: candidate)
            if isActive(onWeekday: weekday), candidate > date {
                return candidate
            }
        }
        return nil
    }

    static func previousWeekday(_ weekday: Int) -> Int {
        weekday == 1 ? 7 : weekday - 1
    }
}

enum ScreenTimeScheduleValidationError: LocalizedError, Equatable {
    case intervalTooShort(title: String)
    case tooManyEnabledSlots(maximum: Int)
    case invalidAllowanceMinutes
    case invalidTicketCount
    case invalidEarnRate
    case invalidCooldownMinutes

    var errorDescription: String? {
        switch self {
        case .intervalTooShort(let title):
            return "\(title)は15分以上の時間帯を指定してください"
        case .tooManyEnabledSlots(let maximum):
            return "有効にできる時間帯は最大\(maximum)件です"
        case .invalidAllowanceMinutes:
            return "持ち時間は0〜\(ScreenTimeFocusSettings.maximumAllowanceMinutes)分の5分刻みで指定してください"
        case .invalidTicketCount:
            return "チケットは0〜\(ScreenTimeFocusSettings.maximumDailyTicketCount)枚で指定してください"
        case .invalidEarnRate:
            return "交換レートは勉強1〜\(ScreenTimeFocusSettings.maximumStudyMinutesPerEarnedMinute)分で指定してください"
        case .invalidCooldownMinutes:
            return "チケットの間隔は0〜\(ScreenTimeFocusSettings.maximumTicketCooldownMinutes)分で指定してください"
        }
    }
}

struct ScreenTimeDailyGoalProgress: Codable, Equatable {
    var dayStart: Int64
    var studyMinutes: Int
    var targetMinutes: Int
    var updatedAt: Int64

    var hasTarget: Bool {
        targetMinutes > 0
    }

    var hasReachedTarget: Bool {
        hasTarget && studyMinutes >= targetMinutes
    }

    func isForDay(containing date: Date, calendar: Calendar = .current) -> Bool {
        dayStart == ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: date))
    }

    /// 目標到達によって「目標未達成の制限」だけが解けるかどうか。
    /// 以前は終日すべての制限を解除していたが、達成後の使いすぎを招くため、
    /// 現在はこのルール自身の解除とボーナス付与にとどめている。
    func liftsGoalRestriction(on date: Date = Date(), calendar: Calendar = .current) -> Bool {
        isForDay(containing: date, calendar: calendar) && hasReachedTarget
    }
}

struct ScreenTimeRuntimeState: Codable, Equatable {
    var timerIsRunning: Bool
    /// Epoch milliseconds for an automatically ending countdown timer.
    /// `nil` means the running timer has no automatic end (for example, a stopwatch).
    var timerRestrictionEndsAt: Int64?
    var updatedAt: Int64

    init(
        timerIsRunning: Bool = false,
        timerRestrictionEndsAt: Int64? = nil,
        updatedAt: Int64 = ScreenTimeDateMath.epochMilliseconds(for: Date())
    ) {
        self.timerIsRunning = timerIsRunning
        self.timerRestrictionEndsAt = timerRestrictionEndsAt
        self.updatedAt = updatedAt
    }

    func isTimerRestrictionActive(at date: Date = Date()) -> Bool {
        guard timerIsRunning else { return false }
        guard let timerRestrictionEndsAt else { return true }
        return ScreenTimeDateMath.epochMilliseconds(for: date) < timerRestrictionEndsAt
    }

    var timerRestrictionEndDate: Date? {
        timerRestrictionEndsAt.map(ScreenTimeDateMath.date(fromEpochMilliseconds:))
    }
}

// MARK: - 持ち時間

/// 1日の「持ち時間」（対象アプリを実際に使える分数）の計算。
///
/// 入りは3つ。基本枠（毎日補充）・勉強で稼いだ分・目標達成ボーナス。
/// 出は対象アプリの実使用時間のみ。チケットは持ち時間を消費しない
/// （チケットは「壁を開ける鍵」で、持ち時間は「使える総量」という別の資源）。
enum ScreenTimeAllowance {
    static func earnedMinutes(studyMinutes: Int, settings: ScreenTimeFocusSettings) -> Int {
        guard settings.earnedAllowanceEnabled,
              settings.studyMinutesPerEarnedMinute > 0,
              studyMinutes > 0 else {
            return 0
        }
        let earned = studyMinutes / settings.studyMinutesPerEarnedMinute
        return min(earned, max(settings.earnedAllowanceCapMinutes, 0))
    }

    static func bonusMinutes(goalReached: Bool, settings: ScreenTimeFocusSettings) -> Int {
        guard goalReached else { return 0 }
        return max(settings.goalBonusAllowanceMinutes, 0)
    }

    /// 1日でありうる最大の持ち時間。使用量マイルストーンの上限に使う。
    static func maximumPossibleMinutes(settings: ScreenTimeFocusSettings) -> Int {
        var total = max(settings.baseAllowanceMinutes, 0)
        if settings.earnedAllowanceEnabled {
            total += max(settings.earnedAllowanceCapMinutes, 0)
        }
        total += max(settings.goalBonusAllowanceMinutes, 0)
        return min(total, ScreenTimeFocusSettings.maximumAllowanceMinutes)
    }

    /// しきい値の階段を張る天井。持ち時間そのものではなく、60分単位へ切り上げた値を使う。
    ///
    /// 階段を張り直すと OS 側のカウンタが 0 に戻り、次の段へ向けて積み上がっていた
    /// 端数（記録済みの段より先の分）が失われる。持ち時間を1目盛り動かすたびに
    /// 張り直していると、ステッパーを触るだけで実使用の計測を巻き戻せてしまう。
    /// 天井を粗い刻みにすることで、細かい調整では階段が変わらないようにする。
    static func ladderCeilingMinutes(for maximumMinutes: Int) -> Int {
        guard maximumMinutes > 0 else { return 0 }
        let bucket = ScreenTimeFocusSettings.usageLadderBucketMinutes
        let rounded = ((maximumMinutes + bucket - 1) / bucket) * bucket
        return min(rounded, ScreenTimeFocusSettings.maximumAllowanceMinutes)
    }

    /// `DeviceActivityEvent` のしきい値として登録する分数の一覧。
    ///
    /// Screen Time は「今日この対象を何分使ったか」をアプリへ直接教えてくれない。
    /// 代わりに、しきい値へ到達したときだけコールバックが届く。そこで天井までの
    /// 階段を張り、到達した最大段を実使用の下限として扱う。
    ///
    /// 段は低い側を密にしてある（少ない持ち時間ほど誤差が体感に響くため）。
    /// 天井は必ず含めるので、使い切りの検知だけは取りこぼさない。
    static func usageMilestones(maximumMinutes: Int) -> [Int] {
        guard maximumMinutes > 0 else { return [] }
        let limit = ScreenTimeFocusSettings.maximumUsageMilestones
        if maximumMinutes <= limit {
            return Array(1...maximumMinutes)
        }
        var values: Set<Int> = [maximumMinutes]
        for index in 1..<limit {
            let fraction = Double(index) / Double(limit)
            // 指数 1.6 で低い側へ寄せる。
            let minutes = Int((Double(maximumMinutes) * pow(fraction, 1.6)).rounded())
            if minutes > 0 {
                values.insert(minutes)
            }
        }
        return values.sorted()
    }

    /// 使用量マイルストーンの誤差幅（最大段間隔）。UI で「目安」と伝えるために使う。
    static func milestoneResolutionMinutes(maximumMinutes: Int) -> Int {
        let milestones = usageMilestones(maximumMinutes: maximumMinutes)
        guard milestones.count > 1 else { return max(maximumMinutes, 1) }
        var largestGap = milestones[0]
        for index in 1..<milestones.count {
            largestGap = max(largestGap, milestones[index] - milestones[index - 1])
        }
        return largestGap
    }
}

/// 予算監視の対象が変わったかどうかを判定するための指紋。
///
/// `startMonitoring` を貼り直すと、その区間で積み上がっていた使用量が 0 に戻る。
/// アプリ前面化ごとに無条件で貼り直すと使用量が永遠に積み上がらないため、
/// 対象アプリが変わったときだけ貼り直す。
///
/// しきい値の階段は指紋に含めない。階段は別途「登録済みの天井」と比較し、
/// 足りなくなったときだけ張り直す（下げる変更では張り直さない）。
enum ScreenTimeBudgetFingerprint {
    static func value(selection: FamilyActivitySelection) -> String {
        var parts: [String] = []
        parts.append(contentsOf: tokenDigests(selection.applicationTokens).map { "a:\($0)" })
        parts.append(contentsOf: tokenDigests(selection.categoryTokens).map { "c:\($0)" })
        parts.append(contentsOf: tokenDigests(selection.webDomainTokens).map { "w:\($0)" })
        parts.sort()
        return digest(Data(parts.joined(separator: "|").utf8))
    }

    /// トークンの `hashValue` はプロセスごとに変わるため使えない。
    /// `Codable` 表現のバイト列を SHA256 にかけ、並べ替えて安定させる。
    private static func tokenDigests<T: Encodable>(_ tokens: Set<T>) -> [String] {
        let encoder = JSONEncoder()
        return tokens.compactMap { token in
            guard let data = try? encoder.encode(token) else { return nil }
            return digest(data)
        }
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// 旧バージョンの端末が読む互換キーの値を作る。
///
/// 旧端末は新しいキーを知らないため、同期で受け取った旧キーだけで動く。
/// そのまま現在値を流し込むと、旧端末側の検証や判定と食い違うことがある。
enum ScreenTimeLegacyCompatibility {
    /// 旧 `dailyTicketMinutes` は10分刻みでしか検証を通らなかった。
    /// 新しい持ち時間は5分刻みなので、切り下げて10分の倍数にしてから渡す。
    /// そうしないと旧端末では Screen Time 設定を一切保存できなくなる。
    static func dailyTicketMinutes(_ baseAllowanceMinutes: Int) -> Int {
        let clamped = max(baseAllowanceMinutes, 0)
        let step = ScreenTimeFocusSettings.ticketDurationMinutes
        return (clamped / step) * step
    }

    /// 旧 `unlockRestrictionsWhenDailyGoalReached` は、目標達成で**すべての**制限を
    /// 終日解除する挙動だった。「チケットでも開けられない」時間帯を持つ設定でこれを
    /// 立てると、旧端末では就寝時間まで開いてしまう。
    /// 交渉不可の枠がある場合は、安全側（制限を続ける）に倒して `false` を渡す。
    static func goalUnlock(
        goalRestrictionEnabled: Bool,
        scheduleSlots: [FocusScheduleSlot]
    ) -> Bool {
        guard goalRestrictionEnabled else { return false }
        return !scheduleSlots.contains { $0.isEnabled && $0.isNonNegotiableBlock }
    }

    /// 旧「時間帯の外も制限」を「常に制限」へ畳む。
    ///
    /// 旧判定は「時間帯ルールがオン」かつ「いまどの枠にも入っていない」ときだけ壁を立てた。
    /// これは「常に制限」＋「無料開放の枠だけが開ける」と同じ結果になるため、
    /// 時間帯ルールがオンだったときに限って `true` を引き継ぐと挙動が保たれる。
    /// 時間帯ルールがオフなら旧設定でも効いていなかったので、そのまま捨てる。
    static func alwaysRestrict(
        alwaysRestrictEnabled: Bool?,
        legacyTicketRestrictionEnabled: Bool?,
        legacyRestrictOutsideSchedule: Bool?,
        scheduledRestrictionEnabled: Bool
    ) -> Bool {
        let always = alwaysRestrictEnabled ?? legacyTicketRestrictionEnabled ?? false
        let migratedOutside = (legacyRestrictOutsideSchedule ?? false) && scheduledRestrictionEnabled
        return always || migratedOutside
    }
}

// MARK: - 設定

struct ScreenTimeFocusSettings: Codable, Equatable {
    static let minimumScheduleDurationMinutes = 15
    static let maximumEnabledScheduleSlots = 20
    static let ticketDurationMinutes = 10
    static let allowanceStepMinutes = 5
    static let maximumAllowanceMinutes = 720
    static let maximumDailyTicketCount = 24
    static let maximumStudyMinutesPerEarnedMinute = 10
    static let maximumTicketCooldownMinutes = 120
    static let maximumUsageMilestones = 18
    /// しきい値の階段を張る天井の刻み。細かい設定変更で階段が変わらないようにする。
    static let usageLadderBucketMinutes = 60
    /// 持ち時間の残りがこの割合を下回ったら「そろそろ終わる」と知らせる。
    static let usageWarningRemainingRatio = 0.2

    var isEnabled: Bool

    // ルール（すべて併用可能）
    /// 今日の学習目標を達成するまで制限する。達成するとこの制限だけが解け、
    /// `goalBonusAllowanceMinutes` が持ち時間へ加算される。
    var goalRestrictionEnabled: Bool
    var timerRestrictionEnabled: Bool
    var scheduledRestrictionEnabled: Bool
    /// 壁の基本状態。オンなら常に制限し、無料開放の時間帯とチケットだけが開ける。
    ///
    /// 以前は「時間帯の外も制限（`restrictOutsideSchedule`）」という別トグルがあったが、
    /// 判定は「時間帯の穴が空いていないときに壁を立てる」で完全に同じだった。
    /// 同じ軸に入口が2つあると同時オンで矛盾した表示になるため、こちらへ統合した。
    var alwaysRestrictEnabled: Bool
    /// 対象アプリの実使用が持ち時間を超えたら、その対象だけをブロックする。
    var budgetRestrictionEnabled: Bool
    /// チケット（壁を一時的に開ける鍵）を使えるようにする。
    var ticketsEnabled: Bool

    // 持ち時間
    var baseAllowanceMinutes: Int
    var earnedAllowanceEnabled: Bool
    /// 勉強何分で持ち時間1分を稼げるか。
    var studyMinutesPerEarnedMinute: Int
    var earnedAllowanceCapMinutes: Int
    var goalBonusAllowanceMinutes: Int

    // チケット
    var dailyTicketCount: Int
    var ticketCooldownMinutes: Int
    /// 2枚目以降、1枚ごとに伸びるクールダウン。使うほど間隔が広がる。
    var ticketCooldownEscalationMinutes: Int

    // 対象の選択（トークンは端末固有なので同期しない）
    /// 制限中も使えるもの（許可リスト）。ここに無いものが壁の対象になる。
    var activitySelection: FamilyActivitySelection
    var selectionWasConfigured: Bool
    /// 持ち時間を消費する対象（時間を決めて使うもの）。
    var budgetSelection: FamilyActivitySelection
    var budgetSelectionWasConfigured: Bool

    var scheduleSlots: [FocusScheduleSlot]
    /// Last time a cloud-portable Screen Time setting changed.
    var updatedAt: Int64
    /// Epoch milliseconds. While `Date() < expiry`, all Screen Time settings are read-only in-app.
    var settingsLockedUntilEpochMilliseconds: Int64?

    init(
        isEnabled: Bool = false,
        goalRestrictionEnabled: Bool = false,
        timerRestrictionEnabled: Bool = false,
        scheduledRestrictionEnabled: Bool = false,
        alwaysRestrictEnabled: Bool = false,
        budgetRestrictionEnabled: Bool = false,
        ticketsEnabled: Bool = false,
        baseAllowanceMinutes: Int = 0,
        earnedAllowanceEnabled: Bool = false,
        studyMinutesPerEarnedMinute: Int = 3,
        earnedAllowanceCapMinutes: Int = 60,
        goalBonusAllowanceMinutes: Int = 0,
        dailyTicketCount: Int = 0,
        ticketCooldownMinutes: Int = 0,
        ticketCooldownEscalationMinutes: Int = 0,
        scheduleSlots: [FocusScheduleSlot] = [],
        activitySelection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true),
        selectionWasConfigured: Bool? = nil,
        budgetSelection: FamilyActivitySelection = FamilyActivitySelection(includeEntireCategory: true),
        budgetSelectionWasConfigured: Bool? = nil,
        updatedAt: Int64 = 0,
        settingsLockedUntilEpochMilliseconds: Int64? = nil
    ) {
        self.isEnabled = isEnabled
        self.goalRestrictionEnabled = goalRestrictionEnabled
        self.timerRestrictionEnabled = timerRestrictionEnabled
        self.scheduledRestrictionEnabled = scheduledRestrictionEnabled
        self.alwaysRestrictEnabled = alwaysRestrictEnabled
        self.budgetRestrictionEnabled = budgetRestrictionEnabled
        self.ticketsEnabled = ticketsEnabled
        self.baseAllowanceMinutes = baseAllowanceMinutes
        self.earnedAllowanceEnabled = earnedAllowanceEnabled
        self.studyMinutesPerEarnedMinute = studyMinutesPerEarnedMinute
        self.earnedAllowanceCapMinutes = earnedAllowanceCapMinutes
        self.goalBonusAllowanceMinutes = goalBonusAllowanceMinutes
        self.dailyTicketCount = dailyTicketCount
        self.ticketCooldownMinutes = ticketCooldownMinutes
        self.ticketCooldownEscalationMinutes = ticketCooldownEscalationMinutes
        self.scheduleSlots = scheduleSlots
        self.activitySelection = Self.selectionIncludingEntireCategories(activitySelection)
        self.selectionWasConfigured = selectionWasConfigured
            ?? !activitySelection.applicationTokens.isEmpty
            || !activitySelection.webDomainTokens.isEmpty
        self.budgetSelection = Self.selectionIncludingEntireCategories(budgetSelection)
        self.budgetSelectionWasConfigured = budgetSelectionWasConfigured
            ?? !budgetSelection.applicationTokens.isEmpty
            || !budgetSelection.categoryTokens.isEmpty
            || !budgetSelection.webDomainTokens.isEmpty
        self.updatedAt = updatedAt
        self.settingsLockedUntilEpochMilliseconds = settingsLockedUntilEpochMilliseconds
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case goalRestrictionEnabled
        case timerRestrictionEnabled
        case scheduledRestrictionEnabled
        case alwaysRestrictEnabled
        case budgetRestrictionEnabled
        case ticketsEnabled
        case baseAllowanceMinutes
        case earnedAllowanceEnabled
        case studyMinutesPerEarnedMinute
        case earnedAllowanceCapMinutes
        case goalBonusAllowanceMinutes
        case dailyTicketCount
        case ticketCooldownMinutes
        case ticketCooldownEscalationMinutes
        case scheduleSlots
        case activitySelection
        case selectionWasConfigured
        case budgetSelection
        case budgetSelectionWasConfigured
        case updatedAt
        case settingsLockedUntilEpochMilliseconds

        // 旧キー。読み取りは移行のため、書き出しは旧バージョンの端末との同期のため残す。
        case legacyTicketRestrictionEnabled = "ticketRestrictionEnabled"
        case legacyDailyTicketMinutes = "dailyTicketMinutes"
        case legacyUnlockRestrictionsWhenDailyGoalReached = "unlockRestrictionsWhenDailyGoalReached"
        // 「時間帯の外も制限」は `alwaysRestrictEnabled` へ統合した。読み取り専用でよい。
        // 旧バージョンの端末も `alwaysRestrictEnabled` を読むため、統合先だけ書き出せば
        // 同じ壁が立つ。書き出しを続けると、統合前の二重入口が同期で復活する。
        case legacyRestrictOutsideSchedule = "restrictOutsideSchedule"
        case legacyRestrictOutsideScheduleWhenTicketsDisabled = "restrictOutsideScheduleWhenTicketsDisabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        timerRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .timerRestrictionEnabled) ?? false
        scheduledRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .scheduledRestrictionEnabled) ?? false

        let legacyTickets = try container.decodeIfPresent(Bool.self, forKey: .legacyTicketRestrictionEnabled)
        let legacyMinutes = try container.decodeIfPresent(Int.self, forKey: .legacyDailyTicketMinutes)
        let legacyOutside = try container.decodeIfPresent(Bool.self, forKey: .legacyRestrictOutsideSchedule)
            ?? container.decodeIfPresent(Bool.self, forKey: .legacyRestrictOutsideScheduleWhenTicketsDisabled)
        let legacyGoalUnlock = try container.decodeIfPresent(
            Bool.self,
            forKey: .legacyUnlockRestrictionsWhenDailyGoalReached
        )

        // 旧「チケット制」は「常に制限」＋「チケットを使える」の2つが一体になっていた。
        // 分解して移行することで、旧設定の実挙動をそのまま保つ。
        alwaysRestrictEnabled = ScreenTimeLegacyCompatibility.alwaysRestrict(
            alwaysRestrictEnabled: try container.decodeIfPresent(Bool.self, forKey: .alwaysRestrictEnabled),
            legacyTicketRestrictionEnabled: legacyTickets,
            legacyRestrictOutsideSchedule: legacyOutside,
            scheduledRestrictionEnabled: scheduledRestrictionEnabled
        )
        ticketsEnabled = try container.decodeIfPresent(Bool.self, forKey: .ticketsEnabled)
            ?? legacyTickets
            ?? false
        goalRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .goalRestrictionEnabled)
            ?? legacyGoalUnlock
            ?? false
        budgetRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .budgetRestrictionEnabled) ?? false

        // 旧 `dailyTicketMinutes` は「10分チケット × N枚」の総分数だった。
        // 分数は基本枠へ、枚数はチケット枚数へ引き継ぐ。
        baseAllowanceMinutes = try container.decodeIfPresent(Int.self, forKey: .baseAllowanceMinutes)
            ?? legacyMinutes
            ?? 0
        dailyTicketCount = try container.decodeIfPresent(Int.self, forKey: .dailyTicketCount)
            ?? legacyMinutes.map { $0 / Self.ticketDurationMinutes }
            ?? 0
        earnedAllowanceEnabled = try container.decodeIfPresent(Bool.self, forKey: .earnedAllowanceEnabled) ?? false
        studyMinutesPerEarnedMinute = try container.decodeIfPresent(
            Int.self,
            forKey: .studyMinutesPerEarnedMinute
        ) ?? 3
        earnedAllowanceCapMinutes = try container.decodeIfPresent(Int.self, forKey: .earnedAllowanceCapMinutes) ?? 60
        goalBonusAllowanceMinutes = try container.decodeIfPresent(Int.self, forKey: .goalBonusAllowanceMinutes) ?? 0
        ticketCooldownMinutes = try container.decodeIfPresent(Int.self, forKey: .ticketCooldownMinutes) ?? 0
        ticketCooldownEscalationMinutes = try container.decodeIfPresent(
            Int.self,
            forKey: .ticketCooldownEscalationMinutes
        ) ?? 0

        scheduleSlots = try container.decodeIfPresent([FocusScheduleSlot].self, forKey: .scheduleSlots) ?? []
        let decodedSelection = try container.decodeIfPresent(
            FamilyActivitySelection.self,
            forKey: .activitySelection
        ) ?? FamilyActivitySelection(includeEntireCategory: true)
        activitySelection = Self.selectionIncludingEntireCategories(decodedSelection)
        selectionWasConfigured = try container.decodeIfPresent(
            Bool.self,
            forKey: .selectionWasConfigured
        ) ?? (!decodedSelection.applicationTokens.isEmpty || !decodedSelection.webDomainTokens.isEmpty)

        let decodedBudgetSelection = try container.decodeIfPresent(
            FamilyActivitySelection.self,
            forKey: .budgetSelection
        ) ?? FamilyActivitySelection(includeEntireCategory: true)
        budgetSelection = Self.selectionIncludingEntireCategories(decodedBudgetSelection)
        budgetSelectionWasConfigured = try container.decodeIfPresent(
            Bool.self,
            forKey: .budgetSelectionWasConfigured
        ) ?? (!decodedBudgetSelection.applicationTokens.isEmpty
              || !decodedBudgetSelection.categoryTokens.isEmpty
              || !decodedBudgetSelection.webDomainTokens.isEmpty)

        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        settingsLockedUntilEpochMilliseconds = try container.decodeIfPresent(
            Int64.self,
            forKey: .settingsLockedUntilEpochMilliseconds
        )
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(goalRestrictionEnabled, forKey: .goalRestrictionEnabled)
        try container.encode(timerRestrictionEnabled, forKey: .timerRestrictionEnabled)
        try container.encode(scheduledRestrictionEnabled, forKey: .scheduledRestrictionEnabled)
        try container.encode(alwaysRestrictEnabled, forKey: .alwaysRestrictEnabled)
        try container.encode(budgetRestrictionEnabled, forKey: .budgetRestrictionEnabled)
        try container.encode(ticketsEnabled, forKey: .ticketsEnabled)
        try container.encode(baseAllowanceMinutes, forKey: .baseAllowanceMinutes)
        try container.encode(earnedAllowanceEnabled, forKey: .earnedAllowanceEnabled)
        try container.encode(studyMinutesPerEarnedMinute, forKey: .studyMinutesPerEarnedMinute)
        try container.encode(earnedAllowanceCapMinutes, forKey: .earnedAllowanceCapMinutes)
        try container.encode(goalBonusAllowanceMinutes, forKey: .goalBonusAllowanceMinutes)
        try container.encode(dailyTicketCount, forKey: .dailyTicketCount)
        try container.encode(ticketCooldownMinutes, forKey: .ticketCooldownMinutes)
        try container.encode(ticketCooldownEscalationMinutes, forKey: .ticketCooldownEscalationMinutes)
        try container.encode(scheduleSlots, forKey: .scheduleSlots)
        try container.encode(activitySelection, forKey: .activitySelection)
        try container.encode(selectionWasConfigured, forKey: .selectionWasConfigured)
        try container.encode(budgetSelection, forKey: .budgetSelection)
        try container.encode(budgetSelectionWasConfigured, forKey: .budgetSelectionWasConfigured)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(
            settingsLockedUntilEpochMilliseconds,
            forKey: .settingsLockedUntilEpochMilliseconds
        )

        // 旧バージョンの端末が読んでも近い挙動になるよう、旧キーも書き出す。
        try container.encode(alwaysRestrictEnabled, forKey: .legacyTicketRestrictionEnabled)
        try container.encode(
            ScreenTimeLegacyCompatibility.dailyTicketMinutes(baseAllowanceMinutes),
            forKey: .legacyDailyTicketMinutes
        )
        try container.encode(
            ScreenTimeLegacyCompatibility.goalUnlock(
                goalRestrictionEnabled: goalRestrictionEnabled,
                scheduleSlots: scheduleSlots
            ),
            forKey: .legacyUnlockRestrictionsWhenDailyGoalReached
        )
    }

    var settingsLockExpiryDate: Date? {
        guard let settingsLockedUntilEpochMilliseconds else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(settingsLockedUntilEpochMilliseconds) / 1_000)
    }

    var isSettingsLocked: Bool {
        isSettingsLocked(at: Date())
    }

    func isSettingsLocked(at date: Date) -> Bool {
        guard let expiryDate = settingsLockExpiryDate else { return false }
        return date < expiryDate
    }

    static func lockExpiryDate(
        from startDate: Date,
        months: Int,
        days: Int,
        calendar: Calendar = .current
    ) -> Date? {
        guard months > 0 || days > 0 else { return nil }
        var components = DateComponents()
        components.month = months
        components.day = days
        return calendar.date(byAdding: components, to: startDate)
    }

    var allowedApplicationTokens: Set<ApplicationToken> {
        activitySelection.applicationTokens
    }

    var allowedWebDomainTokens: Set<WebDomainToken> {
        activitySelection.webDomainTokens
    }

    var budgetApplicationTokens: Set<ApplicationToken> {
        budgetSelection.applicationTokens
    }

    var budgetCategoryTokens: Set<ActivityCategoryToken> {
        budgetSelection.categoryTokens
    }

    var budgetWebDomainTokens: Set<WebDomainToken> {
        budgetSelection.webDomainTokens
    }

    var hasMeaningfulConfiguration: Bool {
        isEnabled
            || goalRestrictionEnabled
            || timerRestrictionEnabled
            || scheduledRestrictionEnabled
            || alwaysRestrictEnabled
            || budgetRestrictionEnabled
            || ticketsEnabled
            || baseAllowanceMinutes != 0
            || earnedAllowanceEnabled
            || goalBonusAllowanceMinutes != 0
            || dailyTicketCount != 0
            || !scheduleSlots.isEmpty
            || selectionWasConfigured
            || budgetSelectionWasConfigured
            || settingsLockedUntilEpochMilliseconds != nil
    }

    var enabledScheduleSlots: [FocusScheduleSlot] {
        guard isEnabled, scheduledRestrictionEnabled else { return [] }
        return scheduleSlots.filter { $0.isEnabled && $0.hasSelectedWeekday }
    }

    var maximumEnabledSlotsForCurrentConfiguration: Int {
        Self.maximumEnabledScheduleSlots - reservedMonitoringActivityCount
    }

    var requiresDailyBoundaryMonitoring: Bool {
        isEnabled && (ticketsEnabled || goalRestrictionEnabled)
    }

    var requiresBudgetMonitoring: Bool {
        false
    }

    private var reservedMonitoringActivityCount: Int {
        guard isEnabled else { return 0 }
        var count = 0
        if requiresDailyBoundaryMonitoring {
            count += 1
        }
        if ticketsEnabled {
            count += 1
        }
        if timerRestrictionEnabled {
            count += 1
        }
        return count
    }

    func validateMonitoringConfiguration() throws {
        guard (0...Self.maximumAllowanceMinutes).contains(baseAllowanceMinutes),
              baseAllowanceMinutes.isMultiple(of: Self.allowanceStepMinutes),
              (0...Self.maximumAllowanceMinutes).contains(earnedAllowanceCapMinutes),
              earnedAllowanceCapMinutes.isMultiple(of: Self.allowanceStepMinutes),
              (0...Self.maximumAllowanceMinutes).contains(goalBonusAllowanceMinutes),
              goalBonusAllowanceMinutes.isMultiple(of: Self.allowanceStepMinutes) else {
            throw ScreenTimeScheduleValidationError.invalidAllowanceMinutes
        }
        guard (0...Self.maximumDailyTicketCount).contains(dailyTicketCount) else {
            throw ScreenTimeScheduleValidationError.invalidTicketCount
        }
        guard (1...Self.maximumStudyMinutesPerEarnedMinute).contains(studyMinutesPerEarnedMinute) else {
            throw ScreenTimeScheduleValidationError.invalidEarnRate
        }
        guard (0...Self.maximumTicketCooldownMinutes).contains(ticketCooldownMinutes),
              (0...Self.maximumTicketCooldownMinutes).contains(ticketCooldownEscalationMinutes) else {
            throw ScreenTimeScheduleValidationError.invalidCooldownMinutes
        }
        let slots = enabledScheduleSlots
        let maximum = maximumEnabledSlotsForCurrentConfiguration
        guard slots.count <= maximum else {
            throw ScreenTimeScheduleValidationError.tooManyEnabledSlots(maximum: maximum)
        }
        if let invalidSlot = slots.first(where: {
            $0.durationMinutes < Self.minimumScheduleDurationMinutes
        }) {
            throw ScreenTimeScheduleValidationError.intervalTooShort(title: invalidSlot.title)
        }
    }

    mutating func normalizeActivitySelection() {
        activitySelection = Self.selectionIncludingEntireCategories(activitySelection)
        budgetSelection = Self.selectionIncludingEntireCategories(budgetSelection)
    }

    var canApplyRestrictions: Bool {
        isEnabled && (!allowedApplicationTokens.isEmpty || !allowedWebDomainTokens.isEmpty)
    }

    var hasBudgetSelection: Bool {
        !budgetApplicationTokens.isEmpty
            || !budgetCategoryTokens.isEmpty
            || !budgetWebDomainTokens.isEmpty
    }

    var canApplyBudgetRestrictions: Bool {
        false
    }

    /// 許可リストの選択が必要かどうか。許可リストが空だと壁そのものが立たない。
    var requiresAllowedSelection: Bool {
        guard isEnabled else { return false }
        if timerRestrictionEnabled || alwaysRestrictEnabled || goalRestrictionEnabled {
            return true
        }
        guard scheduledRestrictionEnabled else { return false }
        return enabledScheduleSlots.contains(where: { $0.behavior == .block })
    }

    /// 持ち時間ルールがオンなのに対象が空、という取り違えを検知する。
    var requiresBudgetSelection: Bool {
        false
    }

    var activeRuleCount: Int {
        guard isEnabled else { return 0 }
        return [
            goalRestrictionEnabled,
            timerRestrictionEnabled,
            scheduledRestrictionEnabled,
            alwaysRestrictEnabled
        ]
        .filter { $0 }
        .count
    }

    func activeScheduleSlots(at date: Date = Date(), calendar: Calendar = .current) -> [FocusScheduleSlot] {
        enabledScheduleSlots.filter { $0.contains(date, calendar: calendar) }
    }

    func hasActiveScheduleSlot(at date: Date = Date(), calendar: Calendar = .current) -> Bool {
        !activeScheduleSlots(at: date, calendar: calendar).isEmpty
    }

    func nextAllowedScheduleStart(
        after date: Date = Date(),
        calendar: Calendar = .current
    ) -> Date? {
        enabledScheduleSlots
            .filter { $0.behavior == .allow }
            .compactMap { $0.nextStart(after: date, calendar: calendar) }
            .min()
    }

    /// この設定でしきい値の階段が覆うべき天井（分）。
    var usageLadderCeilingMinutes: Int {
        ScreenTimeAllowance.ladderCeilingMinutes(
            for: ScreenTimeAllowance.maximumPossibleMinutes(settings: self)
        )
    }

    var usageMilestones: [Int] {
        ScreenTimeAllowance.usageMilestones(maximumMinutes: usageLadderCeilingMinutes)
    }

    var budgetMonitoringFingerprint: String {
        ScreenTimeBudgetFingerprint.value(selection: budgetSelection)
    }

    private static func selectionIncludingEntireCategories(
        _ selection: FamilyActivitySelection
    ) -> FamilyActivitySelection {
        guard !selection.includeEntireCategory else { return selection }
        var normalized = FamilyActivitySelection(includeEntireCategory: true)
        normalized.applicationTokens = selection.applicationTokens
        normalized.categoryTokens = selection.categoryTokens
        normalized.webDomainTokens = selection.webDomainTokens
        return normalized
    }
}

// MARK: - おすすめ設定

/// 初期状態が全オフだと、ユーザーは判定順まで理解しないと組み立てられない。
/// 使いすぎ防止として意味のある組み合わせを、1タップで入る形で用意する。
struct ScreenTimeFocusPreset: Identifiable {
    let id: String
    let title: String
    let summary: String
    let detail: String
    let icon: String
    let apply: (inout ScreenTimeFocusSettings) -> Void

    static let all: [ScreenTimeFocusPreset] = [gentle, night, strict]

    static let gentle = ScreenTimeFocusPreset(
        id: "gentle",
        title: "やさしく始める",
        summary: "タイマー中は集中＋チケット3枚",
        detail: "勉強タイマー中は対象アプリを制限します。必要なときは10分チケットを1日3枚まで使えます。",
        icon: "leaf.fill"
    ) { settings in
        settings.isEnabled = true
        settings.budgetRestrictionEnabled = false
        settings.earnedAllowanceEnabled = false
        settings.goalBonusAllowanceMinutes = 0
        settings.ticketsEnabled = true
        settings.dailyTicketCount = 3
        settings.ticketCooldownMinutes = 15
        settings.ticketCooldownEscalationMinutes = 15
        settings.goalRestrictionEnabled = false
        settings.alwaysRestrictEnabled = false
        settings.timerRestrictionEnabled = true
    }

    static let night = ScreenTimeFocusPreset(
        id: "night",
        title: "夜はしっかり止める",
        summary: "23時以降は交渉不可",
        detail: "勉強タイマー中と23:00〜6:00に制限します。夜間はチケットでも開けられません。",
        icon: "moon.stars.fill"
    ) { settings in
        settings.isEnabled = true
        settings.budgetRestrictionEnabled = false
        settings.earnedAllowanceEnabled = false
        settings.goalBonusAllowanceMinutes = 0
        settings.ticketsEnabled = true
        settings.dailyTicketCount = 2
        settings.ticketCooldownMinutes = 20
        settings.ticketCooldownEscalationMinutes = 20
        settings.timerRestrictionEnabled = true
        settings.scheduledRestrictionEnabled = true
        settings.scheduleSlots = [
            FocusScheduleSlot(
                title: "就寝時間",
                behavior: .block,
                startHour: 23,
                startMinute: 0,
                endHour: 6,
                endMinute: 0,
                allowsTicketBypass: false
            )
        ]
    }

    static let strict = ScreenTimeFocusPreset(
        id: "strict",
        title: "本気で減らす",
        summary: "目標達成まで制限",
        detail: "目標未達成の間と勉強タイマー中に制限し、23:00〜6:00はチケットでも開けられません。",
        icon: "flame.fill"
    ) { settings in
        settings.isEnabled = true
        settings.budgetRestrictionEnabled = false
        settings.earnedAllowanceEnabled = false
        settings.goalBonusAllowanceMinutes = 0
        settings.goalRestrictionEnabled = true
        settings.timerRestrictionEnabled = true
        settings.ticketsEnabled = true
        settings.dailyTicketCount = 1
        settings.ticketCooldownMinutes = 30
        settings.ticketCooldownEscalationMinutes = 30
        settings.scheduledRestrictionEnabled = true
        settings.scheduleSlots = [
            FocusScheduleSlot(
                title: "就寝時間",
                behavior: .block,
                startHour: 23,
                startMinute: 0,
                endHour: 6,
                endMinute: 0,
                allowsTicketBypass: false
            )
        ]
    }
}

// MARK: - 同期

/// Cloud-portable Screen Time policy. Family Controls tokens are deliberately
/// excluded because Apple treats them as opaque, device-local authorization data.
struct ScreenTimeSyncSettings: Codable, Hashable {
    static let stableSyncId = "screen-time-focus"

    var syncId: String
    var isEnabled: Bool
    var goalRestrictionEnabled: Bool
    var timerRestrictionEnabled: Bool
    var scheduledRestrictionEnabled: Bool
    var alwaysRestrictEnabled: Bool
    var ticketsEnabled: Bool
    var dailyTicketCount: Int
    var ticketCooldownMinutes: Int
    var ticketCooldownEscalationMinutes: Int
    var scheduleSlots: [FocusScheduleSlot]
    var selectionWasConfigured: Bool
    var settingsLockedUntilEpochMilliseconds: Int64?
    var updatedAt: Int64
    var deletedAt: Int64?

    init(settings: ScreenTimeFocusSettings) {
        syncId = Self.stableSyncId
        isEnabled = settings.isEnabled
        goalRestrictionEnabled = settings.goalRestrictionEnabled
        timerRestrictionEnabled = settings.timerRestrictionEnabled
        scheduledRestrictionEnabled = settings.scheduledRestrictionEnabled
        alwaysRestrictEnabled = settings.alwaysRestrictEnabled
        ticketsEnabled = settings.ticketsEnabled
        dailyTicketCount = settings.dailyTicketCount
        ticketCooldownMinutes = settings.ticketCooldownMinutes
        ticketCooldownEscalationMinutes = settings.ticketCooldownEscalationMinutes
        scheduleSlots = settings.scheduleSlots
        selectionWasConfigured = settings.selectionWasConfigured
        settingsLockedUntilEpochMilliseconds = settings.settingsLockedUntilEpochMilliseconds
        updatedAt = settings.updatedAt
        deletedAt = nil
    }

    private enum CodingKeys: String, CodingKey {
        case syncId
        case isEnabled
        case goalRestrictionEnabled
        case timerRestrictionEnabled
        case scheduledRestrictionEnabled
        case alwaysRestrictEnabled
        case budgetRestrictionEnabled
        case ticketsEnabled
        case baseAllowanceMinutes
        case earnedAllowanceEnabled
        case studyMinutesPerEarnedMinute
        case earnedAllowanceCapMinutes
        case goalBonusAllowanceMinutes
        case dailyTicketCount
        case ticketCooldownMinutes
        case ticketCooldownEscalationMinutes
        case scheduleSlots
        case selectionWasConfigured
        case budgetSelectionWasConfigured
        case settingsLockedUntilEpochMilliseconds
        case updatedAt
        case deletedAt

        case legacyTicketRestrictionEnabled = "ticketRestrictionEnabled"
        case legacyDailyTicketMinutes = "dailyTicketMinutes"
        case legacyUnlockRestrictionsWhenDailyGoalReached = "unlockRestrictionsWhenDailyGoalReached"
        // 「時間帯の外も制限」は `alwaysRestrictEnabled` へ統合済み。読み取り専用。
        case legacyRestrictOutsideSchedule = "restrictOutsideSchedule"
        case legacyRestrictOutsideScheduleWhenTicketsDisabled = "restrictOutsideScheduleWhenTicketsDisabled"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        syncId = try container.decodeIfPresent(String.self, forKey: .syncId) ?? Self.stableSyncId
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        timerRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .timerRestrictionEnabled) ?? false
        scheduledRestrictionEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .scheduledRestrictionEnabled
        ) ?? false

        let legacyTickets = try container.decodeIfPresent(Bool.self, forKey: .legacyTicketRestrictionEnabled)
        let legacyMinutes = try container.decodeIfPresent(Int.self, forKey: .legacyDailyTicketMinutes)
        let legacyOutside = try container.decodeIfPresent(Bool.self, forKey: .legacyRestrictOutsideSchedule)
            ?? container.decodeIfPresent(Bool.self, forKey: .legacyRestrictOutsideScheduleWhenTicketsDisabled)
        let legacyGoalUnlock = try container.decodeIfPresent(
            Bool.self,
            forKey: .legacyUnlockRestrictionsWhenDailyGoalReached
        )

        alwaysRestrictEnabled = ScreenTimeLegacyCompatibility.alwaysRestrict(
            alwaysRestrictEnabled: try container.decodeIfPresent(Bool.self, forKey: .alwaysRestrictEnabled),
            legacyTicketRestrictionEnabled: legacyTickets,
            legacyRestrictOutsideSchedule: legacyOutside,
            scheduledRestrictionEnabled: scheduledRestrictionEnabled
        )
        ticketsEnabled = try container.decodeIfPresent(Bool.self, forKey: .ticketsEnabled)
            ?? legacyTickets
            ?? false
        goalRestrictionEnabled = try container.decodeIfPresent(Bool.self, forKey: .goalRestrictionEnabled)
            ?? legacyGoalUnlock
            ?? false
        dailyTicketCount = try container.decodeIfPresent(Int.self, forKey: .dailyTicketCount)
            ?? legacyMinutes.map { $0 / ScreenTimeFocusSettings.ticketDurationMinutes }
            ?? 0
        ticketCooldownMinutes = try container.decodeIfPresent(Int.self, forKey: .ticketCooldownMinutes) ?? 0
        ticketCooldownEscalationMinutes = try container.decodeIfPresent(
            Int.self,
            forKey: .ticketCooldownEscalationMinutes
        ) ?? 0
        scheduleSlots = try container.decodeIfPresent([FocusScheduleSlot].self, forKey: .scheduleSlots) ?? []
        selectionWasConfigured = try container.decodeIfPresent(Bool.self, forKey: .selectionWasConfigured) ?? false
        settingsLockedUntilEpochMilliseconds = try container.decodeIfPresent(
            Int64.self,
            forKey: .settingsLockedUntilEpochMilliseconds
        )
        updatedAt = try container.decodeIfPresent(Int64.self, forKey: .updatedAt) ?? 0
        deletedAt = try container.decodeIfPresent(Int64.self, forKey: .deletedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(syncId, forKey: .syncId)
        try container.encode(isEnabled, forKey: .isEnabled)
        try container.encode(goalRestrictionEnabled, forKey: .goalRestrictionEnabled)
        try container.encode(timerRestrictionEnabled, forKey: .timerRestrictionEnabled)
        try container.encode(scheduledRestrictionEnabled, forKey: .scheduledRestrictionEnabled)
        try container.encode(alwaysRestrictEnabled, forKey: .alwaysRestrictEnabled)
        try container.encode(ticketsEnabled, forKey: .ticketsEnabled)
        try container.encode(dailyTicketCount, forKey: .dailyTicketCount)
        try container.encode(ticketCooldownMinutes, forKey: .ticketCooldownMinutes)
        try container.encode(ticketCooldownEscalationMinutes, forKey: .ticketCooldownEscalationMinutes)
        try container.encode(scheduleSlots, forKey: .scheduleSlots)
        try container.encode(selectionWasConfigured, forKey: .selectionWasConfigured)
        try container.encodeIfPresent(
            settingsLockedUntilEpochMilliseconds,
            forKey: .settingsLockedUntilEpochMilliseconds
        )
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }

    var requiresAllowedSelection: Bool {
        guard isEnabled else { return false }
        if timerRestrictionEnabled || alwaysRestrictEnabled || goalRestrictionEnabled {
            return true
        }
        guard scheduledRestrictionEnabled else { return false }
        return scheduleSlots.contains { $0.isEnabled && $0.behavior == .block && $0.hasSelectedWeekday }
    }

    func restoredSettings(
        preserving selection: FamilyActivitySelection,
        budgetSelection: FamilyActivitySelection
    ) -> ScreenTimeFocusSettings {
        ScreenTimeFocusSettings(
            isEnabled: isEnabled,
            goalRestrictionEnabled: goalRestrictionEnabled,
            timerRestrictionEnabled: timerRestrictionEnabled,
            scheduledRestrictionEnabled: scheduledRestrictionEnabled,
            alwaysRestrictEnabled: alwaysRestrictEnabled,
            ticketsEnabled: ticketsEnabled,
            dailyTicketCount: dailyTicketCount,
            ticketCooldownMinutes: ticketCooldownMinutes,
            ticketCooldownEscalationMinutes: ticketCooldownEscalationMinutes,
            scheduleSlots: scheduleSlots,
            activitySelection: selection,
            selectionWasConfigured: selectionWasConfigured,
            updatedAt: updatedAt,
            settingsLockedUntilEpochMilliseconds: settingsLockedUntilEpochMilliseconds
        )
    }

    func requiresSelectionConfirmation(
        preserving selection: FamilyActivitySelection,
        budgetSelection: FamilyActivitySelection
    ) -> Bool {
        let hasAllowlist = !selection.applicationTokens.isEmpty || !selection.webDomainTokens.isEmpty
        if !hasAllowlist, selectionWasConfigured || requiresAllowedSelection {
            return true
        }
        return false
    }
}

// MARK: - 判定

enum ScreenTimePolicyReason: String, Codable, Equatable {
    case masterDisabled
    /// チケットでも無料開放でも開けられない使用禁止時間帯。
    case lockedSchedule
    case studyTimer
    case blockedSchedule
    case dailyGoalPending
    case alwaysRestricted
    /// 対象アプリの持ち時間を使い切った。対象アプリだけがブロックされる。
    case budgetExhausted
    case activeTicket
    case allowedSchedule
    case dailyGoalReached
    case unrestricted
}

struct ScreenTimePolicyDecision: Equatable {
    /// 許可リスト以外すべてを止める壁が立っているか。
    var restrictsAllApps: Bool
    /// 持ち時間を使い切ったため、対象アプリだけを止めているか。
    var restrictsBudgetTargets: Bool
    var reason: ScreenTimePolicyReason
    /// チケット制が有効な間だけチケットを受け付ける。表示側が枚数やボタンを
    /// 出さないよう決定に含める。
    var ticketRestrictionEnabled: Bool = false
    /// いま立っている壁をチケットで開けられるか。交渉不可の時間帯と
    /// 持ち時間の使い切りは開けられない。
    var isTicketBypassable: Bool = false
    var hasActiveTicket: Bool = false

    var isRestricted: Bool {
        restrictsAllApps || restrictsBudgetTargets
    }

    var canStartTicket: Bool {
        ticketRestrictionEnabled && isTicketBypassable && restrictsAllApps && !hasActiveTicket
    }
}

/// 各ルールを独立に評価して重ね合わせる。
///
/// 以前は先に成立したルールで打ち切っていたため、「目標未達成なら制限」と
/// 「就寝時間は必ず制限」を同時に成り立たせられなかった。現在はハード制限
/// （交渉不可）・交渉可能な制限・持ち時間の3層を別々に求めて合成する。
enum ScreenTimePolicyEvaluator {
    static func evaluate(
        settings: ScreenTimeFocusSettings,
        ledger: ScreenTimeTicketLedger?,
        dailyGoalProgress: ScreenTimeDailyGoalProgress?,
        runtimeState: ScreenTimeRuntimeState,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> ScreenTimePolicyDecision {
        guard settings.isEnabled else {
            return ScreenTimePolicyDecision(
                restrictsAllApps: false,
                restrictsBudgetTargets: false,
                reason: .masterDisabled
            )
        }

        let ticketsEnabled = settings.ticketsEnabled
        let hasActiveTicket = ticketsEnabled
            && ledger?.hasActiveTicket(at: referenceDate, calendar: calendar) == true
        let activeSlots = settings.activeScheduleSlots(at: referenceDate, calendar: calendar)
        let hasAllowWindow = activeSlots.contains { $0.behavior == .allow }

        // 第1層: 交渉不可のハード制限。チケットも無料開放も効かない。
        let hasLockedBlock = activeSlots.contains { $0.isNonNegotiableBlock }

        // 第2層: 交渉可能な制限。より具体的な理由を優先して1つ選ぶ。
        var negotiableReason: ScreenTimePolicyReason?
        if settings.timerRestrictionEnabled, runtimeState.isTimerRestrictionActive(at: referenceDate) {
            negotiableReason = .studyTimer
        } else if activeSlots.contains(where: { $0.behavior == .block && $0.allowsTicketBypass }) {
            negotiableReason = .blockedSchedule
        } else if settings.goalRestrictionEnabled, !isGoalReached(
            settings: settings,
            progress: dailyGoalProgress,
            referenceDate: referenceDate,
            calendar: calendar
        ) {
            negotiableReason = .dailyGoalPending
        } else if settings.alwaysRestrictEnabled {
            negotiableReason = .alwaysRestricted
        }

        // 無料開放とチケットは、交渉可能な制限だけを解除する。
        var negotiableSuppressedBy: ScreenTimePolicyReason?
        if negotiableReason != nil {
            if hasAllowWindow {
                negotiableSuppressedBy = .allowedSchedule
            } else if hasActiveTicket {
                negotiableSuppressedBy = .activeTicket
            }
        }
        let negotiableApplies = negotiableReason != nil && negotiableSuppressedBy == nil

        let restrictsAllApps = hasLockedBlock || negotiableApplies
        let reason = resolveReason(
            hasLockedBlock: hasLockedBlock,
            negotiableReason: negotiableApplies ? negotiableReason : nil,
            negotiableSuppressedBy: negotiableSuppressedBy,
            budgetExhausted: false,
            hasAllowWindow: hasAllowWindow,
            settings: settings,
            progress: dailyGoalProgress,
            referenceDate: referenceDate,
            calendar: calendar
        )

        return ScreenTimePolicyDecision(
            restrictsAllApps: restrictsAllApps,
            restrictsBudgetTargets: false,
            reason: reason,
            ticketRestrictionEnabled: ticketsEnabled,
            // 交渉可能な制限が立っているときだけチケットに意味がある。
            isTicketBypassable: !hasLockedBlock && negotiableApplies,
            hasActiveTicket: hasActiveTicket
        )
    }

    static func isGoalReached(
        settings: ScreenTimeFocusSettings,
        progress: ScreenTimeDailyGoalProgress?,
        referenceDate: Date = Date(),
        calendar: Calendar = .current
    ) -> Bool {
        guard let progress else { return false }
        return progress.liftsGoalRestriction(on: referenceDate, calendar: calendar)
    }

    private static func resolveReason(
        hasLockedBlock: Bool,
        negotiableReason: ScreenTimePolicyReason?,
        negotiableSuppressedBy: ScreenTimePolicyReason?,
        budgetExhausted: Bool,
        hasAllowWindow: Bool,
        settings: ScreenTimeFocusSettings,
        progress: ScreenTimeDailyGoalProgress?,
        referenceDate: Date,
        calendar: Calendar
    ) -> ScreenTimePolicyReason {
        if hasLockedBlock {
            return .lockedSchedule
        }
        if let negotiableReason {
            return negotiableReason
        }
        if budgetExhausted {
            return .budgetExhausted
        }
        if let negotiableSuppressedBy {
            return negotiableSuppressedBy
        }
        if hasAllowWindow {
            return .allowedSchedule
        }
        if settings.goalRestrictionEnabled,
           isGoalReached(
            settings: settings,
            progress: progress,
            referenceDate: referenceDate,
            calendar: calendar
           ) {
            return .dailyGoalReached
        }
        return .unrestricted
    }
}

enum ScreenTimeRestrictionApplyResult: Equatable {
    case inactive
    case missingAllowedSelection
    case missingBudgetSelection
    case applied
}

// MARK: - 共有ストア

enum ScreenTimeFocusShared {
    static let appGroupIdentifier = "group.com.studyapp.ios.shared"
    static let settingsKey = "screenTimeFocusSettings.v1"
    static let dailyGoalProgressKey = "screenTimeFocusDailyGoalProgress.v1"
    static let runtimeStateKey = "screenTimeRuntimeState.v1"
    static let restoredSelectionRequiredKey = "screenTimeFocusRestoredSelectionRequired.v1"
    static let budgetFingerprintKey = "screenTimeFocusBudgetFingerprint.v1"
    static let budgetLadderCeilingKey = "screenTimeFocusBudgetLadderCeiling.v1"
    static let scheduleActivityNamePrefix = "studyapp.focus.schedule."
    static let dailyBoundaryActivityName = DeviceActivityName("studyapp.focus.daily-boundary")
    static let ticketExpiryActivityName = DeviceActivityName("studyapp.focus.ticket-expiry")
    static let timerExpiryActivityName = DeviceActivityName("studyapp.focus.timer-expiry")
    static let budgetActivityName = DeviceActivityName("studyapp.focus.budget")
    static let usageEventNamePrefix = "studyapp.focus.usage."
    static let policyStoreName = ManagedSettingsStore.Name("studyapp.focus.policy")
    static let budgetStoreName = ManagedSettingsStore.Name("studyapp.focus.budget")
    static let legacyTimerStoreName = ManagedSettingsStore.Name("studyapp.focus.timer")
    static let legacyScheduleStoreName = ManagedSettingsStore.Name("studyapp.focus.schedule")

    static var allScheduleActivityNames: [DeviceActivityName] {
        loadSettings().scheduleSlots.map(\.activityName)
    }

    static func usageEventName(minutes: Int) -> DeviceActivityEvent.Name {
        DeviceActivityEvent.Name("\(usageEventNamePrefix)\(minutes)")
    }

    /// イベント名から到達した分数を取り出す。到達段のうち最大値を実使用の下限として扱う。
    static func usageMinutes(fromEventName name: DeviceActivityEvent.Name) -> Int? {
        guard name.rawValue.hasPrefix(usageEventNamePrefix) else { return nil }
        return Int(name.rawValue.dropFirst(usageEventNamePrefix.count))
    }

    static func loadSettings() -> ScreenTimeFocusSettings {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: settingsKey),
              var settings = try? JSONDecoder().decode(ScreenTimeFocusSettings.self, from: data) else {
            return ScreenTimeFocusSettings()
        }
        if settings.updatedAt == 0, settings.hasMeaningfulConfiguration {
            settings.updatedAt = ScreenTimeDateMath.epochMilliseconds(for: Date())
            if let migrated = try? JSONEncoder().encode(settings) {
                defaults.set(migrated, forKey: settingsKey)
            }
        }
        return settings
    }

    @discardableResult
    static func saveSettings(_ settings: ScreenTimeFocusSettings) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(settings) else {
            return false
        }
        defaults.set(data, forKey: settingsKey)
        return true
    }

    static func loadSyncSettings() -> ScreenTimeSyncSettings? {
        let settings = loadSettings()
        guard settings.updatedAt > 0, settings.hasMeaningfulConfiguration else { return nil }
        return ScreenTimeSyncSettings(settings: settings)
    }

    @discardableResult
    static func applySyncedSettings(_ synced: ScreenTimeSyncSettings) -> Bool {
        let current = loadSettings()
        let requiresSelection = synced.requiresSelectionConfirmation(
            preserving: current.activitySelection,
            budgetSelection: current.budgetSelection
        )
        let restored = synced.restoredSettings(
            preserving: current.activitySelection,
            budgetSelection: current.budgetSelection
        )
        guard saveSettings(restored),
              let defaults = UserDefaults(suiteName: appGroupIdentifier) else {
            return false
        }
        defaults.set(requiresSelection, forKey: restoredSelectionRequiredKey)
        return true
    }

    static var isRestoredSelectionRequired: Bool {
        UserDefaults(suiteName: appGroupIdentifier)?
            .bool(forKey: restoredSelectionRequiredKey) == true
    }

    static func setRestoredSelectionRequired(_ required: Bool) {
        UserDefaults(suiteName: appGroupIdentifier)?
            .set(required, forKey: restoredSelectionRequiredKey)
    }

    static var budgetMonitoringFingerprint: String? {
        UserDefaults(suiteName: appGroupIdentifier)?.string(forKey: budgetFingerprintKey)
    }

    static func setBudgetMonitoringFingerprint(_ fingerprint: String?) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        if let fingerprint {
            defaults.set(fingerprint, forKey: budgetFingerprintKey)
        } else {
            defaults.removeObject(forKey: budgetFingerprintKey)
        }
    }

    /// 登録済みのしきい値の階段が覆っている天井（分）。0 は未登録。
    static var budgetLadderCeilingMinutes: Int {
        UserDefaults(suiteName: appGroupIdentifier)?.integer(forKey: budgetLadderCeilingKey) ?? 0
    }

    static func setBudgetLadderCeilingMinutes(_ minutes: Int?) {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier) else { return }
        if let minutes {
            defaults.set(minutes, forKey: budgetLadderCeilingKey)
        } else {
            defaults.removeObject(forKey: budgetLadderCeilingKey)
        }
    }

    static func loadDailyGoalProgress() -> ScreenTimeDailyGoalProgress? {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: dailyGoalProgressKey) else {
            return nil
        }
        return try? JSONDecoder().decode(ScreenTimeDailyGoalProgress.self, from: data)
    }

    @discardableResult
    static func saveDailyGoalProgress(_ progress: ScreenTimeDailyGoalProgress) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(progress) else {
            return false
        }
        defaults.set(data, forKey: dailyGoalProgressKey)
        return true
    }

    static func loadRuntimeState() -> ScreenTimeRuntimeState {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = defaults.data(forKey: runtimeStateKey),
              let state = try? JSONDecoder().decode(ScreenTimeRuntimeState.self, from: data) else {
            return ScreenTimeRuntimeState()
        }
        return state
    }

    @discardableResult
    static func saveRuntimeState(_ state: ScreenTimeRuntimeState) -> Bool {
        guard let defaults = UserDefaults(suiteName: appGroupIdentifier),
              let data = try? JSONEncoder().encode(state) else {
            return false
        }
        defaults.set(data, forKey: runtimeStateKey)
        return true
    }

    /// 許可リスト以外すべてを止める壁。
    static func applyRestrictions(
        using store: ManagedSettingsStore,
        settings: ScreenTimeFocusSettings
    ) -> ScreenTimeRestrictionApplyResult {
        guard settings.isEnabled else {
            clearRestrictions(using: store)
            return .inactive
        }
        guard settings.canApplyRestrictions else {
            clearRestrictions(using: store)
            return .missingAllowedSelection
        }
        store.shield.applicationCategories = .all(except: settings.allowedApplicationTokens)
        store.shield.webDomainCategories = .all(except: settings.allowedWebDomainTokens)
        return .applied
    }

    /// 持ち時間を使い切ったときに、対象として選ばれたものだけを止める壁。
    /// 許可リストの壁とは別ストアなので、両方が同時に立っても互いを消さない。
    static func applyBudgetRestrictions(
        using store: ManagedSettingsStore,
        settings: ScreenTimeFocusSettings
    ) -> ScreenTimeRestrictionApplyResult {
        guard settings.isEnabled, settings.budgetRestrictionEnabled else {
            clearRestrictions(using: store)
            return .inactive
        }
        guard settings.hasBudgetSelection else {
            clearRestrictions(using: store)
            return .missingBudgetSelection
        }
        let applications = settings.budgetApplicationTokens
        let categories = settings.budgetCategoryTokens
        let webDomains = settings.budgetWebDomainTokens
        store.shield.applications = applications.isEmpty ? nil : applications
        store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
        store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
        store.shield.webDomainCategories = categories.isEmpty ? nil : .specific(categories)
        return .applied
    }

    static func clearRestrictions(using store: ManagedSettingsStore) {
        store.shield.applicationCategories = nil
        store.shield.applications = nil
        store.shield.webDomainCategories = nil
        store.shield.webDomains = nil
    }
}
