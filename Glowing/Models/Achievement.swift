import Foundation

enum AchievementType: String, CaseIterable, Codable, Identifiable {
    case firstRoutine
    case sevenDayStreak
    case thirtyDayStreak
    case hundredDayStreak
    case firstCheckIn
    case fourWeekCheckIn
    case twelveWeekCheckIn
    case firstImprovement
    case fivePointGain
    case tenPointGain
    case perfectWeek

    var id: String { rawValue }

    var name: String {
        switch self {
        case .firstRoutine: "First Steps"
        case .sevenDayStreak: "One Week"
        case .thirtyDayStreak: "Dedicated"
        case .hundredDayStreak: "Unstoppable"
        case .firstCheckIn: "Snapshot"
        case .fourWeekCheckIn: "Month of Progress"
        case .twelveWeekCheckIn: "Quarter Hero"
        case .firstImprovement: "Getting Better"
        case .fivePointGain: "Leveling Up"
        case .tenPointGain: "Transformation"
        case .perfectWeek: "Perfect Week"
        }
    }

    var description: String {
        switch self {
        case .firstRoutine: "Complete your first routine"
        case .sevenDayStreak: "Maintain a 7-day streak"
        case .thirtyDayStreak: "Maintain a 30-day streak"
        case .hundredDayStreak: "Maintain a 100-day streak"
        case .firstCheckIn: "Take your first progress photos"
        case .fourWeekCheckIn: "4 consecutive weekly check-ins"
        case .twelveWeekCheckIn: "12 consecutive weekly check-ins"
        case .firstImprovement: "Improve your skin score"
        case .fivePointGain: "Improve your skin score by 5+ points"
        case .tenPointGain: "Improve your skin score by 10+ points"
        case .perfectWeek: "Complete all routines for 7 consecutive days"
        }
    }

    var icon: String {
        switch self {
        case .firstRoutine: "star.fill"
        case .sevenDayStreak: "flame.fill"
        case .thirtyDayStreak: "flame.fill"
        case .hundredDayStreak: "flame.fill"
        case .firstCheckIn: "camera.fill"
        case .fourWeekCheckIn: "camera.viewfinder"
        case .twelveWeekCheckIn: "trophy.fill"
        case .firstImprovement: "arrow.up.circle.fill"
        case .fivePointGain: "chart.line.uptrend.xyaxis"
        case .tenPointGain: "sparkles"
        case .perfectWeek: "checkmark.seal.fill"
        }
    }

    var sortOrder: Int {
        switch self {
        case .firstRoutine: 0
        case .sevenDayStreak: 1
        case .thirtyDayStreak: 2
        case .hundredDayStreak: 3
        case .perfectWeek: 4
        case .firstCheckIn: 5
        case .fourWeekCheckIn: 6
        case .twelveWeekCheckIn: 7
        case .firstImprovement: 8
        case .fivePointGain: 9
        case .tenPointGain: 10
        }
    }
}
