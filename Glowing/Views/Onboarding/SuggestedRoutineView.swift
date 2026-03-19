import SwiftUI
import SwiftData

struct SuggestedRoutineView: View {
    @Bindable var viewModel: OnboardingViewModel
    var modelContext: ModelContext

    private var routineArray: [[String: Any]] {
        (viewModel.suggestedRoutineJSON?["routines"] as? [[String: Any]]) ?? []
    }

    private var routinesByCategory: [(Category, [[String: Any]])] {
        let grouped = Dictionary(grouping: routineArray) { routine in
            Category(rawValue: routine["category"] as? String ?? "face") ?? .face
        }
        return Category.allCases.compactMap { cat in
            guard let routines = grouped[cat], !routines.isEmpty else { return nil }
            return (cat, routines)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if !routineArray.isEmpty {
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 36))
                                .foregroundStyle(.tint)

                            Text("Your Routines")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Personalized from your photos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)

                        // Routines grouped by category
                        ForEach(routinesByCategory, id: \.0) { category, routines in
                            categorySection(category: category, routines: routines)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)

                    Text("No Routines Generated")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("We couldn't generate routines from the analysis. You can create your own after setup.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            }

            // Action buttons
            VStack(spacing: 12) {
                Button {
                    viewModel.completeOnboarding(modelContext: modelContext)
                } label: {
                    Text(routineArray.isEmpty ? "Continue" : "Looks Good")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    // MARK: - Category Section

    private func categorySection(category: Category, routines: [[String: Any]]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: category.defaultIcon)
                    .font(.caption)
                    .foregroundStyle(category.accentColor)
                Text(category.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }

            ForEach(Array(routines.enumerated()), id: \.offset) { _, routine in
                routineCard(routine, category: category)
            }
        }
    }

    private func routineCard(_ routine: [String: Any], category: Category) -> some View {
        let name = routine["name"] as? String ?? "Routine"
        let steps = routine["steps"] as? [[String: Any]] ?? []
        let weekdays = routine["scheduledWeekdays"] as? [Int] ?? []
        let timeOfDay = routine["timeOfDay"] as? String ?? "morning"

        return VStack(alignment: .leading, spacing: 0) {
            // Routine header
            HStack(spacing: 8) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if !weekdays.isEmpty {
                    Text(weekdaySummary(weekdays))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text(timeOfDay.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            // Steps
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                if index > 0 {
                    Divider()
                        .padding(.leading, 44)
                }
                stepRow(step: step, index: index + 1, color: category.accentColor)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func stepRow(step: [String: Any], index: Int, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(step["title"] as? String ?? "Step \(index)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let product = step["productName"] as? String, !product.isEmpty {
                    Text(product)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let notes = step["notes"] as? String, !notes.isEmpty {
                    Text(notes)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Helpers

    private func weekdaySummary(_ weekdays: [Int]) -> String {
        let symbols = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let names = weekdays.sorted().compactMap { $0 >= 1 && $0 <= 7 ? symbols[$0] : nil }
        return names.joined(separator: " · ")
    }
}
