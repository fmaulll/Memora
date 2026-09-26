import Foundation
import SwiftData
import Testing
@testable import Memora

// Disk fixtures and URLProtocol callbacks share the main actor. Serialize test
// cases so fixture creation cannot exhaust production network timeout budgets.
@Suite(.serialized)
@MainActor
struct StudyProgressSyncTests {
    @Test func freshFetchCachesRealEpochBeforeBinding() async throws {
        let f = try Fixture(known: false); defer { f.clean() }
        let s = f.session()
        await f.sync.prepare(s, context: f.context)
        #expect(f.decks[0].cachedProgressEpoch == f.epochs[0])
        #expect(f.requests.count == 1 && f.requests[0].timeoutInterval <= 3)
        try f.start(s)
        try f.finish(s)
        #expect(try f.store().pending().flatMap(\.events).first?.progressEpoch == f.epochs[0])
    }

    @Test func studyAllFetchesOneParentScopeAndIndependentEpochs() async throws {
        let f = try Fixture(chapters: 2, known: false); defer { f.clean() }
        let s = f.session(combined: true)
        await f.sync.prepare(s, context: f.context)
        #expect(f.requests.count == 1)
        #expect(f.requests[0].url?.path.contains(f.decks[0].parentDeck!.id.uuidString) == true)
        #expect(f.decks.map(\.cachedProgressEpoch) == f.epochs.map(Optional.some))
        #expect(f.decks[0].parentDeck?.cachedProgressEpoch == nil)
        try f.start(s); try f.finish(s)
        await f.sync.flush(context: f.context)
        #expect(try f.store().pending().isEmpty)
        let groups = try f.posts.map { try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: $0) }.flatMap(\.decks)
        #expect(Set(groups.map(\.deckID)) == Set(f.decks.map(\.id)))
        for group in groups {
            let index = try #require(f.decks.firstIndex { $0.id == group.deckID })
            #expect(group.progressEpoch == f.epochs[index])
        }
    }

    @Test(arguments: [true, false]) func offlinePreparationUsesOnlyExistingCache(known: Bool) async throws {
        let f = try Fixture(known: known); defer { f.clean() }
        let old = f.decks[0].cachedProgressEpoch
        f.reply = { _ in throw URLError(.notConnectedToInternet) }
        let s = f.session()
        await f.sync.prepare(s, context: f.context)
        try f.start(s); try f.finish(s)
        #expect(f.decks[0].cachedProgressEpoch == old)
        let events = try f.store().pending().flatMap(\.events)
        #expect(events.count == (known ? 1 : 0))
        #expect(events.first?.progressEpoch == old)
    }

    @Test(arguments: [true, false]) func resumedBindingNeverRefetchesOrChanges(combined: Bool) async throws {
        let f = try Fixture(chapters: combined ? 2 : 1); defer { f.clean() }
        let s = f.session(combined: combined); try f.start(s)
        try s.rate(.good, expectedPresentation: s.presentationID)
        try s.saveForExit()
        let old = f.decks.map(\.cachedProgressEpoch)
        for deck in f.decks { deck.cachedProgressEpoch = UUID() }
        try f.context.save()
        let resumed = f.session(combined: combined)
        await f.sync.prepare(resumed, context: f.context)
        #expect(f.requests.isEmpty)
        try f.start(resumed); try f.finish(resumed)
        for event in try f.store().pending().flatMap(\.events) {
            let index = try #require(f.decks.firstIndex { $0.id == event.deckID })
            #expect(event.progressEpoch == old[index])
        }
    }

    @Test func accountSwitchDuringPreparationCannotCacheOldResponse() async throws {
        let f = try Fixture(known: false); defer { f.clean() }
        let response = try f.progressResponse(f.decks[0].id)
        f.reply = { _ in
            try f.accounts.activate(userID: UUID(), modelContext: f.context)
            return (200, response)
        }
        await f.sync.prepare(f.session(), context: f.context)
        #expect(try f.context.fetch(FetchDescriptor<StudyDeck>()).isEmpty)
        #expect(try f.store().pending().isEmpty)
    }

    @Test func sealingPreservesTimesAcrossDaysAndRotatesBinding() throws {
        let f = try Fixture(cards: 3); defer { f.clean() }
        let s = f.session(); try f.start(s)
        for _ in 0..<3 { try s.rate(.good, expectedPresentation: s.presentationID) }
        let monday = Date(timeIntervalSince1970: 1700000000)
        try s.rate(.good, expectedPresentation: s.presentationID, now: monday)
        let store = try f.store()
        let originalID = try #require(store.pending().first?.id)
        try store.sealDrafts()
        let first = try #require(store.pending().first)
        let upload = try store.sealedUpload(batchID: first.id)
        f.decks[0].cachedProgressEpoch = UUID()
        try f.context.save()
        try s.rate(.good, expectedPresentation: s.presentationID, now: monday.addingTimeInterval(86400))
        let draft = try #require(store.pending().first { $0.state == .draft })
        #expect(draft.id != originalID && draft.id != first.id)
        #expect(try store.sealedUpload(batchID: first.id) == upload)
        let binding = try JSONDecoder().decode(StudySessionEpochBinding.self, from: #require(f.decks[0].studyProgressBindingData))
        #expect(binding.draftID == draft.id)
        try store.sealDrafts()
        let sealed = try store.pending()
        #expect(sealed.count == 2 && sealed.allSatisfy { $0.state == .sealed })
        #expect(Set(sealed.compactMap(\.completedAt)) == [monday, monday.addingTimeInterval(86400)])
        #expect(try store.sealedUpload(batchID: first.id) == upload)
    }

    @Test func distinctInstantsStaySeparateEvenInsideSameDeviceDay() throws {
        let f = try Fixture(); defer { f.clean() }
        let store = try f.store(), draft = try f.store().createDraft()
        let captured = try store.captureContext(deckID: f.decks[0].id)
        // These can straddle midnight in a plan timezone different from the device.
        for offset in [0.0, 1.0, 86400.0] {
            try store.append(eventID: UUID(), cardID: UUID(), context: captured,
                             completedAt: Date(timeIntervalSince1970: 1700000000 + offset), to: draft.id)
        }
        try store.sealDrafts()
        #expect(try store.pending().count == 3)
        #expect(try Set(store.pending().compactMap(\.operationID)).count == 3)
    }

    @Test func equalInstantsCanShareOneImmutableUpload() throws {
        let f = try Fixture(); defer { f.clean() }
        let store = try f.store(), draft = try f.store().createDraft()
        let captured = try store.captureContext(deckID: f.decks[0].id)
        for _ in 0..<2 {
            try store.append(eventID: UUID(), cardID: UUID(), context: captured,
                             completedAt: Date(timeIntervalSince1970: 1700000000), to: draft.id)
        }
        try store.sealDrafts()
        let item = try #require(store.pending().first)
        #expect(try store.pending().count == 1 && item.events.count == 2)
    }

    @Test func sealSaveFailureLeavesOriginalDraftAndEvents() throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        let before = try #require(f.store().pending().first)
        let failing = try StudyProgressStore(modelContext: f.context, accounts: f.accounts, saveChanges: { throw URLError(.cannotWriteToFile) })
        #expect(throws: (any Error).self) { try failing.sealDrafts() }
        let after = try #require(f.store().pending().first)
        #expect(after.id == before.id && after.events == before.events && after.state == .draft)
    }

    @Test func successValidatesReceiptDeletesOperationWithoutChangingCache() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        let newEpoch = UUID()
        f.decks[0].cachedProgressEpoch = newEpoch; try f.context.save()
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 1)
        #expect(try f.store().pending().isEmpty)
        #expect(f.decks[0].cachedProgressEpoch == newEpoch)
        #expect(f.requests[0].value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(f.requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer test-only")
    }

    @Test(arguments: [0, 500, 503, 408, 429]) func transientFailurePreservesExactBytesUntilLaterTrigger(status: Int) async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { _ in
            if status == 0 { throw URLError(.timedOut) }
            return (status, Data("temporary failure".utf8))
        }
        await f.sync.flush(context: f.context)
        let item = try #require(f.store().pending().first)
        let original = try f.store().sealedUpload(batchID: item.id)
        #expect(f.posts.count == 1 && item.state == .sealed)
        await f.sync.flush(context: f.context)
        #expect(f.posts == [original.payload, original.payload])
        #expect(try f.store().sealedUpload(batchID: item.id) == original)
        f.reply = nil
        await f.sync.flush(context: f.context)
        #expect(f.posts.last == original.payload && f.posts.count == 3)
        #expect(try f.store().pending().isEmpty)
    }

    @Test func lostAcknowledgementReopensAndAcceptsReplayWithSameIdentity() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        var originalReceipt: Data?
        f.reply = { request in
            originalReceipt = try Fixture.receipt(request)
            throw URLError(.networkConnectionLost)
        }
        await f.sync.flush(context: f.context)
        let sent = try #require(f.posts.first)
        try f.reopen()
        f.reply = { _ in (200, try #require(originalReceipt)) }
        await f.sync.flush(context: f.context)
        #expect(f.posts == [sent, sent])
        #expect(try f.store().pending().isEmpty)
    }

    @Test func acceptedResponseBeforeLocalCleanupCanBeReplayed() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        var acceptedReceipt: Data?
        f.reply = { request in
            let response = try Fixture.receipt(request)
            acceptedReceipt = response
            f.accounts.suspend() // Interruption after server acceptance, before local acknowledgement.
            return (200, response)
        }
        await f.sync.flush(context: f.context)
        let first = try #require(f.posts.first)
        try f.accounts.activate(userID: f.owner, modelContext: f.context)
        #expect(try f.store().pending().count == 1)
        f.reply = { _ in (200, try #require(acceptedReceipt)) }
        await f.sync.flush(context: f.context)
        #expect(f.posts == [first, first])
        #expect(try f.store().pending().isEmpty)
    }

    @Test func suspendedAccountAndForeignAccountCannotUploadPendingWork() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.accounts.suspend()
        await f.sync.flush(context: f.context)
        #expect(f.requests.isEmpty)
        try f.accounts.activate(userID: UUID(), modelContext: f.context)
        await f.sync.flush(context: f.context)
        #expect(f.requests.isEmpty)
        #expect(try f.store().pending().isEmpty)
        try f.accounts.activate(userID: f.owner, modelContext: f.context)
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 1)
        #expect(try f.store().pending().isEmpty)
    }

    @Test func successfulAuthRefreshResendsIdenticalBody() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { request in
            f.posts.count == 1 ? (401, Data()) : (200, try Fixture.receipt(request))
        }
        await f.sync.flush(context: f.context)
        #expect(f.refreshes == 1 && f.posts.count == 2 && f.posts[0] == f.posts[1])
        #expect(try f.store().pending().isEmpty)
    }

    @Test(arguments: [400, 401, 500]) func failedRefreshRetainsOperation(status: Int) async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { _ in (401, Data()) }
        f.refreshError = APIError.httpError(statusCode: status, message: nil)
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 1 && f.refreshes == 1)
        #expect(try f.store().pending().first?.state == .sealed)
    }

    @Test func failedSecondUnauthorizedDoesNotLoop() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture(); f.reply = { _ in (401, Data()) }
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 2 && f.refreshes == 1)
        #expect(try f.store().pending().first?.state == .sealed)
    }

    @Test func concurrentTriggersSerializeAndDrainNewlySealedWork() async throws {
        let f = try Fixture(cards: 2); defer { f.clean() }
        let s = f.session(); try f.start(s)
        for _ in 0..<3 { try s.rate(.good, expectedPresentation: s.presentationID) }
        let started = Signal(), release = Signal()
        f.reply = { request in
            if f.posts.count == 1 { started.open(); await release.wait() }
            return (200, try Fixture.receipt(request))
        }
        let first = Task { await f.sync.flush(context: f.context) }
        await started.wait()
        #expect(try f.store().pending().first?.state == .sealed)
        // Next answer commits immediately while the first upload is suspended.
        try s.rate(.good, expectedPresentation: s.presentationID)
        #expect(s.isComplete)
        #expect(try f.store().pending().contains { $0.state == .draft })
        await f.sync.flush(context: f.context)
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 1)
        release.open(); await first.value
        #expect(f.posts.count == 2)
        #expect(try f.store().pending().isEmpty)
    }

    @Test func staleReconciliationPreservesEpochAndDisablesActiveCredit() async throws {
        let f = try Fixture(cards: 3); defer { f.clean() }
        let s = f.session(); try f.start(s)
        for _ in 0..<4 { try s.rate(.good, expectedPresentation: s.presentationID) }
        let old = try #require(f.decks[0].cachedProgressEpoch)
        let fresh = UUID(); f.epochs[0] = fresh
        f.reply = { request in
            if request.httpMethod == "POST" { return Fixture.error(409, "stale_progress_epoch") }
            return (200, try f.progressResponse(f.decks[0].id))
        }
        await f.sync.flush(context: f.context)
        let item = try #require(f.store().pending().first)
        #expect(item.state == .terminalFailure && item.failureCode == "stale_progress_epoch")
        #expect(item.events.first?.progressEpoch == old && f.decks[0].cachedProgressEpoch == fresh)
        let binding = try JSONDecoder().decode(StudySessionEpochBinding.self, from: #require(f.decks[0].studyProgressBindingData))
        #expect(binding.epoch == old)
        let requests = f.requests.count
        try f.finish(s)
        await f.sync.flush(context: f.context)
        #expect(f.requests.count == requests)
        #expect(try f.store().pending().count == 1)
        let next = f.session(); try f.start(next); try f.finish(next)
        #expect(try f.store().pending().filter { $0.state == .draft }.flatMap(\.events).allSatisfy { $0.progressEpoch == fresh })
    }

    @Test func failedReconciliationRetriesGetOnlyAcrossRelaunch() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { request in request.httpMethod == "POST" ? Fixture.error(409, "stale_progress_epoch") : (500, Data()) }
        await f.sync.flush(context: f.context)
        #expect(try f.store().pending().first?.state == .reconciliationRequired)
        let posted = f.posts
        try f.reopen(); f.epochs[0] = UUID(); f.reply = nil
        await f.sync.flush(context: f.context)
        #expect(f.posts == posted && f.decks[0].cachedProgressEpoch == f.epochs[0])
        #expect(try f.store().pending().first?.state == .terminalFailure)
    }

    @Test func missingCardReconcilesMembershipWithoutEditingActiveQueue() async throws {
        let f = try Fixture(cards: 2); defer { f.clean() }
        let s = f.session(); try f.start(s)
        for _ in 0..<3 { try s.rate(.good, expectedPresentation: s.presentationID) }
        let remaining = s.learningCards.map(\.id)
        f.reply = { request in
            request.httpMethod == "POST" ? Fixture.error(422, "card_not_in_deck") : (200, try f.progressResponse(f.decks[0].id, emptyCards: true))
        }
        await f.sync.flush(context: f.context)
        let before = try #require(f.store().pending().first)
        let raw = try #require(f.context.fetch(FetchDescriptor<PendingStudyProgress>()).first?.payloadData)
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 1 && f.requests.count == 2)
        #expect(s.learningCards.map(\.id) == remaining)
        #expect(f.decks[0].cards.count == 2)
        #expect(before.state == .terminalFailure && before.failureCode == "card_not_in_deck")
        #expect(f.posts[0] == raw)
    }

    @Test(arguments: ["idempotency_conflict", "invalid_completion_time", "card_contract_error"]) func terminalErrorsNeverChangeOperationOrResubmit(code: String) async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { _ in Fixture.error(code == "idempotency_conflict" ? 409 : 422, code) }
        await f.sync.flush(context: f.context)
        let item = try #require(f.store().pending().first)
        let raw = try #require(f.posts.first)
        await f.sync.flush(context: f.context)
        #expect(f.posts == [raw] && item.state == .terminalFailure && item.failureCode == code)
        #expect(try f.store().pending().first?.operationID == item.operationID)
    }

    @Test(arguments: ["identity", "epoch", "missing_card", "duplicate", "timestamp"]) func invalidReceiptNeverDeletesOrRewritesOperation(mismatch: String) async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { request in
            var json = try JSONSerialization.jsonObject(with: Fixture.receipt(request)) as! [String: Any]
            var decks = json["decks"] as! [[String: Any]]
            switch mismatch {
            case "identity": json["session_id"] = UUID().uuidString
            case "timestamp": json["completed_at"] = "2020-01-01T00:00:00Z"
            case "epoch": decks[0]["progress_epoch"] = UUID().uuidString
            case "missing_card": decks[0]["accepted_card_ids"] = []
            default: decks[0]["already_learned_card_ids"] = decks[0]["accepted_card_ids"]
            }
            json["decks"] = decks
            return (200, try JSONSerialization.data(withJSONObject: json))
        }
        await f.sync.flush(context: f.context)
        #expect(try f.store().pending().first?.state == .sealed)
        let raw = try #require(f.posts.first)
        f.reply = nil; await f.sync.flush(context: f.context)
        #expect(f.posts == [raw, raw])
        #expect(try f.store().pending().isEmpty)
    }

    @Test func batchBoundariesDoNotChangeStudyAlgorithmOrUploadPerAnswer() throws {
        let f = try Fixture(cards: 5); defer { f.clean() }
        let s = f.session(); try f.start(s)
        for _ in 0..<4 {
            try s.rate(.good, expectedPresentation: s.presentationID)
            #expect(!s.reachedFlushBoundary)
        }
        #expect(try f.store().pending().isEmpty)
        try s.rate(.again, expectedPresentation: s.presentationID)
        #expect(try f.store().pending().isEmpty)
        for i in 0..<4 {
            try s.rate(.good, expectedPresentation: s.presentationID)
            #expect(s.reachedFlushBoundary == (i == 3))
        }
        #expect(s.batchIDs.count == 1 && s.completedCount == 4)
        #expect(f.requests.isEmpty)
        #expect(try f.store().pending().flatMap(\.events).count == 4)
        try f.finish(s)
        #expect(s.reachedFlushBoundary && s.isComplete)
    }

    @Test func alreadyLearnedOnlyAcknowledgementIsSuccess() async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { request in (200, try Fixture.receipt(request, replay: true)) }
        await f.sync.flush(context: f.context)
        #expect(try f.store().pending().isEmpty)
    }

    @Test(arguments: [200, 401]) func accountSwitchDuringUploadNeverCleansOrRefreshesOldOperation(status: Int) async throws {
        let f = try Fixture(); defer { f.clean() }
        try f.capture()
        f.reply = { request in
            let response = try Fixture.receipt(request)
            try f.accounts.activate(userID: UUID(), modelContext: f.context)
            return (status, response)
        }
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 1 && f.refreshes == 0)
        #expect(try f.store().pending().isEmpty)
        try f.accounts.activate(userID: f.owner, modelContext: f.context)
        #expect(try f.store().pending().count == 1)
        f.reply = nil
        await f.sync.flush(context: f.context)
        #expect(f.posts.count == 2 && f.posts[0] == f.posts[1])
    }

    @Test(arguments: [true, false]) func resumedBindingRotatesAfterSealOrAcknowledgement(acknowledged: Bool) async throws {
        let f = try Fixture(cards: 2); defer { f.clean() }
        let original = try autoreleasepool {
            let s = f.session(); try f.start(s)
            for _ in 0..<3 { try s.rate(.good, expectedPresentation: s.presentationID) }
            let item = try #require(f.store().pending().first)
            let sealed = try f.store().seal(draftID: item.id, completedAt: #require(item.events.first?.completedAt))
            if acknowledged { try f.store().acknowledge(sealed) }
            return sealed
        }
        try f.reopen()
        let resumed = f.session(); try f.start(resumed)
        try f.finish(resumed)
        let pending = try f.store().pending()
        let newDraft = try #require(pending.first { $0.state == .draft })
        #expect(newDraft.id != original.batchID && newDraft.events.count == 1)
        if !acknowledged { #expect(try f.store().sealedUpload(batchID: original.batchID) == original) }
    }

    @Test func staleMarkerSurvivesRelaunchAndStopsResumedCredit() async throws {
        let f = try Fixture(cards: 2); defer { f.clean() }
        try autoreleasepool {
            let s = f.session(); try f.start(s)
            for _ in 0..<3 { try s.rate(.good, expectedPresentation: s.presentationID) }
        }
        f.reply = { request in
            request.httpMethod == "POST" ? Fixture.error(409, "stale_progress_epoch") : (500, Data())
        }
        await f.sync.flush(context: f.context)
        try f.reopen()
        let resumed = f.session(); try f.start(resumed); try f.finish(resumed)
        #expect(try f.store().pending().count == 1)
        #expect(try f.store().pending().first?.state == .reconciliationRequired)
    }

    @MainActor final class Signal {
        private var ready = false
        private var waiters: [CheckedContinuation<Void, Never>] = []
        func wait() async { if !ready { await withCheckedContinuation { waiters.append($0) } } }
        func open() { ready = true; waiters.forEach { $0.resume() }; waiters = [] }
    }

    @MainActor final class Fixture {
        let directory: URL
        let suite = "StudyProgressSyncTests.\(UUID())"
        let defaults: UserDefaults
        let accounts: LocalAccountStore
        let owner = UUID()
        let host = UUID().uuidString.lowercased() + ".test"
        var container: ModelContainer?
        var context: ModelContext { container!.mainContext }
        var decks: [StudyDeck] = []
        var epochs: [UUID] = []
        var requests: [URLRequest] = []
        var posts: [Data] = []
        var reply: ((URLRequest) async throws -> (Int, Data))?
        var refreshError: Error?
        var refreshes = 0
        var sync: StudyProgressSync!
        var network: URLSession!

        init(chapters: Int = 1, cards: Int = 1, known: Bool = true) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = UserDefaults(suiteName: suite)!
            accounts = LocalAccountStore(defaults: defaults)
            container = try open()
            try accounts.activate(userID: owner, modelContext: context)
            let parent = chapters > 1 ? StudyDeck(title: "Parent", subject: "Science", educationLevel: "College") : nil
            if let parent { context.insert(parent) }
            for i in 0..<chapters {
                let deck = StudyDeck(title: "Chapter", subject: "Science", educationLevel: "College", parentDeck: parent, position: i)
                context.insert(deck)
                epochs.append(UUID()); deck.cachedProgressEpoch = known ? epochs[i] : nil
                for _ in 0..<cards { context.insert(StudyFlashcardCard(front: "Q", back: "A", deck: deck)) }
                decks.append(deck)
            }
            try context.save()
            let config = URLSessionConfiguration.ephemeral
            config.protocolClasses = [ProgressURLProtocol.self]
            network = URLSession(configuration: config)
            let client = APIClient(baseURL: URL(string: "https://\(host)")!, session: network, accounts: accounts, accessToken: { "test-only" })
            sync = StudyProgressSync(api: StudyProgressAPI(client: client), accounts: accounts, refresh: { [unowned self] in
                refreshes += 1
                if let refreshError { throw refreshError }
            })
            ProgressURLProtocol.handlers[host] = { [unowned self] request in
                requests.append(request)
                if request.httpMethod == "POST" { posts.append(try Self.body(request)) }
                if let reply { return try await reply(request) }
                if request.httpMethod == "POST" { return (200, try Self.receipt(request)) }
                let components = request.url!.pathComponents
                return (200, try progressResponse(UUID(uuidString: components[2])!))
            }
        }

        func session(combined: Bool = false) -> StudySession { StudySession(decks: decks, combined: combined) }
        func start(_ s: StudySession) throws { try s.start(context: context, accounts: accounts) }
        func finish(_ s: StudySession) throws {
            while !s.isComplete { try s.rate(.good, expectedPresentation: s.presentationID) }
        }
        func capture() throws { let s = session(); try start(s); try finish(s) }
        func store() throws -> StudyProgressStore { try StudyProgressStore(modelContext: context, accounts: accounts) }
        func open() throws -> ModelContainer {
            let schema = MemoraSchema.current
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: directory.appendingPathComponent("default.store"))])
        }
        func reopen() throws {
            decks = []; container = nil; container = try open()
            decks = try context.fetch(FetchDescriptor<StudyDeck>()).filter { $0.childDecks.isEmpty }.sorted { ($0.position ?? 0) < ($1.position ?? 0) }
        }
        func progressResponse(_ scope: UUID, emptyCards: Bool = false) throws -> Data {
            let selected = decks.enumerated().filter { $0.element.id == scope || $0.element.parentDeck?.id == scope }
            let facts = selected.map { index, deck in
                DeckLearningFacts(deckID: deck.id, progressEpoch: epochs[index], title: "Chapter", parentDeckID: deck.parentDeck?.id,
                                  position: index, generationStatus: "completed", cards: emptyCards ? [] : deck.cards.map { CardLearningFact(cardID: $0.id, learnedAt: nil) },
                                  learnedCardCount: 0, totalCardCount: emptyCards ? 0 : deck.cards.count, completionPercentage: 0, completed: false)
            }
            return try APIJSON.makeEncoder().encode(StudyProgressResponse(deckID: scope, decks: facts,
                summary: StudyProgressSummary(totalDeckCount: facts.count, completedDeckCount: 0, learnedCardCount: 0, totalCardCount: facts.reduce(0) { $0 + $1.totalCardCount })))
        }
        static func error(_ status: Int, _ code: String) -> (Int, Data) {
            (status, Data("{\"detail\":{\"code\":\"\(code)\",\"message\":\"test\"}}".utf8))
        }
        static func receipt(_ request: URLRequest, replay: Bool = false) throws -> Data {
            let submission = try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: body(request))
            return try APIJSON.makeEncoder().encode(StudyProgressSubmissionResponse(sessionID: submission.sessionID,
                completedAt: submission.completedAt, submittedAt: submission.completedAt.addingTimeInterval(60),
                decks: submission.decks.map { group in DeckSubmissionResult(deckID: group.deckID, progressEpoch: group.progressEpoch,
                    acceptedCardIDs: replay ? [] : group.learnedCards.map(\.cardID), alreadyLearnedCardIDs: replay ? group.learnedCards.map(\.cardID) : []) }))
        }
        static func body(_ request: URLRequest) throws -> Data {
            if let body = request.httpBody { return body }
            throw APIError.invalidResponse
        }
        func clean() {
            ProgressURLProtocol.handlers.removeValue(forKey: host)
            network.invalidateAndCancel()
            reply = nil; sync = nil; decks = []; container = nil
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

private final class ProgressURLProtocol: URLProtocol {
    @MainActor static var handlers: [String: (URLRequest) async throws -> (Int, Data)] = [:]
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host?.hasSuffix(".test") == true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        // Normalize URLSession's input stream once for byte-for-byte inspection.
        var captured = request
        if captured.httpBody == nil, let stream = captured.httpBodyStream {
            stream.open(); defer { stream.close() }
            var data = Data(), bytes = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable {
                let count = stream.read(&bytes, maxLength: bytes.count)
                if count <= 0 { break }
                data.append(contentsOf: bytes.prefix(count))
            }
            captured.httpBody = data
        }
        let request = captured
        Task { @MainActor in
            do {
                guard let handler = Self.handlers[request.url!.host!] else { throw URLError(.unsupportedURL) }
                let (status, data) = try await handler(request)
                let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
                client?.urlProtocol(self, didLoad: data)
                client?.urlProtocolDidFinishLoading(self)
            } catch { client?.urlProtocol(self, didFailWithError: error) }
        }
    }
    override func stopLoading() {}
}
