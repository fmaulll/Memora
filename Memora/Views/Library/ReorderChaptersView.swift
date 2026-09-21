import SwiftUI
import SwiftData

struct ReorderChaptersView: View {

    let parentDeck: StudyDeck

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var chapters: [StudyDeck] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {

                    description
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    if chapters.isEmpty {
                        emptyState
                    } else {
                        chapterList
                    }
                }
            }
            .navigationTitle("Reorder Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        saveOrder()
                    }
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
        .onAppear {
            loadChapters()
        }
    }

    private func saveOrder() {
        let orderedChapterIds = chapters.map(\.id)

        Task {
            do {
                _ = try await DeckAPI.shared.reorderChapters(
                    parentDeckId: parentDeck.id,
                    chapterIds: orderedChapterIds
                )

                await MainActor.run {
                    for (index, chapter) in chapters.enumerated() {
                        chapter.position = index
                    }

                    do {
                        try modelContext.save()

                        print(
                            "✅ CHAPTER ORDER SYNCED:",
                            chapters.count,
                            "chapters"
                        )

                        dismiss()

                    } catch {
                        print(
                            "❌ FAILED TO SAVE CHAPTER ORDER LOCALLY:",
                            error
                        )
                    }
                }

            } catch {
                print(
                    "❌ CHAPTER REORDER FAILED:",
                    error
                )
            }
        }
    }

    // MARK: - Description

    private var description: some View {
        HStack {
            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(parentDeck.title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )
                    .foregroundStyle(
                        Color.appTextPrimary
                    )

                Text("Drag chapters to change their order.")
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
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
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

    private func moveChapter(
        from source: IndexSet,
        to destination: Int
    ) {
        chapters.move(
            fromOffsets: source,
            toOffset: destination
        )
    }

    // MARK: - Chapter List

    private var chapterList: some View {
        List {
            ForEach(
                Array(chapters.enumerated()),
                id: \.element.id
            ) { index, chapter in
                chapterRow(
                    chapter,
                    displayPosition: index + 1
                )
                .listRowInsets(
                    EdgeInsets(
                        top: 5,
                        leading: 20,
                        bottom: 5,
                        trailing: 20
                    )
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
            .onMove(perform: moveChapter)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, .constant(.active))
    }

    // MARK: - Chapter Row

    private func chapterRow(
        _ chapter: StudyDeck,
        displayPosition: Int
    ) -> some View {

        HStack(spacing: 14) {

            chapterIcon(
                position: displayPosition
            )

            VStack(
                alignment: .leading,
                spacing: 5
            ) {
                Text(chapter.title)
                    .font(
                        .custom(
                            "PlusJakartaSans-SemiBold",
                            size: 15
                        )
                    )
                    .foregroundStyle(
                        Color.appTextPrimary
                    )
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {

                    Text(
                        "\(chapter.totalCardCount) card\(chapter.totalCardCount == 1 ? "" : "s")"
                    )

                    if !chapter.subject.isEmpty {
                        Text("•")

                        Text(chapter.subject)
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

        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(
            maxWidth: .infinity,
            alignment: .leading
        )
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

    // MARK: - Chapter Icon

    private func chapterIcon(
        position: Int
    ) -> some View {

        ZStack {
            RoundedRectangle(
                cornerRadius: 8
            )
            .fill(
                Color.appSecondarySurface
            )

            Text("\(position)")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 13
                    )
                )
                .foregroundStyle(
                    Color.appTextSecondary
                )
        }
        .frame(
            width: 38,
            height: 38
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {

            Image(
                systemName: "rectangle.stack"
            )
            .font(.system(size: 24))
            .foregroundStyle(
                Color.appTextSecondary
            )

            Text("No chapters")
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
                "This deck doesn't have any chapters to reorder."
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 13
                )
            )
            .foregroundStyle(
                Color.appTextSecondary
            )
            .multilineTextAlignment(.center)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.horizontal, 30)
        .padding(.top, 60)
    }

    // MARK: - Load

    private func loadChapters() {
        chapters = parentDeck.childDecks.sorted {
            let lhs = $0.position ?? Int.max
            let rhs = $1.position ?? Int.max

            if lhs != rhs {
                return lhs < rhs
            }

            return $0.title
                .localizedCaseInsensitiveCompare(
                    $1.title
                ) == .orderedAscending
        }
    }
}