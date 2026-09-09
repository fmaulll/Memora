import Foundation

/// These chapter checks are local UX gates. The backend currently validates exam
/// results only; it must add chapter tracking to enforce study completion.
struct ExamAccessPolicy {
    static func canStart(
        _ type: ExamType,
        exams: [ExamStatusResponse],
        isGenerating: Bool,
        firstHalfComplete: Bool,
        secondHalfComplete: Bool
    ) -> Bool {
        guard !isGenerating,
              let exam = exams.first(where: { $0.examType == type }),
              exam.status != .locked else { return false }
        let firstPassed = exams.contains { $0.examType == .firstHalf && $0.passed }
        let secondPassed = exams.contains { $0.examType == .secondHalf && $0.passed }
        switch type {
        case .firstHalf:
            return exam.passed || firstHalfComplete
        case .secondHalf:
            return firstPassed && (exam.passed || secondHalfComplete)
        case .final:
            return firstPassed && secondPassed
        }
    }

    static func requirement(for type: ExamType) -> String {
        switch type {
        case .firstHalf:
            return "Finish all chapters in the first half."
        case .secondHalf:
            return "Finish the remaining chapters and pass the First Half Exam."
        case .final:
            return "Pass both half exams to unlock your final exam."
        }
    }
}

@MainActor
struct ChapterExamProgress {
    let chapters: [StudyDeck]
    let firstHalf: [StudyDeck]
    let secondHalf: [StudyDeck]
    let completedIDs: Set<UUID>

    init(chapters: [StudyDeck]) {
        self.chapters = chapters.filter { !$0.needsDeletion }.sorted(by: StudyDeck.chapterOrder)
        let split = (self.chapters.count + 1) / 2
        firstHalf = Array(self.chapters.prefix(split))
        secondHalf = Array(self.chapters.dropFirst(split))
        completedIDs = Set(self.chapters.filter {
            let progress = DeckProgressSummary(deck: $0, isSubscribed: true, now: .now)
            return progress.totalCount > 0 && progress.confirmedCount == progress.totalCount
        }.map(\.id))
    }

    var firstHalfComplete: Bool {
        !firstHalf.isEmpty && firstHalf.allSatisfy { completedIDs.contains($0.id) }
    }
    var secondHalfComplete: Bool {
        !chapters.isEmpty && secondHalf.allSatisfy { completedIDs.contains($0.id) }
    }

    func coverage(for type: ExamType) -> String {
        switch type {
        case .firstHalf:
            return rangeLabel(start: 1, count: firstHalf.count)
        case .secondHalf:
            return rangeLabel(start: firstHalf.count + 1, count: secondHalf.count)
        case .final:
            return "All \(chapters.count) chapters"
        }
    }

    func completionLabel(for type: ExamType) -> String {
        let group = type == .firstHalf ? firstHalf : type == .secondHalf ? secondHalf : chapters
        return "\(group.filter { completedIDs.contains($0.id) }.count)/\(group.count) chapters finished"
    }

    private func rangeLabel(start: Int, count: Int) -> String {
        if count == 0 { return "No additional chapters" }
        if count == 1 { return "Chapter \(start)" }
        return "Chapters \(start)–\(start + count - 1)"
    }
}
