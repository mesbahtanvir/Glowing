import Foundation
import SwiftUI

@MainActor
@Observable
final class AchievementManager {
    static let shared = AchievementManager()

    private static let storageKey = "unlockedAchievements"

    var unlockedAchievements: Set<String> {
        didSet {
            let array = Array(unlockedAchievements)
            UserDefaults.standard.set(array, forKey: Self.storageKey)
        }
    }

    var pendingUnlock: AchievementType?

    private init() {
        let stored = UserDefaults.standard.stringArray(forKey: Self.storageKey) ?? []
        unlockedAchievements = Set(stored)
    }

    func isUnlocked(_ achievement: AchievementType) -> Bool {
        unlockedAchievements.contains(achievement.rawValue)
    }

    /// Check all conditions and return any newly unlocked achievements
    func checkForNewAchievements(
        logs: [RoutineLog],
        routines: [Routine],
        photos: [ProgressPhoto],
        analyses: [SkinAnalysis]
    ) -> [AchievementType] {
        var newlyUnlocked: [AchievementType] = []

        func unlock(_ type: AchievementType) {
            guard !isUnlocked(type) else { return }
            unlockedAchievements.insert(type.rawValue)
            newlyUnlocked.append(type)
        }

        let completedLogs = logs.filter { $0.isFullyCompleted }
        let dailyStreak = StreakCalculator.currentDailyStreak(logs: logs, routines: routines)
        let checkInStreak = CheckInManager.shared.weeklyCheckInStreak(photos: photos)

        // Routine achievements
        if !completedLogs.isEmpty {
            unlock(.firstRoutine)
        }

        // Streak achievements
        if dailyStreak >= 7 {
            unlock(.sevenDayStreak)
        }
        if dailyStreak >= 30 {
            unlock(.thirtyDayStreak)
        }
        if dailyStreak >= 100 {
            unlock(.hundredDayStreak)
        }

        // Perfect week: all routines completed every day for 7 days
        if dailyStreak >= 7 {
            // Simplified: if you have a 7-day streak, you've had a perfect week
            unlock(.perfectWeek)
        }

        // Photo check-in achievements
        let faceSessions = Dictionary(grouping: photos) { $0.sessionID }
            .filter { $0.value.count >= 3 }
        if !faceSessions.isEmpty {
            unlock(.firstCheckIn)
        }

        if checkInStreak >= 4 {
            unlock(.fourWeekCheckIn)
        }
        if checkInStreak >= 12 {
            unlock(.twelveWeekCheckIn)
        }

        // Score improvement achievements
        let sortedAnalyses = analyses
            .filter { $0.overallScore > 0 }
            .sorted { $0.analyzedAt < $1.analyzedAt }

        if sortedAnalyses.count >= 2 {
            let first = sortedAnalyses.first!.overallScore
            let latest = sortedAnalyses.last!.overallScore
            let improvement = latest - first

            if improvement > 0 {
                unlock(.firstImprovement)
            }
            if improvement >= 5 {
                unlock(.fivePointGain)
            }
            if improvement >= 10 {
                unlock(.tenPointGain)
            }
        }

        return newlyUnlocked
    }
}
