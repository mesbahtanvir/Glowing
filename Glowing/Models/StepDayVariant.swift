import Foundation
import SwiftData

/// Represents a day-specific override for a routine step.
/// When a step has day variants, the guided flow checks today's weekday
/// and uses the variant's values instead of the step's defaults.
@Model
final class StepDayVariant {
    /// Weekday number using Calendar convention: 1=Sunday, 2=Monday, ... 7=Saturday
    var weekday: Int
    /// Override product name for this day (nil = use step's default)
    var productName: String?
    /// Override notes for this day (nil = use step's default)
    var notes: String?
    /// If true, skip this step entirely on this day
    var skip: Bool

    init(weekday: Int, productName: String? = nil, notes: String? = nil, skip: Bool = false) {
        self.weekday = weekday
        self.productName = productName
        self.notes = notes
        self.skip = skip
    }

    /// Human-readable weekday name
    static func weekdayName(for weekday: Int) -> String {
        let names = ["", "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        guard weekday >= 1 && weekday <= 7 else { return "?" }
        return names[weekday]
    }

    static func fullWeekdayName(for weekday: Int) -> String {
        let names = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        guard weekday >= 1 && weekday <= 7 else { return "?" }
        return names[weekday]
    }
}
