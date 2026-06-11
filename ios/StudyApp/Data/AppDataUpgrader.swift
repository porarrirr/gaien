import Foundation

enum AppDataUpgradeError: LocalizedError {
    case invalidRoot
    case invalidSchemaVersion
    case unsupportedSchemaVersion(Int)

    var errorDescription: String? {
        switch self {
        case .invalidRoot:
            return "バックアップJSONの形式が正しくありません"
        case .invalidSchemaVersion:
            return "バックアップJSONのschemaVersionが正しくありません"
        case .unsupportedSchemaVersion(let version):
            return "このアプリではschemaVersion \(version)のバックアップを読み込めません"
        }
    }
}

enum AppDataUpgrader {
    static func decode(_ data: Data) throws -> AppData {
        let upgraded = try upgrade(data)
        return try JSONDecoder().decode(AppData.self, from: upgraded)
    }

    static func upgrade(_ data: Data) throws -> Data {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw AppDataUpgradeError.invalidRoot
        }

        let rawVersion = object["schemaVersion"]
        let version: Int
        if rawVersion == nil {
            version = 1
        } else if rawVersion is Bool {
            throw AppDataUpgradeError.invalidSchemaVersion
        } else if let number = rawVersion as? NSNumber {
            guard number.doubleValue.rounded() == number.doubleValue else {
                throw AppDataUpgradeError.invalidSchemaVersion
            }
            version = number.intValue
        } else {
            throw AppDataUpgradeError.invalidSchemaVersion
        }

        guard version >= 1 else {
            throw AppDataUpgradeError.invalidSchemaVersion
        }
        guard version <= AppData.currentSchemaVersion else {
            throw AppDataUpgradeError.unsupportedSchemaVersion(version)
        }

        var currentVersion = version
        while currentVersion < AppData.currentSchemaVersion {
            switch currentVersion {
            case 1:
                object = upgradeV1ToV2(object)
                currentVersion = 2
            default:
                throw AppDataUpgradeError.unsupportedSchemaVersion(currentVersion)
            }
        }

        object["schemaVersion"] = AppData.currentSchemaVersion
        normalizeAdditiveCollections(in: &object)
        return try JSONSerialization.data(withJSONObject: object)
    }

    private static func upgradeV1ToV2(_ source: [String: Any]) -> [String: Any] {
        var upgraded = source
        upgraded["schemaVersion"] = 2
        upgraded["supportsProblemRecords"] = source["supportsProblemRecords"] as? Bool ?? false
        normalizeAdditiveCollections(in: &upgraded)
        return upgraded
    }

    private static func normalizeAdditiveCollections(in object: inout [String: Any]) {
        for key in [
            "subjects",
            "materials",
            "sessions",
            "goals",
            "exams",
            "plans",
            "timetablePeriods",
            "timetableEntries",
            "timetableTerms",
            "timetableReviewRecords",
            "problemReviewRecords"
        ] where object[key] == nil {
            object[key] = []
        }
        if object["supportsProblemRecords"] == nil {
            object["supportsProblemRecords"] = false
        }
        if object["exportDate"] == nil {
            object["exportDate"] = 0
        }
    }
}
