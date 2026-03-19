import SwiftUI
import SwiftData

struct EditRoutineView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let routine: Routine?

    @State private var name: String = ""
    @State private var category: Category = .face
    @State private var timeOfDay: TimeOfDay = .morning
    @State private var season: Season = .yearRound
    @State private var scheduledWeekdays: Set<Int> = []
    @State private var icon: String = "face.smiling"
    @State private var steps: [EditableStep] = []
    @State private var editingStep: EditableStep?
    @State private var editingStepIndex: Int?

    private static let weekdaySymbols: [(Int, String)] = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        // 1=Sun, 2=Mon, ..., 7=Sat
        return (1...7).map { ($0, formatter.weekdaySymbols[$0 - 1]) }
    }()

    private let curatedIcons = [
        "face.smiling", "drop.fill", "sparkles", "scissors",
        "hands.sparkles", "leaf.fill", "sun.max.fill", "moon.fill",
        "heart.fill", "star.fill", "bolt.fill", "flame.fill",
        "wind", "snowflake", "cloud.fill", "eye",
        "mouth", "comb.fill", "figure.walk", "bubbles.and.sparkles"
    ]

    var isEditing: Bool { routine != nil }

    init(routine: Routine? = nil) {
        self.routine = routine
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Info") {
                    TextField("Routine Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(Category.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Time of Day", selection: $timeOfDay) {
                        ForEach(TimeOfDay.allCases, id: \.self) { tod in
                            Text(tod.displayName).tag(tod)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Season", selection: $season) {
                        ForEach(Season.allCases, id: \.self) { s in
                            Label(s.displayName, systemImage: s.icon).tag(s)
                        }
                    }
                }

                Section("Schedule") {
                    if scheduledWeekdays.isEmpty {
                        Text("Every Day")
                            .foregroundStyle(.secondary)
                    }
                    ForEach(Self.weekdaySymbols, id: \.0) { weekday, name in
                        Toggle(name, isOn: Binding(
                            get: { scheduledWeekdays.contains(weekday) },
                            set: { isOn in
                                if isOn {
                                    scheduledWeekdays.insert(weekday)
                                } else {
                                    scheduledWeekdays.remove(weekday)
                                }
                            }
                        ))
                    }
                }

                Section("Icon") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(curatedIcons, id: \.self) { symbolName in
                                Button {
                                    icon = symbolName
                                } label: {
                                    Image(systemName: symbolName)
                                        .font(.title3)
                                        .frame(width: 40, height: 40)
                                        .background(
                                            icon == symbolName
                                                ? category.color
                                                : Color(.systemGray6)
                                        )
                                        .foregroundStyle(
                                            icon == symbolName
                                                ? category.accentColor
                                                : .secondary
                                        )
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Steps") {
                    if steps.isEmpty {
                        Text("No steps yet. Add your first step below.")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                            Button {
                                editingStepIndex = index
                                editingStep = step
                            } label: {
                                HStack {
                                    Text("\(index + 1).")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 24)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(step.title.isEmpty ? "Untitled Step" : step.title)
                                            .font(.body)
                                            .foregroundStyle(step.title.isEmpty ? .secondary : .primary)

                                        if !step.productName.isEmpty {
                                            Text(step.productName)
                                                .font(.caption)
                                                .foregroundStyle(.blue)
                                                .lineLimit(1)
                                        }

                                        if !step.notes.isEmpty {
                                            Text(step.notes)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(1)
                                        }
                                    }

                                    Spacer()

                                    if let duration = step.timerDuration {
                                        Label(formatDuration(duration), systemImage: "timer")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }

                                    if step.imageData != nil {
                                        Image(systemName: "photo")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .tint(.primary)
                        }
                        .onDelete(perform: deleteSteps)
                        .onMove(perform: moveSteps)
                    }

                    Button {
                        let newStep = EditableStep(title: "", notes: "")
                        steps.append(newStep)
                        editingStepIndex = steps.count - 1
                        editingStep = newStep
                    } label: {
                        Label("Add Step", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Routine" : "New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(item: $editingStep) { step in
                if let index = editingStepIndex {
                    EditStepView(step: $steps[index])
                }
            }
            .onAppear {
                if let routine {
                    name = routine.name
                    category = routine.category
                    timeOfDay = routine.timeOfDay
                    season = routine.season
                    scheduledWeekdays = routine.scheduledWeekdays
                    icon = routine.icon
                    steps = routine.sortedSteps.map { routineStep in
                        EditableStep(
                            title: routineStep.title,
                            productName: routineStep.productName ?? "",
                            notes: routineStep.notes ?? "",
                            imageData: routineStep.imageData,
                            timerDuration: routineStep.timerDuration,
                            dayVariants: routineStep.dayVariants.map { dv in
                                EditableDayVariant(
                                    weekday: dv.weekday,
                                    productName: dv.productName ?? "",
                                    notes: dv.notes ?? "",
                                    skip: dv.skip
                                )
                            }.sorted { $0.weekday < $1.weekday }
                        )
                    }
                }
            }
        }
    }

    private func save() {
        if let routine {
            routine.name = name
            routine.category = category
            routine.timeOfDay = timeOfDay
            routine.season = season
            routine.scheduledWeekdays = scheduledWeekdays
            routine.icon = icon

            // Remove old steps
            for step in routine.steps {
                modelContext.delete(step)
            }
            routine.steps = []

            // Add updated steps
            for (index, editableStep) in steps.enumerated() where !editableStep.title.trimmingCharacters(in: .whitespaces).isEmpty {
                let routineStep = makeRoutineStep(from: editableStep, order: index)
                routine.steps.append(routineStep)
            }
        } else {
            let newRoutine = Routine(name: name, category: category, timeOfDay: timeOfDay, season: season, scheduledWeekdays: scheduledWeekdays, icon: icon)
            modelContext.insert(newRoutine)

            for (index, editableStep) in steps.enumerated() where !editableStep.title.trimmingCharacters(in: .whitespaces).isEmpty {
                let routineStep = makeRoutineStep(from: editableStep, order: index)
                newRoutine.steps.append(routineStep)
            }
        }
    }

    private func deleteSteps(offsets: IndexSet) {
        steps.remove(atOffsets: offsets)
    }

    private func moveSteps(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }

    private func makeRoutineStep(from editableStep: EditableStep, order: Int) -> RoutineStep {
        let routineStep = RoutineStep(
            order: order,
            title: editableStep.title,
            productName: editableStep.productName.isEmpty ? nil : editableStep.productName,
            notes: editableStep.notes.isEmpty ? nil : editableStep.notes,
            imageData: editableStep.imageData,
            timerDuration: editableStep.timerDuration
        )

        for variant in editableStep.dayVariants where variant.skip || !variant.productName.isEmpty || !variant.notes.isEmpty {
            let dv = StepDayVariant(
                weekday: variant.weekday,
                productName: variant.productName.isEmpty ? nil : variant.productName,
                notes: variant.notes.isEmpty ? nil : variant.notes,
                skip: variant.skip
            )
            routineStep.dayVariants.append(dv)
        }

        return routineStep
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 && secs > 0 {
            return "\(mins)m \(secs)s"
        } else if mins > 0 {
            return "\(mins)m"
        } else {
            return "\(secs)s"
        }
    }
}
