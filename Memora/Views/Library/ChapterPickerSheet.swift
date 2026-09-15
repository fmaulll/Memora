import SwiftUI

struct ChapterPickerSheet: View {

    let chapters: [StudyDeck]
    let selectedChapterID: UUID?
    let onSelect: (StudyDeck) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredChapters: [StudyDeck] {
        let query = searchText
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return chapters
        }

        return chapters.filter { chapter in
            chapter.title.localizedCaseInsensitiveContains(query) ||
            chapter.subject.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    searchField
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                        .padding(.bottom, 16)

                    if filteredChapters.isEmpty {
                        emptyState
                    } else {
                        chapterList
                    }
                }
            }
            .navigationTitle("Select Chapter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
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
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.appTextSecondary)

            TextField(
                "Search chapters",
                text: $searchText
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 15
                )
            )
            .foregroundStyle(Color.appTextPrimary)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appTextSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(
            Color.appSurface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.appBorder,
                    lineWidth: 1
                )
        }
    }

    // MARK: - Chapter List

    private var chapterList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                ForEach(filteredChapters) { chapter in
                    chapterRow(chapter)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
    }

    private func chapterRow(
        _ chapter: StudyDeck
    ) -> some View {

        let isSelected =
            selectedChapterID == chapter.id

        return Button {
            onSelect(chapter)
            dismiss()
        } label: {
            HStack(spacing: 14) {

                chapterIcon(
                    isSelected: isSelected
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

                Spacer(minLength: 12)

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
                    lineWidth: isSelected ? 1.5 : 1
                )
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func chapterIcon(
        isSelected: Bool
    ) -> some View {
        Image(
            systemName: "rectangle.stack.fill"
        )
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(
            isSelected
                ? Color.appAccent
                : Color.appTextSecondary
        )
        .frame(width: 38, height: 38)
        .background(
            isSelected
                ? Color.appAccent.opacity(0.12)
                : Color.appSecondarySurface,
            in: RoundedRectangle(cornerRadius: 8)
        )
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24))
                .foregroundStyle(
                    Color.appTextSecondary
                )

            Text("No chapters found")
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 15
                    )
                )
                .foregroundStyle(
                    Color.appTextPrimary
                )

            Text("Try another chapter name.")
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
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .padding(.top, 60)
    }
}