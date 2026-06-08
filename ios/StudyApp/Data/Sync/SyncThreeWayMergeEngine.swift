import Foundation
import CryptoKit

struct SyncThreeWayMergeOutcome: Equatable {
    var merged: AppData
    var conflicts: [SyncConflict]
    var usedLegacyTwoWayFallback: Bool
}

/// Git-style three-way merge on top of the existing delta sync model.
/// When no base shadow exists, falls back to `SyncMergeEngine` (backward compatible).
enum SyncThreeWayMergeEngine {

    static func merge(
        base: AppData?,
        local: AppData,
        remoteEnvelopes: [SyncEntityEnvelope],
        now: Int64 = Date().epochMilliseconds
    ) -> SyncThreeWayMergeOutcome {
        let remotePartial = SyncDeltaSerializer.partialAppData(from: remoteEnvelopes, exportDate: local.exportDate)
        guard let base else {
            let merged = SyncMergeEngine.merge(local: local, remote: remotePartial)
            return SyncThreeWayMergeOutcome(
                merged: merged,
                conflicts: [],
                usedLegacyTwoWayFallback: true
            )
        }

        var conflicts: [SyncConflict] = []
        let merged = AppData(
            schemaVersion: max(local.schemaVersion, remotePartial.schemaVersion, base.schemaVersion),
            supportsProblemRecords: local.supportsProblemRecords || remotePartial.supportsProblemRecords || base.supportsProblemRecords,
            subjects: mergeSubjects(base: base.subjects, local: local.subjects, remote: remotePartial.subjects, conflicts: &conflicts, now: now),
            materials: mergeMaterials(base: base.materials, local: local.materials, remote: remotePartial.materials, conflicts: &conflicts, now: now),
            sessions: mergeSessions(base: base.sessions, local: local.sessions, remote: remotePartial.sessions, conflicts: &conflicts, now: now),
            goals: mergeEntities(base: base.goals, local: local.goals, remote: remotePartial.goals, kind: .goal, title: { $0.type.rawValue }, conflicts: &conflicts, now: now) { $0.syncId },
            exams: mergeEntities(base: base.exams, local: local.exams, remote: remotePartial.exams, kind: .exam, title: { $0.name }, conflicts: &conflicts, now: now) { $0.syncId },
            plans: mergePlans(base: base.plans, local: local.plans, remote: remotePartial.plans, conflicts: &conflicts, now: now),
            timetablePeriods: mergeEntities(base: base.timetablePeriods, local: local.timetablePeriods, remote: remotePartial.timetablePeriods, kind: .timetablePeriod, title: { $0.name }, conflicts: &conflicts, now: now) { $0.syncId },
            timetableEntries: mergeEntities(base: base.timetableEntries, local: local.timetableEntries, remote: remotePartial.timetableEntries, kind: .timetableEntry, title: { $0.subjectName }, conflicts: &conflicts, now: now) { $0.syncId },
            timetableTerms: mergeEntities(base: base.timetableTerms, local: local.timetableTerms, remote: remotePartial.timetableTerms, kind: .timetableTerm, title: { $0.name }, conflicts: &conflicts, now: now) { $0.syncId },
            timetableReviewRecords: mergeEntities(base: base.timetableReviewRecords, local: local.timetableReviewRecords, remote: remotePartial.timetableReviewRecords, kind: .timetableReviewRecord, title: { $0.subjectName }, conflicts: &conflicts, now: now) { $0.syncId },
            problemReviewRecords: mergeProblemReviews(base: base.problemReviewRecords, local: local.problemReviewRecords, remote: remotePartial.problemReviewRecords, conflicts: &conflicts, now: now),
            exportDate: max(local.exportDate, remotePartial.exportDate, base.exportDate, now)
        )

        return SyncThreeWayMergeOutcome(
            merged: merged,
            conflicts: conflicts,
            usedLegacyTwoWayFallback: false
        )
    }

    /// Applies user-selected resolutions onto `local` data.
    static func applyResolutions(
        _ resolutions: [SyncConflictResolution],
        to local: AppData,
        conflicts: [SyncConflict],
        resolvedAt: Int64 = Date().epochMilliseconds
    ) -> AppData {
        var result = local
        let conflictMap = Dictionary(uniqueKeysWithValues: conflicts.map { ($0.documentId, $0) })

        for resolution in resolutions {
            let documentId = "\(resolution.kind.rawValue)-\(resolution.syncId)"
            guard let conflict = conflictMap[documentId] else { continue }
            let json: String
            switch resolution.strategy {
            case .keepLocal: json = conflict.localJson
            case .keepRemote: json = conflict.remoteJson
            case .keepMerged: json = conflict.suggestedMergedJson
            }
            result = replaceEntity(
                in: result,
                kind: resolution.kind,
                syncId: resolution.syncId,
                json: jsonWithUpdatedAt(json, resolvedAt)
            )
        }
        return result
    }

    // MARK: - Materials

    private static func mergeMaterials(
        base: [Material],
        local: [Material],
        remote: [Material],
        conflicts: inout [SyncConflict],
        now: Int64
    ) -> [Material] {
        let baseMap = Dictionary(uniqueKeysWithValues: base.map { ($0.syncId, $0) })
        let localMap = Dictionary(uniqueKeysWithValues: local.map { ($0.syncId, $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.syncId, $0) })
        let ids = Set(baseMap.keys).union(localMap.keys).union(remoteMap.keys)

        return ids.compactMap { syncId in
            let baseValue = baseMap[syncId]
            let localValue = localMap[syncId]
            let remoteValue = remoteMap[syncId]

            if let localValue, let remoteValue {
                return mergeMaterial(base: baseValue, local: localValue, remote: remoteValue, conflicts: &conflicts, now: now)
            }
            if let localValue { return localValue }
            return remoteValue
        }
    }

    private static func mergeMaterial(
        base: Material?,
        local: Material,
        remote: Material,
        conflicts: inout [SyncConflict],
        now: Int64
    ) -> Material {
        if let deleteConflict = deletionConflict(base: base, localDeleted: local.deletedAt, remoteDeleted: remote.deletedAt, local: local, remote: remote, kind: .material, title: local.name, now: now) {
            conflicts.append(deleteConflict)
            return local.deletedAt == nil ? local : remote
        }

        var merged = pickNewer(local: local, remote: remote)
        var conflictFields: [SyncConflictField] = []
        let baseValue = base ?? local

        if scalarConflict(base: baseValue.name, local: local.name, remote: remote.name) {
            conflictFields.append(.name)
        }
        if scalarConflict(base: baseValue.note ?? "", local: local.note ?? "", remote: remote.note ?? "") {
            conflictFields.append(.note)
        }

        merged.currentPage = max(local.currentPage, remote.currentPage, baseValue.currentPage)
        merged.totalPages = max(local.totalPages, remote.totalPages, baseValue.totalPages)
        merged.totalProblems = max(local.totalProblems, remote.totalProblems, baseValue.totalProblems)
        merged.problemChapters = unionChapters(base: baseValue.problemChapters, local: local.problemChapters, remote: remote.problemChapters)
        merged.problemRecords = unionProblemRecords(base: baseValue.problemRecords, local: local.problemRecords, remote: remote.problemRecords)

        if !conflictFields.isEmpty {
            conflicts.append(makeConflict(
                kind: .material,
                entity: merged,
                local: local,
                remote: remote,
                base: base,
                fields: conflictFields,
                summary: "教材「\(local.name)」の内容が端末間で異なります",
                now: now
            ))
            return local
        }
        return merged
    }

    // MARK: - Sessions

    private static func mergeSessions(
        base: [StudySession],
        local: [StudySession],
        remote: [StudySession],
        conflicts: inout [SyncConflict],
        now: Int64
    ) -> [StudySession] {
        let baseMap = Dictionary(uniqueKeysWithValues: base.map { ($0.syncId, $0) })
        let localMap = Dictionary(uniqueKeysWithValues: local.map { ($0.syncId, $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.syncId, $0) })
        let ids = Set(baseMap.keys).union(localMap.keys).union(remoteMap.keys)

        return ids.compactMap { syncId in
            guard let localValue = localMap[syncId], let remoteValue = remoteMap[syncId] else {
                return localMap[syncId] ?? remoteMap[syncId]
            }
            if let deleteConflict = deletionConflict(base: baseMap[syncId], localDeleted: localValue.deletedAt, remoteDeleted: remoteValue.deletedAt, local: localValue, remote: remoteValue, kind: .session, title: localValue.subjectName, now: now) {
                conflicts.append(deleteConflict)
                return localValue.deletedAt == nil ? localValue : remoteValue
            }
            var merged = pickNewer(local: localValue, remote: remoteValue)
            let baseValue = baseMap[syncId] ?? localValue
            merged.problemRecords = unionProblemRecords(base: baseValue.problemRecords, local: localValue.problemRecords, remote: remoteValue.problemRecords)
            merged.problemStart = merged.problemStart ?? localValue.problemStart ?? remoteValue.problemStart ?? baseValue.problemStart
            merged.problemEnd = merged.problemEnd ?? localValue.problemEnd ?? remoteValue.problemEnd ?? baseValue.problemEnd
            merged.wrongProblemCount = maxOptional(localValue.wrongProblemCount, remoteValue.wrongProblemCount, baseValue.wrongProblemCount)
            return merged
        }
    }

    // MARK: - Problem reviews

    private static func mergeProblemReviews(
        base: [ProblemReviewRecord],
        local: [ProblemReviewRecord],
        remote: [ProblemReviewRecord],
        conflicts: inout [SyncConflict],
        now: Int64
    ) -> [ProblemReviewRecord] {
        let baseMap = Dictionary(uniqueKeysWithValues: base.map { ($0.syncId, $0) })
        let localMap = Dictionary(uniqueKeysWithValues: local.map { ($0.syncId, $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { ($0.syncId, $0) })
        let ids = Set(baseMap.keys).union(localMap.keys).union(remoteMap.keys)

        return ids.compactMap { syncId -> ProblemReviewRecord? in
            guard let localValue = localMap[syncId], let remoteValue = remoteMap[syncId] else {
                return localMap[syncId] ?? remoteMap[syncId]
            }
            if localValue.deletedAt != nil || remoteValue.deletedAt != nil {
                return SyncMergeEngine.merge([localValue], [remoteValue], key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt).first ?? localValue
            }
            if localValue.reviewedAt == remoteValue.reviewedAt {
                return localValue.updatedAt >= remoteValue.updatedAt ? localValue : remoteValue
            }
            let winner = localValue.reviewedAt >= remoteValue.reviewedAt ? localValue : remoteValue
            let loser = winner.syncId == localValue.syncId ? remoteValue : localValue
            if let baseValue = baseMap[syncId],
               localValue.reviewedAt != baseValue.reviewedAt,
               remoteValue.reviewedAt != baseValue.reviewedAt,
               localValue.problemId == remoteValue.problemId,
               localValue.rating != remoteValue.rating {
                conflicts.append(makeConflict(
                    kind: .problemReviewRecord,
                    entity: winner,
                    local: localValue,
                    remote: remoteValue,
                    base: baseValue,
                    fields: [.problemReviewState],
                    summary: "問題 \(localValue.problemNumber) の復習結果が端末間で異なります",
                    now: now
                ))
                return localValue
            }
            _ = loser
            return winner
        }
    }

    // MARK: - Plans

    private static func mergePlans(
        base: [PlanData],
        local: [PlanData],
        remote: [PlanData],
        conflicts: inout [SyncConflict],
        now: Int64
    ) -> [PlanData] {
        let mergedPlans = mergeEntities(
            base: base.map(\.plan),
            local: local.map(\.plan),
            remote: remote.map(\.plan),
            kind: .plan,
            title: { $0.name },
            conflicts: &conflicts,
            now: now
        ) { $0.syncId }
        let mergedItems = mergeEntities(
            base: base.flatMap(\.items),
            local: local.flatMap(\.items),
            remote: remote.flatMap(\.items),
            kind: .planItem,
            title: { _ in "計画項目" },
            conflicts: &conflicts,
            now: now
        ) { $0.syncId }
        let grouped = Dictionary(grouping: mergedItems, by: \.planSyncId)
        return mergedPlans.map { plan in
            PlanData(plan: plan, items: grouped[plan.syncId] ?? [])
        }
    }

    // MARK: - Generic entities

    private static func mergeSubjects(
        base: [Subject],
        local: [Subject],
        remote: [Subject],
        conflicts: inout [SyncConflict],
        now: Int64
    ) -> [Subject] {
        mergeEntities(base: base, local: local, remote: remote, kind: .subject, title: { $0.name }, conflicts: &conflicts, now: now) { $0.syncId }
    }

    private static func mergeEntities<T: Codable & SyncDeltaEntity>(
        base: [T],
        local: [T],
        remote: [T],
        kind: SyncEntityKind,
        title: (T) -> String,
        conflicts: inout [SyncConflict],
        now: Int64,
        key: (T) -> String
    ) -> [T] {
        let baseMap = Dictionary(uniqueKeysWithValues: base.map { (key($0), $0) })
        let localMap = Dictionary(uniqueKeysWithValues: local.map { (key($0), $0) })
        let remoteMap = Dictionary(uniqueKeysWithValues: remote.map { (key($0), $0) })
        let ids = Set(baseMap.keys).union(localMap.keys).union(remoteMap.keys)

        return ids.compactMap { syncId -> T? in
            guard let localValue = localMap[syncId], let remoteValue = remoteMap[syncId] else {
                return localMap[syncId] ?? remoteMap[syncId]
            }
            if let deleteConflict = deletionConflict(base: baseMap[syncId], localDeleted: localValue.deletedAt, remoteDeleted: remoteValue.deletedAt, local: localValue, remote: remoteValue, kind: kind, title: title(localValue), now: now) {
                conflicts.append(deleteConflict)
                return localValue.deletedAt == nil ? localValue : remoteValue
            }
            if let baseValue = baseMap[syncId],
               jsonHash(localValue) != jsonHash(baseValue),
               jsonHash(remoteValue) != jsonHash(baseValue),
               jsonHash(localValue) != jsonHash(remoteValue) {
                let merged = pickNewer(local: localValue, remote: remoteValue)
                conflicts.append(makeConflict(
                    kind: kind,
                    entity: merged,
                    local: localValue,
                    remote: remoteValue,
                    base: baseValue,
                    fields: [.other],
                    summary: "「\(title(localValue))」が端末間で異なります",
                    now: now
                ))
                return localValue
            }
            return SyncMergeEngine.merge([localValue], [remoteValue], key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt).first ?? localValue
        }
    }

    // MARK: - Helpers

    private static func pickNewer<T: SyncDeltaEntity>(local: T, remote: T) -> T {
        if let localDelete = local.deletedAt, let remoteDelete = remote.deletedAt {
            return localDelete >= remoteDelete ? local : remote
        }
        return local.updatedAt >= remote.updatedAt ? local : remote
    }

    private static func scalarConflict(base: String, local: String, remote: String) -> Bool {
        local != base && remote != base && local != remote
    }

    private static func unionProblemRecords(
        base: [ProblemSessionRecord],
        local: [ProblemSessionRecord],
        remote: [ProblemSessionRecord]
    ) -> [ProblemSessionRecord] {
        var map: [String: ProblemSessionRecord] = [:]
        for record in base + local + remote {
            map[record.stableKey] = record
        }
        return map.values.sorted { $0.number < $1.number }
    }

    private static func unionChapters(
        base: [ProblemChapter],
        local: [ProblemChapter],
        remote: [ProblemChapter]
    ) -> [ProblemChapter] {
        var map: [String: ProblemChapter] = [:]
        for chapter in base + local + remote {
            map[chapter.id] = chapter
        }
        return Array(map.values)
    }

    private static func maxOptional(_ values: Int?...) -> Int? {
        values.compactMap { $0 }.max()
    }

    private static func deletionConflict<T: Codable & SyncDeltaEntity>(
        base: T?,
        localDeleted: Int64?,
        remoteDeleted: Int64?,
        local: T,
        remote: T,
        kind: SyncEntityKind,
        title: String,
        now: Int64
    ) -> SyncConflict? {
        let localAlive = localDeleted == nil
        let remoteAlive = remoteDeleted == nil
        guard localAlive != remoteAlive else { return nil }
        guard let base else { return nil }
        let aliveSideChanged: Bool
        if localAlive {
            aliveSideChanged = local.updatedAt != base.updatedAt
        } else {
            aliveSideChanged = remote.updatedAt != base.updatedAt
        }
        guard aliveSideChanged else { return nil }
        return makeConflict(
            kind: kind,
            entity: localAlive ? local : remote,
            local: local,
            remote: remote,
            base: base,
            fields: [.deletion],
            summary: "「\(title)」の削除が端末間で競合しています",
            now: now
        )
    }

    private static func makeConflict<T: Encodable & SyncDeltaEntity>(
        kind: SyncEntityKind,
        entity: T,
        local: T,
        remote: T,
        base: T?,
        fields: [SyncConflictField],
        summary: String,
        now: Int64
    ) -> SyncConflict {
        let localJson = encode(local)
        let remoteJson = encode(remote)
        return SyncConflict(
            kind: kind,
            syncId: local.syncId,
            title: summary,
            summary: summary,
            conflictFields: fields,
            baseJson: base.map(encode),
            localJson: localJson,
            remoteJson: remoteJson,
            suggestedMergedJson: encode(entity),
            detectedAt: now
        )
    }

    private static func encode<T: Encodable>(_ value: T) -> String {
        guard let data = try? JSONEncoder().encode(value) else { return "{}" }
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func jsonHash<T: Encodable>(_ value: T) -> String {
        let digest = SHA256.hash(data: normalizedJSONData(value))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func normalizedJSONData<T: Encodable>(_ value: T) -> Data {
        guard
            let data = try? JSONEncoder().encode(value),
            let object = try? JSONSerialization.jsonObject(with: data)
        else {
            return Data(encode(value).utf8)
        }
        let normalized = normalizeJSONObject(object)
        guard JSONSerialization.isValidJSONObject(normalized),
              let normalizedData = try? JSONSerialization.data(withJSONObject: normalized, options: [.sortedKeys]) else {
            return data
        }
        return normalizedData
    }

    private static func normalizeJSONObject(_ value: Any) -> Any {
        if let dictionary = value as? [String: Any] {
            return dictionary
                .filter { !localOnlyJSONKeys.contains($0.key) }
                .mapValues(normalizeJSONObject)
        }
        if let array = value as? [Any] {
            return array.map(normalizeJSONObject)
        }
        return value
    }

    private static let localOnlyJSONKeys: Set<String> = [
        "id",
        "planId",
        "subjectId",
        "materialId",
        "sessionId",
        "lastSyncedAt"
    ]

    private static func replaceEntity(in appData: AppData, kind: SyncEntityKind, syncId: String, json: String) -> AppData {
        var copy = appData
        let data = Data(json.utf8)
        let decoder = JSONDecoder()
        switch kind {
        case .subject:
            if let value = try? decoder.decode(Subject.self, from: data) {
                copy.subjects = replace(in: copy.subjects, syncId: syncId, with: value)
            }
        case .material:
            if let value = try? decoder.decode(Material.self, from: data) {
                copy.materials = replace(in: copy.materials, syncId: syncId, with: value)
            }
        case .session:
            if let value = try? decoder.decode(StudySession.self, from: data) {
                copy.sessions = replace(in: copy.sessions, syncId: syncId, with: value)
            }
        case .goal:
            if let value = try? decoder.decode(Goal.self, from: data) {
                copy.goals = replace(in: copy.goals, syncId: syncId, with: value)
            }
        case .exam:
            if let value = try? decoder.decode(Exam.self, from: data) {
                copy.exams = replace(in: copy.exams, syncId: syncId, with: value)
            }
        case .plan:
            if let value = try? decoder.decode(StudyPlan.self, from: data) {
                copy.plans = copy.plans.map { planData in
                    guard planData.plan.syncId == syncId else { return planData }
                    return PlanData(plan: value, items: planData.items)
                }
            }
        case .planItem:
            if let value = try? decoder.decode(PlanItem.self, from: data) {
                copy.plans = replacePlanItem(in: copy.plans, syncId: syncId, with: value)
            }
        case .timetablePeriod:
            if let value = try? decoder.decode(TimetablePeriod.self, from: data) {
                copy.timetablePeriods = replace(in: copy.timetablePeriods, syncId: syncId, with: value)
            }
        case .timetableEntry:
            if let value = try? decoder.decode(TimetableEntry.self, from: data) {
                copy.timetableEntries = replace(in: copy.timetableEntries, syncId: syncId, with: value)
            }
        case .timetableTerm:
            if let value = try? decoder.decode(TimetableTerm.self, from: data) {
                copy.timetableTerms = replace(in: copy.timetableTerms, syncId: syncId, with: value)
            }
        case .timetableReviewRecord:
            if let value = try? decoder.decode(TimetableReviewRecord.self, from: data) {
                copy.timetableReviewRecords = replace(in: copy.timetableReviewRecords, syncId: syncId, with: value)
            }
        case .problemReviewRecord:
            if let value = try? decoder.decode(ProblemReviewRecord.self, from: data) {
                copy.problemReviewRecords = replace(in: copy.problemReviewRecords, syncId: syncId, with: value)
            }
        }
        return copy
    }

    private static func replace<T>(in values: [T], syncId: String, with value: T) -> [T] where T: SyncDeltaEntity {
        var result = values
        if let index = result.firstIndex(where: { $0.syncId == syncId }) {
            result[index] = value
        } else {
            result.append(value)
        }
        return result
    }

    private static func replacePlanItem(in plans: [PlanData], syncId: String, with value: PlanItem) -> [PlanData] {
        let existingOwner = plans.first { planData in
            planData.items.contains { $0.syncId == syncId }
        }?.plan.syncId
        let targetPlanSyncId = value.planSyncId ?? existingOwner
        return plans.map { planData in
            let withoutDuplicate = planData.items.filter { $0.syncId != syncId }
            guard planData.plan.syncId == targetPlanSyncId else {
                return PlanData(plan: planData.plan, items: withoutDuplicate)
            }
            var item = value
            item.planSyncId = targetPlanSyncId
            return PlanData(plan: planData.plan, items: withoutDuplicate + [item])
        }
    }

    private static func jsonWithUpdatedAt(_ json: String, _ updatedAt: Int64) -> String {
        guard
            let data = json.data(using: .utf8),
            var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return json
        }
        object["updatedAt"] = updatedAt
        guard
            JSONSerialization.isValidJSONObject(object),
            let encoded = try? JSONSerialization.data(withJSONObject: object),
            let string = String(data: encoded, encoding: .utf8)
        else {
            return json
        }
        return string
    }
}
