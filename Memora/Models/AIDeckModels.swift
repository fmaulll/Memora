import Foundation

// MARK: - Plan Request

enum StudyIntensity: String, Codable, CaseIterable, Identifiable {
    case easy, balanced, hard

    var id: String { rawValue }
    var title: String {
        switch self {
        case .easy: "Go easy on me"
        case .balanced: "Keep me balanced"
        case .hard: "Push me"
        }
    }
    var subtitle: String {
        switch self {
        case .easy: "Keep things comfortable."
        case .balanced: "Challenge me, but don't destroy me."
        case .hard: "I can handle it."
        }
    }
}

struct DeckPlanRequest: Codable {
    let topic: String
    let educationLevel: String
    let studyPurpose: String
    let preparationDetails: String
    let learningLanguage: String?
    let targetDate: String?
    let studyMaterialIDs: [String]?
    let intensity: StudyIntensity
    let timezone: String

    init(topic: String, educationLevel: String, studyPurpose: String, preparationDetails: String,
         learningLanguage: String?, targetDate: String?, studyMaterialIDs: [String]?,
         intensity: StudyIntensity = .balanced, timezone: String = TimeZone.current.identifier) {
        self.topic = topic; self.educationLevel = educationLevel; self.studyPurpose = studyPurpose
        self.preparationDetails = preparationDetails; self.learningLanguage = learningLanguage
        self.targetDate = targetDate; self.studyMaterialIDs = studyMaterialIDs
        self.intensity = intensity; self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case topic
        case educationLevel = "education_level"
        case studyPurpose = "study_purpose"
        case preparationDetails = "preparation_details"
        case learningLanguage = "learning_language"
        case targetDate = "target_date"
        case studyMaterialIDs = "study_material_ids"
        case intensity, timezone
    }
}

// MARK: - Study Materials

struct StudyMaterialsUploadResponse: Decodable {
    let materials: [UploadedStudyMaterial]
}

struct UploadedStudyMaterial: Decodable, Identifiable {
    let id: String
    let filename: String
}

// MARK: - Plan Response

struct DeckPlanResponse: Codable {
    let title: String
    let subject: String
    let educationLevel: String
    let learningLanguage: String?
    let chapters: [ChapterPlan]
    let timeline: StudyTimelineResponse? = nil

    enum CodingKeys: String, CodingKey {
        case title
        case subject
        case educationLevel = "education_level"
        case learningLanguage = "learning_language"
        case chapters
        case timeline
    }
}

struct ChapterPlan: Codable, Identifiable {
    let title: String
    let description: String
    let keyConcepts: [String]
    let cardCount: Int

    var id: String {
        title
    }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case keyConcepts = "key_concepts"
        case cardCount = "card_count"
    }
}

// MARK: - Generated Deck

struct GeneratedDeckResponse: Decodable {
    let id: UUID
    let title: String
    let subject: String
    let educationLevel: String

    let learningLanguage: String?
    let generationStatus: String
    let chapters: [GeneratedChapter]

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case subject
        case educationLevel = "education_level"
        case learningLanguage = "learning_language"
        case generationStatus = "generation_status"
        case chapters
    }
}

struct GeneratedChapter: Decodable, Identifiable {
    let id: UUID
    let title: String
    let generationStatus: String
    var position: Int? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case position
        case title
        case generationStatus = "generation_status"
    }
}

// MARK: - Generated Deck

struct GeneratedCard: Decodable {
    let front: String
    let back: String
}

struct GenerateDeckRequest: Codable {
    let plan: DeckPlanResponse
    let studyPurpose: String
    let targetDate: String?
    let intensity: StudyIntensity
    let timezone: String

    init(plan: DeckPlanResponse, studyPurpose: String, targetDate: String?,
         intensity: StudyIntensity = .balanced, timezone: String = TimeZone.current.identifier) {
        self.plan = plan; self.studyPurpose = studyPurpose; self.targetDate = targetDate
        self.intensity = intensity; self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case plan
        case studyPurpose = "study_purpose"
        case targetDate = "target_date"
        case intensity, timezone
    }

    // A preview forecast is not curriculum. Sending an old nested timeline after
    // a user changes pace or deadline would make backend validation reject the
    // request, so only the curriculum is included here.
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(PlanPayload(plan), forKey: .plan)
        try container.encode(studyPurpose, forKey: .studyPurpose)
        try container.encode(targetDate, forKey: .targetDate)
        try container.encode(intensity, forKey: .intensity)
        try container.encode(timezone, forKey: .timezone)
    }

    private struct PlanPayload: Encodable {
        let title: String
        let subject: String
        let educationLevel: String
        let learningLanguage: String?
        let chapters: [ChapterPlan]
        enum CodingKeys: String, CodingKey {
            case title, subject, chapters
            case educationLevel = "education_level"
            case learningLanguage = "learning_language"
        }
        init(_ plan: DeckPlanResponse) {
            title = plan.title; subject = plan.subject; educationLevel = plan.educationLevel
            learningLanguage = plan.learningLanguage; chapters = plan.chapters
        }
    }
}

struct StudyDayResponse: Codable, Identifiable {
    let day: Int
    let date: String
    let newCards: Int
    let focus: String
    let readyNewCards: Int?
    let reviewCards: Int?
    let projectedReviewCards: Int?
    let completedReviews: Int?
    let estimatedMinutes: Int?
    let chapterDeckIDs: [UUID]?

    var id: String { date }

    enum CodingKeys: String, CodingKey {
        case day
        case date
        case newCards = "new_cards"
        case focus
        case readyNewCards = "ready_new_cards"
        case reviewCards = "review_cards"
        case projectedReviewCards = "projected_review_cards"
        case completedReviews = "completed_reviews"
        case estimatedMinutes = "estimated_minutes"
        case chapterDeckIDs = "chapter_deck_ids"
    }
}


struct StudyTimelineResponse: Codable {
    let id: UUID?
    let parentDeckID: UUID?
    let revision: Int
    let algorithmVersion: String?
    let intensity: StudyIntensity
    let timezone: String
    let startDate: String?
    let targetDate: String?
    let estimatedFinishDate: String?
    let dateSource: String?
    let dailyMinutesBudget: Int?
    let requiredDailyMinutes: Int?
    let isOverloaded: Bool?
    let reviewsAfterTarget: Int?
    let readyCards: Int?
    let studiedCards: Int?
    let status: String?
    let nextFrom: String?
    let totalDays: Int
    let totalCards: Int
    let dailyPlan: [StudyDayResponse]

    enum CodingKeys: String, CodingKey {
        case id
        case parentDeckID = "parent_deck_id"
        case revision
        case algorithmVersion = "algorithm_version"
        case intensity, timezone
        case startDate = "start_date"
        case targetDate = "target_date"
        case estimatedFinishDate = "estimated_finish_date"
        case dateSource = "date_source"
        case dailyMinutesBudget = "daily_minutes_budget"
        case requiredDailyMinutes = "required_daily_minutes"
        case isOverloaded = "is_overloaded"
        case reviewsAfterTarget = "reviews_after_target"
        case readyCards = "ready_cards"
        case studiedCards = "studied_cards"
        case status
        case nextFrom = "next_from"
        case totalDays = "total_days"
        case totalCards = "total_cards"
        case dailyPlan = "daily_plan"
    }

    init(id: UUID?, parentDeckID: UUID?, revision: Int, algorithmVersion: String?, intensity: StudyIntensity,
         timezone: String, startDate: String?, targetDate: String?, estimatedFinishDate: String?, dateSource: String?,
         dailyMinutesBudget: Int?, requiredDailyMinutes: Int?, isOverloaded: Bool?, reviewsAfterTarget: Int?,
         readyCards: Int?, studiedCards: Int?, status: String?, nextFrom: String?, totalDays: Int,
         totalCards: Int, dailyPlan: [StudyDayResponse]) {
        self.id = id; self.parentDeckID = parentDeckID; self.revision = revision; self.algorithmVersion = algorithmVersion
        self.intensity = intensity; self.timezone = timezone; self.startDate = startDate; self.targetDate = targetDate
        self.estimatedFinishDate = estimatedFinishDate; self.dateSource = dateSource; self.dailyMinutesBudget = dailyMinutesBudget
        self.requiredDailyMinutes = requiredDailyMinutes; self.isOverloaded = isOverloaded; self.reviewsAfterTarget = reviewsAfterTarget
        self.readyCards = readyCards; self.studiedCards = studiedCards; self.status = status; self.nextFrom = nextFrom
        self.totalDays = totalDays; self.totalCards = totalCards; self.dailyPlan = dailyPlan
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try c.decodeIfPresent(UUID.self, forKey: .id),
            parentDeckID: try c.decodeIfPresent(UUID.self, forKey: .parentDeckID),
            revision: try c.decodeIfPresent(Int.self, forKey: .revision) ?? 0,
            algorithmVersion: try c.decodeIfPresent(String.self, forKey: .algorithmVersion),
            intensity: try c.decodeIfPresent(StudyIntensity.self, forKey: .intensity) ?? .balanced,
            timezone: try c.decodeIfPresent(String.self, forKey: .timezone) ?? "UTC",
            startDate: try c.decodeIfPresent(String.self, forKey: .startDate),
            targetDate: try c.decodeIfPresent(String.self, forKey: .targetDate),
            estimatedFinishDate: try c.decodeIfPresent(String.self, forKey: .estimatedFinishDate),
            dateSource: try c.decodeIfPresent(String.self, forKey: .dateSource),
            dailyMinutesBudget: try c.decodeIfPresent(Int.self, forKey: .dailyMinutesBudget),
            requiredDailyMinutes: try c.decodeIfPresent(Int.self, forKey: .requiredDailyMinutes),
            isOverloaded: try c.decodeIfPresent(Bool.self, forKey: .isOverloaded),
            reviewsAfterTarget: try c.decodeIfPresent(Int.self, forKey: .reviewsAfterTarget),
            readyCards: try c.decodeIfPresent(Int.self, forKey: .readyCards),
            studiedCards: try c.decodeIfPresent(Int.self, forKey: .studiedCards),
            status: try c.decodeIfPresent(String.self, forKey: .status),
            nextFrom: try c.decodeIfPresent(String.self, forKey: .nextFrom),
            totalDays: try c.decodeIfPresent(Int.self, forKey: .totalDays) ?? 0,
            totalCards: try c.decodeIfPresent(Int.self, forKey: .totalCards) ?? 0,
            dailyPlan: try c.decodeIfPresent([StudyDayResponse].self, forKey: .dailyPlan) ?? []
        )
    }
}

struct StudyPlanSettingsRequest: Encodable {
    let intensity: StudyIntensity
    let timezone: String
    let targetDate: String?
    enum CodingKeys: String, CodingKey {
        case intensity, timezone
        case targetDate = "target_date"
    }
}

struct StudyPlanPatchRequest: Encodable {
    let expectedRevision: Int
    let intensity: StudyIntensity?
    let timezone: String?
    let targetDate: String?
    enum CodingKeys: String, CodingKey {
        case expectedRevision = "expected_revision"
        case intensity, timezone
        case targetDate = "target_date"
    }
}

struct StudyDueResponse: Decodable {
    let computedAt: Date
    let decks: [StudyDueDeck]
    enum CodingKeys: String, CodingKey { case computedAt = "computed_at", decks }
}

struct StudyDueDeck: Decodable, Identifiable {
    let planID: UUID
    let parentDeckID: UUID
    let parentTitle: String
    let chapterDeckID: UUID
    let chapterTitle: String
    let date: String
    let newCards: Int
    let reviewCards: Int
    let overdueCards: Int
    let estimatedMinutes: Int
    let cards: [StudyDueCard]
    var id: UUID { chapterDeckID }
    enum CodingKeys: String, CodingKey {
        case planID = "plan_id", parentDeckID = "parent_deck_id", parentTitle = "parent_title"
        case chapterDeckID = "chapter_deck_id", chapterTitle = "chapter_title", date
        case newCards = "new_cards", reviewCards = "review_cards", overdueCards = "overdue_cards"
        case estimatedMinutes = "estimated_minutes", cards
    }
}

struct StudyDueCard: Decodable, Identifiable {
    let cardID: UUID
    let activityType: String
    let dueAt: Date
    let isOverdue: Bool
    let isDueNow: Bool
    let stateRevision: Int
    var id: UUID { cardID }
    enum CodingKeys: String, CodingKey {
        case cardID = "card_id", activityType = "activity_type", dueAt = "due_at"
        case isOverdue = "is_overdue", isDueNow = "is_due_now", stateRevision = "state_revision"
    }
}

struct StudyReviewRequest: Codable {
    let eventID: UUID
    let cardID: UUID
    let rating: String
    let occurredAt: Date
    let elapsedMS: Int
    let expectedRevision: Int
    enum CodingKeys: String, CodingKey {
        case eventID = "event_id", cardID = "card_id", rating
        case occurredAt = "occurred_at", elapsedMS = "elapsed_ms", expectedRevision = "expected_revision"
    }
}

struct StudyReviewResponse: Decodable {
    let eventID: UUID
    let cardID: UUID
    let nextDueAt: Date
    let stateRevision: Int
    let planRevision: Int
    let learningState: String
    enum CodingKeys: String, CodingKey {
        case eventID = "event_id", cardID = "card_id", nextDueAt = "next_due_at"
        case stateRevision = "state_revision", planRevision = "plan_revision", learningState = "learning_state"
    }
}


struct GeneratedDeckWithTimelineResponse: Decodable {
    let deck: GeneratedDeckResponse
    let timeline: StudyTimelineResponse?
}

// MARK: - Generation Status

struct DeckGenerationStatusResponse: Decodable {
    let deckID: UUID
    let generationStatus: String
    let chapters: [ChapterGenerationStatus]

    enum CodingKeys: String, CodingKey {
        case deckID = "deck_id"
        case generationStatus = "generation_status"
        case chapters
    }
}


struct ChapterGenerationStatus: Decodable, Identifiable {
    let id: UUID
    let title: String
    let generationStatus: String
    let cardCount: Int

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case generationStatus = "generation_status"
        case cardCount = "card_count"
    }
}
