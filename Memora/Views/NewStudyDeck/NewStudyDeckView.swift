//
//  NewStudyDeckView.swift
//  Memora
//
//  Created by fuckdazeshit on 14/08/26.
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
                        Text("NEW STUDY DECK")
                            .font(.custom("PlusJakartaSans-Bold", size: 14))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.top, 16)

                        Text("How do you want\nto study?")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(Color.appTextPrimary)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)

                        Text("Mr. Ed can build a deck from a topic. Materials are optional.")
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.top, 20)

                        VStack(spacing: 12) {
                            ForEach(methods) { method in
                                StudyDeckMethodCard(
                                    method: method,
                                    isSelected: selectedMethod == method
                                ) {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedMethod = method
                                    }
                                }
                            }
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 34)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .preferredColorScheme(.dark)
            .navigationBarBackButtonHidden()

            if showsSetUpLater {
                Button("Set up later") {
                    isShowingHome = true
                }
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(.white.opacity(0.5))
                .padding(.horizontal, 15)
                .frame(height: 34)
                .background(.white.opacity(0.07), in: Capsule())
                .padding(.trailing, 20)
            }
        }
        
        .safeAreaInset(edge: .top, spacing: 0) {
            BackNavigationBar {
                EmptyView()
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                AppButton(
                    title: "Continue",
                    foreground: selectedMethod == nil
                        ? Color.appTextSecondary
                        : Color.appTextPrimary,
                    background: Color.appAccent
                ) {
                    if let selectedMethod {
                        open(selectedMethod)
                    }
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
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)
            }
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

private enum StudyDeckMethod: String, CaseIterable, Identifiable {
    case studyWithMrEd
    case custom
    case anki

    var id: String { rawValue }

    var title: String {
        switch self {
        case .studyWithMrEd: "Study with Mr. Ed"
        case .custom: "Create Your Own Deck"
        case .anki: "Import Anki Deck"
        }
    }

    var description: String {
        switch self {
        case .studyWithMrEd: "Give me a topic. Materials are optional."
        case .custom: "Build your own flashcards."
        case .anki: "Import your existing .apkg flashcard decks into Memora."
        }
    }

    var tags: [String] {
        switch self {
        case .studyWithMrEd: ["Topic", "AI-Powered"]
        case .custom: ["Custom Cards"]
        case .anki: ["APKG Import", "Anki Compatible"]
        }
    }

    var icon: String {
        switch self {
        case .studyWithMrEd: "brain.head.profile"
        case .custom: "doc.badge.plus"
        case .anki: "rectangle.stack.badge.plus"
        }
    }

    var iconColor: Color {
        switch self {
        case .studyWithMrEd: Color.appAccent
        case .custom: Color.appInfo
        case .anki: Color.appSecondarySurface
        }
    }
}

private struct StudyDeckMethodCard: View {
    let method: StudyDeckMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 16) {
                Image(systemName: method.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(method.iconColor, in: RoundedRectangle(cornerRadius: 13))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(method.title)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                            .foregroundStyle(Color.appTextPrimary)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Color.appTextSecondary)
                    }

                    Text(method.description)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        ForEach(method.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.custom("PlusJakartaSans-Regular", size: 12))
                                .foregroundStyle(Color.appTextSecondary)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(
                                    Color.appSecondarySurface,
                                    in: Capsule()
                                )
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
            .background(
                isSelected
                    ? Color.appSecondarySurface
                    : Color.appSurface,
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
        .buttonStyle(.plain)
    }
}

#Preview {
    NewStudyDeckView()
}
