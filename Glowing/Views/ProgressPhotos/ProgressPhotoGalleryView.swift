import SwiftUI
import SwiftData

struct ProgressPhotoGalleryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressPhoto.capturedAt, order: .reverse) private var allPhotos: [ProgressPhoto]
    @Query(sort: \SkinAnalysis.analyzedAt) private var allAnalyses: [SkinAnalysis]
    @State private var showCapture = false
    @State private var showCompare = false
    @State private var showFaceImport = false
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

    private var analysisBySession: [UUID: SkinAnalysis] {
        Dictionary(uniqueKeysWithValues: allAnalyses.map { ($0.sessionID, $0) })
    }

    /// Group photos by sessionID, sorted by most recent session first
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

    // MARK: - Score Data

    /// Skin scores over time (face sessions only, chronological)
    private var skinScoreData: [ScoreDataPoint] {
        allAnalyses
            .filter { $0.overallScore > 0 }
            .sorted { $0.analyzedAt < $1.analyzedAt }
            .map { ScoreDataPoint(date: $0.analyzedAt, score: $0.overallScore) }
    }

    private var hasAnyScores: Bool {
        !skinScoreData.isEmpty
    }

    // MARK: - Body

    var body: some View {
        Group {
            if sessions.isEmpty {
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

                    Menu {
                        Button {
                            showCapture = true
                        } label: {
                            Label("Take Photos", systemImage: "camera.fill")
                        }

                        Divider()

                        Button {
                            showFaceImport = true
                        } label: {
                            Label("Import Face Photos", systemImage: "face.smiling")
                        }
                    } label: {
                        Image(systemName: "plus")
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
        .sheet(isPresented: $showFaceImport) {
            FacePhotoImportView()
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No Progress Photos", systemImage: "camera")
        } description: {
            Text("Take photos or import from your library to start tracking your progress over time.")
        } actions: {
            Button {
                showCapture = true
            } label: {
                Label("Take Photos", systemImage: "camera.fill")
                    .font(.subheadline)
            }
            .buttonStyle(.borderedProminent)

            Button {
                showFaceImport = true
            } label: {
                Label("Import from Photos", systemImage: "photo.on.rectangle")
                    .font(.subheadline)
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - Dashboard

    private var dashboardContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                // Score trend charts
                if hasAnyScores {
                    trendsSection
                }

                // Session timeline
                timelineSection
            }
            .padding()
        }
    }

    // MARK: - Trends Section

    private var trendsSection: some View {
        VStack(spacing: 12) {
            if !skinScoreData.isEmpty {
                ScoreTrendChartView(
                    title: "Skin Health",
                    icon: "face.smiling",
                    color: .blue,
                    dataPoints: skinScoreData
                )
            }

        }
    }

    // MARK: - Timeline Section

    private static let freeSessionLimit = 2

    private var visibleSessions: [(id: UUID, date: Date, photos: [ProgressPhoto])] {
        if subscriptionManager.isPremium {
            return sessions
        }
        return Array(sessions.prefix(Self.freeSessionLimit))
    }

    private var hasLockedSessions: Bool {
        !subscriptionManager.isPremium && sessions.count > Self.freeSessionLimit
    }

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if hasAnyScores {
                Text("Timeline")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            ForEach(visibleSessions, id: \.id) { session in
                NavigationLink {
                    ProgressPhotoSessionDetailView(
                        sessionID: session.id,
                        date: session.date
                    )
                } label: {
                    sessionCard(
                        date: session.date,
                        photos: session.photos,
                        analysis: analysisBySession[session.id]
                    )
                }
                .buttonStyle(.plain)
            }

            // Locked sessions teaser
            if hasLockedSessions {
                Button {
                    showPaywall = true
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "lock.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        Text("\(sessions.count - Self.freeSessionLimit) more session\(sessions.count - Self.freeSessionLimit == 1 ? "" : "s")")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("Upgrade to Premium to view full history")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color(.systemGray6).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Session Card

    private func sessionCard(date: Date, photos: [ProgressPhoto], analysis: SkinAnalysis?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if let analysis, analysis.overallScore > 0 {
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

            HStack(spacing: 6) {
                ForEach(photos, id: \.persistentModelID) { photo in
                    if let data = photo.imageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 130)
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }
}

#Preview {
    NavigationStack {
        ProgressPhotoGalleryView()
    }
    .modelContainer(for: [ProgressPhoto.self, SkinAnalysis.self], inMemory: true)
}
