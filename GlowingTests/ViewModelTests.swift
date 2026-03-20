import Testing
import Foundation
import SwiftData
@testable import Glowing

// MARK: - StreakCalculator Tests

@Suite("StreakCalculator")
struct StreakCalculatorTests {

    private func makeContainer() throws -> ModelContainer {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        return try ModelContainer(
            for: Routine.self, RoutineStep.self, RoutineLog.self, StepDayVariant.self,
            ProgressPhoto.self, SkinAnalysis.self,
            configurations: config
        )
    }

    private func dayAgo(_ days: Int, from base: Date = Date()) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Calendar.current.startOfDay(for: base))!
            .addingTimeInterval(3600 * 10) // 10 AM
    }

    // MARK: - currentStreak(for:logs:)

    @Test func singleRoutineStreakWithNoLogs() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)
        try context.save()

        let streak = StreakCalculator.currentStreak(for: routine, logs: [])
        #expect(streak == 0)
    }

    @Test func singleRoutineStreakWithTodayOnly() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)

        let log = RoutineLog(routine: routine, completedAt: Date(), stepsCompleted: 3, totalSteps: 3)
        context.insert(log)
        try context.save()

        let streak = StreakCalculator.currentStreak(for: routine, logs: [log])
        #expect(streak == 1)
    }

    @Test func singleRoutineStreakWithConsecutiveDays() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)

        var logs: [RoutineLog] = []
        for i in 0..<5 {
            let log = RoutineLog(routine: routine, completedAt: dayAgo(i), stepsCompleted: 3, totalSteps: 3)
            context.insert(log)
            logs.append(log)
        }
        try context.save()

        let streak = StreakCalculator.currentStreak(for: routine, logs: logs)
        #expect(streak == 5)
    }

    @Test func singleRoutineStreakBreaksOnGap() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)

        // Today + yesterday, then gap, then day 3
        let log0 = RoutineLog(routine: routine, completedAt: dayAgo(0), stepsCompleted: 3, totalSteps: 3)
        let log1 = RoutineLog(routine: routine, completedAt: dayAgo(1), stepsCompleted: 3, totalSteps: 3)
        // Gap at day 2
        let log3 = RoutineLog(routine: routine, completedAt: dayAgo(3), stepsCompleted: 3, totalSteps: 3)
        context.insert(log0)
        context.insert(log1)
        context.insert(log3)
        try context.save()

        let streak = StreakCalculator.currentStreak(for: routine, logs: [log0, log1, log3])
        #expect(streak == 2)
    }

    @Test func singleRoutineStreakPartialNotCounted() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)

        // Partial completion should not count
        let log = RoutineLog(routine: routine, completedAt: Date(), stepsCompleted: 2, totalSteps: 3)
        context.insert(log)
        try context.save()

        let streak = StreakCalculator.currentStreak(for: routine, logs: [log])
        #expect(streak == 0)
    }

    @Test func singleRoutineStreakYesterdayOnlyCountsIfNoToday() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)

        // Only completed yesterday (streak still alive — haven't missed today yet)
        let log = RoutineLog(routine: routine, completedAt: dayAgo(1), stepsCompleted: 3, totalSteps: 3)
        context.insert(log)
        try context.save()

        let streak = StreakCalculator.currentStreak(for: routine, logs: [log])
        #expect(streak == 1)
    }

    // MARK: - currentDailyStreak(logs:routines:)

    @Test func dailyStreakWithNoRoutinesIsZero() throws {
        let streak = StreakCalculator.currentDailyStreak(logs: [], routines: [])
        #expect(streak == 0)
    }

    @Test func dailyStreakWithNoLogsIsZero() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)
        try context.save()

        let streak = StreakCalculator.currentDailyStreak(logs: [], routines: [routine])
        #expect(streak == 0)
    }

    @Test func dailyStreakWithAllRoutinesCompletedToday() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let r1 = Routine(name: "R1", category: .face, timeOfDay: .morning, icon: "test")
        let r2 = Routine(name: "R2", category: .hair, timeOfDay: .morning, icon: "test")
        context.insert(r1)
        context.insert(r2)

        let log1 = RoutineLog(routine: r1, completedAt: Date(), stepsCompleted: 3, totalSteps: 3)
        let log2 = RoutineLog(routine: r2, completedAt: Date(), stepsCompleted: 2, totalSteps: 2)
        context.insert(log1)
        context.insert(log2)
        try context.save()

        let streak = StreakCalculator.currentDailyStreak(logs: [log1, log2], routines: [r1, r2])
        #expect(streak == 1)
    }

    @Test func dailyStreakWithOnlyOneRoutineCompletedIsZero() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let r1 = Routine(name: "R1", category: .face, timeOfDay: .morning, icon: "test")
        let r2 = Routine(name: "R2", category: .hair, timeOfDay: .morning, icon: "test")
        context.insert(r1)
        context.insert(r2)

        // Only R1 is completed today
        let log1 = RoutineLog(routine: r1, completedAt: Date(), stepsCompleted: 3, totalSteps: 3)
        context.insert(log1)
        try context.save()

        let streak = StreakCalculator.currentDailyStreak(logs: [log1], routines: [r1, r2])
        #expect(streak == 0)
    }

    @Test func dailyStreakMultipleDays() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let r1 = Routine(name: "R1", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(r1)

        var logs: [RoutineLog] = []
        for i in 0..<3 {
            let log = RoutineLog(routine: r1, completedAt: dayAgo(i), stepsCompleted: 3, totalSteps: 3)
            context.insert(log)
            logs.append(log)
        }
        try context.save()

        let streak = StreakCalculator.currentDailyStreak(logs: logs, routines: [r1])
        #expect(streak == 3)
    }

    // MARK: - completionDates(for:logs:)

    @Test func completionDatesReturnsCorrectDates() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        context.insert(routine)

        let date1 = dayAgo(0)
        let date2 = dayAgo(1)
        let log1 = RoutineLog(routine: routine, completedAt: date1, stepsCompleted: 3, totalSteps: 3)
        let log2 = RoutineLog(routine: routine, completedAt: date2, stepsCompleted: 3, totalSteps: 3)
        let logPartial = RoutineLog(routine: routine, completedAt: dayAgo(2), stepsCompleted: 1, totalSteps: 3)
        context.insert(log1)
        context.insert(log2)
        context.insert(logPartial)
        try context.save()

        let dates = StreakCalculator.completionDates(for: routine, logs: [log1, log2, logPartial])
        // Only fully completed logs count
        #expect(dates.count == 2)
    }

    @Test func completionDatesExcludesOtherRoutines() throws {
        let container = try makeContainer()
        let context = ModelContext(container)

        let r1 = Routine(name: "R1", category: .face, timeOfDay: .morning, icon: "test")
        let r2 = Routine(name: "R2", category: .hair, timeOfDay: .morning, icon: "test")
        context.insert(r1)
        context.insert(r2)

        let log1 = RoutineLog(routine: r1, completedAt: dayAgo(0), stepsCompleted: 3, totalSteps: 3)
        let log2 = RoutineLog(routine: r2, completedAt: dayAgo(0), stepsCompleted: 2, totalSteps: 2)
        context.insert(log1)
        context.insert(log2)
        try context.save()

        let r1Dates = StreakCalculator.completionDates(for: r1, logs: [log1, log2])
        #expect(r1Dates.count == 1)
    }
}

// MARK: - CheckInManager Tests

@Suite("CheckInManager")
struct CheckInManagerTests {

    private func makePhotosForSession(count: Int, date: Date = Date()) -> [ProgressPhoto] {
        let sessionID = UUID()
        let angles: [PhotoAngle] = [.front, .left, .right, .smile]
        return (0..<count).map { i in
            ProgressPhoto(
                angle: angles[i % angles.count],
                imageData: nil,
                sessionID: sessionID,
                capturedAt: date
            )
        }
    }

    @MainActor
    @Test func lastCheckInDateWithNoPhotos() {
        let manager = CheckInManager.shared
        let result = manager.lastCheckInDate(photos: [])
        #expect(result == nil)
    }

    @MainActor
    @Test func lastCheckInDateWithFewerThanThreePhotos() {
        let manager = CheckInManager.shared
        let photos = makePhotosForSession(count: 2)
        let result = manager.lastCheckInDate(photos: photos)
        #expect(result == nil)
    }

    @MainActor
    @Test func lastCheckInDateWithThreePhotoSession() {
        let manager = CheckInManager.shared
        let photos = makePhotosForSession(count: 3)
        let result = manager.lastCheckInDate(photos: photos)
        #expect(result != nil)
    }

    @MainActor
    @Test func isDueForCheckInWithNoPhotos() {
        let manager = CheckInManager.shared
        #expect(manager.isDueForCheckIn(photos: []))
    }

    @MainActor
    @Test func isDueForCheckInWithRecentPhotos() {
        let manager = CheckInManager.shared
        let photos = makePhotosForSession(count: 3, date: Date())
        #expect(!manager.isDueForCheckIn(photos: photos))
    }

    @MainActor
    @Test func isDueForCheckInWithOldPhotos() {
        let manager = CheckInManager.shared
        let oldDate = Calendar.current.date(byAdding: .day, value: -8, to: Date())!
        let photos = makePhotosForSession(count: 3, date: oldDate)
        #expect(manager.isDueForCheckIn(photos: photos))
    }

    @MainActor
    @Test func isDueForCheckInExactlySevenDays() {
        let manager = CheckInManager.shared
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let photos = makePhotosForSession(count: 3, date: sevenDaysAgo)
        #expect(manager.isDueForCheckIn(photos: photos))
    }

    @MainActor
    @Test func isDueForCheckInSixDaysAgo() {
        let manager = CheckInManager.shared
        let sixDaysAgo = Calendar.current.date(byAdding: .day, value: -6, to: Date())!
        let photos = makePhotosForSession(count: 3, date: sixDaysAgo)
        #expect(!manager.isDueForCheckIn(photos: photos))
    }

    @MainActor
    @Test func daysSinceLastCheckInWithNoPhotos() {
        let manager = CheckInManager.shared
        #expect(manager.daysSinceLastCheckIn(photos: []) == 0)
    }

    @MainActor
    @Test func daysSinceLastCheckInWithRecentPhotos() {
        let manager = CheckInManager.shared
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let photos = makePhotosForSession(count: 3, date: threeDaysAgo)
        let days = manager.daysSinceLastCheckIn(photos: photos)
        #expect(days >= 2 && days <= 4) // Allow for timezone/boundary edge cases
    }

    @MainActor
    @Test func weeklyCheckInStreakWithNoPhotos() {
        let manager = CheckInManager.shared
        #expect(manager.weeklyCheckInStreak(photos: []) == 0)
    }

    @MainActor
    @Test func weeklyCheckInStreakWithSingleSession() {
        let manager = CheckInManager.shared
        let photos = makePhotosForSession(count: 3, date: Date())
        #expect(manager.weeklyCheckInStreak(photos: photos) == 1)
    }

    @MainActor
    @Test func weeklyCheckInStreakWithConsecutiveWeeks() {
        let manager = CheckInManager.shared
        var allPhotos: [ProgressPhoto] = []
        for weekOffset in 0..<3 {
            let date = Calendar.current.date(byAdding: .weekOfYear, value: -weekOffset, to: Date())!
            allPhotos.append(contentsOf: makePhotosForSession(count: 3, date: date))
        }
        let streak = manager.weeklyCheckInStreak(photos: allPhotos)
        #expect(streak >= 2) // At least 2 consecutive weeks
    }

    @MainActor
    @Test func weeklyCheckInStreakTwoPhotoSessionDoesNotCount() {
        let manager = CheckInManager.shared
        let photos = makePhotosForSession(count: 2, date: Date())
        #expect(manager.weeklyCheckInStreak(photos: photos) == 0)
    }

    @MainActor
    @Test func lastCheckInDateReturnsMostRecent() {
        let manager = CheckInManager.shared
        let olderDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let newerDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

        var allPhotos: [ProgressPhoto] = []
        allPhotos.append(contentsOf: makePhotosForSession(count: 3, date: olderDate))
        allPhotos.append(contentsOf: makePhotosForSession(count: 3, date: newerDate))

        let result = manager.lastCheckInDate(photos: allPhotos)
        #expect(result != nil)

        // The result should be closer to newerDate than olderDate
        let calendar = Calendar.current
        let daysSinceResult = calendar.dateComponents([.day], from: result!, to: Date()).day!
        #expect(daysSinceResult <= 2)
    }
}

// MARK: - AchievementManager Tests (Logic Verification)

@Suite("AchievementType Logic")
struct AchievementTypeLogicTests {

    @Test func streakAchievementsAreOrdered() {
        // Ensure the streak achievements are ordered by difficulty
        #expect(AchievementType.sevenDayStreak.sortOrder < AchievementType.thirtyDayStreak.sortOrder)
        #expect(AchievementType.thirtyDayStreak.sortOrder < AchievementType.hundredDayStreak.sortOrder)
    }

    @Test func checkInAchievementsAreOrdered() {
        #expect(AchievementType.firstCheckIn.sortOrder < AchievementType.fourWeekCheckIn.sortOrder)
        #expect(AchievementType.fourWeekCheckIn.sortOrder < AchievementType.twelveWeekCheckIn.sortOrder)
    }

    @Test func scoreAchievementsAreOrdered() {
        #expect(AchievementType.firstImprovement.sortOrder < AchievementType.fivePointGain.sortOrder)
        #expect(AchievementType.fivePointGain.sortOrder < AchievementType.tenPointGain.sortOrder)
    }

    @Test func firstRoutineIsEasiestAchievement() {
        #expect(AchievementType.firstRoutine.sortOrder == 0)
    }
}
