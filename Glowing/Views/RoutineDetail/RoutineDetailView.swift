import SwiftUI
import SwiftData

struct RoutineDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let routine: Routine

    @State private var showingEditSheet = false
    @State private var showingGuidedFlow = false
    @State private var showingDeleteConfirmation = false

    var body: some View {
        List {
            // Header
            Section {
                VStack(spacing: 12) {
                    Image(systemName: routine.icon)
                        .font(.system(size: 40))
                        .foregroundStyle(routine.category.accentColor)
                        .frame(width: 80, height: 80)
                        .background(routine.category.color)
                        .clipShape(Circle())

                    Text(routine.name)
                        .font(.title2)
                        .fontWeight(.bold)

                    HStack(spacing: 8) {
                        Label(routine.category.displayName, systemImage: routine.category.defaultIcon)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(routine.category.color)
                            .clipShape(Capsule())

                        Label(routine.timeOfDay.displayName, systemImage: routine.timeOfDay.icon)
                            .font(.caption)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .clipShape(Capsule())
                    }
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            // Steps
            Section("Steps") {
                if routine.sortedSteps.isEmpty {
                    Text("No steps added yet. Tap edit to add steps.")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                } else {
                    ForEach(routine.sortedSteps) { step in
                        HStack(spacing: 12) {
                            Text("\(step.order + 1)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.white)
                                .frame(width: 24, height: 24)
                                .background(routine.category.accentColor)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 2) {
                                Text(step.title)
                                    .font(.body)

                                if let productName = step.productName, !productName.isEmpty {
                                    Text(productName)
                                        .font(.caption)
                                        .foregroundStyle(routine.category.accentColor)
                                        .lineLimit(1)
                                }

                                if let notes = step.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }

                                if step.hasDayVariants {
                                    HStack(spacing: 3) {
                                        Image(systemName: "calendar.badge.clock")
                                        Text("Varies by day")
                                    }
                                    .font(.caption2)
                                    .foregroundStyle(.orange)
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
                        .padding(.vertical, 2)
                    }
                }
            }

            // Start Button
            if !routine.sortedSteps.isEmpty {
                Section {
                    Button {
                        showingGuidedFlow = true
                    } label: {
                        HStack {
                            Spacer()
                            Label("Start Routine", systemImage: "play.fill")
                                .font(.headline)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .tint(routine.category.accentColor)
                }
            }

            // Delete
            Section {
                Button("Delete Routine", role: .destructive) {
                    showingDeleteConfirmation = true
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditRoutineView(routine: routine)
        }
        .fullScreenCover(isPresented: $showingGuidedFlow) {
            GuidedFlowView(routine: routine)
        }
        .confirmationDialog("Delete Routine", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(routine)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete \"\(routine.name)\"? This cannot be undone.")
        }
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
