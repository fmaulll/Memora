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
    @State private var isShowingUploadMaterials = false
    @State private var isShowingCreateOwnDeck = false
    @State private var isShowingCreateEmptyDeck = false
    @State private var isShowingCreateWithAi = false
    @State private var isShowingHome = false

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
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
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 16)
                        
                        Text("How do you want\nto study?")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 40))
                            .foregroundStyle(.white)
                            .tracking(-1)
                            .lineSpacing(-3)
                            .padding(.top, 16)
                        
                        Text("Choose your method to get started")
                            .font(.custom("PlusJakartaSans-Regular", size: 16))
                            .foregroundStyle(.white.opacity(0.62))
                            .padding(.top, 20)
                        
                        VStack(spacing: 12) {
                            ForEach(methods) { method in
                                StudyDeckMethodCard(
                                    method: method,
                                    isSelected: selectedMethod == method,
                                    accent: accent
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
                WorkflowIndicator(
                    numberOfSteps: selectedMethod?.stepCount ?? methods.count,
                    currentStep: 0,
                    accent: accent
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                HStack {
                    AppButton(
                        title: "Continue",
                        foreground: selectedMethod == nil ? .white.opacity(0.45) : .white,
                        background: AnyShapeStyle(LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing))
                    ) {
                        continueToSelectedMethod()
                    }
                    .disabled(selectedMethod == nil)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 12)
            .padding(.bottom, 12)
            .background(.black.opacity(0.92))
        }
        .navigationDestination(isPresented: $isShowingUploadMaterials) {
            UploadStudyMaterialsView()
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
        .navigationDestination(isPresented: $isShowingCreateEmptyDeck) {
            CreateOwnDeckView(
                mode: .empty,
                onFinish: { deck in
                    onFinish?(deck)
                }
            )
        }
        .navigationDestination(isPresented: $isShowingHome) {
            HomeView()
        }
    }

    private func continueToSelectedMethod() {
        switch selectedMethod {
        case .upload:
            isShowingUploadMaterials = true
        case .custom:
            isShowingCreateOwnDeck = true
        case .empty:
            isShowingCreateEmptyDeck = true
        case .aiTopic:
            isShowingCreateWithAi = true
        case .anki, nil:
            break
        }
    }
}

private enum StudyDeckMethod: String, CaseIterable, Identifiable {
    case upload
    case aiTopic
    case custom
    case empty
    case anki
    

    var id: String { rawValue }

    var title: String {
        switch self {
        case .upload: "Upload Study Materials"
        case .aiTopic: "Learn Any Topic with AI"
        case .custom: "Create Your Own Deck"
        case .empty: "Create Empty Deck"
        case .anki: "Import Anki Deck"
        }
    }

    var description: String {
        switch self {
        case .upload: "PDF, DOCX, or TXT — AI extracts everything."
        case .aiTopic: "Describe what you want to master. AI does the rest."
        case .custom: "Build flashcards manually with complete control."
        case .empty:
            "Create a deck now and add cards or sub-decks later."
        case .anki: "Import your existing .apkg flashcard decks into Memora."
        }
    }

    var tags: [String] {
        switch self {
        case .upload: ["PDF", "DOCX", "TXT"]
        case .aiTopic: ["Any Subject", "AI-Powered"]
        case .custom: ["Custom Cards", "Full Control"]
        case .empty:
            ["Empty Deck", "Organize Later"]
        case .anki: ["APKG Import", "Anki Compatible"]
        }
    }

    var icon: String {
        switch self {
        case .upload: "arrow.up"
        case .aiTopic: "sparkles"
        case .custom: "doc.badge.plus"
        case .empty:
            "folder.badge.plus"
        case .anki: "rectangle.stack.badge.plus"
        }
    }

    var iconColor: Color {
        switch self {
        case .upload: Color(red: 0.35, green: 0.33, blue: 0.95)
        case .aiTopic: Color(red: 0.59, green: 0.25, blue: 0.95)
        case .custom: Color(red: 0.41, green: 0.22, blue: 0.75)
        case .empty: Color(red: 0.39, green: 0.40, blue: 0.95)
        case .anki: Color(red: 0.20, green: 0.47, blue: 0.82)
        }
    }

    var stepCount: Int {
        switch self {
        case .upload: 3
        case .aiTopic: 4
        case .custom: 3
        case .empty: 2
        case .anki: 3
        }
    }
}

private struct StudyDeckMethodCard: View {
    let method: StudyDeckMethod
    let isSelected: Bool
    let accent: Color
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
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.leading)

                        Spacer(minLength: 4)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Text(method.description)
                        .font(.custom("PlusJakartaSans-Regular", size: 13))
                        .foregroundStyle(.white.opacity(0.62))
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 10) {
                        ForEach(method.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.custom("PlusJakartaSans-Regular", size: 12))
                                .foregroundStyle(.white.opacity(0.48))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.white.opacity(0.08), in: Capsule())
                        }
                    }
                    .padding(.top, 8)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(28)
            .background(.white.opacity(isSelected ? 0.23 : 0.18), in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(isSelected ? accent : .white.opacity(0.28), lineWidth: isSelected ? 2 : 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NewStudyDeckView()
}
