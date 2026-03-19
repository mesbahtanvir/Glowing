import SwiftUI

struct AchievementBadgeView: View {
    let achievement: AchievementType
    let isUnlocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(isUnlocked ? Color.yellow.opacity(0.15) : Color(.systemGray5))
                    .frame(width: 48, height: 48)

                Image(systemName: achievement.icon)
                    .font(.title3)
                    .foregroundStyle(isUnlocked ? .yellow : .secondary.opacity(0.4))
            }

            Text(achievement.name)
                .font(.caption2)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(isUnlocked ? .primary : .secondary)
        }
        .frame(width: 70)
        .opacity(isUnlocked ? 1.0 : 0.5)
    }
}
