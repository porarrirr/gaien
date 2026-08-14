import FamilyControls
import XCTest
@testable import StudyApp

// MARK: - 移行

final class ScreenTimeSettingsMigrationTests: XCTestCase {
    /// 旧「チケット制」は「常に制限」と「チケットを使える」が一体だった。
    /// 分解しても実挙動が変わらないことを確かめる。
    func testLegacyTicketRestrictionSplitsIntoAlwaysRestrictAndTickets() throws {
        let json = """
        {
          "isEnabled": true,
          "ticketRestrictionEnabled": true,
          "dailyTicketMinutes": 60,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.alwaysRestrictEnabled)
        XCTAssertTrue(settings.ticketsEnabled)
        XCTAssertEqual(settings.baseAllowanceMinutes, 60)
        XCTAssertEqual(settings.dailyTicketCount, 6)
        XCTAssertFalse(settings.budgetRestrictionEnabled)
    }

    func testLegacyGoalUnlockBecomesGoalRestriction() throws {
        let json = """
        {
          "isEnabled": true,
          "unlockRestrictionsWhenDailyGoalReached": true,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.goalRestrictionEnabled)
    }

    /// 「時間帯の外も制限」は「常に制限」へ統合した。時間帯ルールがオンだったときは
    /// 壁が立っていたので、そのまま引き継ぐ。
    func testLegacyRestrictOutsideScheduleBecomesAlwaysRestrict() throws {
        let json = """
        {
          "isEnabled": true,
          "scheduledRestrictionEnabled": true,
          "restrictOutsideSchedule": true,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.alwaysRestrictEnabled)
    }

    /// さらに古いキーからも同じように引き継ぐ。
    func testLegacyOutsideScheduleKeyFromOlderBuildsBecomesAlwaysRestrict() throws {
        let json = """
        {
          "isEnabled": true,
          "scheduledRestrictionEnabled": true,
          "restrictOutsideScheduleWhenTicketsDisabled": true,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.alwaysRestrictEnabled)
    }

    /// 時間帯ルールがオフなら旧設定でも壁は立っていなかった。引き継ぐと制限が増えてしまう。
    func testLegacyRestrictOutsideScheduleIsDroppedWhenScheduleRuleWasOff() throws {
        let json = """
        {
          "isEnabled": true,
          "scheduledRestrictionEnabled": false,
          "restrictOutsideSchedule": true,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertFalse(settings.alwaysRestrictEnabled)
    }

    /// 同期で行き来しても値が揺れないよう、移行後の設定は再デコードしても同じになる。
    func testMigratedSettingsRoundTripStable() throws {
        let json = """
        {
          "isEnabled": true,
          "scheduledRestrictionEnabled": true,
          "restrictOutsideSchedule": true,
          "scheduleSlots": []
        }
        """

        let migrated = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))
        let encoded = try JSONEncoder().encode(migrated)
        let reloaded = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: encoded)

        XCTAssertEqual(migrated, reloaded)
        XCTAssertFalse(
            String(decoding: encoded, as: UTF8.self).contains("restrictOutsideSchedule")
        )
    }

    /// クラウドに残っている旧フォーマットの同期設定も同じ規則で移行する。
    func testLegacySyncSettingsMigrateOutsideScheduleToAlwaysRestrict() throws {
        let json = """
        {
          "syncId": "screen-time-focus",
          "isEnabled": true,
          "scheduledRestrictionEnabled": true,
          "restrictOutsideSchedule": true,
          "scheduleSlots": [],
          "updatedAt": 12
        }
        """

        let synced = try JSONDecoder().decode(ScreenTimeSyncSettings.self, from: Data(json.utf8))

        XCTAssertTrue(synced.alwaysRestrictEnabled)
        XCTAssertFalse(
            String(decoding: try JSONEncoder().encode(synced), as: UTF8.self)
                .contains("restrictOutsideSchedule")
        )
    }

    func testLegacySlotDefaultsToTicketBypassable() throws {
        let json = """
        {
          "isEnabled": true,
          "scheduledRestrictionEnabled": true,
          "scheduleSlots": [{
            "id": "legacy",
            "title": "従来の制限",
            "isEnabled": true,
            "startHour": 9,
            "startMinute": 0,
            "endHour": 18,
            "endMinute": 0
          }]
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))
        let slot = try XCTUnwrap(settings.scheduleSlots.first)

        XCTAssertEqual(slot.behavior, .block)
        XCTAssertTrue(slot.allowsTicketBypass)
        XCTAssertFalse(slot.isNonNegotiableBlock)
    }

    /// 旧バージョンの端末と同期しても設定が失われないよう、旧キーも書き出している。
    func testEncodedSettingsKeepLegacyKeysForOlderDevices() throws {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true,
            alwaysRestrictEnabled: true,
            ticketsEnabled: true,
            baseAllowanceMinutes: 45,
            dailyTicketCount: 3,
            updatedAt: 1
        )

        let json = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)

        XCTAssertTrue(json.contains("\"ticketRestrictionEnabled\":true"))
        // 旧端末は10分刻みでしか検証を通らないため、45分は40分へ切り下げて渡す。
        // そのまま45を渡すと旧端末側で設定を一切保存できなくなる。
        XCTAssertTrue(json.contains("\"dailyTicketMinutes\":40"))
        XCTAssertTrue(json.contains("\"unlockRestrictionsWhenDailyGoalReached\":true"))
        // 「時間帯の外も制限」は統合済み。旧端末も `ticketRestrictionEnabled` を読んで
        // 同じ壁を立てるので、統合前のキーは書き出さない。
        XCTAssertFalse(json.contains("restrictOutsideSchedule"))
    }

    /// 旧端末の「目標達成で終日開放」は交渉不可の枠も開けてしまう。
    /// その枠があるときは互換キーを立てず、安全側（制限を続ける）に倒す。
    func testLegacyGoalUnlockIsSuppressedWhenANonNegotiableSlotExists() throws {
        var settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: [
                FocusScheduleSlot(
                    id: "night",
                    behavior: .block,
                    startHour: 23,
                    endHour: 6,
                    allowsTicketBypass: false
                )
            ],
            updatedAt: 1
        )

        var json = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        XCTAssertTrue(json.contains("\"unlockRestrictionsWhenDailyGoalReached\":false"))

        // 交渉可能な枠だけなら、旧端末でも挙動が大きくは変わらないので立てる。
        settings.scheduleSlots[0].allowsTicketBypass = true
        json = String(decoding: try JSONEncoder().encode(settings), as: UTF8.self)
        XCTAssertTrue(json.contains("\"unlockRestrictionsWhenDailyGoalReached\":true"))
    }

    func testLegacyDailyTicketMinutesAlwaysLandsOnTheOldTenMinuteGrid() {
        for minutes in stride(from: 0, through: ScreenTimeFocusSettings.maximumAllowanceMinutes, by: 5) {
            let legacy = ScreenTimeLegacyCompatibility.dailyTicketMinutes(minutes)
            XCTAssertTrue(
                legacy.isMultiple(of: ScreenTimeFocusSettings.ticketDurationMinutes),
                "\(minutes)分 → \(legacy)分 が10分刻みになっていない"
            )
            XCTAssertLessThanOrEqual(legacy, minutes)
        }
    }

    func testSettingsRoundTripPreservesNewFields() throws {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            budgetRestrictionEnabled: true,
            ticketsEnabled: true,
            baseAllowanceMinutes: 60,
            earnedAllowanceEnabled: true,
            studyMinutesPerEarnedMinute: 4,
            earnedAllowanceCapMinutes: 90,
            goalBonusAllowanceMinutes: 15,
            dailyTicketCount: 2,
            ticketCooldownMinutes: 20,
            ticketCooldownEscalationMinutes: 10,
            scheduleSlots: [
                FocusScheduleSlot(id: "night", behavior: .block, allowsTicketBypass: false)
            ],
            updatedAt: 99
        )

        let decoded = try JSONDecoder().decode(
            ScreenTimeFocusSettings.self,
            from: try JSONEncoder().encode(settings)
        )

        XCTAssertEqual(decoded.baseAllowanceMinutes, 60)
        XCTAssertEqual(decoded.studyMinutesPerEarnedMinute, 4)
        XCTAssertEqual(decoded.earnedAllowanceCapMinutes, 90)
        XCTAssertEqual(decoded.goalBonusAllowanceMinutes, 15)
        XCTAssertEqual(decoded.dailyTicketCount, 2)
        XCTAssertEqual(decoded.ticketCooldownMinutes, 20)
        XCTAssertEqual(decoded.ticketCooldownEscalationMinutes, 10)
        XCTAssertEqual(decoded.scheduleSlots.first?.allowsTicketBypass, false)
    }

    func testSyncSettingsExcludeRemovedBudgetFieldsAndDeviceLocalSelections() throws {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            budgetRestrictionEnabled: true,
            selectionWasConfigured: true,
            budgetSelectionWasConfigured: true,
            updatedAt: 5
        )

        let synced = ScreenTimeSyncSettings(settings: settings)
        let json = String(decoding: try JSONEncoder().encode(synced), as: UTF8.self)

        XCTAssertTrue(synced.selectionWasConfigured)
        XCTAssertFalse(json.contains("activitySelection"))
        XCTAssertFalse(json.contains("budgetSelection\":{"))
        XCTAssertFalse(json.contains("applicationTokens"))
        XCTAssertFalse(json.contains("budgetRestrictionEnabled"))
        XCTAssertFalse(json.contains("baseAllowanceMinutes"))
        XCTAssertFalse(json.contains("earnedAllowanceEnabled"))
        XCTAssertFalse(json.contains("goalBonusAllowanceMinutes"))
        XCTAssertFalse(json.contains("ticketRestrictionEnabled"))
        XCTAssertFalse(json.contains("dailyTicketMinutes"))
        XCTAssertFalse(json.contains("unlockRestrictionsWhenDailyGoalReached"))
        XCTAssertFalse(json.contains("restrictOutsideSchedule"))
        XCTAssertFalse(json.contains("locationRestrictionEnabled"))
        XCTAssertFalse(json.contains("locationZones"))
    }

    func testRestoredRemovedBudgetSettingsDoNotRequireSelectionConfirmation() {
        let synced = ScreenTimeSyncSettings(
            settings: ScreenTimeFocusSettings(
                isEnabled: true,
                budgetRestrictionEnabled: true,
                budgetSelectionWasConfigured: true,
                updatedAt: 7
            )
        )
        let empty = FamilyActivitySelection(includeEntireCategory: true)

        XCTAssertFalse(
            synced.requiresSelectionConfirmation(preserving: empty, budgetSelection: empty)
        )
        let restored = synced.restoredSettings(preserving: empty, budgetSelection: empty)
        XCTAssertFalse(restored.budgetRestrictionEnabled)
        XCTAssertEqual(restored.updatedAt, 7)
    }

    func testLegacyRuntimeStateDecodeDefaultsTimerExpiryToNil() throws {
        let json = """
        {
          "timerIsRunning": true,
          "updatedAt": 1000
        }
        """

        let runtime = try JSONDecoder().decode(ScreenTimeRuntimeState.self, from: Data(json.utf8))

        XCTAssertTrue(runtime.timerIsRunning)
        XCTAssertNil(runtime.timerRestrictionEndsAt)
    }

    func testStudySessionDecodeDefaultsScreenTimeUnlockExcludedToFalse() throws {
        let json = """
        {
          "id": 1,
          "syncId": "session-1",
          "subjectId": 1,
          "subjectName": "数学",
          "sessionType": "STOPWATCH",
          "startTime": 1000,
          "endTime": 61000,
          "intervals": [],
          "problemRecords": [],
          "createdAt": 1000,
          "updatedAt": 1000
        }
        """

        let session = try JSONDecoder().decode(StudySession.self, from: Data(json.utf8))

        XCTAssertFalse(session.screenTimeUnlockExcluded)
        XCTAssertTrue(session.countsTowardScreenTimeDailyGoalUnlock)
    }

    func testLegacySettingsDecodeWithoutLocationKeys() throws {
        let json = """
        {
          "isEnabled": true,
          "scheduledRestrictionEnabled": true,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertFalse(settings.locationRestrictionEnabled)
        XCTAssertTrue(settings.locationZones.isEmpty)
    }

    func testRestoredSyncSettingsPreserveLocalLocationZones() throws {
        let localZone = FocusLocationZone(
            id: "school",
            title: "学校",
            latitude: 35.6812,
            longitude: 139.7671,
            coordinateWasSet: true,
            radiusMeters: 200,
            allowsTicketBypass: false
        )
        let synced = ScreenTimeSyncSettings(
            settings: ScreenTimeFocusSettings(
                isEnabled: true,
                alwaysRestrictEnabled: true,
                updatedAt: 9
            )
        )
        let empty = FamilyActivitySelection(includeEntireCategory: true)

        let restored = synced.restoredSettings(
            preserving: empty,
            budgetSelection: empty,
            locationRestrictionEnabled: true,
            locationZones: [localZone]
        )

        XCTAssertTrue(restored.locationRestrictionEnabled)
        XCTAssertEqual(restored.locationZones, [localZone])
        XCTAssertTrue(restored.alwaysRestrictEnabled)
        XCTAssertEqual(restored.updatedAt, 9)
    }
}

// MARK: - ルールの合成

final class ScreenTimePolicyCompositionTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// 2026-06-15 は月曜。
    private func date(_ day: Int = 15, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func ledger(
        at referenceDate: Date,
        issued: Int = 3,
        used: Int = 0,
        activeUntil: Date? = nil,
        allowance: Int = 0,
        usage: Int = 0
    ) -> ScreenTimeTicketLedger {
        ScreenTimeTicketLedger(
            dayStart: ScreenTimeDateMath.epochMilliseconds(
                for: calendar.startOfDay(for: referenceDate)
            ),
            issuedLocalDayOrdinal: ScreenTimeDateMath.localDayOrdinal(
                for: referenceDate,
                calendar: calendar
            ),
            baseAllowanceMinutes: allowance,
            usageMilestoneMinutes: usage,
            issuedTicketCount: issued,
            usedTicketCount: used,
            activeTicketStartedAt: activeUntil == nil
                ? nil
                : ScreenTimeDateMath.epochMilliseconds(for: referenceDate),
            activeTicketEndsAt: activeUntil.map(ScreenTimeDateMath.epochMilliseconds),
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: referenceDate)
        )
    }

    private func goal(at referenceDate: Date, studied: Int, target: Int) -> ScreenTimeDailyGoalProgress {
        ScreenTimeDailyGoalProgress(
            dayStart: ScreenTimeDateMath.epochMilliseconds(
                for: calendar.startOfDay(for: referenceDate)
            ),
            studyMinutes: studied,
            targetMinutes: target,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: referenceDate)
        )
    }

    private func decision(
        settings: ScreenTimeFocusSettings,
        ledger: ScreenTimeTicketLedger? = nil,
        goal: ScreenTimeDailyGoalProgress? = nil,
        timerRunning: Bool = false,
        timerRestrictionEnd: Date? = nil,
        at referenceDate: Date
    ) -> ScreenTimePolicyDecision {
        ScreenTimePolicyEvaluator.evaluate(
            settings: settings,
            ledger: ledger,
            dailyGoalProgress: goal,
            runtimeState: ScreenTimeRuntimeState(
                timerIsRunning: timerRunning,
                timerRestrictionEndsAt: timerRestrictionEnd.map(ScreenTimeDateMath.epochMilliseconds)
            ),
            referenceDate: referenceDate,
            calendar: calendar
        )
    }

    private func nightSlot(negotiable: Bool) -> FocusScheduleSlot {
        FocusScheduleSlot(
            id: "night",
            title: "就寝時間",
            behavior: .block,
            startHour: 23,
            startMinute: 0,
            endHour: 6,
            endMinute: 0,
            allowsTicketBypass: negotiable
        )
    }

    func testMasterSwitchOffLeavesEverythingUnrestricted() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: false,
            alwaysRestrictEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 3
        )
        let result = decision(settings: settings, at: date())

        XCTAssertFalse(result.isRestricted)
        XCTAssertEqual(result.reason, .masterDisabled)
        XCTAssertFalse(result.canStartTicket)
    }

    /// 以前は目標達成で終日すべての制限が外れていた。就寝時間の壁が残ることを確認する。
    func testGoalReachedNoLongerUnlocksBlockedSchedule() {
        let now = date(hour: 23, minute: 30)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: [nightSlot(negotiable: true)]
        )

        let result = decision(
            settings: settings,
            goal: goal(at: now, studied: 120, target: 60),
            at: now
        )

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .blockedSchedule)
    }

    /// 目標未達成と就寝時間が同時に成り立つ場合、交渉不可の方が優先される。
    func testNonNegotiableScheduleWinsOverGoalRestriction() {
        let now = date(hour: 23, minute: 30)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 3,
            scheduleSlots: [nightSlot(negotiable: false)]
        )

        let result = decision(
            settings: settings,
            ledger: ledger(at: now),
            goal: goal(at: now, studied: 0, target: 60),
            at: now
        )

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .lockedSchedule)
        XCTAssertFalse(result.isTicketBypassable)
        XCTAssertFalse(result.canStartTicket)
    }

    func testActiveTicketDoesNotOpenNonNegotiableSchedule() {
        let now = date(hour: 23, minute: 30)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 3,
            scheduleSlots: [nightSlot(negotiable: false)]
        )

        let result = decision(
            settings: settings,
            ledger: ledger(at: now, used: 1, activeUntil: now.addingTimeInterval(10 * 60)),
            at: now
        )

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .lockedSchedule)
    }

    func testActiveTicketOpensNegotiableSchedule() {
        let now = date(hour: 23, minute: 30)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 3,
            scheduleSlots: [nightSlot(negotiable: true)]
        )

        let result = decision(
            settings: settings,
            ledger: ledger(at: now, used: 1, activeUntil: now.addingTimeInterval(10 * 60)),
            at: now
        )

        XCTAssertFalse(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .activeTicket)
    }

    func testTimerRestrictionAndGoalRestrictionBothApplyWithTimerReported() {
        let now = date(hour: 14)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true,
            timerRestrictionEnabled: true
        )

        let result = decision(
            settings: settings,
            goal: goal(at: now, studied: 10, target: 60),
            timerRunning: true,
            at: now
        )

        XCTAssertTrue(result.restrictsAllApps)
        // より具体的な理由（タイマー中）を表示する。
        XCTAssertEqual(result.reason, .studyTimer)
    }

    /// タイマーが止まっても目標未達成の制限は残る。以前は判定が打ち切られていた。
    func testGoalRestrictionRemainsAfterTimerStops() {
        let now = date(hour: 14)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true,
            timerRestrictionEnabled: true
        )

        let result = decision(
            settings: settings,
            goal: goal(at: now, studied: 10, target: 60),
            timerRunning: false,
            at: now
        )

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .dailyGoalPending)
    }

    func testGoalReachedReportsReachedWhenNothingElseRestricts() {
        let now = date(hour: 14)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true
        )

        let result = decision(
            settings: settings,
            goal: goal(at: now, studied: 90, target: 60),
            at: now
        )

        XCTAssertFalse(result.isRestricted)
        XCTAssertEqual(result.reason, .dailyGoalReached)
    }

    func testAllowWindowLiftsNegotiableBlockButNotLockedBlock() {
        let now = date(hour: 20)
        let allowSlot = FocusScheduleSlot(
            id: "allow",
            behavior: .allow,
            startHour: 20,
            startMinute: 0,
            endHour: 21,
            endMinute: 0
        )
        let overlappingBlock = FocusScheduleSlot(
            id: "block",
            behavior: .block,
            startHour: 19,
            startMinute: 0,
            endHour: 22,
            endMinute: 0,
            allowsTicketBypass: true
        )
        var settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: [allowSlot, overlappingBlock]
        )

        XCTAssertEqual(decision(settings: settings, at: now).reason, .allowedSchedule)
        XCTAssertFalse(decision(settings: settings, at: now).restrictsAllApps)

        settings.scheduleSlots = [
            allowSlot,
            FocusScheduleSlot(
                id: "block",
                behavior: .block,
                startHour: 19,
                startMinute: 0,
                endHour: 22,
                endMinute: 0,
                allowsTicketBypass: false
            )
        ]

        let locked = decision(settings: settings, at: now)
        XCTAssertTrue(locked.restrictsAllApps)
        XCTAssertEqual(locked.reason, .lockedSchedule)
    }

    /// 旧「時間帯の外も制限」の設定。統合後は `alwaysRestrictEnabled` として同じ壁が立ち、
    /// 無料開放の枠だけが穴を開ける。
    func testAlwaysRestrictBlocksOutsideAllowWindowEvenWithTicketsEnabled() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            alwaysRestrictEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 2,
            scheduleSlots: [
                FocusScheduleSlot(
                    id: "evening",
                    behavior: .allow,
                    startHour: 19,
                    startMinute: 0,
                    endHour: 21,
                    endMinute: 0
                )
            ]
        )

        let outside = date(hour: 10)
        let blocked = decision(settings: settings, ledger: ledger(at: outside), at: outside)
        XCTAssertTrue(blocked.restrictsAllApps)
        XCTAssertEqual(blocked.reason, .alwaysRestricted)
        XCTAssertTrue(blocked.isTicketBypassable)
        XCTAssertTrue(blocked.canStartTicket)

        let inside = date(hour: 20)
        let opened = decision(settings: settings, ledger: ledger(at: inside), at: inside)
        XCTAssertFalse(opened.restrictsAllApps)
        XCTAssertEqual(opened.reason, .allowedSchedule)
    }

    /// 移行の要。旧JSONをデコードした設定が、統合前とまったく同じ判定になる。
    func testMigratedLegacySettingsProduceSameDecisionAsBefore() throws {
        let json = """
        {
          "isEnabled": true,
          "scheduledRestrictionEnabled": true,
          "restrictOutsideSchedule": true,
          "ticketsEnabled": true,
          "dailyTicketCount": 2,
          "scheduleSlots": [{
            "id": "evening",
            "title": "夜の無料開放",
            "behavior": "allow",
            "isEnabled": true,
            "startHour": 19,
            "startMinute": 0,
            "endHour": 21,
            "endMinute": 0
          }]
        }
        """
        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        let outside = date(hour: 10)
        let blocked = decision(settings: settings, ledger: ledger(at: outside), at: outside)
        XCTAssertTrue(blocked.restrictsAllApps)
        XCTAssertTrue(blocked.isTicketBypassable)

        let inside = date(hour: 20)
        XCTAssertFalse(decision(settings: settings, ledger: ledger(at: inside), at: inside).restrictsAllApps)
    }

    func testAlwaysRestrictRequiresTicket() {
        let now = date(hour: 10)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            alwaysRestrictEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 2
        )

        let result = decision(settings: settings, ledger: ledger(at: now), at: now)

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .alwaysRestricted)
        XCTAssertTrue(result.canStartTicket)
    }

    func testTicketsDisabledNeverAllowsStartingATicket() {
        let now = date(hour: 10)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            alwaysRestrictEnabled: true,
            ticketsEnabled: false,
            dailyTicketCount: 5
        )

        let result = decision(settings: settings, ledger: ledger(at: now), at: now)

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertFalse(result.ticketRestrictionEnabled)
        XCTAssertFalse(result.canStartTicket)
    }

    /// 持ち時間ルールは対象が未選択だと成立しない（測れないため）。
    /// この状態は設定画面が赤で警告する。
    func testBudgetRuleWithoutSelectionDoesNotRestrict() {
        let now = date(hour: 10)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            budgetRestrictionEnabled: true,
            baseAllowanceMinutes: 0
        )

        let result = decision(
            settings: settings,
            ledger: ledger(at: now, allowance: 0, usage: 0),
            at: now
        )

        XCTAssertFalse(settings.hasBudgetSelection)
        XCTAssertFalse(settings.canApplyBudgetRestrictions)
        XCTAssertFalse(result.restrictsBudgetTargets)
        XCTAssertEqual(result.reason, .unrestricted)
    }

    /// 持ち時間の使い切りはチケットの対象外。決定の不変条件として固定する。
    func testBudgetExhaustionIsNotTicketBypassable() {
        let budgetOnly = ScreenTimePolicyDecision(
            restrictsAllApps: false,
            restrictsBudgetTargets: true,
            reason: .budgetExhausted,
            ticketRestrictionEnabled: true,
            isTicketBypassable: false,
            hasActiveTicket: false
        )

        XCTAssertTrue(budgetOnly.isRestricted)
        XCTAssertFalse(budgetOnly.canStartTicket)
    }

    func testActiveTicketBlocksStartingAnotherTicket() {
        let now = date(hour: 10)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            alwaysRestrictEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 3
        )

        let result = decision(
            settings: settings,
            ledger: ledger(at: now, used: 1, activeUntil: now.addingTimeInterval(60)),
            at: now
        )

        XCTAssertTrue(result.hasActiveTicket)
        XCTAssertFalse(result.canStartTicket)
    }
}

// MARK: - 持ち時間の計算

final class ScreenTimeAllowanceTests: XCTestCase {
    func testEarnedMinutesFollowExchangeRateAndCap() {
        let settings = ScreenTimeFocusSettings(
            earnedAllowanceEnabled: true,
            studyMinutesPerEarnedMinute: 3,
            earnedAllowanceCapMinutes: 20
        )

        XCTAssertEqual(ScreenTimeAllowance.earnedMinutes(studyMinutes: 0, settings: settings), 0)
        XCTAssertEqual(ScreenTimeAllowance.earnedMinutes(studyMinutes: 2, settings: settings), 0)
        XCTAssertEqual(ScreenTimeAllowance.earnedMinutes(studyMinutes: 30, settings: settings), 10)
        XCTAssertEqual(ScreenTimeAllowance.earnedMinutes(studyMinutes: 300, settings: settings), 20)
    }

    func testEarnedMinutesAreZeroWhenRuleIsOff() {
        let settings = ScreenTimeFocusSettings(
            earnedAllowanceEnabled: false,
            studyMinutesPerEarnedMinute: 3,
            earnedAllowanceCapMinutes: 60
        )

        XCTAssertEqual(ScreenTimeAllowance.earnedMinutes(studyMinutes: 120, settings: settings), 0)
    }

    func testBonusOnlyAppliesWhenGoalReached() {
        let settings = ScreenTimeFocusSettings(goalBonusAllowanceMinutes: 25)

        XCTAssertEqual(ScreenTimeAllowance.bonusMinutes(goalReached: false, settings: settings), 0)
        XCTAssertEqual(ScreenTimeAllowance.bonusMinutes(goalReached: true, settings: settings), 25)
    }

    func testMaximumPossibleMinutesSumsAllSources() {
        let settings = ScreenTimeFocusSettings(
            baseAllowanceMinutes: 60,
            earnedAllowanceEnabled: true,
            earnedAllowanceCapMinutes: 45,
            goalBonusAllowanceMinutes: 15
        )

        XCTAssertEqual(ScreenTimeAllowance.maximumPossibleMinutes(settings: settings), 120)
    }

    /// 使い切りの検知を取りこぼさないため、最大値は必ず段に含める。
    func testUsageMilestonesAlwaysIncludeMaximumAndStayWithinLimit() {
        for maximum in [1, 5, 18, 19, 30, 60, 120, 300, 720] {
            let milestones = ScreenTimeAllowance.usageMilestones(maximumMinutes: maximum)

            XCTAssertEqual(milestones.last, maximum, "maximum \(maximum)")
            XCTAssertLessThanOrEqual(
                milestones.count,
                ScreenTimeFocusSettings.maximumUsageMilestones,
                "maximum \(maximum)"
            )
            XCTAssertEqual(milestones, milestones.sorted(), "maximum \(maximum)")
            XCTAssertEqual(Set(milestones).count, milestones.count, "maximum \(maximum)")
            XCTAssertTrue(milestones.allSatisfy { $0 > 0 }, "maximum \(maximum)")
        }
    }

    func testUsageMilestonesAreEmptyWithoutAllowance() {
        XCTAssertTrue(ScreenTimeAllowance.usageMilestones(maximumMinutes: 0).isEmpty)
    }

    /// 段が密な低い側ほど誤差が小さい。表示の「目安」の根拠。
    func testMilestoneResolutionIsFinerThanTheAllowance() {
        let resolution = ScreenTimeAllowance.milestoneResolutionMinutes(maximumMinutes: 120)

        XCTAssertGreaterThan(resolution, 0)
        XCTAssertLessThan(resolution, 120)
    }
}

// MARK: - 台帳

final class ScreenTimeLedgerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int = 15, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(
            year: 2026,
            month: 6,
            day: day,
            hour: hour,
            minute: minute
        ))!
    }

    private func settings(
        base: Int = 60,
        tickets: Int = 3,
        cooldown: Int = 0,
        escalation: Int = 0,
        cap: Int = 60,
        earning: Bool = false,
        rate: Int = 3,
        bonus: Int = 0
    ) -> ScreenTimeFocusSettings {
        ScreenTimeFocusSettings(
            isEnabled: true,
            budgetRestrictionEnabled: true,
            ticketsEnabled: true,
            baseAllowanceMinutes: base,
            earnedAllowanceEnabled: earning,
            studyMinutesPerEarnedMinute: rate,
            earnedAllowanceCapMinutes: cap,
            goalBonusAllowanceMinutes: bonus,
            dailyTicketCount: tickets,
            ticketCooldownMinutes: cooldown,
            ticketCooldownEscalationMinutes: escalation
        )
    }

    func testFreshLedgerGrantsBaseAllowanceAndTickets() {
        let now = date()
        let ledger = ScreenTimeTicketLedger.make(
            settings: settings(base: 45, tickets: 2),
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(ledger.baseAllowanceMinutes, 45)
        XCTAssertEqual(ledger.totalAllowanceMinutes, 45)
        XCTAssertEqual(ledger.remainingAllowanceMinutes, 45)
        XCTAssertEqual(ledger.issuedTicketCount, 2)
        XCTAssertFalse(ledger.isBudgetExhausted(at: now, calendar: calendar))
    }

    func testZeroAllowanceCountsAsExhausted() {
        let now = date()
        let ledger = ScreenTimeTicketLedger.make(
            settings: settings(base: 0, tickets: 0),
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertTrue(ledger.isBudgetExhausted(at: now, calendar: calendar))
    }

    /// 監視の貼り直しでしきい値の起点が 0 に戻っても、記録は巻き戻らない。
    func testUsageBaselineSurvivesMonitoringRestart() {
        var ledger = ScreenTimeTicketLedger.make(
            settings: settings(),
            referenceDate: date(),
            calendar: calendar
        )

        XCTAssertTrue(ledger.recordUsageMilestone(minutes: 30))
        XCTAssertEqual(ledger.usageMilestoneMinutes, 30)

        ledger.markUsageMonitoringRestarted()

        // 貼り直し後の 5 分到達は、通算 35 分ではなく「まだ 30 分」を意味しない
        // ——ベースラインを足して 35 分になる。
        XCTAssertTrue(ledger.recordUsageMilestone(minutes: 5))
        XCTAssertEqual(ledger.usageMilestoneMinutes, 35)
    }

    func testUsageMilestonesOnlyRatchetUpward() {
        var ledger = ScreenTimeTicketLedger.make(
            settings: settings(),
            referenceDate: date(),
            calendar: calendar
        )

        XCTAssertTrue(ledger.recordUsageMilestone(minutes: 20))
        XCTAssertFalse(ledger.recordUsageMilestone(minutes: 10))
        XCTAssertEqual(ledger.usageMilestoneMinutes, 20)
    }

    func testStudyProgressFillsEarnedAndBonusAllowance() {
        let now = date()
        let config = settings(base: 30, cap: 40, earning: true, rate: 3, bonus: 20)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )

        let progress = ScreenTimeDailyGoalProgress(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: now)),
            studyMinutes: 90,
            targetMinutes: 60,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )

        XCTAssertTrue(ledger.applyStudyProgress(progress: progress, settings: config, goalReached: true))
        XCTAssertEqual(ledger.earnedAllowanceMinutes, 30)
        XCTAssertEqual(ledger.bonusAllowanceMinutes, 20)
        XCTAssertEqual(ledger.totalAllowanceMinutes, 80)
        XCTAssertEqual(ledger.studyMinutes, 90)
    }

    /// 枠が増えたら通知をもう一度出せるようにする。
    func testStudyProgressResetsUsageNotificationFlagsWhenAllowanceGrows() {
        let now = date()
        let config = settings(base: 10, cap: 60, earning: true, rate: 1)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )
        ledger.notifiedUsageWarning = true
        ledger.notifiedUsageExhausted = true

        let progress = ScreenTimeDailyGoalProgress(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: now)),
            studyMinutes: 30,
            targetMinutes: 0,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )

        XCTAssertTrue(ledger.applyStudyProgress(progress: progress, settings: config, goalReached: false))
        XCTAssertFalse(ledger.notifiedUsageWarning)
        XCTAssertFalse(ledger.notifiedUsageExhausted)
    }

    /// 消費が始まる前は自由に反映。始まったあとは減らす変更だけ即時。
    func testGrantRatchetDefersIncreasesOnceConsumptionStarted() {
        let now = date()
        var ledger = ScreenTimeTicketLedger.make(
            settings: settings(base: 60, tickets: 3),
            referenceDate: now,
            calendar: calendar
        )

        ledger.normalize(settings: settings(base: 90, tickets: 5), referenceDate: now, calendar: calendar)
        XCTAssertEqual(ledger.baseAllowanceMinutes, 90, "未消費なら増やす変更も反映する")
        XCTAssertEqual(ledger.issuedTicketCount, 5)

        XCTAssertTrue(ledger.recordUsageMilestone(minutes: 5))

        ledger.normalize(settings: settings(base: 180, tickets: 9), referenceDate: now, calendar: calendar)
        XCTAssertEqual(ledger.baseAllowanceMinutes, 90, "消費後は増やす変更を翌日まで持ち越す")
        XCTAssertEqual(ledger.issuedTicketCount, 5)

        ledger.normalize(settings: settings(base: 30, tickets: 1), referenceDate: now, calendar: calendar)
        XCTAssertEqual(ledger.baseAllowanceMinutes, 30, "減らす変更はすぐ反映する")
        XCTAssertEqual(ledger.issuedTicketCount, 1)
    }

    func testNormalizeRebuildsLedgerOnNewDay() {
        var ledger = ScreenTimeTicketLedger.make(
            settings: settings(base: 60, tickets: 3),
            referenceDate: date(15),
            calendar: calendar
        )
        ledger.recordUsageMilestone(minutes: 40)
        ledger.shieldInteractionCount = 4

        ledger.normalize(settings: settings(base: 60, tickets: 3), referenceDate: date(16), calendar: calendar)

        XCTAssertEqual(ledger.usageMilestoneMinutes, 0)
        XCTAssertEqual(ledger.usageBaselineMinutes, 0)
        XCTAssertEqual(ledger.shieldInteractionCount, 0)
        XCTAssertEqual(ledger.baseAllowanceMinutes, 60)
        XCTAssertEqual(ledger.issuedTicketCount, 3)
    }

    func testReserveTicketConsumesOneAndBlocksWhileActive() throws {
        let now = date()
        let config = settings(tickets: 2)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )
        let expiry = now.addingTimeInterval(10 * 60)

        try ledger.reserveTicket(start: now, expiry: expiry, settings: config, calendar: calendar)

        XCTAssertEqual(ledger.remainingTicketCount, 1)
        XCTAssertTrue(ledger.hasActiveTicket(at: now.addingTimeInterval(9 * 60), calendar: calendar))
        XCTAssertFalse(ledger.hasActiveTicket(at: expiry, calendar: calendar))

        XCTAssertThrowsError(
            try ledger.reserveTicket(
                start: now.addingTimeInterval(60),
                expiry: expiry,
                settings: config,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? ScreenTimeTicketLedgerMutationError, .activeTicket)
        }
    }

    func testReserveTicketRejectsWhenNoneRemaining() {
        let now = date()
        let config = settings(tickets: 0)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertThrowsError(
            try ledger.reserveTicket(
                start: now,
                expiry: now.addingTimeInterval(600),
                settings: config,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? ScreenTimeTicketLedgerMutationError, .noTicketsRemaining)
        }
    }

    /// 連続使用を防ぐクールダウン。以前は期限切れ直後に次を使えた。
    func testCooldownBlocksBackToBackTickets() throws {
        let now = date(hour: 10)
        let config = settings(tickets: 3, cooldown: 15)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )
        let expiry = now.addingTimeInterval(10 * 60)

        try ledger.reserveTicket(start: now, expiry: expiry, settings: config, calendar: calendar)
        ledger.endActiveTicket()

        XCTAssertEqual(ledger.lastTicketEndedAt, ScreenTimeDateMath.epochMilliseconds(for: expiry))
        XCTAssertTrue(ledger.isInTicketCooldown(at: expiry, settings: config))

        XCTAssertThrowsError(
            try ledger.reserveTicket(
                start: expiry,
                expiry: expiry.addingTimeInterval(600),
                settings: config,
                calendar: calendar
            )
        ) { error in
            guard case .cooldown(let until)? = error as? ScreenTimeTicketLedgerMutationError else {
                return XCTFail("Expected cooldown, got \(error)")
            }
            XCTAssertEqual(until, expiry.addingTimeInterval(15 * 60))
        }

        let afterCooldown = expiry.addingTimeInterval(15 * 60)
        XCTAssertFalse(ledger.isInTicketCooldown(at: afterCooldown, settings: config))
        XCTAssertNoThrow(
            try ledger.reserveTicket(
                start: afterCooldown,
                expiry: afterCooldown.addingTimeInterval(600),
                settings: config,
                calendar: calendar
            )
        )
    }

    /// 使うほど間隔が伸びる。
    func testCooldownEscalatesWithEachTicket() {
        let now = date()
        let config = settings(tickets: 5, cooldown: 10, escalation: 10)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(ledger.cooldownMinutes(settings: config), 0, "未使用なら待機なし")

        ledger.usedTicketCount = 1
        XCTAssertEqual(ledger.cooldownMinutes(settings: config), 10)

        ledger.usedTicketCount = 2
        XCTAssertEqual(ledger.cooldownMinutes(settings: config), 20)

        ledger.usedTicketCount = 3
        XCTAssertEqual(ledger.cooldownMinutes(settings: config), 30)
    }

    func testTicketDoesNotConsumeAllowanceMinutes() throws {
        let now = date()
        let config = settings(base: 60, tickets: 2)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )

        try ledger.reserveTicket(
            start: now,
            expiry: now.addingTimeInterval(600),
            settings: config,
            calendar: calendar
        )

        XCTAssertEqual(ledger.remainingAllowanceMinutes, 60)
        XCTAssertEqual(ledger.totalAllowanceMinutes, 60)
    }

    func testLedgerDecodesLegacyFileWithoutAllowanceFields() throws {
        let json = """
        {
          "dayStart": 1781827200000,
          "issuedTicketCount": 3,
          "usedTicketCount": 1,
          "updatedAt": 1781830800000
        }
        """

        let ledger = try JSONDecoder().decode(ScreenTimeTicketLedger.self, from: Data(json.utf8))

        XCTAssertEqual(ledger.issuedTicketCount, 3)
        XCTAssertEqual(ledger.usedTicketCount, 1)
        XCTAssertEqual(ledger.baseAllowanceMinutes, 0)
        XCTAssertEqual(ledger.usageMilestoneMinutes, 0)
        XCTAssertEqual(ledger.usageBaselineMinutes, 0)
        XCTAssertFalse(ledger.protectionInterrupted)
    }
}

// MARK: - 台帳ストア

final class ScreenTimeLedgerStoreTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour))!
    }

    private func makeStore() throws -> (ScreenTimeTicketLedgerStore, URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("ledger.json")
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        return (ScreenTimeTicketLedgerStore(fileURLProvider: { fileURL }), fileURL)
    }

    private var config: ScreenTimeFocusSettings {
        ScreenTimeFocusSettings(
            isEnabled: true,
            budgetRestrictionEnabled: true,
            ticketsEnabled: true,
            baseAllowanceMinutes: 60,
            dailyTicketCount: 3
        )
    }

    /// `loadRaw` は正規化しない。前日の台帳を履歴へ切り出すために必要。
    func testLoadRawKeepsStaleDayForArchiving() throws {
        let (store, _) = try makeStore()

        _ = try store.update(settings: config, referenceDate: date(15), calendar: calendar) { ledger in
            ledger.recordUsageMilestone(minutes: 40)
            ledger.shieldInteractionCount = 2
        }

        let raw = try XCTUnwrap(try store.loadRaw())
        XCTAssertEqual(raw.usageMilestoneMinutes, 40)
        XCTAssertEqual(raw.localDayOrdinal(calendar: calendar), 20_260_615)

        // 通常経路は翌日として読み直す。
        let normalized = try XCTUnwrap(
            try store.load(settings: config, referenceDate: date(16), calendar: calendar, createIfMissing: false)
        )
        XCTAssertEqual(normalized.usageMilestoneMinutes, 0)
        XCTAssertEqual(normalized.localDayOrdinal(calendar: calendar), 20_260_616)
    }

    func testReadOnlyLoadDoesNotCreateFile() throws {
        let (store, fileURL) = try makeStore()

        XCTAssertNil(try store.loadReadOnly(settings: config, referenceDate: date(15), calendar: calendar))
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testUpdatePersistsUsageAcrossLoads() throws {
        let (store, _) = try makeStore()

        _ = try store.update(settings: config, referenceDate: date(15), calendar: calendar) { ledger in
            ledger.recordUsageMilestone(minutes: 25)
        }

        let reloaded = try XCTUnwrap(
            try store.loadReadOnly(settings: config, referenceDate: date(15), calendar: calendar)
        )
        XCTAssertEqual(reloaded.usageMilestoneMinutes, 25)
        XCTAssertEqual(reloaded.remainingAllowanceMinutes, 35)
    }

    func testCorruptedFileSurfacesReadFailure() throws {
        let (store, fileURL) = try makeStore()
        try Data("not json".utf8).write(to: fileURL)

        XCTAssertThrowsError(
            try store.load(settings: config, referenceDate: date(15), calendar: calendar, createIfMissing: true)
        ) { error in
            XCTAssertEqual(
                error as? ScreenTimeTicketLedgerStoreError,
                ScreenTimeTicketLedgerStoreError.stateReadFailed
            )
        }
    }
}

// MARK: - 利用記録

final class ScreenTimeUsageHistoryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: 12))!
    }

    private func record(day: Int, usage: Int, allowance: Int = 60, study: Int = 0) -> ScreenTimeDayRecord {
        let dayStart = calendar.startOfDay(for: date(day))
        return ScreenTimeDayRecord(
            dayOrdinal: ScreenTimeDateMath.localDayOrdinal(for: dayStart, calendar: calendar),
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: dayStart),
            allowanceMinutes: allowance,
            usageMinutes: usage,
            baseMinutes: allowance,
            earnedMinutes: 0,
            bonusMinutes: 0,
            ticketsUsed: 1,
            ticketsIssued: 3,
            shieldInteractions: 2,
            studyMinutes: study,
            goalTargetMinutes: 60,
            protectionInterrupted: false
        )
    }

    func testUpsertReplacesSameDayAndCapsHistoryLength() {
        var history = ScreenTimeUsageHistory()

        history.upsert(record(day: 10, usage: 20))
        history.upsert(record(day: 10, usage: 35))

        XCTAssertEqual(history.days.count, 1)
        XCTAssertEqual(history.days.first?.usageMinutes, 35)

        for day in 1...40 {
            history.upsert(record(day: min(day, 30), usage: day))
        }
        XCTAssertLessThanOrEqual(history.days.count, ScreenTimeUsageHistory.maximumDayCount)
    }

    func testEmptyRecordsAreNotStored() {
        var history = ScreenTimeUsageHistory()
        history.upsert(
            ScreenTimeDayRecord(
                dayOrdinal: 20_260_601,
                dayStart: 0,
                allowanceMinutes: 0,
                usageMinutes: 0,
                baseMinutes: 0,
                earnedMinutes: 0,
                bonusMinutes: 0,
                ticketsUsed: 0,
                ticketsIssued: 0,
                shieldInteractions: 0,
                studyMinutes: 0,
                goalTargetMinutes: 0,
                protectionInterrupted: false
            )
        )

        XCTAssertTrue(history.days.isEmpty)
    }

    func testSummaryAveragesOnlyRecordedDaysAndComparesPreviousPeriod() {
        var history = ScreenTimeUsageHistory()
        // 直近7日（6/9〜6/15）のうち3日だけ記録がある。
        history.upsert(record(day: 15, usage: 30, study: 60))
        history.upsert(record(day: 14, usage: 60, study: 30))
        history.upsert(record(day: 13, usage: 30, study: 0))
        // 前の7日（6/2〜6/8）は平均 90 分。
        history.upsert(record(day: 8, usage: 90))
        history.upsert(record(day: 7, usage: 90))

        let summary = ScreenTimeUsageSummary.make(
            history: history,
            today: nil,
            dayCount: 7,
            referenceDate: date(15),
            calendar: calendar
        )

        XCTAssertEqual(summary.slots.count, 7)
        XCTAssertEqual(summary.recordedDayCount, 3)
        XCTAssertEqual(summary.totalUsageMinutes, 120)
        XCTAssertEqual(summary.averageUsageMinutes, 40)
        XCTAssertEqual(summary.totalStudyMinutes, 90)
        XCTAssertEqual(summary.previousAverageUsageMinutes, 90)
        XCTAssertEqual(summary.usageDeltaMinutes, -50)
        XCTAssertEqual(summary.exceededDayMinutesCheck, 1)
    }

    func testSummaryMergesTodaysLiveLedger() {
        let now = date(15)
        var ledger = ScreenTimeTicketLedger.make(
            settings: ScreenTimeFocusSettings(
                isEnabled: true,
                budgetRestrictionEnabled: true,
                baseAllowanceMinutes: 60
            ),
            referenceDate: now,
            calendar: calendar
        )
        ledger.recordUsageMilestone(minutes: 45)

        let summary = ScreenTimeUsageSummary.make(
            history: ScreenTimeUsageHistory(),
            today: ScreenTimeDayRecord(ledger: ledger, calendar: calendar),
            dayCount: 7,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertEqual(summary.recordedDayCount, 1)
        XCTAssertEqual(summary.slots.last?.usageMinutes, 45)
        XCTAssertEqual(summary.slots.last?.allowanceMinutes, 60)
    }

    func testEmptySummaryHasNoData() {
        let summary = ScreenTimeUsageSummary.make(
            history: ScreenTimeUsageHistory(),
            today: nil,
            dayCount: 7,
            referenceDate: date(15),
            calendar: calendar
        )

        XCTAssertFalse(summary.hasData)
        XCTAssertEqual(summary.averageUsageMinutes, 0)
        XCTAssertNil(summary.usageDeltaMinutes)
        XCTAssertEqual(summary.slots.filter(\.hasRecord).count, 0)
    }

    func testDayRecordFlagsExceededAllowanceAndGoal() {
        let exceeded = record(day: 15, usage: 60, allowance: 60, study: 90)
        XCTAssertTrue(exceeded.exceededAllowance)
        XCTAssertTrue(exceeded.goalReached)

        let within = record(day: 14, usage: 10, allowance: 60, study: 10)
        XCTAssertFalse(within.exceededAllowance)
        XCTAssertFalse(within.goalReached)
    }

    func testHistoryStoreRoundTrip() throws {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let store = ScreenTimeUsageHistoryStore(
            fileURLProvider: { directory.appendingPathComponent("history.json") }
        )

        XCTAssertTrue(try store.loadReadOnly().days.isEmpty)

        try store.update { history in
            history.upsert(record(day: 15, usage: 30))
        }

        XCTAssertEqual(try store.loadReadOnly().days.map(\.usageMinutes), [30])
    }
}

private extension ScreenTimeUsageSummary {
    /// 使い切った日数の別名。テストの意図を読みやすくするためだけのもの。
    var exceededDayMinutesCheck: Int { exceededDayCount }
}

// MARK: - 監視の枠数

final class ScreenTimeMonitoringCapacityTests: XCTestCase {
    func testRemovedBudgetRuleDoesNotReserveMonitoringActivities() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            budgetRestrictionEnabled: true
        )

        XCTAssertFalse(settings.requiresDailyBoundaryMonitoring)
        XCTAssertFalse(settings.requiresBudgetMonitoring)
        XCTAssertEqual(
            settings.maximumEnabledSlotsForCurrentConfiguration,
            ScreenTimeFocusSettings.maximumEnabledScheduleSlots
        )
    }

    func testRemovedBudgetRuleDoesNotConsumeAnExtraActivity() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            goalRestrictionEnabled: true,
            timerRestrictionEnabled: true,
            scheduledRestrictionEnabled: true,
            budgetRestrictionEnabled: true,
            ticketsEnabled: true
        )

        XCTAssertEqual(
            settings.maximumEnabledSlotsForCurrentConfiguration,
            ScreenTimeFocusSettings.maximumEnabledScheduleSlots - 3
        )
    }

    func testValidationRejectsTooManyEnabledSlots() {
        let slots = (0...ScreenTimeFocusSettings.maximumEnabledScheduleSlots).map { index in
            FocusScheduleSlot(id: "slot-\(index)")
        }
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: slots
        )

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(
                error as? ScreenTimeScheduleValidationError,
                .tooManyEnabledSlots(maximum: ScreenTimeFocusSettings.maximumEnabledScheduleSlots)
            )
        }
    }

    func testValidationRejectsShortInterval() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: [
                FocusScheduleSlot(
                    title: "短い時間帯",
                    startHour: 10,
                    startMinute: 0,
                    endHour: 10,
                    endMinute: 14
                )
            ]
        )

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(
                error as? ScreenTimeScheduleValidationError,
                .intervalTooShort(title: "短い時間帯")
            )
        }
    }

    func testValidationRejectsAllowanceOffTheFiveMinuteGrid() {
        let settings = ScreenTimeFocusSettings(isEnabled: true, baseAllowanceMinutes: 7)

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(error as? ScreenTimeScheduleValidationError, .invalidAllowanceMinutes)
        }
    }

    func testValidationRejectsOutOfRangeExchangeRate() {
        let settings = ScreenTimeFocusSettings(isEnabled: true, studyMinutesPerEarnedMinute: 0)

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(error as? ScreenTimeScheduleValidationError, .invalidEarnRate)
        }
    }

    func testValidationRejectsTooManyTickets() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            dailyTicketCount: ScreenTimeFocusSettings.maximumDailyTicketCount + 1
        )

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(error as? ScreenTimeScheduleValidationError, .invalidTicketCount)
        }
    }

    func testPresetsAreValidConfigurations() throws {
        for preset in ScreenTimeFocusPreset.all {
            var settings = ScreenTimeFocusSettings()
            preset.apply(&settings)

            XCTAssertTrue(settings.isEnabled, preset.id)
            XCTAssertGreaterThan(settings.activeRuleCount, 0, preset.id)
            XCTAssertNoThrow(try settings.validateMonitoringConfiguration(), preset.id)
        }
    }

    /// 夜のプリセットは交渉不可の枠を含む（これが無いと就寝時間をチケットで開けてしまう）。
    func testNightAndStrictPresetsIncludeNonNegotiableWindow() {
        for preset in [ScreenTimeFocusPreset.night, ScreenTimeFocusPreset.strict] {
            var settings = ScreenTimeFocusSettings()
            preset.apply(&settings)

            XCTAssertTrue(
                settings.scheduleSlots.contains(where: \.isNonNegotiableBlock),
                preset.id
            )
        }
    }

    func testStrictPresetDoesNotEnableRemovedAllowanceFeature() {
        var settings = ScreenTimeFocusSettings()
        ScreenTimeFocusPreset.strict.apply(&settings)

        XCTAssertEqual(settings.baseAllowanceMinutes, 0)
        XCTAssertFalse(settings.earnedAllowanceEnabled)
        XCTAssertFalse(settings.budgetRestrictionEnabled)
    }
}

// MARK: - 厳格ロック

/// ロックは設定の書き換えだけを止め、ルールの判定やチケットの利用は止めない。
/// 改ざん耐性の要なので、ルール刷新とは独立に守り続ける。
final class ScreenTimeSettingsLockTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int = 15, month: Int = 6, year: Int = 2026, hour: Int = 12) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    func testSettingsLockIsActiveBeforeExpiry() {
        let expiry = date(1, month: 9, hour: 0)
        let settings = ScreenTimeFocusSettings(
            settingsLockedUntilEpochMilliseconds: ScreenTimeDateMath.epochMilliseconds(for: expiry)
        )

        XCTAssertTrue(settings.isSettingsLocked(at: date(1, month: 6)))
        XCTAssertFalse(settings.isSettingsLocked(at: expiry))
        XCTAssertFalse(settings.isSettingsLocked(at: date(1, month: 10)))
    }

    func testSettingsLockExpiryCalculationAddsMonthsAndDays() {
        let start = date(1, month: 6)
        XCTAssertEqual(
            ScreenTimeFocusSettings.lockExpiryDate(from: start, months: 2, days: 10),
            date(11, month: 8)
        )
    }

    func testSettingsLockExpiryCalculationRejectsZeroDuration() {
        XCTAssertNil(ScreenTimeFocusSettings.lockExpiryDate(from: date(1, month: 6), months: 0, days: 0))
    }

    func testSettingsLockDecodeAndEncodeRoundTrip() throws {
        let expiry = ScreenTimeDateMath.epochMilliseconds(for: date(1, month: 9, hour: 0))
        let json = """
        {
          "isEnabled": true,
          "timerRestrictionEnabled": true,
          "scheduleSlots": [],
          "settingsLockedUntilEpochMilliseconds": \(expiry)
        }
        """

        let decoded = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.settingsLockedUntilEpochMilliseconds, expiry)

        let roundTripped = try JSONDecoder().decode(
            ScreenTimeFocusSettings.self,
            from: try JSONEncoder().encode(decoded)
        )
        XCTAssertEqual(roundTripped.settingsLockedUntilEpochMilliseconds, expiry)
    }

    /// ロック中でもチケットは使える。設定を触れないことと、
    /// 決めたルールの中で動けることは別。
    func testSettingsLockDoesNotPreventTicketPolicy() {
        let now = date()
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            alwaysRestrictEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 3,
            settingsLockedUntilEpochMilliseconds: ScreenTimeDateMath.epochMilliseconds(
                for: now.addingTimeInterval(86_400)
            )
        )
        let ledger = ScreenTimeTicketLedger.make(
            settings: settings,
            referenceDate: now,
            calendar: calendar
        )

        XCTAssertTrue(settings.isSettingsLocked(at: now))
        let decision = ScreenTimePolicyEvaluator.evaluate(
            settings: settings,
            ledger: ledger,
            dailyGoalProgress: nil,
            runtimeState: ScreenTimeRuntimeState(timerIsRunning: false),
            referenceDate: now,
            calendar: calendar
        )
        XCTAssertEqual(decision.reason, .alwaysRestricted)
        XCTAssertTrue(decision.canStartTicket)
    }
}

// MARK: - 時間帯の判定

final class ScreenTimeScheduleSlotTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// 2026-06-15 は月曜。
    private func date(_ day: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    private func weekday(of date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    func testScheduleSlotContainsRespectsSelectedWeekdays() {
        let monday = date(15, hour: 20)
        let tuesday = date(16, hour: 20)
        let slot = FocusScheduleSlot(
            startHour: 19,
            endHour: 21,
            weekdays: [weekday(of: monday)]
        )

        XCTAssertTrue(slot.contains(monday, calendar: calendar))
        XCTAssertFalse(slot.contains(tuesday, calendar: calendar))
    }

    /// 日をまたぐ枠は「開始側の曜日」に属する。就寝時間の枠（23:00〜6:00）が
    /// 翌朝まで効き続けるかどうかがここで決まる。
    func testScheduleSlotCrossMidnightAttributesEarlyMorningToStartWeekday() {
        let mondayNight = date(15, hour: 23)
        let tuesdayMorning = date(16, hour: 1)

        let mondayOnly = FocusScheduleSlot(
            startHour: 22,
            endHour: 2,
            weekdays: [weekday(of: mondayNight)]
        )
        XCTAssertTrue(mondayOnly.contains(mondayNight, calendar: calendar))
        XCTAssertTrue(mondayOnly.contains(tuesdayMorning, calendar: calendar))

        let tuesdayOnly = FocusScheduleSlot(
            startHour: 22,
            endHour: 2,
            weekdays: [weekday(of: tuesdayMorning)]
        )
        XCTAssertFalse(tuesdayOnly.contains(tuesdayMorning, calendar: calendar))
        XCTAssertTrue(tuesdayOnly.contains(date(16, hour: 23), calendar: calendar))
    }

    /// 就寝時間の枠が日跨ぎでも「解除不可」であり続けることを確かめる。
    func testCrossMidnightNonNegotiableSlotStaysLockedAfterMidnight() {
        let slot = FocusScheduleSlot(
            id: "night",
            behavior: .block,
            startHour: 23,
            endHour: 6,
            allowsTicketBypass: false
        )
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketsEnabled: true,
            dailyTicketCount: 3,
            scheduleSlots: [slot]
        )
        let earlyMorning = date(16, hour: 2)

        let decision = ScreenTimePolicyEvaluator.evaluate(
            settings: settings,
            ledger: nil,
            dailyGoalProgress: nil,
            runtimeState: ScreenTimeRuntimeState(timerIsRunning: false),
            referenceDate: earlyMorning,
            calendar: calendar
        )

        XCTAssertEqual(decision.reason, .lockedSchedule)
        XCTAssertTrue(decision.restrictsAllApps)
        XCTAssertFalse(decision.isTicketBypassable)
        XCTAssertFalse(decision.canStartTicket)
    }

    func testScheduleSlotWithoutWeekdaysNeverApplies() {
        let monday = date(15, hour: 20)
        let slot = FocusScheduleSlot(startHour: 19, endHour: 21, weekdays: [])

        XCTAssertFalse(slot.hasSelectedWeekday)
        XCTAssertFalse(slot.contains(monday, calendar: calendar))

        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: [slot]
        )
        XCTAssertTrue(settings.enabledScheduleSlots.isEmpty)
        XCTAssertFalse(settings.hasActiveScheduleSlot(at: monday, calendar: calendar))
    }

    func testActivitySelectionIsNormalizedToIncludeEntireCategories() {
        let settings = ScreenTimeFocusSettings(
            activitySelection: FamilyActivitySelection(includeEntireCategory: false),
            budgetSelection: FamilyActivitySelection(includeEntireCategory: false)
        )

        XCTAssertTrue(settings.activitySelection.includeEntireCategory)
        XCTAssertTrue(settings.budgetSelection.includeEntireCategory)
    }
}

// MARK: - 台帳の日跨ぎと巻き戻し

final class ScreenTimeLedgerDayBoundaryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ day: Int = 15, hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    private func settings(base: Int, tickets: Int) -> ScreenTimeFocusSettings {
        ScreenTimeFocusSettings(
            isEnabled: true,
            budgetRestrictionEnabled: true,
            ticketsEnabled: true,
            baseAllowanceMinutes: base,
            dailyTicketCount: tickets
        )
    }

    private func makeStore(
        onStaleDay: ScreenTimeTicketLedgerStore.StaleDayHandler? = nil
    ) throws -> ScreenTimeTicketLedgerStore {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("ledger.json")
        return ScreenTimeTicketLedgerStore(fileURLProvider: { fileURL }, onStaleDay: onStaleDay)
    }

    /// 端末の時計が巻き戻っても、その日の付与をやり直せない。
    /// `issuedLocalDayOrdinal` が存在する理由そのもの。
    func testLedgerDoesNotRefillWhenClockMovesBack() throws {
        let store = try makeStore()
        let firstDay = date()
        let secondDay = date(16)
        let initial = settings(base: 30, tickets: 3)
        let increased = settings(base: 120, tickets: 12)

        _ = try store.load(
            settings: initial,
            referenceDate: firstDay,
            calendar: calendar,
            createIfMissing: true
        )
        try store.update(settings: initial, referenceDate: firstDay, calendar: calendar) { ledger in
            try ledger.reserveTicket(
                start: firstDay,
                expiry: firstDay.addingTimeInterval(10 * 60),
                settings: initial,
                calendar: calendar
            )
        }

        // 消費が始まったあとの増枠は当日には効かない。
        let sameDay = try XCTUnwrap(store.load(
            settings: increased,
            referenceDate: firstDay.addingTimeInterval(12 * 60),
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(sameDay.issuedTicketCount, 3)
        XCTAssertEqual(sameDay.usedTicketCount, 1)

        let nextDay = try XCTUnwrap(store.load(
            settings: increased,
            referenceDate: secondDay,
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(nextDay.issuedTicketCount, 12)
        XCTAssertEqual(nextDay.usedTicketCount, 0)

        // 時計を前日へ戻しても、台帳は前日分に作り直されない。
        var movedBack = try XCTUnwrap(store.load(
            settings: increased,
            referenceDate: firstDay,
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(movedBack.dayStart, nextDay.dayStart)
        XCTAssertEqual(movedBack.issuedTicketCount, 12)
        XCTAssertEqual(movedBack.usedTicketCount, 0)
        XCTAssertThrowsError(
            try movedBack.reserveTicket(
                start: firstDay,
                expiry: firstDay.addingTimeInterval(10 * 60),
                settings: initial,
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(
                error as? ScreenTimeTicketLedgerMutationError,
                .notCurrentDay
            )
        }
    }

    /// 枠を減らす変更は、時計が巻き戻っていても即座に効く（安全側なので許す）。
    /// 増やす変更だけが翌日まで待たされる。
    func testShrinkingTheGrantAppliesEvenWhenTheClockMovedBack() throws {
        let store = try makeStore()
        let firstDay = date()
        let generous = settings(base: 120, tickets: 12)
        let strict = settings(base: 30, tickets: 3)

        _ = try store.load(
            settings: generous,
            referenceDate: firstDay,
            calendar: calendar,
            createIfMissing: true
        )
        let nextDay = try XCTUnwrap(store.load(
            settings: generous,
            referenceDate: date(16),
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(nextDay.issuedTicketCount, 12)

        let shrunk = try XCTUnwrap(store.load(
            settings: strict,
            referenceDate: firstDay,
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(shrunk.dayStart, nextDay.dayStart)
        XCTAssertEqual(shrunk.issuedTicketCount, 3)
        XCTAssertEqual(shrunk.baseAllowanceMinutes, 30)
    }

    /// 日付が変わった台帳は、書き戻しで消える前に必ずフックへ渡る。
    /// アプリ起動時の `snapshot` も含め、読み取り目的の経路でも書き戻しは起きる。
    func testStaleDayIsHandedOverBeforeItIsOverwritten() throws {
        var captured: [ScreenTimeTicketLedger] = []
        let store = try makeStore { captured.append($0) }
        let config = settings(base: 60, tickets: 2)
        let firstDay = date()

        try store.update(settings: config, referenceDate: firstDay, calendar: calendar) { ledger in
            ledger.recordUsageMilestone(minutes: 25)
            ledger.shieldInteractionCount = 4
        }
        XCTAssertTrue(captured.isEmpty)

        // 「読むだけ」のつもりの load でも正規化と書き戻しが走る。
        _ = try store.load(
            settings: config,
            referenceDate: date(16),
            calendar: calendar,
            createIfMissing: false
        )

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.usageMilestoneMinutes, 25)
        XCTAssertEqual(captured.first?.shieldInteractionCount, 4)
        XCTAssertEqual(
            captured.first?.localDayOrdinal(calendar: calendar),
            ScreenTimeDateMath.localDayOrdinal(for: firstDay, calendar: calendar)
        )
    }

    /// 同じ日のうちは何度読み書きしてもフックは起動しない。
    func testStaleDayHandlerIsNotCalledWithinTheSameDay() throws {
        var callCount = 0
        let store = try makeStore { _ in callCount += 1 }
        let config = settings(base: 60, tickets: 2)

        try store.update(settings: config, referenceDate: date(), calendar: calendar) { ledger in
            ledger.recordUsageMilestone(minutes: 5)
        }
        _ = try store.load(
            settings: config,
            referenceDate: date(hour: 23),
            calendar: calendar,
            createIfMissing: true
        )

        XCTAssertEqual(callCount, 0)
    }

    /// 無効化して再度有効化しても、消費済みの枚数は戻らない。
    func testDisableAndReenableDoesNotRestoreUsedTickets() throws {
        let now = date()
        let config = settings(base: 20, tickets: 2)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: now,
            calendar: calendar
        )
        try ledger.reserveTicket(
            start: now,
            expiry: now.addingTimeInterval(10 * 60),
            settings: config,
            calendar: calendar
        )
        ledger.endActiveTicket()

        ledger.normalize(
            settings: config,
            referenceDate: now.addingTimeInterval(30 * 60),
            calendar: calendar
        )

        XCTAssertEqual(ledger.usedTicketCount, 1)
        XCTAssertEqual(ledger.remainingTicketCount, 1)
    }

    /// 0時ちょうどに終わるチケットは、翌日側では既に無効。
    func testTicketEndingAtMidnightIsInactiveOnNextDay() throws {
        let start = date(hour: 23, minute: 55)
        let midnight = date(16, hour: 0)
        let config = settings(base: 20, tickets: 1)
        var ledger = ScreenTimeTicketLedger.make(
            settings: config,
            referenceDate: start,
            calendar: calendar
        )

        try ledger.reserveTicket(start: start, expiry: midnight, settings: config, calendar: calendar)

        XCTAssertTrue(ledger.hasActiveTicket(at: date(hour: 23, minute: 59), calendar: calendar))
        XCTAssertFalse(ledger.hasActiveTicket(at: midnight, calendar: calendar))
    }
}

// MARK: - しきい値の階段

/// 階段を張り直すと OS 側のカウンタが 0 に戻り、次の段への端数が失われる。
/// 設定を細かく動かすだけで計測を巻き戻せないことを守る。
final class ScreenTimeUsageLadderTests: XCTestCase {
    private func settings(base: Int, cap: Int = 0, bonus: Int = 0) -> ScreenTimeFocusSettings {
        ScreenTimeFocusSettings(
            isEnabled: true,
            budgetRestrictionEnabled: true,
            baseAllowanceMinutes: base,
            earnedAllowanceEnabled: cap > 0,
            earnedAllowanceCapMinutes: cap,
            goalBonusAllowanceMinutes: bonus
        )
    }

    func testLadderCeilingIsStableAcrossSmallAllowanceChanges() {
        // 5分刻みでステッパーを動かしても、天井は60分単位でしか動かない。
        XCTAssertEqual(settings(base: 5).usageLadderCeilingMinutes, 60)
        XCTAssertEqual(settings(base: 30).usageLadderCeilingMinutes, 60)
        XCTAssertEqual(settings(base: 60).usageLadderCeilingMinutes, 60)
        XCTAssertEqual(settings(base: 65).usageLadderCeilingMinutes, 120)
        XCTAssertEqual(settings(base: 0).usageLadderCeilingMinutes, 0)
    }

    /// 60分バケット内での増減では階段が一切変わらない＝貼り直しが起きない。
    func testMilestonesAreIdenticalWithinTheSameBucket() {
        let a = settings(base: 5).usageMilestones
        let b = settings(base: 55).usageMilestones
        XCTAssertEqual(a, b)
        XCTAssertFalse(a.isEmpty)
    }

    func testLadderCeilingNeverExceedsTheAllowanceMaximum() {
        let ceiling = settings(
            base: ScreenTimeFocusSettings.maximumAllowanceMinutes,
            cap: ScreenTimeFocusSettings.maximumAllowanceMinutes,
            bonus: ScreenTimeFocusSettings.maximumAllowanceMinutes
        ).usageLadderCeilingMinutes
        XCTAssertEqual(ceiling, ScreenTimeFocusSettings.maximumAllowanceMinutes)
    }

    func testLadderCoversTheWholeAllowanceAndStaysWithinTheEventLimit() {
        for base in stride(from: 5, through: ScreenTimeFocusSettings.maximumAllowanceMinutes, by: 5) {
            let config = settings(base: base)
            let milestones = config.usageMilestones
            XCTAssertLessThanOrEqual(milestones.count, ScreenTimeFocusSettings.maximumUsageMilestones)
            XCTAssertEqual(milestones.last, config.usageLadderCeilingMinutes)
            // 使い切りを検知できるよう、天井は持ち時間以上でなければならない。
            XCTAssertGreaterThanOrEqual(
                config.usageLadderCeilingMinutes,
                ScreenTimeAllowance.maximumPossibleMinutes(settings: config)
            )
        }
    }

    /// 対象アプリが同じなら、持ち時間をいくら動かしても指紋は変わらない。
    /// 指紋が変わらない限り監視は貼り直されない。
    func testFingerprintIgnoresAllowanceChanges() {
        XCTAssertEqual(
            settings(base: 30).budgetMonitoringFingerprint,
            settings(base: 700, cap: 60, bonus: 20).budgetMonitoringFingerprint
        )
    }
}

// MARK: - タイマー期限

final class ScreenTimeTimerExpiryTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    /// カウントダウンタイマーは、アプリが前面に来て状態を書き換えなくても
    /// 期限で制限が解ける（判定は毎回時刻から導く）。
    func testCountdownTimerRestrictionExpiresWithoutForegroundStateMutation() {
        let now = calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: 12))!
        let expiry = now.addingTimeInterval(10 * 60)
        let settings = ScreenTimeFocusSettings(isEnabled: true, timerRestrictionEnabled: true)

        func reason(at date: Date) -> ScreenTimePolicyReason {
            ScreenTimePolicyEvaluator.evaluate(
                settings: settings,
                ledger: nil,
                dailyGoalProgress: nil,
                runtimeState: ScreenTimeRuntimeState(
                    timerIsRunning: true,
                    timerRestrictionEndsAt: ScreenTimeDateMath.epochMilliseconds(for: expiry)
                ),
                referenceDate: date,
                calendar: calendar
            ).reason
        }

        XCTAssertEqual(reason(at: expiry.addingTimeInterval(-1)), .studyTimer)
        XCTAssertEqual(reason(at: expiry), .unrestricted)
    }
}

// MARK: - 場所ルール

final class ScreenTimeLocationPolicyTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(hour: Int = 12, minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 6, day: 15, hour: hour, minute: minute))!
    }

    private func schoolZone(allowsTicketBypass: Bool) -> FocusLocationZone {
        FocusLocationZone(
            id: "school",
            title: "学校",
            latitude: 35.6812,
            longitude: 139.7671,
            coordinateWasSet: true,
            radiusMeters: 150,
            allowsTicketBypass: allowsTicketBypass
        )
    }

    private func settings(
        allowsTicketBypass: Bool = true,
        scheduled: Bool = false,
        allowWindow: Bool = false,
        tickets: Bool = false
    ) -> ScreenTimeFocusSettings {
        var slots: [FocusScheduleSlot] = []
        if scheduled || allowWindow {
            slots.append(
                FocusScheduleSlot(
                    id: "lunch",
                    title: "昼休み",
                    behavior: .allow,
                    startHour: 12,
                    startMinute: 0,
                    endHour: 13,
                    endMinute: 0
                )
            )
        }
        return ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: scheduled || allowWindow,
            locationRestrictionEnabled: true,
            ticketsEnabled: tickets,
            dailyTicketCount: tickets ? 3 : 0,
            scheduleSlots: slots,
            locationZones: [schoolZone(allowsTicketBypass: allowsTicketBypass)]
        )
    }

    private func evaluate(
        settings: ScreenTimeFocusSettings,
        inside: Bool,
        ledger: ScreenTimeTicketLedger? = nil,
        at referenceDate: Date? = nil
    ) -> ScreenTimePolicyDecision {
        ScreenTimePolicyEvaluator.evaluate(
            settings: settings,
            ledger: ledger,
            dailyGoalProgress: nil,
            runtimeState: ScreenTimeRuntimeState(),
            locationPresence: ScreenTimeLocationPresence(
                insideZoneIDs: inside ? ["school"] : []
            ),
            referenceDate: referenceDate ?? date(),
            calendar: calendar
        )
    }

    func testInsideZoneRestrictsAndOutsideDoesNot() {
        let settings = settings()
        let inside = evaluate(settings: settings, inside: true)
        let outside = evaluate(settings: settings, inside: false)

        XCTAssertTrue(inside.restrictsAllApps)
        XCTAssertEqual(inside.reason, .blockedLocation)
        XCTAssertTrue(inside.isTicketBypassable)
        XCTAssertFalse(outside.isRestricted)
        XCTAssertEqual(outside.reason, .unrestricted)
    }

    func testLockedLocationIgnoresTicketsAndAllowWindows() {
        let now = date(hour: 12, minute: 30)
        let settings = settings(allowsTicketBypass: false, allowWindow: true, tickets: true)
        let ledger = ScreenTimeTicketLedger(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: now)),
            issuedLocalDayOrdinal: ScreenTimeDateMath.localDayOrdinal(for: now, calendar: calendar),
            issuedTicketCount: 3,
            usedTicketCount: 1,
            activeTicketStartedAt: ScreenTimeDateMath.epochMilliseconds(for: now),
            activeTicketEndsAt: ScreenTimeDateMath.epochMilliseconds(for: now.addingTimeInterval(600)),
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )

        let result = evaluate(settings: settings, inside: true, ledger: ledger, at: now)

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .lockedLocation)
        XCTAssertFalse(result.isTicketBypassable)
        XCTAssertFalse(result.canStartTicket)
    }

    func testNegotiableLocationIsNotLiftedByAllowWindow() {
        let now = date(hour: 12, minute: 30)
        let result = evaluate(
            settings: settings(allowWindow: true, tickets: true),
            inside: true,
            at: now
        )

        XCTAssertTrue(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .blockedLocation)
        XCTAssertTrue(result.canStartTicket)
    }

    func testNegotiableLocationIsLiftedByTicket() {
        let now = date()
        let settings = settings(tickets: true)
        let ledger = ScreenTimeTicketLedger(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: now)),
            issuedLocalDayOrdinal: ScreenTimeDateMath.localDayOrdinal(for: now, calendar: calendar),
            issuedTicketCount: 3,
            usedTicketCount: 1,
            activeTicketStartedAt: ScreenTimeDateMath.epochMilliseconds(for: now),
            activeTicketEndsAt: ScreenTimeDateMath.epochMilliseconds(for: now.addingTimeInterval(600)),
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )

        let result = evaluate(settings: settings, inside: true, ledger: ledger, at: now)

        XCTAssertFalse(result.restrictsAllApps)
        XCTAssertEqual(result.reason, .activeTicket)
        XCTAssertTrue(result.hasActiveTicket)
    }

    func testValidationRejectsEnabledZoneWithoutCoordinate() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            locationRestrictionEnabled: true,
            locationZones: [FocusLocationZone(title: "未設定", isEnabled: true)]
        )

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(
                error as? ScreenTimeScheduleValidationError,
                .locationCoordinateRequired(title: "未設定")
            )
        }
    }

    func testValidationRejectsTooManyEnabledLocationZones() {
        let zones = (0...ScreenTimeFocusSettings.maximumEnabledLocationZones).map { index in
            FocusLocationZone(
                id: "zone-\(index)",
                title: "場所 \(index)",
                latitude: 35,
                longitude: 139,
                coordinateWasSet: true
            )
        }
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            locationRestrictionEnabled: true,
            locationZones: zones
        )

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(
                error as? ScreenTimeScheduleValidationError,
                .tooManyEnabledLocationZones(maximum: ScreenTimeFocusSettings.maximumEnabledLocationZones)
            )
        }
    }

    func testDisabledZoneWithoutCoordinateDoesNotFailValidation() throws {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            locationRestrictionEnabled: true,
            locationZones: [FocusLocationZone(title: "下書き", isEnabled: false)]
        )

        XCTAssertNoThrow(try settings.validateMonitoringConfiguration())
    }

    func testRegionIdentifierRoundTrip() {
        let zone = schoolZone(allowsTicketBypass: true)
        XCTAssertEqual(FocusLocationZone.zoneID(fromRegionIdentifier: zone.regionIdentifier), zone.id)
        XCTAssertNil(FocusLocationZone.zoneID(fromRegionIdentifier: "other.prefix.id"))
    }

    func testPresenceResolverTreatsClearlyOutsidePointAsOutside() {
        let zone = schoolZone(allowsTicketBypass: true)
        let sample = offset(from: zone, northMeters: 400)

        XCTAssertEqual(
            FocusLocationPresenceResolver.membership(
                latitude: sample.latitude,
                longitude: sample.longitude,
                horizontalAccuracy: 80,
                zone: zone
            ),
            .outside
        )

        let ids = FocusLocationPresenceResolver.insideZoneIDs(
            latitude: sample.latitude,
            longitude: sample.longitude,
            horizontalAccuracy: 80,
            timestamp: Date(),
            zones: [zone],
            previous: ["school"]
        )

        XCTAssertEqual(ids, [])
    }

    func testPresenceResolverUnlocksJustOutsideDrawnRadius() {
        let zone = schoolZone(allowsTicketBypass: true)
        let sample = offset(from: zone, northMeters: 180)
        let distance = FocusLocationPresenceResolver.distanceMeters(
            fromLatitude: zone.latitude,
            fromLongitude: zone.longitude,
            toLatitude: sample.latitude,
            toLongitude: sample.longitude
        )

        XCTAssertGreaterThan(distance - 5, Double(zone.radiusMeters))
        XCTAssertEqual(
            FocusLocationPresenceResolver.membership(
                latitude: sample.latitude,
                longitude: sample.longitude,
                horizontalAccuracy: 5,
                zone: zone
            ),
            .outside
        )
    }

    func testPresenceResolverKeepsPreviousWhenAccuracyOverlapsBoundary() {
        let zone = schoolZone(allowsTicketBypass: true)
        let sample = offset(from: zone, northMeters: 160)

        XCTAssertEqual(
            FocusLocationPresenceResolver.membership(
                latitude: sample.latitude,
                longitude: sample.longitude,
                horizontalAccuracy: 20,
                zone: zone
            ),
            .uncertain
        )

        let stillInside = FocusLocationPresenceResolver.insideZoneIDs(
            latitude: sample.latitude,
            longitude: sample.longitude,
            horizontalAccuracy: 20,
            timestamp: Date(),
            zones: [zone],
            previous: ["school"]
        )
        let stillOutside = FocusLocationPresenceResolver.insideZoneIDs(
            latitude: sample.latitude,
            longitude: sample.longitude,
            horizontalAccuracy: 20,
            timestamp: Date(),
            zones: [zone],
            previous: []
        )

        XCTAssertEqual(stillInside, ["school"])
        XCTAssertEqual(stillOutside, [])
    }

    func testPresenceResolverTreatsClearlyInsidePointAsInside() {
        let zone = schoolZone(allowsTicketBypass: true)
        let sample = offset(from: zone, northMeters: 40)

        XCTAssertEqual(
            FocusLocationPresenceResolver.membership(
                latitude: sample.latitude,
                longitude: sample.longitude,
                horizontalAccuracy: 10,
                zone: zone
            ),
            .inside
        )
    }

    func testPresenceResolverIgnoresStaleSample() {
        let zone = schoolZone(allowsTicketBypass: true)
        let sample = offset(from: zone, northMeters: 400)
        let ids = FocusLocationPresenceResolver.insideZoneIDs(
            latitude: sample.latitude,
            longitude: sample.longitude,
            horizontalAccuracy: 10,
            timestamp: Date().addingTimeInterval(-120),
            zones: [zone],
            previous: ["school"]
        )

        XCTAssertNil(ids)
    }

    func testHaversineDistanceMatchesOneDegreeLatitude() {
        let meters = FocusLocationPresenceResolver.distanceMeters(
            fromLatitude: 0,
            fromLongitude: 0,
            toLatitude: 1,
            toLongitude: 0
        )
        XCTAssertEqual(meters, 111_319.5, accuracy: 1)
    }

    private func offset(
        from zone: FocusLocationZone,
        northMeters: Double
    ) -> (latitude: Double, longitude: Double) {
        let metersPerDegree = 111_319.5
        return (zone.latitude + northMeters / metersPerDegree, zone.longitude)
    }
}
