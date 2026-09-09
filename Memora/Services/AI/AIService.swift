import Foundation

@MainActor
final class AIService {

    static let shared = AIService()

    private init() {}

    // MARK: - Study Materials

    func uploadStudyMaterials(
        _ fileURLs: [URL]
    ) async throws -> [UploadedStudyMaterial] {
        let response: StudyMaterialsUploadResponse =
            try await APIClient.shared.upload(
                endpoint: "/ai/study-materials",
                files: fileURLs,
                fieldName: "files",
                timeout: 300
            )

        return response.materials
    }

    // MARK: - Generate Plan

    func generatePlan(
        topic: String,
        educationLevel: String,
        studyPurpose: String,
        preparationDetails: String,
        learningLanguage: String? = nil,
        targetDate: Date?,
        studyMaterialIDs: [String]? = nil
    ) async throws -> DeckPlanResponse {

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let formattedTargetDate = targetDate.map {
            dateFormatter.string(from: $0)
        }

        let request = DeckPlanRequest(
            topic: topic,
            educationLevel: educationLevel,
            studyPurpose: studyPurpose,
            preparationDetails: preparationDetails,
            learningLanguage: learningLanguage,
            targetDate: formattedTargetDate,
            studyMaterialIDs: studyMaterialIDs
        )

        return try await APIClient.shared.request(
            endpoint: "/ai/decks/plan",
            method: .post,
            body: request,
            timeout: 300
        )
    }

    // MARK: - Generate Cards

    func generateDeck(
        plan: DeckPlanResponse,
        studyPurpose: String,
        targetDate: Date?,
        requiresSubscription: Bool = false
    ) async throws -> GeneratedDeckWithTimelineResponse {

        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .iso8601)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let formattedTargetDate = targetDate.map {
            dateFormatter.string(from: $0)
        }

        let request = GenerateDeckRequest(
            plan: plan,
            studyPurpose: studyPurpose,
            targetDate: formattedTargetDate
        )

        guard let account = AuthManager.shared.currentUser?.id else { throw APIError.unauthorized }
        let intent = try GenerationRequestStore.shared.intent(account: account, request: request, requiresSubscription: requiresSubscription)
        return try await resumeGeneration(intent)
    }

    func resumeGeneration(_ intent: GenerationRequestStore.Intent) async throws -> GeneratedDeckWithTimelineResponse {
        let request = intent.request
        let plan = request.plan
        guard !plan.chapters.isEmpty, plan.chapters.count <= 20,
              plan.chapters.allSatisfy({ (1...100).contains($0.cardCount) }) else {
            throw APIError.backend(statusCode: 422, code: "invalid_plan",
                                   message: "A plan needs 1–20 chapters and 1–100 cards per chapter.")
        }
        guard let account = AuthManager.shared.currentUser?.id else { throw APIError.unauthorized }
        let revision = LocalAccountStore.shared.revision
        let response: GeneratedDeckWithTimelineResponse =
            try await APIClient.shared.request(
                endpoint: "/ai/decks/generate",
                method: .post,
                body: request,
                timeout: 30,
                headers: ["Idempotency-Key": intent.key.uuidString]
            )
        try LocalAccountStore.shared.validateRevision(revision)
        try GenerationRequestStore.shared.record(account: account, intent: intent, deckID: response.deck.id)
        try LocalAccountStore.shared.validateRevision(revision)
        return response
    }

    // MARK: - Retry Failed Deck

    func retryDeck(
        deckID: UUID,
        plan: DeckPlanResponse,
        studyPurpose: String = "Learn from Scratch",
        targetDate: Date? = nil
    ) async throws {
        try await APIClient.shared.requestWithoutResponse(
            endpoint: "/ai/decks/\(deckID.uuidString)/retry",
            method: .post
        )
    }

    // MARK: - Generation Status

    func fetchGenerationStatus(
        deckID: UUID
    ) async throws -> DeckGenerationStatusResponse {

        return try await APIClient.shared.request(
            endpoint: "/decks/\(deckID.uuidString)/generation-status",
            method: .get,
            timeout: 30
        )
    }
}