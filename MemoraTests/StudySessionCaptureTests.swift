import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct StudySessionCaptureTests {
    @Test func newGotItMovesToReviewWithoutEvent() throws {
        let f = try Fixture(); defer { f.clean() }
        let session = try f.start()
        let card = try #require(session.currentCard)
        try session.rate(.good, expectedPresentation: session.presentationID)
        #expect(session.learningCards.contains { $0.id == card.id })
        #expect(session.completedCount == 0)
        #expect(card.reviewCount == 1 && card.correctCount == 1)
        #expect(try f.events().isEmpty)
    }

    @Test func newAgainMovesToReviewWithoutEvent() throws {
        let f = try Fixture(); defer { f.clean() }
        let session = try f.start()
        try session.rate(.again, expectedPresentation: session.presentationID)
        #expect(session.learningCards.count == 1 && session.completedCount == 0)
        #expect(try f.events().isEmpty)
    }

    @Test func reviewAgainRequeuesWithoutEvent() throws {
        let f = try Fixture(); defer { f.clean() }
        let session = try f.start()
        try session.rate(.good, expectedPresentation: session.presentationID)
        #expect(session.isCurrentCardReview)
        try session.rate(.again, expectedPresentation: session.presentationID)
        #expect(session.learningCards.count == 1 && !session.isComplete)
        #expect(try f.events().isEmpty)
    }

    @Test func reviewGotItCapturesExactIdentityEpochTimeAndFinishes() throws {
        let f = try Fixture(); defer { f.clean() }
        let session = try f.start()
        let card = try #require(session.currentCard)
        let time = Date(timeIntervalSince1970: 1700000000.125)
        try session.rate(.good, expectedPresentation: session.presentationID)
        let savesBefore = f.saveCount
        try session.rate(.good, expectedPresentation: session.presentationID, now: time)
        #expect(f.saveCount == savesBefore + 1)
        let events = try f.events()
        #expect(events.count == 1)
        let event = try #require(events.first)
        #expect(event.cardID == card.id && event.deckID == f.decks[0].id)
        #expect(event.progressEpoch == f.decks[0].cachedProgressEpoch && event.completedAt == time)
        #expect(session.isComplete && session.completedCount == 1)
        #expect(!f.decks[0].isStudySessionActive && f.decks[0].studyProgressBindingData == nil)
        #expect(card.reviewCount == 2 && card.correctCount == 2)
        let records = try f.context.fetch(FetchDescriptor<PendingStudyProgress>())
        #expect(records.allSatisfy { $0.stateRawValue == "draft" && $0.operationID == nil && $0.payloadData == nil })
        try session.saveForExit()
        #expect(!f.decks[0].isStudySessionActive) // Closing completion cannot reactivate an empty session.
    }

    @Test func repeatedCallbacksCannotCompleteNewCardOrDuplicateReviewEvent() throws {
        let f = try Fixture(); defer { f.clean() }
        let s = try f.start()
        let newToken = s.presentationID
        #expect(try s.rate(.good, expectedPresentation: newToken))
        #expect(try !s.rate(.good, expectedPresentation: newToken))
        #expect(try f.events().isEmpty)
        let reviewToken = s.presentationID
        #expect(try s.rate(.good, expectedPresentation: reviewToken))
        #expect(try !s.rate(.good, expectedPresentation: reviewToken))
        #expect(try f.events().count == 1)
    }

    @Test func unknownEpochStaysLocalEvenAfterCacheRefresh() throws {
        let f = try Fixture(knownEpoch: false); defer { f.clean() }
        let s = try f.start()
        try s.rate(.good, expectedPresentation: s.presentationID)
        f.decks[0].cachedProgressEpoch = UUID()
        try f.context.save()
        try s.rate(.good, expectedPresentation: s.presentationID)
        #expect(s.isComplete && s.completedCount == 1)
        #expect(try f.events().isEmpty)
    }

    @Test func studyAllUsesIndependentChildEpochsNeverParent() throws {
        let f = try Fixture(chapters: 2); defer { f.clean() }
        let s = try f.start(combined: true)
        while !s.isComplete { try s.rate(.good, expectedPresentation: s.presentationID) }
        let events = try f.events()
        #expect(events.count == 2)
        for deck in f.decks {
            let event = try #require(events.first { $0.deckID == deck.id })
            #expect(event.cardID == deck.cards.first?.id)
            #expect(event.progressEpoch == deck.cachedProgressEpoch)
            #expect(event.deckID != deck.parentDeck?.id)
        }
        #expect(Set(events.map(\.progressEpoch)).count == 2)
    }

    @Test func studyAllUnknownChildDoesNotInheritKnownParentEpoch() throws {
        let f = try Fixture(chapters: 2); defer { f.clean() }
        f.decks[1].cachedProgressEpoch = nil
        f.decks[0].parentDeck?.cachedProgressEpoch = UUID()
        try f.context.save()
        let s = try f.start(combined: true)
        while !s.isComplete { try s.rate(.good, expectedPresentation: s.presentationID) }
        let events = try f.events()
        #expect(events.count == 1 && events.first?.deckID == f.decks[0].id)
    }

    @Test func studyAllMixedRatingsCaptureOnlyReviewGood() throws {
        let f = try Fixture(chapters: 4); defer { f.clean() }
        let s = try f.start(combined: true)
        var successes = Set<UUID>()
        var steps = 0
        while successes.count < 2 && steps < 20 {
            let card = try #require(s.currentCard)
            let owner = try #require(card.deck)
            let shouldComplete = owner.id == f.decks[0].id || owner.id == f.decks[1].id
            if s.isCurrentCardReview && shouldComplete {
                successes.insert(card.id)
                try s.rate(.good, expectedPresentation: s.presentationID)
            } else {
                try s.rate(s.isCurrentCardReview ? .again : .good, expectedPresentation: s.presentationID)
            }
            steps += 1
        }
        #expect(successes.count == 2)
        #expect(Set(try f.events().map(\.cardID)) == successes)
        #expect(!s.isComplete)
    }

    @Test func refreshedEpochCannotRelabelStartedSession() throws {
        let f = try Fixture(); defer { f.clean() }
        let old = f.decks[0].cachedProgressEpoch
        let s = try f.start()
        f.decks[0].cachedProgressEpoch = UUID()
        try f.context.save()
        while !s.isComplete { try s.rate(.good, expectedPresentation: s.presentationID) }
        #expect(try f.events().first?.progressEpoch == old)
    }

    @Test func normalResumePreservesBindingReviewQueueAndDraftAcrossDiskReopen() throws {
        let f = try Fixture(cardsPerDeck: 2); defer { f.clean() }
        let old = f.decks[0].cachedProgressEpoch
        let saved = try autoreleasepool { () -> (Set<UUID>, [UUID], [UUID]) in
            let s = try f.start()
            while try f.events().isEmpty { try s.rate(.good, expectedPresentation: s.presentationID) }
            try s.saveForExit()
            return (s.batchIDs, s.sessionCards.map(\.id), s.learningCards.map(\.id))
        }
        try f.reopen()
        f.decks[0].cachedProgressEpoch = UUID()
        try f.context.save()
        let resumed = try f.start()
        #expect(resumed.batchIDs == saved.0)
        #expect(resumed.sessionCards.map(\.id) == saved.1 && resumed.learningCards.map(\.id) == saved.2)
        #expect(resumed.completedCount == 1)
        while !resumed.isComplete { try resumed.rate(.good, expectedPresentation: resumed.presentationID) }
        let events = try f.events()
        #expect(events.count == 2 && events.allSatisfy { $0.progressEpoch == old })
        #expect(try f.context.fetchCount(FetchDescriptor<PendingStudyProgress>()) == 1)
    }

    @Test func studyAllResumePreservesEveryChapterBinding() throws {
        let f = try Fixture(chapters: 2, cardsPerDeck: 2); defer { f.clean() }
        let epochs = Dictionary(uniqueKeysWithValues: f.decks.map { ($0.id, $0.cachedProgressEpoch!) })
        let saved = try autoreleasepool { () -> Set<UUID> in
            let s = try f.start(combined: true)
            try s.rate(.good, expectedPresentation: s.presentationID)
            try s.rate(.again, expectedPresentation: s.presentationID)
            try s.saveForExit()
            return s.batchIDs
        }
        try f.reopen()
        for deck in f.decks { deck.cachedProgressEpoch = UUID() }
        try f.context.save()
        let resumed = try f.start(combined: true)
        #expect(resumed.batchIDs == saved && resumed.learningCards.count == 2)
        while !resumed.isComplete { try resumed.rate(.good, expectedPresentation: resumed.presentationID) }
        let events = try f.events()
        #expect(events.count == 4)
        #expect(events.allSatisfy { $0.progressEpoch == epochs[$0.deckID] })
    }

    @Test func legacyResumeWithoutBindingStaysUnknown() throws {
        let f = try Fixture(); defer { f.clean() }
        let deck = f.decks[0]
        deck.isStudySessionActive = true
        deck.learningQueueIDs = deck.cards.map(\.id)
        deck.studyBatchCardIDs = deck.learningQueueIDs
        try f.context.save()
        let s = try f.start()
        #expect(s.isCurrentCardReview)
        try s.rate(.good, expectedPresentation: s.presentationID)
        #expect(s.isComplete)
        #expect(try f.events().isEmpty)
    }

    @Test func fourCardBatchDoesNotAdvanceUntilAllFourFinishReview() throws {
        let f = try Fixture(cardsPerDeck: 6); defer { f.clean() }
        let s = try f.start()
        let firstBatch = s.batchIDs
        #expect(firstBatch.count == 4)
        while s.completedCount < 4 {
            let currentID = try #require(s.currentCard).id
            #expect(firstBatch.contains(currentID))
            try s.rate(.good, expectedPresentation: s.presentationID)
            if s.completedCount < 4 { #expect(s.batchIDs == firstBatch) }
        }
        #expect(s.batchIDs.count == 2 && firstBatch.isDisjoint(with: s.batchIDs))
        while !s.isComplete { try s.rate(.good, expectedPresentation: s.presentationID) }
        #expect(s.completedCount == 6)
        #expect(try f.events().count == 6)
    }

    @Test func failedAtomicSaveRestoresQueuesStatsAndStableRetryIdentity() throws {
        let f = try Fixture(); defer { f.clean() }
        let s = try f.start()
        let card = try #require(s.currentCard)
        try s.rate(.good, expectedPresentation: s.presentationID)
        let token = s.presentationID
        let completedAt = Date(timeIntervalSince1970: 1700000000.5)
        f.failSave = true
        #expect(throws: SaveFailure.self) {
            try s.rate(.good, expectedPresentation: token, now: completedAt)
        }
        let retry = try #require(s.retryEvent)
        #expect(retry.completedAt == completedAt)
        #expect(s.completedCount == 0 && s.isCurrentCardReview && !s.isComplete)
        #expect(s.presentationID == token)
        #expect(card.reviewCount == 1)
        #expect(card.correctCount == 1)
        #expect(try f.events().isEmpty)
        let reloaded = ModelContext(f.container!)
        let persisted = try #require(reloaded.fetch(FetchDescriptor<StudyDeck>()).first)
        #expect(persisted.isStudySessionActive && persisted.learningQueueIDs == [card.id])
        #expect(persisted.cards.first?.reviewCount == 1)
        #expect(try reloaded.fetchCount(FetchDescriptor<PendingStudyProgress>()) == 0)
        #expect(throws: SaveFailure.self) { try s.rate(.good, expectedPresentation: token, now: .now) }
        #expect(s.retryEvent == retry)
        f.failSave = false
        let before = f.saveCount
        try s.rate(.good, expectedPresentation: token, now: .now)
        #expect(f.saveCount == before + 1 && s.isComplete)
        #expect(try f.events() == [retry])
        #expect(card.reviewCount == 2)
        #expect(card.correctCount == 2)
    }

    @Test func failureAppendingExistingDraftDoesNotLoseEarlierEvents() throws {
        let f = try Fixture(cardsPerDeck: 2); defer { f.clean() }
        let s = try f.start()
        while try f.events().isEmpty { try s.rate(.good, expectedPresentation: s.presentationID) }
        let first = try f.events()
        #expect(s.isCurrentCardReview)
        f.failSave = true
        #expect(throws: SaveFailure.self) { try s.rate(.good, expectedPresentation: s.presentationID) }
        #expect(try f.events() == first)
        #expect(s.completedCount == 1)
        f.failSave = false
        try s.rate(.good, expectedPresentation: s.presentationID)
        #expect(try f.events().count == 2)
    }

    @Test func suspendedAccountAllowsLocalStudyButNoPendingWork() throws {
        let f = try Fixture(); defer { f.clean() }
        let s = try f.start()
        try s.rate(.good, expectedPresentation: s.presentationID)
        f.accounts.suspend()
        try s.rate(.good, expectedPresentation: s.presentationID)
        #expect(s.isComplete)
        #expect(try f.events().isEmpty)
    }

    @Test func suspendedStartupRemainsUncreditedAfterActivation() throws {
        let f = try Fixture(); defer { f.clean() }
        f.accounts.suspend()
        let s = try f.start()
        try s.rate(.good, expectedPresentation: s.presentationID)
        try f.accounts.activate(userID: f.owner, modelContext: f.context)
        try s.rate(.good, expectedPresentation: s.presentationID)
        #expect(s.isComplete)
        #expect(try f.events().isEmpty)
    }

    @Test func accountSwitchRejectsOldSessionWithoutCreatingForeignWork() throws {
        let f = try Fixture(); defer { f.clean() }
        let s = try f.start()
        try s.rate(.good, expectedPresentation: s.presentationID)
        try f.accounts.activate(userID: UUID(), modelContext: f.context)
        #expect(throws: StudyProgressStorageError.wrongAccount) {
            try s.rate(.good, expectedPresentation: s.presentationID)
        }
        #expect(try f.events().isEmpty)
    }

    @Test func normalAndCombinedSessionsKeepSeparateEpochBindings() throws {
        let f = try Fixture(chapters: 2); defer { f.clean() }
        let normal = StudySession(decks: [f.decks[0]], combined: false)
        try normal.start(context: f.context, accounts: f.accounts)
        let original = f.decks[0].cachedProgressEpoch
        let latest = UUID()
        f.decks[0].cachedProgressEpoch = latest
        try f.context.save()
        _ = try f.start(combined: true)
        let normalBinding = try JSONDecoder().decode(StudySessionEpochBinding.self, from: #require(f.decks[0].studyProgressBindingData))
        let combinedBinding = try JSONDecoder().decode(StudySessionEpochBinding.self, from: #require(f.decks[0].studyAllProgressBindingData))
        #expect(normalBinding.epoch == original && combinedBinding.epoch == latest)
    }

    @Test func failedStartRetainsOriginalEpochAndCannotSwitchOwners() throws {
        let f = try Fixture(); defer { f.clean() }
        let original = f.decks[0].cachedProgressEpoch
        let s = StudySession(decks: f.decks, combined: false)
        #expect(throws: SaveFailure.self) {
            try s.start(context: f.context, accounts: f.accounts, saveChanges: { throw SaveFailure() })
        }
        f.decks[0].cachedProgressEpoch = UUID()
        try f.context.save()
        try s.start(context: f.context, accounts: f.accounts)
        while !s.isComplete { try s.rate(.good, expectedPresentation: s.presentationID) }
        #expect(try f.events().first?.progressEpoch == original)

        let another = StudySession(decks: f.decks, combined: false)
        #expect(throws: SaveFailure.self) {
            try another.start(context: f.context, accounts: f.accounts, saveChanges: { throw SaveFailure() })
        }
        try f.accounts.activate(userID: UUID(), modelContext: f.context)
        #expect(throws: StudyProgressStorageError.wrongAccount) {
            try another.start(context: f.context, accounts: f.accounts)
        }
    }

    private struct SaveFailure: Error {}

    @MainActor
    private final class Fixture {
        let directory: URL
        let suite = "StudySessionCaptureTests.\(UUID())"
        let defaults: UserDefaults
        let accounts: LocalAccountStore
        let owner = UUID()
        var container: ModelContainer?
        var decks: [StudyDeck] = []
        var context: ModelContext { container!.mainContext }
        var saveCount = 0
        var failSave = false

        init(chapters: Int = 1, cardsPerDeck: Int = 1, knownEpoch: Bool = true) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            defaults = UserDefaults(suiteName: suite)!
            accounts = LocalAccountStore(defaults: defaults)
            container = try open()
            try accounts.activate(userID: owner, modelContext: context)
            let parent: StudyDeck?
            if chapters > 1 {
                parent = StudyDeck(title: "Parent", subject: "Science", educationLevel: "College")
                context.insert(parent!)
            } else { parent = nil }
            for i in 0..<chapters {
                let deck = StudyDeck(title: "Chapter \(i)", subject: "Science", educationLevel: "College", parentDeck: parent, position: i)
                context.insert(deck)
                deck.cachedProgressEpoch = knownEpoch ? UUID() : nil
                for j in 0..<cardsPerDeck {
                    context.insert(StudyFlashcardCard(front: "Question \(j)", back: "Answer", deck: deck))
                }
                decks.append(deck)
            }
            try context.save()
        }

        func start(combined: Bool = false) throws -> StudySession {
            let session = StudySession(decks: decks, combined: combined)
            try session.start(context: context, accounts: accounts) { [unowned self] in
                saveCount += 1
                if failSave { throw SaveFailure() }
                try context.save()
            }
            return session
        }

        func events() throws -> [PendingStudyEvent] {
            try context.fetch(FetchDescriptor<PendingStudyProgress>()).flatMap { try $0.events() }
        }

        func open() throws -> ModelContainer {
            let schema = MemoraSchema.current
            return try ModelContainer(for: schema, configurations: [ModelConfiguration(schema: schema, url: directory.appendingPathComponent("default.store"))])
        }

        func reopen() throws {
            decks = []
            container = nil
            container = try open()
            decks = try context.fetch(FetchDescriptor<StudyDeck>()).filter { $0.childDecks.isEmpty }
                .sorted { ($0.position ?? 0) < ($1.position ?? 0) }
        }

        func clean() {
            defaults.removePersistentDomain(forName: suite)
            decks = []
            container = nil
            try? FileManager.default.removeItem(at: directory)
        }
    }
}
