import SwiftUI

struct NewStudyDeckView: View {
    private let showsSetUpLater: Bool
    private let onFinish: ((StudyDeck) -> Void)?
    @State private var selectedMethod: StudyDeckMethod = .studyWithMrEd
    @State private var isShowingCreateOwnDeck = false
    @State private var isShowingCreateWithAi = false
    @State private var isShowingHome = false

    init(showsSetUpLater: Bool = false, onFinish: ((StudyDeck) -> Void)? = nil) {
        self.showsSetUpLater = showsSetUpLater
        self.onFinish = onFinish
    }

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("NEW STUDY DECK")
                            .font(.custom("PlusJakartaSans-Bold", size: 11, relativeTo: .caption))
                            .tracking(1.5)
                            .foregroundStyle(Color.appAccent)
                        Text("Let’s make this stick.")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 30, relativeTo: .largeTitle))
                            .foregroundStyle(Color.appTextPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    mrEdIntroduction

                    VStack(alignment: .leading, spacing: 12) {
                        Text("CHOOSE YOUR APPROACH")
                            .font(.custom("PlusJakartaSans-Bold", size: 11, relativeTo: .caption))
                            .tracking(1)
                            .foregroundStyle(Color.appTextSecondary)
                        ForEach(StudyDeckMethod.allCases) { method in
                            StudyDeckMethodCard(method: method, isSelected: selectedMethod == method) {
                                withAnimation(.easeInOut(duration: 0.18)) { selectedMethod = method }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 24)
            }
            .safeAreaInset(edge: .top, spacing: 0) {
                BackNavigationBar {
                    if showsSetUpLater {
                        Button("Set up later") { isShowingHome = true }
                            .font(.custom("PlusJakartaSans-SemiBold", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(Color.appTextSecondary)
                    }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                VStack(spacing: 10) {
                    Text(selectedMethod == .studyWithMrEd ? "Start with a topic. Bring your notes if you have them." : "Your questions. Your answers. Your deck.")
                        .font(.custom("PlusJakartaSans-Regular", size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.appTextSecondary)
                        .multilineTextAlignment(.center)
                    AppButton(title: selectedMethod == .studyWithMrEd ? "Build with Mr. Ed" : "Create my own deck",
                              icon: .sf("arrow.right"), iconPosition: .right,
                              foreground: Color.appBackground, background: Color.appAccent) {
                        open(selectedMethod)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.appBackground)
                .overlay(alignment: .top) { Rectangle().fill(Color.appBorder).frame(height: 1) }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $isShowingCreateWithAi) {
            AIDeckSetupView(onDeckCreated: { onFinish?($0) }, existingDeck: nil)
        }
        .navigationDestination(isPresented: $isShowingCreateOwnDeck) {
            CreateOwnDeckView(onFinish: { onFinish?($0) })
        }
        .navigationDestination(isPresented: $isShowingHome) { HomeView() }
    }

    private var mrEdIntroduction: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 16) {
                mrEdDialogue.frame(minWidth: 140, maxWidth: .infinity, alignment: .leading)
                mrEdPortrait
            }
            VStack(alignment: .leading, spacing: 16) {
                mrEdPortrait.frame(maxWidth: .infinity)
                mrEdDialogue
            }
        }
        .padding(18)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
        .accessibilityElement(children: .combine)
    }

    private var mrEdDialogue: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("A WORD FROM MR. ED")
                .font(.custom("PlusJakartaSans-Bold", size: 10, relativeTo: .caption2))
                .tracking(1)
                .foregroundStyle(Color.appAccent)
            Text(selectedMethod == .studyWithMrEd
                 ? "“Give me a topic. I’ll build the deck. You’re still doing the studying.”"
                 : "“Making your own? Fine. Writing the cards is studying too. Make them count.”")
                .font(.custom("PlusJakartaSans-Bold", size: 17, relativeTo: .headline))
                .foregroundStyle(Color.appTextPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Tough coach. On your side.")
                .font(.custom("PlusJakartaSans-Regular", size: 12, relativeTo: .caption))
                .foregroundStyle(Color.appTextSecondary)
        }
    }

    private var mrEdPortrait: some View {
        Image("MrEdReady")
            .resizable()
            .scaledToFit()
            .frame(width: 100, height: 174)
            .accessibilityHidden(true)
    }

    private func open(_ method: StudyDeckMethod) {
        switch method {
        case .studyWithMrEd: isShowingCreateWithAi = true
        case .custom: isShowingCreateOwnDeck = true
        case .anki: break // Disabled until import is available.
        }
    }
}

private enum StudyDeckMethod: String, CaseIterable, Identifiable {
    case studyWithMrEd, custom, anki
    var id: String { rawValue }
    var isAvailable: Bool { self != .anki }
    var title: String {
        switch self {
        case .studyWithMrEd: "Study with Mr. Ed"
        case .custom: "Create my own deck"
        case .anki: "Import from Anki"
        }
    }
    var description: String {
        switch self {
        case .studyWithMrEd: "Turn a topic or your notes into a study plan and flashcards."
        case .custom: "Write your own questions and answers, one card at a time."
        case .anki: "Bring your existing flashcards along."
        }
    }
    var icon: String {
        switch self {
        case .studyWithMrEd: "sparkles"
        case .custom: "square.and.pencil"
        case .anki: "square.and.arrow.down"
        }
    }
}

private struct StudyDeckMethodCard: View {
    let method: StudyDeckMethod
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: method.icon)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.appAccent : Color.appTextSecondary)
                    .frame(width: 40, height: 40)
                    .background(Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 7) {
                    if method == .studyWithMrEd {
                        Text("LET MR. ED DO THE PREP")
                            .font(.custom("PlusJakartaSans-Bold", size: 9, relativeTo: .caption2))
                            .tracking(0.8)
                            .foregroundStyle(Color.appAccent)
                    }
                    Text(method.title)
                        .font(.custom("PlusJakartaSans-Bold", size: 16, relativeTo: .headline))
                        .foregroundStyle(method.isAvailable ? Color.appTextPrimary : Color.appTextSecondary)
                    Text(method.description)
                        .font(.custom("PlusJakartaSans-Regular", size: 13, relativeTo: .subheadline))
                        .foregroundStyle(Color.appTextSecondary)
                    if !method.isAvailable {
                        Text("COMING SOON")
                            .font(.custom("PlusJakartaSans-Bold", size: 10, relativeTo: .caption2))
                            .foregroundStyle(Color.appTextSecondary)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 4))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                if method.isAvailable {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(isSelected ? Color.appAccent : Color.appBorder)
                        .accessibilityHidden(true)
                }
            }
            .multilineTextAlignment(.leading)
            .padding(16)
            .background(isSelected ? Color.appAccent.opacity(0.06) : Color.appSurface,
                        in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.appAccent : Color.appBorder, lineWidth: isSelected ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!method.isAvailable)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    NavigationStack { NewStudyDeckView() }
}
