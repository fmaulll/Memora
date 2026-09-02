import SwiftUI
import SwiftData

struct AIDeckSetupView: View {

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \LocalUserProfile.createdAt, order: .reverse)
    private var profiles: [LocalUserProfile]

    let onDeckCreated: (StudyDeck) -> Void
    let existingDeck: StudyDeck?

    @State private var topic = ""
    @State private var educationLevel = "University"
    @State private var studyPurpose = "Learn from Scratch"
    @State private var preparationDetails = ""

    @State private var hasTargetDate = false
    @State private var targetDate = Date()

    @State private var isShowingStudyMaterials = false

    private let accent = Color.appAccent

    private let educationLevels = [
        "Elementary School",
        "Middle School",
        "High School",
        "University",
        "Professional",
        "Self-taught",
    ]

    private let studyPurposeOptions = [
        "Learn from Scratch",
        "Expand My Knowledge",
        "Prepare for an Exam",
        "Prepare for a Certification"
    ]

    var body: some View {

        AppBackground {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {

                    header

                    topicSection

                    educationSection

                    studyPurposeSection

                    preparationDetailsSection

                    targetDateSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationDestination(
            isPresented: $isShowingStudyMaterials
        ) {
            AIStudyMaterialsView(
                topic: topic.trimmingCharacters(in: .whitespacesAndNewlines),
                preparationDetails: preparationDetails.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ),
                educationLevel: educationLevel,
                studyPurpose: studyPurpose,
                targetDate: hasTargetDate ? targetDate : nil,
                onDeckCreated: onDeckCreated,
                existingDeck: existingDeck
            )
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                AppButton(
                    title: "Continue",
                    foreground: canContinue
                        ? Color.appTextPrimary
                        : Color.appTextSecondary
                ) {
                    isShowingStudyMaterials = true
                }
                .disabled(!canContinue)
                .padding(.horizontal, 20)
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(Color.appBackground)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BackNavigationBar {
                EmptyView()
            }
        }
        .navigationBarBackButtonHidden()
        .onAppear {
            if let educationLevel = profiles.first?.educationLevel,
               !educationLevel.isEmpty {
                self.educationLevel = educationLevel
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("CREATE WITH AI")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 13
                    )
                )
                .foregroundStyle(accent)

            Text("What do you want\nto study?")
                .font(
                    .custom(
                        "PlusJakartaSans-ExtraBold",
                        size: 38
                    )
                )
                .foregroundStyle(.white)
                .tracking(-1)
                .lineSpacing(-3)

            Text(
                "Give Mr. Ed the subject. You can add materials in the next step."
            )
            .font(
                .custom(
                    "PlusJakartaSans-Regular",
                    size: 14
                )
            )
            .foregroundStyle(.white.opacity(0.55))
            .lineSpacing(4)
        }
    }

    // MARK: - Topic

    private var topicSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("TOPIC")

            TextField(
                "e.g. Python programming from scratch",
                text: $topic
            )
            .textInputAutocapitalization(.sentences)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .frame(height: 56)
            .background(
                .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        .white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
    }

    // MARK: - Education

    private var educationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("EDUCATION LEVEL")

            Menu {
                ForEach(educationLevels, id: \.self) { level in
                    Button {
                        educationLevel = level
                    } label: {
                        Text(level)
                    }
                }
            } label: {
                HStack {
                    Text(educationLevel)
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 14
                            )
                        )
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 16)
                .frame(height: 56)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            .white.opacity(0.10),
                            lineWidth: 1
                        )
                }
            }
        }
    }

    // MARK: - Preparation Details

    private var preparationDetailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("WHAT ARE YOU PREPARING FOR?")

            TextField(
                "e.g. Math exam covering multiplication, division, and word problems",
                text: $preparationDetails,
                axis: .vertical
            )
            .textInputAutocapitalization(.sentences)
            .foregroundStyle(.white)
            .lineLimit(3...6)
            .padding(16)
            .frame(minHeight: 112, alignment: .topLeading)
            .background(
                .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        .white.opacity(0.10),
                        lineWidth: 1
                    )
            }
        }
    }

    // MARK: - Study Purpose

    private var studyPurposeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("STUDY PURPOSE")

            VStack(spacing: 10) {
                studyPurposeOption(
                    title: "Learn from Scratch",
                    description: "Build a strong foundation from the beginning",
                    icon: "book.closed"
                )

                studyPurposeOption(
                    title: "Expand My Knowledge",
                    description: "Deepen your understanding of a subject",
                    icon: "brain.head.profile"
                )

                studyPurposeOption(
                    title: "Prepare for an Exam",
                    description: "Study toward an upcoming academic exam",
                    icon: "graduationcap"
                )

                studyPurposeOption(
                    title: "Prepare for a Certification",
                    description: "Prepare for a professional certification",
                    icon: "checkmark.seal"
                )
            }
        }
    }

    private func studyPurposeOption(
        title: String,
        description: String,
        icon: String
    ) -> some View {
        Button {
            studyPurpose = title
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(
                        studyPurpose == title
                            ? accent
                            : Color.appTextSecondary
                    )
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 14
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)

                    Text(description)
                        .font(
                            .custom(
                                "PlusJakartaSans-Regular",
                                size: 12
                            )
                        )
                        .foregroundStyle(Color.appTextSecondary)
                }

                Spacer()

                Image(
                    systemName: studyPurpose == title
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.system(size: 20))
                .foregroundStyle(
                    studyPurpose == title
                        ? accent
                        : Color.appTextSecondary
                )
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 70)
            .background(
                studyPurpose == title
                    ? Color.appSecondarySurface
                    : Color.appSurface,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        studyPurpose == title
                            ? accent
                            : Color.appBorder,
                        lineWidth: studyPurpose == title ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Study Deadline

    private var targetDateSection: some View {
        VStack(alignment: .leading, spacing: 12) {

            sectionTitle("WHEN DO YOU NEED TO KNOW THIS?")

            Toggle(
                isOn: $hasTargetDate
            ) {
                VStack(alignment: .leading, spacing: 4) {

                    Text("I have a study deadline")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 14
                            )
                        )
                        .foregroundStyle(.white)

                    Text(
                        "Optional. We'll build a study schedule around it."
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 12
                        )
                    )
                    .foregroundStyle(
                        .white.opacity(0.45)
                    )
                }
            }
            .tint(accent)
            .padding(16)
            .background(
                .white.opacity(0.06),
                in: RoundedRectangle(cornerRadius: 8)
            )

            if hasTargetDate {

                DatePicker(
                    "Study Deadline",
                    selection: $targetDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .tint(accent)
                .padding(16)
                .background(
                    .white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(
                .custom(
                    "PlusJakartaSans-Bold",
                    size: 11
                )
            )
            .foregroundStyle(.white.opacity(0.45))
    }

    private var canContinue: Bool {
        !topic
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty
    }
}
