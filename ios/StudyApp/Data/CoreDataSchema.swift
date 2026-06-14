import CoreData
import Foundation

/// Programmatic Core Data schema for the StudyApp store. Extracted from
/// `PersistenceController` so the repository code isn't interleaved with
/// ~240 lines of entity definitions.
///
/// IMPORTANT: changes here affect on-disk schema. Any attribute add/remove
/// must be paired with a migration plan.
enum CoreDataSchema {
    static let entityNames = [
        "SubjectRecord",
        "MaterialRecord",
        "StudySessionRecord",
        "GoalRecord",
        "ExamRecord",
        "StudyPlanRecord",
        "PlanItemRecord",
        "TimetablePeriodRecord",
        "TimetableEntryRecord",
        "TimetableTermRecord",
        "TimetableReviewRecord",
        "ProblemReviewRecord"
    ]

    static func makeModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        model.entities = [
            entity(
                name: "SubjectRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "color", type: .integer64AttributeType),
                    attribute(name: "icon", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "MaterialRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "subjectSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "sortOrder", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "totalPages", type: .integer64AttributeType),
                    attribute(name: "currentPage", type: .integer64AttributeType),
                    attribute(name: "totalProblems", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "problemChaptersData", type: .stringAttributeType, optional: true),
                    attribute(name: "problemRecordsData", type: .stringAttributeType, optional: true),
                    attribute(name: "color", type: .integer64AttributeType, optional: true),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "StudySessionRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "materialId", type: .integer64AttributeType, optional: true),
                    attribute(name: "materialSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "materialName", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "subjectSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectName", type: .stringAttributeType),
                    attribute(name: "sessionType", type: .stringAttributeType, defaultValue: StudySessionType.stopwatch.rawValue),
                    attribute(name: "startTime", type: .integer64AttributeType),
                    attribute(name: "endTime", type: .integer64AttributeType),
                    attribute(name: "duration", type: .integer64AttributeType),
                    attribute(name: "date", type: .integer64AttributeType),
                    attribute(name: "intervalsData", type: .stringAttributeType, optional: true),
                    attribute(name: "rating", type: .integer16AttributeType, optional: true),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "problemStart", type: .integer64AttributeType, optional: true),
                    attribute(name: "problemEnd", type: .integer64AttributeType, optional: true),
                    attribute(name: "wrongProblemCount", type: .integer64AttributeType, optional: true),
                    attribute(name: "problemRecordsData", type: .stringAttributeType, optional: true),
                    attribute(name: "screenTimeUnlockExcluded", type: .booleanAttributeType, defaultValue: false),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "GoalRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "type", type: .stringAttributeType),
                    attribute(name: "targetMinutes", type: .integer64AttributeType),
                    attribute(name: "dayOfWeek", type: .stringAttributeType, optional: true),
                    attribute(name: "weekStartDay", type: .stringAttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "ExamRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "date", type: .integer64AttributeType),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "StudyPlanRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "startDate", type: .integer64AttributeType),
                    attribute(name: "endDate", type: .integer64AttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "PlanItemRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "planId", type: .integer64AttributeType),
                    attribute(name: "planSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectId", type: .integer64AttributeType),
                    attribute(name: "subjectSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "dayOfWeek", type: .stringAttributeType),
                    attribute(name: "targetMinutes", type: .integer64AttributeType),
                    attribute(name: "actualMinutes", type: .integer64AttributeType),
                    attribute(name: "timeSlot", type: .stringAttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetablePeriodRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "startMinute", type: .integer64AttributeType),
                    attribute(name: "endMinute", type: .integer64AttributeType),
                    attribute(name: "sortOrder", type: .integer64AttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType, defaultValue: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetableEntryRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "termId", type: .integer64AttributeType, optional: true),
                    attribute(name: "termSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "dayOfWeek", type: .stringAttributeType),
                    attribute(name: "periodId", type: .integer64AttributeType),
                    attribute(name: "periodSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "subjectName", type: .stringAttributeType),
                    attribute(name: "courseName", type: .stringAttributeType, optional: true),
                    attribute(name: "roomName", type: .stringAttributeType, optional: true),
                    attribute(name: "validFromDate", type: .integer64AttributeType, optional: true),
                    attribute(name: "validToDate", type: .integer64AttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetableTermRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "name", type: .stringAttributeType),
                    attribute(name: "startDate", type: .integer64AttributeType),
                    attribute(name: "endDate", type: .integer64AttributeType),
                    attribute(name: "isActive", type: .booleanAttributeType, defaultValue: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "TimetableReviewRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "termId", type: .integer64AttributeType),
                    attribute(name: "termSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "entryId", type: .integer64AttributeType),
                    attribute(name: "entrySyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "periodId", type: .integer64AttributeType),
                    attribute(name: "periodSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "occurrenceDate", type: .integer64AttributeType),
                    attribute(name: "dayOfWeek", type: .stringAttributeType),
                    attribute(name: "periodName", type: .stringAttributeType),
                    attribute(name: "periodStartMinute", type: .integer64AttributeType),
                    attribute(name: "periodEndMinute", type: .integer64AttributeType),
                    attribute(name: "subjectName", type: .stringAttributeType),
                    attribute(name: "courseName", type: .stringAttributeType, optional: true),
                    attribute(name: "roomName", type: .stringAttributeType, optional: true),
                    attribute(name: "isReviewed", type: .booleanAttributeType, defaultValue: false),
                    attribute(name: "note", type: .stringAttributeType, optional: true),
                    attribute(name: "isExcluded", type: .booleanAttributeType, defaultValue: false),
                    attribute(name: "reviewedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            ),
            entity(
                name: "ProblemReviewRecord",
                attributes: [
                    attribute(name: "id", type: .integer64AttributeType),
                    attribute(name: "syncId", type: .stringAttributeType),
                    attribute(name: "problemId", type: .stringAttributeType),
                    attribute(name: "materialId", type: .integer64AttributeType),
                    attribute(name: "materialSyncId", type: .stringAttributeType, optional: true),
                    attribute(name: "problemNumber", type: .integer64AttributeType),
                    attribute(name: "reviewedAt", type: .integer64AttributeType),
                    attribute(name: "rating", type: .stringAttributeType),
                    attribute(name: "nextReviewDate", type: .integer64AttributeType),
                    attribute(name: "consecutiveCorrectCount", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "wrongCount", type: .integer64AttributeType, defaultValue: Int64(0)),
                    attribute(name: "createdAt", type: .integer64AttributeType),
                    attribute(name: "updatedAt", type: .integer64AttributeType),
                    attribute(name: "deletedAt", type: .integer64AttributeType, optional: true),
                    attribute(name: "lastSyncedAt", type: .integer64AttributeType, optional: true)
                ]
            )
        ]
        return model
    }

    private static func entity(name: String, attributes: [NSAttributeDescription]) -> NSEntityDescription {
        let entity = NSEntityDescription()
        entity.name = name
        entity.managedObjectClassName = "NSManagedObject"
        entity.properties = attributes
        return entity
    }

    private static func attribute(
        name: String,
        type: NSAttributeType,
        optional: Bool = false,
        defaultValue: Any? = nil
    ) -> NSAttributeDescription {
        let attribute = NSAttributeDescription()
        attribute.name = name
        attribute.attributeType = type
        attribute.isOptional = optional
        attribute.defaultValue = defaultValue
        return attribute
    }
}
