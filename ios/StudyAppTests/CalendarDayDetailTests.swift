import XCTest
@testable import StudyApp

final class CalendarDayDetailTests: XCTestCase {
    func test_makeDayDetail_buildsSummaryOnceForSelectedDay() {
        let date = makeDate(year: 2026, month: 5, day: 9, hour: 9)
        let material = Material(
            id: 10,
            name: "重要問題集",
            subjectId: 1,
            totalProblems: 80,
            problemChapters: [
                ProblemChapter(id: "c1", title: "1章", problemCount: 40),
                ProblemChapter(id: "c2", title: "2章", problemCount: 40)
            ]
        )
        let sessions = [
            makeSession(
                id: 1,
                materialId: material.id,
                materialName: material.name,
                subjectId: 1,
                subjectName: "化学",
                start: date,
                durationMinutes: 45,
                records: [
                    ProblemSessionRecord(number: 1, result: .wrong),
                    ProblemSessionRecord(number: 2, result: .correct)
                ]
            ),
            makeSession(
                id: 2,
                materialId: material.id,
                materialName: material.name,
                subjectId: 1,
                subjectName: "化学",
                start: makeDate(year: 2026, month: 5, day: 9, hour: 10),
                durationMinutes: 30,
                records: [
                    ProblemSessionRecord(number: 41, result: .reviewCorrect)
                ]
            )
        ]

        let detail = CalendarViewModel.makeDayDetail(
            day: 9,
            date: date,
            sessions: sessions,
            materialsById: [material.id: material],
            timetablePeriods: [],
            timetableEntries: [],
            timetableTerms: [],
            referenceDate: makeDate(year: 2026, month: 5, day: 9, hour: 12)
        )

        XCTAssertEqual(detail.totalMinutes, 75)
        XCTAssertEqual(detail.sessions.count, 2)
        XCTAssertEqual(detail.summaryRows.count, 1)
        XCTAssertEqual(detail.summaryRows.first?.subject.subjectName, "化学")
        XCTAssertEqual(detail.summaryRows.first?.material.materialName, "重要問題集")
        XCTAssertTrue(detail.summaryRows.first?.problemPreviewText.contains("不正解 1章 1問") == true)
        XCTAssertTrue(detail.summaryRows.first?.problemPreviewText.contains("復習 2章 1問") == true)
        XCTAssertFalse(detail.timelineItems.isEmpty)
    }

    func test_makeDayDetail_containsBothDisplayModesDataForTabSwitching() {
        let date = makeDate(year: 2026, month: 5, day: 9, hour: 9)
        let session = makeSession(
            id: 1,
            materialId: nil,
            materialName: "",
            subjectId: 1,
            subjectName: "数学",
            start: date,
            durationMinutes: 60
        )

        let detail = CalendarViewModel.makeDayDetail(
            day: 9,
            date: date,
            sessions: [session],
            materialsById: [:],
            timetablePeriods: [],
            timetableEntries: [],
            timetableTerms: [],
            referenceDate: makeDate(year: 2026, month: 5, day: 9, hour: 12)
        )

        XCTAssertEqual(detail.summaryRows.map(\.material.sessionCount), [1])
        XCTAssertTrue(detail.timelineItems.contains(.study(session)))
    }

    func test_makeDayDetail_timelineIncludesLessonsStudyAndGapsInOrder() {
        let date = makeDate(year: 2026, month: 5, day: 9, hour: 0)
        let period = TimetablePeriod(
            id: 1,
            name: "1限",
            startMinute: 9 * 60,
            endMinute: 10 * 60,
            sortOrder: 1
        )
        let entry = TimetableEntry(
            id: 1,
            dayOfWeek: .saturday,
            periodId: period.id,
            subjectName: "英語",
            courseName: nil
        )
        let session = makeSession(
            id: 1,
            materialId: nil,
            materialName: "",
            subjectId: 2,
            subjectName: "数学",
            start: makeDate(year: 2026, month: 5, day: 9, hour: 11),
            durationMinutes: 30
        )

        let detail = CalendarViewModel.makeDayDetail(
            day: 9,
            date: date,
            sessions: [session],
            materialsById: [:],
            timetablePeriods: [period],
            timetableEntries: [entry],
            timetableTerms: [],
            referenceDate: makeDate(year: 2026, month: 5, day: 9, hour: 12)
        )

        XCTAssertTrue(detail.timelineItems.contains { item in
            if case .lesson = item { return true }
            return false
        })
        XCTAssertTrue(detail.timelineItems.contains { item in
            if case .study = item { return true }
            return false
        })
        XCTAssertTrue(detail.timelineItems.contains { item in
            if case .gap = item { return true }
            return false
        })
        XCTAssertEqual(detail.timelineItems, detail.timelineItems.sorted { left, right in
            if left.startTime == right.startTime {
                return left.sortPriority < right.sortPriority
            }
            return left.startTime < right.startTime
        })
    }

    private func makeSession(
        id: Int64,
        materialId: Int64?,
        materialName: String,
        subjectId: Int64,
        subjectName: String,
        start: Date,
        durationMinutes: Int,
        records: [ProblemSessionRecord] = []
    ) -> StudySession {
        StudySession(
            id: id,
            materialId: materialId,
            materialName: materialName,
            subjectId: subjectId,
            subjectName: subjectName,
            startTime: start.epochMilliseconds,
            endTime: start.addingTimeInterval(TimeInterval(durationMinutes * 60)).epochMilliseconds,
            problemRecords: records
        )
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }
}
