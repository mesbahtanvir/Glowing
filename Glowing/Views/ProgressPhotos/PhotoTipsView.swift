import SwiftUI

struct PhotoTipsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "lightbulb.max.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.yellow)

                        Text("Photo Tips")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Consistent photos help track real changes in your skin over time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 16)
                    }
                    .padding(.top, 16)

                    // Tips
                    VStack(alignment: .leading, spacing: 16) {
                        tipRow(icon: "location.fill", color: .blue,
                               title: "Same Spot",
                               detail: "Take photos in the same location each time for consistent lighting.")

                        tipRow(icon: "sun.max.fill", color: .orange,
                               title: "Face a Window",
                               detail: "Natural, front-facing light gives the most accurate skin details.")

                        tipRow(icon: "ruler.fill", color: .green,
                               title: "Arm's Length",
                               detail: "Hold your phone at arm's length for consistent framing.")

                        tipRow(icon: "camera.filters", color: .purple,
                               title: "No Filters",
                               detail: "Use a clean camera — no beauty mode, no filters, no editing.")

                        tipRow(icon: "person.crop.circle", color: .teal,
                               title: "Tie Hair Back",
                               detail: "Keep hair away from your face so skin is fully visible.")
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.bottom, 24)
            }
            .navigationTitle("Before You Start")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Got It") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func tipRow(icon: String, color: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
