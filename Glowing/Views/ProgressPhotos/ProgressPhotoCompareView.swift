import SwiftUI
import SwiftData

struct ProgressPhotoCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProgressPhoto.capturedAt, order: .reverse) private var allPhotos: [ProgressPhoto]
    @Query private var allAnalyses: [SkinAnalysis]

    @State private var selectedBefore: UUID?
    @State private var selectedAfter: UUID?

    private var analysisBySession: [UUID: SkinAnalysis] {
        Dictionary(uniqueKeysWithValues: allAnalyses.map { ($0.sessionID, $0) })
    }

    private var sessions: [(id: UUID, date: Date, photos: [ProgressPhoto])] {
        let grouped = Dictionary(grouping: allPhotos) { $0.sessionID }
        return grouped.map { (id, photos) in
            let date = photos.map(\.capturedAt).max() ?? Date()
            return (id: id, date: date, photos: photos)
        }
        .sorted { $0.date > $1.date }
    }

    /// Whether both sessions are selected
    private var isComparing: Bool {
        selectedBefore != nil && selectedAfter != nil
    }

    private func photos(for sessionID: UUID, angle: PhotoAngle) -> ProgressPhoto? {
        allPhotos.first { $0.sessionID == sessionID && $0.angle == angle }
    }

    var body: some View {
        Group {
            if isComparing {
                comparisonView
            } else {
                selectionView
            }
        }
        .navigationTitle("Compare")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") { dismiss() }
            }

            if isComparing {
                ToolbarItem(placement: .primaryAction) {
                    Button("Change") {
                        selectedBefore = nil
                        selectedAfter = nil
                    }
                }
            }
        }
    }

    // MARK: - Selection

    private var selectionView: some View {
        List {
            Section {
                sessionPicker(title: "Before", selection: $selectedBefore, excluding: selectedAfter)
            } header: {
                Text("Select \"Before\" Session")
            }

            if selectedBefore != nil {
                Section {
                    sessionPicker(title: "After", selection: $selectedAfter, excluding: selectedBefore)
                } header: {
                    Text("Select \"After\" Session")
                }
            }
        }
    }

    private func sessionPicker(title: String, selection: Binding<UUID?>, excluding: UUID?) -> some View {
        ForEach(sessions.filter { $0.id != excluding }, id: \.id) { session in
            Button {
                withAnimation { selection.wrappedValue = session.id }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text("\(session.photos.count) photos")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    if selection.wrappedValue == session.id {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .tint(.primary)
        }
    }

    // MARK: - Comparison

    private var comparisonView: some View {
        ScrollView {
            VStack(spacing: 24) {
                let angles = PhotoAngle.allCases
                ForEach(angles, id: \.self) { angle in
                    VStack(spacing: 8) {
                        Text(angle.displayName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            // Before
                            photoCell(sessionID: selectedBefore, angle: angle, label: "Before")

                            // After
                            photoCell(sessionID: selectedAfter, angle: angle, label: "After")
                        }
                    }
                }

                // Score comparison
                if let beforeID = selectedBefore,
                   let afterID = selectedAfter,
                   let beforeAnalysis = analysisBySession[beforeID],
                   let afterAnalysis = analysisBySession[afterID] {
                    scoreComparisonSection(before: beforeAnalysis, after: afterAnalysis)
                }
            }
            .padding()
        }
    }

    // MARK: - Score Comparison

    private func scoreComparisonSection(before: SkinAnalysis, after: SkinAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Score Comparison")
                .font(.headline)

            // Overall
            HStack {
                Text("Overall")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                scoreDelta(before: before.overallScore, after: after.overallScore)
            }

            Divider()

            // Per-category
            let beforeCats = before.userFacingCategories
            let afterCats = after.userFacingCategories
            ForEach(Array(zip(beforeCats, afterCats)), id: \.0.id) { bCat, aCat in
                HStack {
                    Image(systemName: bCat.icon)
                        .font(.caption)
                        .frame(width: 18)
                    Text(bCat.name)
                        .font(.caption)
                    Spacer()
                    scoreDelta(before: bCat.score, after: aCat.score)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func scoreDelta(before: Int, after: Int) -> some View {
        HStack(spacing: 6) {
            Text("\(before)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Image(systemName: "arrow.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Text("\(after)")
                .font(.caption)
                .fontWeight(.bold)

            let delta = after - before
            if delta != 0 {
                Text(delta > 0 ? "+\(delta)" : "\(delta)")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(delta > 0 ? .green : .red)
            }
        }
    }

    private func photoCell(sessionID: UUID?, angle: PhotoAngle, label: String) -> some View {
        VStack(spacing: 4) {
            if let sessionID,
               let photo = photos(for: sessionID, angle: angle),
               let data = photo.imageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray5))
                    .frame(maxWidth: .infinity)
                    .frame(height: 200)
                    .overlay {
                        Text("No photo")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
            }

            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
