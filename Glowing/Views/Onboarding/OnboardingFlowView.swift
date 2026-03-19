import SwiftUI
import SwiftData

struct OnboardingFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Progress dots
                if viewModel.currentStep != .complete {
                    progressDots
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                }

                // Current step
                Group {
                    switch viewModel.currentStep {
                    case .welcome:
                        WelcomeStepView(viewModel: viewModel)
                    case .capture:
                        OnboardingCaptureView(viewModel: viewModel)
                    case .analyzing:
                        OnboardingAnalysisView(viewModel: viewModel)
                    case .extractingDetails:
                        OnboardingExtractionView(viewModel: viewModel)
                    case .reviewingDetails:
                        if let profile = viewModel.imageAnalysisVM.profile {
                            ExtractedDetailsView(
                                profile: profile,
                                hasClarifications: !viewModel.imageAnalysisVM.clarificationQuestions.isEmpty,
                                onProceed: {
                                    viewModel.imageAnalysisVM.proceedFromReview()
                                    if viewModel.imageAnalysisVM.clarificationQuestions.isEmpty {
                                        viewModel.goToStep(.generatingRoutines)
                                    } else {
                                        viewModel.goToStep(.clarifying)
                                    }
                                },
                                onOverride: { trait, value in
                                    viewModel.imageAnalysisVM.overrideTrait(trait, value: value)
                                }
                            )
                        }
                    case .clarifying:
                        OnboardingClarificationView(viewModel: viewModel)
                    case .generatingRoutines:
                        OnboardingRoutineGenerationView(viewModel: viewModel)
                    case .suggestedRoutine:
                        SuggestedRoutineView(viewModel: viewModel, modelContext: modelContext)
                    case .complete:
                        EmptyView()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }

    // Map logical flow stages (not raw step indices) to progress dots
    private static let progressStages: [OnboardingStep] = [
        .welcome, .capture, .extractingDetails, .reviewingDetails, .suggestedRoutine
    ]

    private var progressDots: some View {
        let stages = Self.progressStages
        let currentStageIndex = stages.firstIndex(where: { $0.rawValue >= viewModel.currentStep.rawValue }) ?? stages.count - 1

        return HStack(spacing: 8) {
            ForEach(0..<stages.count, id: \.self) { index in
                let isActive = index == currentStageIndex
                let isDone = index < currentStageIndex
                Capsule()
                    .fill(isDone ? Color.accentColor : (isActive ? Color.accentColor : Color(.systemGray4)))
                    .frame(width: isActive ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }
}
