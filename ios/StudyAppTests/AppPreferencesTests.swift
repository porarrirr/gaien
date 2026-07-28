import FamilyControls
import XCTest
@testable import StudyApp

final class AppPreferencesTests: XCTestCase {
    func testLegacyPreferencesDecodeAfterTimerAppearanceSettingRemoval() throws {
        let json = """
        {
          "onboardingCompleted": true,
          "selectedColorTheme": "green",
          "selectedThemeMode": "system",
          "liveActivityEnabled": true,
          "liveActivityDisplayPreset": "standard",
          "landscapeTimerDisplayPreset": "problemProgress"
        }
        """

        let preferences = try JSONDecoder().decode(AppPreferences.self, from: Data(json.utf8))

        XCTAssertTrue(preferences.onboardingCompleted)
        XCTAssertEqual(preferences.selectedThemeMode, .system)
    }
}

final class ScreenTimeFocusSettingsTests: XCTestCase {
    func testLegacyScreenTimeSettingsDecodeDefaultsGoalUnlockOff() throws {
        let json = """
        {
          "isEnabled": true,
          "timerRestrictionEnabled": true,
          "scheduledRestrictionEnabled": false,
          "scheduleSlots": []
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertTrue(settings.isEnabled)
        XCTAssertTrue(settings.timerRestrictionEnabled)
        XCTAssertFalse(settings.unlockRestrictionsWhenDailyGoalReached)
        XCTAssertNil(settings.settingsLockedUntilEpochMilliseconds)
        XCTAssertFalse(settings.isSettingsLocked)
        XCTAssertTrue(settings.activitySelection.includeEntireCategory)
    }

    func testSettingsLockDecodeAndEncodeRoundTrip() throws {
        let expiry = testDate(2026, 9, 1, hour: 0).epochMilliseconds
        let json = """
        {
          "isEnabled": true,
          "timerRestrictionEnabled": true,
          "scheduledRestrictionEnabled": false,
          "unlockRestrictionsWhenDailyGoalReached": true,
          "scheduleSlots": [],
          "settingsLockedUntilEpochMilliseconds": \(expiry)
        }
        """

        let decoded = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))
        XCTAssertEqual(decoded.settingsLockedUntilEpochMilliseconds, expiry)

        let encoded = try JSONEncoder().encode(decoded)
        let roundTripped = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: encoded)
        XCTAssertEqual(roundTripped.settingsLockedUntilEpochMilliseconds, expiry)
    }

    func testScreenTimeSyncSettingsExcludeDeviceLocalFamilySelection() throws {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            timerRestrictionEnabled: true,
            scheduleSlots: [
                FocusScheduleSlot(id: "evening", title: "夜", startHour: 19, endHour: 21)
            ],
            selectionWasConfigured: true,
            updatedAt: 123_456
        )

        let synced = ScreenTimeSyncSettings(settings: settings)
        let json = String(decoding: try JSONEncoder().encode(synced), as: UTF8.self)

        XCTAssertTrue(synced.selectionWasConfigured)
        XCTAssertEqual(synced.scheduleSlots.map(\.id), ["evening"])
        XCTAssertFalse(json.contains("activitySelection"))
        XCTAssertFalse(json.contains("applicationTokens"))
        XCTAssertFalse(json.contains("webDomainTokens"))
    }

    func testRestoredScreenTimeSettingsRequireDeviceSelectionWhenRemoteHadOne() {
        let synced = ScreenTimeSyncSettings(
            settings: ScreenTimeFocusSettings(
                isEnabled: true,
                timerRestrictionEnabled: true,
                selectionWasConfigured: true,
                updatedAt: 123_456
            )
        )
        let localSelection = FamilyActivitySelection(includeEntireCategory: true)

        let restored = synced.restoredSettings(preserving: localSelection)

        XCTAssertTrue(restored.isEnabled)
        XCTAssertTrue(restored.timerRestrictionEnabled)
        XCTAssertEqual(restored.updatedAt, 123_456)
        XCTAssertTrue(synced.requiresSelectionConfirmation(preserving: localSelection))
    }

    func testSettingsLockExpiryCalculationRejectsZeroDuration() {
        let start = testDate(2026, 6, 1, hour: 12)
        XCTAssertNil(ScreenTimeFocusSettings.lockExpiryDate(from: start, months: 0, days: 0))
    }

    func testSettingsLockExpiryCalculationAddsMonthsAndDays() {
        let start = testDate(2026, 6, 1, hour: 12)
        let expiry = ScreenTimeFocusSettings.lockExpiryDate(from: start, months: 2, days: 10)
        XCTAssertEqual(expiry, testDate(2026, 8, 11, hour: 12))
    }

    func testSettingsLockIsActiveBeforeExpiry() {
        let expiry = testDate(2026, 9, 1, hour: 0)
        let settings = ScreenTimeFocusSettings(settingsLockedUntilEpochMilliseconds: expiry.epochMilliseconds)
        XCTAssertTrue(settings.isSettingsLocked(at: testDate(2026, 6, 1, hour: 12)))
        XCTAssertFalse(settings.isSettingsLocked(at: expiry))
        XCTAssertFalse(settings.isSettingsLocked(at: testDate(2026, 10, 1, hour: 12)))
    }

    func testDailyGoalUnlockRequiresReachedTargetOnSameDay() {
        let reference = testDate(2026, 6, 1, hour: 12)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )
        let progress = ScreenTimeDailyGoalProgress(
            dayStart: reference.startOfDay.epochMilliseconds,
            studyMinutes: 90,
            targetMinutes: 60,
            updatedAt: reference.epochMilliseconds
        )

        XCTAssertTrue(settings.shouldUnlockRestrictionsForDailyGoal(progress: progress, referenceDate: reference))
    }

    func testDailyGoalUnlockIgnoresStaleProgress() {
        let reference = testDate(2026, 6, 1, hour: 12)
        let yesterday = testDate(2026, 5, 31, hour: 12)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )
        let progress = ScreenTimeDailyGoalProgress(
            dayStart: yesterday.startOfDay.epochMilliseconds,
            studyMinutes: 90,
            targetMinutes: 60,
            updatedAt: yesterday.epochMilliseconds
        )

        XCTAssertFalse(settings.shouldUnlockRestrictionsForDailyGoal(progress: progress, referenceDate: reference))
    }

    func testDailyGoalUnlockEligibleStudyMinutesExcludeManualSessions() {
        let reference = testDate(2026, 6, 1, hour: 12)
        let manual = testSession(id: 1, day: reference.startOfDay, hour: 8, minutes: 60, sessionType: .manual)
        let stopwatch = testSession(id: 2, day: reference.startOfDay, hour: 10, minutes: 25, sessionType: .stopwatch)

        let minutes = StudySession.screenTimeDailyGoalUnlockStudyMinutes(
            from: [manual, stopwatch],
            activeTimerMinutes: 10
        )

        XCTAssertEqual(minutes, 35)
    }

    func testDailyGoalUnlockDoesNotReachTargetWithManualSessionOnly() {
        let reference = testDate(2026, 6, 1, hour: 12)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )
        let manual = testSession(id: 1, day: reference.startOfDay, hour: 8, minutes: 90, sessionType: .manual)
        let progress = ScreenTimeDailyGoalProgress(
            dayStart: reference.startOfDay.epochMilliseconds,
            studyMinutes: StudySession.screenTimeDailyGoalUnlockStudyMinutes(from: [manual]),
            targetMinutes: 60,
            updatedAt: reference.epochMilliseconds
        )

        XCTAssertFalse(settings.shouldUnlockRestrictionsForDailyGoal(progress: progress, referenceDate: reference))
    }

    func testDailyGoalUnlockEligibleStudyMinutesExcludeEditedTimerSessions() {
        let reference = testDate(2026, 6, 1, hour: 12)
        let editedTimer = testSession(
            id: 1,
            day: reference.startOfDay,
            hour: 8,
            minutes: 60,
            sessionType: .timer,
            screenTimeUnlockExcluded: true
        )
        let stopwatch = testSession(id: 2, day: reference.startOfDay, hour: 10, minutes: 25, sessionType: .stopwatch)

        let minutes = StudySession.screenTimeDailyGoalUnlockStudyMinutes(from: [editedTimer, stopwatch])

        XCTAssertEqual(minutes, 25)
    }

    func testDailyGoalUnlockClipsStoredAndActiveIntervalsToCurrentDay() {
        let today = testDate(2026, 6, 2)
        let dayStart = today.epochMilliseconds
        let dayEnd = Calendar.current.date(byAdding: .day, value: 1, to: today)!.epochMilliseconds
        let storedStart = dayStart - 10 * 60_000
        let stored = StudySession(
            id: 1,
            materialId: nil,
            subjectId: 1,
            sessionType: .timer,
            startTime: storedStart,
            endTime: dayStart + 20 * 60_000,
            intervals: [
                StudySessionInterval(startTime: storedStart, endTime: dayStart + 20 * 60_000)
            ]
        )
        let activeIntervals = [
            StudySessionInterval(startTime: dayEnd - 5 * 60_000, endTime: dayEnd + 10 * 60_000)
        ]

        let minutes = StudySession.screenTimeDailyGoalUnlockStudyMinutes(
            from: [stored],
            intervalStart: dayStart,
            intervalEnd: dayEnd,
            additionalIntervals: activeIntervals
        )

        XCTAssertEqual(minutes, 25)
    }

    func testLegacyScheduleSlotDecodeDefaultsToAllWeekdays() throws {
        let json = """
        {
          "id": "slot-1",
          "title": "集中時間",
          "isEnabled": true,
          "startHour": 19,
          "startMinute": 0,
          "endHour": 21,
          "endMinute": 0
        }
        """

        let slot = try JSONDecoder().decode(FocusScheduleSlot.self, from: Data(json.utf8))

        XCTAssertEqual(slot.weekdays, FocusScheduleSlot.allWeekdays)
        XCTAssertTrue(slot.hasSelectedWeekday)
    }

    func testScheduleSlotContainsRespectsSelectedWeekdays() {
        let monday = testDate(2026, 6, 15, hour: 20)
        let tuesday = testDate(2026, 6, 16, hour: 20)
        let mondayWeekday = Calendar.current.component(.weekday, from: monday)

        let slot = FocusScheduleSlot(
            startHour: 19,
            startMinute: 0,
            endHour: 21,
            endMinute: 0,
            weekdays: [mondayWeekday]
        )

        XCTAssertTrue(slot.contains(monday))
        XCTAssertFalse(slot.contains(tuesday))
    }

    func testScheduleSlotCrossMidnightAttributesEarlyMorningToStartWeekday() {
        let mondayNight = testDate(2026, 6, 15, hour: 23)
        let tuesdayMorning = testDate(2026, 6, 16, hour: 1)
        let mondayWeekday = Calendar.current.component(.weekday, from: mondayNight)
        let tuesdayWeekday = Calendar.current.component(.weekday, from: tuesdayMorning)

        let mondayOnly = FocusScheduleSlot(
            startHour: 22,
            startMinute: 0,
            endHour: 2,
            endMinute: 0,
            weekdays: [mondayWeekday]
        )
        XCTAssertTrue(mondayOnly.contains(mondayNight))
        XCTAssertTrue(mondayOnly.contains(tuesdayMorning))

        let tuesdayOnly = FocusScheduleSlot(
            startHour: 22,
            startMinute: 0,
            endHour: 2,
            endMinute: 0,
            weekdays: [tuesdayWeekday]
        )
        XCTAssertFalse(tuesdayOnly.contains(tuesdayMorning))
        XCTAssertTrue(tuesdayOnly.contains(testDate(2026, 6, 16, hour: 23)))
    }

    func testScheduleSlotWithoutWeekdaysNeverApplies() {
        let monday = testDate(2026, 6, 15, hour: 20)
        let slot = FocusScheduleSlot(
            startHour: 19,
            startMinute: 0,
            endHour: 21,
            endMinute: 0,
            weekdays: []
        )

        XCTAssertFalse(slot.hasSelectedWeekday)
        XCTAssertFalse(slot.contains(monday))

        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: [slot]
        )
        XCTAssertTrue(settings.enabledScheduleSlots.isEmpty)
        XCTAssertFalse(settings.hasActiveScheduleSlot(at: monday))
    }

    func testScheduleMonitoringRejectsIntervalsShorterThanFifteenMinutes() {
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

        XCTAssertThrowsError(try settings.validateScheduleMonitoringConfiguration()) { error in
            XCTAssertEqual(
                error as? ScreenTimeScheduleValidationError,
                .intervalTooShort(title: "短い時間帯")
            )
        }
    }

    func testScheduleMonitoringAcceptsFifteenMinuteInterval() throws {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: [
                FocusScheduleSlot(
                    startHour: 10,
                    startMinute: 0,
                    endHour: 10,
                    endMinute: 15
                )
            ]
        )

        XCTAssertNoThrow(try settings.validateScheduleMonitoringConfiguration())
    }

    func testScheduleMonitoringRejectsMoreThanTwentyEnabledSlots() {
        let slots = (0...ScreenTimeFocusSettings.maximumEnabledScheduleSlots).map { index in
            FocusScheduleSlot(id: "slot-\(index)")
        }
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            scheduleSlots: slots
        )

        XCTAssertThrowsError(try settings.validateScheduleMonitoringConfiguration()) { error in
            XCTAssertEqual(
                error as? ScreenTimeScheduleValidationError,
                .tooManyEnabledSlots(maximum: ScreenTimeFocusSettings.maximumEnabledScheduleSlots)
            )
        }
    }

    func testActivitySelectionIsNormalizedToIncludeEntireCategories() {
        let settings = ScreenTimeFocusSettings(
            activitySelection: FamilyActivitySelection(includeEntireCategory: false)
        )

        XCTAssertTrue(settings.activitySelection.includeEntireCategory)
    }

    func testDailyGoalRuleReservesDailyBoundaryMonitoringActivity() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )

        XCTAssertTrue(settings.requiresDailyBoundaryMonitoring)
        XCTAssertEqual(
            settings.maximumEnabledSlotsForCurrentConfiguration,
            ScreenTimeFocusSettings.maximumEnabledScheduleSlots - 1
        )
    }

    func testMonitoringCapacityReservesTicketAndTimerExpiryActivities() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            timerRestrictionEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketRestrictionEnabled: true
        )

        XCTAssertEqual(settings.maximumEnabledSlotsForCurrentConfiguration, 17)
    }

    func testGoalAndTicketRulesReserveTicketExpiryMonitoringActivity() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketRestrictionEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )

        XCTAssertEqual(settings.maximumEnabledSlotsForCurrentConfiguration, 18)
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
}

final class ScreenTimeTicketPolicyTests: XCTestCase {
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

    private func ledger(
        at referenceDate: Date,
        issued: Int = 3,
        used: Int = 0,
        activeUntil: Date? = nil
    ) -> ScreenTimeTicketLedger {
        ScreenTimeTicketLedger(
            dayStart: ScreenTimeDateMath.epochMilliseconds(
                for: calendar.startOfDay(for: referenceDate)
            ),
            issuedTicketCount: issued,
            usedTicketCount: used,
            activeTicketStartedAt: activeUntil == nil
                ? nil
                : ScreenTimeDateMath.epochMilliseconds(for: referenceDate),
            activeTicketEndsAt: activeUntil.map(ScreenTimeDateMath.epochMilliseconds),
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

    func testLegacySettingsAndSlotDecodeToCompatibleTicketDefaults() throws {
        let json = """
        {
          "isEnabled": true,
          "timerRestrictionEnabled": true,
          "scheduledRestrictionEnabled": true,
          "scheduleSlots": [{
            "id": "legacy",
            "title": "従来の制限",
            "isEnabled": true,
            "startHour": 9,
            "startMinute": 0,
            "endHour": 10,
            "endMinute": 0
          }]
        }
        """

        let settings = try JSONDecoder().decode(ScreenTimeFocusSettings.self, from: Data(json.utf8))

        XCTAssertFalse(settings.ticketRestrictionEnabled)
        XCTAssertEqual(settings.dailyTicketMinutes, 0)
        XCTAssertFalse(settings.restrictOutsideScheduleWhenTicketsDisabled)
        XCTAssertEqual(settings.scheduleSlots.first?.behavior, .block)
    }

    func testPolicyPriorityMasterDisabledAndDailyGoalBeatOtherRules() {
        let now = date()
        let block = FocusScheduleSlot(
            behavior: .block,
            startHour: 11,
            endHour: 13
        )
        var settings = ScreenTimeFocusSettings(
            isEnabled: false,
            timerRestrictionEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30,
            unlockRestrictionsWhenDailyGoalReached: true,
            scheduleSlots: [block]
        )
        let reachedGoal = ScreenTimeDailyGoalProgress(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: now)),
            studyMinutes: 60,
            targetMinutes: 60,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )

        XCTAssertEqual(
            decision(settings: settings, goal: reachedGoal, timerRunning: true, at: now).reason,
            .masterDisabled
        )

        settings.isEnabled = true
        XCTAssertEqual(
            decision(settings: settings, goal: reachedGoal, timerRunning: true, at: now).reason,
            .dailyGoalReached
        )

        let pendingGoal = ScreenTimeDailyGoalProgress(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: now)),
            studyMinutes: 59,
            targetMinutes: 60,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )
        let pendingDecision = decision(
            settings: settings,
            goal: pendingGoal,
            timerRunning: true,
            at: now
        )
        XCTAssertTrue(pendingDecision.isRestricted)
        XCTAssertEqual(pendingDecision.reason, .dailyGoalPending)
    }

    func testDailyGoalPolicyRestrictsWhenProgressIsMissingOrStale() {
        let now = date()
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            unlockRestrictionsWhenDailyGoalReached: true
        )
        let staleProgress = ScreenTimeDailyGoalProgress(
            dayStart: ScreenTimeDateMath.epochMilliseconds(
                for: calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: now))!
            ),
            studyMinutes: 60,
            targetMinutes: 60,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )

        XCTAssertEqual(decision(settings: settings, at: now).reason, .dailyGoalPending)
        XCTAssertEqual(
            decision(settings: settings, goal: staleProgress, at: now).reason,
            .dailyGoalPending
        )
    }

    func testPolicyPriorityTimerThenBlockThenAllow() {
        let now = date()
        let allow = FocusScheduleSlot(
            behavior: .allow,
            startHour: 11,
            endHour: 13
        )
        let block = FocusScheduleSlot(
            behavior: .block,
            startHour: 11,
            endHour: 13
        )
        var settings = ScreenTimeFocusSettings(
            isEnabled: true,
            timerRestrictionEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30,
            scheduleSlots: [allow, block]
        )

        XCTAssertEqual(
            decision(settings: settings, timerRunning: true, at: now).reason,
            .studyTimer
        )
        XCTAssertEqual(
            decision(settings: settings, timerRunning: false, at: now).reason,
            .blockedSchedule
        )

        settings.scheduleSlots = [allow]
        XCTAssertEqual(
            decision(settings: settings, timerRunning: false, at: now).reason,
            .allowedSchedule
        )
    }

    func testCountdownTimerRestrictionExpiresWithoutForegroundStateMutation() {
        let now = date()
        let expiry = now.addingTimeInterval(10 * 60)
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            timerRestrictionEnabled: true
        )

        XCTAssertEqual(
            decision(
                settings: settings,
                timerRunning: true,
                timerRestrictionEnd: expiry,
                at: expiry.addingTimeInterval(-1)
            ).reason,
            .studyTimer
        )
        XCTAssertEqual(
            decision(
                settings: settings,
                timerRunning: true,
                timerRestrictionEnd: expiry,
                at: expiry
            ).reason,
            .unrestricted
        )
    }

    func testPolicyUsesActiveTicketThenRequiresTicket() {
        let now = date()
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30
        )
        let active = ledger(
            at: now,
            issued: 3,
            used: 1,
            activeUntil: now.addingTimeInterval(10 * 60)
        )

        XCTAssertEqual(
            decision(settings: settings, ledger: active, at: now).reason,
            .activeTicket
        )
        XCTAssertEqual(
            decision(
                settings: settings,
                ledger: active,
                at: now.addingTimeInterval(10 * 60)
            ).reason,
            .ticketRequired
        )
    }

    func testTicketCanStartAndBypassesEveryRestrictedPolicyReason() {
        let now = date()
        let active = ledger(
            at: now,
            issued: 3,
            used: 1,
            activeUntil: now.addingTimeInterval(10 * 60)
        )
        let block = FocusScheduleSlot(
            behavior: .block,
            startHour: 11,
            endHour: 13
        )
        let pendingGoal = ScreenTimeDailyGoalProgress(
            dayStart: ScreenTimeDateMath.epochMilliseconds(for: calendar.startOfDay(for: now)),
            studyMinutes: 59,
            targetMinutes: 60,
            updatedAt: ScreenTimeDateMath.epochMilliseconds(for: now)
        )

        let goalSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30,
            unlockRestrictionsWhenDailyGoalReached: true
        )
        XCTAssertTrue(
            decision(settings: goalSettings, goal: pendingGoal, at: now).canStartTicket
        )
        XCTAssertEqual(
            decision(settings: goalSettings, ledger: active, goal: pendingGoal, at: now).reason,
            .activeTicket
        )

        let timerSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            timerRestrictionEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30
        )
        XCTAssertTrue(
            decision(settings: timerSettings, timerRunning: true, at: now).canStartTicket
        )
        XCTAssertEqual(
            decision(
                settings: timerSettings,
                ledger: active,
                timerRunning: true,
                at: now
            ).reason,
            .activeTicket
        )

        let scheduleSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30,
            scheduleSlots: [block]
        )
        XCTAssertTrue(decision(settings: scheduleSettings, at: now).canStartTicket)
        XCTAssertEqual(
            decision(settings: scheduleSettings, ledger: active, at: now).reason,
            .activeTicket
        )
    }

    func testPolicyBlocksOutsideScheduleOnlyWhenConfigured() {
        let now = date()
        var settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            restrictOutsideScheduleWhenTicketsDisabled: true
        )

        XCTAssertEqual(decision(settings: settings, at: now).reason, .outsideScheduleBlocked)

        settings.restrictOutsideScheduleWhenTicketsDisabled = false
        XCTAssertEqual(decision(settings: settings, at: now).reason, .unrestricted)
    }

    func testActiveTicketBypassesBlockedScheduleAndContinuesOnWallClock() {
        let ticketStart = date(hour: 11, minute: 55)
        let duringBlock = date(hour: 12, minute: 1)
        let afterBlock = date(hour: 12, minute: 3)
        let block = FocusScheduleSlot(
            behavior: .block,
            startHour: 12,
            startMinute: 0,
            endHour: 12,
            endMinute: 2
        )
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30,
            scheduleSlots: [block]
        )
        let active = ledger(
            at: ticketStart,
            issued: 3,
            used: 1,
            activeUntil: ticketStart.addingTimeInterval(10 * 60)
        )

        XCTAssertEqual(
            decision(settings: settings, ledger: active, at: duringBlock).reason,
            .activeTicket
        )
        XCTAssertEqual(
            decision(settings: settings, ledger: active, at: afterBlock).reason,
            .activeTicket
        )
    }

    func testSettingsLockDoesNotPreventTicketPolicy() {
        let now = date()
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 10,
            settingsLockedUntilEpochMilliseconds: ScreenTimeDateMath.epochMilliseconds(
                for: now.addingTimeInterval(86_400)
            )
        )

        XCTAssertTrue(settings.isSettingsLocked(at: now))
        XCTAssertTrue(decision(settings: settings, at: now).canStartTicket)
    }

    func testTicketReservationConsumesOneAndRejectsDoubleConsumption() throws {
        let now = date()
        var ledger = self.ledger(at: now, issued: 2)
        let expiry = now.addingTimeInterval(10 * 60)

        try ledger.reserveTicket(start: now, expiry: expiry, calendar: calendar)

        XCTAssertEqual(ledger.usedTicketCount, 1)
        XCTAssertEqual(ledger.remainingTicketCount, 1)
        XCTAssertTrue(ledger.hasActiveTicket(at: now.addingTimeInterval(9 * 60), calendar: calendar))
        XCTAssertFalse(ledger.hasActiveTicket(at: expiry, calendar: calendar))
        XCTAssertThrowsError(
            try ledger.reserveTicket(
                start: now.addingTimeInterval(60),
                expiry: expiry.addingTimeInterval(60),
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(error as? ScreenTimeTicketLedgerMutationError, .activeTicket)
        }
    }

    func testTicketEndingAtMidnightIsInactiveOnNextDay() throws {
        let start = date(hour: 23, minute: 55)
        let midnight = date(16, hour: 0)
        var ledger = self.ledger(at: start, issued: 1)

        try ledger.reserveTicket(start: start, expiry: midnight, calendar: calendar)

        XCTAssertTrue(ledger.hasActiveTicket(at: date(hour: 23, minute: 59), calendar: calendar))
        XCTAssertFalse(ledger.hasActiveTicket(at: midnight, calendar: calendar))
    }

    func testLedgerSnapshotsAllowanceUntilNextDayAndDoesNotRefillWhenClockMovesBack() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let fileURL = temporaryDirectory.appendingPathComponent("ledger.json")
        let store = ScreenTimeTicketLedgerStore(fileURLProvider: { fileURL })
        let firstDay = date()
        let secondDay = date(16)
        let initialSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30
        )
        let changedSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 120
        )

        _ = try store.load(
            settings: initialSettings,
            referenceDate: firstDay,
            calendar: calendar,
            createIfMissing: true
        )
        try store.update(
            settings: initialSettings,
            referenceDate: firstDay,
            calendar: calendar
        ) { ledger in
            try ledger.reserveTicket(
                start: firstDay,
                expiry: firstDay.addingTimeInterval(10 * 60),
                calendar: calendar
            )
        }

        let sameDay = try XCTUnwrap(store.load(
            settings: changedSettings,
            referenceDate: firstDay.addingTimeInterval(12 * 60),
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(sameDay.issuedTicketCount, 3)
        XCTAssertEqual(sameDay.usedTicketCount, 1)

        let nextDay = try XCTUnwrap(store.load(
            settings: changedSettings,
            referenceDate: secondDay,
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(nextDay.issuedTicketCount, 12)
        XCTAssertEqual(nextDay.usedTicketCount, 0)

        var clockMovedBack = try XCTUnwrap(store.load(
            settings: initialSettings,
            referenceDate: firstDay,
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(clockMovedBack.dayStart, nextDay.dayStart)
        XCTAssertEqual(clockMovedBack.issuedTicketCount, 12)
        XCTAssertEqual(clockMovedBack.usedTicketCount, 0)
        XCTAssertThrowsError(
            try clockMovedBack.reserveTicket(
                start: firstDay,
                expiry: firstDay.addingTimeInterval(10 * 60),
                calendar: calendar
            )
        ) { error in
            XCTAssertEqual(
                error as? ScreenTimeTicketLedgerMutationError,
                ScreenTimeTicketLedgerMutationError.notCurrentDay
            )
        }
    }

    func testInitialAllowanceChangeAppliesImmediatelyBeforeFirstTicketUse() throws {
        let temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )
        addTeardownBlock {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        let fileURL = temporaryDirectory.appendingPathComponent("ledger.json")
        let store = ScreenTimeTicketLedgerStore(fileURLProvider: { fileURL })
        let now = date()
        let initialSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 0
        )
        let configuredSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30
        )

        let initial = try XCTUnwrap(store.load(
            settings: initialSettings,
            referenceDate: now,
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(initial.issuedTicketCount, 0)

        let configured = try XCTUnwrap(store.load(
            settings: configuredSettings,
            referenceDate: now.addingTimeInterval(60),
            calendar: calendar,
            createIfMissing: true
        ))
        XCTAssertEqual(configured.issuedTicketCount, 3)
        XCTAssertEqual(configured.remainingTicketCount, 3)
    }

    func testDisableAndReenableDoesNotRestoreUsedTickets() throws {
        let now = date()
        var ledger = self.ledger(at: now, issued: 2)
        try ledger.reserveTicket(
            start: now,
            expiry: now.addingTimeInterval(10 * 60),
            calendar: calendar
        )
        ledger.activeTicketStartedAt = nil
        ledger.activeTicketEndsAt = nil
        let reenabledSettings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 20
        )

        ledger.normalize(
            settings: reenabledSettings,
            referenceDate: now.addingTimeInterval(30 * 60),
            calendar: calendar
        )

        XCTAssertEqual(ledger.usedTicketCount, 1)
        XCTAssertEqual(ledger.remainingTicketCount, 1)
    }

    func testTicketModeLimitsSchedulesToEighteen() {
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            scheduledRestrictionEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30,
            scheduleSlots: (0..<19).map { FocusScheduleSlot(id: "slot-\($0)") }
        )

        XCTAssertThrowsError(try settings.validateMonitoringConfiguration()) { error in
            XCTAssertEqual(
                error as? ScreenTimeScheduleValidationError,
                .tooManyEnabledSlots(
                    maximum: ScreenTimeFocusSettings.maximumEnabledScheduleSlotsWithTickets
                )
            )
        }
    }

    func testMonitoringRejectsMissingAllowedSelectionDuringActiveTicket() throws {
        let now = date()
        let settings = ScreenTimeFocusSettings(
            isEnabled: true,
            ticketRestrictionEnabled: true,
            dailyTicketMinutes: 30
        )
        let active = ledger(
            at: now,
            issued: 3,
            used: 1,
            activeUntil: now.addingTimeInterval(10 * 60)
        )

        XCTAssertEqual(
            decision(settings: settings, ledger: active, at: now).reason,
            .activeTicket
        )
        XCTAssertTrue(settings.requiresAllowedSelection)
        XCTAssertFalse(settings.canApplyRestrictions)
        XCTAssertThrowsError(
            try ScreenTimeAccessEngine().syncMonitoring(
                settings: settings,
                referenceDate: now,
                calendar: calendar
            )
        ) { error in
            guard let focusError = error as? ScreenTimeFocusError,
                  case .missingAllowedApplications = focusError else {
                return XCTFail("Expected missingAllowedApplications, got \(error)")
            }
        }
    }
}
