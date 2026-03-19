import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query private var logs: [RoutineLog]
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query private var progressPhotos: [ProgressPhoto]
    @State private var showCapture = false

    private var dailyStreak: Int {
        StreakCalculator.currentDailyStreak(logs: logs, routines: routines)
    }

    /// All completion dates across all routines, colored by category
    private var allCompletionDates: Set<DateComponents> {
        var dates = Set<DateComponents>()
        let calendar = Calendar.current
        for log in logs where log.isFullyCompleted {
            let comps = calendar.dateComponents([.year, .month, .day], from: log.completedAt)
            dates.insert(comps)
        }
        return dates
    }

    /// Week summary: for each of the last 7 days, how many routines were completed
    private var weekSummary: [(Date, Int, Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).reversed().map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today)!
            let total = routines.filter { $0.isScheduledToday(on: date) }.count
            let completed = routines.filter { routine in
                logs.contains { log in
                    log.routine?.persistentModelID == routine.persistentModelID
                    && log.isFullyCompleted
                    && calendar.isDate(log.completedAt, inSameDayAs: date)
                }
            }.count
            return (date, completed, total)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if logs.isEmpty {
                    ContentUnavailableView {
                        Label("No History Yet", systemImage: "calendar")
                    } description: {
                        Text("Complete routines to start building your streak.")
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Streak + week overview
                            streakHeader
                                .padding(.horizontal)

                            // Weekly bar
                            weekBar
                                .padding(.horizontal)

                            // Combined calendar
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Completion Calendar")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                CalendarGridView(
                                    completionDates: allCompletionDates,
                                    accentColor: .green
                                )
                                .padding(.horizontal)
                            }

                            // Progress Photos
                            progressPhotosSection
                                .padding(.horizontal)

                            // Per-routine breakdown (compact)
                            VStack(alignment: .leading, spacing: 12) {
                                Text("By Routine")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal)

                                ForEach(routines) { routine in
                                    NavigationLink(value: routine) {
                                        routineStreakRow(routine)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Spacer(minLength: 16)
                        }
                        .padding(.top, 8)
                    }
                    .navigationDestination(for: Routine.self) { routine in
                        RoutineHistoryDetailView(routine: routine, logs: logs)
                    }
                }
            }
            .navigationTitle("History")
            .fullScreenCover(isPresented: $showCapture) {
                ProgressPhotoCaptureView()
            }
        }
    }

    // MARK: - Progress Photos Section

    private var progressPhotosSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Progress Photos")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                NavigationLink {
                    ProgressPhotoGalleryView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "camera.fill")
                            .font(.callout)
                            .foregroundStyle(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Photos")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.primary)

                            let sessionCount = Set(progressPhotos.map(\.sessionID)).count
                            Text(sessionCount == 0 ? "No sessions yet" : "\(sessionCount) session\(sessionCount == 1 ? "" : "s")")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(12)
                    .background(Color(.systemGray6).opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }

            Button {
                showCapture = true
            } label: {
                Label("Take Progress Photo", systemImage: "camera")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.bordered)
            .tint(.blue)
        }
    }

    // MARK: - Streak Header

    private var streakHeader: some View {
        HStack(spacing: 20) {
            // Daily streak
            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                        .font(.title2)
                    Text("\(dailyStreak)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                }
                Text("Day Streak")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Total completions
            let totalCompletions = logs.filter { $0.isFullyCompleted }.count
            VStack(spacing: 6) {
                Text("\(totalCompletions)")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Text("Total Done")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(.green.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - Week Bar

    private var weekBar: some View {
        HStack(spacing: 6) {
            ForEach(weekSummary, id: \.0) { date, completed, total in
                VStack(spacing: 6) {
                    // Day label
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    // Completion indicator
                    ZStack {
                        Circle()
                            .fill(total > 0 && completed >= total ? .green : Color(.systemGray5))
                            .frame(width: 32, height: 32)

                        if total > 0 && completed >= total {
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                        } else if completed > 0 {
                            Circle()
                                .trim(from: 0, to: total > 0 ? Double(completed) / Double(total) : 0)
                                .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                                .frame(width: 28, height: 28)
                                .rotationEffect(.degrees(-90))
                        }
                    }

                    // Date
                    Text(date.formatted(.dateTime.day()))
                        .font(.caption2)
                        .foregroundStyle(Calendar.current.isDateInToday(date) ? .primary : .secondary)
                        .fontWeight(Calendar.current.isDateInToday(date) ? .bold : .regular)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Routine Streak Row

    private func routineStreakRow(_ routine: Routine) -> some View {
        let streak = StreakCalculator.currentStreak(for: routine, logs: logs)

        return HStack(spacing: 12) {
            Image(systemName: routine.icon)
                .font(.callout)
                .foregroundStyle(routine.category.accentColor)
                .frame(width: 32, height: 32)
                .background(routine.category.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(routine.timeOfDay.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if streak > 0 {
                StreakBadgeView(streak: streak)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}

// MARK: - Routine History Detail (drill-down)

struct RoutineHistoryDetailView: View {
    let routine: Routine
    let logs: [RoutineLog]

    var body: some View {
        List {
            Section {
                HStack {
                    Image(systemName: routine.icon)
                        .foregroundStyle(routine.category.accentColor)
                        .frame(width: 30)

                    Text(routine.name)
                        .font(.headline)

                    Spacer()

                    StreakBadgeView(
                        streak: StreakCalculator.currentStreak(for: routine, logs: logs)
                    )
                }
            }

            Section {
                CalendarGridView(
                    completionDates: StreakCalculator.completionDates(for: routine, logs: logs),
                    accentColor: routine.category.accentColor
                )
            }
        }
        .navigationTitle(routine.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
