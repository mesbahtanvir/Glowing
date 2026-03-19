import SwiftUI

struct RoutineRowView: View {
    let routine: Routine
    var streak: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: routine.icon)
                .font(.title3)
                .foregroundStyle(routine.category.accentColor)
                .frame(width: 36, height: 36)
                .background(routine.category.color)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(routine.name)
                    .font(.body)
                    .fontWeight(.medium)

                Text("\(routine.sortedSteps.count) steps")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if streak > 0 {
                StreakBadgeView(streak: streak)
            }
        }
        .padding(.vertical, 2)
    }
}
