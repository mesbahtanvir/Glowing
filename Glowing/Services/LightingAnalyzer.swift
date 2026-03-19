import Foundation
import UIKit
import CoreImage
import Vision

@MainActor
final class LightingAnalyzer {
    static let shared = LightingAnalyzer()

    private let ciContext = CIContext()

    private init() {}

    // MARK: - Full Analysis (Post-Capture)

    /// Analyze a captured photo for lighting quality. Runs Vision face detection + Core Image analysis.
    func analyzeImage(_ image: UIImage) async -> LightingCondition {
        guard let cgImage = image.cgImage else {
            return LightingCondition(faceBrightness: 0.5, brightnessBalance: 0, contrast: 0.5)
        }

        let ciImage = CIImage(cgImage: cgImage)

        // Detect face region using Vision
        let faceRect = await detectFaceRect(in: cgImage)

        // Use face region or fallback to center crop
        let analysisRegion: CGRect
        if let faceRect {
            // Vision returns normalized coords (bottom-left origin), convert to Core Image coords
            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)
            analysisRegion = CGRect(
                x: faceRect.origin.x * imageWidth,
                y: faceRect.origin.y * imageHeight,
                width: faceRect.width * imageWidth,
                height: faceRect.height * imageHeight
            )
        } else {
            // Fallback: center 60% of image
            let w = CGFloat(cgImage.width)
            let h = CGFloat(cgImage.height)
            analysisRegion = CGRect(x: w * 0.2, y: h * 0.2, width: w * 0.6, height: h * 0.6)
        }

        let brightness = computeAverageBrightness(ciImage: ciImage, region: analysisRegion)
        let balance = computeBrightnessBalance(ciImage: ciImage, region: analysisRegion)
        let contrast = computeContrast(ciImage: ciImage, region: analysisRegion)

        return LightingCondition(
            faceBrightness: brightness,
            brightnessBalance: balance,
            contrast: contrast
        )
    }

    // MARK: - Lightweight Analysis (Live Preview)

    /// Fast analysis for camera preview frames. Skips Vision face detection for speed.
    /// Uses center region as proxy for face.
    nonisolated func analyzeLiveFrame(_ pixelBuffer: CVPixelBuffer) -> LightingCondition {
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let extent = ciImage.extent

        // Use center 50% as approximate face region
        let centerRegion = CGRect(
            x: extent.width * 0.25,
            y: extent.height * 0.25,
            width: extent.width * 0.5,
            height: extent.height * 0.5
        )

        let brightness = computeAverageBrightness(ciImage: ciImage, region: centerRegion)
        let balance = computeBrightnessBalance(ciImage: ciImage, region: centerRegion)

        return LightingCondition(
            faceBrightness: brightness,
            brightnessBalance: balance,
            contrast: 0.5 // skip histogram for live performance
        )
    }

    // MARK: - Vision Face Detection

    private func detectFaceRect(in cgImage: CGImage) async -> CGRect? {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, error in
                guard error == nil,
                      let results = request.results as? [VNFaceObservation],
                      let face = results.first else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: face.boundingBox)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: nil)
            }
        }
    }

    // MARK: - Core Image Metrics

    private nonisolated func computeAverageBrightness(ciImage: CIImage, region: CGRect) -> Float {
        guard let filter = CIFilter(name: "CIAreaAverage") else { return 0.5 }
        let cropped = ciImage.cropped(to: region)
        filter.setValue(cropped, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: cropped.extent), forKey: "inputExtent")

        guard let outputImage = filter.outputImage else { return 0.5 }

        var bitmap = [UInt8](repeating: 0, count: 4)
        let context = CIContext()
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Convert RGB to perceived brightness (luminance)
        let r = Float(bitmap[0]) / 255.0
        let g = Float(bitmap[1]) / 255.0
        let b = Float(bitmap[2]) / 255.0
        return 0.299 * r + 0.587 * g + 0.114 * b
    }

    private nonisolated func computeBrightnessBalance(ciImage: CIImage, region: CGRect) -> Float {
        let midX = region.midX
        let leftRegion = CGRect(x: region.minX, y: region.minY, width: midX - region.minX, height: region.height)
        let rightRegion = CGRect(x: midX, y: region.minY, width: region.maxX - midX, height: region.height)

        let leftBrightness = computeAverageBrightness(ciImage: ciImage, region: leftRegion)
        let rightBrightness = computeAverageBrightness(ciImage: ciImage, region: rightRegion)

        return abs(leftBrightness - rightBrightness)
    }

    private nonisolated func computeContrast(ciImage: CIImage, region: CGRect) -> Float {
        guard let filter = CIFilter(name: "CIAreaHistogram") else { return 0.5 }
        let cropped = ciImage.cropped(to: region)
        filter.setValue(cropped, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgRect: cropped.extent), forKey: "inputExtent")
        filter.setValue(64, forKey: "inputCount") // 64 bins
        filter.setValue(1.0, forKey: "inputScale")

        guard let outputImage = filter.outputImage else { return 0.5 }

        var histogram = [UInt8](repeating: 0, count: 64 * 4)
        let context = CIContext()
        context.render(
            outputImage,
            toBitmap: &histogram,
            rowBytes: 64 * 4,
            bounds: CGRect(x: 0, y: 0, width: 64, height: 1),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )

        // Find the range of non-zero bins for luminance channel (use green as proxy)
        var minBin = 63
        var maxBin = 0
        for i in 0..<64 {
            let value = histogram[i * 4 + 1] // green channel
            if value > 2 { // threshold to skip noise
                minBin = min(minBin, i)
                maxBin = max(maxBin, i)
            }
        }

        return maxBin > minBin ? Float(maxBin - minBin) / 63.0 : 0.5
    }

    // MARK: - EXIF Metadata Extraction

    /// Extract lighting-relevant EXIF data from captured photo data
    nonisolated func extractEXIFLighting(from imageData: Data) -> (iso: Float, exposure: Double, colorTemp: Int) {
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] else {
            return (iso: 0, exposure: 0, colorTemp: 5500)
        }

        let iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber])?.first?.floatValue ?? 0
        let exposure = (exif[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue ?? 0

        // White balance / color temperature from EXIF (if available)
        let colorTemp: Int
        if let wb = exif[kCGImagePropertyExifWhiteBalance as String] as? Int, wb == 0 {
            colorTemp = 5500 // auto white balance, assume daylight
        } else {
            colorTemp = 5500 // default if not available
        }

        return (iso: iso, exposure: exposure, colorTemp: colorTemp)
    }
}
