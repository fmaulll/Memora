//
//  NewStudyDeckView.swift
//  Memora
//

import SwiftUI

struct NewStudyDeckView: View {
    private let showsSetUpLater: Bool
    private let onFinish: ((StudyDeck) -> Void)?

    @State private var selectedMethod: StudyDeckMethod?
    @State private var isShowingCreateOwnDeck = false
    @State private var isShowingCreateWithAi = false
    @State private var isShowingHome = false

    private let methods = StudyDeckMethod.allCases

    init(
        showsSetUpLater: Bool = false,
        onFinish: ((StudyDeck) -> Void)? = nil
    ) {
        self.showsSetUpLater = showsSetUpLater
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            AppBackground {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {

                        pageHeader

                        mrEdHero
                            .padding(.top, 24)

                        methodHeader
                            .padding(.top, 34)

                        VStack(spacing: 12) {
                            ForEach(methods) { method in
                                StudyDeckMethodCard(
                                    method: method,
                                    isSelected: selectedMethod == method
                                ) {
                                    select(method)
                                }
                            }
                        }
                        .padding(.top, 16)

                        Text("You can change or edit your deck later.")
                            .font(
                                .custom(
                                    "PlusJakartaSans-Regular",
                                    size: 12
                                )
                            )
                            .foregroundStyle(Color.appTextSecondary.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.top, 20)
                            .padding(.bottom, 36)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarBackButtonHidden()

            if showsSetUpLater {
                setupLaterButton
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            BackNavigationBar {
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomAction
        }
        .navigationDestination(isPresented: $isShowingCreateWithAi) {
            AIDeckSetupView(
                onDeckCreated: { createdDeck in
                    onFinish?(createdDeck)
                },
                existingDeck: nil
            )
        }
        .navigationDestination(isPresented: $isShowingCreateOwnDeck) {
            CreateOwnDeckView(
                onFinish: { deck in
                    onFinish?(deck)
                }
            )
        }
        .navigationDestination(isPresented: $isShowingHome) {
            HomeView()
        }
    }

    // MARK: - Header

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NEW STUDY DECK")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 12
                    )
                )
                .tracking(1.4)
                .foregroundStyle(Color.appAccent)

            Text("What are we\nstudying today?")
                .font(
                    .custom(
                        "PlusJakartaSans-ExtraBold",
                        size: 38
                    )
                )
                .tracking(-1)
                .lineSpacing(-3)
                .foregroundStyle(Color.appTextPrimary)
        }
        .padding(.top, 18)
    }

    // MARK: - Mr. Ed Hero

    private var mrEdHero: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.appSurface)

            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.appAccent.opacity(0.35),
                    lineWidth: 1
                )

            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 12) {

                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.appAccent)
                            .frame(width: 7, height: 7)

                        Text("MR. ED IS READY")
                            .font(
                                .custom(
                                    "PlusJakartaSans-Bold",
                                    size: 11
                                )
                            )
                            .tracking(1)
                            .foregroundStyle(Color.appAccent)
                    }

                    Text("Give me the material.\nI'll handle the boring part.")
                        .font(
                            .custom(
                                "PlusJakartaSans-Bold",
                                size: 18
                            )
                        )
                        .foregroundStyle(Color.appTextPrimary)
                        .fixedSize(
                            horizontal: false,
                            vertical: true
                        )

                    Text(
                        "Pick how you want to build your deck. I recommend letting me do it."
                    )
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 13
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)
                    .lineSpacing(3)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                }
                .frame(
                    maxWidth: .infinity,
                    alignment: .leading
                )

                Image("MrEdJudging")
                    .resizable()
                    .scaledToFit()
                    .frame(
                        width: 112,
                        height: 150
                    )
                    .padding(.leading, 8)
                    .padding(.trailing, -4)
                    .padding(.bottom, -18)
            }
            .padding(.leading, 20)
            .padding(.trailing, 10)
            .padding(.vertical, 18)
        }
        .clipped()
    }

    // MARK: - Method Header

    private var methodHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Choose your approach")
                .font(
                    .custom(
                        "PlusJakartaSans-Bold",
                        size: 19
                    )
                )
                .foregroundStyle(Color.appTextPrimary)

            Text("You bring the knowledge. Pick how you want to turn it into a deck.")
                .font(
                    .custom(
                        "PlusJakartaSans-Regular",
                        size: 13
                    )
                )
                .foregroundStyle(Color.appTextSecondary)
                .lineSpacing(2)
        }
    }

    // MARK: - Bottom Action

    private var bottomAction: some View {
        VStack(spacing: 0) {
            if let selectedMethod {
                HStack(spacing: 8) {
                    Image(systemName: selectedMethod.icon)
                        .font(.system(size: 12, weight: .semibold))

                    Text(selectedMethod.title)
                        .font(
                            .custom(
                                "PlusJakartaSans-SemiBold",
                                size: 12
                            )
                        )

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.appAccent)
                }
                .foregroundStyle(Color.appTextSecondary)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            AppButton(
                title: continueButtonTitle,
                foreground: selectedMethod == nil
                    ? Color.appTextSecondary
                    : Color.appTextPrimary,
                background: Color.appAccent
            ) {
                guard let selectedMethod else {
                    return
                }

                open(selectedMethod)
            }
            .disabled(selectedMethod == nil)
            .opacity(selectedMethod == nil ? 0.45 : 1)
            .padding(.horizontal, 20)
        }
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.appBackground)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.appBorder)
                .frame(height: 1)
        }
        .animation(
            .easeInOut(duration: 0.2),
            value: selectedMethod
        )
    }

    private var continueButtonTitle: String {
        switch selectedMethod {
        case .studyWithMrEd:
            return "Study with Mr. Ed"

        case .custom:
            return "Create My Deck"

        case .anki:
            return "Continue"

        case nil:
            return "Choose a Study Method"
        }
    }

    // MARK: - Setup Later

    private var setupLaterButton: some View {
        Button("Set up later") {
            isShowingHome = true
        }
        .font(
            .custom(
                "PlusJakartaSans-SemiBold",
                size: 13
            )
        )
        .foregroundStyle(Color.appTextSecondary)
        .padding(.horizontal, 12)
        .frame(height: 34)
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
        .padding(.trailing, 20)
    }

    // MARK: - Actions

    private func select(_ method: StudyDeckMethod) {
        withAnimation(
            .spring(
                response: 0.28,
                dampingFraction: 0.82
            )
        ) {
            selectedMethod = method
        }
    }

    private func open(_ method: StudyDeckMethod) {
        switch method {
        case .studyWithMrEd:
            isShowingCreateWithAi = true

        case .custom:
            isShowingCreateOwnDeck = true

        case .anki:
            break
        }
    }
}

// MARK: - Study Method

private enum StudyDeckMethod: String, CaseIterable, Identifiable {
    case studyWithMrEd
    case custom
    case anki

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .studyWithMrEd:
            return "Study with Mr. Ed"

        case .custom:
            return "Create Your Own Deck"

        case .anki:
            return "Import Anki Deck"
        }
    }

    var description: String {
        switch self {
        case .studyWithMrEd:
            return "Give Mr. Ed a topic or your study materials. He'll build the deck for you."

        case .custom:
            return "Take full control and write every flashcard yourself."

        case .anki:
            return "Bring your existing .apkg flashcard decks into Memora."
        }
    }

    var eyebrow: String {
        switch self {
        case .studyWithMrEd:
            return "MR. ED'S PICK"

        case .custom:
            return "MANUAL"

        case .anki:
            return "IMPORT"
        }
    }

    var tags: [String] {
        switch self {
        case .studyWithMrEd:
            return [
                "AI-Powered",
                "Fastest"
            ]

        case .custom:
            return [
                "Full Control"
            ]

        case .anki:
            return [
                "APKG",
                "Anki"
            ]
        }
    }

    var icon: String {
        switch self {
        case .studyWithMrEd:
            return "sparkles"

        case .custom:
            return "square.and.pencil"

        case .anki:
            return "square.and.arrow.down"
        }
    }

    var iconColor: Color {
        switch self {
        case .studyWithMrEd:
            return Color.appAccent

        case .custom:
            return Color.appInfo

        case .anki:
            return Color.appSecondarySurface
        }
    }

    var isRecommended: Bool {
        self == .studyWithMrEd
    }
}

// MARK: - Method Card

private struct StudyDeckMethodCard: View {
    let method: StudyDeckMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 0) {

                HStack(alignment: .top, spacing: 14) {
                    methodIcon

                    VStack(alignment: .leading, spacing: 5) {
                        eyebrow

                        Text(method.title)
                            .font(
                                .custom(
                                    "PlusJakartaSans-Bold",
                                    size: 16
                                )
                            )
                            .foregroundStyle(Color.appTextPrimary)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer(minLength: 8)

                    selectionIndicator
                }

                Text(method.description)
                    .font(
                        .custom(
                            "PlusJakartaSans-Regular",
                            size: 13
                        )
                    )
                    .foregroundStyle(Color.appTextSecondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(3)
                    .fixedSize(
                        horizontal: false,
                        vertical: true
                    )
                    .padding(.top, 14)

                HStack(spacing: 8) {
                    ForEach(method.tags, id: \.self) { tag in
                        Text(tag)
                            .font(
                                .custom(
                                    "PlusJakartaSans-SemiBold",
                                    size: 11
                                )
                            )
                            .foregroundStyle(
                                method.isRecommended
                                    ? Color.appAccent
                                    : Color.appTextSecondary
                            )
                            .padding(.horizontal, 10)
                            .frame(height: 28)
                            .background(
                                method.isRecommended
                                    ? Color.appAccent.opacity(0.10)
                                    : Color.appSecondarySurface,
                                in: RoundedRectangle(cornerRadius: 8)
                            )
                            .overlay {
                                if method.isRecommended {
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(
                                            Color.appAccent.opacity(0.20),
                                            lineWidth: 1
                                        )
                                }
                            }
                    }
                }
                .padding(.top, 16)
            }
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .padding(18)
            .background(
                cardBackground,
                in: RoundedRectangle(cornerRadius: 8)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        borderColor,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
            .overlay(alignment: .leading) {
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.appAccent)
                        .frame(
                            width: 3,
                            height: 44
                        )
                        .padding(.leading, 1)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(isSelected ? 1 : 0.995)
        .animation(
            .spring(
                response: 0.25,
                dampingFraction: 0.85
            ),
            value: isSelected
        )
    }

    private var methodIcon: some View {
        Image(systemName: method.icon)
            .font(
                .system(
                    size: 19,
                    weight: .semibold
                )
            )
            .foregroundStyle(
                method == .anki
                    ? Color.appTextPrimary
                    : .white
            )
            .frame(
                width: 46,
                height: 46
            )
            .background(
                method.iconColor,
                in: RoundedRectangle(cornerRadius: 8)
            )
    }

    private var eyebrow: some View {
        Text(method.eyebrow)
            .font(
                .custom(
                    "PlusJakartaSans-Bold",
                    size: 10
                )
            )
            .tracking(0.8)
            .foregroundStyle(
                method.isRecommended
                    ? Color.appAccent
                    : Color.appTextSecondary
            )
    }

    @ViewBuilder
    private var selectionIndicator: some View {
        if isSelected {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Color.appAccent)
        } else {
            Image(systemName: "circle")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(Color.appBorder)
        }
    }

    private var cardBackground: Color {
        if isSelected {
            return Color.appSecondarySurface
        }

        return Color.appSurface
    }

    private var borderColor: Color {
        if isSelected {
            return Color.appAccent
        }

        if method.isRecommended {
            return Color.appAccent.opacity(0.28)
        }

        return Color.appBorder
    }
}

#Preview {
    NavigationStack {
        NewStudyDeckView()
    }
}