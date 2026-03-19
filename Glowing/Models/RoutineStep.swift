import Foundation
import SwiftData

@Model
final class RoutineStep {
    var order: Int
    var title: String
    var productName: String?
    var notes: String?
    @Attribute(.externalStorage) var imageData: Data?
    var timerDuration: Int?
    @Relationship(deleteRule: .cascade) var dayVariants: [StepDayVariant]

    /// Returns the resolved product name for a given weekday (1=Sun, 7=Sat)
    func resolvedProductName(for weekday: Int) -> String? {
        if let variant = dayVariants.first(where: { $0.weekday == weekday }) {
            return variant.productName ?? productName
        }
        return productName
    }

    /// Returns the resolved notes for a given weekday
    func resolvedNotes(for weekday: Int) -> String? {
        if let variant = dayVariants.first(where: { $0.weekday == weekday }) {
            return variant.notes ?? notes
        }
        return notes
    }

    /// Returns whether this step should be skipped on the given weekday
    func isSkipped(on weekday: Int) -> Bool {
        dayVariants.first(where: { $0.weekday == weekday })?.skip ?? false
    }

    /// Returns true if this step has any day-specific variants configured
    var hasDayVariants: Bool {
        !dayVariants.isEmpty
    }

    init(order: Int, title: String, productName: String? = nil, notes: String? = nil, imageData: Data? = nil, timerDuration: Int? = nil) {
        self.order = order
        self.title = title
        self.productName = productName
        self.notes = notes
        self.imageData = imageData
        self.timerDuration = timerDuration
        self.dayVariants = []
    }
}
