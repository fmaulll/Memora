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
        modelContext: ModelContext
    ) throws -> StudyDeck {
        let rootDeck: StudyDeck

        if let existingDeck {
            guard existingDeck.parentDeck == nil else {
                throw AIDeckCreationError.existingDeckMustBeRoot
            }

            guard existingDeck.cards.isEmpty else {
                throw AIDeckCreationError.existingDeckMustBeEmpty
            }

            guard existingDeck.childDecks.isEmpty else {
                throw AIDeckCreationError.existingDeckMustHaveNoChildren
            }

            rootDeck = existingDeck
            rootDeck.isSynced = false

        } else {
            rootDeck = StudyDeck(
                id: generatedDeck.id,
                title: generatedDeck.title,
                subject: generatedDeck.subject,
                educationLevel: generatedDeck.educationLevel,
                generationStatus: generatedDeck.generationStatus
            )

            rootDeck.isSynced = false
            modelContext.insert(rootDeck)
        }

        for chapter in generatedDeck.chapters {
            let chapterDeck = StudyDeck(
                id: chapter.id,
                title: chapter.title,
                subject: generatedDeck.subject,
                educationLevel: generatedDeck.educationLevel,
                parentDeck: rootDeck,
                generationStatus: chapter.generationStatus
            )

            chapterDeck.isSynced = false
            modelContext.insert(chapterDeck)
        }

        try modelContext.save()

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
