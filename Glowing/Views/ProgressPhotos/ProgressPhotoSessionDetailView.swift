import SwiftUI
import SwiftData

struct ProgressPhotoSessionDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var photos: [ProgressPhoto]
    @State private var showDeleteConfirmation = false
    @State private var analysis: SkinAnalysis?
    @State private var manager = SkinAnalysisManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false

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
        let order: [PhotoAngle] = [.front, .left, .right]
        return photos.sorted { a, b in
            let ai = order.firstIndex(of: a.angle) ?? 0
            let bi = order.firstIndex(of: b.angle) ?? 0
            return ai < bi
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Date header
                Text(date.formatted(.dateTime.weekday(.wide).month(.wide).day().year()))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)

                // Full-size photos
                ForEach(sortedPhotos, id: \.persistentModelID) { photo in
                    VStack(alignment: .leading, spacing: 8) {
                        // Angle label
                        HStack(spacing: 6) {
                            Image(systemName: photo.angle.icon)
                                .font(.caption)
                                .foregroundStyle(.blue)
                            Text(photo.angle.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                        }

                        // Photo
                        if let data = photo.imageData,
                           let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .padding(.horizontal)
                }

                // Skin analysis section
                skinAnalysisSection
                    .padding(.horizontal)
            }
            .padding(.bottom, 32)
        }
        .navigationTitle("Session Detail")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .task {
            fetchAnalysis()
        }
    }

    // MARK: - Analysis Section

    @ViewBuilder
    private var skinAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Skin Analysis")
                    .font(.headline)
                Spacer()
                if analysis != nil {
                    Button("Re-analyze") {
                        runAnalysis()
                    }
                    .font(.caption)
                }
            }

            if manager.isAnalyzing {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Analyzing your skin...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else if let analysis {
                SkinAnalysisResultView(analysis: analysis)
            } else if subscriptionManager.isPremium {
                Button {
                    runAnalysis()
                } label: {
                    Label("Analyze Skin", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    Label("Unlock AI Analysis", systemImage: "lock.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(.orange)
            }

            if let error = manager.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    // MARK: - Analysis Helpers

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

    // MARK: - Delete

    private func deleteSession() {
        // Delete analysis too
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
