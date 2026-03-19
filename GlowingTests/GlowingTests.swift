import Testing
import Foundation
@testable import Glowing

// MARK: - Category Tests

struct CategoryTests {

    @Test func allCasesContainsThreeCategories() {
        #expect(Category.allCases.count == 3)
        #expect(Category.allCases.contains(.face))
        #expect(Category.allCases.contains(.hair))
        #expect(Category.allCases.contains(.stubble))
    }

    @Test func displayNames() {
        #expect(Category.face.displayName == "Face")
        #expect(Category.hair.displayName == "Hair")
        #expect(Category.stubble.displayName == "Stubble")
    }

    @Test func defaultIcons() {
        #expect(Category.face.defaultIcon == "face.smiling")
        #expect(Category.hair.defaultIcon == "scissors")
        #expect(Category.stubble.defaultIcon == "line.3.horizontal")
    }

    @Test func sortOrderIsAscending() {
        let sorted = Category.allCases.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted == [.face, .hair, .stubble])
    }

    @Test func sortOrderValues() {
        #expect(Category.face.sortOrder == 0)
        #expect(Category.hair.sortOrder == 1)
        #expect(Category.stubble.sortOrder == 2)
    }

    @Test func rawValues() {
        #expect(Category.face.rawValue == "face")
        #expect(Category.hair.rawValue == "hair")
        #expect(Category.stubble.rawValue == "stubble")
    }

    @Test func initFromRawValue() {
        #expect(Category(rawValue: "face") == .face)
        #expect(Category(rawValue: "hair") == .hair)
        #expect(Category(rawValue: "stubble") == .stubble)
        #expect(Category(rawValue: "body") == nil)
        #expect(Category(rawValue: "dental") == nil)
        #expect(Category(rawValue: "fragrance") == nil)
        #expect(Category(rawValue: "unknown") == nil)
    }
}

// MARK: - TimeOfDay Tests

struct TimeOfDayTests {

    @Test func allCases() {
        #expect(TimeOfDay.allCases.count == 3)
    }

    @Test func displayNames() {
        #expect(TimeOfDay.morning.displayName == "Morning")
        #expect(TimeOfDay.evening.displayName == "Evening")
        #expect(TimeOfDay.weekly.displayName == "Weekly")
    }

    @Test func sortOrder() {
        let sorted = TimeOfDay.allCases.sorted { $0.sortOrder < $1.sortOrder }
        #expect(sorted == [.morning, .evening, .weekly])
    }

    @Test func icons() {
        #expect(TimeOfDay.morning.icon == "sunrise.fill")
        #expect(TimeOfDay.evening.icon == "moon.fill")
        #expect(TimeOfDay.weekly.icon == "calendar")
    }

    @Test func defaultNotificationHours() {
        #expect(TimeOfDay.morning.defaultNotificationHour == 7)
        #expect(TimeOfDay.evening.defaultNotificationHour == 20)
        #expect(TimeOfDay.weekly.defaultNotificationHour == 10)
    }

    @Test func rawValues() {
        #expect(TimeOfDay.morning.rawValue == "morning")
        #expect(TimeOfDay.evening.rawValue == "evening")
        #expect(TimeOfDay.weekly.rawValue == "weekly")
    }
}

// MARK: - PhotoAngle Tests

struct PhotoAngleTests {

    @Test func allCasesContainsThreeAngles() {
        #expect(PhotoAngle.allCases.count == 3)
        #expect(PhotoAngle.allCases.contains(.front))
        #expect(PhotoAngle.allCases.contains(.left))
        #expect(PhotoAngle.allCases.contains(.right))
    }

    @Test func faceAnglesMatchesAllCases() {
        #expect(PhotoAngle.faceAngles == PhotoAngle.allCases)
    }

    @Test func displayNames() {
        #expect(PhotoAngle.front.displayName == "Front")
        #expect(PhotoAngle.left.displayName == "Left Side")
        #expect(PhotoAngle.right.displayName == "Right Side")
    }

    @Test func guidanceTextIsNotEmpty() {
        for angle in PhotoAngle.allCases {
            #expect(!angle.guidanceText.isEmpty)
        }
    }

    @Test func positioningTipIsNotEmpty() {
        for angle in PhotoAngle.allCases {
            #expect(!angle.positioningTip.isEmpty)
        }
    }

    @Test func icons() {
        #expect(PhotoAngle.front.icon == "face.smiling")
        #expect(PhotoAngle.left.icon == "arrow.turn.up.left")
        #expect(PhotoAngle.right.icon == "arrow.turn.up.right")
    }

    @Test func rawValues() {
        #expect(PhotoAngle.front.rawValue == "front")
        #expect(PhotoAngle.left.rawValue == "left")
        #expect(PhotoAngle.right.rawValue == "right")
    }

    @Test func initFromRawValue() {
        #expect(PhotoAngle(rawValue: "front") == .front)
        #expect(PhotoAngle(rawValue: "left") == .left)
        #expect(PhotoAngle(rawValue: "right") == .right)
        #expect(PhotoAngle(rawValue: "body") == nil)
        #expect(PhotoAngle(rawValue: "unknown") == nil)
    }
}

// MARK: - Season Tests

struct SeasonTests {

    @Test func allCasesCount() {
        #expect(Season.allCases.count == 5)
    }

    @Test func displayNames() {
        #expect(Season.yearRound.displayName == "Year-Round")
        #expect(Season.winter.displayName.contains("Winter"))
        #expect(Season.spring.displayName.contains("Spring"))
        #expect(Season.summer.displayName.contains("Summer"))
        #expect(Season.fall.displayName.contains("Fall"))
    }

    @Test func icons() {
        #expect(Season.yearRound.icon == "calendar")
        #expect(Season.winter.icon == "snowflake")
        #expect(Season.spring.icon == "leaf.fill")
        #expect(Season.summer.icon == "sun.max.fill")
        #expect(Season.fall.icon == "wind")
    }

    @Test func yearRoundMonthsCoverAllTwelve() {
        #expect(Season.yearRound.months.count == 12)
        for month in 1...12 {
            #expect(Season.yearRound.months.contains(month))
        }
    }

    @Test func winterMonths() {
        #expect(Season.winter.months == [12, 1, 2])
    }

    @Test func springMonths() {
        #expect(Season.spring.months == [3, 4, 5])
    }

    @Test func summerMonths() {
        #expect(Season.summer.months == [6, 7, 8])
    }

    @Test func fallMonths() {
        #expect(Season.fall.months == [9, 10, 11])
    }

    @Test func yearRoundIsAlwaysCurrent() {
        // Test with various dates throughout the year
        let calendar = Calendar.current
        for month in 1...12 {
            let date = calendar.date(from: DateComponents(year: 2025, month: month, day: 15))!
            #expect(Season.yearRound.isCurrent(on: date))
        }
    }

    @Test func winterIsCurrentInDecJanFeb() {
        let calendar = Calendar.current
        let jan = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!
        let feb = calendar.date(from: DateComponents(year: 2025, month: 2, day: 15))!
        let dec = calendar.date(from: DateComponents(year: 2025, month: 12, day: 15))!
        let jul = calendar.date(from: DateComponents(year: 2025, month: 7, day: 15))!

        #expect(Season.winter.isCurrent(on: jan))
        #expect(Season.winter.isCurrent(on: feb))
        #expect(Season.winter.isCurrent(on: dec))
        #expect(!Season.winter.isCurrent(on: jul))
    }

    @Test func summerIsCurrentInJunJulAug() {
        let calendar = Calendar.current
        let jun = calendar.date(from: DateComponents(year: 2025, month: 6, day: 15))!
        let jul = calendar.date(from: DateComponents(year: 2025, month: 7, day: 15))!
        let aug = calendar.date(from: DateComponents(year: 2025, month: 8, day: 15))!
        let jan = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!

        #expect(Season.summer.isCurrent(on: jun))
        #expect(Season.summer.isCurrent(on: jul))
        #expect(Season.summer.isCurrent(on: aug))
        #expect(!Season.summer.isCurrent(on: jan))
    }

    @Test func seasonsDoNotOverlap() {
        let seasonalSeasons: [Season] = [.winter, .spring, .summer, .fall]
        for month in 1...12 {
            let matching = seasonalSeasons.filter { $0.months.contains(month) }
            #expect(matching.count == 1, "Month \(month) should belong to exactly one season")
        }
    }

    @Test func allMonthsCovered() {
        let allMonths = Season.winter.months
            .union(Season.spring.months)
            .union(Season.summer.months)
            .union(Season.fall.months)
        #expect(allMonths.count == 12)
    }
}

// MARK: - Achievement Tests

struct AchievementTests {

    @Test func allCasesCount() {
        #expect(AchievementType.allCases.count == 11)
    }

    @Test func allHaveNonEmptyNames() {
        for achievement in AchievementType.allCases {
            #expect(!achievement.name.isEmpty)
        }
    }

    @Test func allHaveNonEmptyDescriptions() {
        for achievement in AchievementType.allCases {
            #expect(!achievement.description.isEmpty)
        }
    }

    @Test func allHaveNonEmptyIcons() {
        for achievement in AchievementType.allCases {
            #expect(!achievement.icon.isEmpty)
        }
    }

    @Test func idMatchesRawValue() {
        for achievement in AchievementType.allCases {
            #expect(achievement.id == achievement.rawValue)
        }
    }

    @Test func sortOrderIsUnique() {
        let sortOrders = AchievementType.allCases.map(\.sortOrder)
        let uniqueSortOrders = Set(sortOrders)
        #expect(sortOrders.count == uniqueSortOrders.count)
    }

    @Test func sortOrderStartsFromZero() {
        let minOrder = AchievementType.allCases.map(\.sortOrder).min()
        #expect(minOrder == 0)
    }

    @Test func sortOrderIsContiguous() {
        let sortOrders = AchievementType.allCases.map(\.sortOrder).sorted()
        for (index, order) in sortOrders.enumerated() {
            #expect(order == index, "Expected sort order \(index) but got \(order)")
        }
    }

    @Test func specificAchievementNames() {
        #expect(AchievementType.firstRoutine.name == "First Steps")
        #expect(AchievementType.sevenDayStreak.name == "One Week")
        #expect(AchievementType.perfectWeek.name == "Perfect Week")
        #expect(AchievementType.firstCheckIn.name == "Snapshot")
        #expect(AchievementType.tenPointGain.name == "Transformation")
    }
}

// MARK: - StepDayVariant Tests

struct StepDayVariantTests {

    @Test func weekdayNames() {
        #expect(StepDayVariant.weekdayName(for: 1) == "Sun")
        #expect(StepDayVariant.weekdayName(for: 2) == "Mon")
        #expect(StepDayVariant.weekdayName(for: 3) == "Tue")
        #expect(StepDayVariant.weekdayName(for: 4) == "Wed")
        #expect(StepDayVariant.weekdayName(for: 5) == "Thu")
        #expect(StepDayVariant.weekdayName(for: 6) == "Fri")
        #expect(StepDayVariant.weekdayName(for: 7) == "Sat")
    }

    @Test func fullWeekdayNames() {
        #expect(StepDayVariant.fullWeekdayName(for: 1) == "Sunday")
        #expect(StepDayVariant.fullWeekdayName(for: 2) == "Monday")
        #expect(StepDayVariant.fullWeekdayName(for: 3) == "Tuesday")
        #expect(StepDayVariant.fullWeekdayName(for: 4) == "Wednesday")
        #expect(StepDayVariant.fullWeekdayName(for: 5) == "Thursday")
        #expect(StepDayVariant.fullWeekdayName(for: 6) == "Friday")
        #expect(StepDayVariant.fullWeekdayName(for: 7) == "Saturday")
    }

    @Test func outOfRangeWeekdayReturnsQuestionMark() {
        #expect(StepDayVariant.weekdayName(for: 0) == "?")
        #expect(StepDayVariant.weekdayName(for: 8) == "?")
        #expect(StepDayVariant.weekdayName(for: -1) == "?")
        #expect(StepDayVariant.fullWeekdayName(for: 0) == "?")
        #expect(StepDayVariant.fullWeekdayName(for: 8) == "?")
    }
}

// MARK: - RoutineLog Tests

struct RoutineLogTests {

    @Test func isFullyCompletedWhenAllStepsDone() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "face.smiling")
        let log = RoutineLog(routine: routine, stepsCompleted: 5, totalSteps: 5)
        #expect(log.isFullyCompleted)
    }

    @Test func isNotFullyCompletedWhenPartial() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "face.smiling")
        let log = RoutineLog(routine: routine, stepsCompleted: 3, totalSteps: 5)
        #expect(!log.isFullyCompleted)
    }

    @Test func isNotFullyCompletedWhenZeroSteps() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "face.smiling")
        let log = RoutineLog(routine: routine, stepsCompleted: 0, totalSteps: 5)
        #expect(!log.isFullyCompleted)
    }

    @Test func isFullyCompletedWithZeroTotalSteps() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "face.smiling")
        let log = RoutineLog(routine: routine, stepsCompleted: 0, totalSteps: 0)
        #expect(log.isFullyCompleted)
    }
}

// MARK: - SkinAnalysis Category Helper Tests

struct SkinAnalysisCategoryTests {

    private func makeAnalysis(
        overallScore: Int = 75,
        hairOverallScore: Int = 0,
        bodyOverallScore: Int = 0
    ) -> SkinAnalysis {
        SkinAnalysis(
            sessionID: UUID(),
            overallScore: overallScore,
            summary: "Test summary",
            skinToneScore: 7, skinToneNote: "Good",
            acneScore: 6, acneNote: "Mild",
            pigmentationScore: 8, pigmentationNote: "Even",
            scarsScore: 9, scarsNote: "Minimal",
            textureScore: 7, textureNote: "Smooth",
            darkCirclesScore: 5, darkCirclesNote: "Moderate",
            poresScore: 6, poresNote: "Visible",
            rednessScore: 8, rednessNote: "Low",
            hairOverallScore: hairOverallScore,
            bodyOverallScore: bodyOverallScore
        )
    }

    @Test func userFacingCategoriesCountIsSix() {
        let analysis = makeAnalysis()
        #expect(analysis.userFacingCategories.count == 6)
    }

    @Test func userFacingCategoryIds() {
        let analysis = makeAnalysis()
        let ids = analysis.userFacingCategories.map(\.id)
        #expect(ids.contains("acne"))
        #expect(ids.contains("texture"))
        #expect(ids.contains("hydration"))
        #expect(ids.contains("darkCircles"))
        #expect(ids.contains("redness"))
        #expect(ids.contains("skinTone"))
    }

    @Test func allCategoriesCountIsFifteen() {
        let analysis = makeAnalysis()
        #expect(analysis.categories.count == 15)
    }

    @Test func hairCategoriesCountIsFour() {
        let analysis = makeAnalysis(hairOverallScore: 7)
        #expect(analysis.hairCategories.count == 4)
    }

    @Test func hasHairAnalysisWhenScoreAboveZero() {
        let withHair = makeAnalysis(hairOverallScore: 5)
        let withoutHair = makeAnalysis(hairOverallScore: 0)
        #expect(withHair.hasHairAnalysis)
        #expect(!withoutHair.hasHairAnalysis)
    }

    @Test func hasBodyAnalysisWhenScoreAboveZero() {
        let withBody = makeAnalysis(bodyOverallScore: 60)
        let withoutBody = makeAnalysis(bodyOverallScore: 0)
        #expect(withBody.hasBodyAnalysis)
        #expect(!withoutBody.hasBodyAnalysis)
    }

    @Test func bodyCategoriesCountIsThree() {
        let analysis = makeAnalysis(bodyOverallScore: 70)
        #expect(analysis.bodyCategories.count == 3)
    }

    @Test func categoryResultHasCorrectScores() {
        let analysis = makeAnalysis()
        let acneCategory = analysis.userFacingCategories.first { $0.id == "acne" }
        #expect(acneCategory?.score == 6)
        #expect(acneCategory?.note == "Mild")
    }
}

// MARK: - Routine Model Tests

struct RoutineModelTests {

    @Test func initSetsPropertiesCorrectly() {
        let routine = Routine(
            name: "Morning Skincare",
            category: .face,
            timeOfDay: .morning,
            icon: "face.smiling"
        )

        #expect(routine.name == "Morning Skincare")
        #expect(routine.category == .face)
        #expect(routine.timeOfDay == .morning)
        #expect(routine.icon == "face.smiling")
        #expect(routine.season == .yearRound)
        #expect(routine.scheduledWeekdays.isEmpty)
        #expect(routine.displayOrder == 0)
        #expect(routine.steps.isEmpty)
    }

    @Test func categoryGetSetUsesRawValue() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        #expect(routine.categoryRaw == "face")

        routine.category = .hair
        #expect(routine.categoryRaw == "hair")
        #expect(routine.category == .hair)
    }

    @Test func timeOfDayGetSetUsesRawValue() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        #expect(routine.timeOfDayRaw == "morning")

        routine.timeOfDay = .evening
        #expect(routine.timeOfDayRaw == "evening")
        #expect(routine.timeOfDay == .evening)
    }

    @Test func seasonGetSetUsesRawValue() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        #expect(routine.seasonRaw == Season.yearRound.rawValue)

        routine.season = .summer
        #expect(routine.seasonRaw == "summer")
        #expect(routine.season == .summer)
    }

    @Test func isScheduledTodayYearRoundNoWeekday() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        // Year-round, no weekday constraint — always scheduled
        #expect(routine.isScheduledToday(on: Date()))
    }

    @Test func isScheduledTodayWithMatchingWeekday() {
        let calendar = Calendar.current
        // Create a date that's a Monday (weekday 2)
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2 // Monday
        let monday = calendar.date(from: components)!

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, scheduledWeekdays: [2], icon: "test")
        #expect(routine.isScheduledToday(on: monday))
    }

    @Test func isNotScheduledTodayWithWrongWeekday() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 2 // Monday
        let monday = calendar.date(from: components)!

        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, scheduledWeekdays: [6], icon: "test") // Friday
        #expect(!routine.isScheduledToday(on: monday))
    }

    @Test func isScheduledTodayWithMultipleWeekdays() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 4 // Wednesday
        let wednesday = calendar.date(from: components)!

        let routine = Routine(name: "Test", category: .stubble, timeOfDay: .morning, scheduledWeekdays: [2, 4, 6], icon: "test") // Mon, Wed, Fri
        #expect(routine.isScheduledToday(on: wednesday))
    }

    @Test func isNotScheduledTodayWithMultipleWeekdaysOnOffDay() {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 3 // Tuesday
        let tuesday = calendar.date(from: components)!

        let routine = Routine(name: "Test", category: .stubble, timeOfDay: .morning, scheduledWeekdays: [2, 4, 6], icon: "test") // Mon, Wed, Fri
        #expect(!routine.isScheduledToday(on: tuesday))
    }

    @Test func scheduledWeekdaysRoundTrips() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, scheduledWeekdays: [2, 4, 6], icon: "test")
        #expect(routine.scheduledWeekdays == [2, 4, 6])
        #expect(routine.scheduledWeekdaysRaw == "2,4,6")

        routine.scheduledWeekdays = []
        #expect(routine.scheduledWeekdaysRaw == "")
        #expect(routine.scheduledWeekdays.isEmpty)
    }

    @Test func isNotScheduledTodayWhenSeasonDoesNotMatch() {
        let calendar = Calendar.current
        let july = calendar.date(from: DateComponents(year: 2025, month: 7, day: 15))!

        let routine = Routine(name: "Winter Care", category: .face, timeOfDay: .morning, season: .winter, icon: "test")
        #expect(!routine.isScheduledToday(on: july))
    }

    @Test func isScheduledTodayWhenSeasonMatches() {
        let calendar = Calendar.current
        let january = calendar.date(from: DateComponents(year: 2025, month: 1, day: 15))!

        let routine = Routine(name: "Winter Care", category: .face, timeOfDay: .morning, season: .winter, icon: "test")
        #expect(routine.isScheduledToday(on: january))
    }

    @Test func sortedStepsReturnsByOrder() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        let step1 = RoutineStep(order: 2, title: "Step B")
        let step2 = RoutineStep(order: 0, title: "Step A")
        let step3 = RoutineStep(order: 1, title: "Step C")
        routine.steps = [step1, step2, step3]

        let sorted = routine.sortedSteps
        #expect(sorted[0].title == "Step A")
        #expect(sorted[1].title == "Step C")
        #expect(sorted[2].title == "Step B")
    }

    @Test func invalidCategoryRawFallsBackToFace() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        routine.categoryRaw = "invalid_category"
        #expect(routine.category == .face)
    }

    @Test func invalidTimeOfDayRawFallsBackToMorning() {
        let routine = Routine(name: "Test", category: .face, timeOfDay: .morning, icon: "test")
        routine.timeOfDayRaw = "invalid_time"
        #expect(routine.timeOfDay == .morning)
    }
}

// MARK: - RoutineStep Tests

struct RoutineStepTests {

    @Test func initSetsPropertiesCorrectly() {
        let step = RoutineStep(
            order: 1,
            title: "Cleanser",
            productName: "CeraVe",
            notes: "Apply gently",
            timerDuration: 60
        )

        #expect(step.order == 1)
        #expect(step.title == "Cleanser")
        #expect(step.productName == "CeraVe")
        #expect(step.notes == "Apply gently")
        #expect(step.timerDuration == 60)
        #expect(step.dayVariants.isEmpty)
    }

    @Test func hasDayVariantsIsFalseByDefault() {
        let step = RoutineStep(order: 0, title: "Test")
        #expect(!step.hasDayVariants)
    }

    @Test func hasDayVariantsIsTrueWithVariants() {
        let step = RoutineStep(order: 0, title: "Test")
        step.dayVariants = [StepDayVariant(weekday: 2)]
        #expect(step.hasDayVariants)
    }

    @Test func resolvedProductNameFallsBackToDefault() {
        let step = RoutineStep(order: 0, title: "Moisturize", productName: "Default Product")
        // No variant for weekday 3
        #expect(step.resolvedProductName(for: 3) == "Default Product")
    }

    @Test func resolvedProductNameUsesVariantWhenAvailable() {
        let step = RoutineStep(order: 0, title: "Moisturize", productName: "Default Product")
        let variant = StepDayVariant(weekday: 3, productName: "Special Product")
        step.dayVariants = [variant]
        #expect(step.resolvedProductName(for: 3) == "Special Product")
    }

    @Test func resolvedProductNameUsesDefaultWhenVariantHasNilProduct() {
        let step = RoutineStep(order: 0, title: "Moisturize", productName: "Default Product")
        let variant = StepDayVariant(weekday: 3) // No productName override
        step.dayVariants = [variant]
        #expect(step.resolvedProductName(for: 3) == "Default Product")
    }

    @Test func resolvedNotesUsesVariantWhenAvailable() {
        let step = RoutineStep(order: 0, title: "Test", notes: "Default notes")
        let variant = StepDayVariant(weekday: 5, notes: "Friday notes")
        step.dayVariants = [variant]
        #expect(step.resolvedNotes(for: 5) == "Friday notes")
    }

    @Test func resolvedNotesFallsBackToDefault() {
        let step = RoutineStep(order: 0, title: "Test", notes: "Default notes")
        #expect(step.resolvedNotes(for: 2) == "Default notes")
    }

    @Test func isSkippedReturnsFalseByDefault() {
        let step = RoutineStep(order: 0, title: "Test")
        #expect(!step.isSkipped(on: 2))
    }

    @Test func isSkippedReturnsTrueWhenVariantSaysSkip() {
        let step = RoutineStep(order: 0, title: "Test")
        let variant = StepDayVariant(weekday: 2, skip: true)
        step.dayVariants = [variant]
        #expect(step.isSkipped(on: 2))
    }

    @Test func isSkippedReturnsFalseForOtherWeekdays() {
        let step = RoutineStep(order: 0, title: "Test")
        let variant = StepDayVariant(weekday: 2, skip: true)
        step.dayVariants = [variant]
        #expect(!step.isSkipped(on: 3)) // Wednesday is not skipped
    }
}

// MARK: - ProgressPhoto Tests

struct ProgressPhotoTests {

    @Test func initSetsPropertiesCorrectly() {
        let sessionID = UUID()
        let photo = ProgressPhoto(angle: .front, imageData: nil, sessionID: sessionID)

        #expect(photo.angle == .front)
        #expect(photo.angleRaw == "front")
        #expect(photo.sessionID == sessionID)
        #expect(photo.imageData == nil)
        #expect(photo.note == nil)
    }

    @Test func angleGetSetUsesRawValue() {
        let photo = ProgressPhoto(angle: .front, imageData: nil, sessionID: UUID())
        #expect(photo.angleRaw == "front")

        photo.angle = .left
        #expect(photo.angleRaw == "left")
        #expect(photo.angle == .left)
    }

    @Test func invalidAngleRawFallsBackToFront() {
        let photo = ProgressPhoto(angle: .front, imageData: nil, sessionID: UUID())
        photo.angleRaw = "invalid"
        #expect(photo.angle == .front)
    }

    @Test func photoWithNote() {
        let photo = ProgressPhoto(angle: .right, imageData: nil, sessionID: UUID(), note: "Test note")
        #expect(photo.note == "Test note")
    }
}

// MARK: - RoutineTemplate & Package Tests

struct RoutineTemplateTests {

    @Test func allPackagesContainsThreePackages() {
        #expect(RoutinePackage.allPackages.count == 3)
    }

    @Test func packageCategoriesAreFaceHairStubble() {
        let categories = Set(RoutinePackage.allPackages.map(\.category))
        #expect(categories.contains(.face))
        #expect(categories.contains(.hair))
        #expect(categories.contains(.stubble))
    }

    @Test func eachPackageHasRoutines() {
        for package in RoutinePackage.allPackages {
            #expect(!package.routines.isEmpty, "Package '\(package.name)' should have routines")
        }
    }

    @Test func eachRoutineHasSteps() {
        for package in RoutinePackage.allPackages {
            for routine in package.routines {
                #expect(!routine.steps.isEmpty, "Routine '\(routine.name)' in '\(package.name)' should have steps")
            }
        }
    }

    @Test func totalStepsIsPositive() {
        for package in RoutinePackage.allPackages {
            #expect(package.totalSteps > 0, "Package '\(package.name)' should have positive total steps")
        }
    }

    @Test func totalStepsSumsCorrectly() {
        for package in RoutinePackage.allPackages {
            let manualTotal = package.routines.reduce(0) { $0 + $1.steps.count }
            #expect(package.totalSteps == manualTotal)
        }
    }

    @Test func eachPackageHasNonEmptyDescription() {
        for package in RoutinePackage.allPackages {
            #expect(!package.description.isEmpty)
        }
    }

    @Test func eachPackageHasNonEmptyIcon() {
        for package in RoutinePackage.allPackages {
            #expect(!package.icon.isEmpty)
        }
    }

    @Test func stubblePackageHasTwoRoutines() {
        let stubble = RoutinePackage.stubblePackage
        #expect(stubble.routines.count == 2)
        #expect(stubble.routines[0].name == "Stubble Trim")
        #expect(stubble.routines[0].scheduledWeekdays == [2, 4, 6]) // Mon, Wed, Fri
        #expect(stubble.routines[1].name == "Edge Cleanup")
        #expect(stubble.routines[1].scheduledWeekdays == [2, 4]) // Mon, Wed
    }

    @Test func noBodyDentalOrFragranceCategories() {
        for package in RoutinePackage.allPackages {
            #expect(package.category != Category(rawValue: "body"))
            #expect(package.category != Category(rawValue: "dental"))
            #expect(package.category != Category(rawValue: "fragrance"))
        }
    }
}
