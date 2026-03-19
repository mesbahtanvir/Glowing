import Foundation
import SwiftUI
import SwiftData

enum Category: String, CaseIterable, Codable {
    case face
    case hair
    case stubble

    var displayName: String {
        switch self {
        case .face: "Face"
        case .hair: "Hair"
        case .stubble: "Stubble"
        }
    }

    var defaultIcon: String {
        switch self {
        case .face: "face.smiling"
        case .hair: "scissors"
        case .stubble: "line.3.horizontal"
        }
    }

    var color: Color {
        switch self {
        case .face: Color(red: 0.98, green: 0.86, blue: 0.90)
        case .hair: Color(red: 0.87, green: 0.82, blue: 0.98)
        case .stubble: Color(red: 0.94, green: 0.90, blue: 0.84)
        }
    }

    var accentColor: Color {
        switch self {
        case .face: Color(red: 0.90, green: 0.40, blue: 0.55)
        case .hair: Color(red: 0.55, green: 0.40, blue: 0.80)
        case .stubble: Color(red: 0.60, green: 0.48, blue: 0.35)
        }
    }

    /// Face (primary) → Hair → Stubble
    var sortOrder: Int {
        switch self {
        case .face: 0
        case .hair: 1
        case .stubble: 2
        }
    }
}

enum TimeOfDay: String, CaseIterable, Codable {
    case morning
    case evening
    case weekly

    var displayName: String {
        switch self {
        case .morning: "Morning"
        case .evening: "Evening"
        case .weekly: "Weekly"
        }
    }

    var sortOrder: Int {
        switch self {
        case .morning: 0
        case .evening: 1
        case .weekly: 2
        }
    }

    var icon: String {
        switch self {
        case .morning: "sunrise.fill"
        case .evening: "moon.fill"
        case .weekly: "calendar"
        }
    }

    var defaultNotificationHour: Int {
        switch self {
        case .morning: 7
        case .evening: 20
        case .weekly: 10
        }
    }
}

@Model
final class Routine {
    var name: String
    var categoryRaw: String
    var timeOfDayRaw: String
    var seasonRaw: String = Season.yearRound.rawValue
    var scheduledWeekdaysRaw: String = ""  // comma-separated weekday ints, empty = every day
    var displayOrder: Int = 0   // ordering within the same category + timeOfDay
    var icon: String
    var createdAt: Date
    @Relationship(deleteRule: .cascade) var steps: [RoutineStep]

    var category: Category {
        get { Category(rawValue: categoryRaw) ?? .face }
        set { categoryRaw = newValue.rawValue }
    }

    var timeOfDay: TimeOfDay {
        get { TimeOfDay(rawValue: timeOfDayRaw) ?? .morning }
        set { timeOfDayRaw = newValue.rawValue }
    }

    var season: Season {
        get { Season(rawValue: seasonRaw) ?? .yearRound }
        set { seasonRaw = newValue.rawValue }
    }

    /// Days this routine is scheduled (1=Sun ... 7=Sat). Empty means every day.
    var scheduledWeekdays: Set<Int> {
        get {
            guard !scheduledWeekdaysRaw.isEmpty else { return [] }
            return Set(scheduledWeekdaysRaw.split(separator: ",").compactMap { Int($0) })
        }
        set {
            if newValue.isEmpty {
                scheduledWeekdaysRaw = ""
            } else {
                scheduledWeekdaysRaw = newValue.sorted().map(String.init).joined(separator: ",")
            }
        }
    }

    var sortedSteps: [RoutineStep] {
        steps.sorted { $0.order < $1.order }
    }

    /// Whether this routine should appear today based on season and weekday
    func isScheduledToday(on date: Date = Date()) -> Bool {
        let calendar = Calendar.current

        // Check season
        if season != .yearRound && !season.isCurrent(on: date) {
            return false
        }

        // Check weekday (empty set = every day)
        if !scheduledWeekdays.isEmpty {
            let todayWeekday = calendar.component(.weekday, from: date)
            if !scheduledWeekdays.contains(todayWeekday) {
                return false
            }
        }

        return true
    }

    init(name: String, category: Category, timeOfDay: TimeOfDay, season: Season = .yearRound, scheduledWeekdays: Set<Int> = [], displayOrder: Int = 0, icon: String, createdAt: Date = Date()) {
        self.name = name
        self.categoryRaw = category.rawValue
        self.timeOfDayRaw = timeOfDay.rawValue
        self.seasonRaw = season.rawValue
        self.displayOrder = displayOrder
        self.icon = icon
        self.createdAt = createdAt
        self.steps = []
        self.scheduledWeekdays = scheduledWeekdays
    }
}
