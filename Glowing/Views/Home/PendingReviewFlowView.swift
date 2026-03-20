import SwiftUI
import SwiftData

/// Lightweight flow for reviewing analysis results after they were processed in the background.
/// Reuses the same ImageAnalysisViewModel that was running in PendingAnalysisManager.
struct PendingReviewFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    var imageAnalysisVM: ImageAnalysisViewModel
    var capturedPhotos: [PhotoAngle: Data]

    @State private var step: Step = .review

    enum Step {
        case review
        case clarifying
        case generating
        case suggested
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .review:
                    if let profile = imageAnalysisVM.profile {
                        ExtractedDetailsView(
                            profile: profile,
                            hasClarifications: !imageAnalysisVM.clarificationQuestions.isEmpty,
                            onProceed: {
                                imageAnalysisVM.proceedFromReview()
                                if imageAnalysisVM.clarificationQuestions.isEmpty {
                                    step = .generating
                                } else {
                                    step = .clarifying
                                }
                            },
                            onOverride: { trait, value in
                                imageAnalysisVM.overrideTrait(trait, value: value)
                            }
                        )
                    }

                case .clarifying:
                    if let question = imageAnalysisVM.currentQuestion {
                        ClarificationView(
                            question: question,
                            currentIndex: imageAnalysisVM.currentQuestionIndex,
                            totalCount: imageAnalysisVM.clarificationQuestions.count,
                            onAnswer: { value in
                                imageAnalysisVM.submitClarificationAnswer(value)
                            },
                            onSkip: {
                                imageAnalysisVM.skipRemainingQuestions()
                            }
                        )
                    } else {
                        ProgressView()
                    }

                case .generating:
                    VStack(spacing: 24) {
                        Spacer()
                        if let error = imageAnalysisVM.error {
                            Image(systemName: "exclamationmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundStyle(.red)
                            Text("Generation Failed")
                                .font(.title3.bold())
                            Text(error)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                            Button("Try Again") {
                                Task { await imageAnalysisVM.generateRoutines() }
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Creating your personalized routines...")
                                .font(.headline)
                            Text("Based on your unique profile")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }

                case .suggested:
                    suggestedRoutinesView
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: imageAnalysisVM.flowState) { _, newState in
                switch newState {
                case .generatingRoutines:
                    if step == .clarifying { step = .generating }
                case .showingResults:
                    step = .suggested
                default:
                    break
                }
            }
        }
    }

    // MARK: - Suggested Routines

    private var routineArray: [[String: Any]] {
        imageAnalysisVM.generatedRoutines
    }

    private var suggestedRoutinesView: some View {
        VStack(spacing: 0) {
            if !routineArray.isEmpty {
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 36))
                                .foregroundStyle(.tint)
                            Text("Your Routines")
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Personalized from your photos")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)

                        ForEach(Array(routineArray.enumerated()), id: \.offset) { _, routine in
                            routinePreviewCard(routine)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                }
            } else {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("No Routines Generated")
                        .font(.title3)
                        .fontWeight(.bold)
                    Text("We couldn't generate routines from the analysis. You can create your own.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                Spacer()
            }

            Button {
                saveAndComplete()
            } label: {
                Text("Looks Good")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func routinePreviewCard(_ routine: [String: Any]) -> some View {
        let name = routine["name"] as? String ?? "Routine"
        let steps = routine["steps"] as? [[String: Any]] ?? []

        return VStack(alignment: .leading, spacing: 8) {
            Text(name)
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(Array(steps.enumerated()), id: \.offset) { index, stepData in
                HStack(spacing: 8) {
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .frame(width: 20, height: 20)
                        .background(.teal)
                        .clipShape(Circle())

                    Text(stepData["title"] as? String ?? "Step \(index + 1)")
                        .font(.caption)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Save

    private func saveAndComplete() {
        // Save photos
        let sessionID = UUID()
        let now = Date()
        for (angle, data) in capturedPhotos {
            let photo = ProgressPhoto(
                angle: angle,
                imageData: data,
                sessionID: sessionID,
                capturedAt: now
            )
            modelContext.insert(photo)
        }

        // Save routines
        imageAnalysisVM.saveRoutines(modelContext: modelContext)

        // Mark onboarding complete
        if let user = AuthManager.shared.currentUser {
            user.hasCompletedOnboarding = true
        }

        // Clean up pending manager
        PendingAnalysisManager.shared.markComplete()

        dismiss()
    }
}
