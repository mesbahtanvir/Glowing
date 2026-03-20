import CoreGraphics
import Foundation

// MARK: - Face Guidance Readiness

enum FaceGuidanceReadiness: String {
    case ready       // no issues, good to capture
    case adjusting   // 1 minor issue
    case notReady    // no face or 2+ issues
}

// MARK: - Face Guidance Issues

enum FaceGuidanceIssue: String, CaseIterable {
    case noFaceDetected
    case faceTooClose
    case faceTooFar
    case faceSlightlyClose
    case faceSlightlyFar
    case faceOffCenterLeft
    case faceOffCenterRight
    case faceOffCenterUp
    case faceOffCenterDown
    case headAngleNeedsTurnLeft
    case headAngleNeedsTurnRight
    case headAngleShouldBeStraight

    var shortMessage: String {
        switch self {
        case .noFaceDetected: "Position your face in the frame"
        case .faceTooClose: "Move back"
        case .faceTooFar: "Move closer"
        case .faceSlightlyClose: "Move back a little"
        case .faceSlightlyFar: "Move a bit closer"
        case .faceOffCenterLeft: "Move right"
        case .faceOffCenterRight: "Move left"
        case .faceOffCenterUp: "Move down a little"
        case .faceOffCenterDown: "Move up a little"
        case .headAngleNeedsTurnLeft: "Turn left more"
        case .headAngleNeedsTurnRight: "Turn right more"
        case .headAngleShouldBeStraight: "Look straight ahead"
        }
    }

    /// Whether this issue alone should block readiness
    var isCritical: Bool {
        switch self {
        case .noFaceDetected, .faceTooClose, .faceTooFar:
            return true
        default:
            return false
        }
    }
}

// MARK: - Face Guidance

struct FaceGuidance: Sendable {
    let faceBoundingBox: CGRect?   // Vision normalized coords (0-1), nil = no face
    let faceYawDegrees: Float?     // 0=straight, negative=turned left, positive=turned right
    let targetAngle: PhotoAngle    // what angle user is trying to capture
    let issues: [FaceGuidanceIssue]
    let readiness: FaceGuidanceReadiness

    /// How well the face fills the guide ellipse: 1.0 = perfect fit, <1 = too far, >1 = too close
    let fitRatio: CGFloat?

    // Guide ellipse sizes (points) for each angle
    static let frontEllipse = CGSize(width: 200, height: 270)
    static let sideEllipse = CGSize(width: 170, height: 240)

    nonisolated init(
        faceBoundingBox: CGRect?,
        faceYawDegrees: Float?,
        targetAngle: PhotoAngle,
        screenSize: CGSize = CGSize(width: 393, height: 852)
    ) {
        self.faceBoundingBox = faceBoundingBox
        self.faceYawDegrees = faceYawDegrees
        self.targetAngle = targetAngle

        // Compute issues
        var detectedIssues: [FaceGuidanceIssue] = []

        guard let bbox = faceBoundingBox else {
            self.issues = [.noFaceDetected]
            self.readiness = .notReady
            self.fitRatio = nil
            return
        }

        // --- Size check relative to the guide ellipse ---
        // The guide ellipse height as a fraction of screen height is the ideal face bbox height.
        // Vision bbox is in normalized coords (0-1), where height maps to the full frame.
        let ellipse = (targetAngle == .front || targetAngle == .smile) ? Self.frontEllipse : Self.sideEllipse
        // The ellipse is offset up by 20pt, so it's roughly centered in the camera area.
        // The ideal Vision face height = ellipse height / screen height
        // We use ~85% of the ellipse as the ideal face fill (head doesn't fill the entire oval)
        let idealFaceHeight = (ellipse.height * 0.85) / screenSize.height
        let currentFitRatio = bbox.height / idealFaceHeight
        self.fitRatio = currentFitRatio

        // --- Size check relative to the guide ellipse ---
        // Tight bands: ±10% is "good fit", ±25% is "slightly off", beyond is critical
        if currentFitRatio > 1.25 {
            detectedIssues.append(.faceTooClose)
        } else if currentFitRatio > 1.10 {
            detectedIssues.append(.faceSlightlyClose)
        } else if currentFitRatio < 0.75 {
            detectedIssues.append(.faceTooFar)
        } else if currentFitRatio < 0.90 {
            detectedIssues.append(.faceSlightlyFar)
        }

        // --- Center checks ---
        // Face center vs frame center (0.5, 0.5) in Vision normalized coords
        // With .leftMirrored orientation on front camera, Vision X is flipped:
        // user's left appears as higher X in Vision coords.
        // So we swap left/right to give correct guidance from the user's perspective.
        let faceCenterX = bbox.midX
        let faceCenterY = bbox.midY
        let centerThreshold: CGFloat = 0.07

        if faceCenterX < 0.5 - centerThreshold {
            detectedIssues.append(.faceOffCenterRight) // mirrored: low X = user is too far right
        } else if faceCenterX > 0.5 + centerThreshold {
            detectedIssues.append(.faceOffCenterLeft)  // mirrored: high X = user is too far left
        }

        if faceCenterY < 0.5 - centerThreshold {
            detectedIssues.append(.faceOffCenterDown) // Vision Y is bottom-up
        } else if faceCenterY > 0.5 + centerThreshold {
            detectedIssues.append(.faceOffCenterUp)
        }

        // --- Head angle checks based on target ---
        // With .leftMirrored on front camera, Vision yaw is inverted relative to the user:
        // user turns their head to their left → Vision reports positive yaw
        // user turns their head to their right → Vision reports negative yaw
        if let yaw = faceYawDegrees {
            switch targetAngle {
            case .front, .smile:
                // Must be within 10° of straight
                if abs(yaw) > 10 {
                    detectedIssues.append(.headAngleShouldBeStraight)
                }
            case .left:
                // User's left profile: with mirroring, yaw should be positive, at least 25°
                if yaw < 25 {
                    detectedIssues.append(.headAngleNeedsTurnLeft)
                }
            case .right:
                // User's right profile: with mirroring, yaw should be negative, at least -25°
                if yaw > -25 {
                    detectedIssues.append(.headAngleNeedsTurnRight)
                }
            }
        }

        self.issues = detectedIssues

        // Compute readiness — strict: any issue prevents "ready"
        if detectedIssues.isEmpty {
            self.readiness = .ready
        } else if detectedIssues.allSatisfy({ !$0.isCritical }) {
            self.readiness = .adjusting
        } else {
            self.readiness = .notReady
        }
    }

    /// The most important issue to show the user
    var primaryIssue: FaceGuidanceIssue? {
        issues.first
    }
}
