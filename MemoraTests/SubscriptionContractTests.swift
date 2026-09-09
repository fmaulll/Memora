import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct SubscriptionContractTests {
    private let now = Date(timeIntervalSince1970: 2_000_000_000)

    @Test func canceledRenewalRetainsAccessUntilExactExpiry() {
        let entitlement = makeEntitlement(status: "active", expires: now.addingTimeInterval(60))
        #expect(entitlement.allowsAccess(at: now))
        #expect(!entitlement.allowsAccess(at: now.addingTimeInterval(60)))
    }

    @Test func graceUsesGraceDeadlineAndNoOtherStatusGrantsAccess() {
        let grace = makeEntitlement(status: "grace_period", expires: now.addingTimeInterval(-60), grace: now.addingTimeInterval(60))
        #expect(grace.allowsAccess(at: now))
        #expect(!grace.allowsAccess(at: now.addingTimeInterval(60)))
        for status in ["none", "billing_retry", "expired", "revoked", "verification_required", "unknown"] {
            #expect(!makeEntitlement(status: status, expires: now.addingTimeInterval(60)).allowsAccess(at: now))
        }
        #expect(!makeEntitlement(status: "active", expires: nil).allowsAccess(at: now))
        #expect(!makeEntitlement(status: "active", expires: now.addingTimeInterval(60), subscribed: false).allowsAccess(at: now))
        #expect(!makeEntitlement(status: "active", expires: now.addingTimeInterval(60), revoked: now).allowsAccess(at: now))
    }

    @Test func authContractCarriesBackendPurchaseIdentityAndEntitlement() throws {
        let user = UserResponse(id: UUID(), name: "Student", email: "guest@example.com", createdAt: now,
                                isAnonymous: true, appAccountToken: UUID(), freeAIDeckAvailable: true,
                                entitlement: makeEntitlement(status: "none", expires: nil, subscribed: false))
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601
        let encodedUser = String(decoding: try encoder.encode(user), as: UTF8.self)
        let json = """
        {"user":\(encodedUser),"access_token":"access","refresh_token":"refresh","token_type":"bearer"}
        """
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(TokenResponse.self, from: Data(json.utf8))
        #expect(response.user.appAccountToken == user.appAccountToken)
        #expect(response.user.isAnonymous)
        #expect(response.user.freeAIDeckAvailable)
        #expect(!response.user.entitlement.isSubscribed)
    }

    @Test func errorContractAcceptsStructuredLegacyAndValidationDetails() throws {
        let decoder = JSONDecoder()
        let structured = try decoder.decode(BackendErrorDetail.self, from: Data(#"{"detail":{"code":"subscription_owned_by_another_account","message":"Use the owning account."}}"#.utf8))
        #expect(structured.code == "subscription_owned_by_another_account")
        #expect(structured.message == "Use the owning account.")
        let legacy = try decoder.decode(BackendErrorDetail.self, from: Data(#"{"detail":"Invalid credentials"}"#.utf8))
        #expect(legacy.message == "Invalid credentials")
        let validation = try decoder.decode(BackendErrorDetail.self, from: Data(#"{"detail":[{"loc":["header","Idempotency-Key"],"msg":"Field required","type":"missing"}]}"#.utf8))
        #expect(validation.message == "Field required")
    }

    @Test func generationIntentSurvivesRelaunchAndIsScopedByAccountAndBody() throws {
        let suite = "generation-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let account = UUID()
        let request = GenerateDeckRequest(plan: DeckPlanResponse(title: "Biology", subject: "S", educationLevel: "U", learningLanguage: "English",
                                                                chapters: [ChapterPlan(title: "Cells", description: "Study", keyConcepts: [], cardCount: 10)]),
                                          studyPurpose: "Learn", targetDate: nil)
        let store = GenerationRequestStore(defaults: defaults)
        let first = try store.intent(account: account, request: request)
        let reloaded = GenerationRequestStore(defaults: defaults)
        #expect(try reloaded.intent(account: account, request: request).key == first.key)
        #expect(try reloaded.intent(account: UUID(), request: request).key != first.key)
        let edited = GenerateDeckRequest(plan: request.plan, studyPurpose: "Exam", targetDate: nil)
        #expect(try reloaded.intent(account: account, request: edited).key != first.key)
        let destination = UUID()
        try reloaded.move(from: account, to: destination)
        #expect(reloaded.pending(account: account).isEmpty)
        #expect(reloaded.pending(account: destination).contains { $0.key == first.key })
        try reloaded.move(from: destination, to: account)
        let deckID = UUID()
        try reloaded.record(account: account, intent: first, deckID: deckID)
        #expect(try store.intent(account: account, request: request).deckID == deckID)
        store.complete(account: account, deckID: deckID)
        #expect(try store.intent(account: account, request: request).key != first.key)
    }

    @Test func verificationRequestContainsOnlySignedTransaction() throws {
        let data = try JSONEncoder().encode(VerifyApplePurchaseRequest(signedTransaction: "signed-jws"))
        let body = try #require(JSONSerialization.jsonObject(with: data) as? [String: String])
        #expect(body == ["signed_transaction": "signed-jws"])
    }

    @Test func managedDeckUpdateDoesNotRewriteParentMetadata() throws {
        let request = DeckUpdateRequest(omitParentDeck: true, title: "Renamed", subject: nil,
                                        educationLevel: nil, isFavorite: true, parentDeckId: UUID())
        let body = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: Any])
        #expect(body["parent_deck_id"] == nil)
        #expect(body["title"] as? String == "Renamed")
        #expect(body["position"] == nil)
    }

    @Test func explicitMergeRetainsLocalCardsButInvalidatesOldSession() throws {
        let suite = "merge-tests-\(UUID())"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = LocalAccountStore(defaults: defaults)
        let container = try ModelContainer(for: StudyDeck.self, StudyFlashcardCard.self, LocalUserProfile.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let guest = UUID(), destination = UUID()
        try store.activate(userID: guest, modelContext: context)
        let card = StudyFlashcardCard(front: "Question", back: "Answer")
        card.reviewCount = 2
        context.insert(StudyDeck(title: "Deck", subject: "S", educationLevel: "U", cards: [card]))
        context.insert(LocalUserProfile(userId: guest, name: "Student", email: nil, createdAt: now))
        let oldSession = try store.session()
        try store.reassignAfterMerge(userID: destination, modelContext: context)
        #expect(store.ownerID == destination)
        #expect(throws: CancellationError.self) { try store.validate(oldSession) }
        #expect(try context.fetch(FetchDescriptor<StudyFlashcardCard>()).first?.reviewCount == 2)
        #expect(try context.fetch(FetchDescriptor<LocalUserProfile>()).first?.userId == destination)
    }

    @Test func pendingPurchaseVerificationIsAccountScopedAndMovesOnlyExplicitly() throws {
        let source = UUID(), destination = UUID()
        let keychain = KeychainService.shared
        defer {
            try? keychain.saveAppleVerifications([:], userID: source)
            try? keychain.saveAppleVerifications([:], userID: destination)
        }
        try keychain.saveAppleVerifications(["1": "source-jws"], userID: source)
        try keychain.saveAppleVerifications(["2": "destination-jws"], userID: destination)
        #expect(try keychain.pendingAppleVerifications(userID: source) == ["1": "source-jws"])
        #expect(try keychain.pendingAppleVerifications(userID: destination) == ["2": "destination-jws"])
        try keychain.moveAppleVerifications(from: source, to: destination)
        #expect(try keychain.pendingAppleVerifications(userID: source).isEmpty)
        #expect(try keychain.pendingAppleVerifications(userID: destination) == ["1": "source-jws", "2": "destination-jws"])
    }

    @Test func duplicateGenerationResponseReusesServerDeckWithoutDuplicatingChapters() throws {
        let container = try ModelContainer(for: StudyDeck.self, StudyFlashcardCard.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let generated = GeneratedDeckResponse(id: UUID(), title: "Biology", subject: "Science", educationLevel: "School",
                                              learningLanguage: "English", generationStatus: "generating",
                                              chapters: [GeneratedChapter(id: UUID(), title: "Cells", generationStatus: "pending", position: 1)])
        let first = try AIDeckCreationService.shared.createDeck(from: generated, existingDeck: nil, modelContext: container.mainContext)
        let retried = try AIDeckCreationService.shared.createDeck(from: generated, existingDeck: nil, modelContext: container.mainContext)
        #expect(first.id == generated.id)
        #expect(first === retried)
        #expect(first.isSynced && first.isAIGenerated)
        #expect(try container.mainContext.fetch(FetchDescriptor<StudyDeck>()).count == 2)
    }

    private func makeEntitlement(status: String, expires: Date?, grace: Date? = nil,
                                 subscribed: Bool = true, revoked: Date? = nil) -> SubscriptionEntitlement {
        SubscriptionEntitlement(isSubscribed: subscribed, status: status, productID: "test.monthly",
                                expiresAt: expires, autoRenew: false, gracePeriodExpiresAt: grace,
                                revokedAt: revoked, lastVerifiedAt: now)
    }
}
