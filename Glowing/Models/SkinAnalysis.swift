import Foundation
import SwiftData

@Model
final class SkinAnalysis {
    var sessionID: UUID
    var analyzedAt: Date

    // Overall
    var overallScore: Int
    var summary: String

    // Category scores (0-10) + notes
    var skinToneScore: Int
    var skinToneNote: String

    var acneScore: Int
    var acneNote: String

    var pigmentationScore: Int
    var pigmentationNote: String

    var scarsScore: Int
    var scarsNote: String

    var textureScore: Int
    var textureNote: String

    var darkCirclesScore: Int
    var darkCirclesNote: String

    var poresScore: Int
    var poresNote: String

    var rednessScore: Int
    var rednessNote: String

    // Multi-angle categories (leverage all 3 photos)
    var symmetryScore: Int
    var symmetryNote: String

    var jawlineScore: Int
    var jawlineNote: String

    var hydrationScore: Int
    var hydrationNote: String

    var wrinklesScore: Int
    var wrinklesNote: String

    // Grooming categories
    var beardScore: Int
    var beardNote: String

    var eyebrowsScore: Int
    var eyebrowsNote: String

    var lipsScore: Int
    var lipsNote: String

    // Hair health categories
    var hairOverallScore: Int
    var hairOverallNote: String
    var hairlineScore: Int
    var hairlineNote: String
    var hairThicknessScore: Int
    var hairThicknessNote: String
    var hairConditionScore: Int
    var hairConditionNote: String
    var scalpHealthScore: Int
    var scalpHealthNote: String
    var hairType: String

    // Profile attributes (not scored, descriptive)
    var skinType: String
    var faceShape: String

    // Per-side observations (cross-referencing left/right)
    var leftSideNote: String
    var rightSideNote: String

    // Body structure analysis (physique, not skin)
    var bodyNote: String
    var bodyOverallScore: Int
    var postureScore: Int
    var postureNote: String
    var bodyCompositionScore: Int
    var bodyCompositionNote: String
    var shouldersScore: Int
    var shouldersNote: String
    var bodySummary: String
    var bodyRecommendations: String

    // Actionable recommendations
    var recommendations: String

    // Raw API response
    var rawJSON: String?

    init(
        sessionID: UUID,
        analyzedAt: Date = Date(),
        overallScore: Int,
        summary: String,
        skinToneScore: Int, skinToneNote: String,
        acneScore: Int, acneNote: String,
        pigmentationScore: Int, pigmentationNote: String,
        scarsScore: Int, scarsNote: String,
        textureScore: Int, textureNote: String,
        darkCirclesScore: Int, darkCirclesNote: String,
        poresScore: Int, poresNote: String,
        rednessScore: Int, rednessNote: String,
        symmetryScore: Int = 0, symmetryNote: String = "",
        jawlineScore: Int = 0, jawlineNote: String = "",
        hydrationScore: Int = 0, hydrationNote: String = "",
        wrinklesScore: Int = 0, wrinklesNote: String = "",
        beardScore: Int = 0, beardNote: String = "",
        eyebrowsScore: Int = 0, eyebrowsNote: String = "",
        lipsScore: Int = 0, lipsNote: String = "",
        hairOverallScore: Int = 0, hairOverallNote: String = "",
        hairlineScore: Int = 0, hairlineNote: String = "",
        hairThicknessScore: Int = 0, hairThicknessNote: String = "",
        hairConditionScore: Int = 0, hairConditionNote: String = "",
        scalpHealthScore: Int = 0, scalpHealthNote: String = "",
        hairType: String = "",
        skinType: String = "",
        faceShape: String = "",
        leftSideNote: String = "",
        rightSideNote: String = "",
        bodyNote: String = "",
        bodyOverallScore: Int = 0,
        postureScore: Int = 0, postureNote: String = "",
        bodyCompositionScore: Int = 0, bodyCompositionNote: String = "",
        shouldersScore: Int = 0, shouldersNote: String = "",
        bodySummary: String = "",
        bodyRecommendations: String = "",
        recommendations: String = "",
        rawJSON: String? = nil
    ) {
        self.sessionID = sessionID
        self.analyzedAt = analyzedAt
        self.overallScore = overallScore
        self.summary = summary
        self.skinToneScore = skinToneScore
        self.skinToneNote = skinToneNote
        self.acneScore = acneScore
        self.acneNote = acneNote
        self.pigmentationScore = pigmentationScore
        self.pigmentationNote = pigmentationNote
        self.scarsScore = scarsScore
        self.scarsNote = scarsNote
        self.textureScore = textureScore
        self.textureNote = textureNote
        self.darkCirclesScore = darkCirclesScore
        self.darkCirclesNote = darkCirclesNote
        self.poresScore = poresScore
        self.poresNote = poresNote
        self.rednessScore = rednessScore
        self.rednessNote = rednessNote
        self.symmetryScore = symmetryScore
        self.symmetryNote = symmetryNote
        self.jawlineScore = jawlineScore
        self.jawlineNote = jawlineNote
        self.hydrationScore = hydrationScore
        self.hydrationNote = hydrationNote
        self.wrinklesScore = wrinklesScore
        self.wrinklesNote = wrinklesNote
        self.beardScore = beardScore
        self.beardNote = beardNote
        self.eyebrowsScore = eyebrowsScore
        self.eyebrowsNote = eyebrowsNote
        self.lipsScore = lipsScore
        self.lipsNote = lipsNote
        self.hairOverallScore = hairOverallScore
        self.hairOverallNote = hairOverallNote
        self.hairlineScore = hairlineScore
        self.hairlineNote = hairlineNote
        self.hairThicknessScore = hairThicknessScore
        self.hairThicknessNote = hairThicknessNote
        self.hairConditionScore = hairConditionScore
        self.hairConditionNote = hairConditionNote
        self.scalpHealthScore = scalpHealthScore
        self.scalpHealthNote = scalpHealthNote
        self.hairType = hairType
        self.skinType = skinType
        self.faceShape = faceShape
        self.leftSideNote = leftSideNote
        self.rightSideNote = rightSideNote
        self.bodyNote = bodyNote
        self.bodyOverallScore = bodyOverallScore
        self.postureScore = postureScore
        self.postureNote = postureNote
        self.bodyCompositionScore = bodyCompositionScore
        self.bodyCompositionNote = bodyCompositionNote
        self.shouldersScore = shouldersScore
        self.shouldersNote = shouldersNote
        self.bodySummary = bodySummary
        self.bodyRecommendations = bodyRecommendations
        self.recommendations = recommendations
        self.rawJSON = rawJSON
    }
}

// MARK: - Category Display Helper

extension SkinAnalysis {
    struct CategoryResult: Identifiable {
        let id: String
        let name: String
        let icon: String
        let score: Int
        let note: String
    }

    var hasHairAnalysis: Bool {
        hairOverallScore > 0
    }

    var hairCategories: [CategoryResult] {
        [
            CategoryResult(id: "hairline", name: "Hairline", icon: "arrow.up.and.line.horizontal.and.arrow.down", score: hairlineScore, note: hairlineNote),
            CategoryResult(id: "hairThickness", name: "Thickness", icon: "line.3.horizontal.decrease", score: hairThicknessScore, note: hairThicknessNote),
            CategoryResult(id: "hairCondition", name: "Condition", icon: "sparkles", score: hairConditionScore, note: hairConditionNote),
            CategoryResult(id: "scalpHealth", name: "Scalp Health", icon: "circle.dotted.circle", score: scalpHealthScore, note: scalpHealthNote),
        ]
    }

    var hasBodyAnalysis: Bool {
        bodyOverallScore > 0
    }

    var bodyCategories: [CategoryResult] {
        [
            CategoryResult(id: "posture", name: "Posture", icon: "figure.stand", score: postureScore, note: postureNote),
            CategoryResult(id: "bodyComposition", name: "Composition", icon: "figure.arms.open", score: bodyCompositionScore, note: bodyCompositionNote),
            CategoryResult(id: "shoulders", name: "Shoulders", icon: "figure.strengthtraining.traditional", score: shouldersScore, note: shouldersNote),
        ]
    }

    /// The 6 key user-facing metrics for the skincare app
    var userFacingCategories: [CategoryResult] {
        [
            CategoryResult(id: "acne", name: "Acne", icon: "circle.dotted", score: acneScore, note: acneNote),
            CategoryResult(id: "texture", name: "Texture", icon: "square.grid.3x3.fill", score: textureScore, note: textureNote),
            CategoryResult(id: "hydration", name: "Hydration", icon: "humidity.fill", score: hydrationScore, note: hydrationNote),
            CategoryResult(id: "darkCircles", name: "Dark Circles", icon: "eye.fill", score: darkCirclesScore, note: darkCirclesNote),
            CategoryResult(id: "redness", name: "Redness", icon: "drop.fill", score: rednessScore, note: rednessNote),
            CategoryResult(id: "skinTone", name: "Skin Tone", icon: "sun.max.fill", score: skinToneScore, note: skinToneNote),
        ]
    }

    /// All categories (full developer view)
    var categories: [CategoryResult] {
        [
            CategoryResult(id: "skinTone", name: "Skin Tone", icon: "sun.max.fill", score: skinToneScore, note: skinToneNote),
            CategoryResult(id: "acne", name: "Acne", icon: "circle.dotted", score: acneScore, note: acneNote),
            CategoryResult(id: "pigmentation", name: "Pigmentation", icon: "paintpalette.fill", score: pigmentationScore, note: pigmentationNote),
            CategoryResult(id: "scars", name: "Scars", icon: "bandage.fill", score: scarsScore, note: scarsNote),
            CategoryResult(id: "texture", name: "Texture", icon: "square.grid.3x3.fill", score: textureScore, note: textureNote),
            CategoryResult(id: "darkCircles", name: "Dark Circles", icon: "eye.fill", score: darkCirclesScore, note: darkCirclesNote),
            CategoryResult(id: "pores", name: "Pores", icon: "circle.grid.3x3.fill", score: poresScore, note: poresNote),
            CategoryResult(id: "redness", name: "Redness", icon: "drop.fill", score: rednessScore, note: rednessNote),
            CategoryResult(id: "symmetry", name: "Symmetry", icon: "arrow.left.arrow.right", score: symmetryScore, note: symmetryNote),
            CategoryResult(id: "jawline", name: "Jawline", icon: "face.smiling", score: jawlineScore, note: jawlineNote),
            CategoryResult(id: "hydration", name: "Hydration", icon: "humidity.fill", score: hydrationScore, note: hydrationNote),
            CategoryResult(id: "wrinkles", name: "Wrinkles", icon: "line.3.horizontal", score: wrinklesScore, note: wrinklesNote),
            CategoryResult(id: "beard", name: "Beard", icon: "mustache.fill", score: beardScore, note: beardNote),
            CategoryResult(id: "eyebrows", name: "Eyebrows", icon: "eyebrow", score: eyebrowsScore, note: eyebrowsNote),
            CategoryResult(id: "lips", name: "Lips", icon: "mouth.fill", score: lipsScore, note: lipsNote),
        ]
    }
}
