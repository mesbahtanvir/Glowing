import Foundation
import SwiftData

@Model
final class RoutineLog {
    var routine: Routine?
    var completedAt: Date
    var stepsCompleted: Int
    var totalSteps: Int

    var isFullyCompleted: Bool {
        stepsCompleted == totalSteps
    }

    init(routine: Routine, completedAt: Date = Date(), stepsCompleted: Int, totalSteps: Int) {
        self.routine = routine
        self.completedAt = completedAt
        self.stepsCompleted = stepsCompleted
        self.totalSteps = totalSteps
    }
}
