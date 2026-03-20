import SwiftUI
import SwiftData

struct ProgressDashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.capturedAt, order: .reverse) private var allPhotos: [ProgressPhoto]
    @Query(sort: \SkinAnalysis.analyzedAt) private var allAnalyses: [SkinAnalysis]
    @Query private var logs: [RoutineLog]
    @Query(sort: \Routine.createdAt) private var routines: [Routine]

    @State private var showCapture = false
    @State private var showCompare = false
    @State private var scoreAnimationProgress: CGFloat = 0
    @State private var animatedScoreValue: Int = 0

    private var checkInManager = CheckInManager.shared
    private var achievementManager = AchievementManager.shared

    // MARK: - Score Data

    private var skinScoreData: [ScoreDataPoint] {
        allAnalyses
            .filter { $0.overallScore > 0 }
            .sorted { $0.analyzedAt < $1.analyzedAt }
            .map { ScoreDataPoint(date: $0.analyzedAt, score: $0.overallScore) }
    }

    private var latestAnalysis: SkinAnalysis? {
        allAnalyses.filter { $0.overallScore > 0 }.max(by: { $0.analyzedAt < $1.analyzedAt })
    }

    private var previousAnalysis: SkinAnalysis? {
        let sorted = allAnalyses.filter { $0.overallScore > 0 }.sorted { $0.analyzedAt < $1.analyzedAt }
        guard sorted.count >= 2 else { return nil }
        return sorted[sorted.count - 2]
    }

    private var scoreDelta: Int? {
        guard let latest = latestAnalysis?.overallScore, let previous = previousAnalysis?.overallScore else { return nil }
        return latest - previous
    }

    // MARK: - Streaks

    private var dailyStreak: Int {
        StreakCalculator.currentDailyStreak(logs: logs, routines: routines)
    }

    private var checkInStreak: Int {
        checkInManager.weeklyCheckInStreak(photos: allPhotos)
    }

    private var totalCompletions: Int {
        logs.filter { $0.isFullyCompleted }.count
    }

    private var allCompletionDates: Set<DateComponents> {
        var dates = Set<DateComponents>()
        let calendar = Calendar.current
        for log in logs where log.isFullyCompleted {
            let comps = calendar.dateComponents([.year, .month, .day], from: log.completedAt)
            dates.insert(comps)
        }
        return dates
    }

    // MARK: - Journey summary

    private var journeySummary: String {
        let analysisCount = allAnalyses.filter { $0.overallScore > 0 }.count
        if analysisCount == 0 && totalCompletions == 0 {
            return "Your journey starts with one routine."
        }
        if let delta = scoreDelta, delta > 0 {
            return "Your score moved up \(delta) points. Your routine is making a difference."
        }
        if let delta = scoreDelta, delta < 0 {
            return "Skin fluctuates naturally. What matters is the trend over time."
        }
        if dailyStreak >= 7 {
            return "A full week of consistency. That builds real results."
        }
        if totalCompletions >= 10 {
            return "\(totalCompletions) routines completed. Consistency is the foundation."
        }
        if analysisCount >= 2 {
            return "\(analysisCount) check-ins tracked. Every data point helps you understand your skin."
        }
        return "Every routine you complete is an investment in your skin."
    }

    // MARK: - Body

    var body: some View {
        Group {
            if allPhotos.isEmpty && logs.isEmpty {
                emptyState
            } else {
                dashboardContent
            }
        }
        .navigationTitle("Your Journey")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if allAnalyses.count >= 2 {
                        Button {
                            showCompare = true
                        } label: {
                            Image(systemName: "square.split.2x1")
                        }
                    }

                    Button {
                        showCapture = true
                    } label: {
                        Image(systemName: "camera.fill")
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCapture) {
            ProgressPhotoCaptureView()
        }
        .sheet(isPresented: $showCompare) {
            NavigationStack {
                ProgressPhotoCompareView()
            }
        }
        .onAppear {
            animateScore()
        }
    }

    private func animateScore() {
        guard let score = latestAnalysis?.overallScore, score > 0 else { return }
        scoreAnimationProgress = 0
        animatedScoreValue = 0
        withAnimation(.easeOut(duration: 0.8)) {
            scoreAnimationProgress = Double(score) / 100.0
        }
        let steps = min(score, 40)
        let interval = 0.8 / Double(steps)
        for i in 1...steps {
            DispatchQueue.main.asyncAfter(deadline: .now() + interval * Double(i)) {
                animatedScoreValue = Int(Double(score) * Double(i) / Double(steps))
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Progress Yet", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Complete routines and take progress photos to start seeing your journey here.")
        } actions: {
            Button {
                showCapture = true
            } label: {
                Label("Take Photos", systemImage: "camera.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 20) {
                // Journey headline
                journeyCard

                // Skin score trend
                if skinScoreData.count >= 2 {
                    ScoreTrendChartView(
                        title: "Skin Health",
                        icon: "face.smiling",
                        color: .blue,
                        dataPoints: skinScoreData
                    )
                }

                // Consistency stats
                consistencySection

                // Calendar
                if !logs.isEmpty {
                    calendarSection
                }

                // Achievements
                achievementsSection
            }
            .padding()
        }
    }

    // MARK: - Journey Card

    private var journeyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let latest = latestAnalysis {
                HStack(spacing: 14) {
                    // Animated score ring
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5), lineWidth: 5)
                            .frame(width: 52, height: 52)

                        Circle()
                            .trim(from: 0, to: scoreAnimationProgress)
                            .stroke(scoreColor(latest.overallScore), style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .frame(width: 52, height: 52)
                            .rotationEffect(.degrees(-90))

                        Text("\(animatedScoreValue)")
                            .font(.headline)
                            .fontWeight(.bold)
                            .monospacedDigit()
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Skin Score")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if let delta = scoreDelta, delta != 0 {
                                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(delta > 0 ? .teal : .secondary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background((delta > 0 ? Color.teal : Color.secondary).opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }

                        Text(journeySummary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }

                    Spacer(minLength: 0)
                }
            } else {
                Text(journeySummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Consistency Section

    private var consistencySection: some View {
        HStack(spacing: 12) {
            consistencyStat(
                value: "\(dailyStreak)",
                label: "Day Streak",
                icon: "flame.fill",
                iconColor: .orange,
                bgColor: .orange
            )

            consistencyStat(
                value: "\(checkInStreak)",
                label: "Week Streak",
                icon: "camera.fill",
                iconColor: .blue,
                bgColor: .blue
            )

            consistencyStat(
                value: "\(totalCompletions)",
                label: "Completed",
                icon: "checkmark.circle.fill",
                iconColor: .green,
                bgColor: .green
            )
        }
    }

    private func consistencyStat(value: String, label: String, icon: String, iconColor: Color, bgColor: Color) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundStyle(iconColor)
                    .font(.caption)
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(bgColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        let sorted = AchievementType.allCases.sorted { $0.sortOrder < $1.sortOrder }
        let unlocked = sorted.filter { achievementManager.isUnlocked($0) }
        let locked = sorted.filter { !achievementManager.isUnlocked($0) }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Achievements")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(unlocked.count)/\(sorted.count)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Show unlocked first, locked after (dimmed)
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(unlocked) { achievement in
                    AchievementBadgeView(
                        achievement: achievement,
                        isUnlocked: true
                    )
                }
                ForEach(locked) { achievement in
                    AchievementBadgeView(
                        achievement: achievement,
                        isUnlocked: false
                    )
                }
            }
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Consistency Calendar")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            CalendarGridView(
                completionDates: allCompletionDates,
                accentColor: .teal
            )
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .teal }
        if score >= 40 { return .teal.opacity(0.6) }
        return .teal.opacity(0.35)
    }
}

#Preview {
    NavigationStack {
        ProgressDashboardView()
    }
    .modelContainer(for: [ProgressPhoto.self, SkinAnalysis.self, RoutineLog.self, Routine.self], inMemory: true)
}
