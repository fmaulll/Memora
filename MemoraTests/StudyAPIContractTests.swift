import Foundation
import Testing
@testable import Memora

private final class StudyFixtureBundle: NSObject {}

struct StudyAPIContractTests {
    private func fixture(_ name: String) throws -> Data {
        let bundle = Bundle(for: StudyFixtureBundle.self)
        let url = try #require(
            bundle.url(forResource: name, withExtension: "json")
                ?? bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures/Phase2D")
        )
        return try Data(contentsOf: url)
    }

    private func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try APIJSON.makeDecoder().decode(type, from: fixture(name))
    }

    @Test func progressFactsAndAggregatesDecode() throws {
        let progress = try decode(StudyProgressResponse.self, "progress.response")
        #expect(progress.summary.learnedCardCount == 4)
        #expect(progress.summary.totalCardCount == 20)
        #expect(progress.decks[0].completionPercentage == 40)
        #expect(progress.decks[0].cards.filter { $0.learnedAt != nil }.count == 4)
        #expect(progress.decks[0].progressEpoch != progress.decks[1].progressEpoch)
        let completed = try decode(StudyProgressResponse.self, "progress-chapter-completed.response")
        #expect(completed.decks.contains { $0.completed })
        let reset = try decode(StudyProgressResponse.self, "progress-after-reset.response")
        #expect(reset.summary.learnedCardCount == 0)
    }

    @Test func immutableSubmissionPreservesIdentityEpochAndWireShape() throws {
        let submission = try decode(StudyProgressSubmission.self, "submission.request")
        let encoder = APIJSON.makeEncoder()
        let payload = try encoder.encode(submission)
        let retriedPayload = try encoder.encode(submission)
        #expect(payload == retriedPayload)
        let restored = try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: payload)
        #expect(restored == submission)
        let json = try #require(JSONSerialization.jsonObject(with: payload) as? [String: Any])
        #expect(Set(json.keys) == ["session_id", "completed_at", "decks"])
        let groups = try #require(json["decks"] as? [[String: Any]])
        for group in groups {
            #expect(Set(group.keys) == ["deck_id", "progress_epoch", "learned_cards"])
            let cards = try #require(group["learned_cards"] as? [[String: Any]])
            for card in cards {
                #expect(Set(card.keys) == ["card_id", "phase", "answer"])
                #expect(card["phase"] as? String == "review")
                #expect(card["answer"] as? String == "got_it")
            }
        }
        let receipt = try decode(StudyProgressSubmissionResponse.self, "submission.response")
        let replay = try decode(StudyProgressSubmissionResponse.self, "submission-replay.response")
        #expect(receipt.sessionID == submission.sessionID)
        #expect(receipt.sessionID == replay.sessionID)
        #expect(receipt.submittedAt == replay.submittedAt)
        let duplicate = try decode(StudyProgressSubmissionResponse.self, "submission-already-learned.response")
        #expect(duplicate.decks.allSatisfy { $0.acceptedCardIDs.isEmpty })
        #expect(duplicate.decks.contains { !$0.alreadyLearnedCardIDs.isEmpty })
    }

    @Test func studyAllPayloadKeepsEachOwningDeckAndEpoch() throws {
        let groups = (0..<2).map { _ in
            DeckLearnedTransitions(deckID: UUID(), progressEpoch: UUID(), learnedCards: [.init(cardID: UUID())])
        }
        let request = StudyProgressSubmission(sessionID: UUID(), completedAt: Date(timeIntervalSince1970: 1000), decks: groups)
        let restored = try APIJSON.makeDecoder().decode(StudyProgressSubmission.self, from: APIJSON.makeEncoder().encode(request))
        #expect(restored == request)
        #expect(restored.decks[0].progressEpoch != restored.decks[1].progressEpoch)
    }

    @Test func nonqualifyingTransitionPayloadsAreRejected() throws {
        let cardID = UUID().uuidString
        for (phase, answer) in [("new", "got_it"), ("review", "again")] {
            let payload = Data("{\"card_id\":\"\(cardID)\",\"phase\":\"\(phase)\",\"answer\":\"\(answer)\"}".utf8)
            #expect(throws: DecodingError.self) {
                try APIJSON.makeDecoder().decode(LearnedCardTransition.self, from: payload)
            }
        }
    }

    @Test func resetHasPerDeckEpochsAndRetryIdentity() throws {
        let request = try decode(StudyProgressResetRequest.self, "reset.request")
        let response = try decode(StudyProgressResetResponse.self, "reset.response")
        let replay = try decode(StudyProgressResetResponse.self, "reset-replay.response")
        #expect(request.resetID == response.resetID)
        #expect(response.resetAt == replay.resetAt)
        #expect(response.decks.count == request.expectedDecks.count)
        for deck in response.decks {
            #expect(deck.previousEpoch != deck.progressEpoch)
            #expect(request.expectedDecks.contains { $0.deckID == deck.deckID && $0.progressEpoch == deck.previousEpoch })
        }
        let encoded = try APIJSON.makeEncoder().encode(request)
        #expect(try APIJSON.makeDecoder().decode(StudyProgressResetRequest.self, from: encoded) == request)
    }

    @Test func persistentPlanPreservesCalendarDatesAndNullableFields() throws {
        let plan = try decode(StudyPlanResponse.self, "plan.response")
        #expect(plan.startDate.rawValue == "2026-09-21")
        #expect(plan.timezone == "Asia/Jakarta")
        #expect(plan.requestedTargetDate == nil)
        #expect(plan.requiredDailyCardCount == nil)
        #expect(plan.targetAchievable == nil)
        #expect(plan.items.contains { $0.status == .partial && $0.period == .historical && $0.closedAt != nil })
        let exam = try #require(plan.items.first { $0.itemType == .firstHalfExam })
        #expect(exam.chapterID == nil && exam.targetCardCount == nil)
        #expect(exam.actualLearnedCount == nil && exam.shortfallCount == nil)
        #expect(exam.closedAt == nil && exam.achievedAt == nil)
        let recalculated = try decode(StudyPlanResponse.self, "recalculate.response")
        #expect(recalculated.id == plan.id)
        let roundTrip = try APIJSON.makeDecoder().decode(StudyPlanResponse.self, from: APIJSON.makeEncoder().encode(plan))
        #expect(roundTrip.startDate == plan.startDate)
    }

    @Test func allPlanStatesAndPopulatedOptionalsDecode() throws {
        var plan = try #require(JSONSerialization.jsonObject(with: fixture("plan.response")) as? [String: Any])
        plan["requested_target_date"] = "2026-09-26"
        plan["required_daily_card_count"] = 0
        plan["target_achievable"] = false
        plan["projection_blocked"] = true
        plan["count_source"] = "planned"
        let originalItems = try #require(plan["items"] as? [[String: Any]])
        var item = originalItems[0]
        for status in ["upcoming", "active", "completed", "missed", "partial"] {
            for period in ["historical", "current", "future"] {
                item["status"] = status
                item["period"] = period
                item["achieved_at"] = "2026-09-24T17:15:54.123456Z"
                plan["items"] = [item]
                let result = try APIJSON.makeDecoder().decode(StudyPlanResponse.self, from: JSONSerialization.data(withJSONObject: plan))
                #expect(result.requiredDailyCardCount == 0 && result.targetAchievable == false)
                #expect(result.projectionBlocked)
                #expect(result.items[0].achievedAt != nil)
            }
        }
    }

    @Test func calendarDatesValidateWithoutTimezoneConversion() throws {
        #expect(APICalendarDate(rawValue: "2024-02-29") != nil)
        for value in ["2026-02-29", "2026-04-31", "2026-13-01", "2026-9-01", "2026-09-21T00:00:00Z", "0000-01-01"] {
            #expect(APICalendarDate(rawValue: value) == nil)
        }
        let request = StudyPlanCreateRequest(startDate: APICalendarDate(rawValue: "2026-09-21"), requestedTargetDate: nil, timezone: "Asia/Jakarta", studyWeekdays: [0, 6], dailyCardLimit: 10)
        let json = try #require(JSONSerialization.jsonObject(with: APIJSON.makeEncoder().encode(request)) as? [String: Any])
        #expect(json["start_date"] as? String == "2026-09-21")
        #expect(json["study_weekdays"] as? [Int] == [0, 6])
    }

    @Test func examsUseServerAvailabilityAndAllowAbsentIDs() throws {
        let single = try decode(ExamProgressionResponse.self, "exams-one-chapter.response")
        let second = try #require(single.exams.first { $0.examType == .secondHalf })
        #expect(second.examID == nil && second.status == .notApplicable)
        #expect(!second.applicable && !second.available && second.chapterIDs.isEmpty)
        #expect(Set(single.exams.map(\.id)).count == 3)
        let locked = try decode(ExamProgressionResponse.self, "exams-locked.response")
        #expect(locked.exams.allSatisfy { !$0.available })
        let unlocked = try decode(ExamProgressionResponse.self, "exams-unlocked.response")
        #expect(unlocked.exams.contains { $0.available })
        let passed = try decode(ExamProgressionResponse.self, "exams-passed.response")
        #expect(passed.exams.contains { $0.passed && $0.completed && $0.available && $0.completedAt != nil })
    }

    @Test func legacyExamAndCardDatesAcceptNaiveUTC() throws {
        let source = try decode(ExamSourceCardsResponse.self, "exam-cards.response")
        #expect(!source.cards.isEmpty)
        let questions = try decode(ExamQuestionsResponse.self, "exam-questions.response")
        let generated = try decode(ExamQuestionsResponse.self, "exam-generate-existing.response")
        #expect(questions.examID == generated.examID)
        let submission = try decode(ExamSubmissionResponse.self, "exam-submission.response")
        #expect(submission.passed)
        let answer = ExamSubmissionRequest(answers: [.init(questionID: questions.questions[0].id, answer: "Actual option text")])
        let answerJSON = try #require(JSONSerialization.jsonObject(with: APIJSON.makeEncoder().encode(answer)) as? [String: Any])
        #expect((answerJSON["answers"] as? [[String: Any]])?.first?["answer"] as? String == "Actual option text")
        #expect(APIJSON.timestamp("2026-09-24T17:15:54.792701", allowsNaiveUTC: true) == APIJSON.timestamp("2026-09-24T17:15:54.792701Z"))
        #expect(APIJSON.timestamp("2026-09-24T17:15:54", allowsNaiveUTC: true) != nil)
        #expect(APIJSON.timestamp("2026-09-24T17:15:54") == nil)
        #expect(APIJSON.timestamp("2026-09-24T18:00:00+07:00") == APIJSON.timestamp("2026-09-24T11:00:00Z"))
    }

    @Test func structuredErrorsRetainMachineCode() throws {
        for (name, status, code) in [
            ("error-stale-epoch.response", 409, "stale_progress_epoch"),
            ("error-idempotency-conflict.response", 409, "idempotency_conflict"),
            ("error-content-not-ready.response", 409, "study_plan_content_not_ready"),
            ("error-exam-locked.response", 403, "exam_locked")
        ] {
            let error = APIError.responseError(statusCode: status, data: try fixture(name))
            #expect(error.statusCode == status && error.businessCode == code)
        }
        let future = APIError.responseError(statusCode: 409, data: Data(#"{"detail":{"code":"future_code","message":"Keep this"}}"#.utf8))
        #expect(future.businessCode == "future_code")
    }

    @Test func validationLocationsLegacyErrorsAndPlain500Decode() throws {
        let error = APIError.responseError(statusCode: 422, data: try fixture("error-validation.response"))
        guard case .validationError(_, let issues) = error else {
            Issue.record("Expected validation error"); return
        }
        #expect(issues[0].type == "timezone_aware")
        #expect(issues[0].location == [.field("body"), .field("completed_at")])
        let indexed = APIError.responseError(statusCode: 422, data: Data(#"{"detail":[{"type":"missing","loc":["body","decks",0,"deck_id"],"msg":"Required","ctx":{},"input":null}]}"#.utf8))
        guard case .validationError(_, let indexedIssues) = indexed else {
            Issue.record("Expected indexed validation issue"); return
        }
        #expect(indexedIssues[0].location[2] == .index(0))
        let auth = APIError.responseError(statusCode: 401, data: try fixture("error-authentication.response"))
        if case .unauthorized = auth {} else { Issue.record("401 must retain auth handling") }
        let missing = APIError.responseError(statusCode: 404, data: try fixture("error-exam-not-found.response"))
        #expect(missing.statusCode == 404 && missing.businessCode == nil)
        let failure = APIError.responseError(statusCode: 500, data: Data("Internal Server Error".utf8))
        #expect(failure.statusCode == 500 && failure.businessCode == nil)
        #expect(failure.localizedDescription.contains("Internal Server Error"))
        #expect(APIError.responseError(statusCode: 503, data: nil).statusCode == 503)
    }
}
