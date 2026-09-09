import Foundation
import SwiftData

@MainActor
final class AIDeckCreationService {

    static let shared = AIDeckCreationService()

    private init() {
    }

    func createDeck(
        from generatedDeck: GeneratedDeckResponse,
        existingDeck: StudyDeck?,
        modelContext: ModelContext,
        requiresSubscription: Bool = false
    ) throws -> StudyDeck {
        let id = generatedDeck.id
        if let saved = try modelContext.fetch(FetchDescriptor<StudyDeck>(predicate: #Predicate { $0.id == id })).first {
            if let account = AuthManager.shared.currentUser?.id {
                GenerationRequestStore.shared.complete(account: account, deckID: id)
            }
            return saved
        }
        if let existingDeck {
            guard existingDeck.parentDeck == nil else { throw AIDeckCreationError.existingDeckMustBeRoot }
            guard existingDeck.cards.isEmpty else { throw AIDeckCreationError.existingDeckMustBeEmpty }
            guard existingDeck.childDecks.isEmpty else { throw AIDeckCreationError.existingDeckMustHaveNoChildren }
            // The server creates a new parent ID. Retire only the empty placeholder.
            existingDeck.needsDeletion = true
        }
        let rootDeck = StudyDeck(id: generatedDeck.id, title: generatedDeck.title,
                                 subject: generatedDeck.subject, educationLevel: generatedDeck.educationLevel,
                                 generationStatus: generatedDeck.generationStatus)
        rootDeck.isSynced = true
        rootDeck.isAIGenerated = true
        modelContext.insert(rootDeck)

        rootDeck.requiresSubscription = rootDeck.requiresSubscription || requiresSubscription

        for (index, chapter) in generatedDeck.chapters.enumerated() {
            let chapterDeck = StudyDeck(
                id: chapter.id,
                title: chapter.title,
                subject: generatedDeck.subject,
                educationLevel: generatedDeck.educationLevel,
                parentDeck: rootDeck,
                generationStatus: chapter.generationStatus,
                position: chapter.position ?? (index + 1)
            )

            chapterDeck.requiresSubscription = rootDeck.requiresSubscription
            chapterDeck.isSynced = true
            chapterDeck.isAIGenerated = true
            modelContext.insert(chapterDeck)
        }

        try modelContext.save()

        if let account = AuthManager.shared.currentUser?.id {
            GenerationRequestStore.shared.complete(account: account, deckID: rootDeck.id)
        }
        return rootDeck
    }
}

enum AIDeckCreationError: LocalizedError {
    case existingDeckMustBeRoot
    case existingDeckMustBeEmpty
    case existingDeckMustHaveNoChildren

    var errorDescription: String? {
        switch self {
        case .existingDeckMustBeRoot:
            return "AI decks must be created from a root deck."
        case .existingDeckMustBeEmpty:
            return "AI decks can only be created from an empty deck."
        case .existingDeckMustHaveNoChildren:
            return "AI decks can only be created from a deck without sub-decks."
        }
    }
}
