import SwiftUI
import UIKit

/// The advice for one outfit photo.
///
/// Quiet by default: a short read on the look, then the suggestions. Each card shows the change to try;
/// what we noticed and why it works are one tap away.
struct OutfitAdviceResultView: View {
    let advice: OutfitAdvice
    let photo: UIImage?
    let goal: StyleGoal?
    let onNewPhoto: () -> Void
    let onEditGoal: () -> Void

    @State private var selectedKind: AdviceKind
    @State private var expandedIDs: Set<String> = []

    init(
        advice: OutfitAdvice,
        photo: UIImage?,
        goal: StyleGoal?,
        onNewPhoto: @escaping () -> Void,
        onEditGoal: @escaping () -> Void
    ) {
        self.advice = advice
        self.photo = photo
        self.goal = goal
        self.onNewPhoto = onNewPhoto
        self.onEditGoal = onEditGoal
        _selectedKind = State(initialValue: advice.defaultKind)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if !advice.summary.isEmpty {
                    Text(advice.summary)
                        .font(.body)
                }

                adviceSection

                if !advice.strengths.isEmpty {
                    strengthsSection
                }

                notesSection

                actions

                Text("These are suggestions. You know your taste best.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
            .padding()
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: 6) {
                if !advice.detectedStyle.isEmpty {
                    Text("Reads as \(advice.detectedStyle)")
                        .font(.headline)
                }

                if let goal {
                    Text("Goal: \(goal.text)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let alignment = advice.goalAlignment {
                    alignmentPill(alignment)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private func alignmentPill(_ alignment: GoalAlignment) -> some View {
        let color = alignmentColor(alignment)
        return Label(alignment.displayName, systemImage: alignment.icon)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .foregroundStyle(color)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }

    /// Teal at different strengths rather than red and green: a read on progress, not a verdict.
    private func alignmentColor(_ alignment: GoalAlignment) -> Color {
        switch alignment {
        case .onTarget: Color.teal
        case .close: Color.teal.opacity(0.75)
        case .offTarget: Color.secondary
        }
    }

    // MARK: - Advice

    private var adviceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Advice type", selection: $selectedKind) {
                ForEach(AdviceKind.allCases, id: \.self) { kind in
                    Text(kind.displayName).tag(kind)
                }
            }
            .pickerStyle(.segmented)

            Text(lensDescription)
                .font(.footnote)
                .foregroundStyle(.secondary)

            let items = advice.items(for: selectedKind)
            if items.isEmpty {
                Text("Nothing to flag here. This part of your look holds up.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(items) { item in
                    AdviceCard(item: item, isExpanded: expandedIDs.contains(item.id)) {
                        toggle(item.id)
                    }
                }
            }
        }
    }

    private var lensDescription: String {
        switch selectedKind {
        case .subjective:
            if let goal {
                return "Based on your goal: \(goal.text)"
            }
            if !advice.detectedStyle.isEmpty {
                return "Based on the style you seem to be going for: \(advice.detectedStyle)"
            }
            return "Based on the style you seem to be going for."
        case .objective:
            return "What tends to work for anyone: color, proportion, fit and finish."
        }
    }

    private func toggle(_ id: String) {
        var updated = expandedIDs
        if updated.contains(id) {
            updated.remove(id)
        } else {
            updated.insert(id)
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            expandedIDs = updated
        }
    }

    // MARK: - Strengths and Notes

    private var strengthsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What's working")
                .font(.subheadline.weight(.semibold))

            ForEach(Array(advice.strengths.enumerated()), id: \.offset) { _, line in
                Label(line, systemImage: "checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var notesSection: some View {
        if !advice.limitations.isEmpty || advice.photoTip != nil {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(advice.limitations.enumerated()), id: \.offset) { _, line in
                    Label(line, systemImage: "info.circle")
                }

                if let tip = advice.photoTip {
                    Label(tip, systemImage: "camera.viewfinder")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button(action: onNewPhoto) {
                Text("Check Another Look")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .controlSize(.large)

            Button(goal == nil ? "Add a Goal" : "Change Goal", action: onEditGoal)
                .font(.subheadline)
        }
    }
}

// MARK: - Advice Card

private struct AdviceCard: View {
    let item: AdviceItem
    let isExpanded: Bool
    let onToggle: () -> Void

    private var hasDetail: Bool {
        !item.observation.isEmpty || !item.rationale.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: onToggle) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Label(item.principle.displayName, systemImage: item.principle.icon)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)

                        if item.impact == .high {
                            Text("Big impact")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .foregroundStyle(Color.teal)
                                .background(Color.teal.opacity(0.14))
                                .clipShape(Capsule())
                        }

                        Spacer(minLength: 0)

                        if hasDetail {
                            Image(systemName: "chevron.down")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        }
                    }

                    Text(item.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)

                    Text(item.suggestion)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(isExpanded ? "Hides the details" : "Shows the details")

            if isExpanded && hasDetail {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    if !item.observation.isEmpty {
                        detail(title: "What we noticed", text: item.observation)
                    }
                    if !item.rationale.isEmpty {
                        detail(title: "Why it works", text: item.rationale)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func detail(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.subheadline)
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        OutfitAdviceResultView(
            advice: OutfitAdvice(
                detectedStyle: "smart casual",
                summary: "A relaxed, put-together look. Swapping the hoodie for a collared layer is the one change that gets it closest to an interview.",
                goalAlignment: .close,
                strengths: [
                    "The navy chinos are a clean, versatile base.",
                    "The brown belt and shoes match.",
                ],
                subjective: [
                    AdviceItem(
                        id: "subjective-0",
                        kind: .subjective,
                        principle: .occasion,
                        impact: .high,
                        title: "Swap the hoodie for a collared layer",
                        observation: "The grey zip hoodie reads as weekend wear next to the tailored trousers.",
                        suggestion: "Try a navy knit polo or an unstructured blazer in its place.",
                        rationale: "For a job interview a collar signals effort and matches the trousers."
                    ),
                ],
                objective: [
                    AdviceItem(
                        id: "objective-0",
                        kind: .objective,
                        principle: .proportion,
                        impact: .medium,
                        title: "Stagger the hem lengths",
                        observation: "The tee and the jacket both end at the hip, so two hems stack at one height.",
                        suggestion: "Tuck the front of the tee loosely, or choose a shorter tee.",
                        rationale: "Staggered hems give an outfit a clear rhythm instead of a blocky stack."
                    ),
                    AdviceItem(
                        id: "objective-1",
                        kind: .objective,
                        principle: .color,
                        impact: .low,
                        title: "Add one lighter piece",
                        observation: "Navy, charcoal and black sit close together in value.",
                        suggestion: "A white or light blue shirt would give the outfit a focal point.",
                        rationale: "Contrast in lightness shows where to look first."
                    ),
                ],
                limitations: ["Your shoes are cropped out of the photo, so we couldn't judge them."],
                photoTip: "Step back so your whole outfit fits in the frame."
            ),
            photo: nil,
            goal: StyleGoal("Job interview"),
            onNewPhoto: {},
            onEditGoal: {}
        )
        .navigationTitle("Style")
    }
}
