import SwiftUI
import SwiftData

struct YouView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query private var logs: [RoutineLog]
    @Query(sort: \ProgressPhoto.capturedAt, order: .reverse) private var allPhotos: [ProgressPhoto]
    @Query(sort: \SkinAnalysis.analyzedAt) private var allAnalyses: [SkinAnalysis]

    @State private var showCapture = false
    @State private var showCompare = false
    @State private var showCreateRoutine = false
    @State private var isRegenerating = false
    @State private var regenerateError: String?

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
        return latest - previous
    }

    private var routinesByCategory: [(Category, [Routine])] {
        let grouped = Dictionary(grouping: routines) { $0.category }
        return Category.allCases
            .compactMap { cat in
                guard let items = grouped[cat], !items.isEmpty else { return nil }
                return (cat, items.sorted {
                    if $0.timeOfDay.sortOrder != $1.timeOfDay.sortOrder {
                        return $0.timeOfDay.sortOrder < $1.timeOfDay.sortOrder
                    }
                    return $0.displayOrder < $1.displayOrder
                })
            }
    }

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

    private var dailyStreak: Int {
        StreakCalculator.currentDailyStreak(logs: logs, routines: routines)
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 20) {
                    // Score card
                    if let latest = latestAnalysis {
                        scoreCard(analysis: latest)
                    }

                    // Weekly check-in
                    WeeklyCheckInBannerView {
                        showCapture = true
                    }
                    .padding(.horizontal)

                    // My Routines
                    routinesSection

                    // Photo timeline
                    if !sessions.isEmpty {
                        photoTimelineSection
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("You")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
            .sheet(isPresented: $showCreateRoutine) {
                EditRoutineView()
            }
        }
    }

    // MARK: - Score Card

    private func scoreCard(analysis: SkinAnalysis) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 6)
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: Double(analysis.overallScore) / 100.0)
                    .stroke(scoreColor(analysis.overallScore), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 64, height: 64)
                    .rotationEffect(.degrees(-90))

                Text("\(analysis.overallScore)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
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
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
    }

    // MARK: - Routines

    private var routinesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("My Routines")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                Spacer()

                Button {
                    showCreateRoutine = true
                } label: {
                    Image(systemName: "plus")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal)

            if routines.isEmpty {
                Text("No routines yet")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(routinesByCategory, id: \.0) { category, items in
                        ForEach(items) { routine in
                            NavigationLink {
                                RoutineDetailView(routine: routine)
                            } label: {
                                routineRow(routine)
                            }
                            .buttonStyle(.plain)

                            if !(category == routinesByCategory.last?.0 && routine.id == items.last?.id) {
                                Divider()
                                    .padding(.leading, 56)
                            }
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
            }

            // Regenerate with AI
            if !allPhotos.isEmpty {
                regenerateButton
                    .padding(.horizontal)
            }
        }
    }

    // MARK: - Regenerate

    private var regenerateButton: some View {
        Button {
            Task { await regenerateRoutines() }
        } label: {
            HStack(spacing: 6) {
                if isRegenerating {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "wand.and.stars")
                }
                Text(isRegenerating ? "Regenerating..." : "Regenerate with AI")
                    .fontWeight(.medium)
            }
            .font(.caption)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.bordered)
        .disabled(isRegenerating)
    }

    private func regenerateRoutines() async {
        guard let latestSession = sessions.first else { return }

        isRegenerating = true
        regenerateError = nil

        // Build images from latest photo session
        let images = latestSession.photos.compactMap { photo -> AnalysisImage? in
            guard let data = photo.imageData,
                  let uiImage = UIImage(data: data),
                  let base64 = uiImage.jpegData(compressionQuality: 0.7)?.base64EncodedString()
            else { return nil }
            return AnalysisImage(angle: photo.angle.rawValue, base64Data: base64)
        }

        guard !images.isEmpty else {
            isRegenerating = false
            return
        }

        do {
            let result = try await BackendAPIClient.shared.analyzeOnboarding(images: images)

            // Delete existing routines
            for routine in routines {
                modelContext.delete(routine)
            }

            // Create new routines from AI response
            if let json = result.suggestedRoutineJSON {
                let routineArray = json["routines"] as? [[String: Any]] ?? []
                for routineJSON in routineArray {
                    let name = routineJSON["name"] as? String ?? "Routine"
                    let categoryRaw = routineJSON["category"] as? String ?? "face"
                    let category = Category(rawValue: categoryRaw) ?? .face
                    let timeOfDayRaw = routineJSON["timeOfDay"] as? String ?? "morning"
                    let timeOfDay = TimeOfDay(rawValue: timeOfDayRaw) ?? .morning
                    let weekdays = routineJSON["scheduledWeekdays"] as? [Int] ?? []
                    let icon = routineJSON["icon"] as? String ?? category.defaultIcon
                    let displayOrder = routineJSON["displayOrder"] as? Int ?? 0

                    let routine = Routine(
                        name: name,
                        category: category,
                        timeOfDay: timeOfDay,
                        scheduledWeekdays: Set(weekdays),
                        displayOrder: displayOrder,
                        icon: icon
                    )
                    modelContext.insert(routine)

                    let steps = routineJSON["steps"] as? [[String: Any]] ?? []
                    for (index, stepJSON) in steps.enumerated() {
                        let step = RoutineStep(
                            order: index,
                            title: stepJSON["title"] as? String ?? "Step \(index + 1)",
                            productName: stepJSON["productName"] as? String,
                            notes: stepJSON["notes"] as? String,
                            timerDuration: stepJSON["timerDuration"] as? Int
                        )
                        routine.steps.append(step)
                    }
                }
            }

            isRegenerating = false
        } catch {
            regenerateError = error.localizedDescription
            isRegenerating = false
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(spacing: 12) {
            Image(systemName: routine.icon)
                .font(.callout)
                .foregroundStyle(routine.category.accentColor)
                .frame(width: 32, height: 32)
                .background(routine.category.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text("\(routine.sortedSteps.count) steps · \(routine.timeOfDay.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let streak = StreakCalculator.currentStreak(for: routine, logs: logs)
            if streak > 0 {
                StreakBadgeView(streak: streak)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
            .padding(.horizontal)

            VStack(spacing: 0) {
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

                    if session.id != sessions.prefix(3).last?.id {
                        Divider()
                            .padding(.leading, 68)
                    }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal)

            if sessions.count >= 2 {
                Button {
                    showCompare = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.split.2x1")
                        Text("Compare Photos")
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                }
                .padding(.horizontal)
            }
        }
    }

    private func photoTimelineRow(session: (id: UUID, date: Date, photos: [ProgressPhoto])) -> some View {
        HStack(spacing: 10) {
            if let firstPhoto = session.photos.first,
               let data = firstPhoto.imageData,
               let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(session.date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

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
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Helpers

    private func scoreColor(_ score: Int) -> Color {
        if score >= 70 { return .green }
        if score >= 40 { return .orange }
        return .red
    }
}

#Preview {
    YouView()
        .modelContainer(for: [Routine.self, RoutineStep.self, RoutineLog.self, StepDayVariant.self, ProgressPhoto.self, SkinAnalysis.self], inMemory: true)
}
