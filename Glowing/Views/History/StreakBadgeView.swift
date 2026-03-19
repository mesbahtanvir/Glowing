import SwiftUI

struct StreakBadgeView: View {
    let streak: Int

    private var flameColor: Color {
        if streak >= 100 {
            return .purple
        } else if streak >= 30 {
            return .red
        } else if streak >= 7 {
            return .orange
        } else {
            return .orange.opacity(0.7)
        }
    }

    private var flameFont: Font {
        if streak >= 100 {
            return .title2
        } else if streak >= 30 {
            return .title3
        } else if streak >= 7 {
            return .subheadline
        } else {
            return .caption
        }
    }

    private var milestoneLabel: String? {
        if streak >= 100 {
            return "Unstoppable"
        } else if streak >= 30 {
            return "On Fire"
        } else if streak >= 7 {
            return "Hot Streak"
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: streak >= 30 ? "flame.circle.fill" : "flame.fill")
                .foregroundStyle(flameColor)
                .font(flameFont)

            Text("\(streak)")
                .fontWeight(.semibold)
                .font(.caption)

            if let label = milestoneLabel {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(flameColor)
            }
        }
    }
}
