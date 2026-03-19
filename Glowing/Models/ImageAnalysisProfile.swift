import Foundation

// MARK: - Confidence Level

enum AnalysisConfidence: String, Codable {
    case high
    case medium
    case low
}

// MARK: - Skin Enums

enum SkinType: String, Codable, CaseIterable {
    case oily
    case dry
    case combination
    case normal
    case sensitive

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Hair Enums

enum HairPattern: String, Codable, CaseIterable {
    case straight
    case wavy
    case curly
    case coily

    var displayName: String {
        rawValue.capitalized
    }
}

enum HairThickness: String, Codable, CaseIterable {
    case fine
    case medium
    case coarse

    var displayName: String {
        rawValue.capitalized
    }
}

enum HairLength: String, Codable, CaseIterable {
    case short
    case medium
    case long

    var displayName: String {
        rawValue.capitalized
    }
}

// MARK: - Facial Hair Enums

enum FacialHairStatus: String, Codable, CaseIterable {
    case cleanShaven = "clean_shaven"
    case stubble
    case shortBeard = "short_beard"
    case mediumBeard = "medium_beard"
    case fullBeard = "full_beard"
    case patchy

    var displayName: String {
        switch self {
        case .cleanShaven: "Clean Shaven"
        case .stubble: "Stubble"
        case .shortBeard: "Short Beard"
        case .mediumBeard: "Medium Beard"
        case .fullBeard: "Full Beard"
        case .patchy: "Patchy"
        }
    }
}

enum BeardGrowthPattern: String, Codable, CaseIterable {
    case even
    case patchyCheeks = "patchy_cheeks"
    case patchyChin = "patchy_chin"
    case neckHeavy = "neck_heavy"

    var displayName: String {
        switch self {
        case .even: "Even"
        case .patchyCheeks: "Patchy Cheeks"
        case .patchyChin: "Patchy Chin"
        case .neckHeavy: "Neck Heavy"
        }
    }
}

// MARK: - Lips & Eyebrows Enums

enum LipsCondition: String, Codable, CaseIterable {
    case healthy
    case dry
    case chapped
    case cracked
    case pigmented

    var displayName: String {
        rawValue.capitalized
    }
}

enum EyebrowCondition: String, Codable, CaseIterable {
    case wellGroomed = "well_groomed"
    case sparse
    case overgrown
    case unibrow
    case asymmetric

    var displayName: String {
        switch self {
        case .wellGroomed: "Well Groomed"
        case .sparse: "Sparse"
        case .overgrown: "Overgrown"
        case .unibrow: "Unibrow"
        case .asymmetric: "Asymmetric"
        }
    }
}

// MARK: - Image Analysis Profile

struct ImageAnalysisProfile {
    // Skin
    var skinType: SkinType
    var skinTypeConfidence: AnalysisConfidence
    var isAcneProne: Bool
    var acneProneConfidence: AnalysisConfidence
    var hasPigmentation: Bool
    var hasSensitivity: Bool
    var hasDehydration: Bool
    var hasSunDamage: Bool

    // Hair
    var hairPattern: HairPattern
    var hairPatternConfidence: AnalysisConfidence
    var hairThickness: HairThickness
    var hairThicknessConfidence: AnalysisConfidence
    var hairLength: HairLength
    var scalpConcerns: [String]

    // Lips
    var lipsCondition: LipsCondition
    var needsLipCare: Bool

    // Eyebrows
    var eyebrowCondition: EyebrowCondition
    var needsEyebrowGrooming: Bool

    // Beard/Facial Hair
    var facialHairStatus: FacialHairStatus
    var facialHairStatusConfidence: AnalysisConfidence
    var beardGrowthPattern: BeardGrowthPattern
    var beardGrowthPatternConfidence: AnalysisConfidence
    var canGrowFullBeard: Bool?
    var beardRecommendation: String
    var needsBeardPreferenceInput: Bool

    // Face
    var faceShape: String

    // MARK: - Parsing from LLM JSON

    static func fromJSON(_ json: [String: Any]) -> ImageAnalysisProfile {
        let skin = json["skin"] as? [String: Any] ?? [:]
        let hair = json["hair"] as? [String: Any] ?? [:]
        let lips = json["lips"] as? [String: Any] ?? [:]
        let eyebrows = json["eyebrows"] as? [String: Any] ?? [:]
        let beard = json["beard"] as? [String: Any] ?? [:]
        let face = json["face"] as? [String: Any] ?? [:]

        return ImageAnalysisProfile(
            // Skin
            skinType: SkinType(rawValue: skin["skinType"] as? String ?? "normal") ?? .normal,
            skinTypeConfidence: AnalysisConfidence(rawValue: skin["skinTypeConfidence"] as? String ?? "medium") ?? .medium,
            isAcneProne: skin["isAcneProne"] as? Bool ?? false,
            acneProneConfidence: AnalysisConfidence(rawValue: skin["acneProneConfidence"] as? String ?? "medium") ?? .medium,
            hasPigmentation: skin["hasPigmentation"] as? Bool ?? false,
            hasSensitivity: skin["hasSensitivity"] as? Bool ?? false,
            hasDehydration: skin["hasDehydration"] as? Bool ?? false,
            hasSunDamage: skin["hasSunDamage"] as? Bool ?? false,

            // Hair
            hairPattern: HairPattern(rawValue: hair["hairPattern"] as? String ?? "straight") ?? .straight,
            hairPatternConfidence: AnalysisConfidence(rawValue: hair["hairPatternConfidence"] as? String ?? "high") ?? .high,
            hairThickness: HairThickness(rawValue: hair["hairThickness"] as? String ?? "medium") ?? .medium,
            hairThicknessConfidence: AnalysisConfidence(rawValue: hair["hairThicknessConfidence"] as? String ?? "medium") ?? .medium,
            hairLength: HairLength(rawValue: hair["hairLength"] as? String ?? "short") ?? .short,
            scalpConcerns: hair["scalpConcerns"] as? [String] ?? [],

            // Lips
            lipsCondition: LipsCondition(rawValue: lips["condition"] as? String ?? "healthy") ?? .healthy,
            needsLipCare: lips["needsCare"] as? Bool ?? false,

            // Eyebrows
            eyebrowCondition: EyebrowCondition(rawValue: eyebrows["condition"] as? String ?? "well_groomed") ?? .wellGroomed,
            needsEyebrowGrooming: eyebrows["needsGrooming"] as? Bool ?? false,

            // Beard
            facialHairStatus: FacialHairStatus(rawValue: beard["status"] as? String ?? "clean_shaven") ?? .cleanShaven,
            facialHairStatusConfidence: AnalysisConfidence(rawValue: beard["statusConfidence"] as? String ?? "high") ?? .high,
            beardGrowthPattern: BeardGrowthPattern(rawValue: beard["growthPattern"] as? String ?? "even") ?? .even,
            beardGrowthPatternConfidence: AnalysisConfidence(rawValue: beard["growthPatternConfidence"] as? String ?? "medium") ?? .medium,
            canGrowFullBeard: beard["canGrowFullBeard"] as? Bool,
            beardRecommendation: beard["recommendation"] as? String ?? "",
            needsBeardPreferenceInput: beard["needsUserPreference"] as? Bool ?? false,

            // Face
            faceShape: face["faceShape"] as? String ?? "oval"
        )
    }

    /// Traits that have low or medium confidence and may need user clarification
    var ambiguousTraits: [String] {
        var traits: [String] = []
        if skinTypeConfidence != .high { traits.append("skinType") }
        if hairThicknessConfidence != .high { traits.append("hairThickness") }
        if acneProneConfidence != .high { traits.append("acneProne") }
        if needsBeardPreferenceInput { traits.append("beardPreference") }
        return traits
    }

    /// Convert confirmed profile to a prompt-friendly string for routine generation
    func toPromptDescription() -> String {
        var lines: [String] = []

        lines.append("SKIN: Type=\(skinType.rawValue), Acne-prone=\(isAcneProne), Pigmentation=\(hasPigmentation), Sensitivity=\(hasSensitivity), Dehydration=\(hasDehydration), Sun damage=\(hasSunDamage)")
        lines.append("HAIR: Pattern=\(hairPattern.rawValue), Thickness=\(hairThickness.rawValue), Length=\(hairLength.rawValue), Scalp concerns=\(scalpConcerns.isEmpty ? "none" : scalpConcerns.joined(separator: ", "))")
        lines.append("LIPS: Condition=\(lipsCondition.rawValue), Needs care=\(needsLipCare)")
        lines.append("EYEBROWS: Condition=\(eyebrowCondition.rawValue), Needs grooming=\(needsEyebrowGrooming)")
        lines.append("FACIAL HAIR: Status=\(facialHairStatus.rawValue), Growth=\(beardGrowthPattern.rawValue), Can grow full beard=\(canGrowFullBeard.map(String.init) ?? "unknown"), Recommendation=\(beardRecommendation)")
        lines.append("FACE SHAPE: \(faceShape)")

        return lines.joined(separator: "\n")
    }
}
