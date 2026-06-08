import Foundation

/// Identifies which domain entity an envelope carries. Stable rawValues are
/// used as part of the Firestore document ID, so renaming or removing cases
/// is a breaking change.
enum SyncEntityKind: String, Codable, CaseIterable {
    case subject
    case material
    case session
    case goal
    case exam
    case plan
    case planItem
    case timetablePeriod
    case timetableEntry
    case timetableTerm
    case timetableReviewRecord
    case problemReviewRecord
}

/// A single entity, encoded and paired with the metadata we need for
/// incremental sync (conflict resolution, tombstone propagation, delta cursor).
///
/// The envelope carries the entity as JSON rather than as a `Codable`
/// existential so the storage backend (Firestore, tests, local caches) can
/// persist it verbatim without needing the domain types.
struct SyncEntityEnvelope: Equatable {
    var kind: SyncEntityKind
    /// The entity's stable `syncId` (matches `Subject.syncId`, `Material.syncId`, etc.).
    var syncId: String
    /// Client-side last-modified timestamp. Authoritative for merge ordering.
    var updatedAt: Int64
    /// Tombstone timestamp when the entity is logically deleted.
    var deletedAt: Int64?
    /// The entity encoded as JSON using the domain type's `Codable` conformance.
    var json: String
    /// Optional revision metadata (ignored by legacy clients/readers).
    var revisionId: String?
    var parentRevisionId: String?
    var deviceId: String?
    var contentHash: String?

    /// Stable document id used by the Firestore delta store. The leading kind
    /// keeps ids unique across domain types even if syncIds collide (they
    /// shouldn't, but belt-and-braces).
    var documentId: String {
        "\(kind.rawValue)-\(syncId)"
    }
}

/// Pure serializer / reassembler between `AppData` and a bag of
/// `SyncEntityEnvelope`s. Swapping the Firestore layer for any other
/// delta-capable store is a matter of writing/reading envelopes.
///
/// Design notes:
/// * `decompose` emits one envelope per entity (including tombstones). Plans
///   and their items are emitted as separate kinds so each has its own
///   `updatedAt` and can sync independently.
/// * `assemble` rebuilds a full `AppData` by merging the envelopes *onto*
///   a base snapshot using `SyncMergeEngine`, so last-writer-wins with
///   tombstone precedence is preserved.
/// * `changedSince` is the primary upload primitive: hand it the local
///   `AppData` and the cursor from the previous successful sync, and it
///   returns exactly the envelopes that need to be pushed.
enum SyncDeltaSerializer {

    // MARK: - Decomposition (AppData -> envelopes)

    static func decompose(_ appData: AppData) -> [SyncEntityEnvelope] {
        var envelopes: [SyncEntityEnvelope] = []
        envelopes.reserveCapacity(estimatedEnvelopeCount(for: appData))

        for value in appData.subjects {
            envelopes.append(envelope(for: value, kind: .subject))
        }
        for value in appData.materials {
            envelopes.append(envelope(for: value, kind: .material))
        }
        for value in appData.sessions {
            envelopes.append(envelope(for: value, kind: .session))
        }
        for value in appData.goals {
            envelopes.append(envelope(for: value, kind: .goal))
        }
        for value in appData.exams {
            envelopes.append(envelope(for: value, kind: .exam))
        }
        for planData in appData.plans {
            envelopes.append(envelope(for: planData.plan, kind: .plan))
            for item in planData.items {
                envelopes.append(envelope(for: item, kind: .planItem))
            }
        }
        for value in appData.timetablePeriods {
            envelopes.append(envelope(for: value, kind: .timetablePeriod))
        }
        for value in appData.timetableEntries {
            envelopes.append(envelope(for: value, kind: .timetableEntry))
        }
        for value in appData.timetableTerms {
            envelopes.append(envelope(for: value, kind: .timetableTerm))
        }
        for value in appData.timetableReviewRecords {
            envelopes.append(envelope(for: value, kind: .timetableReviewRecord))
        }
        for value in appData.problemReviewRecords {
            envelopes.append(envelope(for: value, kind: .problemReviewRecord))
        }
        return envelopes
    }

    /// Same as `decompose`, but filtered to only entities after the composite cursor.
    static func changedSince(_ appData: AppData, cursor: SyncDeltaCursor) -> [SyncEntityEnvelope] {
        decompose(appData).filter { $0.cursorPosition > cursor }
    }

    /// Legacy Int64 cursor support.
    static func changedSince(_ appData: AppData, cursor: Int64) -> [SyncEntityEnvelope] {
        changedSince(appData, cursor: SyncDeltaCursor.fromLegacy(cursor))
    }

    // MARK: - Reassembly (envelopes + base -> AppData)

    /// Merges the given envelopes onto `base` using `SyncMergeEngine`
    /// semantics (last-writer-wins with tombstone precedence and
    /// problem-progress preservation).
    ///
    /// Envelopes that fail to decode are skipped; we log via the caller
    /// rather than `fatalError` so a single bad document does not prevent
    /// the rest of the sync from applying.
    static func assemble(envelopes: [SyncEntityEnvelope], onto base: AppData) -> AppData {
        let partial = partialAppData(from: envelopes, exportDate: base.exportDate)
        return SyncMergeEngine.merge(local: base, remote: partial)
    }

    // MARK: - Private

    private static func estimatedEnvelopeCount(for appData: AppData) -> Int {
        appData.subjects.count
            + appData.materials.count
            + appData.sessions.count
            + appData.goals.count
            + appData.exams.count
            + appData.plans.count
            + appData.plans.reduce(0) { $0 + $1.items.count }
            + appData.timetablePeriods.count
            + appData.timetableEntries.count
            + appData.timetableTerms.count
            + appData.timetableReviewRecords.count
            + appData.problemReviewRecords.count
    }

    /// Packs a single `Encodable` domain entity (including its `updatedAt`
    /// and `deletedAt`) into an envelope. JSON encoding is expected to
    /// succeed for the project's own Codable types; a failure returns a
    /// defensively-empty envelope rather than throwing, which keeps
    /// decompose infallible.
    private static func envelope<T: SyncDeltaEntity>(for entity: T, kind: SyncEntityKind) -> SyncEntityEnvelope {
        let json = (try? encodeToString(entity)) ?? "{}"
        return SyncEntityEnvelope(
            kind: kind,
            syncId: entity.syncId,
            updatedAt: entity.updatedAt,
            deletedAt: entity.deletedAt,
            json: json
        )
    }

    private static func encodeToString<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }

    private static func decodeFromString<T: Decodable>(_ string: String, as: T.Type) throws -> T {
        let data = Data(string.utf8)
        return try JSONDecoder().decode(T.self, from: data)
    }

    /// Rebuilds the subset of `AppData` that the envelopes describe.
    /// The resulting `AppData` is suitable as the `remote` argument to
    /// `SyncMergeEngine.merge`. Unknown kinds are skipped.
    static func partialAppData(
        from envelopes: [SyncEntityEnvelope],
        exportDate: Int64
    ) -> AppData {
        var subjects: [Subject] = []
        var materials: [Material] = []
        var sessions: [StudySession] = []
        var goals: [Goal] = []
        var exams: [Exam] = []
        var plans: [StudyPlan] = []
        var planItems: [PlanItem] = []
        var timetablePeriods: [TimetablePeriod] = []
        var timetableEntries: [TimetableEntry] = []
        var timetableTerms: [TimetableTerm] = []
        var timetableReviewRecords: [TimetableReviewRecord] = []
        var problemReviewRecords: [ProblemReviewRecord] = []

        for envelope in envelopes {
            switch envelope.kind {
            case .subject:
                if let value = try? decodeFromString(envelope.json, as: Subject.self) {
                    subjects.append(value)
                }
            case .material:
                if let value = try? decodeFromString(envelope.json, as: Material.self) {
                    materials.append(value)
                }
            case .session:
                if let value = try? decodeFromString(envelope.json, as: StudySession.self) {
                    sessions.append(value)
                }
            case .goal:
                if let value = try? decodeFromString(envelope.json, as: Goal.self) {
                    goals.append(value)
                }
            case .exam:
                if let value = try? decodeFromString(envelope.json, as: Exam.self) {
                    exams.append(value)
                }
            case .plan:
                if let value = try? decodeFromString(envelope.json, as: StudyPlan.self) {
                    plans.append(value)
                }
            case .planItem:
                if let value = try? decodeFromString(envelope.json, as: PlanItem.self) {
                    planItems.append(value)
                }
            case .timetablePeriod:
                if let value = try? decodeFromString(envelope.json, as: TimetablePeriod.self) {
                    timetablePeriods.append(value)
                }
            case .timetableEntry:
                if let value = try? decodeFromString(envelope.json, as: TimetableEntry.self) {
                    timetableEntries.append(value)
                }
            case .timetableTerm:
                if let value = try? decodeFromString(envelope.json, as: TimetableTerm.self) {
                    timetableTerms.append(value)
                }
            case .timetableReviewRecord:
                if let value = try? decodeFromString(envelope.json, as: TimetableReviewRecord.self) {
                    timetableReviewRecords.append(value)
                }
            case .problemReviewRecord:
                if let value = try? decodeFromString(envelope.json, as: ProblemReviewRecord.self) {
                    problemReviewRecords.append(value)
                }
            }
        }

        // Rebuild plans as [PlanData] by grouping plan items under their plan's syncId.
        let itemsByPlanSyncId = Dictionary(grouping: planItems, by: \.planSyncId)
        let planData: [PlanData] = plans.map { plan in
            let items = (itemsByPlanSyncId[plan.syncId] ?? [])
            return PlanData(plan: plan, items: items)
        }

        return AppData(
            subjects: subjects,
            materials: materials,
            sessions: sessions,
            goals: goals,
            exams: exams,
            plans: planData,
            timetablePeriods: timetablePeriods,
            timetableEntries: timetableEntries,
            timetableTerms: timetableTerms,
            timetableReviewRecords: timetableReviewRecords,
            problemReviewRecords: problemReviewRecords,
            exportDate: exportDate
        )
    }
}

/// Internal conformance used by `SyncDeltaSerializer.envelope(for:kind:)` so
/// we can encode any of the domain entities through a single code path. All
/// participating types already declare `syncId`, `updatedAt`, and `deletedAt`;
/// this protocol just gives the compiler a uniform handle.
protocol SyncDeltaEntity: Encodable {
    var syncId: String { get }
    var updatedAt: Int64 { get }
    var deletedAt: Int64? { get }
}

extension Subject: SyncDeltaEntity {}
extension Material: SyncDeltaEntity {}
extension StudySession: SyncDeltaEntity {}
extension Goal: SyncDeltaEntity {}
extension Exam: SyncDeltaEntity {}
extension StudyPlan: SyncDeltaEntity {}
extension PlanItem: SyncDeltaEntity {}
extension TimetablePeriod: SyncDeltaEntity {}
extension TimetableEntry: SyncDeltaEntity {}
extension TimetableTerm: SyncDeltaEntity {}
extension TimetableReviewRecord: SyncDeltaEntity {}
extension ProblemReviewRecord: SyncDeltaEntity {}
