import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct StudyProgressPersistenceTests {
    @Test func optionalEpochDefaultsSurviveDiskReopen() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let id = try autoreleasepool {
            let container = try fixture.open()
            let deck = fixture.insertDeck(in: container.mainContext)
            try container.mainContext.save()
            return deck.id
        }
        let container = try fixture.open()
        let deck = try #require(container.mainContext.fetch(FetchDescriptor<StudyDeck>()).first { $0.id == id })
        #expect(deck.cachedProgressEpoch == nil)
        #expect(deck.progressEpochFetchedAt == nil)
    }

    @Test func epochAndFreshnessRoundTripWithIndependentChapters() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let epochA = UUID(), epochB = UUID()
        let fetched = Date(timeIntervalSince1970: 1700000000.125)
        let ids = try autoreleasepool {
            let container = try fixture.open()
            let context = container.mainContext
            try fixture.activate(in: context)
            let parent = fixture.insertDeck(in: context)
            let a = fixture.insertDeck(in: context, parent: parent)
            let b = fixture.insertDeck(in: context, parent: parent)
            try context.save()
            let store = try fixture.store(context)
            try store.cacheEpoch(epochA, for: a.id, fetchedAt: fetched)
            try store.cacheEpoch(epochB, for: b.id, fetchedAt: fetched)
            return (parent.id, a.id, b.id)
        }
        let reopened = try fixture.open()
        let context = reopened.mainContext
        let decks = try context.fetch(FetchDescriptor<StudyDeck>())
        #expect(decks.first { $0.id == ids.0 }?.cachedProgressEpoch == nil)
        #expect(decks.first { $0.id == ids.1 }?.cachedProgressEpoch == epochA)
        #expect(decks.first { $0.id == ids.2 }?.cachedProgressEpoch == epochB)
        #expect(decks.first { $0.id == ids.1 }?.progressEpochFetchedAt == fetched)
    }

    @Test func childNeverUsesParentEpochAndUnknownCannotBecomeCreditableLater() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let context = container.mainContext
        try fixture.activate(in: context)
        let parent = fixture.insertDeck(in: context)
        parent.cachedProgressEpoch = UUID() // Even a preexisting parent value must not leak to the child.
        let child = fixture.insertDeck(in: context, parent: parent)
        try context.save()
        let store = try fixture.store(context)
        #expect(throws: StudyProgressStorageError.deckUnavailable) { try store.captureContext(deckID: parent.id) }
        let unknown = try store.captureContext(deckID: child.id)
        #expect(unknown.epoch == nil)
        let draft = try store.createDraft()
        try store.cacheEpoch(UUID(), for: child.id, fetchedAt: .now)
        #expect(unknown.epoch == nil)
        #expect(throws: StudyProgressStorageError.unknownEpoch) {
            try store.append(eventID: UUID(), cardID: UUID(), context: unknown, completedAt: .now, to: draft.id)
        }
        #expect(try store.pending(batchID: draft.id).events.isEmpty)
    }

    @Test func capturedEpochDoesNotChangeWhenCacheRefreshes() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let context = container.mainContext
        try fixture.activate(in: context)
        let deck = fixture.insertDeck(in: context)
        let store = try fixture.store(context)
        let old = UUID(), fresh = UUID()
        try store.cacheEpoch(old, for: deck.id, fetchedAt: Date(timeIntervalSince1970: 100))
        let captured = try store.captureContext(deckID: deck.id)
        let draft = try store.createDraft()
        try store.cacheEpoch(fresh, for: deck.id, fetchedAt: Date(timeIntervalSince1970: 200))
        try store.cacheEpoch(old, for: deck.id, fetchedAt: Date(timeIntervalSince1970: 150))
        try store.append(eventID: UUID(), cardID: UUID(), context: captured, completedAt: .now, to: draft.id)
        #expect(deck.cachedProgressEpoch == fresh)
        #expect(try store.pending(batchID: draft.id).events[0].progressEpoch == old)
    }

    @Test func draftEventsSurviveNewContextAndCompleteContainerReopen() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let eventID = UUID(), cardID = UUID()
        let occurred = Date(timeIntervalSince1970: 1700000000.123456)
        let saved = try autoreleasepool {
            let container = try fixture.open()
            let prepared = try fixture.prepare(in: container.mainContext)
            try prepared.store.append(eventID: eventID, cardID: cardID, context: prepared.capture,
                                      completedAt: occurred, to: prepared.draftID)
            let otherContext = ModelContext(container)
            let reloaded = try fixture.store(otherContext).pending(batchID: prepared.draftID)
            #expect(reloaded.events[0].id == eventID)
            return reloaded
        }
        let container = try fixture.open()
        let restored = try fixture.store(container.mainContext).pending(batchID: saved.id)
        #expect(restored.state == .draft)
        #expect(restored.events == saved.events)
        #expect(restored.events[0].cardID == cardID)
        #expect(restored.events[0].completedAt == occurred)
        #expect(restored.operationID == nil)
    }

    @Test func duplicateEventAppendIsIdempotentAndConflictingIdentityIsRejected() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let p = try fixture.prepare(in: container.mainContext)
        let id = UUID(), card = UUID(), occurred = Date()
        try p.store.append(eventID: id, cardID: card, context: p.capture, completedAt: occurred, to: p.draftID)
        try p.store.append(eventID: id, cardID: card, context: p.capture, completedAt: occurred, to: p.draftID)
        #expect(try p.store.pending(batchID: p.draftID).events.count == 1)
        #expect(throws: StudyProgressStorageError.eventIdentityConflict) {
            try p.store.append(eventID: id, cardID: UUID(), context: p.capture, completedAt: occurred, to: p.draftID)
        }
        let another = try p.store.createDraft()
        #expect(throws: StudyProgressStorageError.eventAlreadyRecordedInAnotherBatch) {
            try p.store.append(eventID: id, cardID: card, context: p.capture, completedAt: occurred, to: another.id)
        }
    }

    @Test func sealedBytesAndOperationIdentitySurviveRelaunchAndCacheDeletion() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let saved = try autoreleasepool {
            let container = try fixture.open()
            let p = try fixture.prepare(in: container.mainContext)
            try p.store.append(eventID: UUID(), cardID: UUID(), context: p.capture,
                               completedAt: Date(timeIntervalSince1970: 100), to: p.draftID)
            let sealed = try p.store.seal(draftID: p.draftID, completedAt: Date(timeIntervalSince1970: 100.25))
            #expect(sealed.operationID != sealed.batchID)
            let decoded = try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: sealed.payload)
            #expect(decoded.sessionID == sealed.operationID)
            #expect(decoded.completedAt == sealed.completedAt)
            try fixture.accounts.clear(modelContext: container.mainContext)
            return sealed
        }
        let container = try fixture.open()
        try fixture.activate(in: container.mainContext)
        let store = try fixture.store(container.mainContext)
        let retry = try store.sealedUpload(batchID: saved.batchID)
        #expect(retry == saved)
        #expect(try store.sealedUpload(batchID: saved.batchID) == saved)
        #expect(try container.mainContext.fetchCount(FetchDescriptor<StudyDeck>()) == 0)
    }

    @Test func sealedBatchesRejectAppendAndReseal() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let p = try fixture.prepare(in: container.mainContext)
        let eventID = UUID(), cardID = UUID(), occurred = Date()
        try p.store.append(eventID: eventID, cardID: cardID, context: p.capture, completedAt: occurred, to: p.draftID)
        let sealed = try p.store.seal(draftID: p.draftID, completedAt: occurred)
        #expect(throws: StudyProgressStorageError.sealedBatch) {
            try p.store.append(eventID: UUID(), cardID: UUID(), context: p.capture, completedAt: .now, to: p.draftID)
        }
        #expect(throws: StudyProgressStorageError.sealedBatch) {
            try p.store.seal(draftID: p.draftID, completedAt: .now)
        }
        #expect(try p.store.sealedUpload(batchID: p.draftID) == sealed)
    }

    @Test func emptyDraftCannotBeSealedAndErrorPreservesExistingData() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let p = try fixture.prepare(in: container.mainContext)
        #expect(throws: StudyProgressStorageError.emptyBatch) {
            try p.store.seal(draftID: p.draftID, completedAt: .now)
        }
        let snapshot = try p.store.pending(batchID: p.draftID)
        #expect(snapshot.state == .draft && snapshot.operationID == nil)
    }

    @Test func studyAllKeepsOwningDecksAndEpochsAndRejectsMixedEpochs() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let context = container.mainContext
        let p = try fixture.prepare(in: context)
        let second = fixture.insertDeck(in: context)
        try p.store.cacheEpoch(UUID(), for: second.id, fetchedAt: Date(timeIntervalSince1970: 100))
        let captureB = try p.store.captureContext(deckID: second.id)
        let time = Date()
        try p.store.append(eventID: UUID(), cardID: UUID(), context: p.capture, completedAt: time, to: p.draftID)
        try p.store.append(eventID: UUID(), cardID: UUID(), context: captureB, completedAt: time, to: p.draftID)
        try p.store.cacheEpoch(UUID(), for: second.id, fetchedAt: Date(timeIntervalSince1970: 200))
        let refreshed = try p.store.captureContext(deckID: second.id)
        #expect(throws: StudyProgressStorageError.mixedEpochs) {
            try p.store.append(eventID: UUID(), cardID: UUID(), context: refreshed, completedAt: time, to: p.draftID)
        }
        let sealed = try p.store.seal(draftID: p.draftID, completedAt: time)
        let request = try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: sealed.payload)
        #expect(request.decks.count == 2)
        #expect(request.decks.contains { $0.deckID == captureB.deckID && $0.progressEpoch == captureB.epoch })
        #expect(request.decks.contains { $0.deckID == p.capture.deckID && $0.progressEpoch == p.capture.epoch })
    }

    @Test func otherAccountsCannotListRetrieveAppendOrSealOldWork() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let context = container.mainContext
        let a = try fixture.prepare(in: context)
        try a.store.append(eventID: UUID(), cardID: UUID(), context: a.capture, completedAt: .now, to: a.draftID)
        try fixture.accounts.activate(userID: UUID(), modelContext: context)
        let b = try fixture.store(context)
        #expect(try b.pending().isEmpty)
        #expect(throws: StudyProgressStorageError.notFound) { try b.pending(batchID: a.draftID) }
        #expect(throws: StudyProgressStorageError.notFound) { try b.sealedUpload(batchID: a.draftID) }
        #expect(throws: StudyProgressStorageError.notFound) { try b.seal(draftID: a.draftID, completedAt: .now) }
        let draftB = try b.createDraft()
        #expect(throws: StudyProgressStorageError.wrongAccount) {
            try b.append(eventID: UUID(), cardID: UUID(), context: a.capture, completedAt: .now, to: draftB.id)
        }
        #expect(throws: CancellationError.self) { try a.store.pending() }
        #expect(throws: CancellationError.self) { try a.store.createDraft() }
        try fixture.activate(in: context)
        #expect(try fixture.store(context).pending().map(\.id) == [a.draftID])
        #expect(try context.fetchCount(FetchDescriptor<PendingStudyProgress>()) == 2)
    }

    @Test func logoutAndRejectedRefreshCleanupRetainDraftsButDisableAccess() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let context = container.mainContext
        let p = try fixture.prepare(in: context)
        context.insert(LocalUserProfile(userId: fixture.owner, name: "Learner"))
        try p.store.append(eventID: UUID(), cardID: UUID(), context: p.capture, completedAt: .now, to: p.draftID)
        // Both AuthManager.logout and rejected-refresh logout use this cleanup.
        try fixture.accounts.clear(modelContext: context)
        #expect(try context.fetchCount(FetchDescriptor<StudyDeck>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<LocalUserProfile>()) == 0)
        #expect(try context.fetchCount(FetchDescriptor<PendingStudyProgress>()) == 1)
        #expect(throws: CancellationError.self) { try p.store.pending() }
        #expect(throws: CancellationError.self) { try fixture.store(context) }
        try fixture.activate(in: context)
        #expect(try fixture.store(context).pending(batchID: p.draftID).events.count == 1)
    }

    @Test func suspendedAuthenticationCannotExposeOrModifyPendingWork() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let p = try fixture.prepare(in: container.mainContext)
        fixture.accounts.suspend()
        #expect(throws: CancellationError.self) { try p.store.pending() }
        #expect(throws: CancellationError.self) { try p.store.captureContext(deckID: p.capture.deckID) }
        try fixture.activate(in: container.mainContext)
        #expect(try fixture.store(container.mainContext).pending().count == 1)
        #expect(throws: CancellationError.self) { try p.store.pending() }
    }

    @Test func deletingCachedDecksAndCardsDoesNotDeleteEvents() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let container = try fixture.open()
        let context = container.mainContext
        let p = try fixture.prepare(in: context)
        let deck = try #require(context.fetch(FetchDescriptor<StudyDeck>()).first)
        let card = StudyFlashcardCard(front: "Question", back: "Answer", deck: deck)
        context.insert(card)
        try p.store.append(eventID: UUID(), cardID: card.id, context: p.capture, completedAt: .now, to: p.draftID)
        context.delete(deck)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<StudyFlashcardCard>()) == 0)
        #expect(try p.store.pending(batchID: p.draftID).events[0].cardID == card.id)
    }

    @Test func preS2DiskStoreMigratesWithoutLosingAnyExistingModels() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        let legacySchema = Schema([PreS2Models.Item.self, PreS2Models.StudyDeck.self,
            PreS2Models.StudyFlashcardCard.self, PreS2Models.LocalUserProfile.self])
        let ids = try autoreleasepool {
            let container = try fixture.open(schema: legacySchema)
            let context = container.mainContext
            let parent = PreS2Models.StudyDeck(title: "Parent", subject: "Science", educationLevel: "College")
            context.insert(parent)
            let chapter = PreS2Models.StudyDeck(title: "Chapter", subject: "Science", educationLevel: "College", parentDeck: parent, position: 3)
            context.insert(chapter)
            let card = PreS2Models.StudyFlashcardCard(front: "Preserve question", back: "Preserve answer", deck: chapter)
            context.insert(card)
            card.reviewCount = 7
            card.correctCount = 2
            card.interval = 5
            card.lastReviewedAt = Date(timeIntervalSince1970: 100)
            card.nextReviewAt = Date(timeIntervalSince1970: 200)
            card.frontImageData = Data([1, 2, 3])
            chapter.studyQueueIDs = [card.id]
            chapter.learningQueueIDs = [UUID()]
            chapter.studyCompletedCount = 12
            chapter.isStudySessionActive = true
            chapter.studyBatchCardIDs = [card.id]
            chapter.studyAllQueueIDs = [card.id]
            chapter.studyAllLearningQueueIDs = chapter.learningQueueIDs
            chapter.studyAllCompletedCount = 9
            chapter.isStudyAllSessionActive = true
            chapter.studyAllBatchCardIDs = [card.id]
            chapter.isFavorite = true
            chapter.requiresSubscription = true
            context.insert(PreS2Models.LocalUserProfile(userId: fixture.owner, name: "Existing user", email: "test@example.com"))
            context.insert(PreS2Models.Item(timestamp: Date(timeIntervalSince1970: 300)))
            try context.save()
            return (parent.id, chapter.id, card.id, chapter.learningQueueIDs)
        }
        try autoreleasepool {
            // This is the exact S2 app schema, without a custom migration plan.
            let container = try fixture.open()
            let context = container.mainContext
            let decks = try context.fetch(FetchDescriptor<StudyDeck>())
            #expect(decks.count == 2)
            let chapter = try #require(decks.first { $0.id == ids.1 })
            #expect(chapter.parentDeck?.id == ids.0 && chapter.position == 3)
            #expect(chapter.title == "Chapter" && chapter.isFavorite && chapter.requiresSubscription)
            #expect(chapter.studyQueueIDs == [ids.2] && chapter.learningQueueIDs == ids.3)
            #expect(chapter.studyCompletedCount == 12 && chapter.isStudySessionActive)
            #expect(chapter.studyBatchCardIDs == [ids.2])
            #expect(chapter.studyAllQueueIDs == [ids.2] && chapter.studyAllLearningQueueIDs == ids.3)
            #expect(chapter.studyAllCompletedCount == 9 && chapter.isStudyAllSessionActive)
            #expect(chapter.studyAllBatchCardIDs == [ids.2])
            #expect(decks.allSatisfy { $0.cachedProgressEpoch == nil && $0.progressEpochFetchedAt == nil })
            let cards = try context.fetch(FetchDescriptor<StudyFlashcardCard>())
            #expect(cards.count == 1)
            let card = try #require(cards.first)
            #expect(card.id == ids.2 && card.deck?.id == chapter.id)
            #expect(card.front == "Preserve question" && card.back == "Preserve answer")
            #expect(card.reviewCount == 7 && card.correctCount == 2 && card.interval == 5)
            #expect(card.lastReviewedAt == Date(timeIntervalSince1970: 100))
            #expect(card.nextReviewAt == Date(timeIntervalSince1970: 200))
            #expect(card.frontImageData == Data([1, 2, 3]))
            let profile = try #require(context.fetch(FetchDescriptor<LocalUserProfile>()).first)
            #expect(profile.userId == fixture.owner && profile.name == "Existing user")
            #expect(try context.fetch(FetchDescriptor<Item>()).first?.timestamp == Date(timeIntervalSince1970: 300))
            #expect(try context.fetchCount(FetchDescriptor<PendingStudyProgress>()) == 0)
            context.insert(PendingStudyProgress(accountID: fixture.owner))
            try context.save()
        }
        let reopened = try fixture.open()
        #expect(try reopened.mainContext.fetchCount(FetchDescriptor<StudyDeck>()) == 2)
        #expect(try reopened.mainContext.fetchCount(FetchDescriptor<PendingStudyProgress>()) == 1)
    }

    @Test func persistenceOperationsDoNotIssueHTTPRequests() throws {
        let fixture = try DiskFixture()
        defer { fixture.cleanUp() }
        ProgressPersistenceNetworkSpy.reset()
        #expect(URLProtocol.registerClass(ProgressPersistenceNetworkSpy.self))
        defer { URLProtocol.unregisterClass(ProgressPersistenceNetworkSpy.self) }
        let container = try fixture.open()
        let p = try fixture.prepare(in: container.mainContext)
        try p.store.append(eventID: UUID(), cardID: UUID(), context: p.capture, completedAt: .now, to: p.draftID)
        _ = try p.store.seal(draftID: p.draftID, completedAt: .now)
        _ = try p.store.pending()
        _ = try p.store.sealedUpload(batchID: p.draftID)
        #expect(ProgressPersistenceNetworkSpy.requestCount == 0)
    }

    @MainActor
    private final class DiskFixture {
        let owner = UUID()
        let directory: URL
        let suite = "StudyProgressPersistenceTests.\(UUID().uuidString)"
        let defaults: UserDefaults
        let accounts: LocalAccountStore

        init() throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = UserDefaults(suiteName: suite)!
            accounts = LocalAccountStore(defaults: defaults)
        }

        func open(schema: Schema = MemoraSchema.current) throws -> ModelContainer {
            let configuration = ModelConfiguration(schema: schema, url: directory.appendingPathComponent("default.store"))
            return try ModelContainer(for: schema, configurations: [configuration])
        }

        func activate(in context: ModelContext) throws {
            try accounts.activate(userID: owner, modelContext: context)
        }

        func store(_ context: ModelContext) throws -> StudyProgressStore {
            try StudyProgressStore(modelContext: context, accounts: accounts)
        }

        func insertDeck(in context: ModelContext, parent: StudyDeck? = nil) -> StudyDeck {
            let deck = StudyDeck(title: "Study", subject: "Science", educationLevel: "College", parentDeck: parent)
            context.insert(deck)
            return deck
        }

        func prepare(in context: ModelContext) throws -> (store: StudyProgressStore, capture: StudyProgressContext, draftID: UUID) {
            try activate(in: context)
            let deck = insertDeck(in: context)
            let store = try store(context)
            try store.cacheEpoch(UUID(), for: deck.id, fetchedAt: .now)
            return (store, try store.captureContext(deckID: deck.id), try store.createDraft().id)
        }

        func cleanUp() {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
    }
}

// No real network is used by this test. Any accidental URL Loading System
// request while the local operations run is counted and immediately rejected.
private final class ProgressPersistenceNetworkSpy: URLProtocol {
    private static let lock = NSLock()
    private static var count = 0
    static var requestCount: Int { lock.withLock { count } }
    static func reset() { lock.withLock { count = 0 } }

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.scheme == "http" || request.url?.scheme == "https"
    }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.lock.withLock { Self.count += 1 }
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }
    override func stopLoading() {}
}
