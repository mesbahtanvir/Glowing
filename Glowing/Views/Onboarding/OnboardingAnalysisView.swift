import SwiftUI

struct OnboardingAnalysisView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if viewModel.isAnalyzing {
                analyzingContent
            } else if viewModel.analysisError != nil {
                errorContent
            } else {
                resultsContent
            }

            Spacer()

            if !viewModel.isAnalyzing && viewModel.analysisError == nil {
                Button {
                    viewModel.advance()
                } label: {
                    Text("See Your Routine")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }

            if viewModel.analysisError != nil {
                VStack(spacing: 12) {
                    Button {
                        viewModel.analysisError = nil
                        Task { await viewModel.analyzePhotos() }
                    } label: {
                        Text("Try Again")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)

                    Button {
                        // Skip analysis and go to suggested routine step
                        viewModel.advance()
                    } label: {
                        Text("Skip for Now")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Analyzing

    private var analyzingContent: some View {
        GlowingBubbleView(
            message: "Analyzing Your Skin",
            submessage: "Our AI is evaluating your photos to understand your skin and build a personalized routine.",
            accentColor: .blue
        )
    }

    // MARK: - Error

    private var errorContent: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Analysis Failed")
                    .font(.title2)
                    .fontWeight(.bold)

                Text(viewModel.analysisError ?? "Something went wrong.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
        }
    }

    // MARK: - Results

    private var resultsContent: some View {
        VStack(spacing: 24) {
            // Score ring
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 8)
                    .frame(width: 100, height: 100)

                Circle()
                    .trim(from: 0, to: Double(viewModel.overallScore) / 100.0)
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(viewModel.overallScore)")
                        .font(.title)
                        .fontWeight(.bold)
                        .monospacedDigit()
                    Text("/ 100")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                Text("Your Skin Score")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("This is your starting point, not a grade.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(viewModel.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Top concerns
            if !viewModel.topConcerns.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Concerns")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(viewModel.topConcerns, id: \.self) { concern in
                            Text(concern)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.12))
                                .foregroundStyle(.orange)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    private var scoreColor: Color {
        if viewModel.overallScore >= 70 { return .teal }
        if viewModel.overallScore >= 40 { return .teal.opacity(0.6) }
        return .teal.opacity(0.35)
    }
}
