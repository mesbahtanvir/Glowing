import SwiftUI

/// Shows progress while LLM extracts traits from photos, then auto-advances.
struct OnboardingExtractionView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if let error = viewModel.imageAnalysisVM.error {
                // Error state
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.red)

                Text("Analysis Failed")
                    .font(.title3.bold())

                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Try Again") {
                    Task { await viewModel.imageAnalysisVM.extractDetails() }
                }
                .buttonStyle(.borderedProminent)
            } else if let warning = viewModel.imageAnalysisVM.lightingWarning {
                // Lighting warning
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.yellow)

                Text("Lighting Issue")
                    .font(.title3.bold())

                Text(warning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button("Continue Anyway") {
                    viewModel.imageAnalysisVM.proceedDespiteLighting()
                }
                .buttonStyle(.borderedProminent)

                Button("Retake Photos") {
                    viewModel.imageAnalysisVM.retakePhotos()
                    viewModel.goToStep(.capture)
                }
                .foregroundStyle(.secondary)
            } else {
                // Loading state
                ProgressView()
                    .scaleEffect(1.5)

                Text(viewModel.imageAnalysisVM.progressMessage.isEmpty
                     ? "Analyzing your features..."
                     : viewModel.imageAnalysisVM.progressMessage)
                    .font(.headline)

                Text("This takes a few seconds")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            viewModel.startImageAnalysis()
        }
        .onChange(of: viewModel.imageAnalysisVM.flowState) { _, newState in
            if newState == .reviewingDetails {
                viewModel.goToStep(.reviewingDetails)
            }
        }
    }
}
