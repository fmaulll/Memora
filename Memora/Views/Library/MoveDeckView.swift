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

    private let accent = Color(
        red: 0.40,
        green: 0.40,
        blue: 0.95
    )
    private var canMoveUnderParent: Bool {
        deck.childDecks.isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {

            VStack(alignment: .leading, spacing: 6) {
                Text("Move Deck")
                    .font(
                        .custom(
                            "PlusJakartaSans-ExtraBold",
                            size: 28
                        )
                    )
                    .foregroundStyle(.white)

                Text("Choose where you want to move")
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 15
                        )
                    )
                    .foregroundStyle(.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .padding(.top, 20)

            ScrollView {
                VStack(spacing: 8) {

                    destinationRow(
                        title: "No Parent",
                        icon: "folder",
                        isSelected: selectedParent == nil
                    ) {
                        selectedParent = nil
                    }

                    ForEach(availableParentDecks) { candidate in
                        destinationRow(
                            title: candidate.title,
                            icon: "folder.fill",
                            isSelected: selectedParent?.id == candidate.id
                        ) {
                            selectedParent = candidate
                        }
                    }
                }
                .padding(.horizontal, 20)
            }

            Button {
                moveDeck()
            } label: {
                Text("Move")
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 16
                        )
                    )
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [
                                accent,
                                Color(
                                    red: 0.55,
                                    green: 0.36,
                                    blue: 0.96
                                )
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .buttonStyle(.plain)
            .disabled(
                selectedParent?.id == deck.parentDeck?.id ||
                (selectedParent == nil && deck.parentDeck == nil)
            )
            .opacity(
                selectedParent?.id == deck.parentDeck?.id ||
                (selectedParent == nil && deck.parentDeck == nil)
                    ? 0.4
                    : 1
            )
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            Color(
                red: 0.035,
                green: 0.035,
                blue: 0.16
            )
        )
        .preferredColorScheme(.dark)
        .safeAreaInset(edge: .top, spacing: 0) {
            BackNavigationBar {
                EmptyView()
            }
        }
        .navigationBarBackButtonHidden(true)
    }

    private var availableParentDecks: [StudyDeck] {
        guard canMoveUnderParent else {
            return []
        }

        return allDecks.filter { candidate in
            candidate.id != deck.id
            && candidate.parentDeck == nil
            && candidate.cards.filter { !$0.needsDeletion }.isEmpty
        }
    }

    private func destinationRow(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 14) {

                Image(systemName: icon)
                    .font(
                        .system(
                            size: 18,
                            weight: .medium
                        )
                    )
                    .foregroundStyle(
                        isSelected
                            ? accent
                            : .white.opacity(0.45)
                    )
                    .frame(width: 28)

                Text(title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 16
                        )
                    )
                    .foregroundStyle(.white)

                Spacer()

                Image(
                    systemName: isSelected
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 22))
                .foregroundStyle(
                    isSelected
                        ? accent
                        : .white.opacity(0.25)
                )
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(
                isSelected
                    ? accent.opacity(0.10)
                    : .white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected
                            ? accent.opacity(0.35)
                            : .white.opacity(0.08),
                        lineWidth: 1
                    )
            }
        }
        .buttonStyle(.plain)
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