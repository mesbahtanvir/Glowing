import Foundation
import SwiftUI
import SwiftData

enum OnboardingStep: Int, CaseIterable {
    case welcome
    case capture
    case analyzing          // legacy single-shot analysis
    case extractingDetails  // new: LLM call 1 — trait extraction
    case reviewingDetails   // new: show detected traits
    case clarifying         // new: ask user clarification questions
    case generatingRoutines // new: LLM call 2 — routine generation
    case suggestedRoutine
    case complete
}

@MainActor
@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .welcome
    var capturedPhotos: [PhotoAngle: Data] = [:]
    var isAnalyzing = false
    var analysisError: String?

    // Analysis results
    var skinAnalysisJSON: [String: Any]?
    var suggestedRoutineJSON: [String: Any]?
    var overallScore: Int = 0
    var topConcerns: [String] = []
    var summary: String = ""

    // Multi-step image analysis flow
    let imageAnalysisVM = ImageAnalysisViewModel()

    // MARK: - Navigation

    func advance() {
        guard let nextStep = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = nextStep
        }
    }

    func goToStep(_ step: OnboardingStep) {
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep = step
        }
    }

    // MARK: - Multi-Step Analysis (New Flow)

    /// Start the new multi-step image analysis flow after photos are captured
    func startImageAnalysis() {
        imageAnalysisVM.startFromExistingPhotos(capturedPhotos)
        goToStep(.extractingDetails)
    }

    /// Called when the image analysis flow completes and routines are generated
    func onImageAnalysisComplete() {
        // Store generated routines for the suggested routine view
        suggestedRoutineJSON = ["routines": imageAnalysisVM.generatedRoutines]
        goToStep(.suggestedRoutine)
    }

    // MARK: - Legacy Single-Shot Analysis

    func analyzePhotos() async {
        isAnalyzing = true
        analysisError = nil

        let images = capturedPhotos.compactMap { (angle, data) -> AnalysisImage? in
            let croppedData = FaceCropper.cropToFace(jpegData: data, compressionQuality: 0.7)
            return AnalysisImage(angle: angle.rawValue, base64Data: croppedData.base64EncodedString())
        }

        do {
            let result = try await BackendAPIClient.shared.analyzeOnboarding(
                images: images
            )

            skinAnalysisJSON = result.skinAnalysisJSON
            suggestedRoutineJSON = result.suggestedRoutineJSON

            // Extract key display values
            overallScore = result.skinAnalysisJSON["overallScore"] as? Int ?? 0
            summary = result.skinAnalysisJSON["summary"] as? String ?? ""

            // Build top concerns from grouped categories
            var concerns: [(String, Int)] = []
            let groupKeys = ["skin", "hair", "lips", "under_eye", "facial_hair", "eyebrows", "eye_area", "teeth", "nose", "facial_structure", "neck_posture", "overall_impression"]
            for groupKey in groupKeys {
                if let groupDict = result.skinAnalysisJSON[groupKey] as? [String: Any] {
                    for (_, value) in groupDict {
                        if let catDict = value as? [String: Any],
                           let score = catDict["score"] as? Int,
                           let note = catDict["note"] as? String,
                           score <= 5, score > 0 {
                            // Use the note's first few words as a readable name
                            let label = note.components(separatedBy: " ").prefix(3).joined(separator: " ")
                            concerns.append((label, score))
                        }
                    }
                }
            }
            topConcerns = concerns.sorted { $0.1 < $1.1 }.prefix(3).map(\.0)

            isAnalyzing = false
        } catch {
            isAnalyzing = false
            analysisError = error.localizedDescription
        }
    }

    // MARK: - Create Routines from Suggestion

    func createSuggestedRoutines(modelContext: ModelContext) {
        guard let json = suggestedRoutineJSON else { return }

        // New format: "routines" array with category, timeOfDay, scheduledWeekdays
        let routineArray = json["routines"] as? [[String: Any]] ?? []

        if !routineArray.isEmpty {
            createRoutinesFromArray(routineArray, modelContext: modelContext)
        } else {
            // Legacy fallback: morningSteps/eveningSteps format
            createRoutinesFromLegacyFormat(json, modelContext: modelContext)
        }
    }

    private func createRoutinesFromArray(_ routineArray: [[String: Any]], modelContext: ModelContext) {
        for routineJSON in routineArray {
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
    }

    private func createRoutinesFromLegacyFormat(_ json: [String: Any], modelContext: ModelContext) {
        if let morningSteps = json["morningSteps"] as? [[String: Any]], !morningSteps.isEmpty {
            let routine = Routine(name: "Morning Skincare", category: .face, timeOfDay: .morning, displayOrder: 0, icon: "sun.max.fill")
            modelContext.insert(routine)
            for (index, stepJSON) in morningSteps.enumerated() {
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

        if let eveningSteps = json["eveningSteps"] as? [[String: Any]], !eveningSteps.isEmpty {
            let routine = Routine(name: "Evening Skincare", category: .face, timeOfDay: .evening, displayOrder: 1, icon: "moon.fill")
            modelContext.insert(routine)
            for (index, stepJSON) in eveningSteps.enumerated() {
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
    }

    // MARK: - Complete Onboarding

    func completeOnboarding(modelContext: ModelContext) {
        // Save skin analysis if available
        if let json = skinAnalysisJSON {
            let sessionID = UUID()
            // Save photos as ProgressPhotos
            let now = Date()
            for (angle, data) in capturedPhotos {
                let photo = ProgressPhoto(
                    angle: angle,
                    imageData: data,
                    sessionID: sessionID,
                    capturedAt: now
                )
                modelContext.insert(photo)
            }

            // Parse and save analysis
            let rawJSONString = (try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted))
                .flatMap { String(data: $0, encoding: .utf8) }
            let analysis = SkinAnalysisManager.shared.parseSkinAnalysis(
                sessionID: sessionID,
                result: json,
                rawJSON: rawJSONString
            )
            modelContext.insert(analysis)
        }

        // Create suggested routines
        createSuggestedRoutines(modelContext: modelContext)

        // Mark onboarding complete
        if let user = AuthManager.shared.currentUser {
            user.hasCompletedOnboarding = true
        }
    }
}
