import Foundation

struct PersistedSyncUserState: Codable, Equatable {
    var cursor: SyncDeltaCursor = .zero
    var baseShadow: AppData?
    var revisions: [String: String] = [:]
    var legacyMigrationDone = false
    var lastSyncAt: Int64?
}

struct PersistedSyncState: Codable, Equatable {
    var ownerUserId: String?
    var users: [String: PersistedSyncUserState] = [:]
}

struct SyncStateLoadResult {
    var root: PersistedSyncState
    var user: PersistedSyncUserState
    var migratedLegacyState: Bool
    var repairedInconsistentState: Bool
}

enum SyncStateStore {
    private static let legacyLastSyncKey = "studyapp.sync.lastSyncAt"
    private static let legacyOwnerKey = "studyapp.sync.localOwnerUserId"
    private static let legacyCursorPrefix = "studyapp.sync.deltaCursor."
    private static let legacyMigrationPrefix = "studyapp.sync.deltaMigrationDone."

    static func load(
        userId: String,
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) throws -> SyncStateLoadResult {
        var root = try loadRoot(fileManager: fileManager)
        var migratedLegacyState = false
        var repairedInconsistentState = false
        var createdUserState = false

        var user: PersistedSyncUserState
        if let existing = root.users[userId] {
            user = existing
        } else {
            user = try legacyUserState(userId: userId, fileManager: fileManager, defaults: defaults)
            root.users[userId] = user
            createdUserState = true
            if root.ownerUserId == nil {
                root.ownerUserId = defaults.string(forKey: legacyOwnerKey)
            }
            migratedLegacyState = hasLegacyState(userId: userId, fileManager: fileManager, defaults: defaults)
        }

        let repair = repairInconsistentState(user)
        if repair.didRepair {
            user = repair.state
            root.users[userId] = user
            repairedInconsistentState = true
        }

        if createdUserState || migratedLegacyState || repairedInconsistentState {
            try save(root, fileManager: fileManager)
            if migratedLegacyState {
                try removeLegacyState(userId: userId, fileManager: fileManager, defaults: defaults)
            }
        }

        return SyncStateLoadResult(
            root: root,
            user: user,
            migratedLegacyState: migratedLegacyState,
            repairedInconsistentState: repairedInconsistentState
        )
    }

    static func save(
        _ state: PersistedSyncState,
        fileManager: FileManager = .default
    ) throws {
        let url = try stateFileURL(fileManager: fileManager)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        try fileManager.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    static func clear(
        fileManager: FileManager = .default,
        defaults: UserDefaults = .standard
    ) throws {
        let url = try stateFileURL(fileManager: fileManager)
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        for key in defaults.dictionaryRepresentation().keys where
            key == legacyLastSyncKey ||
            key == legacyOwnerKey ||
            key.hasPrefix(legacyCursorPrefix) ||
            key.hasPrefix(legacyMigrationPrefix) {
            defaults.removeObject(forKey: key)
        }
        for directoryName in ["StudyApp/SyncBases", "StudyApp/SyncBaseRevisions"] {
            guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                continue
            }
            let directory = base.appendingPathComponent(directoryName, isDirectory: true)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    static func mergedRevisions(
        current: [String: String],
        envelopes: [SyncEntityEnvelope]
    ) -> [String: String] {
        var revisions = current
        for envelope in envelopes {
            if let revision = envelope.revisionId ?? envelope.contentHash, !revision.isEmpty {
                revisions[envelope.documentId] = revision
            }
        }
        return revisions
    }

    static func repairInconsistentState(
        _ state: PersistedSyncUserState
    ) -> (state: PersistedSyncUserState, didRepair: Bool) {
        let hasCursor = state.cursor != .zero
        let hasBase = state.baseShadow != nil
        let hasRevisions = !state.revisions.isEmpty
        let baseHasData = state.baseShadow.map { !$0.isEmpty } ?? false
        let isInconsistent =
            hasCursor != hasBase ||
            (hasRevisions && (!hasCursor || !hasBase)) ||
            (baseHasData && !hasRevisions)
        guard isInconsistent else {
            return (state, false)
        }

        var repaired = state
        repaired.cursor = .zero
        repaired.baseShadow = nil
        repaired.revisions = [:]
        return (repaired, true)
    }

    private static func loadRoot(fileManager: FileManager) throws -> PersistedSyncState {
        let url = try stateFileURL(fileManager: fileManager)
        guard fileManager.fileExists(atPath: url.path) else {
            return PersistedSyncState()
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PersistedSyncState.self, from: data)
    }

    private static func legacyUserState(
        userId: String,
        fileManager: FileManager,
        defaults: UserDefaults
    ) throws -> PersistedSyncUserState {
        PersistedSyncUserState(
            cursor: try legacyCursor(userId: userId, defaults: defaults),
            baseShadow: try legacyBaseShadow(userId: userId, fileManager: fileManager),
            revisions: try legacyRevisions(userId: userId, fileManager: fileManager),
            legacyMigrationDone: defaults.bool(forKey: legacyMigrationPrefix + userId),
            lastSyncAt: (defaults.object(forKey: legacyLastSyncKey) as? NSNumber)?.int64Value
        )
    }

    private static func legacyCursor(userId: String, defaults: UserDefaults) throws -> SyncDeltaCursor {
        let key = legacyCursorPrefix + userId
        if let data = defaults.data(forKey: key) {
            return try JSONDecoder().decode(SyncDeltaCursor.self, from: data)
        }
        if let number = defaults.object(forKey: key) as? NSNumber {
            return .fromLegacy(number.int64Value)
        }
        return .zero
    }

    private static func legacyBaseShadow(userId: String, fileManager: FileManager) throws -> AppData? {
        guard let url = legacyBaseURL(userId: userId, fileManager: fileManager),
              fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        return try AppDataUpgrader.decode(Data(contentsOf: url))
    }

    private static func legacyRevisions(userId: String, fileManager: FileManager) throws -> [String: String] {
        guard let url = legacyRevisionURL(userId: userId, fileManager: fileManager),
              fileManager.fileExists(atPath: url.path) else {
            return [:]
        }
        return try JSONDecoder().decode([String: String].self, from: Data(contentsOf: url))
    }

    private static func hasLegacyState(
        userId: String,
        fileManager: FileManager,
        defaults: UserDefaults
    ) -> Bool {
        defaults.object(forKey: legacyLastSyncKey) != nil ||
            defaults.object(forKey: legacyOwnerKey) != nil ||
            defaults.object(forKey: legacyCursorPrefix + userId) != nil ||
            defaults.object(forKey: legacyMigrationPrefix + userId) != nil ||
            legacyBaseURL(userId: userId, fileManager: fileManager).map {
                fileManager.fileExists(atPath: $0.path)
            } == true ||
            legacyRevisionURL(userId: userId, fileManager: fileManager).map {
                fileManager.fileExists(atPath: $0.path)
            } == true
    }

    private static func removeLegacyState(
        userId: String,
        fileManager: FileManager,
        defaults: UserDefaults
    ) throws {
        defaults.removeObject(forKey: legacyLastSyncKey)
        defaults.removeObject(forKey: legacyOwnerKey)
        defaults.removeObject(forKey: legacyCursorPrefix + userId)
        defaults.removeObject(forKey: legacyMigrationPrefix + userId)
        if let url = legacyBaseURL(userId: userId, fileManager: fileManager),
           fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
        if let url = legacyRevisionURL(userId: userId, fileManager: fileManager),
           fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }

    private static func stateFileURL(fileManager: FileManager) throws -> URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let directory = base.appendingPathComponent("StudyApp", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("SyncState.json")
    }

    private static func legacyBaseURL(userId: String, fileManager: FileManager) -> URL? {
        let safeUserId = userId.replacingOccurrences(of: "/", with: "_")
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("StudyApp/SyncBases", isDirectory: true)
            .appendingPathComponent("\(safeUserId).json")
    }

    private static func legacyRevisionURL(userId: String, fileManager: FileManager) -> URL? {
        let safeUserId = userId.replacingOccurrences(of: "/", with: "_")
        return fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("StudyApp/SyncBaseRevisions", isDirectory: true)
            .appendingPathComponent("\(safeUserId).json")
    }
}
