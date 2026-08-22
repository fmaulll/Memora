import SwiftUI
import SwiftData

struct HomeView: View {

    @Query(sort: \StudyDeck.createdAt, order: .reverse) private var decks: [StudyDeck]
    @State private var selectedTab: BottomBar.Tab = .home
    @State private var isShowingNewStudyDeck = false
    @State private var authManager = AuthManager.shared

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    private let cardFill = Color.white.opacity(0.18)

    private var totalCardCount: Int {
        decks.reduce(0) { $0 + $1.cards.count }
    }

    var body: some View {
        ZStack {
            AppBackground {
                Group {
                    if selectedTab == .home {
                        homeContent
                    } else {
                        LibraryView()
                    }
                }
            }

        .safeAreaInset(edge: .top, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity)
                .background(
                    Color(red: 0.04, green: 0.04, blue: 0.13)
                        .ignoresSafeArea(edges: .top)
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(.white.opacity(0.10))
                        .frame(height: 1)
                }
        }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            BottomBar(selectedTab: $selectedTab) {
                isShowingNewStudyDeck = true
            }
        }
        .navigationBarBackButtonHidden()
        .navigationDestination(isPresented: $isShowingNewStudyDeck) {
            NewStudyDeckView()
        }
    }

    private var homeContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 16) {
                    summaryCard(title: "STREAK", value: "14", icon: "flame.fill", color: .orange)
                    summaryCard(title: "GOAL", value: "82", icon: "target", color: accent)
                }
                .padding(.top, 24)

                sectionHeader("Recent Decks")
                    .padding(.top, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        ForEach(decks.prefix(3)) { deck in
                            NavigationLink {
                                DeckDetailsView(deck: deck)
                            } label: {
                                deckCard(for: deck)
                            }
                        }
                    }
                }
                .padding(.top, 14)

                sectionHeader("Quick Actions")
                    .padding(.top, 24)

                Button {
                    isShowingNewStudyDeck = true
                } label: {
                    Label("Continue Studying", systemImage: "play.fill")
                        .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 14)

                sectionHeader("Progress")
                    .padding(.top, 24)

                HStack(spacing: 16) {
                    progressCard(title: "Study time", value: "8h", detail: "+8h vs last week", icon: "clock", color: .indigo)
                    progressCard(title: "Cards reviewed", value: "42", detail: "+42 this week", icon: "brain", color: .green)
                }
                .padding(.top, 14)

                HStack(spacing: 16) {
                    progressCard(title: "Decks completed", value: "3", detail: "+1 this week", icon: "rosette", color: .orange)
                    progressCard(title: "Accuracy", value: "86%", detail: "+5% this week", icon: "chart.line.uptrend.xyaxis", color: .purple)
                }
                .padding(.top, 16)
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 20)
        }
    }

    private var header: some View {
        HStack {
            if selectedTab == .home {
                VStack(alignment: .leading, spacing: 6) {
                    Text(authManager.currentUser?.name ?? "User")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                        .foregroundStyle(.white)
                    Text(Date.now, format: .dateTime.weekday(.wide).month(.wide).day().year())
                        .environment(\.locale, Locale(identifier: "en_US"))
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.32))
                }
                Spacer()
                Text((authManager.currentUser?.name.prefix(2).uppercased()) ?? "US")
                    .font(.custom("PlusJakartaSans-Bold", size: 17))
                    .foregroundStyle(.white)
                    .frame(width: 52, height: 52)
                    .background(accent, in: RoundedRectangle(cornerRadius: 17))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Library")
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 30))
                        .foregroundStyle(.white)
                    Text("\(decks.count) deck\(decks.count == 1 ? "" : "s") · \(totalCardCount) cards")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.32))
                }
                Spacer()
                Button {
                    isShowingNewStudyDeck = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 52, height: 52)
                        .background(
                            LinearGradient(colors: [accent, Color(red: 0.55, green: 0.36, blue: 0.96)], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16)
                        )
                }
                .accessibilityLabel("Create a new study deck")
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.custom("PlusJakartaSans-Bold", size: 20))
                .foregroundStyle(.white)
            Spacer()
            if title == "Recent Decks" {
                Text("See all")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                    .foregroundStyle(accent)
            }
        }
    }

    private func summaryCard(title: String, value: String, icon: String, color: Color) -> some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .font(.system(size: 20))
                    
                    Text(title)
                        .font(.custom("PlusJakartaSans-Bold", size: 16))
                        .foregroundStyle(.white.opacity(0.60))
                }
                HStack(alignment: .bottom) {
                    Text(value)
                        .font(.custom("PlusJakartaSans-Bold", size: 30))
                        .foregroundStyle(.white)
                    
                    Text(title == "STREAK" ? "Days" : "%")
                        .font(.custom("PlusJakartaSans-Bold", size: 12))
                        .foregroundStyle(.white.opacity(0.40))
                        .padding(.bottom, 4)
                    
                }
            }
        }
        .frame(height: 150)
    }

    private func deckCard(for deck: StudyDeck) -> some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Text(String(deck.title.prefix(2)).uppercased())
                    .font(.custom("PlusJakartaSans-Bold", size: 14))
                    .foregroundStyle(.green)
                    .frame(width: 42, height: 42)
                    .background(.green.opacity(0.18), in: Circle())
                // Spacer()
                Text(deck.title)
                    .font(.custom("PlusJakartaSans-SemiBold", size: 16))
                    .foregroundStyle(.white)

                Text("\(deck.cards.count) cards")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(.white.opacity(0.5))

                HStack {
                    Text("Progress")
                        .font(.custom("PlusJakartaSans-Bold", size: 14))
                        .foregroundStyle(.white.opacity(0.55))
                    
                    Spacer()
                    
                    Text("\(0)%")
                        .font(.custom("PlusJakartaSans-Bold", size: 14))
                        .foregroundStyle(.green)
                    
                }
                ProgressView(value: Double(0), total: 100)
                    .tint(.green)
            }
        }
        .frame(width: 200, height: 200)
    }

    private func progressCard(title: String, value: String, detail: String, icon: String, color: Color) -> some View {
        dashboardCard {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(color)
                    .font(.system(size: 20))
                    .frame(width: 48, height: 48)
                    .background(color.opacity(0.18), in: RoundedRectangle(cornerRadius: 14))
                Spacer()
                Text(title)
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(.white.opacity(0.55))
                Text(value)
                    .font(.custom("PlusJakartaSans-Bold", size: 22))
                    .foregroundStyle(.white)
                Text("↗ \(detail)")
                    .font(.custom("PlusJakartaSans-SemiBold", size: 12))
                    .foregroundStyle(.green)
            }
        }
        .frame(height: 210)
    }

    private func dashboardCard<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(cardFill, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20)
                    .stroke(.white.opacity(0.28), lineWidth: 1.5)
            }
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
}
