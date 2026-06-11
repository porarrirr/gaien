import CoreData
import Foundation

struct DataMigrationLedger: Equatable {
    static let currentSchemaVersion = 1
    static let schemaVersionKey = "StudyApp.dataSchemaVersion"
    static let completedMigrationsKey = "StudyApp.completedMigrations"
    static let identifierSequencePrefix = "StudyApp.nextIdentifier."

    var dataSchemaVersion: Int
    var completedMigrations: Set<String>

    static func load(
        coordinator: NSPersistentStoreCoordinator,
        store: NSPersistentStore
    ) -> DataMigrationLedger {
        let metadata = coordinator.metadata(for: store)
        let version = (metadata[schemaVersionKey] as? NSNumber)?.intValue
            ?? metadata[schemaVersionKey] as? Int
            ?? 0
        let completed = metadata[completedMigrationsKey] as? [String] ?? []
        return DataMigrationLedger(
            dataSchemaVersion: version,
            completedMigrations: Set(completed)
        )
    }

    func save(
        coordinator: NSPersistentStoreCoordinator,
        store: NSPersistentStore
    ) throws {
        var metadata = coordinator.metadata(for: store)
        metadata[Self.schemaVersionKey] = dataSchemaVersion
        metadata[Self.completedMigrationsKey] = completedMigrations.sorted()
        coordinator.setMetadata(metadata, for: store)
    }
}

struct DataMigration {
    let id: String
    let run: (NSManagedObjectContext) throws -> Void
}
