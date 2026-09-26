# Study Timeline integration: architecture and S1

S2 is now implemented separately; see [S2 persistence and migration handoff](study-progress-s2.md)
for the exact fields, account behavior, tests, and manual verification. The sections
below preserve the original S1 architecture map and later-phase boundaries.

Scope: API contracts first. No Timeline UI, notifications, new learning engine,
progress persistence, progress uploads, or backend reset calls are activated in S1.

Contracts were checked against the adjacent backend's `app/schemas/study_progress.py`,
`study_plan.py`, `exam.py`, corresponding routers/services, and the Phase 2D capture
pack in `docs/examples/phase-2d`. Copied test fixtures are disposable test-account
exchanges, not production data. Their scheduler clock is September 22, 2026;
creation/receipt timestamps use the capture clock. They have no API envelope.

## 1. File map

| Phase | File | Responsibility |
| --- | --- | --- |
| S1 | `Memora/Services/API/Models/StudyProgressModels.swift` (new) | Progress facts, aggregates, exact epochs, immutable submission/reset request and receipt DTOs |
| S1 | `Memora/Services/API/StudyProgressAPI.swift` (new) | GET progress, POST submissions, POST reset through APIClient |
| S1 | `Memora/Services/API/Models/StudyPlanModels.swift` (new) | Persistent plan create/read/recalculate contracts |
| S1 | `Memora/Services/API/StudyPlanAPI.swift` (new) | Plan GET, create, explicit recalculate; no automatic callers |
| S1 | `Memora/Services/API/Models/APICalendarDate.swift` (new) | Validated date-only value, independent of device timezone |
| S1 | `Memora/Services/API/APIJSON.swift` (new), `APIClient.swift` | Reuse existing JSON behavior with a testable codec; date-only values are not timestamp instants |
| S1 | `Memora/Services/API/APIError.swift` | Business codes, validation issue paths, legacy string errors, plain-text failure fallback |
| S1 | `Memora/Services/API/Models/ExamModels.swift`, `ExamAPI.swift` | Nullable milestone ID, availability/applicability/completion/chapter IDs; separate source-card endpoint |
| S1 | `Memora/Services/API/Models/CardModels.swift` | Legacy naive UTC timestamps, also supported specifically for exam completion timestamps |
| S1 | `Memora/Services/Sync/SyncManager.swift` | Existing HTTP-status handling recognizes structured errors without losing their code/message |
| S1 | `Memora/Views/Library/DeckDetailsView.swift` | Only exam compatibility: hide inapplicable milestones, enable using server availability |
| S1 | `MemoraTests/StudyAPIContractTests.swift`, `MemoraTests/Fixtures/Phase2D/` (new) | Backend fixture decoding, wire shapes, dates, errors, epoch and upload identity round trips |
| S2 | `Memora/Models/StudyDeck.swift` | Optional per-owning-deck cached epoch and fetch metadata; server-confirmed per-card learned cache if needed for indicators |
| S2 | Proposed `Memora/Models/PendingStudyProgress.swift`, `Memora/Services/Sync/StudyProgressStore.swift` | Durable draft/sealed upload batches, ownership, recovery state; narrow persistence helper |
| S2 | `Memora/MemoraApp.swift`, persistence test fixtures | Register new model and verify reopening an existing on-disk store |
| S2 | `Memora/Services/Auth/LocalAccountStore.swift`, `AuthManager.swift` | Account isolation and preservation of pending operations during authentication recovery |
| S3 | `Memora/Views/Library/StudyFlashcardsView.swift` | Small phase-aware capture hook and existing local save transaction |
| S4 | Proposed `Memora/Services/Sync/StudyProgressSync.swift`, `SyncManager.swift`, `AppSyncManager.swift` | Batch sealing, authenticated upload, retry/reconciliation, lifecycle flushing |
| S5 | `DeckDetailsView.swift`, progress persistence/sync helper | Online reset with durable reset operation and local reset recovery |
| S6 | `DeckDetailsView.swift`, `ExamTakingView.swift`, existing content mutation/sync paths | Refresh canonical progress, plan, and exam data after successful mutations |
| Later | `HomeView.swift`, `Views/NewStudyDeck/DeckReadyView.swift`, `ContentView.swift` | Selected progress display migration and plan-timezone day rollover hook |

Paths for future new files are proposals, not implemented files.

## 2. Required API models

Progress: response root, per-deck learning facts, card fact, summary, deck epoch,
qualified transition, deck transition group, immutable submission and receipt,
reset request and receipt. Epochs are UUIDs, and completion percentages are 0–100.

Plan: create request, response, chapter, item, item type/status/period/count-source
enums. Optional values follow the exact backend schema. `required_daily_card_count`
is an optional Int, `target_achievable` an optional Bool; zero and false remain
distinct from null. No preview-plan DTO is reused.

Errors: retain HTTP status plus arbitrary business code/message, or validation
issues with mixed string/integer locations. Unknown business codes survive decoding.
401 continues to use the existing unauthorized case. 500 remains a server failure.
S1 adds no automatic retry, reset, or account creation behavior.

## 3–4. SwiftData fields and epoch ownership (S2)

S1 changes no SwiftData models or container schema. The app currently has a single
unversioned container containing StudyDeck, StudyFlashcardCard, LocalUserProfile,
and Item. No explicit migration plan exists. The app deployment target is iOS 17.6;
the available test simulator is iOS 18.3.1.

In S2, add an optional cached epoch to each actual card-owning StudyDeck, not to
the parent as a substitute for child epochs. A nil epoch means unknown, not reset
and not a synthetic UUID. Capture a session's epoch separately from a refreshable
cache, including on resume: a mid-session fetch must not relabel earlier learning.
Existing active sessions without an epoch require an explicit initialization policy.

Per-card server-confirmed learnedAt can later be cached separately from review
counters. Pending local success must not be shown as server-confirmed achievement.
No backfill from correctCount or queue absence is valid.

Use additive optional/defaulted fields and a small new pending model. Verify an
on-disk upgrade, session resume, and kill/reopen persistence before activating S3.
Do not delete/recreate the user's database as a migration strategy.

## 5. Durable pending storage (S2)

Prefer one small draft batch containing qualifying event values over one database
row per answer. Persist each append immediately; it includes event identity, owner
account, exact card/owning-deck/epoch, and actual completion time. Seal a draft into
an immutable request before the first network attempt. Persist its operation UUID,
exact payload, and pending/reconciliation state. A new batch always gets a new UUID;
reset UUIDs share the backend receipt namespace.

Commit the event and changed session persistence together. Save failure must not
silently show completion while losing the event; restore prior in-memory state or
present a retryable persistence error. No network work occurs in this transaction.

The current logout path deletes cached decks/cards/profiles, including after rejected
refresh. Pending work must not cascade with that cache. Retain it with explicit
account ownership, only upload after the same account is validated, and never
allow another account to see or upload it. The existing LocalAccountStore revision
checks remain essential before applying async results.

## 6. Exact capture point (S3)

In `rateCard`, snapshot whether the card is in learningCards before the existing
transition. Only REVIEW plus the UI's `.good` action qualifies. NEW good and REVIEW
again do not qualify. Use the exact card's owning chapter ID, then persist alongside
the existing queue/count update. `handleLearningCardRating` remains responsible for
removal/requeue and completedCardCount; the study engine, four-card batches, and
single/combined resume behavior stay intact.

Known epoch while offline: persist qualified work with that epoch; server may later
reject it if another device reset. Unknown epoch on first offline study: allow local
practice with an explicit no-backend-credit indication, or require initial online
setup for credited study. Recommendation: local practice remains available, but do
not retroactively attach the next fetched epoch to those answers.

## 7. Study All and uploads (S4)

Group by actual owning deck and captured epoch. One request may include many deck
groups, with at most 100 distinct decks and 5000 cards total. Never merge different
epochs for one deck into one request. All retries use the same sealed payload/UUID.

Flush at four-card batch completion, exit, full completion, explicit sync and app
lifecycle. Keep pending-upload checks independent of AppSyncManager's 15-minute
content-sync throttle and first-install early return. Upload locally created
decks/cards first. Serialize progress/reset work per affected account/scope.

The API has one completed_at per upload, not per transition. Preserve event times
locally, and define batch completion attribution when sealing. Never combine old
offline days into an upload timestamped at retry time. Seal before crossing relevant
plan-local day boundaries; decide the timestamp policy explicitly in S4.

Network/500/auth errors retain pending work. Stale epoch and card_not_in_deck require
refetch and reconciliation; never relabel old events. Idempotency conflict stops
automatic retry for that operation. A receipt acknowledges an operation, but can
carry an old epoch after reset: it must not overwrite the current epoch cache.

## 8. Reset (S5)

Require connectivity. Read the current backend scope and epochs; persist reset_id
and expected_decks, pause uploads for that scope, then POST reset. On confirmed
success, reconcile pending old-epoch work and apply the existing local statistics/
session reset. Clear both normal and Study All batch IDs (normal batch IDs are
currently omitted by local reset). Persist enough reset state to complete local
clearing if the app dies after the server commits. A lost response retries the same
reset UUID/payload; it must not rotate epochs a second time. Refetch current progress
before applying an old replay as current truth. Refresh plan/exams afterward.

Backend reset preserves exam achievements. Parent reset scope excludes direct root
cards when children exist, matching the current local child-only reset scope.

## 9. Plan fetching/cache and progress display migration (S6/later)

Start with API DTOs in view state, loaded in tasks rather than body calculations.
No SwiftData plan cache is needed in S1. Later cache only if offline viewing or
notifications justify it; key by account/root/plan and accept newer server responses
without rewriting unchanged data. Never locally regenerate canonical plan items.

After accepted learning/reset/content mutations/exam milestones, refresh needed
progress, plan, and exam responses. Receipts do not contain updated aggregates or
plans. No redundant recalculate after those automatic backend hooks. For new-day
refresh, extend ContentView's existing scene-active path through AppSyncManager,
tracking calendar day per plan timezone, outside the 15-minute throttle.

Displays eventually needing canonical facts: DeckDetails mastered/learning summary,
percentage bar, child-row mastered count, individual card mastered badge, and
DeckReady's hard-coded 0% mastered. Home currently reports local new/due counts;
those can remain scheduling metrics, but future learned/chapter-completion UI must
use backend facts. Commented-out ParentDeckDetails/SubdeckDetails implementations
are not active migration targets. Keep session progress and Continue buttons local.

## 10. Exam compatibility (S1)

exam_id is optional; use exam type as stable list identity. Hide when applicable is
false; enable taking/retaking only from available. Do not infer availability from
status, chapter percentages, plan item dates, or a client prerequisite sequence.
No requirement for a non-null exam ID before generation: the generation endpoint
uses parent ID and exam type. Taking questions still uses a non-null generated ID.

Exam/card legacy timestamps accept naive UTC plus timezone-bearing ISO timestamps.
Progress/plan instants remain strict, and calendar dates stay YYYY-MM-DD values.
Exam submission is not idempotent; S1 does not add automatic retries to it.

## Verification boundaries

S1 tests decode captured progress, plans, receipts, exams, card timestamps and errors;
exercise nullable/zero fields, date-only validation, mixed validation paths,
qualified-transition wire literals, and immutable request identity/epoch round trips.
These are contract tests, not proof that app learning uploads, crash recovery,
server deduplication, or safe reset integration work. Those require S2–S6 and the
handoff's end-to-end checklist. The current study engine is not edited in S1.

Verified September 25, 2026 with Xcode 16.2: app/test compilation succeeded and
all 20 MemoraTests passed on iPhone 16 / iOS 18.3.1, including 12 new contract tests.
No iOS 17.6 physical-device run or live backend mutation was performed for S1.
