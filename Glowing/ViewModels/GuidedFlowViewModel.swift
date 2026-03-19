import Foundation
import SwiftData

/// A resolved snapshot of a step for a specific day, with day-variant overrides applied.
struct ResolvedStep: Identifiable {
    let id = UUID()
    let routineName: String
    let title: String
    let productName: String?
    let notes: String?
    let imageData: Data?
    let timerDuration: Int?
    let isTransition: Bool

    init(from step: RoutineStep, routineName: String, weekday: Int) {
        self.routineName = routineName
        self.title = step.title
        self.productName = step.resolvedProductName(for: weekday)
        self.notes = step.resolvedNotes(for: weekday)
        self.imageData = step.imageData
        self.timerDuration = step.timerDuration
        self.isTransition = false
    }

    /// Creates a transition card between routines
    init(transitionTo routineName: String) {
        self.routineName = routineName
        self.title = "Up Next"
        self.productName = routineName
        self.notes = "Tap Next to continue"
        self.imageData = nil
        self.timerDuration = nil
        self.isTransition = true
    }
}

/// Tracks which routine each step range belongs to, for logging.
struct RoutineSegment {
    let routine: Routine
    let stepCount: Int
}

@Observable
final class GuidedFlowViewModel {
    let routines: [Routine]
    private(set) var segments: [RoutineSegment] = []
    private(set) var resolvedSteps: [ResolvedStep] = []

    private(set) var currentStepIndex: Int = 0
    private(set) var isComplete: Bool = false
    private(set) var timerSecondsRemaining: Int = 0
    private(set) var timerTotalSeconds: Int = 0
    private(set) var timerIsRunning: Bool = false

    var currentResolvedStep: ResolvedStep? {
        guard currentStepIndex < resolvedSteps.count else { return nil }
        return resolvedSteps[currentStepIndex]
    }

    /// Current routine's category (for theming)
    var currentCategory: Category {
        guard let step = currentResolvedStep else {
            return routines.first?.category ?? .face
        }
        // Find which routine this step belongs to
        for routine in routines where routine.name == step.routineName {
            return routine.category
        }
        return routines.first?.category ?? .face
    }

    var totalSteps: Int { resolvedSteps.count }
    var progress: Double {
        guard totalSteps > 0 else { return 0 }
        return Double(currentStepIndex) / Double(totalSteps)
    }

    var isLastStep: Bool {
        currentStepIndex >= resolvedSteps.count - 1
    }

    /// The name of the current routine being performed
    var currentRoutineName: String {
        currentResolvedStep?.routineName ?? routines.first?.name ?? ""
    }

    private var timerTask: Task<Void, Never>?

    /// Initialize with a single routine
    init(routine: Routine) {
        self.routines = [routine]
    }

    /// Initialize with multiple routines (combined flow)
    init(routines: [Routine]) {
        self.routines = routines
    }

    func startRoutine() {
        let weekday = Calendar.current.component(.weekday, from: Date())
        var allSteps: [ResolvedStep] = []
        var allSegments: [RoutineSegment] = []

        // Sort by category priority: body → hair → stubble → face → dental → fragrance
        let sortedRoutines = routines.sorted {
            if $0.category.sortOrder != $1.category.sortOrder {
                return $0.category.sortOrder < $1.category.sortOrder
            }
            return $0.displayOrder < $1.displayOrder
        }

        for (routineIndex, routine) in sortedRoutines.enumerated() {
            let steps = routine.sortedSteps
                .filter { !$0.isSkipped(on: weekday) }
                .map { ResolvedStep(from: $0, routineName: routine.name, weekday: weekday) }

            guard !steps.isEmpty else { continue }

            // Add transition card between routines (not before the first)
            if routineIndex > 0 && !allSteps.isEmpty {
                allSteps.append(ResolvedStep(transitionTo: routine.name))
            }

            allSteps.append(contentsOf: steps)
            allSegments.append(RoutineSegment(routine: routine, stepCount: steps.count))
        }

        resolvedSteps = allSteps
        segments = allSegments
        currentStepIndex = 0
        isComplete = resolvedSteps.isEmpty
        if !isComplete {
            startCurrentStepTimer()
        }
    }

    func advance() {
        cancelTimer()

        if currentStepIndex < resolvedSteps.count - 1 {
            currentStepIndex += 1
            startCurrentStepTimer()
        } else {
            isComplete = true
        }
    }

    func finishAndLog(modelContext: ModelContext) {
        for segment in segments {
            let log = RoutineLog(
                routine: segment.routine,
                stepsCompleted: segment.stepCount,
                totalSteps: segment.stepCount
            )
            modelContext.insert(log)
        }
    }

    private func startCurrentStepTimer() {
        cancelTimer()
        guard let step = currentResolvedStep,
              !step.isTransition,
              let duration = step.timerDuration,
              duration > 0 else { return }

        timerTotalSeconds = duration
        timerSecondsRemaining = duration
        timerIsRunning = true

        timerTask = Task { @MainActor [weak self] in
            while let self, self.timerSecondsRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self.timerSecondsRemaining -= 1
            }
            guard let self, !Task.isCancelled else { return }
            self.timerIsRunning = false
        }
    }

    private func cancelTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerIsRunning = false
        timerSecondsRemaining = 0
        timerTotalSeconds = 0
    }
}
