import SwiftUI

struct StepCardView: View {
    let step: ResolvedStep
    let stepNumber: Int
    let totalSteps: Int
    var accentColor: Color = .blue

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {

                // ── Header: step number + title ──
                VStack(alignment: .leading, spacing: 8) {
                    Text("STEP \(stepNumber)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(accentColor)
                        .tracking(1.5)

                    Text(step.title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 16)

                // ── Product pill (what to use) ──
                if let productName = step.productName, !productName.isEmpty {
                    HStack(spacing: 8) {
                        Image(systemName: "drop.fill")
                            .font(.caption)
                            .foregroundStyle(accentColor)
                        Text(productName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(accentColor.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom, 16)
                }

                // ── Timer badge (if this step has a timer) ──
                if let duration = step.timerDuration, duration > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "timer")
                            .font(.caption)
                        Text(formatDuration(duration))
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(accentColor.opacity(0.8))
                    .padding(.bottom, 16)
                }

                // ── Divider ──
                if step.notes != nil || step.imageData != nil {
                    Rectangle()
                        .fill(Color(.separator).opacity(0.3))
                        .frame(height: 1)
                        .padding(.bottom, 16)
                }

                // ── Instructions (how to do it) ──
                if let notes = step.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How to do it")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                            .tracking(0.8)

                        Text(notes)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.bottom, 16)
                }

                // ── Step image ──
                if let imageData = step.imageData,
                   let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 8)
                }
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
    }

    private func formatDuration(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        if mins > 0 && secs > 0 {
            return "\(mins) min \(secs)s"
        } else if mins > 0 {
            return "\(mins) min"
        } else {
            return "\(secs)s"
        }
    }
}
