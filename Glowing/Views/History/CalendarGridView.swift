import SwiftUI

struct CalendarGridView: View {
    let completionDates: Set<DateComponents>
    var accentColor: Color = .blue

    @State private var displayedMonth: Date = Date()

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdaySymbols = Calendar.current.veryShortWeekdaySymbols

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.month(.wide).year())
    }

    private var daysInMonth: [DayItem] {
        guard let range = calendar.range(of: .day, in: .month, for: displayedMonth),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let offset = (firstWeekday - calendar.firstWeekday + 7) % 7

        var items: [DayItem] = []

        // Leading empty cells
        for _ in 0..<offset {
            items.append(DayItem(day: 0, isCompleted: false))
        }

        // Day cells
        for day in range {
            guard let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) else { continue }
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            let completed = completionDates.contains(components)
            items.append(DayItem(day: day, isCompleted: completed))
        }

        return items
    }

    var body: some View {
        VStack(spacing: 8) {
            // Month navigation
            HStack {
                Button {
                    changeMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(.plain)

                Spacer()

                Text(monthTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    changeMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(.plain)
            }

            // Weekday headers
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(daysInMonth) { item in
                    if item.day == 0 {
                        Color.clear
                            .frame(height: 28)
                    } else {
                        ZStack {
                            Circle()
                                .fill(item.isCompleted ? accentColor : Color.clear)
                                .frame(width: 28, height: 28)

                            Text("\(item.day)")
                                .font(.caption2)
                                .foregroundStyle(item.isCompleted ? .white : .primary)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func changeMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newMonth
        }
    }
}

private struct DayItem: Identifiable {
    let id = UUID()
    let day: Int
    let isCompleted: Bool
}
