//
//  OnboardingView.swift
//  Memora
//
//  Created by fuckdazeshit on 13/08/26.
//

import SwiftUI

struct OnboardingView: View {
    @State private var currentPage = 0
    @State private var hasCompletedOnboarding = false

    private let background = Color(red: 0.04, green: 0.04, blue: 0.13)
    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let accent2 = Color(red: 0.66, green: 0.33, blue: 0.97)
    private let accent3 = Color(red: 0.13, green: 0.77, blue: 0.37)

    private let pages = [
        OnboardingPage(
            title: "Learn Any Subject with AI",
            subtitle: "Ask AI about any topic and instantly create a personalized study deck.",
            imageName: "StepOne"
        ),
        OnboardingPage(
            title: "Upload Your Notes",
            subtitle: "Import PDFs, DOCX, or TXT files and let AI generate flashcards automatically.",
            imageName: "StepTwo"
        ),
        OnboardingPage(
            title: "Study Smarter, Not Harder",
            subtitle: "Review with spaced repetition and take adaptive exams based on what you struggle with.",
            imageName: "StepThree"
        )
    ]

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                WelcomeView()
            } else {
                ZStack(alignment: .topTrailing) {
                    background.ignoresSafeArea()

                    VStack(spacing: 0) {
                        TabView(selection: $currentPage) {
                            ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                                OnboardingPageView(page: page)
                                    .tag(index)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .never))
                        .animation(.easeInOut(duration: 0.45), value: currentPage)
                        .frame(height: .infinity)   // or 560 depending on your design

                        PageIndicator(
                            numberOfPages: pages.count,
                            currentPage: currentPage,
                            accents: [accent, accent2, accent3]
                        ).padding(.bottom, 20)

                        AppButton(
                            title: currentPage == pages.count - 1 ? "Get Started" : "Next",
                            icon: .sf(currentPage == pages.count - 1 ? "sparkles" : "chevron.right"),
                            iconPosition: .right,
                            foreground: .white,
                            background: LinearGradient(
                                stops: [
                                Gradient.Stop(color: Color(red: 0.39, green: 0.4, blue: 0.95), location: 0.00),
                                Gradient.Stop(color: Color(red: 0.55, green: 0.36, blue: 0.96), location: 1.00),
                                ],
                                startPoint: UnitPoint(x: 0, y: 0.5),
                                endPoint: UnitPoint(x: 1, y: 0.5))
                        ) {
                            withAnimation(.easeInOut(duration: 0.45)) {
                                if currentPage < pages.count - 1 {
                                    currentPage += 1
                                } else {
                                    hasCompletedOnboarding = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 28)

                    Button("Skip") {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .foregroundStyle(.white.opacity(0.45))
                    .padding(.horizontal, 16)
                    .frame(height: 34)
                    .background(.white.opacity(0.07), in: Capsule())
                    .padding(.top, 20)
                    .padding(.trailing, 20)
                }
            }
        }
    }
}

private struct PageIndicator: View {
    let numberOfPages: Int
    let currentPage: Int
    let accents: [Color]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<numberOfPages, id: \.self) { page in
                Capsule()
                    .fill(
                        page == currentPage
                        ? accents[min(page, accents.count - 1)]
                        : .white.opacity(0.10)
                    )
                    .frame(width: page == currentPage ? 24 : 8, height: 8)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Onboarding page \(currentPage + 1) of \(numberOfPages)")
    }
}

struct OnboardingPage {
    let title: String
    let subtitle: String
    let imageName: String
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    @State private var isAnimating = false

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image(page.imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 310)
                .scaleEffect(isAnimating ? 1.13 : 1.10)
                .offset(y: isAnimating ? -6 : 6)
                .opacity(isAnimating ? 1 : 0.82)
                .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true), value: isAnimating)
                .onAppear {
                    isAnimating = true
                }

            Text(page.title)
                .font(.largeTitle)
                .bold()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)

            Text(page.subtitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 40)
        .padding(.horizontal, 20)
    }
}


#Preview {
    OnboardingView()
}
