import SwiftUI
import SwiftData

struct WelcomeView: View {

    @Environment(\.modelContext) private var modelContext

    @State private var deckID: UUID = UUID()

    private let accent = Color(red: 0.39, green: 0.40, blue: 0.95)
    let cards = [
        CardCreateRequest(
            id: UUID(),
            front: "What is mitosis?",
            back: "A process of cell division.",
            frontImageURL: nil,
            backImageURL: nil
        ),

        CardCreateRequest(
            id: UUID(),
            front: "What is meiosis?",
            back: "A type of cell division that produces gametes.",
            frontImageURL: nil,
            backImageURL: nil
        ),

        CardCreateRequest(
            id: UUID(),
            front: "What is DNA?",
            back: "Deoxyribonucleic acid.",
            frontImageURL: nil,
            backImageURL: nil
        )
    ]

    var body: some View {
        AppBackground {
            VStack {
                
                VStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Welcome to")
                            .font(.custom("PlusJakartaSans-Regular", size: 48))
                            .kerning(2.88)
                            .foregroundColor(Color(red: 0.96, green: 0.95, blue: 0.98))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Text("Memora")
                            .font(.custom("PlusJakartaSans-ExtraBold", size: 48))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Your personal AI tutor for notes,\nflashcards, and exams.")
                        .font(.custom("PlusJakartaSans-Regular", size: 16))
                        .foregroundStyle(.white.opacity(0.62))
                        .lineSpacing(6)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer(minLength: 46)

                testField()
                
                VStack(spacing: 20) {
                    NavigationButton(title: "Continue with Apple", icon: .sf("apple.logo"), foreground: .black, background: .white) { }
                    NavigationButton(title: "Continue with Google", icon: .asset("GoogleIcon"), foreground: .white, background: Color(red: 0.02, green: 0.28, blue: 0.65)) { }
                    NavigationButton(title: "Sign up with Email", icon: .sf("envelope.fill"), foreground: .white, background: Color(red: 0.40, green: 0.40, blue: 0.53)) { 
                        RegisterView()
                    }

                    Text("OR")
                        .font(.custom("PlusJakartaSans-Regular", size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.vertical, 6)
                    
                    NavigationButton(
                        title: "Continue as Guest",
                        icon: .sf("person.fill")
                    ) {
                        NewStudyDeckView(showsSetUpLater: true)
                    }
                    
                    
                    HStack(spacing: 4) {
                        Text("Have an account?")
                            .foregroundStyle(.white.opacity(0.8))
                        
                        NavigationLink {
                            LoginView()
                        } label: {
                            Text("Login")
                                .foregroundStyle(accent)
                        }
                    }
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    
                    (
                        Text("By continuing, you agree to our ")
                            .foregroundStyle(.white.opacity(0.55))
                        + Text("Terms of Service")
                            .foregroundStyle(accent)
                        + Text(" and ")
                            .foregroundStyle(.white.opacity(0.55))
                        + Text("Privacy Policy")
                            .foregroundStyle(accent)
                    )
                    .font(.custom("PlusJakartaSans-Regular", size: 14))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity) // important
                    .fixedSize(horizontal: false, vertical: true) // prevents truncation
                }
//                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 20)
            .padding(.top, 100)
            .padding(.bottom, 28)
        }
    }


    private func testField() -> some View {
        VStack(alignment: .leading, spacing: 16) {

            // Button("Login (Test)") {
            //     Task {
            //         do {
            //             let user = try await AuthAPI.shared.login(
            //                 email: "edi.s@example.com",
            //                 password: "password123"
            //             )

            //             print("Logged in:", user.name)

            //             print(
            //                 "Token exists:",
            //                 KeychainService.shared.hasAccessToken()
            //             )

            //         } catch {
            //             print("Login error:", error)
            //         }
            //     }
            // }

            // Button("Me (Test)") {
            //     Task {
            //         do {
            //             let user = try await AuthAPI.shared.me()

            //             print("Current user:")
            //             print(user.id)
            //             print(user.name)
            //             print(user.email)

            //         } catch {
            //             print("Me error:", error)
            //         }
            //     }
            // }
            // Button("Create Deck") {
            //     Task {
            //         do {
            //             let deck = try await DeckAPI.shared.create(
            //                 id: UUID(),
            //                 title: "How to make meth",
            //                 subject: "Chemistry",
            //                 educationLevel: "Beginner"
            //             )

            //             print("Created deck:")
            //             print(deck.id)
            //             print(deck.title)
            //             deckID = deck.id

            //         } catch {
            //             print("Deck error:", error)
            //         }
            //     }
            // }
            // Button("Test UUID") {
            //     Task {
            //         do {
            //             let localID = UUID()

            //             let response = try await DeckAPI.shared.create(
            //                 id: localID,
            //                 title: "UUID Test",
            //                 subject: "Test",
            //                 educationLevel: "Beginner"
            //             )

            //             print("LOCAL :", localID)
            //             print("SERVER:", response.id)
            //             print("MATCH :", localID == response.id)

            //         } catch {
            //             print("UUID test error:", error)
            //         }
            //     }
            // }

            // Button("Test Sync") {
            //     Task {
            //         do {

            //             let deck = StudyDeck(
            //                 title: "Sync Test",
            //                 subject: "Biology",
            //                 educationLevel: "Beginner"
            //             )

            //             try await SyncManager.shared.syncDeck(deck)

            //             print("SYNC SUCCESS")
            //             print("Deck ID:", deck.id)

            //         } catch {
            //             print("SYNC ERROR:", error)
            //         }
            //     }
            // }

            // Button("Test Sync Deck + Cards") {
            //     Task {
            //         do {
            //             let deckID = UUID()

            //             // 1. Create deck on backend
            //             let deck = try await DeckAPI.shared.create(
            //                 id: deckID,
            //                 title: "Biology",
            //                 subject: "Biology",
            //                 educationLevel: "Beginner"
            //             )

            //             print("Created deck:", deck.id)

            //             // 2. Create cards WITHOUT StudyFlashcardCard
            //             let cards = [
            //                 CardCreateRequest(
            //                     id: UUID(),
            //                     front: "What is mitosis?",
            //                     back: "A process of cell division.",
            //                     frontImageURL: nil,
            //                     backImageURL: nil
            //                 ),

            //                 CardCreateRequest(
            //                     id: UUID(),
            //                     front: "What is DNA?",
            //                     back: "Deoxyribonucleic acid.",
            //                     frontImageURL: nil,
            //                     backImageURL: nil
            //                 ),

            //                 CardCreateRequest(
            //                     id: UUID(),
            //                     front: "What is RNA?",
            //                     back: "Ribonucleic acid.",
            //                     frontImageURL: nil,
            //                     backImageURL: nil
            //                 )
            //             ]

            //             // 3. Upload all cards
            //             let createdCards = try await CardAPI.shared.createBulk(
            //                 deckID: deck.id,
            //                 cards: cards
            //             )

            //             print("Created \(createdCards.count) cards")

            //             for card in createdCards {
            //                 print(card.id, card.front)
            //             }

            //             print("SYNC SUCCESS")

            //         } catch {
            //             print("SYNC ERROR:", error)
            //         }
            //     }
            // }

            // Button("Get Decks") {
            //     Task {
            //         do {
            //             let decks = try await DeckAPI.shared.getAll()

            //             print("Deck count:", decks.count)

            //             for deck in decks {
            //                 print(deck.title, deck.id)

            //                 deckID = deck.id
            //             }

            //         } catch {
            //             print("Get decks error:", error)
            //         }
            //     }
            // }

            // Button("Update Deck") {
            //     Task {
            //         do {
            //             let updated = try await DeckAPI.shared.update(
            //                 id: deckID,
            //                 title: "Meth is awesome"
            //             )

            //             print("Updated:", updated.title)

            //         } catch {
            //             print("Update error:", error)
            //         }
            //     }
            // }

            // Button("Delete Deck") {
            //     Task {
            //         do {
            //             try await DeckAPI.shared.delete(
            //                 id: deckID
            //             )

            //             print("Deck deleted")

            //         } catch {
            //             print("Delete error:", error)
            //         }
            //     }
            // }

            // Button("Create Cards bulk") {
            //     Task {
            //         do {
            //             let createdCards = try await CardAPI.shared.createBulk(
            //                 deckID: deckID,
            //                 cards: cards
            //             )

            //             print("Created \(createdCards.count) cards")

            //             for card in createdCards {
            //                 print(card.id, card.front)
            //             }

            //         } catch {
            //             print("Card error:", error)
            //         }
            //     }
            // }

            // Button("Get All Cards") {
            //     Task {
            //         do {
            //             let cards = try await CardAPI.shared.getAll(
            //                 deckID: deckID
            //             )

            //             print("Cards:", cards.count)

            //             for card in cards {
            //                 print(card.id, card.front)
            //             }

            //         } catch {
            //             print("Get cards error:", error)
            //         }
            //     }
            // }

            // Button("Get All Decks") {
            //     Task {
            //         do {
            //             let decks = try await DeckAPI.shared.getAll()

            //             guard let deck = decks.first else {
            //                 print("No decks")
            //                 return
            //             }

            //             print("Found:", deck.title)

            //         } catch {
            //             print("Sync error:", error)
            //         }
            //     }
            // }

            // Button("Test Card Reconciliation") {
            //     Task {
            //         do {

            //             // Use ONE fixed deck ID for both tests
            //             let deckID = UUID(
            //                 uuidString: "11111111-1111-1111-1111-111111111111"
            //             )!

            //             // First make sure the deck exists
            //             do {
            //                 _ = try await DeckAPI.shared.get(id: deckID)
            //             } catch {
            //                 _ = try await DeckAPI.shared.create(
            //                     id: deckID,
            //                     title: "Reconciliation Test",
            //                     subject: "Testing",
            //                     educationLevel: "Beginner"
            //                 )
            //             }

            //             // A, C, D
            //             let cards: [CardCreateRequest] = []

            //             let result = try await CardAPI.shared.createBulk(
            //                 deckID: deckID,
            //                 cards: cards
            //             )

            //             print("SERVER CARDS:", result.count)

            //             for card in result {
            //                 print(card.front, card.id)
            //             }

            //         } catch {
            //             print("RECONCILIATION ERROR:", error)
            //         }
            //     }
            // }

            // Button("Test Full Sync") {
            //     Task {
            //         do {

            //             let deck = StudyDeck(
            //                 title: "Full Sync Test",
            //                 subject: "Biology",
            //                 educationLevel: "Beginner"
            //             )

            //             modelContext.insert(deck)

            //             let card1 = StudyFlashcardCard(
            //                 front: "What is mitosis?",
            //                 back: "Cell division."
            //             )

            //             let card2 = StudyFlashcardCard(
            //                 front: "What is DNA?",
            //                 back: "Deoxyribonucleic acid."
            //             )

            //             let card3 = StudyFlashcardCard(
            //                 front: "What is RNA?",
            //                 back: "Ribonucleic acid."
            //             )

            //             modelContext.insert(card1)
            //             modelContext.insert(card2)
            //             modelContext.insert(card3)

            //             deck.cards = [
            //                 card1,
            //                 card2,
            //                 card3
            //             ]

            //             try modelContext.save()

            //             try await SyncManager.shared.syncDeck(deck)

            //             print("FULL SYNC SUCCESS")
            //             print("Deck:", deck.id)

            //         } catch {
            //             print("FULL SYNC ERROR:", error)
            //         }
            //     }
            // }

            // Button("Test Download") {
            //     Task {
            //         do {
            //             let decks = try await DeckAPI.shared.getAll()

            //             print("SERVER DECKS:", decks.count)

            //             for deck in decks {
            //                 print("DECK:", deck.id, deck.title)

            //                 let cards = try await CardAPI.shared.getAll(
            //                     deckID: deck.id
            //                 )

            //                 print("  CARDS:", cards.count)

            //                 for card in cards {
            //                     print("  -", card.id, card.front)
            //                 }
            //             }

            //         } catch {
            //             print("DOWNLOAD ERROR:", error)
            //         }
            //     }
            // }

            Button("Test Download → SwiftData") {
                Task {
                    do {
                        try await SyncManager.shared.downloadAll(
                            modelContext: modelContext
                        )

                        print("LOCAL DOWNLOAD SUCCESS")

                        // Fetch all local decks
                        let descriptor = FetchDescriptor<StudyDeck>()

                        let localDecks = try modelContext.fetch(descriptor)

                        print("LOCAL DECKS:", localDecks.count)

                        for deck in localDecks {

                            print("")
                            print("DECK:")
                            print("  ID:", deck.id)
                            print("  TITLE:", deck.title)
                            print("  SUBJECT:", deck.subject)
                            print("  SYNCED:", deck.isSynced)
                            print("  CARDS:", deck.cards.count)

                            for card in deck.cards {
                                print(
                                    "    CARD:",
                                    card.id,
                                    "|",
                                    card.front,
                                    "| synced:",
                                    card.isSynced
                                )
                            }
                        }

                    } catch {
                        print("DOWNLOAD SYNC ERROR:", error)
                    }
                }
            }

            // Button("Add Unsynced Card") {
            //     do {
            //         let descriptor = FetchDescriptor<StudyDeck>(
            //             predicate: #Predicate<StudyDeck> { deck in
            //                 deck.title == "Full Sync Test"
            //             }
            //         )

            //         guard let deck = try modelContext.fetch(descriptor).first else {
            //             print("Deck not found")
            //             return
            //         }

            //         let card = StudyFlashcardCard(
            //             front: "LOCAL ONLY",
            //             back: "This should survive"
            //         )

            //         card.isSynced = false

            //         deck.cards.append(card)

            //         try modelContext.save()

            //         print("Added unsynced card:", card.id)

            //     } catch {
            //         print("ADD ERROR:", error)
            //     }
            // }

            Button("Add Offline Deck") {
                do {
                    let deck = StudyDeck(
                        title: "Offline Test",
                        subject: "Testing",
                        educationLevel: "Beginner"
                    )

                    deck.isSynced = false

                    modelContext.insert(deck)

                    try modelContext.save()

                    print("Created offline deck:")
                    print("ID:", deck.id)
                    print("Title:", deck.title)
                    print("Synced:", deck.isSynced)

                } catch {
                    print("OFFLINE DECK ERROR:", error)
                }
            }
            
        }
    }
}

#Preview {
    WelcomeView()
}
