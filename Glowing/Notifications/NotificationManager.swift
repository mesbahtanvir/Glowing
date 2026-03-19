import Foundation
import UserNotifications
import SwiftUI

@Observable
final class NotificationManager {
    static let shared = NotificationManager()

    @ObservationIgnored
    @AppStorage("notif_morning_enabled") private var morningEnabled = false
    @ObservationIgnored
    @AppStorage("notif_evening_enabled") private var eveningEnabled = false
    @ObservationIgnored
    @AppStorage("notif_weekly_enabled") private var weeklyEnabled = false
    @ObservationIgnored
    @AppStorage("notif_checkin_enabled") private var checkInEnabled = false
    @ObservationIgnored
    @AppStorage("notif_checkin_weekday") private var checkInWeekday = 1 // Sunday

    @ObservationIgnored
    @AppStorage("notif_morning_hour") private var morningHour = 7
    @ObservationIgnored
    @AppStorage("notif_morning_minute") private var morningMinute = 0
    @ObservationIgnored
    @AppStorage("notif_evening_hour") private var eveningHour = 20
    @ObservationIgnored
    @AppStorage("notif_evening_minute") private var eveningMinute = 0
    @ObservationIgnored
    @AppStorage("notif_weekly_hour") private var weeklyHour = 10
    @ObservationIgnored
    @AppStorage("notif_weekly_minute") private var weeklyMinute = 0

    private init() {}

    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func isEnabled(for timeOfDay: TimeOfDay) -> Bool {
        switch timeOfDay {
        case .morning: morningEnabled
        case .evening: eveningEnabled
        case .weekly: weeklyEnabled
        }
    }

    func setEnabled(_ enabled: Bool, for timeOfDay: TimeOfDay) {
        switch timeOfDay {
        case .morning: morningEnabled = enabled
        case .evening: eveningEnabled = enabled
        case .weekly: weeklyEnabled = enabled
        }
    }

    func reminderTime(for timeOfDay: TimeOfDay) -> Date {
        let calendar = Calendar.current
        var components = DateComponents()
        switch timeOfDay {
        case .morning:
            components.hour = morningHour
            components.minute = morningMinute
        case .evening:
            components.hour = eveningHour
            components.minute = eveningMinute
        case .weekly:
            components.hour = weeklyHour
            components.minute = weeklyMinute
        }
        return calendar.date(from: components) ?? Date()
    }

    func setReminderTime(_ date: Date, for timeOfDay: TimeOfDay) {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)

        switch timeOfDay {
        case .morning:
            morningHour = hour
            morningMinute = minute
        case .evening:
            eveningHour = hour
            eveningMinute = minute
        case .weekly:
            weeklyHour = hour
            weeklyMinute = minute
        }
    }

    func scheduleReminder(for timeOfDay: TimeOfDay) {
        let center = UNUserNotificationCenter.current()
        let identifier = "reminder-\(timeOfDay.rawValue)"

        // Remove existing
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard isEnabled(for: timeOfDay) else { return }

        let content = UNMutableNotificationContent()
        content.title = "Glowing"
        content.body = "Time for your \(timeOfDay.displayName.lowercased()) routine!"
        content.sound = .default

        var dateComponents = DateComponents()
        let time = reminderTime(for: timeOfDay)
        let calendar = Calendar.current
        dateComponents.hour = calendar.component(.hour, from: time)
        dateComponents.minute = calendar.component(.minute, from: time)

        if timeOfDay == .weekly {
            dateComponents.weekday = 1 // Sunday
        }

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelReminder(for timeOfDay: TimeOfDay) {
        let identifier = "reminder-\(timeOfDay.rawValue)"
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    // MARK: - Check-In Notifications

    var isCheckInEnabled: Bool {
        get { checkInEnabled }
        set { checkInEnabled = newValue }
    }

    var checkInDay: Int {
        get { checkInWeekday }
        set { checkInWeekday = newValue }
    }

    func scheduleCheckInReminder() {
        let center = UNUserNotificationCenter.current()
        let identifier = "reminder-checkin"

        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        guard checkInEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Check-In"
        content.body = "Time for your weekly skin progress photos! Consistent tracking shows real results."
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.weekday = checkInWeekday
        dateComponents.hour = 10
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        center.add(request)
    }

    func cancelCheckInReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["reminder-checkin"])
        center.removeDeliveredNotifications(withIdentifiers: ["reminder-checkin"])
    }
}
