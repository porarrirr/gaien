import XCTest
@testable import StudyApp

/// Covers the pure widget-snapshot compute layer. The computer is where
/// streaks, today/week totals, and the 7-day activity strip are derived, and
/// is the main piece of logic that would break silently as data grows.
final class StudyWidgetSnapshotComputerTests: XCTestCase {

    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC") ?? .current
        return cal
    }()

    // MARK: - streakDays / bestStreak (pure helpers)

    func test_streakDays_emptyWhenNoStudyDays() {
        XCTAssertEqual(
            StudyWidgetSnapshotComputer.streakDays(from: [], referenceDay: 100),
            0
        )
    }

    func test_streakDays_countsBackwardsFromReferenceDay() {
        let days: Set<Int64> = [98, 99, 100]
        XCTAssertEqual(
            StudyWidgetSnapshotComputer.streakDays(from: days, referenceDay: 100),
            3
        )
    }

    func test_streakDays_breaksOnGap() {
        let days: Set<Int64> = [95, 96, 98, 99, 100]
        XCTAssertEqual(
            StudyWidgetSnapshotComputer.streakDays(from: days, referenceDay: 100),
            3,
            "Streak ends at the first missing day before reference."
        )
    }

    func test_streakDays_isZeroWhenReferenceDayIsNotStudied() {
        let days: Set<Int64> = [98, 99]
        XCTAssertEqual(
            StudyWidgetSnapshotComputer.streakDays(from: days, referenceDay: 100),
            0
        )
    }

    func test_bestStreak_findsLongestConsecutiveRun() {
        // Two runs: 1..3 and 10..14. The longer one wins.
        let sorted: [Int64] = [1, 2, 3, 10, 11, 12, 13, 14]
        XCTAssertEqual(StudyWidgetSnapshotComputer.bestStreak(from: sorted), 5)
    }

    func test_bestStreak_returnsZeroWhenEmpty() {
        XCTAssertEqual(StudyWidgetSnapshotComputer.bestStreak(from: []), 0)
    }

    // MARK: - compute()

    func test_compute_todayTotalsOnlyIncludeTodaySessions() {
        let reference = try! XCTUnwrap(makeUTCDate(year: 2024, month: 6, day: 15, hour: 15))
        let todayStart = calendar.startOfDay(for: reference).epochMilliseconds
        let yesterdayStart = todayStart - 86_400_000

        let todaySession = makeSession(startTime: todayStart + 60_000, durationMillis: 30 * 60_000)
        let yesterdaySession = makeSession(startTime: yesterdayStart + 60_000, durationMillis: 45 * 60_000)

        let inputs = StudyWidgetSnapshotComputer.Inputs(
            recentSessions: [todaySession, yesterdaySession],
            goals: [],
            upcomingExams: [],
            studyDayEpochDays: [],
            referenceDate: reference,
            calendar: calendar
        )

        let snapshot = StudyWidgetSnapshotComputer.compute(inputs)

        XCTAssertEqual(snapshot.todayStudyMinutes, 30)
        XCTAssertEqual(snapshot.todaySessionCount, 1)
    }

    func test_compute_dailyGoalIsPickedByWeekday() {
        let reference = try! XCTUnwrap(makeUTCDate(year: 2024, month: 6, day: 15, hour: 12)) // Sat
        let saturdayGoal = makeDailyGoal(weekday: .saturday, targetMinutes: 120, updatedAt: 2_000)
        let sundayGoal = makeDailyGoal(weekday: .sunday, targetMinutes: 90, updatedAt: 3_000)

        let inputs = StudyWidgetSnapshotComputer.Inputs(
            recentSessions: [],
            goals: [saturdayGoal, sundayGoal],
            upcomingExams: [],
            studyDayEpochDays: [],
            referenceDate: reference,
            calendar: calendar
        )

        let snapshot = StudyWidgetSnapshotComputer.compute(inputs)

        XCTAssertEqual(snapshot.dailyGoalMinutes, 120)
    }

    func test_compute_weekActivityContainsSevenEntriesWithTodayFlag() {
        let reference = try! XCTUnwrap(makeUTCDate(year: 2024, month: 6, day: 15, hour: 12))

        let inputs = StudyWidgetSnapshotComputer.Inputs(
            recentSessions: [],
            goals: [],
            upcomingExams: [],
            studyDayEpochDays: [],
            referenceDate: reference,
            calendar: calendar
        )

        let snapshot = StudyWidgetSnapshotComputer.compute(inputs)

        XCTAssertEqual(snapshot.weekActivity.count, 7)
        XCTAssertEqual(snapshot.weekActivity.filter { $0.isToday }.count, 1)
        XCTAssertEqual(snapshot.weekActivity.last?.isToday, true)
    }

    func test_compute_limitsExamsToThreeEntries() {
        let reference = try! XCTUnwrap(makeUTCDate(year: 2024, month: 6, day: 15, hour: 12))
        let exams = (1...5).map { offset in
            Exam(
                id: Int64(offset),
                syncId: "e-\(offset)",
                name: "Exam \(offset)",
                date: reference.epochDay + Int64(offset),
                note: nil,
                createdAt: 0,
                updatedAt: 0
            )
        }

        let inputs = StudyWidgetSnapshotComputer.Inputs(
            recentSessions: [],
            goals: [],
            upcomingExams: exams,
            studyDayEpochDays: [],
            referenceDate: reference,
            calendar: calendar
        )

        let snapshot = StudyWidgetSnapshotComputer.compute(inputs)

        XCTAssertEqual(snapshot.upcomingExams.count, 3)
    }

    // MARK: - Helpers

    private func makeUTCDate(year: Int, month: Int, day: Int, hour: Int) -> Date? {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        return calendar.date(from: components)
    }

    private func makeSession(
        startTime: Int64,
        durationMillis: Int64
    ) -> StudySession {
        let end = startTime + durationMillis
        return StudySession(
            id: startTime,
            syncId: "sess-\(startTime)",
            materialId: nil,
            subjectId: 1,
            startTime: startTime,
            endTime: end,
            intervals: [StudySessionInterval(startTime: startTime, endTime: end)]
        )
    }

    private func makeDailyGoal(
        weekday: StudyWeekday,
        targetMinutes: Int,
        updatedAt: Int64
    ) -> Goal {
        Goal(
            id: Int64(targetMinutes),
            syncId: "g-\(weekday.rawValue)",
            type: .daily,
            targetMinutes: targetMinutes,
            dayOfWeek: weekday,
            weekStartDay: .monday,
            isActive: true,
            createdAt: 0,
            updatedAt: updatedAt
        )
    }
}
