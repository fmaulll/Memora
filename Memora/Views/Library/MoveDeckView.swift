import SwiftUI
import SwiftData

struct MoveDeckView: View {

    let deck: StudyDeck

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var selectedParent: StudyDeck?
    @State private var availableParentDecks: [StudyDeck] = []
    @State private var searchText = ""

    // We need this separately because `selectedParent == nil`
    // can mean either:
    // 1. No Parent is actually selected
    // 2. State has not been initialized yet
    @State private var hasLoadedInitialParent = false

    // MARK: - Filtered Parents

    private var filteredParentDecks: [StudyDeck] {
        let query = searchText
            .trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard !query.isEmpty else {
            return availableParentDecks
        }

        return availableParentDecks.filter { candidate in
            candidate.title.localizedCaseInsensitiveContains(query) ||
            candidate.subject.localizedCaseInsensitiveContains(query)
        }
    }

    // MARK: - Current State

    private var currentParentID: UUID? {
        deck.parentDeck?.id
    }

    private var selectedParentID: UUID? {
        selectedParent?.id
    }

    private var hasChangedDestination: Bool {
        guard hasLoadedInitialParent else {
            return false
        }

        return selectedParentID != currentParentID
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {

            // MARK: - Header

            HStack {
                VStack(
                    alignment: .leading,
                    spacing: 4
                ) {
                    Text(
                        deck.parentDeck == nil
                            ? "Move Deck"
                            : "Move Chapter"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Bold",
                            size: 20
                        )
                    )
                    .foregroundStyle(
                        Color.appTextPrimary
                    )

                    Text("Choose a new parent deck")
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 13
                            )
                        )
                        .foregroundStyle(
                            Color.appTextSecondary
                        )
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(
                            .system(
                                size: 14,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(
                            Color.appTextSecondary
                        )
                        .frame(
                            width: 36,
                            height: 36
                        )
                        .background(
                            Color.appSurface,
                            in: Circle()
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // MARK: - Search

            searchField
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            // MARK: - Destinations

            destinationList

            // MARK: - Move Button

            Button {
                moveDeck()
            } label: {
                Text(
                    deck.parentDeck == nil
                        ? "Move Deck"
                        : "Move Chapter"
                )
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 15
                    )
                )
                .foregroundStyle(
                    hasChangedDestination
                        ? .white
                        : Color.appTextSecondary
                )
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    hasChangedDestination
                        ? Color.appAccent
                        : Color.appSurface,
                    in: RoundedRectangle(
                        cornerRadius: 8
                    )
                )
                .overlay {
                    RoundedRectangle(
                        cornerRadius: 8
                    )
                    .stroke(
                        hasChangedDestination
                            ? Color.appAccent
                            : Color.appBorder,
                        lineWidth: 1
                    )
                }
            }
            .buttonStyle(.plain)
            .disabled(!hasChangedDestination)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 20)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .background(Color.appBackground)
        .preferredColorScheme(.dark)
        .task {
            loadAvailableParentDecks()
        }
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 12) {

            Image(systemName: "magnifyingglass")
                .font(
                    .system(
                        size: 15,
                        weight: .medium
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )

            TextField(
                "Search decks",
                text: $searchText
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 15
                )
            )
            .foregroundStyle(
                Color.appTextPrimary
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(
                        systemName: "xmark.circle.fill"
                    )
                    .font(.system(size: 16))
                    .foregroundStyle(
                        Color.appTextSecondary
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            Color.appSurface,
            in: RoundedRectangle(
                cornerRadius: 8
            )
        )
        .overlay {
            RoundedRectangle(
                cornerRadius: 8
            )
            .stroke(
                Color.appBorder,
                lineWidth: 1
            )
        }
    }

    // MARK: - Destination List

    private var destinationList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {

                noParentRow

                ForEach(
                    filteredParentDecks
                ) { candidate in
                    parentRow(candidate)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    // MARK: - No Parent

    private var noParentRow: some View {

        let isSelected =
            hasLoadedInitialParent &&
            selectedParent == nil

        return Button {
            selectedParent = nil
        } label: {
            HStack(spacing: 14) {

                destinationIcon(
                    systemName: "folder",
                    isSelected: isSelected
                )

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text("No Parent")
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 15
                            )
                        )
                        .foregroundStyle(
                            Color.appTextPrimary
                        )

                    Text(
                        "Keep this as a standalone deck"
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 12
                        )
                    )
                    .foregroundStyle(
                        Color.appTextSecondary
                    )
                }

                Spacer(minLength: 12)

                selectionIndicator(
                    isSelected: isSelected
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                isSelected
                    ? Color.appAccent.opacity(0.08)
                    : Color.appSurface,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8
                )
                .stroke(
                    isSelected
                        ? Color.appAccent
                        : Color.appBorder,
                    lineWidth: isSelected
                        ? 1.5
                        : 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Parent Row

    private func parentRow(
        _ candidate: StudyDeck
    ) -> some View {

        let isSelected =
            selectedParent?.id == candidate.id

        return Button {
            selectedParent = candidate
        } label: {
            HStack(spacing: 14) {

                destinationIcon(
                    systemName: "folder.fill",
                    isSelected: isSelected
                )

                VStack(
                    alignment: .leading,
                    spacing: 5
                ) {
                    Text(candidate.title)
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 15
                            )
                        )
                        .foregroundStyle(
                            Color.appTextPrimary
                        )
                        .multilineTextAlignment(
                            .leading
                        )
                        .lineLimit(2)

                    HStack(spacing: 6) {

                        Text(
                            "\(candidate.childDecks.filter { !$0.needsDeletion }.count) chapter\(candidate.childDecks.filter { !$0.needsDeletion }.count == 1 ? "" : "s")"
                        )

                        if !candidate.subject.isEmpty {
                            Text("•")

                            Text(candidate.subject)
                                .lineLimit(1)
                        }
                    }
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 12
                        )
                    )
                    .foregroundStyle(
                        Color.appTextSecondary
                    )
                }

                Spacer(minLength: 12)

                selectionIndicator(
                    isSelected: isSelected
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(
                isSelected
                    ? Color.appAccent.opacity(0.08)
                    : Color.appSurface,
                in: RoundedRectangle(
                    cornerRadius: 8
                )
            )
            .overlay {
                RoundedRectangle(
                    cornerRadius: 8
                )
                .stroke(
                    isSelected
                        ? Color.appAccent
                        : Color.appBorder,
                    lineWidth: isSelected
                        ? 1.5
                        : 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Icon

    private func destinationIcon(
        systemName: String,
        isSelected: Bool
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isSelected
                        ? Color.appAccent.opacity(0.12)
                        : Color.appSecondarySurface
                )

            Image(systemName: systemName)
                .font(
                    .system(
                        size: 15,
                        weight: .semibold
                    )
                )
                .foregroundStyle(
                    isSelected
                        ? Color.appAccent
                        : Color.appTextSecondary
                )
        }
        .frame(
            width: 38,
            height: 38
        )
    }

    // MARK: - Selection Indicator

    @ViewBuilder
    private func selectionIndicator(
        isSelected: Bool
    ) -> some View {
        if isSelected {
            Image(
                systemName: "checkmark.circle.fill"
            )
            .font(.system(size: 20))
            .foregroundStyle(
                Color.appAccent
            )
        } else {
            Image(
                systemName: "chevron.right"
            )
            .font(
                .system(
                    size: 13,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                Color.appTextSecondary
            )
        }
    }

    // MARK: - Load Destinations

    private func loadAvailableParentDecks() {
        do {
            let descriptor =
                FetchDescriptor<StudyDeck>(
                    predicate:
                        #Predicate<StudyDeck> { candidate in
                            !candidate.needsDeletion
                        },
                    sortBy: [
                        SortDescriptor(
                            \StudyDeck.createdAt
                        )
                    ]
                )

            let decks =
                try modelContext.fetch(
                    descriptor
                )

            let movingDeckID = deck.id
            let currentParentID =
                deck.parentDeck?.id

            availableParentDecks =
                decks.filter { candidate in

                    // Cannot move a deck into itself.
                    guard candidate.id != movingDeckID else {
                        return false
                    }

                    // Chapters cannot become parents.
                    // Only root decks are valid destinations.
                    guard candidate.parentDeck == nil else {
                        return false
                    }

                    return true
                }

            // Restore the current parent selection.
            if let currentParentID {

                selectedParent =
                    availableParentDecks.first {
                        $0.id == currentParentID
                    }

                if selectedParent == nil {
                    selectedParent =
                        deck.parentDeck
                }

            } else {
                selectedParent = nil
            }

            hasLoadedInitialParent = true

        } catch {
            print(
                "❌ LOAD MOVE DESTINATIONS ERROR:",
                error
            )

            availableParentDecks = []
            selectedParent = deck.parentDeck
            hasLoadedInitialParent = true
        }
    }

    // MARK: - Move

    private func moveDeck() {
        guard hasChangedDestination else {
            return
        }

        deck.parentDeck = selectedParent
        deck.isSynced = false

        do {
            try modelContext.save()
            dismiss()
        } catch {
            print(
                "❌ MOVE DECK ERROR:",
                error
            )
        }
    }
}