import SwiftUI
import SwiftData

struct MoveDeckView: View {

    let deck: StudyDeck

    @Query(
        filter: #Predicate<StudyDeck> { deck in
            !deck.needsDeletion
        },
        sort: \StudyDeck.createdAt
    )
    private var allDecks: [StudyDeck]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedParent: StudyDeck?

    var body: some View {
        List {

            Section {
                Button {
                    selectedParent = nil
                } label: {
                    destinationRow(
                        title: "No Parent",
                        isSelected: selectedParent == nil
                    )
                }
            }

            Section("Decks") {
                ForEach(availableParentDecks) { candidate in
                    Button {
                        selectedParent = candidate
                    } label: {
                        destinationRow(
                            title: candidate.title,
                            isSelected: selectedParent?.id == candidate.id
                        )
                    }
                }
            }
        }
        .navigationTitle("Move Deck")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Move") {
                    moveDeck()
                }
                .disabled(
                    selectedParent?.id == deck.parentDeck?.id ||
                    (selectedParent == nil && deck.parentDeck == nil)
                )
            }
        }
    }

    private var availableParentDecks: [StudyDeck] {
        allDecks.filter { candidate in
            candidate.id != deck.id
            && candidate.parentDeck == nil
            && candidate.cards.filter { !$0.needsDeletion }.isEmpty
        }
    }

    private func destinationRow(
        title: String,
        isSelected: Bool
    ) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .foregroundStyle(.tint)
            }
        }
    }

    private func moveDeck() {
        deck.parentDeck = selectedParent
        deck.isSynced = false

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print("❌ MOVE DECK ERROR:", error)
        }
    }
}