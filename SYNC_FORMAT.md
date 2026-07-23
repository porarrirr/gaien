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
| `deletedAt` | integer or null | Tombstone timestamp. **The key must always be present** (write `null` for live entities): `firestore.rules` validates the field on every write |
| `serverUpdatedAt` | Firestore timestamp | Server write timestamp |
| `json` | string | Codable/JSON entity payload (≤ 900,000 bytes; validated client-side before upload) |
| `revisionId` | string, optional | Current revision identifier |
| `parentRevisionId` | string, optional | Previous revision identifier |
| `deviceId` | string, optional | Anonymous installation identifier |
| `contentHash` | string, optional | Payload integrity/revision hash |

`updatedAt` / `deletedAt` must be within `0..4102444800000` (year 2100).
Clients validate size and timestamps before upload so a rules rejection is
reported as a specific error instead of a generic permission failure.

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

## Three-way merge contract

Both platforms must resolve a concurrent per-entity merge identically:

1. If exactly one side (local/remote) differs from the base shadow, adopt the
   changed side unconditionally. Client-clock `updatedAt` comparison is only a
   tie-breaker when **both** sides changed — otherwise a device with a slow
   clock silently loses its edits (and deletions) forever, because the fetch
   cursor has already advanced past the consumed envelope.
2. Change detection hashes the entity JSON after normalization: keys sorted,
   and the local-only keys `id`, `planId`, `subjectId`, `materialId`,
   `sessionId`, `lastSyncedAt` removed at every nesting level. Without this an
   upload that only re-stamps `lastSyncedAt` produces false conflicts.
3. Two tombstones for the same entity are never a conflict; the newer
   tombstone wins.

## Sync reset generation

`users/<uid>.syncGeneration` (string ≤ 128 chars, with server timestamp
`syncGenerationUpdatedAt`) marks the generation of the cloud dataset.
`deleteCloudDataForCurrentUser` writes a fresh random generation after
deleting all documents. Every sync compares the stored generation with the
cloud value:

- stored == remote → continue.
- stored missing → adopt the remote value (first contact).
- otherwise → the cloud was reset by another device: discard local sync state
  (cursors, base shadow, revision map) and perform a full resync. This
  prevents a device with a stale cursor from re-uploading only its diff and
  resurrecting a partial dataset.

## Import (upload local data)

`importLocalDataToCloud` mirrors the local dataset: it fetches **all** cloud
envelopes (not a cursor diff), uploads every local entity, and writes
tombstones (`updatedAt`/`deletedAt` set both in the envelope fields and inside
`json`) for live cloud entities that do not exist locally. The
progress-loss guard compares the full assembled cloud state against the
post-import state, where matching tombstones count as intentional deletions.

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
