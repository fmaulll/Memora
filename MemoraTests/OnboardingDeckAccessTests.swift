import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct OnboardingDeckAccessTests {
    @Test func firstDeckAndChaptersRemainLockedAfterReload() throws {
        let container = try makeContainer()
        let deck = try AIDeckCreationService.shared.createDeck(
            from: generatedDeck(),
            existingDeck: nil,
            modelContext: container.mainContext,
            requiresSubscription: true
        )

        let reloadedContext = ModelContext(container)
        let savedDecks = try reloadedContext.fetch(FetchDescriptor<StudyDeck>())
        #expect(savedDecks.count == 2)
        #expect(savedDecks.allSatisfy { $0.needsSubscription })
        #expect(savedDecks.contains { $0.id == deck.id && $0.requiresSubscription })
    }

    @Test func ordinaryDeckCreationDoesNotRequireSubscription() throws {
        let container = try makeContainer()
        let deck = try AIDeckCreationService.shared.createDeck(
            from: generatedDeck(),
            existingDeck: nil,
            modelContext: container.mainContext
        )
        #expect(!deck.needsSubscription)
        #expect(deck.childDecks.allSatisfy { !$0.needsSubscription })
    }

    @Test func chapterInheritsLockedParent() throws {
        let container = try makeContainer()
        let parent = StudyDeck(title: "First deck", subject: "Biology", educationLevel: "University")
        parent.requiresSubscription = true
        container.mainContext.insert(parent)
        let child = StudyDeck(title: "Chapter", subject: "Biology", educationLevel: "University", parentDeck: parent)
        container.mainContext.insert(child)
        #expect(!child.requiresSubscription)
        #expect(child.needsSubscription)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: StudyDeck.self, StudyFlashcardCard.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func generatedDeck() -> GeneratedDeckResponse {
        GeneratedDeckResponse(
            id: UUID(), title: "Biology", subject: "Science", educationLevel: "University",
            learningLanguage: "English", generationStatus: "generating",
            chapters: [GeneratedChapter(id: UUID(), title: "Cells", generationStatus: "generating")]
        )
    }
}
