import SwiftUI

struct LanguagePickerSheet: View {

    @Environment(\.dismiss) private var dismiss

    @Binding var selectedLanguage: String?
    @State private var searchText = ""

    private let languages = [
        "Arabic", "Bengali", "Bulgarian", "Catalan", "Chinese",
        "Croatian", "Czech", "Danish", "Dutch", "English",
        "Estonian", "Finnish", "French", "Georgian", "German",
        "Greek", "Hebrew", "Hindi", "Hungarian", "Indonesian",
        "Italian", "Japanese", "Korean", "Latvian", "Lithuanian",
        "Malay", "Norwegian", "Persian", "Polish", "Portuguese",
        "Romanian", "Russian", "Serbian", "Slovak", "Slovenian",
        "Spanish", "Swedish", "Tamil", "Telugu", "Thai",
        "Turkish", "Ukrainian", "Urdu", "Vietnamese", "Welsh"
    ]

    private var filteredLanguages: [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else {
            return languages
        }

        return languages.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 10) {
                        Button {
                            selectedLanguage = nil
                            dismiss()
                        } label: {
                            languageRow(
                                title: "No language selected",
                                isSelected: selectedLanguage == nil
                            )
                        }
                        .buttonStyle(.plain)

                        ForEach(filteredLanguages, id: \.self) { language in
                            Button {
                                selectedLanguage = language
                                dismiss()
                            } label: {
                                languageRow(
                                    title: language,
                                    isSelected: selectedLanguage == language
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Learning Language")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search languages")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Color.appAccent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func languageRow(
        title: String,
        isSelected: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 20))
                .foregroundStyle(
                    isSelected ? Color.appAccent : Color.appTextSecondary
                )

            Text(title)
                .font(
                    .custom(
                        "PlusJakartaSans-SemiBold",
                        size: 15
                    )
                )
                .foregroundStyle(Color.appTextPrimary)

            Spacer()
        }
        .padding(.horizontal, 16)
        .frame(height: 56)
        .background(
            isSelected ? Color.appAccent.opacity(0.12) : Color.appSurface,
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.appAccent : Color.appBorder,
                    lineWidth: isSelected ? 2 : 1
                )
        }
    }
}

#Preview {
    LanguagePickerSheet(selectedLanguage: .constant(nil))
}
