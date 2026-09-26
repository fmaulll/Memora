# Swift S4: durable progress synchronization

S4 adds epoch preparation and upload orchestration to S1–S3. It does not add reset integration, timeline UI, notifications, plan/exam refresh, or a new study engine.

## File map

Added:
- `Memora/Services/Sync/StudyProgressSync.swift`: epoch preparation, serialized flush, receipt validation, authentication recovery, error classification and reconciliation.
- `MemoraTests/StudyProgressSyncTests.swift`: mocked URLProtocol integration tests with disposable disk stores.
- `MemoraTests/StudyProgressS4MigrationTests.swift`: actual S3-store → current-schema migration test.
- This handoff.

The integration index also links to this handoff.

Changed:
- `Models/PendingStudyProgress.swift`: optional `failureCode`, reconciliation-required and terminal states. Existing payload/event fields remain immutable after sealing.
- `Services/Sync/StudyProgressStore.swift`: atomic split/seal, safe draft rotation, acknowledgement deletion, durable rejection lookup.
- `Services/API/APIClient.swift`: optional raw JSON body using the existing transport, authentication headers and error decoder; injectable dependencies for network tests. Production base URL remains unchanged.
- `Services/API/StudyProgressAPI.swift`: submit persisted bytes; bounded progress GET.
- `Services/StudySession.swift`: exposes fresh/resume status and successful batch boundaries; consults durable rejection markers before credit capture. NEW/REVIEW, SRS, queues and four-card rules are unchanged.
- `Views/Library/StudyFlashcardsView.swift`: preparation task, best-effort boundary/exit flush, disabled rating while preparation is incomplete.
- `Services/Sync/AppSyncManager.swift`: progress flush runs before content-throttle and initial-download decisions.

`StudyDeck`, `MemoraSchema`, `MemoraApp`, `ContentView`, `DeckDetailsView`, `SyncManager` and authentication storage need no schema/behavior changes for S4. Existing lifecycle and navigation entry points connect through the files above. No store replacement, deletion fallback or container reset is introduced.

## Epoch preparation

A genuinely fresh screen calls GET `/decks/{id}/study-progress`, with a three-second total request-timeout budget across its scopes. Study All uses one shared parent scope when possible, then caches each child's actual epoch separately through `cacheEpoch`. Normal study uses its owning deck. Backend response root identity is checked and unrelated returned IDs are ignored.

Resumes skip preparation. Their saved account/epoch bindings remain unchanged even if a cache has newer values. Network failure uses a previously cached epoch; nil remains local-only for the entire session. There is no synthetic epoch and no retroactive credit. The short preparation path does not wait for token refresh after a 401; it uses the same fallback. Upload/reconciliation use the normal refresh path below. Leaving during preparation cancels the view task; it cannot start an old screen after dismissal or an account change.

## Capture, boundaries, and rotation

S3 still saves qualifying REVIEW → Got It events in the same transaction as local queues and statistics. Uploads are triggered only after successful four-card batch completion, full completion, exit/Done, explicit app sync, startup or foreground sync. Rating and dismissal never await HTTP.

Each trigger seals account-owned drafts before entering the upload pipeline. Split/seal/delete commits in one local transaction: either the original draft remains, or its replacement immutable operations do. Sealing failure leaves durable drafts for a later trigger. Full completion can clear active bindings safely because pending lookup is account-scoped, independent of deck relationships.

Rotation is lazy and transactional: a saved binding may point to an old draft that is now sealed, split/deleted or acknowledged. At the next qualifying answer, `appendStudyEvent` resolves that pointer, creates a new draft if needed, and saves the new event plus updated binding/queues together. No await occurs during this operation. It works with in-memory controllers and after a process restart. Low-level S2 `append` still rejects a direct append to a sealed record.

## Historical completion time and Study All

Inspected backend `app/services/study_progress.py` and `app/services/study_attribution.py`. Accepted cards receive the request's `completed_at`; attribution buckets by **plan-local day + chapter + epoch**, and already-learned acknowledgements do not create new learning events.

Swift currently has no authoritative persisted-plan timezone cache. Therefore S4 groups only events with the exact same saved completion instant. Distinct instants become distinct sealed operations, even when the device considers them the same day. This conservative fallback cannot combine Monday/Tuesday learning under one later timestamp in an unknown plan timezone. The existing wire encoder emits whole-second ISO8601; the immutable stored request timestamp matches that representation. Original local event precision is retained. Upload/retry time never substitutes for event time.

This usually means one request per qualifying event **at a batch/exit/lifecycle boundary**, not a request from every rating tap. Correct attribution takes priority over minimizing requests. Future timezone-aware batching may reduce request count for new drafts; existing sealed payloads must never be merged or rewritten.

Study All retains S3's per-chapter drafts and independently captured epochs. It does not substitute a parent ID or force a multi-chapter merge. Existing S2 multi-deck drafts remain supported and are split by event instant before sealing.

## Transport, account ownership, and receipts

`APIClient.request(rawJSONBody:)` places persisted `payloadData` directly into `URLRequest.httpBody`. Request decoding is used only for receipt validation, never for rebuilding outgoing bytes. Operation UUID, body, completion time, epochs and card IDs remain fixed for every resend.

The shared `StudyProgressSync` maintains one pipeline per account. Concurrent triggers can seal new work; the running pipeline drains newly sealed operations without sending the same operation twice in parallel. Each operation is attempted at most once in that drain, except the single authorized resend after token refresh. Operations are ordered by saved completion time. A transient failure stops the drain until a later meaningful trigger; there is no polling/backoff timer or tight retry loop.

Every persistence access is bound to `LocalAccountStore`'s active account/revision. Revision checks occur around network waits and before cleanup/reconciliation. Suspended sessions cannot upload. Logout/cache deletion preserves pending records. Another account cannot read or send them; the original account can resume them after activation.

On HTTP 401, use `AuthAPI.refreshAccessToken`, then resend the same bytes once if the original account revision remains active. Refresh failures are retryable, including rejected refresh responses. S4 never creates an anonymous replacement account, clears tokens or deletes pending work in response to auth failure.

Receipt validation checks operation UUID, completion time, unique deck groups, matching group epochs, and the exact union of accepted/already-learned card IDs without duplicates. It does **not** update cached epochs. A valid acknowledgement deletes the local operation in a save. If acceptance happens but response/cleanup is lost, the same UUID/body survive; a later immutable receipt replay is accepted and cleanup finishes.

## Failure handling

| Outcome | Durable action |
| --- | --- |
| Transport, timeout, 5xx, 401/auth inability, 408/425/429 | Keep sealed bytes unchanged; stop this drain and retry on a later trigger. |
| Invalid/mismatched success receipt | Preserve sealed operation; never acknowledge uncertain work. |
| `stale_progress_epoch` | Persist reconciliation-required before GET. Read current progress and cache epochs for future sessions; then retain old operation as terminal. Never resend/relabel its events. |
| `card_not_in_deck` | Persist reconciliation-required and read current progress/card membership (404 also resolves a deleted scope). Retain terminal operation with original IDs. Do not overwrite active queues or trigger a full content download in the study callback. Existing content sync remains responsible for content changes. |
| Reconciliation GET fails transiently | Keep reconciliation-required. Later triggers retry GET only, not rejected POST. |
| `idempotency_conflict` or other nonretryable 4xx | Terminal record preserves UUID, exact payload, events and backend code/status. No new UUID or automatic resend. |

Retained stale-epoch records explicitly block further backend-credit capture for that deck/epoch, including resumed sessions after a restart; local study still proceeds. Missing-card rejection blocks the original rejected card/deck/epoch combination. Other sealed work containing already-rejected learning is terminalized without another POST. The rejection scope is conservative because backend errors do not identify an individual failing entry. These markers do not relabel bindings. A new session may capture the newly fetched epoch.

DEBUG logs contain operation identifiers and reason/error codes only. No card text, tokens, raw error bodies or payload JSON are logged by S4.

## Automated verification

The complete `MemoraTests` suite runs against disposable local stores and URLProtocol responses; no live backend is needed. Coverage includes epoch preparation/fallback, normal and Study All resume, account changes, atomic sealing failure, multi-day attribution, immutable bytes across restart, draft rotation, receipt validation/replay, transient errors, auth recovery, concurrent triggers, durable reconciliation, stale resumed sessions, S3 atomic capture regressions and pre-S2/S3 schema migration.

Final run: **86 test functions, 102 executed cases including parameterized cases; zero failures, zero skipped cases, and no compiler warnings**. Xcode simulator: iPhone 16, iOS 18.3.1. Result bundle: `/tmp/memora-s4-tests-3.xcresult`; build/test log: `/tmp/memora-s4-tests-3.log`. This does not replace testing on the user's physical iPhone/iOS 17.6.1.

## Exact live-backend verification

1. Start the existing FastAPI/PostgreSQL environment with its migrations applied. Keep the existing app installation/data. Verify the API address in `APIClient` matches the reachable LAN server (`http://192.168.1.13:8000` in the current project), and that `/auth/me` works for the app's account. Use that account's bearer token in Swagger/Postman; do not paste tokens into logs.
2. Choose a deck with server-generated/synced cards. Finish any already-active local session first if testing *fresh* preparation. Open Study. Expect one GET `/decks/{owning_deck_id}/study-progress` before rating becomes enabled. Inspect its real `progress_epoch`; no app-generated replacement should appear.
3. Reveal a NEW card and choose Got It. It enters REVIEW. Expect no learned event and no POST for that action. With several cards, complete the NEW presentations in the current four-card batch before REVIEW begins.
4. Reveal that card in REVIEW and choose Got It. Expect a local capture log. Complete the four-card batch (or press X/Done). Expect one or more POST `/study/progress/submissions`, followed by acknowledged logs. With the conservative timestamp policy, distinct event times produce separate POSTs at this boundary.
5. GET `/decks/{owning_deck_id}/study-progress` using Swagger/Postman. Verify the exact card's `learned_at`, learned counts, and chapter completion. App queues should continue normally; S4 does not refresh progress displays or timelines.
6. Start fresh Study All for a parent with at least two chapters. Expect one parent progress GET. Learn cards from both chapters and finish/exit. Inspect requests privately in a debugger/proxy if necessary: each group must use the actual child `deck_id` and that child's captured epoch, never the parent ID/epoch. Verify each child with progress GET.
7. For offline recovery, first prepare a session online, then stop the backend/network. Learn and exit or complete a batch. Local study must continue; the upload is deferred. Note the operation ID in DEBUG logs. Terminate and relaunch the app without uninstalling it. Reconnect and foreground the app. Expect the same operation ID to be acknowledged, even if content sync ran less than 15 minutes ago. Confirm backend facts retain original completion dates.
8. For replay, use a test network proxy to drop a successful submission response after server acceptance. Foreground again after restoring responses. Verify the same operation UUID/body is resent and the backend returns its original receipt; no extra learned fact is created.
9. For stale epoch, prepare a test session at epoch A, disconnect, record learning, and use the backend reset endpoint from Swagger/another client to rotate to B. Reconnect/flush. Expect a rejected POST, progress GET and terminal old operation. Existing local study continues without credits under B. Finish the old session; a fresh session can bind B. This tests reconciliation only; no Swift reset UI/integration was added.
10. For missing content, remove a test card on the backend after local capture and before upload. Expect `card_not_in_deck`, reconciliation GET and no repeated rejected POST on later foregrounds. Remaining local queues must not be overwritten by this response.
11. While an upload is delayed, switch accounts. The old pending operation must remain inaccessible to the new account. Switch back and trigger app sync/foreground; the original account may retry. Never reset the application store for this check.

Backend plans may adapt automatically after accepted learning. S4 deliberately sends no redundant recalculate call and makes no new timeline/exam refresh request.

## S5/S6 handoff

- S5 must preserve immutable operation identities and handle the receipt namespace shared by submission/reset UUIDs. Never relabel pre-reset events. Retained stale markers currently disable old-epoch credit; do not purge them while old bindings can still resume.
- Binding draft pointers are allowed to reference sealed/deleted records until the next atomic capture rotates them. Do not treat that as a missing-event error or recreate old payloads.
- Successful receipts are acknowledgements, not current snapshots. S6 should fetch current progress/plan/exams when needed and must not overwrite active local queues.
- No automatic POST recalculate is needed after progress/reset/exam hooks. Backend adaptation already handles it.
- An authoritative plan-timezone cache could permit safe same-day grouping of **unsealed** events later. Never change already-sealed bodies to adopt that optimization.
- Terminal diagnostics are retained without an automatic retention policy. Any future cleanup must consider resumed binding rejection and account isolation.
