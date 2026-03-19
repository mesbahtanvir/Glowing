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

    // Category sparkline data
    private func categoryData(keyPath: KeyPath<SkinAnalysis, Int>) -> [ScoreDataPoint] {
        allAnalyses
            .filter { $0.overallScore > 0 }
            .sorted { $0.analyzedAt < $1.analyzedAt }
            .map { ScoreDataPoint(date: $0.analyzedAt, score: $0[keyPath: keyPath]) }
    }

    // MARK: - Session Data

    private var sessions: [(id: UUID, date: Date, photos: [ProgressPhoto])] {
        let grouped = Dictionary(grouping: allPhotos) { $0.sessionID }
        return grouped.map { (id, photos) in
            let date = photos.map(\.capturedAt).max() ?? Date()
            let sorted = photos.sorted { a, b in
                let order: [PhotoAngle] = [.front, .left, .right]
                let ai = order.firstIndex(of: a.angle) ?? 0
                let bi = order.firstIndex(of: b.angle) ?? 0
                return ai < bi
            }
            return (id: id, date: date, photos: sorted)
        }
        .sorted { $0.date > $1.date }
    }

    private var analysisBySession: [UUID: SkinAnalysis] {
        Dictionary(uniqueKeysWithValues: allAnalyses.map { ($0.sessionID, $0) })
    }

    // MARK: - Streaks

    private var dailyStreak: Int {
        StreakCalculator.currentDailyStreak(logs: logs, routines: routines)
    }

    private var checkInStreak: Int {
        checkInManager.weeklyCheckInStreak(photos: allPhotos)
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

    // MARK: - Body

    var body: some View {
        Group {
            if allPhotos.isEmpty && logs.isEmpty {
                emptyState
            } else {
                dashboardContent
            }
        }
        .navigationTitle("Progress")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 16) {
                    if sessions.count >= 2 {
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
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Progress Data", systemImage: "chart.line.uptrend.xyaxis")
        } description: {
            Text("Complete routines and take progress photos to see your dashboard.")
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
            LazyVStack(spacing: 16) {
                // Score overview card
                if let latest = latestAnalysis {
                    scoreOverviewCard(analysis: latest)
                }

                // Category mini-trends
                if !allAnalyses.isEmpty {
                    categoryTrendsSection
                }

                // Skin score trend chart
                if skinScoreData.count >= 2 {
                    ScoreTrendChartView(
                        title: "Skin Health",
                        icon: "face.smiling",
                        color: .blue,
                        dataPoints: skinScoreData
                    )
                }

                // Streaks section
                streaksSection

                // Achievements
                achievementsSection

                // Photo timeline
                if !sessions.isEmpty {
                    photoTimelineSection
                }

                // Calendar
                if !logs.isEmpty {
                    calendarSection
                }
            }
            .padding()
        }
    }

    // MARK: - Score Overview Card

    private func scoreOverviewCard(analysis: SkinAnalysis) -> some View {
        HStack(spacing: 16) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: Double(analysis.overallScore) / 100.0)
                    .stroke(scoreColor(analysis.overallScore), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(analysis.overallScore)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text("Skin Score")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    if let delta = scoreDelta, delta != 0 {
                        Text(delta > 0 ? "+\(delta)" : "\(delta)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(delta > 0 ? .green : .red)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background((delta > 0 ? Color.green : Color.red).opacity(0.12))
                            .clipShape(Capsule())
                    }
                }

                Text(analysis.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Category Trends

    private var categoryTrendsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Key Metrics")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                CategoryTrendView(name: "Acne", icon: "circle.dotted", dataPoints: categoryData(keyPath: \.acneScore))
                CategoryTrendView(name: "Texture", icon: "square.grid.3x3.fill", dataPoints: categoryData(keyPath: \.textureScore))
                CategoryTrendView(name: "Hydration", icon: "humidity.fill", dataPoints: categoryData(keyPath: \.hydrationScore))
                CategoryTrendView(name: "Dark Circles", icon: "eye.fill", dataPoints: categoryData(keyPath: \.darkCirclesScore))
                CategoryTrendView(name: "Redness", icon: "drop.fill", dataPoints: categoryData(keyPath: \.rednessScore))
                CategoryTrendView(name: "Skin Tone", icon: "sun.max.fill", dataPoints: categoryData(keyPath: \.skinToneScore))
            }
        }
    }

    // MARK: - Streaks Section

    private var streaksSection: some View {
        HStack(spacing: 12) {
            // Daily streak
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.title3)
                    Text("\(dailyStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Text("Day Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Check-in streak
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "camera.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                    Text("\(checkInStreak)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Text("Week Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            // Total completions
            let totalCompletions = logs.filter { $0.isFullyCompleted }.count
            VStack(spacing: 6) {
                Text("\(totalCompletions)")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Total Done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    // MARK: - Photo Timeline

    private var photoTimelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Photo Timeline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                NavigationLink {
                    ProgressPhotoGalleryView()
                } label: {
                    Text("See All")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            ForEach(Array(sessions.prefix(3)), id: \.id) { session in
                NavigationLink {
                    ProgressPhotoSessionDetailView(
                        sessionID: session.id,
                        date: session.date
                    )
                } label: {
                    photoTimelineRow(session: session)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func photoTimelineRow(session: (id: UUID, date: Date, photos: [ProgressPhoto])) -> some View {
        HStack(spacing: 10) {
            // Thumbnail
            if let firstPhoto = session.photos.first,
               let data = firstPhoto.imageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("\(session.photos.count) photos")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let analysis = analysisBySession[session.id], analysis.overallScore > 0 {
                Text("\(analysis.overallScore)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(scoreColor(analysis.overallScore).opacity(0.15))
                    .foregroundStyle(scoreColor(analysis.overallScore))
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Achievements

    private var achievementsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Achievements")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            let sorted = AchievementType.allCases.sorted { $0.sortOrder < $1.sortOrder }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(sorted) { achievement in
                    AchievementBadgeView(
                        achievement: achievement,
                        isUnlocked: achievementManager.isUnlocked(achievement)
                    )
                }
            }
        }
    }

    // MARK: - Calendar

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Completion Calendar")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            CalendarGridView(
                completionDates: allCompletionDates,
                accentColor: .green
            )
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }
}

#Preview {
    NavigationStack {
        ProgressDashboardView()
    }
    .modelContainer(for: [ProgressPhoto.self, SkinAnalysis.self, RoutineLog.self, Routine.self], inMemory: true)
}
