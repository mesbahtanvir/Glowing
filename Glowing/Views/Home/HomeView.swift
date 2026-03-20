import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query private var logs: [RoutineLog]
    @Query private var photos: [ProgressPhoto]
    @Query private var analyses: [SkinAnalysis]
    @State private var showingGuidedFlow = false
    @State private var singleRoutineToStart: Routine?
    @State private var achievementManager = AchievementManager.shared
    @State private var showAchievementToast = false
    @State private var unlockedAchievement: AchievementType?
    @State private var showRoutineList = false
    @State private var showOnboarding = false
    @State private var showPendingReview = false
    @State private var pendingManager = PendingAnalysisManager.shared

    private var currentTimeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        return hour < 15 ? .morning : .evening
    }

    private var todayRoutines: [Routine] {
        let now = Date()
        return routines
            .filter { routine in
                guard routine.timeOfDay == currentTimeOfDay || routine.timeOfDay == .weekly else {
                    return false
                }
                return routine.isScheduledToday(on: now)
            }
            .sorted {
                if $0.category.sortOrder != $1.category.sortOrder {
                    return $0.category.sortOrder < $1.category.sortOrder
                }
                return $0.displayOrder < $1.displayOrder
            }
    }

    private func isCompletedToday(_ routine: Routine) -> Bool {
        let calendar = Calendar.current
        return logs.contains { log in
            log.routine?.persistentModelID == routine.persistentModelID
            && calendar.isDateInToday(log.completedAt)
        }
    }

    private var completedCount: Int {
        todayRoutines.filter { isCompletedToday($0) }.count
    }

    private var pendingRoutines: [Routine] {
        todayRoutines.filter { !isCompletedToday($0) }
    }

    private var dailyStreak: Int {
        StreakCalculator.currentDailyStreak(logs: logs, routines: routines)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good Morning"
        } else if hour < 17 {
            return "Good Afternoon"
        } else {
            return "Good Evening"
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty && pendingManager.state == .idle {
                    noRoutinesView
                } else if todayRoutines.isEmpty && pendingManager.state == .idle {
                    emptyStateView
                } else {
                    VStack(spacing: 0) {
                        if pendingManager.state == .analyzing || pendingManager.state == .readyForReview {
                            pendingAnalysisCard
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                        if todayRoutines.isEmpty {
                            emptyStateView
                        } else {
                            todayContent
                        }
                    }
                }
            }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if pendingRoutines.count >= 2 {
                        Button {
                            showingGuidedFlow = true
                        } label: {
                            Text("Start All")
                                .font(.subheadline)
                        }
                    }
                }
                ToolbarItemGroup(placement: .primaryAction) {
                    if dailyStreak > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "flame.fill")
                                .foregroundStyle(.orange)
                            Text("\(dailyStreak)")
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }
                        .font(.subheadline)
                    }
                    Button {
                        showRoutineList = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                }
            }
            .sheet(isPresented: $showRoutineList) {
                RoutineListView()
            }
            .fullScreenCover(isPresented: $showingGuidedFlow) {
                checkForAchievements()
            } content: {
                GuidedFlowView(routines: pendingRoutines)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingFlowView()
            }
            .fullScreenCover(isPresented: $showPendingReview) {
                if let vm = pendingManager.imageAnalysisVM {
                    PendingReviewFlowView(
                        imageAnalysisVM: vm,
                        capturedPhotos: pendingManager.capturedPhotos
                    )
                }
            }
            .fullScreenCover(item: $singleRoutineToStart, onDismiss: {
                checkForAchievements()
            }) { routine in
                GuidedFlowView(routine: routine)
            }
            .overlay(alignment: .top) {
                if showAchievementToast, let achievement = unlockedAchievement {
                    achievementToast(achievement)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
        }
    }

    // MARK: - Achievement

    private func checkForAchievements() {
        let newlyUnlocked = achievementManager.checkForNewAchievements(
            logs: logs,
            routines: routines,
            photos: photos,
            analyses: analyses
        )

        if let first = newlyUnlocked.first {
            unlockedAchievement = first
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                showAchievementToast = true
            }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                withAnimation { showAchievementToast = false }
            }
        }
    }

    private func achievementToast(_ achievement: AchievementType) -> some View {
        HStack(spacing: 10) {
            Image(systemName: achievement.icon)
                .font(.title3)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 2) {
                Text(achievement.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(achievement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal)
        .sensoryFeedback(.success, trigger: showAchievementToast)
        .onTapGesture {
            withAnimation { showAchievementToast = false }
        }
    }

    // MARK: - Pending Analysis Card

    private var pendingAnalysisCard: some View {
        Button {
            if pendingManager.state == .readyForReview {
                showPendingReview = true
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(pendingManager.state == .analyzing ? Color.teal.opacity(0.12) : Color.green.opacity(0.12))
                        .frame(width: 40, height: 40)

                    if pendingManager.state == .analyzing {
                        Image(systemName: "sparkle")
                            .font(.body)
                            .foregroundStyle(.teal)
                            .symbolEffect(.pulse.wholeSymbol, options: .repeating)
                    } else {
                        Image(systemName: "checkmark")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.green)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(pendingManager.state == .analyzing ? "Reading your features..." : "Your results are ready")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(pendingManager.state == .analyzing ? "This won't take long" : "Tap to review and get your routines")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if pendingManager.state == .readyForReview {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(pendingManager.state == .analyzing)
    }

    // MARK: - No Routines (Onboarding Prompt)

    private var noRoutinesView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "sparkles")
                .font(.system(size: 40))
                .foregroundStyle(.teal)

            Text("Get Your Personalized Routine")
                .font(.title3)
                .fontWeight(.bold)

            Text("Take a quick photo scan and we'll build routines tailored to your skin, hair, and features.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button {
                showOnboarding = true
            } label: {
                Label("Start Scan", systemImage: "camera.fill")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .padding(.horizontal, 40)

            Spacer()
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 8) {
            Spacer()

            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)

            Text("Nothing scheduled \(currentTimeOfDay == .morning ? "this morning" : "tonight")")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }

    // MARK: - Today Content

    private var todayContent: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Routine cards — the sole center of attention
                VStack(spacing: 0) {
                    ForEach(todayRoutines) { routine in
                        todayRoutineRow(routine)
                        if routine.id != todayRoutines.last?.id {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Quiet completion message
                if completedCount > 0 {
                    Text(completionMessage)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 8)
        }
    }

    private var completionMessage: String {
        if pendingRoutines.isEmpty {
            return "All done for \(currentTimeOfDay == .morning ? "this morning" : "tonight")"
        }
        return "\(completedCount) of \(todayRoutines.count) complete"
    }

    // MARK: - Routine Row

    private func todayRoutineRow(_ routine: Routine) -> some View {
        let completed = isCompletedToday(routine)

        return Button {
            if !completed {
                singleRoutineToStart = routine
            }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(routine.category.color.opacity(completed ? 0.4 : 1))
                        .frame(width: 40, height: 40)

                    Image(systemName: routine.icon)
                        .font(.title3)
                        .foregroundStyle(routine.category.accentColor.opacity(completed ? 0.4 : 1))
                }

                Text(routine.name)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(completed ? .secondary : .primary)

                Spacer()

                if completed {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(completed)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Routine.self, RoutineStep.self, RoutineLog.self, StepDayVariant.self], inMemory: true)
}
