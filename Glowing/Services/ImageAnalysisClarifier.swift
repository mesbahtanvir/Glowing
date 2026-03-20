import Foundation

// MARK: - Clarification Models

struct ClarificationOption: Identifiable {
    let id = UUID()
    let label: String
    let description: String
    let value: String
}

struct ClarificationQuestion: Identifiable {
    let id: String
    let category: Category
    let question: String
    let options: [ClarificationOption]
    let trait: String // which profile field this resolves
}

// MARK: - Clarifier

struct ImageAnalysisClarifier {

    /// Inspect the extracted profile and build clarification questions for ambiguous traits.
    static func buildQuestions(from profile: ImageAnalysisProfile) -> [ClarificationQuestion] {
        var questions: [ClarificationQuestion] = []

        // Beard preference — only when the LLM says growth is decent but style is ambiguous
        if profile.needsBeardPreferenceInput {
            questions.append(ClarificationQuestion(
                id: "beardPreference",
                category: .stubble,
                question: "Your beard growth looks solid. What style are you going for?",
                options: [
                    ClarificationOption(label: "Full Beard", description: "Grow it out with proper care routine", value: "full_beard"),
                    ClarificationOption(label: "Short Beard", description: "Neat, trimmed short beard", value: "short_beard"),
                    ClarificationOption(label: "Stubble", description: "Maintained stubble look", value: "stubble"),
                    ClarificationOption(label: "Clean Shaven", description: "No facial hair", value: "clean_shaven"),
                ],
                trait: "facialHairStatus"
            ))
        }

        // Skin sensitivity — not reliably visible in photos
        if profile.skinTypeConfidence != .high && profile.skinType == .sensitive {
            questions.append(ClarificationQuestion(
                id: "skinSensitivity",
                category: .face,
                question: "Does your skin react easily to new products?",
                options: [
                    ClarificationOption(label: "Yes, often", description: "Redness, stinging, or breakouts with many products", value: "sensitive"),
                    ClarificationOption(label: "Sometimes", description: "Occasional reactions to certain ingredients", value: "combination"),
                    ClarificationOption(label: "Rarely", description: "Can use most products without issues", value: "normal"),
                ],
                trait: "skinType"
            ))
        }

        // Scalp concerns — not always visible, especially with longer hair
        if profile.scalpConcerns.isEmpty && profile.hairLength != .short {
            questions.append(ClarificationQuestion(
                id: "scalpConcerns",
                category: .hair,
                question: "Do you experience any scalp issues?",
                options: [
                    ClarificationOption(label: "Dandruff / Flaking", description: "Visible flakes on scalp or shoulders", value: "dandruff"),
                    ClarificationOption(label: "Oily Scalp", description: "Hair gets greasy quickly", value: "oiliness"),
                    ClarificationOption(label: "Dry / Itchy", description: "Scalp feels tight or itchy", value: "dryness"),
                    ClarificationOption(label: "None", description: "No scalp concerns", value: "none"),
                ],
                trait: "scalpConcerns"
            ))
        }

        return questions
    }

    /// Apply user's clarification answers to the profile
    static func applyAnswers(_ answers: [String: String], to profile: inout ImageAnalysisProfile) {
        for (questionID, value) in answers {
            switch questionID {
            case "beardPreference":
                if let status = FacialHairStatus(rawValue: value) {
                    profile.facialHairStatus = status
                    profile.needsBeardPreferenceInput = false
                    profile.beardRecommendation = "User chose: \(status.displayName)"
                }

            case "skinSensitivity":
                if let skinType = SkinType(rawValue: value) {
                    profile.skinType = skinType
                    profile.skinTypeConfidence = .high
                }

            case "scalpConcerns":
                if value == "none" {
                    profile.scalpConcerns = []
                } else {
                    profile.scalpConcerns = [value]
                }

            default:
                break
            }
        }
    }
}
