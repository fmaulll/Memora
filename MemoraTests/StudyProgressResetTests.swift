import Foundation
import SwiftData
import Testing
@testable import Memora

// Disk fixtures and URLProtocol callbacks share the main actor. Serialize test
// cases so fixture creation cannot exhaust production network timeout budgets.
@Suite(.serialized)
@MainActor
struct StudyProgressResetTests {
    typealias Fixture = StudyProgressSyncTests.Fixture
    typealias Signal = StudyProgressSyncTests.Signal

    @Test(arguments: [true, false]) func parentAndChapterResetClearOnlyIntendedLocalScope(parent: Bool) async throws {
        let f = try Fixture(chapters: 2, cards: 2); defer { f.clean() }
        let server = Server(f)
        try seedSessions(f)
        let untouched = LocalState(f.decks[1])
        let originalEpochs = f.epochs
        let scope = parent ? f.decks[0].parentDeck!.id : f.decks[0].id
        try await resetter(f).reset(scopeID: scope, context: f.context)
        #expect(server.rotations == (parent ? 2 : 1))
        #expect(f.epochs[0] != originalEpochs[0])
        assertCleared(f.decks[0])
        if parent { assertCleared(f.decks[1]); #expect(f.epochs[1] != originalEpochs[1]) }
        else { #expect(LocalState(f.decks[1]) == untouched); #expect(f.epochs[1] == originalEpochs[1]) }
        #expect(f.decks[0].cachedProgressEpoch == f.epochs[0])
        #expect(try operations(f).first?.stateRawValue == "completed")
        #expect(f.requests.allSatisfy { $0.url!.path.contains("study-progress") })
        #expect(server.examPassed) // Mock backend preserves milestones; no exam mutation was sent.
        let fresh = StudySession(decks: [f.decks[0]], combined: false)
        try fresh.start(context: f.context, accounts: f.accounts)
        let binding = try JSONDecoder().decode(StudySessionEpochBinding.self, from: #require(f.decks[0].studyProgressBindingData))
        #expect(binding.epoch == f.epochs[0] && !fresh.wasResuming)
    }

    @Test func pendingLearningIsRetiredWithoutRelabelingOrChangingPayload() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f)
        try f.capture()
        try f.store().sealDrafts()
        let before = try #require(f.store().pending().first)
        let body = try f.store().sealedUpload(batchID: before.id).payload
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context)
        let after = try #require(f.store().pending().first)
        #expect(after.id == before.id && after.operationID == before.operationID && after.events == before.events)
        #expect(after.state == .terminalFailure && after.failureCode == "superseded_by_reset")
        #expect(try f.context.fetch(FetchDescriptor<PendingStudyProgress>()).first?.payloadData == body)
        await f.sync.flush(context: f.context)
        #expect(server.progressPosts == 0)
    }

    @Test(arguments: [0, 500, 503, 401]) func failedResetKeepsLocalSessionsAndImmutableOperation(status: Int) async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.postStatus = status
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(LocalState(f.decks[0]) == before && server.rotations == 0)
        let first = try #require(operations(f).first)
        let payload = first.payloadData, id = first.id
        #expect(first.stateRawValue == "pending")
        server.postStatus = nil
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context)
        #expect(server.requests.allSatisfy { $0 == payload })
        #expect(try operations(f).first?.id == id)
        #expect(server.rotations == 1)
        assertCleared(f.decks[0])
    }

    @Test func initialOfflineScopeReadDoesNotCreateOfflineReset() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.failReads = true
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(try operations(f).isEmpty)
        #expect(LocalState(f.decks[0]) == before && server.requests.isEmpty)
    }

    @Test func lostResponseReplaysExactResetAfterRelaunchWithoutSecondRotation() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.loseResponse = true
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(server.rotations == 1 && LocalState(f.decks[0]) == before)
        let payload = try #require(operations(f).first?.payloadData)
        try f.reopen(); server.loseResponse = false
        await f.sync.flush(context: f.context)
        #expect(server.requests == [payload, payload] && server.rotations == 1)
        assertCleared(f.decks[0])
        #expect(try operations(f).first?.stateRawValue == "completed")
        let count = f.requests.count
        await f.sync.flush(context: f.context)
        #expect(f.requests.count == count)
    }

    @Test func confirmedResetWaitsForCurrentReadAndRecoversWithoutAnotherPost() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.failReadsAfterReset = true
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(try operations(f).first?.stateRawValue == "confirmed")
        #expect(LocalState(f.decks[0]) == before)
        try f.reopen()
        let newer = UUID(); f.epochs[0] = newer // Another device has reset again since the receipt.
        server.failReadsAfterReset = false
        await f.sync.flush(context: f.context)
        #expect(server.requests.count == 1 && server.rotations == 1)
        #expect(f.decks[0].cachedProgressEpoch == newer)
        assertCleared(f.decks[0])
    }

    @Test func retryButtonAfterAutomaticRecoveryDoesNotCreateNewReset() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f)
        server.loseResponse = true
        var id: UUID?
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context, onPersisted: { id = $0 }) }
        server.loseResponse = false
        await f.sync.flush(context: f.context)
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context, operationID: #require(id))
        #expect(server.rotations == 1 && server.requests.count == 2)
        #expect(try operations(f).count == 1)
    }

    @Test func localCommitFailureLeavesConfirmedOperationForRecovery() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        let failing = StudyProgressResetSync(progress: f.sync, saveChanges: { context in
            if try context.fetch(FetchDescriptor<PendingStudyReset>()).contains(where: { $0.stateRawValue == "completed" }) {
                throw URLError(.cannotWriteToFile)
            }
            try context.save()
        })
        await fails { try await failing.reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(LocalState(f.decks[0]) == before)
        #expect(try operations(f).first?.stateRawValue == "confirmed")
        try f.reopen()
        await f.sync.flush(context: f.context)
        #expect(server.requests.count == 1)
        assertCleared(f.decks[0])
    }

    @Test(arguments: ["stale_progress_epoch", "progress_scope_changed"]) func rejectedResetNeedsFreshExplicitConfirmation(code: String) async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.rejectCode = code
        var oldID: UUID?
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context, onPersisted: { oldID = $0 }) }
        #expect(LocalState(f.decks[0]) == before)
        #expect(try operations(f).first?.stateRawValue == "rejected")
        await f.sync.flush(context: f.context)
        #expect(server.requests.count == 1)
        // Retrying the old operation remains rejected; only a NEW confirmation may create an ID.
        server.rejectCode = nil
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context, operationID: oldID) }
        #expect(server.requests.count == 1)
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context)
        #expect(try operations(f).count == 2)
        #expect(server.rotations == 1)
    }

    @Test func rejectedReconciliationFailureRetainsFenceAndRetriesGetOnly() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f)
        server.rejectCode = "stale_progress_epoch"; server.failReadsAfterPost = true
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(try operations(f).first?.stateRawValue == "rejectedNeedsReconciliation")
        server.failReadsAfterPost = false
        await f.sync.flush(context: f.context)
        #expect(server.requests.count == 1)
        #expect(try operations(f).first?.stateRawValue == "rejected")
    }

    @Test func idempotencyConflictBlocksWithoutNewIdentityOrLocalReset() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.rejectCode = "idempotency_conflict"
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        let operation = try #require(operations(f).first), id = operation.id, payload = operation.payloadData
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        await f.sync.flush(context: f.context)
        #expect(server.requests == [payload] && operation.id == id && operation.stateRawValue == "blocked")
        #expect(LocalState(f.decks[0]) == before)
    }

    @Test(arguments: ["identity", "previous_epoch", "missing_deck", "same_epoch"]) func invalidReceiptCannotClearLocalState(mismatch: String) async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.receiptMismatch = mismatch
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(LocalState(f.decks[0]) == before)
        #expect(try operations(f).first?.stateRawValue == "pending")
        server.receiptMismatch = nil
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context)
        #expect(server.rotations == 1 && server.requests.count == 2)
    }

    @Test func resetWaitsForInflightProgressThenRetiresRemainingOldLearning() async throws {
        let f = try Fixture(cards: 2); defer { f.clean() }
        let server = Server(f); try f.capture()
        let started = Signal(), release = Signal()
        server.progressWait = { started.open(); await release.wait() }
        let flush = Task { await f.sync.flush(context: f.context) }
        await started.wait()
        let reset = Task { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        // Wait until reset has enqueued at the gate, without relying on wall-clock sleeps.
        while !f.sync.gate.hasWaiter(f.owner) { await Task.yield() }
        #expect(server.requests.isEmpty)
        release.open(); await flush.value; try await reset.value
        #expect(server.progressPosts == 1 && server.rotations == 1)
        await f.sync.flush(context: f.context)
        #expect(server.progressPosts == 1)
        #expect(try f.store().pending().allSatisfy { $0.state == .terminalFailure })
    }

    @Test func concurrentResetTapsAndFlushCannotDuplicateOrBypassReset() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try f.capture()
        let started = Signal(), release = Signal()
        server.resetWait = { started.open(); await release.wait() }
        let reset = Task { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        await started.wait()
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        await f.sync.flush(context: f.context)
        #expect(server.progressPosts == 0 && server.requests.count == 1)
        release.open(); try await reset.value
        #expect(server.rotations == 1)
    }

    @Test func uncertainResetBlocksStudyAndOldControllersCannotResurrectQueues() async throws {
        let f = try Fixture(cards: 2); defer { f.clean() }
        let server = Server(f)
        let study = f.session(); try f.start(study)
        try study.rate(.good, expectedPresentation: study.presentationID)
        server.postStatus = 500
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(throws: StudyResetError.self) { try study.rate(.good, expectedPresentation: study.presentationID) }
        #expect(throws: StudyResetError.self) { try study.saveForExit() }
        #expect(throws: StudyResetError.self) { try f.start(f.session()) }
        server.postStatus = nil
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context)
        #expect(throws: StudyResetError.self) { try study.rate(.good, expectedPresentation: study.presentationID) }
        try study.saveForExit()
        assertCleared(f.decks[0])
    }

    @Test func differentAccountCannotRecoverOrFinishOriginalReset() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f)
        let scope = f.decks[0].id
        server.loseResponse = true
        await fails { try await resetter(f).reset(scopeID: scope, context: f.context) }
        let payload = try #require(operations(f).first?.payloadData)
        try f.accounts.activate(userID: UUID(), modelContext: f.context)
        await f.sync.flush(context: f.context)
        #expect(server.requests == [payload])
        #expect(try operations(f).isEmpty)
        try f.accounts.activate(userID: f.owner, modelContext: f.context)
        // The original content cache may be absent after logout. Pending reset survives.
        server.loseResponse = false; server.deleted = true
        await f.sync.flush(context: f.context)
        #expect(server.requests == [payload, payload] && server.rotations == 1)
        #expect(try operations(f).first?.stateRawValue == "completed")
    }

    @Test func accountSuspensionAfterBackendAcceptancePreservesPendingReceiptReplay() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try seedSessions(f)
        let before = LocalState(f.decks[0])
        server.afterCommit = { f.accounts.suspend() }
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        #expect(LocalState(f.decks[0]) == before)
        try f.accounts.activate(userID: f.owner, modelContext: f.context)
        server.afterCommit = nil
        await f.sync.flush(context: f.context)
        #expect(server.requests.count == 2 && server.rotations == 1)
        assertCleared(f.decks[0])
    }

    @Test func uncertainChapterResetFencesOnlyItsScopeDuringLaterFlush() async throws {
        let f = try Fixture(chapters: 2); defer { f.clean() }
        let server = Server(f)
        let study = f.session(combined: true); try f.start(study); try f.finish(study)
        server.postStatus = 500
        await fails { try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context) }
        await f.sync.flush(context: f.context)
        #expect(server.progressPosts == 1)
        let sent = try f.requests.filter { $0.url!.path == "/study/progress/submissions" }.map {
            try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: Fixture.body($0))
        }
        #expect(sent.flatMap(\.decks).map(\.deckID) == [f.decks[1].id])
        #expect(try f.store().pending().flatMap(\.events).allSatisfy { $0.deckID == f.decks[0].id })
    }

    @Test func existingS4RejectionMarkersRemainMeaningfulAfterReset() async throws {
        let f = try Fixture(); defer { f.clean() }
        let server = Server(f); try f.capture(); try f.store().sealDrafts()
        let item = try #require(f.store().pending().first)
        let event = try #require(item.events.first)
        try f.store().block(batchID: item.id, code: "stale_progress_epoch", reconcile: false)
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context)
        #expect(try f.store().pending().first?.failureCode == "stale_progress_epoch")
        #expect(try f.store().creditIsBlocked(deckID: event.deckID, epoch: event.progressEpoch, cardID: event.cardID))
        #expect(server.rotations == 1)
    }

    @Test func resettingChapterInvalidatesOpenStudyAllWithoutClearingSiblingStats() async throws {
        let f = try Fixture(chapters: 2, cards: 2); defer { f.clean() }
        let server = Server(f)
        let study = f.session(combined: true); try f.start(study)
        try study.rate(.good, expectedPresentation: study.presentationID)
        let sibling = LocalState(f.decks[1])
        try await resetter(f).reset(scopeID: f.decks[0].id, context: f.context)
        #expect(throws: StudyResetError.self) { try study.rate(.good, expectedPresentation: study.presentationID) }
        try study.saveForExit()
        assertCleared(f.decks[0])
        #expect(LocalState(f.decks[1]) == sibling && server.rotations == 1)
    }

    private func resetter(_ f: Fixture) -> StudyProgressResetSync { StudyProgressResetSync(progress: f.sync) }
    private func operations(_ f: Fixture) throws -> [PendingStudyReset] {
        try StudyResetStore(context: f.context, accounts: f.accounts).operations()
    }
    private func fails(_ work: () async throws -> Void) async {
        do { try await work(); Issue.record("Expected reset to fail or defer") } catch { }
    }
    private func seedSessions(_ f: Fixture) throws {
        for deck in f.decks {
            let ids = deck.cards.map(\.id)
            deck.studyQueueIDs = ids; deck.learningQueueIDs = ids; deck.studyCompletedCount = 3
            deck.studyBatchCardIDs = ids; deck.isStudySessionActive = true
            deck.studyAllQueueIDs = ids; deck.studyAllLearningQueueIDs = ids; deck.studyAllCompletedCount = 4
            deck.studyAllBatchCardIDs = ids; deck.isStudyAllSessionActive = true
            let binding = try JSONEncoder().encode(StudySessionEpochBinding(accountID: f.owner, epoch: deck.cachedProgressEpoch, draftID: nil))
            deck.studyProgressBindingData = binding; deck.studyAllProgressBindingData = binding
            for card in deck.cards {
                card.reviewCount = 7; card.correctCount = 5; card.interval = 4; card.difficulty = 2.5
                card.lastReviewedAt = Date(timeIntervalSince1970: 1000); card.nextReviewAt = Date(timeIntervalSince1970: 2000)
            }
        }
        try f.context.save()
    }
    private func assertCleared(_ deck: StudyDeck) {
        #expect(deck.studyQueueIDs.isEmpty && deck.learningQueueIDs.isEmpty && deck.studyBatchCardIDs.isEmpty)
        #expect(deck.studyAllQueueIDs.isEmpty && deck.studyAllLearningQueueIDs.isEmpty && deck.studyAllBatchCardIDs.isEmpty)
        #expect(deck.studyCompletedCount == 0 && deck.studyAllCompletedCount == 0)
        #expect(!deck.isStudySessionActive && !deck.isStudyAllSessionActive)
        #expect(deck.studyProgressBindingData == nil && deck.studyAllProgressBindingData == nil)
        #expect(deck.cards.allSatisfy { $0.reviewCount == 0 && $0.correctCount == 0 && $0.interval == 0 && $0.difficulty == 0 && $0.lastReviewedAt == nil && $0.nextReviewAt == nil })
    }

    private struct LocalState: Equatable {
        let queues: [[UUID]]
        let counts: [Int]
        let flags: [Bool]
        let bindings: [Data?]
        let cardStats: [String]
        init(_ deck: StudyDeck) {
            queues = [deck.studyQueueIDs, deck.learningQueueIDs, deck.studyBatchCardIDs, deck.studyAllQueueIDs, deck.studyAllLearningQueueIDs, deck.studyAllBatchCardIDs]
            counts = [deck.studyCompletedCount, deck.studyAllCompletedCount]
            flags = [deck.isStudySessionActive, deck.isStudyAllSessionActive]
            bindings = [deck.studyProgressBindingData, deck.studyAllProgressBindingData]
            cardStats = deck.cards.sorted { $0.id.uuidString < $1.id.uuidString }.map { "\($0.id):\($0.reviewCount):\($0.correctCount):\($0.interval):\($0.difficulty):\(String(describing: $0.lastReviewedAt)):\(String(describing: $0.nextReviewAt))" }
        }
    }

    @MainActor private final class Server {
        unowned let f: Fixture
        var requests: [Data] = []
        var receipts: [UUID: Data] = [:]
        var rotations = 0
        var progressPosts = 0
        var examPassed = true
        var postStatus: Int?
        var rejectCode: String?
        var receiptMismatch: String?
        var failReads = false, failReadsAfterReset = false, failReadsAfterPost = false, loseResponse = false, deleted = false
        var progressWait: (() async -> Void)?
        var resetWait: (() async -> Void)?
        var afterCommit: (() -> Void)?
        init(_ f: Fixture) {
            self.f = f
            f.reply = { [self] request in try await respond(request) }
        }
        func respond(_ request: URLRequest) async throws -> (Int, Data) {
            if request.url!.path.hasSuffix("/reset") {
                let body = try Fixture.body(request); requests.append(body)
                await resetWait?()
                if let status = postStatus {
                    if status == 0 { throw URLError(.notConnectedToInternet) }
                    return (status, Data("temporary failure".utf8))
                }
                if let code = rejectCode { return Fixture.error(409, code) }
                let submission = try APIJSON.makeDecoder().decode(StudyProgressResetRequest.self, from: body)
                let receipt: Data
                if let old = receipts[submission.resetID] { receipt = old }
                else {
                    var results: [DeckResetResult] = []
                    for expected in submission.expectedDecks {
                        let index = try #require(f.decks.firstIndex { $0.id == expected.deckID })
                        guard f.epochs[index] == expected.progressEpoch else { return Fixture.error(409, "stale_progress_epoch") }
                        let rotated = UUID(); f.epochs[index] = rotated; rotations += 1
                        results.append(DeckResetResult(deckID: expected.deckID, progressEpoch: rotated, previousEpoch: expected.progressEpoch, clearedCardCount: 1))
                    }
                    let scope = UUID(uuidString: request.url!.pathComponents[2])!
                    receipt = try APIJSON.makeEncoder().encode(StudyProgressResetResponse(resetID: submission.resetID, deckID: scope, resetAt: Date(), decks: results))
                    receipts[submission.resetID] = receipt
                    afterCommit?()
                }
                if loseResponse { throw URLError(.networkConnectionLost) }
                if let mismatch = receiptMismatch {
                    var json = try JSONSerialization.jsonObject(with: receipt) as! [String: Any]
                    var decks = json["decks"] as! [[String: Any]]
                    switch mismatch {
                    case "identity": json["reset_id"] = UUID().uuidString
                    case "previous_epoch": decks[0]["previous_epoch"] = UUID().uuidString
                    case "missing_deck": decks = []
                    default: decks[0]["progress_epoch"] = decks[0]["previous_epoch"]
                    }
                    json["decks"] = decks
                    return (200, try JSONSerialization.data(withJSONObject: json))
                }
                return (200, receipt)
            }
            if request.httpMethod == "POST" {
                progressPosts += 1
                await progressWait?()
                return (200, try Fixture.receipt(request))
            }
            if deleted { return (404, Data()) }
            if failReads || (failReadsAfterReset && rotations > 0) || (failReadsAfterPost && !requests.isEmpty) { return (500, Data()) }
            let scope = UUID(uuidString: request.url!.pathComponents[2])!
            return (200, try f.progressResponse(scope))
        }
    }
}
