import SwiftUI

/// Wraps ClarificationView for the onboarding flow, auto-advancing when done.
struct OnboardingClarificationView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        Group {
            if let question = viewModel.imageAnalysisVM.currentQuestion {
                ClarificationView(
                    question: question,
                    currentIndex: viewModel.imageAnalysisVM.currentQuestionIndex,
                    totalCount: viewModel.imageAnalysisVM.clarificationQuestions.count,
                    onAnswer: { value in
                        viewModel.imageAnalysisVM.submitClarificationAnswer(value)
                    },
                    onSkip: {
                        viewModel.imageAnalysisVM.skipRemainingQuestions()
                    }
                )
            } else {
                // All questions answered, waiting for transition
                ProgressView()
            }
        }
        .onChange(of: viewModel.imageAnalysisVM.flowState) { _, newState in
            if newState == .generatingRoutines {
                viewModel.goToStep(.generatingRoutines)
            }
        }
    }
}
