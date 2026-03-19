import SwiftUI
import SwiftData

struct ImageAnalysisFlowView: View {
    @Bindable var viewModel: ImageAnalysisViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch viewModel.flowState {
                case .idle:
                    startView

                case .selectingImages:
                    Text("Capture your photos to begin analysis.")
                        .foregroundStyle(.secondary)

                case .checkingLighting:
                    if let warning = viewModel.lightingWarning {
                        lightingWarningView(warning)
                    } else {
                        progressView
                    }

                case .extractingDetails:
                    if viewModel.error != nil {
                        errorView
                    } else {
                        progressView
                    }

                case .reviewingDetails:
                    if let profile = viewModel.profile {
                        ExtractedDetailsView(
                            profile: profile,
                            hasClarifications: !viewModel.clarificationQuestions.isEmpty,
                            onProceed: { viewModel.proceedFromReview() },
                            onOverride: { trait, value in viewModel.overrideTrait(trait, value: value) }
                        )
                    }

                case .clarifying:
                    if let question = viewModel.currentQuestion {
                        ClarificationView(
                            question: question,
                            currentIndex: viewModel.currentQuestionIndex,
                            totalCount: viewModel.clarificationQuestions.count,
                            onAnswer: { value in viewModel.submitClarificationAnswer(value) },
                            onSkip: { viewModel.skipRemainingQuestions() }
                        )
                    }

                case .generatingRoutines:
                    if viewModel.error != nil {
                        errorView
                    } else {
                        progressView
                    }

                case .showingResults:
                    routineResultsView

                case .complete:
                    completeView
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if viewModel.flowState != .complete {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
            }
        }
    }

    // MARK: - Start View

    private var startView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "camera.viewfinder")
                .font(.system(size: 60))
                .foregroundStyle(.white.opacity(0.8))

            Text("Image Analysis")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("We'll analyze your photos to detect skin type, hair pattern, facial hair, and more — then create personalized routines.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                viewModel.startFresh()
            } label: {
                Text("Take New Photos")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)

            Text(viewModel.progressMessage)
                .font(.headline)
                .foregroundStyle(.white)

            Spacer()
        }
    }

    // MARK: - Lighting Warning

    private func lightingWarningView(_ warning: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.yellow)

            Text("Lighting Issue")
                .font(.title2.bold())
                .foregroundStyle(.white)

            Text(warning)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            if let condition = viewModel.lightingCondition {
                LightingMetricsView(condition: condition)
                    .padding(.horizontal, 24)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    viewModel.retakePhotos()
                } label: {
                    Text("Retake Photos")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                Button {
                    viewModel.proceedDespiteLighting()
                } label: {
                    Text("Continue Anyway")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Error View

    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.red)

            Text("Something went wrong")
                .font(.title3.bold())
                .foregroundStyle(.white)

            Text(viewModel.error ?? "Unknown error")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button {
                Task { await viewModel.extractDetails() }
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 12)
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Spacer()
        }
    }

    // MARK: - Routine Results

    private var routineResultsView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.yellow)
                    .padding(.top, 32)

                Text("Your Personalized Routines")
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Text("Based on your profile, here are your recommended routines.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                // Group routines by category
                ForEach(["face", "hair", "stubble"], id: \.self) { categoryRaw in
                    let routines = viewModel.generatedRoutines.filter {
                        ($0["category"] as? String) == categoryRaw
                    }
                    if !routines.isEmpty {
                        routineCategorySection(
                            category: Category(rawValue: categoryRaw) ?? .face,
                            routines: routines
                        )
                    }
                }

                Button {
                    viewModel.saveRoutines(modelContext: modelContext)
                } label: {
                    Text("Save Routines")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.white)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
        }
    }

    private func routineCategorySection(category: Category, routines: [[String: Any]]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: category.defaultIcon)
                Text(category.displayName)
                    .font(.headline)
            }
            .foregroundStyle(category.accentColor)
            .padding(.horizontal, 24)

            ForEach(Array(routines.enumerated()), id: \.offset) { _, routine in
                routineCard(routine)
            }
        }
    }

    private func routineCard(_ routine: [String: Any]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                let icon = routine["icon"] as? String ?? "sparkles"
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.7))
                Text(routine["name"] as? String ?? "Routine")
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Spacer()
                let timeOfDay = routine["timeOfDay"] as? String ?? ""
                Text(timeOfDay.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            let steps = routine["steps"] as? [[String: Any]] ?? []
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 8) {
                    Text("\(index + 1).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step["title"] as? String ?? "")
                            .font(.caption)
                            .foregroundStyle(.white)
                        if let product = step["productName"] as? String {
                            Text(product)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 24)
    }

    // MARK: - Complete View

    private var completeView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(.green)

            Text("Routines Saved!")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("Your personalized routines are ready to go.")
                .font(.body)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.white)
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
    }
}

// MARK: - Lighting Metrics View

struct LightingMetricsView: View {
    let condition: LightingCondition

    var body: some View {
        VStack(spacing: 8) {
            metricRow("Brightness", value: condition.faceBrightness, ideal: "0.45–0.65")
            metricRow("Balance", value: condition.brightnessBalance, ideal: "< 0.10")
            metricRow("Contrast", value: condition.contrast, ideal: "0.30–0.60")
        }
        .padding(16)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func metricRow(_ name: String, value: Float, ideal: String) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(String(format: "%.2f", value))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.white)
            Text("(ideal: \(ideal))")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
