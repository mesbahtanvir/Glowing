import Foundation
import SwiftUI
import SwiftData

// MARK: - Flow State

enum ImageAnalysisFlowState: Equatable {
    case idle
    case selectingImages
    case checkingLighting
    case extractingDetails
    case reviewingDetails
    case clarifying
    case generatingRoutines
    case showingResults
    case complete

    static func == (lhs: ImageAnalysisFlowState, rhs: ImageAnalysisFlowState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.selectingImages, .selectingImages),
             (.checkingLighting, .checkingLighting), (.extractingDetails, .extractingDetails),
             (.reviewingDetails, .reviewingDetails), (.clarifying, .clarifying),
             (.generatingRoutines, .generatingRoutines), (.showingResults, .showingResults),
             (.complete, .complete):
            return true
        default:
            return false
        }
    }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ImageAnalysisViewModel {

    // Flow state
    var flowState: ImageAnalysisFlowState = .idle
    var error: String?

    // Images
    var capturedPhotos: [PhotoAngle: Data] = [:]

    // Lighting
    var lightingCondition: LightingCondition?
    var lightingWarning: String?
    var baselineLighting: LightingCondition?

    // Extracted profile
    var profile: ImageAnalysisProfile?

    // Clarification
    var clarificationQuestions: [ClarificationQuestion] = []
    var clarificationAnswers: [String: String] = [:]
    var currentQuestionIndex: Int = 0

    // Generated routines
    var generatedRoutines: [[String: Any]] = []

    // Progress
    var progressMessage: String = ""

    // MARK: - Start Fresh (New Photos)

    func startFresh() {
        flowState = .selectingImages
        capturedPhotos = [:]
        profile = nil
        clarificationQuestions = []
        clarificationAnswers = [:]
        generatedRoutines = []
        error = nil
    }

    // MARK: - Start From Existing Photos

    func startFromExistingPhotos(_ photos: [PhotoAngle: Data], baseline: LightingCondition? = nil) {
        capturedPhotos = photos
        baselineLighting = baseline
        profile = nil
        clarificationQuestions = []
        clarificationAnswers = [:]
        generatedRoutines = []
        error = nil

        Task {
            await checkLightingAndProceed()
        }
    }

    // MARK: - Photos Captured (from camera)

    func photosReady(_ photos: [PhotoAngle: Data]) {
        capturedPhotos = photos
        Task {
            await checkLightingAndProceed()
        }
    }

    // MARK: - Lighting Check

    private func checkLightingAndProceed() async {
        flowState = .checkingLighting
        progressMessage = "Checking lighting conditions..."

        // Analyze lighting on the front photo
        if let frontData = capturedPhotos[.front],
           let image = UIImage(data: frontData) {
            let condition = await LightingAnalyzer.shared.analyzeImage(image)
            lightingCondition = condition

            if condition.qualityScore == .poor {
                lightingWarning = condition.primaryIssueMessage
                // Stay in checkingLighting state so the view can show warning
                return
            }

            // Check consistency with baseline if available
            if let baseline = baselineLighting, !condition.isConsistentWith(baseline) {
                lightingWarning = "Your lighting looks different from your last session. This may affect score comparisons."
                return
            }
        }

        // Lighting is fine, proceed to extraction
        await extractDetails()
    }

    /// User acknowledged lighting warning and wants to proceed anyway
    func proceedDespiteLighting() {
        lightingWarning = nil
        Task {
            await extractDetails()
        }
    }

    /// User wants to retake photos due to lighting
    func retakePhotos() {
        lightingWarning = nil
        lightingCondition = nil
        startFresh()
    }

    // MARK: - Extract Details (LLM Call 1)

    func extractDetails() async {
        flowState = .extractingDetails
        progressMessage = "Analyzing your features..."
        error = nil

        let images = capturedPhotos.compactMap { (angle, data) -> AnalysisImage? in
            guard let base64 = UIImage(data: data)?
                .jpegData(compressionQuality: 0.7)?
                .base64EncodedString() else { return nil }
            return AnalysisImage(angle: angle.rawValue, base64Data: base64)
        }

        do {
            let extractedProfile = try await BackendAPIClient.shared.extractImageDetails(images: images)
            profile = extractedProfile

            // Build clarification questions
            clarificationQuestions = ImageAnalysisClarifier.buildQuestions(from: extractedProfile)

            if clarificationQuestions.isEmpty {
                // No clarification needed — show detected traits for review
                flowState = .reviewingDetails
            } else {
                // Show detected traits first, then move to clarification
                flowState = .reviewingDetails
            }
        } catch {
            self.error = error.localizedDescription
            flowState = .extractingDetails // stay on this state so UI can show error
        }
    }

    // MARK: - Review & Clarification

    /// User reviewed extracted details and is ready to proceed
    func proceedFromReview() {
        if clarificationQuestions.isEmpty {
            Task { await generateRoutines() }
        } else {
            currentQuestionIndex = 0
            flowState = .clarifying
        }
    }

    /// User manually overrides a detected trait
    func overrideTrait(_ trait: String, value: String) {
        guard profile != nil else { return }
        var answers = [trait: value]
        ImageAnalysisClarifier.applyAnswers(answers, to: &profile!)
    }

    /// Submit answer for current clarification question
    func submitClarificationAnswer(_ value: String) {
        guard currentQuestionIndex < clarificationQuestions.count else { return }
        let question = clarificationQuestions[currentQuestionIndex]
        clarificationAnswers[question.id] = value

        currentQuestionIndex += 1

        if currentQuestionIndex >= clarificationQuestions.count {
            // All questions answered — apply and generate
            if var updatedProfile = profile {
                ImageAnalysisClarifier.applyAnswers(clarificationAnswers, to: &updatedProfile)
                profile = updatedProfile
            }
            Task { await generateRoutines() }
        }
    }

    /// Skip remaining clarification questions
    func skipRemainingQuestions() {
        if var updatedProfile = profile {
            ImageAnalysisClarifier.applyAnswers(clarificationAnswers, to: &updatedProfile)
            profile = updatedProfile
        }
        Task { await generateRoutines() }
    }

    var currentQuestion: ClarificationQuestion? {
        guard currentQuestionIndex < clarificationQuestions.count else { return nil }
        return clarificationQuestions[currentQuestionIndex]
    }

    // MARK: - Generate Routines (LLM Call 2)

    func generateRoutines() async {
        guard let confirmedProfile = profile else {
            error = "No profile available"
            return
        }

        flowState = .generatingRoutines
        progressMessage = "Creating your personalized routines..."
        error = nil

        do {
            let routines = try await BackendAPIClient.shared.generateRoutines(profile: confirmedProfile)
            generatedRoutines = routines
            flowState = .showingResults
        } catch {
            self.error = error.localizedDescription
        }
    }

    // MARK: - Save Routines to SwiftData

    func saveRoutines(modelContext: ModelContext) {
        for routineJSON in generatedRoutines {
            let name = routineJSON["name"] as? String ?? "Routine"
            let categoryRaw = routineJSON["category"] as? String ?? "face"
            let category = Category(rawValue: categoryRaw) ?? .face
            let timeOfDayRaw = routineJSON["timeOfDay"] as? String ?? "morning"
            let timeOfDay = TimeOfDay(rawValue: timeOfDayRaw) ?? .morning
            let weekdays = routineJSON["scheduledWeekdays"] as? [Int] ?? []
            let icon = routineJSON["icon"] as? String ?? category.defaultIcon
            let displayOrder = routineJSON["displayOrder"] as? Int ?? 0

            let routine = Routine(
                name: name,
                category: category,
                timeOfDay: timeOfDay,
                scheduledWeekdays: Set(weekdays),
                displayOrder: displayOrder,
                icon: icon
            )
            modelContext.insert(routine)

            let steps = routineJSON["steps"] as? [[String: Any]] ?? []
            for (index, stepJSON) in steps.enumerated() {
                let step = RoutineStep(
                    order: index,
                    title: stepJSON["title"] as? String ?? "Step \(index + 1)",
                    productName: stepJSON["productName"] as? String,
                    notes: stepJSON["notes"] as? String,
                    timerDuration: stepJSON["timerDuration"] as? Int
                )
                routine.steps.append(step)
            }
        }

        flowState = .complete
    }
}
