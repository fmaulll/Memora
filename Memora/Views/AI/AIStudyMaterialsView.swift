import SwiftUI
import UniformTypeIdentifiers

struct AIStudyMaterialsView: View {

    let topic: String
    let preparationDetails: String
    let educationLevel: String
    let studyPurpose: String
    let targetDate: Date?
    let onDeckCreated: (StudyDeck) -> Void
    let existingDeck: StudyDeck?

    @State private var selectedMaterialURLs: [URL] = []
    @State private var isShowingFileImporter = false
    @State private var isGenerating = false
    @State private var generatedPlan: DeckPlanResponse?
    @State private var isShowingPlanPreview = false
    @State private var errorMessage: String?

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    uploadButton

                    if !selectedMaterialURLs.isEmpty {
                        selectedMaterials
                    }

                    Text("Not required. I can work without them.")
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 13
                            )
                        )
                        .foregroundStyle(Color.appTextSecondary)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(
                                .custom(
                                    "PlusJakartaSans-Regular",
                                    size: 13
                                )
                            )
                            .foregroundStyle(Color.appError)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BackNavigationBar {
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            AppButton(
                title: isGenerating ? "Building your plan..." : "Continue",
                foreground: Color.appTextPrimary,
                background: Color.appAccent
            ) {
                generatePlan()
            }
            .disabled(isGenerating)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color.appBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.appBorder)
                    .frame(height: 1)
            }
        }
        .navigationBarBackButtonHidden()
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: materialTypes,
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                selectedMaterialURLs.append(
                    contentsOf: urls.filter { url in
                        !selectedMaterialURLs.contains(url)
                    }
                )

            case .failure(let error):
                errorMessage = error.localizedDescription
            }
        }
        .navigationDestination(isPresented: $isShowingPlanPreview) {
            if let generatedPlan {
                AIPlanPreviewView(
                    plan: generatedPlan,
                    studyPurpose: studyPurpose,
                    targetDate: targetDate,
                    onDeckCreated: onDeckCreated,
                    existingDeck: existingDeck
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("STUDY MATERIALS")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(Color.appAccent)

            Text("Anything Mr. Ed\nshould read?")
                .font(
                    .custom(
                        "PlusJakartaSans-ExtraBold",
                        size: 38
                    )
                )
                .foregroundStyle(Color.appTextPrimary)
                .tracking(-1)
                .lineSpacing(-3)

            Text("Add notes, documents, or slides for extra context. You can also continue without them.")
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 14
                    )
                )
                .foregroundStyle(Color.appTextSecondary)
                .lineSpacing(4)
        }
    }

    private var uploadButton: some View {
        Button {
            isShowingFileImporter = true
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.appAccent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Upload materials")
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 14
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)

                    Text("PDF, notes, documents, or slides")
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 12
                            )
                        )
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer()

                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 68)
            .background(
                Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.appBorder, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private var selectedMaterials: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADDED MATERIALS")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 11
                    )
                )
                .foregroundStyle(Color.appTextSecondary)

            ForEach(selectedMaterialURLs, id: \.self) { url in
                HStack(spacing: 12) {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.appInfo)

                    Text(url.lastPathComponent)
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 13
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        selectedMaterialURLs.removeAll { $0 == url }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(url.lastPathComponent)")
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 56)
                .background(
                    Color.appSecondarySurface,
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
        }
    }

    private var materialTypes: [UTType] {
        [
            .pdf,
            .plainText,
            UTType(filenameExtension: "docx") ?? .data,
            UTType(filenameExtension: "pptx") ?? .data
        ]
    }

    private func generatePlan() {
        guard !isGenerating else {
            return
        }

        isGenerating = true
        errorMessage = nil

        Task {
            do {
                let uploadedMaterials: [UploadedStudyMaterial]

                if selectedMaterialURLs.isEmpty {
                    uploadedMaterials = []
                } else {
                    uploadedMaterials = try await AIService.shared
                        .uploadStudyMaterials(selectedMaterialURLs)
                }

                let plan = try await AIService.shared.generatePlan(
                    topic: topic,
                    educationLevel: educationLevel,
                    studyPurpose: studyPurpose,
                    preparationDetails: preparationDetails,
                    targetDate: targetDate,
                    studyMaterialIDs: uploadedMaterials.map(\.id)
                )

                await MainActor.run {
                    generatedPlan = plan
                    isGenerating = false
                    isShowingPlanPreview = true
                }

            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isGenerating = false
                }
            }
        }
    }
}
