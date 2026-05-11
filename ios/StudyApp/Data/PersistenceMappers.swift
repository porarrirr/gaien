import CoreData
import Foundation

/// Converts between Core Data `NSManagedObject` records and domain entities.
/// Extracted from `PersistenceController` so the repository code stays focused
/// on query/save orchestration rather than key-by-key mapping.
///
/// All reader functions (`subject`, `material`, …) are tolerant of missing
/// attributes and return sensible defaults, matching the behaviour expected
/// by legacy imports.
enum PersistenceMappers {

    // MARK: - Writers (entity -> record)

    static func apply(_ subject: Subject, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(subject.syncId, forKey: "syncId")
        record.setValue(subject.name, forKey: "name")
        record.setValue(Int64(subject.color), forKey: "color")
        record.setValue(subject.icon?.rawValue, forKey: "icon")
        record.setValue(subject.createdAt == 0 ? now : subject.createdAt, forKey: "createdAt")
        record.setValue(subject.updatedAt == 0 ? now : subject.updatedAt, forKey: "updatedAt")
        record.setValue(subject.deletedAt, forKey: "deletedAt")
        record.setValue(subject.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(
        _ material: Material,
        assignedId: Int64,
        subjectId: Int64,
        subjectSyncId: String?,
        now: Int64,
        to record: NSManagedObject
    ) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(material.syncId, forKey: "syncId")
        record.setValue(material.name, forKey: "name")
        record.setValue(subjectId, forKey: "subjectId")
        record.setValue(subjectSyncId, forKey: "subjectSyncId")
        record.setValue(material.sortOrder, forKey: "sortOrder")
        record.setValue(Int64(material.totalPages), forKey: "totalPages")
        record.setValue(Int64(material.currentPage), forKey: "currentPage")
        record.setValue(Int64(material.totalProblems), forKey: "totalProblems")
        record.setValue(encodeProblemChapters(material.problemChapters), forKey: "problemChaptersData")
        record.setValue(encodeProblemRecords(material.problemRecords), forKey: "problemRecordsData")
        record.setValue(material.color.map { Int64($0) }, forKey: "color")
        record.setValue(material.note, forKey: "note")
        record.setValue(material.createdAt == 0 ? now : material.createdAt, forKey: "createdAt")
        record.setValue(material.updatedAt == 0 ? now : material.updatedAt, forKey: "updatedAt")
        record.setValue(material.deletedAt, forKey: "deletedAt")
        record.setValue(material.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(
        _ session: StudySession,
        assignedId: Int64,
        subjectId: Int64,
        materialId: Int64?,
        now: Int64,
        to record: NSManagedObject
    ) {
        let effectiveIntervals = session.effectiveIntervals
        let startTime = effectiveIntervals.first?.startTime ?? session.startTime
        let endTime = effectiveIntervals.last?.endTime ?? session.endTime

        record.setValue(assignedId, forKey: "id")
        record.setValue(session.syncId, forKey: "syncId")
        record.setValue(materialId, forKey: "materialId")
        record.setValue(session.materialSyncId, forKey: "materialSyncId")
        record.setValue(session.materialName, forKey: "materialName")
        record.setValue(subjectId, forKey: "subjectId")
        record.setValue(session.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(session.subjectName, forKey: "subjectName")
        record.setValue(session.sessionType.rawValue, forKey: "sessionType")
        record.setValue(startTime, forKey: "startTime")
        record.setValue(endTime, forKey: "endTime")
        record.setValue(effectiveIntervals.reduce(0) { $0 + $1.duration }, forKey: "duration")
        record.setValue(Date(epochMilliseconds: startTime).epochDay, forKey: "date")
        record.setValue(encodeIntervals(effectiveIntervals), forKey: "intervalsData")
        record.setValue(session.rating, forKey: "rating")
        record.setValue(session.note, forKey: "note")
        record.setValue(session.problemStart.map { Int64($0) }, forKey: "problemStart")
        record.setValue(session.problemEnd.map { Int64($0) }, forKey: "problemEnd")
        record.setValue(session.wrongProblemCount.map { Int64($0) }, forKey: "wrongProblemCount")
        record.setValue(encodeProblemRecords(session.problemRecords), forKey: "problemRecordsData")
        record.setValue(session.createdAt == 0 ? now : session.createdAt, forKey: "createdAt")
        record.setValue(session.updatedAt == 0 ? now : session.updatedAt, forKey: "updatedAt")
        record.setValue(session.deletedAt, forKey: "deletedAt")
        record.setValue(session.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(_ goal: Goal, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(goal.syncId, forKey: "syncId")
        record.setValue(goal.type.rawValue, forKey: "type")
        record.setValue(Int64(goal.targetMinutes), forKey: "targetMinutes")
        record.setValue(goal.dayOfWeek?.rawValue, forKey: "dayOfWeek")
        record.setValue(goal.weekStartDay.rawValue, forKey: "weekStartDay")
        record.setValue(goal.isActive, forKey: "isActive")
        record.setValue(goal.createdAt == 0 ? now : goal.createdAt, forKey: "createdAt")
        record.setValue(goal.updatedAt == 0 ? now : goal.updatedAt, forKey: "updatedAt")
        record.setValue(goal.deletedAt, forKey: "deletedAt")
        record.setValue(goal.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(_ exam: Exam, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(exam.syncId, forKey: "syncId")
        record.setValue(exam.name, forKey: "name")
        record.setValue(exam.date, forKey: "date")
        record.setValue(exam.note, forKey: "note")
        record.setValue(exam.createdAt == 0 ? now : exam.createdAt, forKey: "createdAt")
        record.setValue(exam.updatedAt == 0 ? now : exam.updatedAt, forKey: "updatedAt")
        record.setValue(exam.deletedAt, forKey: "deletedAt")
        record.setValue(exam.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(_ plan: StudyPlan, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(plan.syncId, forKey: "syncId")
        record.setValue(plan.name, forKey: "name")
        record.setValue(plan.startDate, forKey: "startDate")
        record.setValue(plan.endDate, forKey: "endDate")
        record.setValue(plan.isActive, forKey: "isActive")
        record.setValue(plan.createdAt == 0 ? now : plan.createdAt, forKey: "createdAt")
        record.setValue(plan.updatedAt == 0 ? now : plan.updatedAt, forKey: "updatedAt")
        record.setValue(plan.deletedAt, forKey: "deletedAt")
        record.setValue(plan.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(
        _ item: PlanItem,
        assignedId: Int64,
        planId: Int64,
        planSyncId: String?,
        subjectId: Int64,
        now: Int64,
        to record: NSManagedObject
    ) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(item.syncId, forKey: "syncId")
        record.setValue(planId, forKey: "planId")
        record.setValue(planSyncId, forKey: "planSyncId")
        record.setValue(subjectId, forKey: "subjectId")
        record.setValue(item.subjectSyncId, forKey: "subjectSyncId")
        record.setValue(item.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(Int64(item.targetMinutes), forKey: "targetMinutes")
        record.setValue(Int64(item.actualMinutes), forKey: "actualMinutes")
        record.setValue(item.timeSlot, forKey: "timeSlot")
        record.setValue(item.createdAt == 0 ? now : item.createdAt, forKey: "createdAt")
        record.setValue(item.updatedAt == 0 ? now : item.updatedAt, forKey: "updatedAt")
        record.setValue(item.deletedAt, forKey: "deletedAt")
        record.setValue(item.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(_ period: TimetablePeriod, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(period.syncId, forKey: "syncId")
        record.setValue(period.name, forKey: "name")
        record.setValue(Int64(period.startMinute), forKey: "startMinute")
        record.setValue(Int64(period.endMinute), forKey: "endMinute")
        record.setValue(Int64(period.sortOrder), forKey: "sortOrder")
        record.setValue(period.isActive, forKey: "isActive")
        record.setValue(period.createdAt == 0 ? now : period.createdAt, forKey: "createdAt")
        record.setValue(period.updatedAt == 0 ? now : period.updatedAt, forKey: "updatedAt")
        record.setValue(period.deletedAt, forKey: "deletedAt")
        record.setValue(period.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(
        _ entry: TimetableEntry,
        assignedId: Int64,
        termId: Int64?,
        termSyncId: String?,
        periodId: Int64,
        periodSyncId: String?,
        now: Int64,
        to record: NSManagedObject
    ) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(entry.syncId, forKey: "syncId")
        record.setValue(termId, forKey: "termId")
        record.setValue(termSyncId, forKey: "termSyncId")
        record.setValue(entry.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(periodId, forKey: "periodId")
        record.setValue(periodSyncId, forKey: "periodSyncId")
        record.setValue(entry.subjectName, forKey: "subjectName")
        record.setValue(entry.courseName, forKey: "courseName")
        record.setValue(entry.roomName, forKey: "roomName")
        record.setValue(entry.validFromDate, forKey: "validFromDate")
        record.setValue(entry.validToDate, forKey: "validToDate")
        record.setValue(entry.createdAt == 0 ? now : entry.createdAt, forKey: "createdAt")
        record.setValue(entry.updatedAt == 0 ? now : entry.updatedAt, forKey: "updatedAt")
        record.setValue(entry.deletedAt, forKey: "deletedAt")
        record.setValue(entry.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(_ term: TimetableTerm, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(term.syncId, forKey: "syncId")
        record.setValue(term.name, forKey: "name")
        record.setValue(term.startDate, forKey: "startDate")
        record.setValue(term.endDate, forKey: "endDate")
        record.setValue(term.isActive, forKey: "isActive")
        record.setValue(term.createdAt == 0 ? now : term.createdAt, forKey: "createdAt")
        record.setValue(term.updatedAt == 0 ? now : term.updatedAt, forKey: "updatedAt")
        record.setValue(term.deletedAt, forKey: "deletedAt")
        record.setValue(term.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(_ review: TimetableReviewRecord, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(review.syncId, forKey: "syncId")
        record.setValue(review.termId, forKey: "termId")
        record.setValue(review.termSyncId, forKey: "termSyncId")
        record.setValue(review.entryId, forKey: "entryId")
        record.setValue(review.entrySyncId, forKey: "entrySyncId")
        record.setValue(review.periodId, forKey: "periodId")
        record.setValue(review.periodSyncId, forKey: "periodSyncId")
        record.setValue(review.occurrenceDate, forKey: "occurrenceDate")
        record.setValue(review.dayOfWeek.rawValue, forKey: "dayOfWeek")
        record.setValue(review.periodName, forKey: "periodName")
        record.setValue(Int64(review.periodStartMinute), forKey: "periodStartMinute")
        record.setValue(Int64(review.periodEndMinute), forKey: "periodEndMinute")
        record.setValue(review.subjectName, forKey: "subjectName")
        record.setValue(review.courseName, forKey: "courseName")
        record.setValue(review.roomName, forKey: "roomName")
        record.setValue(review.isReviewed, forKey: "isReviewed")
        record.setValue(review.note, forKey: "note")
        record.setValue(review.isExcluded, forKey: "isExcluded")
        record.setValue(review.reviewedAt, forKey: "reviewedAt")
        record.setValue(review.createdAt == 0 ? now : review.createdAt, forKey: "createdAt")
        record.setValue(review.updatedAt == 0 ? now : review.updatedAt, forKey: "updatedAt")
        record.setValue(review.deletedAt, forKey: "deletedAt")
        record.setValue(review.lastSyncedAt, forKey: "lastSyncedAt")
    }

    static func apply(_ review: ProblemReviewRecord, assignedId: Int64, now: Int64, to record: NSManagedObject) {
        record.setValue(assignedId, forKey: "id")
        record.setValue(review.syncId, forKey: "syncId")
        record.setValue(review.problemId, forKey: "problemId")
        record.setValue(review.materialId, forKey: "materialId")
        record.setValue(review.materialSyncId, forKey: "materialSyncId")
        record.setValue(Int64(review.problemNumber), forKey: "problemNumber")
        record.setValue(review.reviewedAt, forKey: "reviewedAt")
        record.setValue(review.rating.rawValue, forKey: "rating")
        record.setValue(review.nextReviewDate, forKey: "nextReviewDate")
        record.setValue(Int64(review.consecutiveCorrectCount), forKey: "consecutiveCorrectCount")
        record.setValue(Int64(review.wrongCount), forKey: "wrongCount")
        record.setValue(review.createdAt == 0 ? now : review.createdAt, forKey: "createdAt")
        record.setValue(review.updatedAt == 0 ? now : review.updatedAt, forKey: "updatedAt")
        record.setValue(review.deletedAt, forKey: "deletedAt")
        record.setValue(review.lastSyncedAt, forKey: "lastSyncedAt")
    }

    // MARK: - Readers (record -> entity)

    static func subject(_ record: NSManagedObject) -> Subject {
        Subject(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            color: Int(record.value(forKey: "color") as? Int64 ?? 0),
            icon: (record.value(forKey: "icon") as? String).flatMap(SubjectIcon.init(rawValue:)),
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func material(_ record: NSManagedObject) -> Material {
        Material(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            subjectSyncId: record.value(forKey: "subjectSyncId") as? String,
            sortOrder: record.value(forKey: "sortOrder") as? Int64 ?? 0,
            totalPages: Int(record.value(forKey: "totalPages") as? Int64 ?? 0),
            currentPage: Int(record.value(forKey: "currentPage") as? Int64 ?? 0),
            totalProblems: Int(record.value(forKey: "totalProblems") as? Int64 ?? 0),
            problemChapters: decodeProblemChapters(record.value(forKey: "problemChaptersData") as? String),
            problemRecords: decodeProblemRecords(record.value(forKey: "problemRecordsData") as? String),
            color: (record.value(forKey: "color") as? Int64).map(Int.init),
            note: record.value(forKey: "note") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func session(_ record: NSManagedObject) -> StudySession {
        StudySession(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            materialId: record.value(forKey: "materialId") as? Int64,
            materialSyncId: record.value(forKey: "materialSyncId") as? String,
            materialName: record.value(forKey: "materialName") as? String ?? "",
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            subjectSyncId: record.value(forKey: "subjectSyncId") as? String,
            subjectName: record.value(forKey: "subjectName") as? String ?? "",
            sessionType: StudySessionType(rawValue: record.value(forKey: "sessionType") as? String ?? "") ?? .stopwatch,
            startTime: record.value(forKey: "startTime") as? Int64 ?? 0,
            endTime: record.value(forKey: "endTime") as? Int64 ?? 0,
            intervals: decodeIntervals(record.value(forKey: "intervalsData") as? String),
            rating: (record.value(forKey: "rating") as? NSNumber)?.intValue,
            note: record.value(forKey: "note") as? String,
            problemStart: (record.value(forKey: "problemStart") as? Int64).map(Int.init),
            problemEnd: (record.value(forKey: "problemEnd") as? Int64).map(Int.init),
            wrongProblemCount: (record.value(forKey: "wrongProblemCount") as? Int64).map(Int.init),
            problemRecords: decodeProblemRecords(record.value(forKey: "problemRecordsData") as? String),
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func goal(_ record: NSManagedObject) -> Goal {
        Goal(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            type: GoalType(rawValue: record.value(forKey: "type") as? String ?? GoalType.daily.rawValue) ?? .daily,
            targetMinutes: Int(record.value(forKey: "targetMinutes") as? Int64 ?? 0),
            dayOfWeek: (record.value(forKey: "dayOfWeek") as? String).flatMap(StudyWeekday.init(rawValue:)),
            weekStartDay: StudyWeekday(rawValue: record.value(forKey: "weekStartDay") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            isActive: record.value(forKey: "isActive") as? Bool ?? false,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func exam(_ record: NSManagedObject) -> Exam {
        Exam(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            date: record.value(forKey: "date") as? Int64 ?? 0,
            note: record.value(forKey: "note") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func plan(_ record: NSManagedObject) -> StudyPlan {
        StudyPlan(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            startDate: record.value(forKey: "startDate") as? Int64 ?? 0,
            endDate: record.value(forKey: "endDate") as? Int64 ?? 0,
            isActive: record.value(forKey: "isActive") as? Bool ?? false,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func planItem(_ record: NSManagedObject) -> PlanItem {
        PlanItem(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            planId: record.value(forKey: "planId") as? Int64 ?? 0,
            planSyncId: record.value(forKey: "planSyncId") as? String,
            subjectId: record.value(forKey: "subjectId") as? Int64 ?? 0,
            subjectSyncId: record.value(forKey: "subjectSyncId") as? String,
            dayOfWeek: StudyWeekday(rawValue: record.value(forKey: "dayOfWeek") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            targetMinutes: Int(record.value(forKey: "targetMinutes") as? Int64 ?? 0),
            actualMinutes: Int(record.value(forKey: "actualMinutes") as? Int64 ?? 0),
            timeSlot: record.value(forKey: "timeSlot") as? String,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func timetablePeriod(_ record: NSManagedObject) -> TimetablePeriod {
        TimetablePeriod(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            startMinute: Int(record.value(forKey: "startMinute") as? Int64 ?? 0),
            endMinute: Int(record.value(forKey: "endMinute") as? Int64 ?? 0),
            sortOrder: Int(record.value(forKey: "sortOrder") as? Int64 ?? 0),
            isActive: record.value(forKey: "isActive") as? Bool ?? true,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func timetableEntry(_ record: NSManagedObject) -> TimetableEntry {
        TimetableEntry(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            termId: record.value(forKey: "termId") as? Int64,
            termSyncId: record.value(forKey: "termSyncId") as? String,
            dayOfWeek: StudyWeekday(rawValue: record.value(forKey: "dayOfWeek") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            periodId: record.value(forKey: "periodId") as? Int64 ?? 0,
            periodSyncId: record.value(forKey: "periodSyncId") as? String,
            subjectName: record.value(forKey: "subjectName") as? String ?? "",
            courseName: record.value(forKey: "courseName") as? String,
            roomName: record.value(forKey: "roomName") as? String,
            validFromDate: record.value(forKey: "validFromDate") as? Int64,
            validToDate: record.value(forKey: "validToDate") as? Int64,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func timetableTerm(_ record: NSManagedObject) -> TimetableTerm {
        TimetableTerm(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            name: record.value(forKey: "name") as? String ?? "",
            startDate: record.value(forKey: "startDate") as? Int64 ?? 0,
            endDate: record.value(forKey: "endDate") as? Int64 ?? 0,
            isActive: record.value(forKey: "isActive") as? Bool ?? true,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func timetableReviewRecord(_ record: NSManagedObject) -> TimetableReviewRecord {
        TimetableReviewRecord(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            termId: record.value(forKey: "termId") as? Int64 ?? 0,
            termSyncId: record.value(forKey: "termSyncId") as? String,
            entryId: record.value(forKey: "entryId") as? Int64 ?? 0,
            entrySyncId: record.value(forKey: "entrySyncId") as? String,
            periodId: record.value(forKey: "periodId") as? Int64 ?? 0,
            periodSyncId: record.value(forKey: "periodSyncId") as? String,
            occurrenceDate: record.value(forKey: "occurrenceDate") as? Int64 ?? 0,
            dayOfWeek: StudyWeekday(rawValue: record.value(forKey: "dayOfWeek") as? String ?? StudyWeekday.monday.rawValue) ?? .monday,
            periodName: record.value(forKey: "periodName") as? String ?? "",
            periodStartMinute: Int(record.value(forKey: "periodStartMinute") as? Int64 ?? 0),
            periodEndMinute: Int(record.value(forKey: "periodEndMinute") as? Int64 ?? 0),
            subjectName: record.value(forKey: "subjectName") as? String ?? "",
            courseName: record.value(forKey: "courseName") as? String,
            roomName: record.value(forKey: "roomName") as? String,
            isReviewed: record.value(forKey: "isReviewed") as? Bool ?? false,
            note: record.value(forKey: "note") as? String,
            isExcluded: record.value(forKey: "isExcluded") as? Bool ?? false,
            reviewedAt: record.value(forKey: "reviewedAt") as? Int64,
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    static func problemReviewRecord(_ record: NSManagedObject) -> ProblemReviewRecord {
        let materialId = record.value(forKey: "materialId") as? Int64 ?? 0
        let problemNumber = Int(record.value(forKey: "problemNumber") as? Int64 ?? 0)
        return ProblemReviewRecord(
            id: record.value(forKey: "id") as? Int64 ?? 0,
            syncId: record.value(forKey: "syncId") as? String ?? "",
            problemId: record.value(forKey: "problemId") as? String ?? ProblemReviewRecord.problemId(materialId: materialId, problemNumber: problemNumber),
            materialId: materialId,
            materialSyncId: record.value(forKey: "materialSyncId") as? String,
            problemNumber: problemNumber,
            reviewedAt: record.value(forKey: "reviewedAt") as? Int64 ?? 0,
            rating: ProblemReviewRating(rawValue: record.value(forKey: "rating") as? String ?? "") ?? .again,
            nextReviewDate: record.value(forKey: "nextReviewDate") as? Int64 ?? 0,
            consecutiveCorrectCount: Int(record.value(forKey: "consecutiveCorrectCount") as? Int64 ?? 0),
            wrongCount: Int(record.value(forKey: "wrongCount") as? Int64 ?? 0),
            createdAt: record.value(forKey: "createdAt") as? Int64 ?? 0,
            updatedAt: record.value(forKey: "updatedAt") as? Int64 ?? 0,
            deletedAt: record.value(forKey: "deletedAt") as? Int64,
            lastSyncedAt: record.value(forKey: "lastSyncedAt") as? Int64
        )
    }

    // MARK: - Blob encode/decode

    static func encodeIntervals(_ intervals: [StudySessionInterval]) -> String? {
        guard !intervals.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(intervals) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeIntervals(_ value: String?) -> [StudySessionInterval] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([StudySessionInterval].self, from: data)) ?? []
    }

    static func encodeProblemRecords(_ records: [ProblemSessionRecord]) -> String? {
        guard !records.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(records.sorted(by: { $0.number < $1.number })) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeProblemRecords(_ value: String?) -> [ProblemSessionRecord] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ProblemSessionRecord].self, from: data)) ?? []
    }

    static func encodeProblemChapters(_ chapters: [ProblemChapter]) -> String? {
        guard !chapters.isEmpty else { return nil }
        guard let data = try? JSONEncoder().encode(chapters) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decodeProblemChapters(_ value: String?) -> [ProblemChapter] {
        guard let value, let data = value.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([ProblemChapter].self, from: data)) ?? []
    }
}
