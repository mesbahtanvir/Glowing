import SwiftUI
import SwiftData

struct ProgressPhotoSessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var photos: [ProgressPhoto]
    @State private var showDeleteConfirmation = false
    @State private var analysis: SkinAnalysis?
    @State private var manager = SkinAnalysisManager.shared

    @Query(sort: \SkinAnalysis.analyzedAt) private var allAnalyses: [SkinAnalysis]

    let sessionID: UUID
    let date: Date

    init(sessionID: UUID, date: Date) {
        self.sessionID = sessionID
        self.date = date
        let id = sessionID
        _photos = Query(
            filter: #Predicate<ProgressPhoto> { $0.sessionID == id },
            sort: \ProgressPhoto.angleRaw
        )
    }

    private var sortedPhotos: [ProgressPhoto] {
        let order: [PhotoAngle] = [.front, .left, .right, .smile]
        return photos.sorted { a, b in
            let ai = order.firstIndex(of: a.angle) ?? 0
            let bi = order.firstIndex(of: b.angle) ?? 0
            return ai < bi
        }
    }

    // MARK: - Before/After

    private var previousSessionAnalysis: SkinAnalysis? {
        let scored = allAnalyses
            .filter { $0.overallScore > 0 && $0.sessionID != sessionID }
            .sorted { $0.analyzedAt < $1.analyzedAt }
        return scored.last { $0.analyzedAt < date }
    }

    private var deltaFromPrevious: Int? {
        guard let current = analysis, current.overallScore > 0,
              let previous = previousSessionAnalysis, previous.overallScore > 0 else { return nil }
        let diff = current.overallScore - previous.overallScore
        return diff != 0 ? diff : nil
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Date
                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // Photo strip
                photoStrip

                // Analysis
                skinAnalysisSection
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                if analysis != nil {
                    Button {
                        runAnalysis()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete Session", isPresented: $showDeleteConfirmation) {
            Button("Delete All Photos", role: .destructive) {
                deleteSession()
            }
        } message: {
            Text("This will permanently delete all photos and analysis from this session.")
        }
        .task {
            fetchAnalysis()
        }
    }

    // MARK: - Photo Strip

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(sortedPhotos, id: \.persistentModelID) { photo in
                    if let data = photo.imageData,
                       let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 250, height: 340)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(alignment: .bottomLeading) {
                                Text(photo.angle.displayName)
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .padding(8)
                            }
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Analysis Section

    @ViewBuilder
    private var skinAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if manager.isAnalyzing {
                GlowingBubbleView(
                    message: "Analyzing your skin...",
                    accentColor: .blue
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let analysis {
                // Delta from previous
                if let delta = deltaFromPrevious {
                    HStack(spacing: 6) {
                        Image(systemName: delta > 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .foregroundStyle(delta > 0 ? .green : .orange)

                        Text(delta > 0 ? "+\(delta) from last check-in" : "\(delta) from last check-in")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                SkinAnalysisResultView(analysis: analysis)
            } else {
                Button {
                    runAnalysis()
                } label: {
                    Label("Analyze Skin", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
            }

            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Helpers

    private func fetchAnalysis() {
        let sid = sessionID
        let descriptor = FetchDescriptor<SkinAnalysis>(
            predicate: #Predicate { $0.sessionID == sid }
        )
        analysis = try? modelContext.fetch(descriptor).first
    }

    private func runAnalysis() {
        Task {
            await manager.analyzeSession(
                sessionID: sessionID,
                photos: Array(photos),
                modelContext: modelContext
            )
            fetchAnalysis()
        }
    }

    private func deleteSession() {
        let sid = sessionID
        if let existingAnalysis = try? modelContext.fetch(
            FetchDescriptor<SkinAnalysis>(
                predicate: #Predicate { $0.sessionID == sid }
            )
        ) {
            for a in existingAnalysis {
                modelContext.delete(a)
            }
        }
        for photo in photos {
            modelContext.delete(photo)
        }
        dismiss()
    }
}
