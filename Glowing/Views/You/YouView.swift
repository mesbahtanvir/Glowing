import SwiftUI
import SwiftData
import Charts

struct YouView: View {
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

    // MARK: - Data

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
        let diff = latest - previous
        return diff != 0 ? diff : nil
    }

    private var recentScores: [ScoreDataPoint] {
        allAnalyses
            .filter { $0.overallScore > 0 }
            .sorted { $0.analyzedAt < $1.analyzedAt }
            .suffix(5)
            .map { ScoreDataPoint(date: $0.analyzedAt, score: $0.overallScore) }
    }

    private var sessions: [(id: UUID, date: Date, photos: [ProgressPhoto])] {
        let grouped = Dictionary(grouping: allPhotos) { $0.sessionID }
        return grouped.map { (id, photos) in
            let date = photos.map(\.capturedAt).max() ?? Date()
            let sorted = photos.sorted { a, b in
                let order: [PhotoAngle] = [.front, .left, .right, .smile]
                let ai = order.firstIndex(of: a.angle) ?? 0
                let bi = order.firstIndex(of: b.angle) ?? 0
                return ai < bi
            }
            return (id: id, date: date, photos: sorted)
        }
        .sorted { $0.date > $1.date }
    }

    private var dailyStreak: Int {
        StreakCalculator.currentDailyStreak(logs: logs, routines: routines)
    }

    private var totalCompletions: Int {
        logs.filter { $0.isFullyCompleted }.count
    }

    private var checkInHint: String? {
        let days = checkInManager.daysSinceLastCheckIn(photos: allPhotos)
        if days == 0 || allPhotos.isEmpty { return nil }
        if checkInManager.isDueForCheckIn(photos: allPhotos) {
            return "Check-in due"
        }
        let remaining = 7 - days
        return "Next check-in in \(remaining) day\(remaining == 1 ? "" : "s")"
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Score card — center of attention
                    if let latest = latestAnalysis {
                        NavigationLink {
                            ProgressDashboardView()
                        } label: {
                            scoreCard(analysis: latest)
                        }
                        .buttonStyle(.plain)
                    }

                    // Consistency stats
                    if dailyStreak > 0 || totalCompletions > 0 || !sessions.isEmpty {
                        consistencyRow
                    }

                    // Latest session photos
                    if let latest = sessions.first {
                        latestSessionView(latest)
                    }

                    // Check-in action
                    checkInSection
                }
                .padding(.vertical)
            }
            .navigationTitle("You")
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if sessions.count >= 2 {
                        Button {
                            showCompare = true
                        } label: {
                            Image(systemName: "square.split.2x1")
                        }
                    }
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Image(systemName: "gearshape")
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
    }

    // MARK: - Score Animation

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

    // MARK: - Score Card

    private func scoreCard(analysis: SkinAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 14) {
                // Animated score ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5), lineWidth: 5)
                        .frame(width: 52, height: 52)

                    Circle()
                        .trim(from: 0, to: scoreAnimationProgress)
                        .stroke(scoreColor(analysis.overallScore), style: StrokeStyle(lineWidth: 5, lineCap: .round))
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

                        Text(scoreLabel(analysis.overallScore))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        if let delta = scoreDelta {
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

                    Text(analysis.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Mini sparkline
            if recentScores.count >= 2 {
                Chart(recentScores) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(scoreColor(analysis.overallScore).opacity(0.6))
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [scoreColor(analysis.overallScore).opacity(0.15), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartYScale(domain: 0...100)
                .frame(height: 32)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Consistency Row

    private var consistencyRow: some View {
        HStack(spacing: 0) {
            if dailyStreak > 0 {
                statItem(value: "\(dailyStreak)", label: "Day Streak", icon: "flame.fill", color: .orange)
            }
            if !sessions.isEmpty {
                statItem(value: "\(sessions.count)", label: "Check-ins", icon: "camera", color: .blue)
            }
            if totalCompletions > 0 {
                statItem(value: "\(totalCompletions)", label: "Completed", icon: "checkmark", color: .green)
            }
        }
        .padding(.horizontal)
    }

    private func statItem(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .monospacedDigit()
            }
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Latest Session

    private func latestSessionView(_ session: (id: UUID, date: Date, photos: [ProgressPhoto])) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if sessions.count > 1 {
                    NavigationLink {
                        ProgressPhotoGalleryView()
                    } label: {
                        Text("See All")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .padding(.horizontal)

            NavigationLink {
                ProgressPhotoSessionDetailView(
                    sessionID: session.id,
                    date: session.date
                )
            } label: {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(session.photos, id: \.persistentModelID) { photo in
                            if let data = photo.imageData,
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 160)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Check-in Section

    private var checkInSection: some View {
        VStack(spacing: 8) {
            Button {
                showCapture = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "camera")
                        .font(.caption)
                    Text(sessions.isEmpty ? "Take First Photos" : "New Check-in")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .padding(.horizontal)

            if let hint = checkInHint {
                Text(hint)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .teal }
        if score >= 40 { return .teal.opacity(0.6) }
        return .teal.opacity(0.35)
    }

    private func scoreLabel(_ score: Int) -> String {
        if score >= 80 { return "Thriving" }
        if score >= 60 { return "On Track" }
        if score >= 40 { return "Building" }
        return "Starting Out"
    }
}

#Preview {
    YouView()
        .modelContainer(for: [ProgressPhoto.self, SkinAnalysis.self, RoutineLog.self, Routine.self], inMemory: true)
}
