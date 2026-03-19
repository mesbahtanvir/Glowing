import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Routine.createdAt) private var routines: [Routine]
    @Query private var logs: [RoutineLog]
    @State private var showingCreateSheet = false

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

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    ContentUnavailableView {
                        Label("No Routines", systemImage: "sparkles")
                    } description: {
                        Text("All default routines have been removed. Tap + to create a new one.")
                    }
                } else {
                    List {
                        ForEach(routinesByCategory, id: \.0) { category, routinesInGroup in
                            Section {
                                ForEach(routinesInGroup) { routine in
                                    NavigationLink(value: routine) {
                                        routineRow(routine)
                                    }
                                }
                                .onDelete { offsets in
                                    for index in offsets {
                                        modelContext.delete(routinesInGroup[index])
                                    }
                                }
                            } header: {
                                HStack(spacing: 6) {
                                    Image(systemName: category.defaultIcon)
                                        .foregroundStyle(category.accentColor)
                                    Text(category.displayName)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Routines")
            .navigationDestination(for: Routine.self) { routine in
                RoutineDetailView(routine: routine)
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showingCreateSheet = true
                    } label: {
                        Label("Add", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreateSheet) {
                EditRoutineView()
            }
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

                Text("\(routine.sortedSteps.count) steps · \(routine.timeOfDay.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            let streak = StreakCalculator.currentStreak(for: routine, logs: logs)
            if streak > 0 {
                StreakBadgeView(streak: streak)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    RoutineListView()
        .modelContainer(for: [Routine.self, RoutineStep.self, RoutineLog.self, StepDayVariant.self], inMemory: true)
}
