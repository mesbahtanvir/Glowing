//
//  GlowingApp.swift
//  Glowing
//
//  Created by Mesbah Tanvir on 2026-03-08.
//

import SwiftUI
import SwiftData

@main
struct GlowingApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Routine.self,
            RoutineStep.self,
            RoutineLog.self,
            StepDayVariant.self,
            ProgressPhoto.self,
            SkinAnalysis.self,
            UserProfile.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // If migration fails, delete the old store and try again
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            // Also remove related files (.sqlite-shm, .sqlite-wal)
            let shmURL = url.appendingPathExtension("sqlite-shm")
            let walURL = url.appendingPathExtension("sqlite-wal")
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)

            // Reset seed version so it re-seeds
            UserDefaults.standard.removeObject(forKey: "seedVersion")

            do {
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                fatalError("Could not create ModelContainer: \(error)")
            }
        }
    }()

    @State private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
            .task {
                seedDefaultRoutines()
                PendingAnalysisManager.shared.resumeIfNeeded()
            }
        }
        .modelContainer(sharedModelContainer)
    }

    /// Bump this number whenever templates change during development to re-seed.
    private static let seedVersion = 8

    @MainActor
    private func seedDefaultRoutines() {
        let context = sharedModelContainer.mainContext
        let currentVersion = UserDefaults.standard.integer(forKey: "seedVersion")

        guard currentVersion < Self.seedVersion else { return }

        // Skip seeding if user has completed onboarding (they get personalized routines)
        if authManager.currentUser?.hasCompletedOnboarding == true { return }

        // Clear existing routines (cascade deletes steps + day variants)
        do {
            let existing = try context.fetch(FetchDescriptor<Routine>())
            for routine in existing {
                context.delete(routine)
            }
            // Also clear orphaned logs since routines are being replaced
            let existingLogs = try context.fetch(FetchDescriptor<RoutineLog>())
            for log in existingLogs {
                context.delete(log)
            }
        } catch {
            // Continue with seeding even if cleanup fails
        }

        // Seed all packages
        for package in RoutinePackage.allPackages {
            for template in package.routines {
                let routine = Routine(
                    name: template.name,
                    category: package.category,
                    timeOfDay: template.timeOfDay,
                    season: template.season,
                    scheduledWeekdays: template.scheduledWeekdays,
                    displayOrder: template.displayOrder,
                    icon: template.icon
                )
                context.insert(routine)

                for (index, stepTemplate) in template.steps.enumerated() {
                    let step = RoutineStep(
                        order: index,
                        title: stepTemplate.title,
                        productName: stepTemplate.productName,
                        notes: stepTemplate.notes,
                        timerDuration: stepTemplate.timerDuration
                    )

                    for dvTemplate in stepTemplate.dayVariants {
                        let dv = StepDayVariant(
                            weekday: dvTemplate.weekday,
                            productName: dvTemplate.productName,
                            notes: dvTemplate.notes,
                            skip: dvTemplate.skip
                        )
                        step.dayVariants.append(dv)
                    }

                    routine.steps.append(step)
                }
            }
        }

        UserDefaults.standard.set(Self.seedVersion, forKey: "seedVersion")
    }
}
