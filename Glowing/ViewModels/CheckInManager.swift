import Foundation
import SwiftData

@MainActor
@Observable
final class CheckInManager {
    static let shared = CheckInManager()

    private static let checkInIntervalDays = 7

    private init() {}

    // MARK: - Check-In Status

    /// Compute the last check-in date from a set of photo sessions
    func lastCheckInDate(photos: [ProgressPhoto]) -> Date? {
        // Only face sessions count as check-ins (need at least front + left + right)
        let grouped = Dictionary(grouping: photos) { $0.sessionID }
        let faceSessions = grouped.filter { (_, sessionPhotos) in
            sessionPhotos.count >= 3
        }

        return faceSessions
            .map { $0.value.map(\.capturedAt).max() ?? Date.distantPast }
            .max()
    }

    /// Whether a check-in is due (more than 7 days since the last 3-angle face session)
    func isDueForCheckIn(photos: [ProgressPhoto]) -> Bool {
        guard let lastDate = lastCheckInDate(photos: photos) else {
            return true
        }
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
        return daysSince >= Self.checkInIntervalDays
    }

    /// Days since last check-in
    func daysSinceLastCheckIn(photos: [ProgressPhoto]) -> Int {
        guard let lastDate = lastCheckInDate(photos: photos) else {
            return 0
        }
        return Calendar.current.dateComponents([.day], from: lastDate, to: Date()).day ?? 0
    }

    /// Weekly photo check-in streak (consecutive weeks with a 3-angle face session)
    func weeklyCheckInStreak(photos: [ProgressPhoto]) -> Int {
        let grouped = Dictionary(grouping: photos) { $0.sessionID }
        let faceSessions = grouped.filter { (_, sessionPhotos) in
            sessionPhotos.count >= 3
        }

        // Get the date of each qualifying session
        let sessionDates = faceSessions
            .map { $0.value.map(\.capturedAt).max() ?? Date.distantPast }
            .sorted(by: >)

        guard !sessionDates.isEmpty else { return 0 }

        let calendar = Calendar.current
        var streak = 1
        var currentWeek = calendar.component(.weekOfYear, from: sessionDates[0])
        var currentYear = calendar.component(.yearForWeekOfYear, from: sessionDates[0])

        for date in sessionDates.dropFirst() {
            let week = calendar.component(.weekOfYear, from: date)
            let year = calendar.component(.yearForWeekOfYear, from: date)

            // Same week — skip
            if week == currentWeek && year == currentYear { continue }

            // Previous week — streak continues
            let daysBetween = calendar.dateComponents([.day], from: date, to: calendar.date(from: DateComponents(weekOfYear: currentWeek, yearForWeekOfYear: currentYear))!).day ?? 0
            if daysBetween <= 14 {
                streak += 1
                currentWeek = week
                currentYear = year
            } else {
                break
            }
        }

        return streak
    }
}
