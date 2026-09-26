# Swift S5 — backend Reset Progress

S5 connects the existing deck/chapter Reset Progress confirmation to the backend reset contract. It preserves existing installation data and does not implement S6, timeline UI, notifications, exam refresh, or plan recalculation.

## Ordering and durable states

The account's progress upload and reset pipeline share `StudyProgressGate`:

1. A reset waits for the current in-flight progress HTTP operation. The progress drain stops before its next operation if a reset is waiting.
2. Fetch GET `/decks/{requested_scope_id}/study-progress` using existing authentication recovery. No offline/local-only reset is created when this read fails.
3. Persist `PendingStudyReset`: account ID, requested scope ID, UUID `reset_id`, exact encoded request bytes and `pending` state. The request includes every returned deck and its real current epoch. Scope IDs and epochs are never synthesized.
4. This durable record fences affected learning uploads and study mutations, including after relaunch. Existing queues/statistics remain unchanged while the result is uncertain. Other scopes can continue syncing after this reset attempt releases the account gate.
5. POST the persisted bytes to `/decks/{scope_id}/study-progress/reset`. Validate reset ID, path scope, exact unique deck set, previous epochs, rotated epochs and nonnegative cleared counts.
6. Save the valid receipt and `confirmed` state before any current-state GET or local clearing.
7. GET current progress separately for each originally affected deck. Cache current epochs from these reads, never from the reset receipt. A confirmed reset followed by a deleted deck's 404 clears its local epoch rather than installing an old receipt epoch. A newer cache observation is not overwritten by an older fetch.
8. In one local save: retire old learning, clear scoped card statistics and both study-session types, clear both batch-ID arrays and bindings, cache current epochs, assign `lastStudyResetID`, and mark the operation `completed`.

There is no automatic second reset UUID after a timeout, lost response, authentication failure or server error. A pending request retries its exact UUID/body. A confirmed request only needs current GETs plus local completion; it does not need another POST. A completed request is a no-op when referenced by a Retry action.

Completed reset records are retained for idempotent UI retry and diagnostics. A brand-new explicit confirmation after completion can intentionally create another reset. The UI remembers its operation ID so an error's Retry button cannot accidentally reset again after foreground recovery has already completed it.

## Pending S4 learning

The chosen ordering is **finish the in-flight upload, fence the remaining scope, then retire its unsent learning after confirmed reset**. It does not require draining an offline backlog before reset.

Draft/sealed learning records intersecting the confirmed scope become terminal with `superseded_by_reset`. Their events, epochs, UUIDs and sealed bytes remain unchanged. Existing S4 stale/reconciliation/terminal markers are preserved. While reset is pending/confirmed/blocked, progress POSTs intersecting the scope cannot start.

An already-sealed multi-deck operation intersecting the reset scope is retired as a whole. The client never edits/reissues an immutable request to salvage other groups. Normal S3/S4 capture uses per-chapter drafts, so this conservative case mainly concerns older/multi-deck records; their original data is retained for diagnosis.

No old answer is assigned the new epoch. No successful reset receipt is treated as a current snapshot. If another device resets again after the saved receipt, current GET epochs win.

## Failure handling

| Failure | Behavior |
| --- | --- |
| Initial scope GET fails/offline/auth unavailable | No reset intent is sent; all existing local study state stays intact. |
| Reset POST timeout, network failure, 5xx, transient auth, 408/425/429 | Keep `pending`, exact UUID/body and scope fence; Retry or later app sync resumes it. |
| Response lost after backend commit | Repost the same bytes. Backend replay confirms the original rotation. |
| Receipt does not match request | Keep pending and preserve local state; never clear on an unverified acknowledgement. |
| Backend confirmed, current GET fails | Keep `confirmed`; retry GET and local completion later. |
| Local clearing save fails | Roll back the transaction and explicitly restore live observed queues/statistics/cache/learning states. The confirmed operation remains recoverable. No empty UI state is left behind by SwiftData rollback. |
| `stale_progress_epoch` / `progress_scope_changed` | Persist `rejectedNeedsReconciliation`, GET current scope, refresh current epoch cache, then retain `rejected`. No local clearing. A new explicit confirmation is required for a new request. Retry of the old ID stays rejected. |
| Rejection reconciliation GET fails | Keep its fence and retry GET only during later recovery. |
| `idempotency_conflict` or another definitive nonretryable 4xx | Retain `blocked` with original identity/body and diagnostic code. No automatic replacement ID; scope remains fenced pending investigation. |
| Account switches or suspends during a request | Stop account-bound processing and keep durable work. Another account cannot recover or upload it. |

Reset uses S4's existing `AuthAPI.refreshAccessToken` recovery: one refresh and resend, not an anonymous replacement or token/data reset. Logout clears content cache as before but preserves both operation logs.

## Intentional local clearing

Only originally confirmed scope members are reset. Parent reset covers the server's immediate chapters; chapter reset leaves siblings' statistics/session records alone; standalone reset covers itself. Direct parent cards are excluded when the backend parent scope consists of children.

For each affected deck, reset clears:

- Card `reviewCount`, `correctCount`, `lastReviewedAt`, `nextReviewAt`, `difficulty`, `interval`, preserving the old exclusion of cards marked for deletion.
- Normal `studyQueueIDs`, `learningQueueIDs`, `studyCompletedCount`, `isStudySessionActive`, `studyBatchCardIDs`, `studyProgressBindingData`.
- Study All `studyAllQueueIDs`, `studyAllLearningQueueIDs`, `studyAllCompletedCount`, `isStudyAllSessionActive`, `studyAllBatchCardIDs`, `studyAllProgressBindingData`.

Exam achievements and deck/card content are not cleared. Backend reset already preserves exam achievements and adapts plans. No exam mutation or POST study-plan/recalculate is sent.

`lastStudyResetID` invalidates a controller created before intentional clearing. Its next rating cannot write stale queues/stats; closing it does not restore them. Resetting a chapter also invalidates an open Study All controller containing that chapter, while preserving sibling persisted records. Fresh controllers use the refreshed epochs. Backend GETs otherwise never rewrite queues.

## UI and lifecycle

The existing confirmation remains in `DeckDetailsView`. An in-progress overlay and disabled underlying controls prevent repeated submissions on that screen; the shared gate also rejects duplicate concurrent calls for the same account/scope. Retryable failures show Try Again. Rejected scope/epoch conflicts explain that another explicit confirmation is required; integrity failures show a diagnostic code.

S4's startup, foreground and explicit-sync hooks now recover durable resets before eligible progress uploads. Recovery is independent of the content-sync throttle and initial-download early return. It only continues existing user-authorized resets; it never invents a reset request.

## Files

Added:
- `Models/PendingStudyReset.swift`: durable immutable request, receipt and reset states/errors.
- `Services/Sync/StudyProgressGate.swift`: shared per-account serialization and reset priority.
- `Services/Sync/StudyResetStore.swift`: account-scoped persistence, fences, atomic local completion and rollback restoration.
- `Services/Sync/StudyProgressResetSync.swift`: online reset, validation, replay, conflict reconciliation and recovery.
- `MemoraTests/StudyProgressResetTests.swift`: mocked backend reset, recovery, concurrency and scope tests.
- `MemoraTests/PreS5Models.swift`, `MemoraTests/StudyResetMigrationTests.swift`: frozen S4 schema and real disk migration coverage.
- This handoff.

Changed:
- `Models/MemoraSchema.swift`: additive `PendingStudyReset` registration; unchanged store location/container policy.
- `Models/StudyDeck.swift`: optional `lastStudyResetID`.
- `Models/PendingStudyProgress.swift`: narrow live-state restoration after failed reset transaction; immutable event/payload fields unchanged.
- `Services/API/StudyProgressAPI.swift`: reset raw-body transport overload.
- `Services/Sync/StudyProgressSync.swift`: shared gate, reset recovery and scope upload fences; reuse of its authentication helper.
- `Services/StudySession.swift`: fence and reset-generation checks before study writes.
- `Views/Library/DeckDetailsView.swift`: existing reset action now uses durable backend-first service, progress/retry feedback.
- `Views/Library/StudyFlashcardsView.swift`: meaningful reset errors and safe closing of invalidated/fenced controllers.
- `Services/Auth/LocalAccountStore.swift`: documentation explicitly includes reset records in preserved logs; deletion behavior is unchanged.
- `MemoraTests/StudyProgressSyncTests.swift`: reuse of mock fixtures; serialized case scheduling to avoid main-actor fixture load exhausting the existing three-second preparation timeout. Explicit concurrency tests still run overlapping tasks.
- Integration index links this handoff.

## Verification

Automated tests use URLProtocol responses and disposable stores. No live backend is required. Coverage includes parent/chapter success, epoch rotation and fresh binding, unchanged pending bytes, lost response and receipt replay, confirmed-before-local-clear recovery, retry after automatic completion, save failure restoration, both session types/batches/bindings, stale/scope conflicts, invalid receipts, integrity errors, pending reset vs progress races, unaffected chapters, old controllers, account isolation, and preservation of S4 rejection markers.

The migration test creates an actual frozen S4 disk store, then opens it with the S5 schema and verifies cards, statistics, both queues/batch arrays, bindings, cached epochs and sealed operation bytes. No production store reset or fallback container was introduced. Final verification: **107 test functions, 131 executed cases including parameterized cases, zero failures, zero skipped cases, and no compiler warnings** on iPhone 16 simulator/iOS 18.3.1. Result bundle: `/tmp/memora-s5-tests-3.xcresult`; log: `/tmp/memora-s5-tests-3.log`.

## Exact live-backend verification

1. Start the existing FastAPI/PostgreSQL environment with migrations applied. Keep the app installed with its existing data. Confirm its configured API address is reachable and authentication works. Use the same account's token privately in Swagger/Postman.
2. Choose a synced parent with at least two chapters. Study some cards, leaving a resumable normal session and a Study All session. Record GET `/decks/{parent_id}/study-progress` epochs and GET `/decks/{parent_id}/exams` achievements.
3. From the existing ellipsis/options sheet choose Reset Chapter Progress and confirm. Expect scope GET, reset POST, then current progress GET for that chapter. While active, repeated reset taps should be unavailable.
4. Verify the chapter's backend learned facts/counts are cleared and its epoch changed. Locally verify its statistics, normal/Study All resume state and batches are cleared. Its sibling statistics remain. Start fresh study and inspect its captured epoch: it should match current progress GET.
5. Perform Reset Deck Progress for the parent. Verify the request includes all returned chapter IDs and individual epochs, and all affected local chapter sessions clear. Repeat with a standalone deck. Check both normal and Study All batch IDs/binding data in the debugger if needed.
6. GET exams again: passed milestones/best scores/attempts must remain. Check server logs contain no reset-triggered POST `/study-plan/recalculate` or exam mutation. S5 does not refresh the timeline/exam UI.
7. For offline failure, stop the backend before confirming a reset. The error should allow retry; local study statistics and queues must remain intact. Restore connectivity and retry. If the initial scope GET never succeeded, a new intent is only persisted after a successful read.
8. For uncertain delivery, use a test proxy to drop the reset response *after* the backend commits it. Note the persisted operation UUID/bytes in the debugger (do not publish payloads/tokens). Existing local state should remain. Kill/relaunch without uninstalling, reconnect and foreground: the same reset UUID/body must replay, with no second epoch rotation, then local clearing completes.
9. Alternatively, allow the reset receipt through but block subsequent progress GETs. Verify a `confirmed` operation remains and local statistics do not clear yet. Relaunch/reconnect: GETs and local completion should recover without another reset POST. If another device reset in between, cached epochs must match the latest GET, not the old receipt.
10. While reset is uncertain, try studying the affected scope: it must ask you to complete reset first. An unrelated chapter can still study/sync. Deliberately delay an already-running progress submission and confirm reset: reset must wait for that request, then prevent remaining old-scope progress submissions. After reset, old pending learning stays terminal with original epochs/bytes.
11. For a stale-scope test, change/reset the backend scope from another client between the app's initial GET and reset POST. Expect rejection reconciliation and a message that local state was retained. There must be no automatic fresh reset UUID. A new explicit confirmation may then fetch the current scope and create a new request.
12. Switch accounts while a reset response is delayed. The old account's reset must not finish against the new account's cache. Switch back and foreground to recover the original operation. Existing operation logs must survive logout.

Physical iPhone/iOS 17.6.1 and the real backend still require these manual checks; simulator mocks cannot prove server deployment or physical-device behavior.

## S6 handoff

- Completed reset records are not UI progress snapshots. Refresh progress/plan/exams with GET when S6 needs them, without replacing active queues.
- Never relabel pre-reset events, rebuild uncertain requests, or remove fences before a defined terminal outcome.
- Keep `lastStudyResetID` invalidation when refreshing local deck content. Completed record cleanup must not break a still-visible Retry action's operation ID.
- S4 rejection markers remain meaningful; keep the prior retention rules for old bindings/epochs.
- Plan adaptation is already automatic on the backend. Reset does not need a second recalculation request.
