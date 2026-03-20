import Foundation

// MARK: - Lighting Quality

enum LightingQuality: String {
    case good           // all metrics in ideal range
    case acceptable     // minor issues, usable for analysis
    case poor           // significant issues, warn user

    var displayName: String {
        switch self {
        case .good: "Good lighting"
        case .acceptable: "Acceptable lighting"
        case .poor: "Poor lighting"
        }
    }

    var iconName: String {
        switch self {
        case .good: "checkmark.circle.fill"
        case .acceptable: "exclamationmark.triangle.fill"
        case .poor: "xmark.circle.fill"
        }
    }
}

// MARK: - Lighting Issues

enum LightingIssue: String, CaseIterable {
    case tooDark
    case tooBright
    case unevenLighting
    case harshShadows
    case warmTint
    case coolTint

    var userMessage: String {
        switch self {
        case .tooDark: "Too dark — move closer to a window or turn on more lights"
        case .tooBright: "Too bright — avoid direct sunlight or overhead light"
        case .unevenLighting: "Uneven lighting — face the light source directly"
        case .harshShadows: "Harsh shadows detected — use softer, diffused light"
        case .warmTint: "Warm/yellow tint — switch to daylight or white light"
        case .coolTint: "Cool/blue tint — fluorescent light detected"
        }
    }

    var shortMessage: String {
        switch self {
        case .tooDark: "Too dark"
        case .tooBright: "Too bright"
        case .unevenLighting: "Uneven lighting"
        case .harshShadows: "Harsh shadows"
        case .warmTint: "Warm tint"
        case .coolTint: "Cool tint"
        }
    }
}

// MARK: - Lighting Condition

struct LightingCondition: Sendable {
    let faceBrightness: Float        // 0.0 (black) to 1.0 (white), ideal ~0.45-0.65
    let brightnessBalance: Float     // |left - right| delta, ideal < 0.1
    let contrast: Float              // 0.0 (flat) to 1.0 (extreme), ideal 0.3-0.6
    let colorTemperature: Int        // Kelvin estimate, ideal 5000-6500 (daylight)
    let isoValue: Float
    let exposureDuration: Double
    let qualityScore: LightingQuality
    let issues: [LightingIssue]
    let timestamp: Date

    nonisolated init(
        faceBrightness: Float,
        brightnessBalance: Float,
        contrast: Float,
        colorTemperature: Int = 5500,
        isoValue: Float = 0,
        exposureDuration: Double = 0,
        timestamp: Date = Date()
    ) {
        self.faceBrightness = faceBrightness
        self.brightnessBalance = brightnessBalance
        self.contrast = contrast
        self.colorTemperature = colorTemperature
        self.isoValue = isoValue
        self.exposureDuration = exposureDuration
        self.timestamp = timestamp

        // Compute issues
        var detectedIssues: [LightingIssue] = []
        if faceBrightness < 0.3 { detectedIssues.append(.tooDark) }
        if faceBrightness > 0.8 { detectedIssues.append(.tooBright) }
        if brightnessBalance > 0.2 { detectedIssues.append(.unevenLighting) }
        if contrast > 0.7 { detectedIssues.append(.harshShadows) }
        if colorTemperature < 3500 { detectedIssues.append(.warmTint) }
        if colorTemperature > 7500 { detectedIssues.append(.coolTint) }
        self.issues = detectedIssues

        // Compute quality
        if detectedIssues.isEmpty {
            self.qualityScore = .good
        } else if detectedIssues.contains(.tooDark) || detectedIssues.contains(.tooBright) || detectedIssues.count >= 2 {
            self.qualityScore = .poor
        } else {
            self.qualityScore = .acceptable
        }
    }

    /// Check if this lighting condition is consistent with a baseline session
    func isConsistentWith(_ baseline: LightingCondition, brightnessTolerance: Float = 0.15, balanceTolerance: Float = 0.15) -> Bool {
        let brightnessDelta = abs(faceBrightness - baseline.faceBrightness)
        let balanceDelta = abs(brightnessBalance - baseline.brightnessBalance)
        return brightnessDelta <= brightnessTolerance && balanceDelta <= balanceTolerance
    }

    /// Human-readable summary of the primary issue, if any
    var primaryIssueMessage: String? {
        issues.first?.userMessage
    }
}
