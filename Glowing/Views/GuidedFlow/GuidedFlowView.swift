import SwiftUI
import SwiftData

struct GuidedFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var logs: [RoutineLog]
    @State private var viewModel: GuidedFlowViewModel
    @State private var showCompletion = false


    /// Single routine
    init(routine: Routine) {
        _viewModel = State(initialValue: GuidedFlowViewModel(routine: routine))
    }

    /// Multiple routines (combined flow)
    init(routines: [Routine]) {
        _viewModel = State(initialValue: GuidedFlowViewModel(routines: routines))
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    viewModel.currentCategory.color.opacity(0.5),
                    viewModel.currentCategory.color.opacity(0.15),
                    Color(.systemBackground)
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: viewModel.currentCategory)

            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.horizontal)
                    .padding(.top, 8)

                // Step dots
                stepDots
                    .padding(.top, 12)
                    .padding(.horizontal)

                // Step content — fills available space
                stepContent
                    .frame(maxHeight: .infinity)

                // Fixed bottom area: timer + button
                bottomControls
            }

            // Completion overlay
            if showCompletion {
                completionOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
            }
        }
        .onAppear {
            viewModel.startRoutine()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(viewModel.currentRoutineName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Text("Step \(viewModel.currentStepIndex + 1) of \(viewModel.totalSteps)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            // Invisible spacer for symmetry
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .opacity(0)
        }
    }

    // MARK: - Step Dots

    private var stepDots: some View {
        HStack(spacing: 4) {
            ForEach(0..<viewModel.totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= viewModel.currentStepIndex
                          ? viewModel.currentCategory.accentColor
                          : viewModel.currentCategory.accentColor.opacity(0.2))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.3), value: viewModel.currentStepIndex)
            }
        }
    }

    // MARK: - Step Content

    private var stepContent: some View {
        Group {
            if let step = viewModel.currentResolvedStep {
                if step.isTransition {
                    transitionCard(step: step)
                } else {
                    StepCardView(
                        step: step,
                        stepNumber: viewModel.currentStepIndex + 1,
                        totalSteps: viewModel.totalSteps,
                        accentColor: viewModel.currentCategory.accentColor
                    )
                }
            }
        }
        .id(viewModel.currentStepIndex)
        .transition(.push(from: .trailing))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: viewModel.currentStepIndex)
        .padding(.vertical, 16)
    }

    private func transitionCard(step: ResolvedStep) -> some View {
        VStack(spacing: 24) {
            // Completed checkmark for previous routine
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(.green)

            VStack(spacing: 8) {
                Text("Up Next")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(1.2)

                Text(step.productName ?? "")
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.horizontal, 20)
    }

    // MARK: - Bottom Controls (fixed position)

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Timer
            Group {
                if viewModel.timerTotalSeconds > 0 {
                    CountdownTimerView(
                        secondsRemaining: viewModel.timerSecondsRemaining,
                        totalSeconds: viewModel.timerTotalSeconds,
                        isRunning: viewModel.timerIsRunning,
                        accentColor: viewModel.currentCategory.accentColor
                    )
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: viewModel.timerTotalSeconds > 0)

            // Next / Finish button
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    viewModel.advance()
                }
                if viewModel.isComplete {
                    viewModel.finishAndLog(modelContext: modelContext)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        showCompletion = true
                    }
                }
            } label: {
                Text(buttonLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.currentCategory.accentColor)
            .sensoryFeedback(.impact(flexibility: .solid), trigger: viewModel.currentStepIndex)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private var buttonLabel: String {
        if viewModel.isLastStep {
            return "Finish"
        } else if viewModel.currentResolvedStep?.isTransition == true {
            return "Continue"
        } else {
            return "Next"
        }
    }

    // MARK: - Completion Overlay

    private var completionOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            VStack(spacing: 24) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)

                VStack(spacing: 8) {
                    if viewModel.routines.count > 1 {
                        Text("All Done!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("\(viewModel.routines.count) routines completed")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Routine Complete!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text(viewModel.routines.first?.name ?? "")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // Streak info
                streakInfo

                Button {
                    dismiss()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            .padding(32)
            .background(.ultraThickMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 28))
            .padding(.horizontal, 32)
            .sensoryFeedback(.success, trigger: showCompletion)
        }
    }

    private var streakInfo: some View {
        VStack(spacing: 8) {
            ForEach(viewModel.routines) { routine in
                let streak = StreakCalculator.currentStreak(for: routine, logs: logs)
                if streak > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                        Text("\(routine.name): \(streak) day streak")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
