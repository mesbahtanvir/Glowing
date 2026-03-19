import Foundation
import SwiftData

struct StreakCalculator {
    static func currentStreak(for routine: Routine, logs: [RoutineLog]) -> Int {
        let calendar = Calendar.current
        let routineLogs = logs
            .filter { $0.routine?.persistentModelID == routine.persistentModelID && $0.isFullyCompleted }
            .sorted { $0.completedAt > $1.completedAt }

        guard !routineLogs.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if there's a completion today
        let hasToday = routineLogs.contains { calendar.isDate($0.completedAt, inSameDayAs: checkDate) }

        if !hasToday {
            // Check yesterday — streak might still be alive
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let dayHasCompletion = routineLogs.contains { calendar.isDate($0.completedAt, inSameDayAs: checkDate) }
            if dayHasCompletion {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    static func currentDailyStreak(logs: [RoutineLog], routines: [Routine]) -> Int {
        let calendar = Calendar.current
        guard !routines.isEmpty else { return 0 }

        var streak = 0
        var checkDate = calendar.startOfDay(for: Date())

        // Check if all routines are completed today
        let allDoneToday = routines.allSatisfy { routine in
            logs.contains { $0.routine?.persistentModelID == routine.persistentModelID && $0.isFullyCompleted && calendar.isDate($0.completedAt, inSameDayAs: checkDate) }
        }

        if !allDoneToday {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: checkDate) else { return 0 }
            checkDate = yesterday
        }

        while true {
            let finalCheckDate = checkDate
            let allDone = routines.allSatisfy { routine in
                logs.contains { $0.routine?.persistentModelID == routine.persistentModelID && $0.isFullyCompleted && calendar.isDate($0.completedAt, inSameDayAs: finalCheckDate) }
            }

            if allDone {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                checkDate = previousDay
            } else {
                break
            }
        }

        return streak
    }

    static func completionDates(for routine: Routine, logs: [RoutineLog]) -> Set<DateComponents> {
        let calendar = Calendar.current
        let dates = logs
            .filter { $0.routine?.persistentModelID == routine.persistentModelID && $0.isFullyCompleted }
            .map { calendar.dateComponents([.year, .month, .day], from: $0.completedAt) }
        return Set(dates)
    }
}
