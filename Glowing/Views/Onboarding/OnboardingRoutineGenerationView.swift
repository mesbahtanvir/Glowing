import SwiftUI

/// Shows progress while LLM generates routines, then auto-advances to suggested routines.
struct OnboardingRoutineGenerationView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let error = viewModel.imageAnalysisVM.error {
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
                    Task { await viewModel.imageAnalysisVM.generateRoutines() }
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
        .onAppear {
            // The ImageAnalysisViewModel should already be generating routines
            // via proceedFromReview() or submitClarificationAnswer()
        }
        .onChange(of: viewModel.imageAnalysisVM.flowState) { _, newState in
            if newState == .showingResults {
                viewModel.onImageAnalysisComplete()
            }
        }
    }
}
