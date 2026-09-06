import SwiftUI

struct ExamTakingView: View {

    let questionsResponse: ExamQuestionsResponse
    let onFinished: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var answers: [UUID: String] = [:]
    @State private var currentIndex = 0
    @State private var isSubmitting = false
    @State private var submissionResult: ExamSubmissionResponse?
    @State private var errorMessage: String?

    private var questions: [ExamQuestionResponse] {
        questionsResponse.questions.sorted { $0.position < $1.position }
    }

    private var currentQuestion: ExamQuestionResponse? {
        guard questions.indices.contains(currentIndex) else {
            return nil
        }

        return questions[currentIndex]
    }

    private var allQuestionsAnswered: Bool {
        questions.allSatisfy { answers[$0.id] != nil }
    }

    var body: some View {
        AppBackground {
            if let submissionResult {
                resultView(submissionResult)
            } else if let currentQuestion {
                questionView(currentQuestion)
            } else {
                emptyQuestionsView
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if submissionResult == nil {
                BackNavigationBar {
                    EmptyView()
                }
            }
        }
        .navigationBarBackButtonHidden()
    }

    private func questionView(
        _ question: ExamQuestionResponse
    ) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(examTitle)
                    .font(.custom("PlusJakartaSans-Bold", size: 13))
                    .foregroundStyle(Color.appAccent)

                Text("Question \(currentIndex + 1) of \(questions.count)")
                    .font(.custom("PlusJakartaSans-Regular", size: 13))
                    .foregroundStyle(Color.appTextSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)

            ProgressView(
                value: Double(currentIndex + 1),
                total: Double(max(questions.count, 1))
            )
            .tint(Color.appAccent)
            .padding(.horizontal, 24)
            .padding(.top, 16)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(question.question)
                        .font(.custom("PlusJakartaSans-ExtraBold", size: 28))
                        .foregroundStyle(Color.appTextPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    if question.questionType == "multiple_choice"
                        || question.questionType == "true_false" {
                        optionsView(for: question)
                    } else {
                        Text("This question type is not supported yet.")
                            .font(.custom("PlusJakartaSans-Regular", size: 14))
                            .foregroundStyle(Color.appWarning)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.custom("PlusJakartaSans-Regular", size: 13))
                            .foregroundStyle(Color.appError)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 32)
                .padding(.bottom, 32)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                if currentIndex > 0 {
                    Button {
                        currentIndex -= 1
                    } label: {
                        Image(systemName: "arrow.left")
                            .foregroundStyle(Color.appTextPrimary)
                            .frame(width: 54, height: 54)
                            .background(Color.appSecondarySurface, in: RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.appBorder, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                AppButton(
                    title: currentIndex == questions.count - 1
                        ? (isSubmitting ? "Submitting..." : "Submit Exam")
                        : "Next",
                    icon: .sf(currentIndex == questions.count - 1 ? "checkmark" : "arrow.right"),
                    iconPosition: .right,
                    foreground: Color.appTextPrimary,
                    background: Color.appAccent
                ) {
                    if currentIndex == questions.count - 1 {
                        submitExam()
                    } else {
                        currentIndex += 1
                    }
                }
                .disabled(
                    answers[question.id] == nil
                        || isSubmitting
                        || (currentIndex == questions.count - 1
                            && !allQuestionsAnswered)
                )
                .opacity(
                    answers[question.id] == nil
                        || isSubmitting
                        || (currentIndex == questions.count - 1
                            && !allQuestionsAnswered)
                        ? 0.45
                        : 1
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private func optionsView(
        for question: ExamQuestionResponse
    ) -> some View {
        VStack(spacing: 10) {
            ForEach(question.options, id: \.self) { option in
                Button {
                    answers[question.id] = option
                    errorMessage = nil
                } label: {
                    HStack(spacing: 12) {
                        Text(option)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 15))
                            .foregroundStyle(Color.appTextPrimary)
                            .multilineTextAlignment(.leading)

                        Spacer()

                        Image(
                            systemName: answers[question.id] == option
                                ? "checkmark.circle.fill"
                                : "circle"
                        )
                        .foregroundStyle(
                            answers[question.id] == option
                                ? Color.appAccent
                                : Color.appTextSecondary
                        )
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 58)
                    .background(
                        answers[question.id] == option
                            ? Color.appAccent.opacity(0.12)
                            : Color.appSurface,
                        in: RoundedRectangle(cornerRadius: 8)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                answers[question.id] == option
                                    ? Color.appAccent
                                    : Color.appBorder,
                                lineWidth: answers[question.id] == option ? 2 : 1
                            )
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func resultView(
        _ result: ExamSubmissionResponse
    ) -> some View {
        VStack(spacing: 22) {
            Spacer()

            Image(
                systemName: result.passed
                    ? "checkmark.circle.fill"
                    : "arrow.counterclockwise.circle.fill"
            )
            .font(.system(size: 64))
            .foregroundStyle(
                result.passed ? Color.appSuccess : Color.appWarning
            )

            Text(result.passed ? "Exam passed" : "Keep working")
                .font(.custom("PlusJakartaSans-ExtraBold", size: 32))
                .foregroundStyle(Color.appTextPrimary)

            Text("\(result.score, specifier: "%.0f")%")
                .font(.custom("PlusJakartaSans-ExtraBold", size: 48))
                .foregroundStyle(Color.appAccent)

            Text("\(result.correctAnswers) of \(result.totalQuestions) correct")
                .font(.custom("PlusJakartaSans-Regular", size: 15))
                .foregroundStyle(Color.appTextSecondary)

            Text("Attempt \(result.attemptNumber) · Passing score \(result.passingScore, specifier: "%.0f")%")
                .font(.custom("PlusJakartaSans-Regular", size: 13))
                .foregroundStyle(Color.appTextSecondary)

            Spacer()

            AppButton(
                title: "Back to deck",
                icon: .sf("arrow.left"),
                foreground: Color.appTextPrimary,
                background: Color.appAccent
            ) {
                onFinished()
                dismiss()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    private var emptyQuestionsView: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("No questions available")
                .font(.custom("PlusJakartaSans-Bold", size: 20))
                .foregroundStyle(Color.appTextPrimary)
            Text("Mr. Ed could not find any questions for this exam.")
                .font(.custom("PlusJakartaSans-Regular", size: 14))
                .foregroundStyle(Color.appTextSecondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, 24)
    }

    private var examTitle: String {
        switch questionsResponse.examType {
        case .firstHalf:
            return "FIRST HALF EXAM"
        case .secondHalf:
            return "SECOND HALF EXAM"
        case .final:
            return "FINAL EXAM"
        }
    }

    private func submitExam() {
        guard !isSubmitting, allQuestionsAnswered else {
            return
        }

        isSubmitting = true
        errorMessage = nil

        let submissionAnswers: [ExamAnswer] = questions.compactMap {
            (question: ExamQuestionResponse) -> ExamAnswer? in
            guard let answer = answers[question.id] else {
                return nil
            }

            return ExamAnswer(questionID: question.id, answer: answer)
        }

        Task {
            do {
                let result = try await ExamAPI.shared.submitExam(
                    examID: questionsResponse.examID,
                    answers: submissionAnswers
                )

                await MainActor.run {
                    submissionResult = result
                    isSubmitting = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSubmitting = false
                }
            }
        }
    }
}

#Preview {
    Text("Exam preview requires backend questions")
}
