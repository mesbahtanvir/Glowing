import SwiftUI
import Charts

struct ScoreDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Int
}

struct ScoreTrendChartView: View {
    let title: String
    let icon: String
    let color: Color
    let dataPoints: [ScoreDataPoint]

    private var latestScore: Int? {
        dataPoints.last?.score
    }

    private var previousScore: Int? {
        guard dataPoints.count >= 2 else { return nil }
        return dataPoints[dataPoints.count - 2].score
    }

    private var delta: Int? {
        guard let latest = latestScore, let previous = previousScore else { return nil }
        return latest - previous
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Spacer()

                if let score = latestScore {
                    HStack(spacing: 4) {
                        Text("\(score)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .monospacedDigit()

                        if let delta, delta != 0 {
                            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundStyle(delta > 0 ? .green : .red)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background((delta > 0 ? Color.green : Color.red).opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            if dataPoints.count >= 2 {
                // Chart
                Chart(dataPoints) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(color.gradient)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))

                    AreaMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [color.opacity(0.2), color.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(color)
                    .symbolSize(20)
                }
                .chartYScale(domain: 0...100)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { value in
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                            .foregroundStyle(Color(.systemGray4))
                        AxisValueLabel()
                            .font(.caption2)
                    }
                }
                .frame(height: 140)
            } else if dataPoints.count == 1 {
                // Single data point — show message
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("\(dataPoints[0].score)")
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(color)
                        Text("Take another session to see your trend")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .frame(height: 80)
            } else {
                // No data
                HStack {
                    Spacer()
                    Text("No scores yet")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(height: 60)
            }
        }
        .padding(14)
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
