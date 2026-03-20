import Foundation
import SwiftData

// MARK: - Category Entry (Flexible Storage)

/// A single scored category from the AI analysis
struct CategoryEntry: Codable, Identifiable, Sendable {
    let id: String           // e.g. "active_acne", "frizz_level"
    let group: String        // e.g. "skin", "hair", "lips", "under_eye", "facial_hair", "eyebrows"
    let label: String        // e.g. "Active acne", "Frizz level"
    let score: Int           // 0-10
    let note: String         // AI observation
    let confidence: String   // "high", "medium", "low"
}

// MARK: - Category Group Metadata

struct CategoryGroup: Identifiable {
    let id: String           // e.g. "skin", "hair"
    let label: String        // e.g. "Skin", "Hair"
    let icon: String         // SF Symbol
    let displayOrder: Int
    let entries: [CategoryEntry]

    var averageScore: Double {
        guard !entries.isEmpty else { return 0 }
        return Double(entries.reduce(0) { $0 + $1.score }) / Double(entries.count)
    }
}

// MARK: - SkinAnalysis Model

@Model
final class SkinAnalysis {
    var sessionID: UUID
    var analyzedAt: Date

    // Overall
    var overallScore: Int
    var summary: String

    // Flexible category storage — JSON-encoded [CategoryEntry]
    var categoriesJSON: String

    // Profile attributes (not scored, descriptive)
    var skinType: String
    var faceShape: String
    var hairType: String

    // Per-side observations
    var leftSideNote: String
    var rightSideNote: String

    // Actionable recommendations
    var recommendations: String

    // Raw API response
    var rawJSON: String?

    init(
        sessionID: UUID,
        analyzedAt: Date = Date(),
        overallScore: Int,
        summary: String,
        categoriesJSON: String = "[]",
        skinType: String = "",
        faceShape: String = "",
        hairType: String = "",
        leftSideNote: String = "",
        rightSideNote: String = "",
        recommendations: String = "",
        rawJSON: String? = nil
    ) {
        self.sessionID = sessionID
        self.analyzedAt = analyzedAt
        self.overallScore = overallScore
        self.summary = summary
        self.categoriesJSON = categoriesJSON
        self.skinType = skinType
        self.faceShape = faceShape
        self.hairType = hairType
        self.leftSideNote = leftSideNote
        self.rightSideNote = rightSideNote
        self.recommendations = recommendations
        self.rawJSON = rawJSON
    }
}

// MARK: - Category Access Helpers

extension SkinAnalysis {

    /// All decoded category entries
    var categoryEntries: [CategoryEntry] {
        guard let data = categoriesJSON.data(using: .utf8),
              let entries = try? JSONDecoder().decode([CategoryEntry].self, from: data) else {
            return []
        }
        return entries
    }

    /// Categories filtered by group
    func categories(in group: String) -> [CategoryEntry] {
        categoryEntries.filter { $0.group == group }
    }

    var skinCategories: [CategoryEntry] { categories(in: "skin") }
    var hairCategories: [CategoryEntry] { categories(in: "hair") }
    var lipsCategories: [CategoryEntry] { categories(in: "lips") }
    var underEyeCategories: [CategoryEntry] { categories(in: "under_eye") }
    var facialHairCategories: [CategoryEntry] { categories(in: "facial_hair") }
    var eyebrowCategories: [CategoryEntry] { categories(in: "eyebrows") }
    var eyeAreaCategories: [CategoryEntry] { categories(in: "eye_area") }
    var teethCategories: [CategoryEntry] { categories(in: "teeth") }
    var noseCategories: [CategoryEntry] { categories(in: "nose") }
    var facialStructureCategories: [CategoryEntry] { categories(in: "facial_structure") }
    var neckPostureCategories: [CategoryEntry] { categories(in: "neck_posture") }
    var overallImpressionCategories: [CategoryEntry] { categories(in: "overall_impression") }

    var hasHairAnalysis: Bool {
        !hairCategories.isEmpty && hairCategories.contains { $0.score > 0 }
    }

    /// Top concerns: lowest-scoring categories (score <= 5), sorted ascending
    var topConcerns: [CategoryEntry] {
        categoryEntries
            .filter { $0.score > 0 && $0.score <= 5 }
            .sorted { $0.score < $1.score }
            .prefix(5)
            .map { $0 }
    }

    /// Organized into display groups, ordered for the UI
    var displayGroups: [CategoryGroup] {
        let groupOrder: [(id: String, label: String, icon: String, order: Int)] = [
            ("skin", "Skin", "face.smiling", 0),
            ("under_eye", "Under-Eye", "eye.fill", 1),
            ("eye_area", "Eye Area", "eye", 2),
            ("lips", "Lips", "mouth.fill", 3),
            ("teeth", "Teeth / Smile", "mouth", 4),
            ("nose", "Nose", "nose", 5),
            ("hair", "Hair", "comb.fill", 6),
            ("facial_hair", "Facial Hair", "mustache.fill", 7),
            ("eyebrows", "Eyebrows", "eyebrow", 8),
            ("facial_structure", "Facial Structure", "person.crop.rectangle", 9),
            ("neck_posture", "Neck / Posture", "figure.stand", 10),
            ("overall_impression", "Overall Impression", "sparkles", 11),
        ]

        return groupOrder.compactMap { info in
            let entries = categories(in: info.id)
            guard !entries.isEmpty else { return nil }
            return CategoryGroup(
                id: info.id,
                label: info.label,
                icon: info.icon,
                displayOrder: info.order,
                entries: entries
            )
        }
    }
}
