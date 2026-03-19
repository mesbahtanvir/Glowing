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
                    case .suggestedRoutine:
                        SuggestedRoutineView(viewModel: viewModel, modelContext: modelContext)
                    case .complete:
                        EmptyView()
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                ))
            }
        }
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<4, id: \.self) { index in
                let isActive = index == viewModel.currentStep.rawValue
                let isDone = index < viewModel.currentStep.rawValue
                Capsule()
                    .fill(isDone ? Color.accentColor : (isActive ? Color.accentColor : Color(.systemGray4)))
                    .frame(width: isActive ? 24 : 8, height: 8)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.currentStep)
    }
}
