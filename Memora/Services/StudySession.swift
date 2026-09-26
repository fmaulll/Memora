import Foundation
import Observation
import SwiftData

struct StudySessionEpochBinding: Codable, Equatable {
    let accountID: UUID?
    let epoch: UUID?
    var draftID: UUID?
}

/// The existing local NEW/REVIEW engine, moved out of the view so its transition
/// and single-save persistence can be exercised together. No networking here.
@Observable @MainActor
final class StudySession {
    static let batchSize = 4
    let decks: [StudyDeck]
    let cards: [StudyFlashcardCard]
    let isCombined: Bool
    private(set) var sessionCards: [StudyFlashcardCard]
    private(set) var learningCards: [StudyFlashcardCard]
    private(set) var batchIDs: Set<UUID> = []
    private(set) var completedCount: Int
    private(set) var isComplete = false
    private(set) var presentationID = UUID()
    private(set) var isStarted = false
    private(set) var reachedFlushBoundary = false
    private var lastPresentedCardID: UUID?

    @ObservationIgnored let wasResuming: Bool
    @ObservationIgnored private var bindings: [UUID: StudySessionEpochBinding] = [:]
    @ObservationIgnored private var context: ModelContext?
    @ObservationIgnored private var accounts: LocalAccountStore?
    @ObservationIgnored private var ownerAtStart: UUID?
    @ObservationIgnored private var saveChanges: (() throws -> Void)?
    @ObservationIgnored private var failedAttempt: RatingAttempt?

    struct RatingAttempt {
        let presentationID: UUID
        let cardID: UUID
        let rating: CardRating
        let event: PendingStudyEvent?
        let capturedAccountID: UUID?
    }

    // Visible internally for deterministic failure/retry tests; no production UI.
    var retryEvent: PendingStudyEvent? { failedAttempt?.event }

    init(decks: [StudyDeck], combined: Bool) {
        self.decks = decks
        isCombined = combined
        cards = decks.flatMap(\.cards).filter { !$0.needsDeletion }
        let byID = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
        wasResuming = combined ? decks.contains { $0.isStudyAllSessionActive }
            : decks.first?.isStudySessionActive == true
        if wasResuming {
            sessionCards = decks.flatMap { combined ? $0.studyAllQueueIDs : $0.studyQueueIDs }.compactMap { byID[$0] }
            learningCards = decks.flatMap { combined ? $0.studyAllLearningQueueIDs : $0.learningQueueIDs }.compactMap { byID[$0] }
            completedCount = decks.reduce(0) { $0 + (combined ? $1.studyAllCompletedCount : $1.studyCompletedCount) }
            let saved = decks.flatMap { combined ? $0.studyAllBatchCardIDs : $0.studyBatchCardIDs }
            // Preserve the prior normal/combined fallback rules exactly.
            let fallback = !combined && !learningCards.isEmpty
                ? learningCards : Array(sessionCards.prefix(Self.batchSize))
            batchIDs = saved.isEmpty ? Set(fallback.map(\.id)) : Set(saved)
        } else {
            sessionCards = cards
            learningCards = []
            completedCount = 0
            batchIDs = Set(cards.prefix(Self.batchSize).map(\.id))
        }
    }

    var currentCard: StudyFlashcardCard? {
        let newCards = sessionCards.filter { batchIDs.contains($0.id) }
        if let card = newCards.first(where: { $0.id != lastPresentedCardID }) { return card }
        if let card = learningCards.first(where: { $0.id != lastPresentedCardID }) { return card }
        return newCards.first ?? learningCards.first
    }

    var isCurrentCardReview: Bool {
        guard let card = currentCard else { return false }
        return learningCards.contains { $0.id == card.id }
    }

    /// Called on screen appearance, not from an eagerly constructed navigation
    /// destination. Persist bindings even before the first answer or app exit.
    func start(context: ModelContext, accounts: LocalAccountStore? = nil,
               saveChanges: (() throws -> Void)? = nil) throws {
        guard !isStarted else { return }
        let accounts = accounts ?? .shared
        if self.context != nil, accounts.ownerID != ownerAtStart {
            throw StudyProgressStorageError.wrongAccount
        }
        self.context = context
        self.accounts = accounts
        self.saveChanges = saveChanges ?? { try context.save() }
        ownerAtStart = accounts.ownerID
        // Retain captured values on a failed start/save retry too.
        if bindings.isEmpty {
            let store = try? StudyProgressStore(modelContext: context, accounts: accounts)
            var capturedBindings: [UUID: StudySessionEpochBinding] = [:]
            for deck in decks {
                let data = isCombined ? deck.studyAllProgressBindingData : deck.studyProgressBindingData
                if wasResuming, let data {
                    capturedBindings[deck.id] = try JSONDecoder().decode(StudySessionEpochBinding.self, from: data)
                } else if !wasResuming, let captured = try? store?.captureContext(deckID: deck.id) {
                    capturedBindings[deck.id] = StudySessionEpochBinding(accountID: captured.accountID, epoch: captured.epoch)
                } else {
                    // Legacy resume and suspended/unknown startup stay local.
                    capturedBindings[deck.id] = StudySessionEpochBinding(accountID: accounts.ownerID, epoch: nil)
                }
            }
            bindings = capturedBindings
        }
        do {
            try stageSession()
            try self.saveChanges?()
            isStarted = true
        } catch {
            context.rollback()
            throw error
        }
    }

    /// expectedPresentation is captured by the rendered rating controls. A stale
    /// callback cannot accidentally rate the next card (including the same card
    /// changing from NEW to REVIEW when it is the only card in a batch).
    @discardableResult
    func rate(_ rating: CardRating, expectedPresentation: UUID, now: Date = .now) throws -> Bool {
        guard isStarted, expectedPresentation == presentationID,
              let context, let accounts else { return false }
        guard accounts.ownerID == ownerAtStart else { throw StudyProgressStorageError.wrongAccount }
        guard let card = currentCard else { return false }

        // Qualification is captured BEFORE any counters or queues mutate.
        let wasReview = learningCards.contains { $0.id == card.id }
        let attempt: RatingAttempt
        if let failedAttempt {
            guard failedAttempt.presentationID == expectedPresentation,
                  failedAttempt.cardID == card.id,
                  failedAttempt.rating == rating else { throw StudyProgressStorageError.corruptRecord }
            // Retry the same answer and identity; do not regenerate completion time.
            attempt = failedAttempt
        } else {
            let owner = card.deck.flatMap { owner in decks.first { $0.id == owner.id } }
            let binding = owner.flatMap { bindings[$0.id] }
            let blocked: Bool
            if wasReview, rating == .good, let owner, let epoch = binding?.epoch,
               (try? accounts.session()) != nil {
                blocked = try StudyProgressStore(modelContext: context, accounts: accounts)
                    .creditIsBlocked(deckID: owner.id, epoch: epoch, cardID: card.id)
            } else { blocked = false }
            let eligible = !blocked && wasReview && rating == .good && binding?.epoch != nil
                && binding?.accountID == accounts.ownerID && (try? accounts.session()) != nil
            let event: PendingStudyEvent?
            if eligible, let owner, let epoch = binding?.epoch {
                event = PendingStudyEvent(id: UUID(), cardID: card.id, deckID: owner.id,
                                          progressEpoch: epoch, completedAt: now)
            } else {
                event = nil
                #if DEBUG
                if wasReview && rating == .good {
                    print("STUDY PROGRESS: local only (unknown epoch, ownership, or suspended account)")
                }
                #endif
            }
            attempt = RatingAttempt(presentationID: presentationID, cardID: card.id,
                                    rating: rating, event: event, capturedAccountID: binding?.accountID)
        }

        let previous = (sessionCards, learningCards, batchIDs, completedCount, lastPresentedCardID, isComplete, bindings)
        let previousReview = CardReviewSnapshot(card)
        // No await between staging the model changes and committing them.
        do {
            applyLocalRating(attempt.rating, to: card)
            if let event = attempt.event, let owner = attempt.capturedAccountID,
               owner == accounts.ownerID, (try? accounts.session()) != nil,
               try !StudyProgressStore(modelContext: context, accounts: accounts)
                    .creditIsBlocked(deckID: event.deckID, epoch: event.progressEpoch, cardID: event.cardID) {
                let store = try StudyProgressStore(modelContext: context, accounts: accounts, saveChanges: saveChanges)
                let draftID = bindings[event.deckID]?.draftID
                _ = try store.appendStudyEvent(event, capturedAccountID: owner, draftID: draftID) { draftID in
                    self.bindings[event.deckID]?.draftID = draftID
                    try self.stageSession()
                }
                #if DEBUG
                print("STUDY PROGRESS captured: event=\(event.id) card=\(event.cardID) deck=\(event.deckID) epoch=\(event.progressEpoch)")
                #endif
            } else {
                try stageSession()
                try saveChanges?()
            }
            reachedFlushBoundary = isComplete || batchIDs != previous.2
            failedAttempt = nil
            presentationID = UUID()
            return true
        } catch {
            context.rollback()
            (sessionCards, learningCards, batchIDs, completedCount, lastPresentedCardID, isComplete, bindings) = previous
            // SwiftData rollback alone can leave already-observed model objects
            // exposing staged values. Restore those live values without a save.
            previousReview.restore(card)
            failedAttempt = attempt
            try stageSession()
            throw error
        }
    }

    private struct CardReviewSnapshot {
        let reviewCount: Int
        let correctCount: Int
        let lastReviewedAt: Date?
        let nextReviewAt: Date?
        let difficulty: Double
        let interval: Int

        init(_ card: StudyFlashcardCard) {
            reviewCount = card.reviewCount
            correctCount = card.correctCount
            lastReviewedAt = card.lastReviewedAt
            nextReviewAt = card.nextReviewAt
            difficulty = card.difficulty
            interval = card.interval
        }

        func restore(_ card: StudyFlashcardCard) {
            card.reviewCount = reviewCount
            card.correctCount = correctCount
            card.lastReviewedAt = lastReviewedAt
            card.nextReviewAt = nextReviewAt
            card.difficulty = difficulty
            card.interval = interval
        }
    }

    private func applyLocalRating(_ rating: CardRating, to card: StudyFlashcardCard) {
        lastPresentedCardID = card.id
        SpacedRepetitionService().review(card: card, rating: rating)
        if sessionCards.contains(where: { $0.id == card.id }) {
            sessionCards.removeAll { $0.id == card.id }
            switch rating {
            case .again, .hard: learningCards.insert(card, at: min(1, learningCards.count))
            case .good, .easy: learningCards.append(card)
            }
        } else {
            learningCards.removeAll { $0.id == card.id }
            switch rating {
            case .again, .hard: learningCards.insert(card, at: min(1, learningCards.count))
            case .good, .easy: completedCount += 1
            }
        }
        let hasActiveBatch = sessionCards.contains { batchIDs.contains($0.id) }
            || learningCards.contains { batchIDs.contains($0.id) }
        if !hasActiveBatch && !sessionCards.isEmpty {
            batchIDs = Set(sessionCards.prefix(Self.batchSize).map(\.id))
        }
        isComplete = sessionCards.isEmpty && learningCards.isEmpty
    }

    func saveForExit() throws {
        guard isStarted, let context, let accounts else { return }
        guard accounts.ownerID == ownerAtStart else { throw StudyProgressStorageError.wrongAccount }
        do {
            try stageSession()
            try saveChanges?()
        } catch {
            context.rollback()
            throw error
        }
    }

    /// Same queue/count formulas as the original view. Finishing clears local
    /// session bindings, but never deletes the durable pending draft.
    private func stageSession() throws {
        for deck in decks {
            let childIDs = Set(deck.cards.filter { !$0.needsDeletion }.map(\.id))
            let newIDs = sessionCards.filter { childIDs.contains($0.id) }.map(\.id)
            let reviewIDs = learningCards.filter { childIDs.contains($0.id) }.map(\.id)
            let data = try bindings[deck.id].map { try JSONEncoder().encode($0) }
            if isCombined {
                deck.studyAllQueueIDs = isComplete ? [] : newIDs
                deck.studyAllLearningQueueIDs = isComplete ? [] : reviewIDs
                deck.studyAllCompletedCount = isComplete ? 0 : max(childIDs.count - newIDs.count - reviewIDs.count, 0)
                deck.isStudyAllSessionActive = !isComplete && (!newIDs.isEmpty || !reviewIDs.isEmpty)
                deck.studyAllBatchCardIDs = isComplete ? [] : Array(batchIDs.intersection(childIDs))
                deck.studyAllProgressBindingData = isComplete ? nil : data
            } else {
                deck.studyQueueIDs = isComplete ? [] : sessionCards.map(\.id)
                deck.learningQueueIDs = isComplete ? [] : learningCards.map(\.id)
                deck.studyCompletedCount = isComplete ? 0 : completedCount
                deck.isStudySessionActive = !isComplete
                deck.studyBatchCardIDs = isComplete ? [] : Array(batchIDs)
                deck.studyProgressBindingData = isComplete ? nil : data
            }
        }
    }
}
