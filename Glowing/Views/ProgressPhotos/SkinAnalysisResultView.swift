import SwiftUI

struct SkinAnalysisResultView: View {
    let analysis: SkinAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            faceAnalysisContent

            // Timestamp
            Text("Analyzed \(analysis.analyzedAt.formatted(.relative(presentation: .named)))")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(Color(.systemGray6).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    // MARK: - Face Analysis Content

    private var faceAnalysisContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Overall score + summary
            HStack(alignment: .top, spacing: 14) {
                scoreRing(score: analysis.overallScore, max: 100, size: 52)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Skin Health Score")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(scoreLabel(analysis.overallScore))
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(scoreColor(analysis.overallScore, max: 100).opacity(0.15))
                            .foregroundStyle(scoreColor(analysis.overallScore, max: 100))
                            .clipShape(Capsule())
                    }
                    Text(analysis.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(4)
                }
            }

            // Profile badges (skin type + face shape + hair type)
            if !analysis.skinType.isEmpty || !analysis.faceShape.isEmpty || !analysis.hairType.isEmpty {
                HStack(spacing: 8) {
                    if !analysis.skinType.isEmpty {
                        profileBadge(label: "Skin Type", value: analysis.skinType, icon: "drop.halffull")
                    }
                    if !analysis.faceShape.isEmpty {
                        profileBadge(label: "Face Shape", value: analysis.faceShape, icon: "face.dashed")
                    }
                    if !analysis.hairType.isEmpty {
                        profileBadge(label: "Hair Type", value: analysis.hairType, icon: "comb.fill")
                    }
                }
            }

            // Top concerns (lowest scoring categories)
            let concerns = analysis.topConcerns
            if !concerns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Top Opportunities")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(concerns) { entry in
                                HStack(spacing: 4) {
                                    Text("\(entry.score)")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .monospacedDigit()
                                        .foregroundStyle(scoreColor(entry.score, max: 10))
                                    Text(entry.label)
                                        .font(.caption2)
                                        .lineLimit(1)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(scoreColor(entry.score, max: 10).opacity(0.1))
                                .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            // Grouped category sections
            ForEach(analysis.displayGroups) { group in
                groupSection(group)
            }

            // Recommendations
            if !analysis.recommendations.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Recommendations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    Text(analysis.recommendations)
                        .font(.caption)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            #if DEBUG
            // Per-side observations
            if !analysis.leftSideNote.isEmpty || !analysis.rightSideNote.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Side-by-Side Observations")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    if !analysis.leftSideNote.isEmpty {
                        sideNote(label: "Left Side", note: analysis.leftSideNote)
                    }
                    if !analysis.rightSideNote.isEmpty {
                        sideNote(label: "Right Side", note: analysis.rightSideNote)
                    }
                }
            }
            #endif
        }
    }

    // MARK: - Group Section

    private func groupSection(_ group: CategoryGroup) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Group header
            HStack(spacing: 8) {
                Image(systemName: group.icon)
                    .font(.caption)
                    .foregroundStyle(scoreColor(Int(group.averageScore.rounded()), max: 10))
                Text(group.label)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f", group.averageScore))
                    .font(.caption)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .foregroundStyle(scoreColor(Int(group.averageScore.rounded()), max: 10))
                Text("avg")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(group.entries) { entry in
                    categoryCard(entry)
                }
            }
        }
    }

    // MARK: - Score Ring

    private func scoreRing(score: Int, max: Int, size: CGFloat) -> some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray4), lineWidth: 4)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: Double(score) / Double(max))
                .stroke(scoreColor(score, max: max), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
            Text("\(score)")
                .font(.headline)
                .fontWeight(.bold)
                .monospacedDigit()
        }
    }

    // MARK: - Category Card

    private func categoryCard(_ entry: CategoryEntry) -> some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(entry.label)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Text("\(entry.score)/10")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(scoreColor(entry.score, max: 10))
                }
                Text(entry.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                if entry.confidence == "low" {
                    Text("(low confidence)")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(8)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Profile Badge

    private func profileBadge(label: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(value.capitalized)
                    .font(.caption2)
                    .fontWeight(.medium)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .clipShape(Capsule())
    }

    // MARK: - Side Note

    private func sideNote(label: String, note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: label == "Left Side" ? "arrow.turn.up.left" : "arrow.turn.up.right")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .fontWeight(.medium)
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Color & Labels

    private func scoreColor(_ score: Int, max: Int) -> Color {
        let ratio = Double(score) / Double(max)
        if ratio >= 0.7 { return .teal }
        if ratio >= 0.4 { return .teal.opacity(0.6) }
        return .teal.opacity(0.35)
    }

    private func scoreLabel(_ score: Int) -> String {
        if score >= 80 { return "Thriving" }
        if score >= 60 { return "On Track" }
        if score >= 40 { return "Building" }
        return "Starting Out"
    }
}
