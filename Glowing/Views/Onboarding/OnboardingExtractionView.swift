import SwiftUI

/// Shows progress while LLM extracts traits from photos, then auto-advances.
struct OnboardingExtractionView: View {
    @Bindable var viewModel: OnboardingViewModel
    @State private var showSkip = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let error = viewModel.imageAnalysisVM.error {
                errorState(error)
            } else if let warning = viewModel.imageAnalysisVM.lightingWarning {
                lightingWarningState(warning)
            } else {
                analyzingState
            }

            Spacer()

            // Gentle skip option — appears after a brief pause
            if showSkip && viewModel.imageAnalysisVM.error == nil && viewModel.imageAnalysisVM.lightingWarning == nil {
                Button {
                    PendingAnalysisManager.shared.handOff(
                        vm: viewModel.imageAnalysisVM,
                        photos: viewModel.capturedPhotos
                    )
                    viewModel.goToStep(.complete)
                } label: {
                    Text("We'll notify you when it's ready")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
                .padding(.bottom, 40)
                .transition(.opacity)
            }
        }
        .onAppear {
            viewModel.startImageAnalysis()
            // Reveal skip after a calm pause so it doesn't compete with the loading state
            Task {
                try? await Task.sleep(for: .seconds(3))
                withAnimation(.easeIn(duration: 0.4)) { showSkip = true }
            }
        }
        .onChange(of: viewModel.imageAnalysisVM.flowState) { _, newState in
            if newState == .reviewingDetails {
                viewModel.goToStep(.reviewingDetails)
            }
        }
    }

    // MARK: - Analyzing

    private var analyzingState: some View {
        VStack(spacing: 20) {
            Image(systemName: "sparkle")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse.wholeSymbol, options: .repeating)

            VStack(spacing: 8) {
                Text("Reading your features")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("Sit tight — this only takes a moment.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
    }

    // MARK: - Error

    private func errorState(_ error: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.trianglehead.2.counterclockwise")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Button {
                Task { await viewModel.imageAnalysisVM.extractDetails() }
            } label: {
                Text("Try Again")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    // MARK: - Lighting Warning

    private func lightingWarningState(_ warning: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "sun.max.trianglebadge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Lighting could be better")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(warning)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            VStack(spacing: 12) {
                Button {
                    viewModel.imageAnalysisVM.proceedDespiteLighting()
                } label: {
                    Text("Continue Anyway")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    viewModel.imageAnalysisVM.retakePhotos()
                    viewModel.goToStep(.capture)
                } label: {
                    Text("Retake Photos")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 40)
            .padding(.top, 4)
        }
    }
}
