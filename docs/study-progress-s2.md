# Swift S2: durable local study progress

S2 adds local persistence only. There are no callers in StudyFlashcardsView, no
progress uploads, no reset integration, and no timeline or notification changes.

## Files

Added:

- `Memora/Models/MemoraSchema.swift`: the exact app schema, shared with migration tests.
- `Memora/Models/PendingStudyProgress.swift`: durable draft/sealed entity and event values.
- `Memora/Services/Sync/StudyProgressStore.swift`: account-scoped local persistence API.
- `MemoraTests/PreS2Models.swift`: frozen pre-S2 definitions, test-only.
- `MemoraTests/StudyProgressPersistenceTests.swift`: temporary on-disk persistence/migration tests.
- This document.

Changed:

- `Memora/Models/StudyDeck.swift`: two optional epoch-cache fields.
- `Memora/MemoraApp.swift`: use the shared schema, now including pending progress.
- `Memora/Services/Auth/LocalAccountStore.swift`: document why pending operations
  must not be included in cache cleanup. Existing cleanup behavior already preserves
  unrelated entities, so its executable logic is unchanged.

AuthManager, SyncManager, study views, card statistics, and server-confirmed learned
indicators are unchanged. No `serverLearnedAt` field is introduced in S2.

## Exact persisted fields

StudyDeck additions:

| Field | Type | Meaning |
| --- | --- | --- |
| cachedProgressEpoch | UUID? | Backend epoch for this actual card-owning deck; nil is unknown |
| progressEpochFetchedAt | Date? | When the cached backend epoch was obtained; nil until cached |

The new PendingStudyProgress entity has these fields, all with private setters:

| Field | Type | Meaning |
| --- | --- | --- |
| id | UUID | Local batch identity, allocated at draft creation |
| accountID | UUID | Existing LocalAccountStore backend owner ID |
| createdAt | Date | Local creation time |
| stateRawValue | String | draft or sealed |
| eventsData | Data | Encoded array of stable-ID event values; initially empty |
| operationID | UUID? | Upload idempotency UUID, allocated once at sealing |
| payloadData | Data? | Exact sealed HTTP request JSON bytes |
| completedAt | Date? | Timestamp as encoded in that sealed request |

Each event stores `id`, `cardID`, `deckID`, `progressEpoch` (UUIDs), and `completedAt`
(Date). Events inherit the batch's immutable account ownership. They are values
inside one batch, not individual SwiftData rows. Local event encoding preserves
Date precision independently of APIJSON's wire timestamp encoding.

There are deliberately no relationships from pending work to decks/cards/profiles.
Deleting cache objects cannot cascade-delete these operations.

## Epochs and recording boundary

`cacheEpoch` accepts a supplied backend UUID and fetch date. It never fetches or
generates an epoch. Older fetch metadata cannot replace newer cached metadata.
Apply only a current backend progress snapshot, not an old submission/reset receipt.

`captureContext` returns an immutable value containing account ID, owning deck ID,
and optional epoch. It rejects parent decks with active children, and never looks
up a parent epoch as a fallback. A standalone deck can own an epoch. A missing
child epoch remains unknown even if the parent has a stored value.

An already-captured context never changes when the cache refreshes. Append requires
a known captured epoch; an unknown context throws `unknownEpoch`, even if an epoch
has since been fetched. It does not inspect current cache values to fill the gap.

## Draft and sealed lifecycle

1. Create a draft under the active account.
2. Append qualified event values using caller-provided, stable event IDs. Each
   append saves immediately. Identical repeated append to the same draft is a no-op;
   reuse of an ID with changed content or in another batch is rejected.
3. At a future upload boundary, seal using an explicitly chosen completion time.
   There is no default `.now` that could timestamp offline work at retry time.
4. Sealing groups by the captured owning deck/epoch, deduplicates card IDs for the
   backend request, allocates a fresh operation UUID, and saves exact payload bytes.
5. Retry loading returns those saved bytes and UUID. It does not rebuild the body
   from current models, epochs, or clocks. Appends and resealing are rejected.

Mixed epochs for one deck and conflicting card ownership cannot share a draft.
The helper enforces the request's 100-deck / 5000-unique-card limits. S4 must split
batches when necessary. The event list remains available after sealing for future
reconciliation; no reconciliation policy or automatic deletion is activated yet.

The backend has one completion timestamp per upload. S2 keeps all event times and
requires callers to supply the sealing timestamp rather than choosing the S4
batch attribution policy. Wire encoding currently normalizes to whole seconds;
the persisted sealed timestamp is decoded from those exact bytes. Event times
remain unchanged. S4 must avoid merging unrelated study days into a retry-time
timestamp and must send the stored body bytes without regenerating request content.

## Account and logout behavior

The helper binds to LocalAccountStore's owner and active session revision. All
reads/writes validate that binding. It has no public arbitrary-account lookup.
Returned snapshots are values, not mutable SwiftData objects. A stale helper cannot
read, create, append, cache an epoch, seal, or retrieve a payload after suspension
or account switching. Create a new helper after account activation.

| Scenario | Pending work |
| --- | --- |
| Normal logout | Preserved on disk; cached decks/cards/profile are cleared; helper access stops |
| Rejected refresh token | Same logout cleanup, so pending work survives; no new account is created |
| Same account returns | Its pending work is accessible after existing account activation |
| Another account signs in | Only that account's work is returned; previous work remains inaccessible through the helper |
| Cached deck/card deleted by sync | Stable IDs/events survive for later reconciliation |
| Authentication suspended | Pending work stays stored; the helper refuses access until activation |

The pending log is an account-owned operation store, not part of the single-account
content cache. No network authentication changes are made in S2. In particular,
the existing offline startup restoration can leave LocalAccountStore suspended;
S3 must explicitly handle that state before using the helper. Do not bypass it by
accepting an arbitrary account ID or treating another account's tokens as valid.

## Migration and persistence verification

The production configuration retains the same unversioned store and default URL.
The registered models are Item, StudyDeck, StudyFlashcardCard, LocalUserProfile,
and now PendingStudyProgress. The schema adds two optional attributes and an
independent entity. No database deletion, custom remapping, or migration fallback
is introduced.

The migration test creates a temporary SQLite-backed store with frozen pre-S2
definitions (including existing relationships and attributes), releases its
container, and opens the same URL with the exact S2 app schema. It checks:

- Parent/child relationships and stable IDs, deck settings and positions.
- Card content, image bytes, counters, interval, and review dates.
- Both session queues, completed counts, active flags, and batch ID arrays.
- Existing user profile and Item.
- New epoch fields remain nil and pending storage starts empty.
- The migrated store accepts new pending data and survives another reopening.

Other tests release/recreate containers to verify draft IDs/events and immutable
sealed payloads, as well as recreating just ModelContext. All stores are isolated
temporary test stores; no installed user's database is deleted. A URLProtocol spy
checks that local persistence operations initiate no HTTP requests.

Verified September 25, 2026: Xcode 16.2 compiled the app and all 36 MemoraTests
passed on iPhone 16 / iOS 18.3.1, including 16 new S2 persistence tests. The full
passing run includes the pre-S2 disk migration and no-HTTP checks. Physical iOS
17.6.1 installation/resume verification remains manual.

## Manual verification on the existing installation

1. Before installing S2, note a deck/chapter, several cards, and current study
   progress. Leave an unfinished normal session or Study All session saved.
2. Build/run S2 over the existing installation using the same bundle ID. Do not
   uninstall, delete app data, or invoke Reset Progress.
3. Confirm the same decks, cards, profile, and Continue studying/Continue Study All
   state remain. Resume and verify that the existing study flow behaves normally.
4. Exit the study session to save it, terminate the app, and relaunch. Confirm the
   deck data and saved session still remain.
5. Run StudyProgressPersistenceTests to exercise draft creation/sealing/reopening.
   These test-only fixtures create pending events; production Got It does not yet.

Repeat the installation/resume check on the physical iPhone running iOS 17.6.1.
The available simulator verifies iOS 18.3.1, not the physical-device OS.

## Decisions S3 must respect

- Qualify REVIEW plus Got It before changing the queues. The persistence API does
  not infer phase or qualification from card statistics or queue absence.
- Capture the owning deck's epoch before the operation and preserve it with resume
  state. Persisting session epoch bindings is S3 work; refreshing a cached epoch
  must not relabel earlier answers or an unknown-epoch operation.
- Keep a stable event ID/time across a failed local save and its retry.
- Unknown-epoch offline work cannot be retroactively credited. Local practice
  behavior and its user-facing explanation still belong to S3.
- The helper uses the supplied context's save/rollback. In S3, stage queue/statistic
  changes in that same context before append to commit them with the event; restore
  in-memory view state if saving fails. Do not add an intervening save that loses
  atomicity. Draft creation can happen before any qualifying transition.
- Known-epoch offline append needs no network, but account activation must already
  be established. Handle suspended offline restoration deliberately.
- Do not upload in S3. Sealing/retry/network boundaries remain S4 work.

S2 stops here.
