import CoreData
import Foundation

/// Lightweight Core Data query helpers that work against any
/// `NSManagedObjectContext`.
///
/// Previously these were private instance methods on `PersistenceController`
/// that only worked on `viewContext`. By making them free functions taking a
/// context, both the main `viewContext` path (per-entity CRUD) and heavy
/// background-context operations (export, import, overdue calculations) can
/// share the same fetch boilerplate.
enum CoreDataQuery {

    /// Fetches managed objects of `entity` matching `predicate`, sorted by `sort`.
    static func fetch(
        _ entity: String,
        in context: NSManagedObjectContext,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor] = []
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.sortDescriptors = sort
        return try context.fetch(request)
    }

    /// Fetches a single record matching `id`, or `nil` if none exists.
    static func fetchOne(
        _ entity: String,
        id: Int64,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %lld", id)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    /// Maps `syncId` → persisted `id` for every record of `entity`. Empty sync
    /// IDs or non-positive IDs are skipped, matching the behaviour of the
    /// legacy helper it replaces.
    static func existingIdMap(
        _ entity: String,
        in context: NSManagedObjectContext
    ) throws -> [String: Int64] {
        let records = try fetch(entity, in: context)
        var result = [String: Int64]()
        result.reserveCapacity(records.count)
        for record in records {
            guard let syncId = record.value(forKey: "syncId") as? String, !syncId.isEmpty else { continue }
            guard let id = record.value(forKey: "id") as? Int64, id > 0 else { continue }
            result[syncId] = id
        }
        return result
    }

    /// Returns the largest `id` across the given entities, or `0` if all empty.
    /// Used to allocate the next local identifier without clashing with
    /// records imported from remote snapshots.
    static func maxIdentifier(
        in context: NSManagedObjectContext,
        entities: [String]
    ) throws -> Int64 {
        var maxId: Int64 = 0
        for entityName in entities {
            let request = NSFetchRequest<NSDictionary>(entityName: entityName)
            request.resultType = .dictionaryResultType
            let expression = NSExpressionDescription()
            expression.name = "maxId"
            expression.expression = NSExpression(forFunction: "max:", arguments: [NSExpression(forKeyPath: "id")])
            expression.expressionResultType = .integer64AttributeType
            request.propertiesToFetch = [expression]
            let result = try context.fetch(request).first?["maxId"] as? Int64 ?? 0
            maxId = max(maxId, result)
        }
        return maxId
    }

    /// Returns true iff every entity has no rows. Used to gate the one-time
    /// legacy JSON snapshot import.
    static func isEmpty(
        in context: NSManagedObjectContext,
        entities: [String]
    ) throws -> Bool {
        for entity in entities {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            request.fetchLimit = 1
            if try context.count(for: request) > 0 {
                return false
            }
        }
        return true
    }
}
