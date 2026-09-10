import SwiftUI

/// The persisted plan is the source of truth; the timeline shown during AI
/// creation is only a forecast until the server admits the deck.
struct StudyTimelineView: View {
    let parentDeckID: UUID
    let parentTitle: String

    @State private var timeline: StudyTimelineResponse?
    @State private var isLoading = true
    @State private var isLoadingMore = false
    @State private var errorMessage: String?
    @State private var selectedDay: StudyDayResponse?
    @State private var dueItems: [StudyDueDeck] = []
    @State private var isLoadingDueItems = false
    @State private var isCreatingPlan = false

    var body: some View {
        AppBackground {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if isLoading {
                        ProgressView("Loading your study timeline…").tint(Color.appAccent)
                    } else if let timeline {
                        timelineSummary(timeline)
                        timelinePath(timeline)
                        if timeline.nextFrom != nil {
                            Button(isLoadingMore ? "Loading…" : "Show more dates") {
                                Task { await loadMore(timeline) }
                            }
                            .disabled(isLoadingMore)
                            .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                            .foregroundStyle(Color.appAccent)
                            .frame(maxWidth: .infinity)
                        }
                        maintenanceNote(timeline)
                    } else if let errorMessage {
                        ContentUnavailableView("Study timeline unavailable", systemImage: "calendar.badge.exclamationmark", description: Text(errorMessage))
                        Button(isCreatingPlan ? "Creating timeline…" : "Create study timeline") {
                            Task { await createPlan() }
                        }
                        .disabled(isCreatingPlan)
                        .font(.custom("PlusJakartaSans-SemiBold", size: 14))
                        .foregroundStyle(Color.appAccent)
                    }
                }
                .padding(20)
            }
            .safeAreaInset(edge: .top, spacing: 0) { BackNavigationBar { EmptyView() } }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden()
        .task { await load() }
        .sheet(item: $selectedDay) { day in
            StudyTimelineDaySheet(day: day, decks: dueItems, isLoading: isLoadingDueItems)
                .presentationDetents([.medium, .large])
                .presentationBackground(Color.appBackground)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STUDY TIMELINE").font(.custom("PlusJakartaSans-Bold", size: 11)).tracking(1.4).foregroundStyle(Color.appAccent)
            Text(parentTitle).font(.custom("PlusJakartaSans-ExtraBold", size: 30)).foregroundStyle(Color.appTextPrimary)
            Text("A plan for introductions and reviews. The path ends at your goal; maintenance reviews continue afterward.")
                .font(.custom("PlusJakartaSans-Regular", size: 13)).foregroundStyle(Color.appTextSecondary)
        }
    }

    private func timelineSummary(_ plan: StudyTimelineResponse) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(plan.status?.capitalized ?? "Active", systemImage: plan.status == "maintenance" ? "arrow.triangle.2.circlepath" : "calendar")
                    .foregroundStyle(Color.appAccent)
                Spacer()
                Text(plan.intensity.title).font(.custom("PlusJakartaSans-SemiBold", size: 12)).foregroundStyle(Color.appTextSecondary)
            }
            Text(goalLabel(plan)).font(.custom("PlusJakartaSans-Bold", size: 18)).foregroundStyle(Color.appTextPrimary)
            HStack(spacing: 18) {
                timelineMetric("Daily", value: "\(plan.dailyMinutesBudget ?? 0) min")
                timelineMetric("Required", value: "\(plan.requiredDailyMinutes ?? 0) min")
                timelineMetric("Cards", value: "\(plan.totalCards)")
            }
            if plan.isOverloaded == true {
                Label("This deadline needs more time than the selected daily budget. You can still follow it, but some reviews may continue after the target.", systemImage: "exclamationmark.triangle.fill")
                    .font(.custom("PlusJakartaSans-Regular", size: 12)).foregroundStyle(Color.appWarning)
            }
        }
        .padding(16).background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }

    private func timelineMetric(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.custom("PlusJakartaSans-Bold", size: 15)).foregroundStyle(Color.appTextPrimary)
            Text(label).font(.custom("PlusJakartaSans-Regular", size: 11)).foregroundStyle(Color.appTextSecondary)
        }
    }

    private func timelinePath(_ plan: StudyTimelineResponse) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(plan.dailyPlan.enumerated()), id: \.element.date) { index, day in
                Button { open(day) } label: {
                    HStack(spacing: 12) {
                        if index.isMultiple(of: 2) { dayContent(day, alignment: .leading); Spacer(minLength: 28) }
                        else { Spacer(minLength: 28); dayContent(day, alignment: .trailing) }
                        VStack(spacing: 0) {
                            Circle().fill(dayColor(day)).frame(width: 16, height: 16)
                            if index < plan.dailyPlan.count - 1 { Rectangle().fill(Color.appBorder).frame(width: 2, height: 38) }
                        }
                        .accessibilityHidden(true)
                        if !index.isMultiple(of: 2) { Spacer(minLength: 0) }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(accessibilityLabel(day))
                .accessibilityHint("Opens cards scheduled for this date.")
            }
        }
    }

    private func dayContent(_ day: StudyDayResponse, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(day.date).font(.custom("PlusJakartaSans-Bold", size: 13)).foregroundStyle(Color.appTextPrimary)
            Text(daySummary(day)).font(.custom("PlusJakartaSans-Regular", size: 12)).foregroundStyle(Color.appTextSecondary)
            if let minutes = day.estimatedMinutes, minutes > 0 { Text("~\(minutes) min").font(.custom("PlusJakartaSans-SemiBold", size: 11)).foregroundStyle(Color.appAccent) }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
        .padding(12).background(Color.appSurface, in: RoundedRectangle(cornerRadius: 8))
        .overlay { RoundedRectangle(cornerRadius: 8).stroke(Color.appBorder, lineWidth: 1) }
    }

    private func dayColor(_ day: StudyDayResponse) -> Color {
        if (day.completedReviews ?? 0) > 0 { return .appSuccess }
        if day.date == timelineToday { return .appAccent }
        return day.date < timelineToday ? .appError : .appInfo
    }
    private var timelineToday: String { Self.dateString(Date(), timezone: timeline?.timezone ?? TimeZone.current.identifier) }
    private func daySummary(_ day: StudyDayResponse) -> String {
        let new = day.readyNewCards ?? day.newCards
        let review = day.reviewCards ?? 0
        return new + review == 0 ? "Rest and let it settle" : "\(new) new · \(review) reviews"
    }
    private func accessibilityLabel(_ day: StudyDayResponse) -> String { "\(day.date). \(daySummary(day)). \(day.focus)" }
    private func goalLabel(_ plan: StudyTimelineResponse) -> String {
        if let target = plan.targetDate { return "Goal: \(target)" }
        return "Estimated finish: \(plan.estimatedFinishDate ?? "in progress")"
    }
    private func maintenanceNote(_ plan: StudyTimelineResponse) -> some View {
        Text(plan.status == "maintenance" ? "All current cards have been introduced. Keep up with the reviews that become due." : "After the goal date, maintenance reviews remain available here when they are due.")
            .font(.custom("PlusJakartaSans-Regular", size: 12)).foregroundStyle(Color.appTextSecondary)
    }

    private func load() async {
        isLoading = true; errorMessage = nil
        do { timeline = try await AIService.shared.studyPlan(parentDeckID: parentDeckID) }
        catch { errorMessage = error.localizedDescription }
        isLoading = false
    }
    private func loadMore(_ current: StudyTimelineResponse) async {
        guard let next = current.nextFrom else { return }
        isLoadingMore = true; defer { isLoadingMore = false }
        do {
            let nextPage = try await AIService.shared.studyPlan(parentDeckID: parentDeckID, from: next)
            timeline = merge(current, nextPage)
        } catch { errorMessage = error.localizedDescription }
    }
    private func merge(_ current: StudyTimelineResponse, _ next: StudyTimelineResponse) -> StudyTimelineResponse {
        StudyTimelineResponse(id: next.id, parentDeckID: next.parentDeckID, revision: next.revision,
                              algorithmVersion: next.algorithmVersion, intensity: next.intensity, timezone: next.timezone,
                              startDate: next.startDate, targetDate: next.targetDate, estimatedFinishDate: next.estimatedFinishDate,
                              dateSource: next.dateSource, dailyMinutesBudget: next.dailyMinutesBudget,
                              requiredDailyMinutes: next.requiredDailyMinutes, isOverloaded: next.isOverloaded,
                              reviewsAfterTarget: next.reviewsAfterTarget, readyCards: next.readyCards,
                              studiedCards: next.studiedCards, status: next.status, nextFrom: next.nextFrom,
                              totalDays: next.totalDays, totalCards: next.totalCards,
                              dailyPlan: current.dailyPlan + next.dailyPlan)
    }
    private func createPlan() async {
        isCreatingPlan = true; defer { isCreatingPlan = false }
        do {
            timeline = try await AIService.shared.createStudyPlan(
                parentDeckID: parentDeckID,
                settings: StudyPlanSettingsRequest(intensity: .balanced, timezone: TimeZone.current.identifier, targetDate: nil)
            )
            errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    private func open(_ day: StudyDayResponse) {
        selectedDay = day; dueItems = []; isLoadingDueItems = true
        Task {
            defer { isLoadingDueItems = false }
            do { dueItems = try await AIService.shared.dueStudy(date: day.date).decks.filter { $0.parentDeckID == parentDeckID } }
            catch { errorMessage = error.localizedDescription }
        }
    }
    private static func dateString(_ date: Date, timezone: String) -> String {
        let formatter = DateFormatter(); formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.timeZone = TimeZone(identifier: timezone) ?? .current
        formatter.dateFormat = "yyyy-MM-dd"; return formatter.string(from: date)
    }
}

private struct StudyTimelineDaySheet: View {
    let day: StudyDayResponse
    let decks: [StudyDueDeck]
    let isLoading: Bool
    var body: some View {
        NavigationStack {
            List {
                Section(day.focus) {
                    Text("\(day.date) · \(day.newCards) introductions · \(day.reviewCards ?? 0) reviews")
                }
                if isLoading { ProgressView("Checking what is ready…") }
                ForEach(decks) { deck in
                    Section(deck.chapterTitle) {
                        Text("\(deck.newCards) new · \(deck.reviewCards) reviews · about \(deck.estimatedMinutes) min")
                        ForEach(deck.cards) { card in
                            Label(card.isDueNow ? "Ready to study" : "Scheduled later", systemImage: card.isDueNow ? "checkmark.circle.fill" : "clock")
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(Color.appBackground).foregroundStyle(Color.appTextPrimary)
            .navigationTitle(day.date).navigationBarTitleDisplayMode(.inline)
        }
    }
}
