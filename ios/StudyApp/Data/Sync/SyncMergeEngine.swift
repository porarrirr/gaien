import Foundation

/// Pure merge/transform logic previously living inside
/// `FirebaseSyncRepository`. Isolated here so the rules (last-writer-wins with
/// tombstone awareness, problem-progress preservation, `lastSyncedAt` stamping)
/// can be unit-tested without Firebase or the persistence stack.
///
/// Conflict resolution summary:
/// * A tombstone (`deletedAt`) older than the other side's `updatedAt`
///   can still win if it is newer than the opposite side's deletion.
/// * Otherwise the side with the greater `updatedAt` wins.
/// * When two records disagree on which has problem progress, `enrich`
///   keeps problem chapters/records/totals from whichever side still has
///   them (never downgrades non-deleted data).
enum SyncMergeEngine {

    // MARK: - Top-level

    static func merge(local: AppData, remote: AppData) -> AppData {
        AppData(
            schemaVersion: max(local.schemaVersion, remote.schemaVersion),
            supportsProblemRecords: local.supportsProblemRecords || remote.supportsProblemRecords,
            subjects: merge(local.subjects, remote.subjects, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            materials: mergeMaterials(local.materials, remote.materials),
            sessions: mergeSessions(local.sessions, remote.sessions),
            goals: merge(local.goals, remote.goals, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            exams: merge(local.exams, remote.exams, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            plans: mergePlans(local.plans, remote.plans),
            timetablePeriods: merge(local.timetablePeriods, remote.timetablePeriods, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            timetableEntries: merge(local.timetableEntries, remote.timetableEntries, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            timetableTerms: merge(local.timetableTerms, remote.timetableTerms, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            timetableReviewRecords: merge(local.timetableReviewRecords, remote.timetableReviewRecords, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            problemReviewRecords: merge(local.problemReviewRecords, remote.problemReviewRecords, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt),
            exportDate: max(local.exportDate, remote.exportDate)
        )
    }

    // MARK: - Type-specific merges

    static func mergeMaterials(_ local: [Material], _ remote: [Material]) -> [Material] {
        merge(local, remote, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt) { selected, other in
            guard selected.deletedAt == nil else { return selected }
            var enriched = selected
            if enriched.problemChapters.isEmpty, !other.problemChapters.isEmpty {
                enriched.problemChapters = other.problemChapters
            }
            if enriched.problemRecords.isEmpty, !other.problemRecords.isEmpty {
                enriched.problemRecords = other.problemRecords
            }
            if enriched.totalProblems == 0, other.totalProblems > 0 {
                enriched.totalProblems = other.totalProblems
            }
            return enriched
        }
    }

    static func mergeSessions(_ local: [StudySession], _ remote: [StudySession]) -> [StudySession] {
        merge(local, remote, key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt) { selected, other in
            guard selected.deletedAt == nil else { return selected }
            var enriched = selected
            if enriched.problemRecords.isEmpty, !other.problemRecords.isEmpty {
                enriched.problemRecords = other.problemRecords
            }
            if enriched.problemStart == nil {
                enriched.problemStart = other.problemStart
            }
            if enriched.problemEnd == nil {
                enriched.problemEnd = other.problemEnd
            }
            if enriched.wrongProblemCount == nil {
                enriched.wrongProblemCount = other.wrongProblemCount
            }
            return enriched
        }
    }

    static func mergePlans(_ local: [PlanData], _ remote: [PlanData]) -> [PlanData] {
        let plans = merge(local.map(\.plan), remote.map(\.plan), key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt)
        let items = merge(local.flatMap(\.items), remote.flatMap(\.items), key: \.syncId, updatedAt: \.updatedAt, deletedAt: \.deletedAt)
        let grouped = Dictionary(grouping: items, by: \.planSyncId)
        return plans.map { plan in
            PlanData(plan: plan, items: grouped[plan.syncId] ?? [])
        }
    }

    // MARK: - Generic merge

    static func merge<T>(
        _ lhs: [T],
        _ rhs: [T],
        key: KeyPath<T, String>,
        updatedAt: KeyPath<T, Int64>,
        deletedAt: KeyPath<T, Int64?>
    ) -> [T] {
        merge(lhs, rhs, key: key, updatedAt: updatedAt, deletedAt: deletedAt) { selected, _ in selected }
    }

    static func merge<T>(
        _ lhs: [T],
        _ rhs: [T],
        key: KeyPath<T, String>,
        updatedAt: KeyPath<T, Int64>,
        deletedAt: KeyPath<T, Int64?>,
        preservingDetails enrich: (T, T) -> T
    ) -> [T] {
        var result: [String: T] = [:]
        result.reserveCapacity(lhs.count + rhs.count)
        for item in lhs + rhs {
            let id = item[keyPath: key]
            guard let existing = result[id] else {
                result[id] = item
                continue
            }
            let existingDelete = existing[keyPath: deletedAt] ?? .min
            let candidateDelete = item[keyPath: deletedAt] ?? .min
            if candidateDelete > existing[keyPath: updatedAt] && candidateDelete >= existingDelete {
                result[id] = item
            } else if existingDelete > item[keyPath: updatedAt] && existingDelete >= candidateDelete {
                result[id] = existing
            } else if item[keyPath: updatedAt] >= existing[keyPath: updatedAt] {
                result[id] = enrich(item, existing)
            } else {
                result[id] = enrich(existing, item)
            }
        }
        return Array(result.values)
    }

    // MARK: - Post-merge stamping

    /// Returns a copy of `appData` where every entity's `lastSyncedAt` is set
    /// to `timestamp` and `exportDate` is refreshed. Used right before we
    /// upload to Firestore so each record locally reflects when it was last
    /// synced.
    static func markSynced(_ appData: AppData, at timestamp: Int64) -> AppData {
        AppData(
            schemaVersion: appData.schemaVersion,
            supportsProblemRecords: appData.supportsProblemRecords,
            subjects: appData.subjects.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            materials: appData.materials.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            sessions: appData.sessions.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            goals: appData.goals.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            exams: appData.exams.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            plans: appData.plans.map { planData in
                var plan = planData.plan
                plan.lastSyncedAt = timestamp
                let items = planData.items.map { item -> PlanItem in
                    var value = item
                    value.lastSyncedAt = timestamp
                    return value
                }
                return PlanData(plan: plan, items: items)
            },
            timetablePeriods: appData.timetablePeriods.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            timetableEntries: appData.timetableEntries.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            timetableTerms: appData.timetableTerms.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            timetableReviewRecords: appData.timetableReviewRecords.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            problemReviewRecords: appData.problemReviewRecords.map { var value = $0; value.lastSyncedAt = timestamp; return value },
            exportDate: timestamp
        )
    }
}

/// Pre-upload check: detects if a sync operation is about to drop meaningful
/// problem progress. This guard previously lived inline inside
/// `FirebaseSyncRepository.syncNow()`; extracting lets tests assert the
/// safety check without any Firestore dependency.
struct SyncProgressGuard {
    struct Summary: Equatable {
        var sessionProblemRecords: Int
        var materialProblemRecords: Int
        var materialsWithProblemTotals: Int
        var activeProblemReviewRecords: Int

        var hasProblemProgress: Bool {
            sessionProblemRecords > 0 ||
            materialProblemRecords > 0 ||
            activeProblemReviewRecords > 0 ||
            materialsWithProblemTotals > 0
        }

        init(appData: AppData) {
            sessionProblemRecords = appData.sessions.reduce(0) { $0 + $1.problemRecords.count }
            materialProblemRecords = appData.materials.reduce(0) { $0 + $1.problemRecords.count }
            materialsWithProblemTotals = appData.materials.filter { $0.effectiveTotalProblems > 0 }.count
            activeProblemReviewRecords = appData.problemReviewRecords.filter { $0.deletedAt == nil }.count
        }
    }

    /// Returns true when `destination` drops problem-progress data that
    /// `source` still has, which is the condition the sync path must abort on.
    static func wouldLoseProgress(from source: AppData, to destination: AppData) -> Bool {
        let before = Summary(appData: source)
        let after = Summary(appData: destination)
        guard before.hasProblemProgress else { return false }

        return after.sessionProblemRecords < before.sessionProblemRecords
            || after.materialProblemRecords < before.materialProblemRecords
            || after.activeProblemReviewRecords < before.activeProblemReviewRecords
            || after.materialsWithProblemTotals < before.materialsWithProblemTotals
    }
}
