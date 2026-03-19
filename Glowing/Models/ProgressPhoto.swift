import Foundation
import SwiftData

enum PhotoAngle: String, Codable, CaseIterable {
    case front
    case left
    case right

    static var faceAngles: [PhotoAngle] { allCases }

    var displayName: String {
        switch self {
        case .front: "Front"
        case .left: "Left Side"
        case .right: "Right Side"
        }
    }

    var guidanceText: String {
        switch self {
        case .front: "Look straight at the camera · Keep your chin level"
        case .left: "Turn 90° left · Align your ear inside the circle"
        case .right: "Turn 90° right · Align your ear inside the circle"
        }
    }

    var positioningTip: String {
        switch self {
        case .front: "Center your face in the oval. Keep shoulders level and visible."
        case .left: "Show your full left profile — ear, jawline, and neck visible."
        case .right: "Show your full right profile — ear, jawline, and neck visible."
        }
    }

    var icon: String {
        switch self {
        case .front: "face.smiling"
        case .left: "arrow.turn.up.left"
        case .right: "arrow.turn.up.right"
        }
    }
}

@Model
final class ProgressPhoto {
    var capturedAt: Date
    var angleRaw: String
    @Attribute(.externalStorage) var imageData: Data?
    var sessionID: UUID
    var note: String?

    var angle: PhotoAngle {
        get { PhotoAngle(rawValue: angleRaw) ?? .front }
        set { angleRaw = newValue.rawValue }
    }

    init(angle: PhotoAngle, imageData: Data?, sessionID: UUID, capturedAt: Date = Date(), note: String? = nil) {
        self.angleRaw = angle.rawValue
        self.imageData = imageData
        self.sessionID = sessionID
        self.capturedAt = capturedAt
        self.note = note
    }
}
