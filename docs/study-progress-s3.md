# Swift S3: local REVIEW success capture

S3 captures durable local events only. It does not fetch epochs, upload progress,
seal drafts, refresh plans/exams, integrate backend reset, or add timeline UI.

## Files

- Added `Memora/Services/StudySession.swift`: existing local queue/resume/selection
  rules extracted from StudyFlashcardsView, session bindings, and rating transaction.
- Changed `Memora/Views/Library/StudyFlashcardsView.swift`: use the local session
  helper; retain presentation/style; start on appearance; retryable save errors.
- Changed `Memora/Models/StudyDeck.swift`: two optional encoded session bindings.
- Changed `Memora/Services/Sync/StudyProgressStore.swift`: append a draft event and
  stage session changes within the same single-save transaction. A save closure
  permits deterministic persistence-failure tests; production uses ModelContext.save.
- Added `MemoraTests/StudySessionCaptureTests.swift`: production-engine capture,
  batch/resume, failure/retry, account, and disk persistence coverage.
- Updated `MemoraTests/StudyProgressPersistenceTests.swift`: migration checks also
  verify that both new session-binding fields default to nil.

The NEW/REVIEW transitions and SpacedRepetitionService formulas are unchanged.
Queue selection still prefers an eligible NEW card, then REVIEW, avoids the last
presented card when possible, and advances batches only when the current batch is
empty in both queues. Normal and Study All restore the same saved queue/batch state.

## Persisted session binding

StudyDeck adds:

- `studyProgressBindingData: Data?`
- `studyAllProgressBindingData: Data?`

Each holds a Codable StudySessionEpochBinding:

- `accountID: UUID?`
- `epoch: UUID?`
- `draftID: UUID?`

The owning deck ID is the StudyDeck's existing ID. This avoids a new session model
or global epoch. Each Study All chapter has its independent binding; normal and
combined sessions use different fields. A chapter's draft accumulates multiple
events in that session. Different chapters may have separate drafts for S4 to handle.

Start saves bindings alongside existing session state before accepting answers.
It runs on view appearance, not in an eagerly created navigation destination.
Reappearance does not start another session. Resume decodes the stored binding and
never reads a newer cached epoch for that work. An old active session with no binding
is explicitly unknown. Completing the whole session clears its bindings/queues,
while durable drafts remain in PendingStudyProgress. Closing the completed screen
does not reactivate an empty session.

These are additive optional fields in the existing unversioned schema. No store
deletion, replacement, or reset was introduced.

## Qualification and ownership

At the beginning of `StudySession.rate`, before any mutation:

`wasReview = learningCards.contains { $0.id == card.id }`

Only `wasReview && rating == .good` is eligible. NEW good, NEW again, and REVIEW
again never create an event. The legacy internal easy rating still follows its
existing local behavior but is not the two-button UI's Got It event.

Both modes resolve ownership through `card.deck`, verified against the session's
source decks. No parent ID substitution occurs. The event uses that deck's saved
binding, not its current cached epoch. Qualification never uses correctCount,
interval, completed count, or queue absence.

Unknown epoch means local study only. A cache refresh cannot turn a session that
started unknown into a creditable session. Suspended authentication also permits
local transitions without pending credit. Starting while suspended captures an
unknown binding; later activation does not retroactively credit it. Account switches
invalidate the old session's persistence access before touching old card objects.

S3 does not change authentication restoration or bypass LocalAccountStore checks.

## Atomic save and retries

For a creditable transition, allocate its event UUID and actual completion time
before mutation. Apply the unchanged local transition and review statistics, append
the event to an existing/new draft, stage queues/counts/bindings, then save once on
the same context. No await or network operation occurs in that transaction.

On failure, rollback and restore both the in-memory queues and the card's pre-answer
statistics. Explicit restoration matters: failure tests demonstrated that already
observed SwiftData objects can expose staged values after rollback. Restore the
visible session instead of reporting completion. The event UUID/time remain in
the failed attempt for retry, and the original answer is retried rather than silently
substituting another rating. Nothing is logged as captured before commit succeeds.

The UI keeps the answer visible, presents a save error, and provides Retry saving
answer. Repeated callbacks carry the old presentation UUID and are ignored after
success, including a one-card NEW-to-REVIEW transition. An identical event append
also retains S2's event-ID duplicate protection.

A successful event survives disk reopen. If the process terminates after a failed
save, neither the event nor the completion was committed; resume starts from the
last saved queues. An in-memory retry keeps its UUID/time, while an answer given
again after process termination is a new uncommitted-to-committed transition.

## Automated verification

The tests use actual StudySession, StudyProgressStore, and isolated on-disk SwiftData
stores without a live backend. They exercise all four phase/rating combinations,
exact event fields, stale callbacks, independent Study All epochs, unknown epochs,
legacy resume, normal/combined disk reopen, four-card boundaries, single-save
transactions, injected failure rollback and stable retry identity, authentication
suspension/switches, and separate normal/combined bindings. Existing S1/S2 tests
remain part of the full suite.

Verified September 26, 2026 with Xcode 16.2 on iPhone 16 / iOS 18.3.1 Simulator:
app compilation succeeded and all 57 MemoraTests passed, including 21 new S3 tests.
The migration test also passed with the two new optional binding fields. No live
backend or physical iOS 17.6.1 run was used for this verification.

## Manual verification

**Prerequisite for credit tests:** a fresh session must start with a real cached
backend epoch and an active LocalAccountStore account. S3 intentionally makes no
request to populate that cache. If it is nil, expect local study and no event;
that is the required unknown-epoch behavior. Do not generate fake epochs for real
accounts. The automated fixtures use test-only UUIDs in disposable stores.

1. Install over the existing app without uninstalling or clearing data. For a deck
   with a known cached epoch, begin a fresh session.
2. On a card labeled NEW, tap Got It: it enters REVIEW and no event is logged.
3. When that card is labeled REVIEW, tap Again: it requeues and still has no event.
4. On REVIEW, tap Got It: expect one DEBUG line beginning `STUDY PROGRESS captured`
   containing only event/card/deck/epoch IDs. No question/answer text or payload
   contents are logged. No HTTP progress submission should appear on the backend.
5. Repeat in Study All across two chapters. Logs must show the actual child IDs
   and each child's epoch, not the parent ID.
6. Exit an unfinished session, force-close the app, and relaunch. Resume and check
   queues/batch position. The tests additionally verify that changing the epoch
   cache before resume does not change the captured epoch.
7. For unknown epochs or suspended auth, expect `STUDY PROGRESS: local only` on
   qualifying local answers, normal study behavior, and zero new creditable events.

To inspect without production debug UI, pause inside StudyFlashcardsView.rateCard
after a successful rating and use the debugger with the active account:

```swift
po try StudyProgressStore(modelContext: modelContext).pending()
```

This displays account-filtered snapshots, events and their timestamps, not card
text or sealed request blobs. For precise repeatable failure/resume checks, run
StudySessionCaptureTests in Xcode's Test Navigator; no real user's data is used.
Physical iOS 17.6.1 installation/resume verification remains a manual step.

## S4 requirements

- All S3 records remain drafts. Introduce explicit sealing/upload boundaries later.
- Each chapter/session binding can point to a draft. When S4 seals it, coordinate
  rotation to a new draft before later answers; never mutate or append to a sealed
  body. Do not silently rebuild a failed upload with a fresh operation UUID.
- Events already carry immutable owning-deck IDs, epochs, UUIDs and completion
  times. Preserve them when grouping; different epochs of the same deck must not
  share one request. Define batch timestamp/day attribution explicitly.
- Send the exact persisted sealed payload; do not rebuild it using cached epochs.
- Normal study and Study All retain their local session responsibilities. Server
  progress reconciliation must not overwrite their queues.
- Epoch acquisition and the product behavior for sessions starting unknown remain
  separate from local capture. Never retroactively credit previously unknown work.
- No reset or plan-refresh hook is activated by S3.
