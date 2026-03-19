import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var manager = NotificationManager.shared
    @State private var systemDenied = false

    var body: some View {
        Form {
            if systemDenied {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Notifications Disabled")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("Enable notifications in system Settings for reminders to work.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            UIApplication.shared.open(url)
                        }
                    }
                }
            }

            Section {
                Text("Get reminded when it's time for your routines.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            ForEach(TimeOfDay.allCases, id: \.self) { timeOfDay in
                Section {
                    Toggle(
                        "Remind me",
                        isOn: Binding(
                            get: { manager.isEnabled(for: timeOfDay) },
                            set: { enabled in
                                if enabled {
                                    Task {
                                        let authorized = await manager.requestAuthorization()
                                        if authorized {
                                            manager.setEnabled(true, for: timeOfDay)
                                            manager.scheduleReminder(for: timeOfDay)
                                        }
                                    }
                                } else {
                                    manager.setEnabled(false, for: timeOfDay)
                                    manager.cancelReminder(for: timeOfDay)
                                }
                            }
                        )
                    )

                    if manager.isEnabled(for: timeOfDay) {
                        DatePicker(
                            "Time",
                            selection: Binding(
                                get: { manager.reminderTime(for: timeOfDay) },
                                set: { newTime in
                                    manager.setReminderTime(newTime, for: timeOfDay)
                                    manager.scheduleReminder(for: timeOfDay)
                                }
                            ),
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text(timeOfDay.displayName)
                }
            }
            // Weekly check-in reminder
            Section {
                Toggle(
                    "Check-in Reminder",
                    isOn: Binding(
                        get: { manager.isCheckInEnabled },
                        set: { enabled in
                            if enabled {
                                Task {
                                    let authorized = await manager.requestAuthorization()
                                    if authorized {
                                        manager.isCheckInEnabled = true
                                        manager.scheduleCheckInReminder()
                                    }
                                }
                            } else {
                                manager.isCheckInEnabled = false
                                manager.cancelCheckInReminder()
                            }
                        }
                    )
                )

                if manager.isCheckInEnabled {
                    Picker("Day", selection: Binding(
                        get: { manager.checkInDay },
                        set: { newDay in
                            manager.checkInDay = newDay
                            manager.scheduleCheckInReminder()
                        }
                    )) {
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                        Text("Tuesday").tag(3)
                        Text("Wednesday").tag(4)
                        Text("Thursday").tag(5)
                        Text("Friday").tag(6)
                        Text("Saturday").tag(7)
                    }
                }
            } header: {
                Text("Weekly Check-In")
            } footer: {
                Text("Get reminded to take your weekly progress photos.")
            }
        }
        .navigationTitle("Notifications")
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            systemDenied = settings.authorizationStatus == .denied
        }
    }
}
