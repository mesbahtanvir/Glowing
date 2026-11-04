import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Glowing

// Shared fixtures, helpers and stubs for the fashion-advice tests.

// MARK: - JSON fixtures

let fullResponseJSON = """
{
  "isOutfitVisible": true,
  "photoFeedback": null,
  "detectedStyle": "  smart casual ",
  "summary": "A relaxed look. Swap the hoodie for a collared layer.",
  "goalAlignment": "close",
  "strengths": ["Clean navy chinos", "   ", "Matching brown belt and shoes"],
  "subjective": [
    {"principle": "occasion", "impact": "high", "title": "Swap the hoodie", "observation": "The hoodie reads as weekend wear.", "suggestion": "Try a knit polo.", "rationale": "A collar signals effort."}
  ],
  "objective": [
    {"principle": "color", "impact": "low", "title": "Add a lighter piece", "observation": "Everything is dark.", "suggestion": "Try a white tee.", "rationale": "Contrast shows where to look."},
    {"principle": "proportion", "impact": "high", "title": "Stagger the hems", "observation": "Two hems stack at the hip.", "suggestion": "Tuck the tee.", "rationale": "Staggered hems add rhythm."}
  ],
  "limitations": ["Shoes are cropped out of the photo."]
}
"""

/// Parses JSON text into a dictionary. Records an issue, and returns an empty dictionary, if the text
/// isn't a JSON object, so a typo in a fixture shows up as itself rather than as a confusing failure.
func object(_ json: String) -> [String: Any] {
    guard let data = json.data(using: .utf8),
          let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        Issue.record("Fixture is not valid JSON: \(json.prefix(120))")
        return [:]
    }
    return parsed
}

/// One advice item as JSON text, for building responses.
func itemJSON(
    principle: String = "color",
    impact: String = "medium",
    title: String,
    suggestion: String = "Try something else."
) -> String {
    """
    {"principle": "\(principle)", "impact": "\(impact)", "title": "\(title)", "observation": "Seen.", "suggestion": "\(suggestion)", "rationale": "Because."}
    """
}

/// A response with a summary and the given item JSON in each lens. `extra` is appended inside the
/// object and must start with a comma, e.g. `, "goalAlignment": "close"`.
func responseJSON(objective: [String] = [], subjective: [String] = [], extra: String = "") -> String {
    "{\"summary\": \"ok\", \"objective\": [\(objective.joined(separator: ","))], \"subjective\": [\(subjective.joined(separator: ","))]\(extra)}"
}

/// Parses `json`, returning either the advice or the typed error so a test can compare with `==`.
@MainActor
func parseResult(_ json: String) -> Result<OutfitAdvice, OutfitAdviceError> {
    do {
        return .success(try OutfitAdvice.parse(object(json)))
    } catch let error as OutfitAdviceError {
        return .failure(error)
    } catch {
        Issue.record("Unexpected error type: \(error)")
        return .failure(.unusableResponse)
    }
}

/// Parses `json` and returns the advice, recording an issue and returning nil if it throws.
@MainActor
func parsedAdvice(_ json: String) -> OutfitAdvice? {
    switch parseResult(json) {
    case .success(let advice):
        return advice
    case .failure(let error):
        Issue.record("Expected advice but parsing threw \(error)")
        return nil
    }
}

func isSuccess<Success, Failure: Error>(_ result: Result<Success, Failure>) -> Bool {
    if case .success = result { return true }
    return false
}

/// Runs `work`, expecting it to throw exactly `expected`. `label` says which case failed.
@MainActor
func expectThrows(_ expected: OutfitAdviceError, _ label: String = "", _ work: () throws -> Void) {
    do {
        try work()
        Issue.record("Expected \(expected) but nothing was thrown. \(label)")
    } catch let error as OutfitAdviceError {
        #expect(error == expected, "\(label)")
    } catch {
        Issue.record("Unexpected error \(error). \(label)")
    }
}

@MainActor
func sampleAdvice(summary: String = "Looks good.") -> OutfitAdvice {
    OutfitAdvice(
        detectedStyle: "casual",
        summary: summary,
        goalAlignment: nil,
        strengths: [],
        subjective: [],
        objective: [],
        limitations: [],
        photoTip: nil
    )
}

/// Lists a string's Unicode scalars in hex, so a failure message can show invisible characters.
func scalars(_ text: String) -> String {
    text.unicodeScalars
        .map { "U+" + String($0.value, radix: 16, uppercase: true) }
        .joined(separator: " ")
}

// MARK: - Images

/// A solid-colour image of exactly the given pixel size, encoded as `type`, written with `metadata`.
/// `hasAlpha` keeps a transparent channel in formats that can hold one.
func makeImageData(
    width: Int,
    height: Int,
    type: UTType = .jpeg,
    hasAlpha: Bool = false,
    metadata: [CFString: Any] = [:]
) -> Data {
    let alpha = hasAlpha ? CGImageAlphaInfo.premultipliedLast : CGImageAlphaInfo.noneSkipLast
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: alpha.rawValue
    ) else {
        return Data()
    }
    context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: hasAlpha ? 0.5 : 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    guard let image = context.makeImage() else { return Data() }

    let output = NSMutableData()
    guard let destination = CGImageDestinationCreateWithData(
        output as CFMutableData,
        type.identifier as CFString,
        1,
        nil
    ) else {
        return Data()
    }

    var properties = metadata
    if type == .jpeg {
        properties[kCGImageDestinationLossyCompressionQuality] = 0.9
    }
    CGImageDestinationAddImage(destination, image, properties as CFDictionary)
    guard CGImageDestinationFinalize(destination) else { return Data() }
    return output as Data
}

/// A solid-colour JPEG of exactly the given pixel size, optionally carrying GPS metadata.
func makeJPEG(width: Int, height: Int, withGPS: Bool = false) -> Data {
    makeImageData(width: width, height: height, metadata: withGPS ? gpsMetadata() : [:])
}

func gpsMetadata() -> [CFString: Any] {
    let gps: [CFString: Any] = [
        kCGImagePropertyGPSLatitude: 43.65,
        kCGImagePropertyGPSLatitudeRef: "N",
        kCGImagePropertyGPSLongitude: 79.38,
        kCGImagePropertyGPSLongitudeRef: "W",
    ]
    return [kCGImagePropertyGPSDictionary: gps]
}

/// Camera make and model plus a capture time: the metadata that identifies a device and a moment.
func deviceMetadata() -> [CFString: Any] {
    let tiff: [CFString: Any] = [
        kCGImagePropertyTIFFMake: "TestCam",
        kCGImagePropertyTIFFModel: "Model 1",
    ]
    let exif: [CFString: Any] = [
        kCGImagePropertyExifDateTimeOriginal: "2026:01:02 03:04:05",
    ]
    return [
        kCGImagePropertyTIFFDictionary: tiff,
        kCGImagePropertyExifDictionary: exif,
    ]
}

func imageProperties(of data: Data) -> [CFString: Any]? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
    return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
}

/// The pixel size recorded in an image's properties, or nil if it can't be read.
func pixelSize(of data: Data?) -> (width: Int, height: Int)? {
    guard let data,
          let properties = imageProperties(of: data),
          let width = properties[kCGImagePropertyPixelWidth] as? Int,
          let height = properties[kCGImagePropertyPixelHeight] as? Int else {
        return nil
    }
    return (width, height)
}

/// True if the data starts with the JPEG signature.
func isJPEG(_ data: Data) -> Bool {
    data.starts(with: [0xFF, 0xD8, 0xFF])
}

// MARK: - Stub advisors

/// Answers every request with `outcome`, which a test can change between calls, and records what it was asked.
@MainActor
final class StubAdvisor: OutfitAdvising {
    var outcome: Result<OutfitAdvice, Error>
    private(set) var callCount = 0
    private(set) var lastGoal: StyleGoal?
    private(set) var lastPhoto: Data?

    init(_ outcome: Result<OutfitAdvice, Error>) {
        self.outcome = outcome
    }

    func adviseOnOutfit(photoJPEG: Data, goal: StyleGoal?) async throws -> OutfitAdvice {
        callCount += 1
        lastGoal = goal
        lastPhoto = photoJPEG
        return try outcome.get()
    }
}

/// Never answers; only ends when the task is cancelled.
@MainActor
final class SuspendingAdvisor: OutfitAdvising {
    func adviseOnOutfit(photoJPEG: Data, goal: StyleGoal?) async throws -> OutfitAdvice {
        try await Task.sleep(for: .seconds(60))
        return sampleAdvice()
    }
}

/// Answers every request with "answer for <goal>", except that a request whose goal is "slow" waits
/// for `release()` first. It ignores cancellation, like a service that answers anyway, so a test can
/// make a superseded analysis finish *after* a newer one.
///
/// It keys off the goal rather than call order, and `release()` works even if it arrives first,
/// so the test cannot hang whatever order the tasks happen to run in.
@MainActor
final class GatedAdvisor: OutfitAdvising {
    private var gate: CheckedContinuation<Void, Never>?
    private var isReleased = false
    private(set) var callCount = 0

    func adviseOnOutfit(photoJPEG: Data, goal: StyleGoal?) async throws -> OutfitAdvice {
        callCount += 1
        let name = goal?.text ?? "no goal"
        if name == "slow" && !isReleased {
            await withCheckedContinuation { continuation in
                gate = continuation
            }
        }
        return sampleAdvice(summary: "answer for \(name)")
    }

    func release() {
        isReleased = true
        gate?.resume()
        gate = nil
    }
}
