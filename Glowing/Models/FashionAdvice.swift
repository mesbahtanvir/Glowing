import Foundation

// MARK: - Advice Kind

/// The two lenses fashion advice is given through.
enum AdviceKind: String, CaseIterable, Sendable {
    /// Tied to the user's goal, or to the style they appear to be going for.
    case subjective
    /// What tends to work for almost anyone, whatever their taste: color, proportion, fit.
    case objective

    var displayName: String {
        switch self {
        case .subjective: "For your goal"
        case .objective: "Fundamentals"
        }
    }
}

// MARK: - Principle

/// The styling idea a piece of advice rests on. Drives the icon and label on each card.
enum FashionPrinciple: String, CaseIterable, Sendable {
    // Objective: holds up whatever the person's taste.
    case color
    case proportion
    case fit
    case texturePattern = "texture_pattern"
    case formality
    case accessories
    case layering
    case condition

    // Subjective: depends on the goal or the target style.
    case styleMatch = "style_match"
    case occasion
    case impression

    /// Fallback for anything the model invents that we don't recognise.
    case other

    static let objectiveCases: [FashionPrinciple] = [
        .color, .proportion, .fit, .texturePattern, .formality, .accessories, .layering, .condition,
    ]

    static let subjectiveCases: [FashionPrinciple] = [
        .styleMatch, .occasion, .impression,
    ]

    var displayName: String {
        switch self {
        case .color: "Color"
        case .proportion: "Proportion"
        case .fit: "Fit"
        case .texturePattern: "Texture & pattern"
        case .formality: "Formality"
        case .accessories: "Accessories"
        case .layering: "Layering"
        case .condition: "Care & condition"
        case .styleMatch: "Style match"
        case .occasion: "Occasion"
        case .impression: "Impression"
        case .other: "Styling"
        }
    }

    /// SF Symbol name.
    var icon: String {
        switch self {
        case .color: "paintpalette"
        case .proportion: "ruler"
        case .fit: "tshirt"
        case .texturePattern: "square.grid.3x3"
        case .formality: "briefcase"
        case .accessories: "eyeglasses"
        case .layering: "square.stack.3d.up"
        case .condition: "wand.and.stars"
        case .styleMatch: "sparkles"
        case .occasion: "calendar"
        case .impression: "eye"
        case .other: "lightbulb"
        }
    }
}

// MARK: - Impact

/// How much a change moves the whole outfit. Used to put the biggest wins first.
enum AdviceImpact: String, CaseIterable, Sendable {
    case high
    case medium
    case low

    /// Lower sorts first.
    var rank: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}

// MARK: - Goal Alignment

/// A gentle, three-step read on how close the outfit is to the user's goal.
/// Deliberately not a score: it should inform at a glance, not judge.
enum GoalAlignment: String, CaseIterable, Sendable {
    case onTarget = "on_target"
    case close
    case offTarget = "off_target"

    var displayName: String {
        switch self {
        case .onTarget: "On target"
        case .close: "Nearly there"
        case .offTarget: "Not quite yet"
        }
    }

    /// SF Symbol name.
    var icon: String {
        switch self {
        case .onTarget: "checkmark.circle.fill"
        case .close: "arrow.up.right.circle"
        case .offTarget: "ellipsis.circle"
        }
    }
}

// MARK: - Advice Item

/// One concrete piece of advice: what we see, what to try, and why it works.
struct AdviceItem: Identifiable, Equatable, Sendable {
    /// Unique within one `OutfitAdvice`, e.g. "objective-2".
    let id: String
    let kind: AdviceKind
    let principle: FashionPrinciple
    let impact: AdviceImpact
    let title: String
    let observation: String
    let suggestion: String
    let rationale: String

    /// JSON keys of one item in the model's response. The prompt's schema must mention each of these.
    enum JSONKey: String, CaseIterable {
        case principle, impact, title, observation, suggestion, rationale
    }
}

// MARK: - Errors

enum OutfitAdviceError: LocalizedError, Equatable {
    /// The photo doesn't show an outfit we can advise on. `tip` says how to retake it, when the model offered one.
    case noOutfitVisible(tip: String?)
    /// The response parsed as JSON but held nothing we could show.
    case unusableResponse

    var errorDescription: String? {
        switch self {
        case .noOutfitVisible(let tip): tip ?? "We couldn't see an outfit in this photo."
        case .unusableResponse: "We couldn't put together advice this time."
        }
    }
}

// MARK: - Outfit Advice

/// Everything we show after analysing a photo.
struct OutfitAdvice: Equatable, Sendable {
    /// The style the outfit reads as today, e.g. "smart casual". May be empty.
    let detectedStyle: String
    let summary: String
    /// nil when the user gave no goal.
    let goalAlignment: GoalAlignment?
    let strengths: [String]
    let subjective: [AdviceItem]
    let objective: [AdviceItem]
    /// What couldn't be judged from this photo (shoes cropped out, and so on).
    let limitations: [String]
    /// How a better photo would help. Only set when the outfit was visible but the photo was limited.
    let photoTip: String?

    func items(for kind: AdviceKind) -> [AdviceItem] {
        switch kind {
        case .subjective: subjective
        case .objective: objective
        }
    }

    /// The lens to show first. The user's goal leads whenever there is advice for it.
    var defaultKind: AdviceKind {
        subjective.isEmpty ? .objective : .subjective
    }
}

// MARK: - Parsing

extension OutfitAdvice {

    /// JSON keys at the top level of the model's response. The prompt's schema must mention each of these.
    enum JSONKey: String, CaseIterable {
        case isOutfitVisible, photoFeedback, detectedStyle, summary, goalAlignment
        case strengths, subjective, objective, limitations
    }

    /// The most items we show per lens, however many the model returns.
    static let maxItemsPerKind = 4
    /// The most strengths / limitations we show.
    static let maxNotes = 3

    /// Builds advice from the model's JSON.
    ///
    /// Model output is not trusted to be perfectly shaped, so parsing is forgiving: unknown principles
    /// become `.other`, a missing impact becomes `.medium`, and items without a title or suggestion are
    /// dropped. It only throws when there is genuinely nothing to show.
    static func parse(_ json: [String: Any]) throws -> OutfitAdvice {
        let photoFeedback = cleanedString(json[JSONKey.photoFeedback.rawValue])

        if let visible = boolean(json[JSONKey.isOutfitVisible.rawValue]), !visible {
            throw OutfitAdviceError.noOutfitVisible(tip: photoFeedback)
        }

        let summary = cleanedString(json[JSONKey.summary.rawValue]) ?? ""
        let subjective = parseItems(json[JSONKey.subjective.rawValue], kind: .subjective)
        let objective = parseItems(json[JSONKey.objective.rawValue], kind: .objective)

        // A great outfit can legitimately have no items, but it should still have a summary.
        guard !summary.isEmpty || !subjective.isEmpty || !objective.isEmpty else {
            throw OutfitAdviceError.unusableResponse
        }

        let alignmentToken = token(json[JSONKey.goalAlignment.rawValue])
        let alignment = alignmentToken.flatMap { GoalAlignment(rawValue: $0) }

        return OutfitAdvice(
            detectedStyle: cleanedString(json[JSONKey.detectedStyle.rawValue]) ?? "",
            summary: summary,
            goalAlignment: alignment,
            strengths: parseNotes(json[JSONKey.strengths.rawValue]),
            subjective: subjective,
            objective: objective,
            limitations: parseNotes(json[JSONKey.limitations.rawValue]),
            photoTip: photoFeedback
        )
    }

    // MARK: Helpers

    private static func parseItems(_ raw: Any?, kind: AdviceKind) -> [AdviceItem] {
        guard let values = raw as? [Any] else { return [] }

        var items: [AdviceItem] = []
        for (index, value) in values.enumerated() {
            // A stray string, number or null in the list costs only itself, never its neighbours.
            guard let entry = value as? [String: Any],
                  let title = cleanedString(entry[AdviceItem.JSONKey.title.rawValue]),
                  let suggestion = cleanedString(entry[AdviceItem.JSONKey.suggestion.rawValue]) else {
                continue
            }

            let principle = token(entry[AdviceItem.JSONKey.principle.rawValue])
                .flatMap { FashionPrinciple(rawValue: $0) } ?? .other
            let impact = token(entry[AdviceItem.JSONKey.impact.rawValue])
                .flatMap { AdviceImpact(rawValue: $0) } ?? .medium

            items.append(AdviceItem(
                id: "\(kind.rawValue)-\(index)",
                kind: kind,
                principle: principle,
                impact: impact,
                title: title,
                observation: cleanedString(entry[AdviceItem.JSONKey.observation.rawValue]) ?? "",
                suggestion: suggestion,
                rationale: cleanedString(entry[AdviceItem.JSONKey.rationale.rawValue]) ?? ""
            ))
        }

        // Biggest impact first. The index tie-break keeps the model's own order within an impact
        // level, which is more predictable than relying on the sort being stable.
        let ordered = items.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.impact.rank != rhs.element.impact.rank {
                    return lhs.element.impact.rank < rhs.element.impact.rank
                }
                return lhs.offset < rhs.offset
            }
            .map { $0.element }

        return Array(ordered.prefix(maxItemsPerKind))
    }

    private static func parseNotes(_ raw: Any?) -> [String] {
        guard let values = raw as? [Any] else { return [] }
        let notes = values.compactMap { cleanedString($0) }
        return Array(notes.prefix(maxNotes))
    }

    /// Trimmed string, or nil when empty or when the model wrote a placeholder like "null".
    private static func cleanedString(_ raw: Any?) -> String? {
        guard let string = raw as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        switch trimmed.lowercased() {
        case "null", "none", "n/a":
            return nil
        default:
            return trimmed
        }
    }

    /// Lowercased snake_case form of an enum-like string, so "Texture Pattern" and "texture-pattern"
    /// both match "texture_pattern".
    private static func token(_ raw: Any?) -> String? {
        guard let cleaned = cleanedString(raw) else { return nil }
        return cleaned.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "-", with: "_")
    }

    /// Accepts a real boolean or the strings "true" / "false".
    private static func boolean(_ raw: Any?) -> Bool? {
        if let value = raw as? Bool { return value }
        if let string = raw as? String {
            switch string.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "true": return true
            case "false": return false
            default: return nil
            }
        }
        return nil
    }
}
