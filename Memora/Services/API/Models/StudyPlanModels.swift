import Foundation

struct StudyPlanCreateRequest: Codable {
    let startDate: APICalendarDate?
    let requestedTargetDate: APICalendarDate?
    let timezone: String
    // Backend convention: Monday = 0, Sunday = 6 (not Calendar.weekday).
    let studyWeekdays: [Int]
    let dailyCardLimit: Int

    enum CodingKeys: String, CodingKey {
        case startDate = "start_date", requestedTargetDate = "requested_target_date", timezone
        case studyWeekdays = "study_weekdays", dailyCardLimit = "daily_card_limit"
    }
}

struct StudyPlanResponse: Codable, Identifiable {
    let id: UUID
    let parentDeckID: UUID
    let startDate: APICalendarDate
    let requestedTargetDate: APICalendarDate?
    let estimatedFinishDate: APICalendarDate
    let timezone: String
    let studyWeekdays: [Int]
    let dailyCardLimit: Int
    let requiredDailyCardCount: Int?
    let targetAchievable: Bool?
    let remainingCardCount: Int
    let projectionBlocked: Bool
    let revision: Int
    let algorithmVersion: String
    let countSource: StudyPlanCountSource
    let createdAt: Date
    let updatedAt: Date
    let chapters: [StudyPlanChapterResponse]
    let items: [StudyPlanItemResponse]

    enum CodingKeys: String, CodingKey {
        case id, parentDeckID = "parent_deck_id", startDate = "start_date"
        case requestedTargetDate = "requested_target_date", estimatedFinishDate = "estimated_finish_date"
        case timezone, studyWeekdays = "study_weekdays", dailyCardLimit = "daily_card_limit"
        case requiredDailyCardCount = "required_daily_card_count", targetAchievable = "target_achievable"
        case remainingCardCount = "remaining_card_count", projectionBlocked = "projection_blocked"
        case revision, algorithmVersion = "algorithm_version", countSource = "count_source"
        case createdAt = "created_at", updatedAt = "updated_at", chapters, items
    }
}

enum StudyPlanCountSource: String, Codable { case planned, actual }
enum StudyPlanItemType: String, Codable {
    case learn
    case firstHalfExam = "first_half_exam"
    case secondHalfExam = "second_half_exam"
    case finalExam = "final_exam"
}
enum StudyPlanItemStatus: String, Codable { case upcoming, active, completed, partial, missed }
enum StudyPlanItemPeriod: String, Codable { case historical, current, future }

struct StudyPlanChapterResponse: Codable, Identifiable {
    let id: UUID
    let title: String
    let position: Int
    let generationStatus: String
    let scheduledCardCount: Int

    enum CodingKeys: String, CodingKey {
        case id, title, position, generationStatus = "generation_status"
        case scheduledCardCount = "scheduled_card_count"
    }
}

struct StudyPlanItemResponse: Codable, Identifiable {
    let id: UUID
    let scheduledDate: APICalendarDate
    let itemType: StudyPlanItemType
    let chapterID: UUID?
    let targetCardCount: Int?
    let position: Int
    let actualLearnedCount: Int?
    let shortfallCount: Int?
    let status: StudyPlanItemStatus
    let period: StudyPlanItemPeriod
    let closedAt: Date?
    let achievedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, scheduledDate = "scheduled_date", itemType = "item_type", chapterID = "chapter_id"
        case targetCardCount = "target_card_count", position, actualLearnedCount = "actual_learned_count"
        case shortfallCount = "shortfall_count", status, period
        case closedAt = "closed_at", achievedAt = "achieved_at"
    }
}
