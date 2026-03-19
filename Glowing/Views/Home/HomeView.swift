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
    @State private var showAchievementUnlock = false
    @State private var unlockedAchievement: AchievementType?

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
                if todayRoutines.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing Scheduled", systemImage: "moon.zzz.fill")
                    } description: {
                        Text("No \(currentTimeOfDay.displayName.lowercased()) routines scheduled for today. Your \(currentTimeOfDay == .morning ? "evening" : "morning") routines will appear later.")
                    }
                } else {
                    todayFeedContent
                }
            }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
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
                }
            }
            .fullScreenCover(isPresented: $showingGuidedFlow) {
                checkForAchievements()
            } content: {
                GuidedFlowView(routines: pendingRoutines)
            }
            .fullScreenCover(item: $singleRoutineToStart, onDismiss: {
                checkForAchievements()
            }) { routine in
                GuidedFlowView(routine: routine)
            }
            .overlay {
                if showAchievementUnlock, let achievement = unlockedAchievement {
                    AchievementUnlockView(achievement: achievement) {
                        showAchievementUnlock = false
                        unlockedAchievement = nil
                    }
                }
            }
        }
    }

    // MARK: - Achievement Check

    private func checkForAchievements() {
        let newlyUnlocked = achievementManager.checkForNewAchievements(
            logs: logs,
            routines: routines,
            photos: photos,
            analyses: analyses
        )

        if let first = newlyUnlocked.first {
            unlockedAchievement = first
            showAchievementUnlock = true
        }
    }

    // MARK: - Today Feed

    private var todayFeedContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Flat routine list
                routineList

                // Start button
                if !pendingRoutines.isEmpty {
                    startAllButton
                }

                // Completion footer
                completionFooter

                Spacer(minLength: 16)
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Routine List

    private var routineList: some View {
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
    }

    // MARK: - Completion Footer

    private var completionFooter: some View {
        Group {
            if pendingRoutines.isEmpty {
                VStack(spacing: 4) {
                    Text("All Done!")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.green)
                    Text("\(completedCount)/\(todayRoutines.count) completed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("\(completedCount)/\(todayRoutines.count) completed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Routine Row

    private func todayRoutineRow(_ routine: Routine) -> some View {
        let completed = isCompletedToday(routine)
        let weekday = Calendar.current.component(.weekday, from: Date())
        let activeStepCount = routine.sortedSteps.filter { !$0.isSkipped(on: weekday) }.count

        return Button {
            if !completed {
                singleRoutineToStart = routine
            }
        } label: {
            HStack(spacing: 12) {
                // Icon
                ZStack {
                    Circle()
                        .fill(routine.category.color.opacity(completed ? 0.5 : 1))
                        .frame(width: 40, height: 40)

                    Image(systemName: routine.icon)
                        .font(.title3)
                        .foregroundStyle(routine.category.accentColor.opacity(completed ? 0.5 : 1))
                }

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(routine.name)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(completed ? .secondary : .primary)

                    Text("\(activeStepCount) steps")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

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

    // MARK: - Start All Button

    private var startAllButton: some View {
        Button {
            showingGuidedFlow = true
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "play.fill")
                    .font(.caption)
                Text(pendingRoutines.count == 1 ? "Start Routine" : "Start All (\(pendingRoutines.count))")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(.borderedProminent)
        .tint(currentTimeOfDay == .morning ? .orange : .indigo)
    }
}

#Preview {
    HomeView()
        .modelContainer(for: [Routine.self, RoutineStep.self, RoutineLog.self, StepDayVariant.self], inMemory: true)
}
