import Foundation
import SwiftData
import Testing
@testable import Memora

@MainActor
struct DeckPositionAndExamTests {
    @Test func decodesBackendPosition() throws {
        let json = """
        {"id":"11111111-1111-1111-1111-111111111111",
         "user_id":"22222222-2222-2222-2222-222222222222",
         "parent_deck_id":null,"title":"Biology","position":7,
         "key_concepts":["Cells"],"card_count":12,"subject":"Science",
         "education_level":"University","learning_language":"English",
         "is_favorite":false,"generation_status":"completed",
         "created_at":"2026-09-10T00:00:00Z","updated_at":"2026-09-10T00:00:00Z"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(DeckResponse.self, from: Data(json.utf8))
        #expect(response.position == 7)
    }

    @Test func positionsPersistAndSortBeforeCreationDate() throws {
        let container = try ModelContainer(for: StudyDeck.self, StudyFlashcardCard.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let first = StudyDeck(title: "First", subject: "S", educationLevel: "U", createdAt: .now, position: 1)
        let second = StudyDeck(title: "Second", subject: "S", educationLevel: "U", createdAt: .distantPast, position: 2)
        container.mainContext.insert(second)
        container.mainContext.insert(first)
        try container.mainContext.save()
        let context = ModelContext(container)
        let restored = try context.fetch(FetchDescriptor<StudyDeck>()).sorted(by: StudyDeck.chapterOrder)
        #expect(restored.map(\.position) == [1, 2])
        #expect(restored.map(\.title) == ["First", "Second"])
    }

    @Test func equalPositionsUseIDAsBackendTieBreaker() {
        let first = StudyDeck(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                              title: "Z", subject: "S", educationLevel: "U", createdAt: .now, position: 2)
        let second = StudyDeck(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                               title: "A", subject: "S", educationLevel: "U", createdAt: .distantPast, position: 2)
        #expect([second, first].sorted(by: StudyDeck.chapterOrder).map(\.id) == [first.id, second.id])
    }

    @Test func backendLockCannotBeOverriddenByPassedPrerequisites() {
        let exams = [exam(.firstHalf, status: .completed, passed: true), exam(.secondHalf, status: .locked)]
        #expect(!ExamAccessPolicy.canStart(.secondHalf, exams: exams, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
        #expect(!ExamAccessPolicy.canStart(.final, exams: exams, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
    }

    @Test func passingIsRequiredNotJustCompletingAnAttempt() {
        let failedFirst = [exam(.firstHalf, status: .completed), exam(.secondHalf, status: .unlocked)]
        #expect(!ExamAccessPolicy.canStart(.secondHalf, exams: failedFirst, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
        let passedFirst = [exam(.firstHalf, status: .completed, passed: true), exam(.secondHalf, status: .unlocked)]
        #expect(ExamAccessPolicy.canStart(.secondHalf, exams: passedFirst, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
        let failedSecond = [exam(.secondHalf, status: .completed), exam(.final, status: .unlocked)]
        #expect(!ExamAccessPolicy.canStart(.final, exams: failedSecond, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
        let passedSecond = [exam(.firstHalf, status: .completed, passed: true), exam(.secondHalf, status: .completed, passed: true), exam(.final, status: .unlocked)]
        #expect(ExamAccessPolicy.canStart(.final, exams: passedSecond, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
    }

    @Test func missingStatusAndGenerationBlockExamsButFailedAttemptsCanRetry() {
        #expect(!ExamAccessPolicy.canStart(.firstHalf, exams: [], isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
        let first = [exam(.firstHalf, status: .unlocked)]
        #expect(!ExamAccessPolicy.canStart(.firstHalf, exams: first, isGenerating: true, firstHalfComplete: true, secondHalfComplete: true))
        #expect(ExamAccessPolicy.canStart(.firstHalf, exams: first, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
        let retry = [exam(.firstHalf, status: .completed)]
        #expect(ExamAccessPolicy.canStart(.firstHalf, exams: retry, isGenerating: false, firstHalfComplete: true, secondHalfComplete: true))
    }

    @Test func localChapterGatesApplyEvenWhenBackendStartsUnlocked() {
        let exams = [exam(.firstHalf, status: .unlocked)]
        #expect(!ExamAccessPolicy.canStart(.firstHalf, exams: exams, isGenerating: false,
                                         firstHalfComplete: false, secondHalfComplete: true))
        let second = [exam(.firstHalf, status: .completed, passed: true), exam(.secondHalf, status: .unlocked)]
        #expect(!ExamAccessPolicy.canStart(.secondHalf, exams: second, isGenerating: false,
                                         firstHalfComplete: true, secondHalfComplete: false))
    }

    @Test func oddSplitUsesPositionThenIDAndRequiresEveryCard() {
        var chapters: [StudyDeck] = []
        for position in [5, 2, 4, 1, 3] {
            let card = StudyFlashcardCard(front: "Q", back: "A")
            card.reviewCount = 2
            card.correctCount = 1
            card.interval = 1
            chapters.append(StudyDeck(title: "Chapter", subject: "S", educationLevel: "U", cards: [card], position: position))
        }
        let progress = ChapterExamProgress(chapters: chapters)
        #expect(progress.firstHalf.map(\.position) == [1, 2, 3])
        #expect(progress.secondHalf.map(\.position) == [4, 5])
        #expect(progress.firstHalfComplete)
        #expect(progress.secondHalfComplete)
        let card = chapters[1].cards[0]
        chapters[1].isStudySessionActive = true
        chapters[1].studyConfirmationIDs = [card.id]
        #expect(!ChapterExamProgress(chapters: chapters).firstHalfComplete)
        #expect(!ChapterExamProgress(chapters: []).firstHalfComplete)
    }

    private func exam(_ type: ExamType, status: ExamStatus, passed: Bool = false) -> ExamStatusResponse {
        ExamStatusResponse(examID: UUID(), examType: type, status: status, passed: passed,
                           bestScore: nil, attemptCount: 0, completedAt: nil)
    }
}
