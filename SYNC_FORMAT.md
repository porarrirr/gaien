# StudyApp Sync Format

This document is the Android/iOS contract for Firestore sync data. Changes to
this format require coordinated implementation and tests on both platforms.

## Current Generation

Generation 3 stores one document per entity under:

`users/<uid>/sync_entities/<kind>-<syncId>`

The format is frozen for the data-layer migration described in
`DATA_LAYER_PLAN.md`.

## Envelope

Each document contains:

| Field | Type | Meaning |
|---|---|---|
| `kind` | string | Stable entity kind listed below |
| `syncId` | string | Stable cross-device entity identity |
| `updatedAt` | integer | Client epoch milliseconds used for merge ordering |
| `deletedAt` | integer or null | Tombstone timestamp |
| `serverUpdatedAt` | Firestore timestamp | Server write timestamp |
| `json` | string | Codable/JSON entity payload |
| `revisionId` | string, optional | Current revision identifier |
| `parentRevisionId` | string, optional | Previous revision identifier |
| `deviceId` | string, optional | Anonymous installation identifier |
| `contentHash` | string, optional | Payload integrity/revision hash |

Stable kinds:

`subject`, `material`, `session`, `goal`, `exam`, `plan`, `planItem`,
`timetablePeriod`, `timetableEntry`, `timetableTerm`,
`timetableReviewRecord`, `problemReviewRecord`.

Renaming or removing a kind is a breaking change.

## Local Apply Rollout

iOS applies merged snapshots with syncId upserts. The former full-replace and
shadow-comparison path has been removed so a sync cannot replace unrelated
local edits made while the merge was being prepared.

## Cursor

Clients persist two independent positions:

1. A Firestore fetch cursor: `serverUpdatedAt` plus `documentId`.
2. A legacy client cursor retained for local state compatibility.

Only the server cursor controls remote fetches. Entity `updatedAt` remains a
client timestamp used for merge ordering and never advances the fetch cursor.
Uploads are selected by comparing the current local snapshot with the saved
base shadow, so a clock-skewed remote entity cannot suppress later local
edits.

Clients migrating from the old `updatedAt` fetch cursor reset the server
cursor once, perform a full fetch, and persist a migration flag. A missing
base shadow or revision map still resets the associated local sync state.

## Deletion

Deletion is logical. Clients write `deletedAt` and keep the entity payload so
offline devices can receive the tombstone. Server cleanup must retain
tombstones for at least 90 days.

## Payload Versions

- Local Core Data store: `dataSchemaVersion` in persistent-store metadata.
- Export/snapshot JSON: `AppData.schemaVersion` (currently 2).
- Firestore collection generation: currently 3.

These version axes are independent. Export JSON is upgraded step by step by
the client before decoding. New fields must be additive and optional/defaulted.

## Legacy Generations

- Generation 1: `users/<uid>/sync/default.payload`
- Generation 2: `users/<uid>/sync/default` manifest plus `chunks`

iOS records legacy migration and fallback usage in `users/<uid>.clientFlags`.
Run `node tools/audit_legacy_sync.mjs` with read-only Firestore credentials to
measure remaining generation 1/2 users before deleting compatibility code.
