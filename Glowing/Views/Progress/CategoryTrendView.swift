import SwiftUI
import Charts

struct CategoryTrendView: View {
    let name: String
    let icon: String
    let dataPoints: [ScoreDataPoint]

    private var latestScore: Int? {
        dataPoints.last?.score
    }

    private var color: Color {
        guard let score = latestScore else { return .secondary }
        if score >= 7 { return .teal }
        if score >= 4 { return .teal.opacity(0.6) }
        return .teal.opacity(0.35)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .lineLimit(1)
                Spacer()
                if let score = latestScore {
                    Text("\(score)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(color)
                }
            }

            if dataPoints.count >= 2 {
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round))
                }
                .chartYScale(domain: 0...10)
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(height: 32)
            } else {
                Text(dataPoints.isEmpty ? "No data" : "Need 2+ sessions")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .frame(height: 32)
            }
        }
        .padding(8)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
