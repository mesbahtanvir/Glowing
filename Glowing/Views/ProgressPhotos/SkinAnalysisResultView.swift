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

            // Profile badges (skin type + face shape)
            if !analysis.skinType.isEmpty || !analysis.faceShape.isEmpty {
                HStack(spacing: 8) {
                    if !analysis.skinType.isEmpty {
                        profileBadge(label: "Skin Type", value: analysis.skinType, icon: "drop.halffull")
                    }
                    if !analysis.faceShape.isEmpty {
                        profileBadge(label: "Face Shape", value: analysis.faceShape, icon: "face.dashed")
                    }
                }
            }

            // Key metrics (6 user-facing categories)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(analysis.userFacingCategories) { category in
                    categoryCard(category)
                }
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

            // Hair health section
            if analysis.hasHairAnalysis {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "comb.fill")
                            .font(.caption)
                            .foregroundStyle(.indigo)
                        Text("Hair Health")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(analysis.hairOverallScore)/10")
                            .font(.caption)
                            .fontWeight(.bold)
                            .monospacedDigit()
                            .foregroundStyle(scoreColor(analysis.hairOverallScore, max: 10))
                    }

                    if !analysis.hairOverallNote.isEmpty {
                        Text(analysis.hairOverallNote)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(analysis.hairCategories) { category in
                            categoryCard(category)
                        }
                    }
                }
            }

            #if DEBUG
            // Full categories (developer view)
            VStack(alignment: .leading, spacing: 10) {
                Text("All Categories (Debug)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.orange)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(analysis.categories) { category in
                        categoryCard(category)
                    }
                }
            }

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

    private func categoryCard(_ category: SkinAnalysis.CategoryResult) -> some View {
        HStack(spacing: 8) {
            Image(systemName: category.icon)
                .font(.caption)
                .foregroundStyle(scoreColor(category.score, max: 10))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(category.name)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    Spacer()
                    Text("\(category.score)/10")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundStyle(scoreColor(category.score, max: 10))
                }
                Text(category.note)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
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
        if ratio >= 0.7 { return .green }
        if ratio >= 0.4 { return .orange }
        return .red
    }

    private func scoreLabel(_ score: Int) -> String {
        if score >= 80 { return "Excellent" }
        if score >= 60 { return "Good" }
        if score >= 40 { return "Fair" }
        return "Needs Work"
    }
}
