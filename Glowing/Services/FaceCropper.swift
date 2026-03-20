import UIKit
import Vision

/// Crops a photo to the face region including hair, forehead, and chin.
/// Uses Vision framework for on-device face detection.
enum FaceCropper {

    /// Crop the image to the detected face region with generous padding for hair.
    /// Returns the original image if no face is detected.
    static func cropToFace(_ image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: visionOrientation(from: image), options: [:])

        do {
            try handler.perform([request])
        } catch {
            return image
        }

        guard let face = request.results?.first else {
            return image
        }

        // Vision bbox is in normalized coords (0-1), origin at bottom-left
        let bbox = face.boundingBox
        let imageWidth = CGFloat(cgImage.width)
        let imageHeight = CGFloat(cgImage.height)

        // Convert Vision coords to image pixel coords (flip Y)
        let faceX = bbox.origin.x * imageWidth
        let faceY = (1 - bbox.origin.y - bbox.height) * imageHeight
        let faceW = bbox.width * imageWidth
        let faceH = bbox.height * imageHeight

        // Expand the crop region:
        // - 60% above for hair/forehead (face bbox typically starts at brow)
        // - 25% below for chin/neck
        // - 30% on each side for ears and some context
        let topPadding = faceH * 0.60
        let bottomPadding = faceH * 0.25
        let sidePadding = faceW * 0.30

        let cropX = max(0, faceX - sidePadding)
        let cropY = max(0, faceY - topPadding)
        let cropRight = min(imageWidth, faceX + faceW + sidePadding)
        let cropBottom = min(imageHeight, faceY + faceH + bottomPadding)
        let cropW = cropRight - cropX
        let cropH = cropBottom - cropY

        let cropRect = CGRect(x: cropX, y: cropY, width: cropW, height: cropH)

        guard let cropped = cgImage.cropping(to: cropRect) else {
            return image
        }

        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    /// Crop face from JPEG data, returning cropped JPEG data.
    /// Returns original data if no face detected.
    static func cropToFace(jpegData: Data, compressionQuality: CGFloat = 0.8) -> Data {
        guard let image = UIImage(data: jpegData) else { return jpegData }
        let cropped = cropToFace(image)
        return cropped.jpegData(compressionQuality: compressionQuality) ?? jpegData
    }

    // MARK: - Private

    private static func visionOrientation(from image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}
