import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Turns whatever the camera or photo library hands us into a small, upright JPEG that is cheap to send.
///
/// - Applies the photo's orientation, so the pixels are upright with no orientation tag to misread.
/// - Shrinks so the longest side is at most `maxDimension`, and never enlarges a small photo.
/// - Drops EXIF and other metadata, including GPS location. Only pixels are re-encoded.
///
/// ImageIO's thumbnailing decodes straight to the target size, so a 48 MP photo never has to be held
/// in memory at full resolution. Every function is `nonisolated` so the work can run off the main thread.
enum OutfitImagePreparer {

    /// The longest-side pixel count to render at: never above `limit`, never above the original.
    /// Returns 0 when there is nothing sensible to render.
    nonisolated static func targetLongestSide(width: Int, height: Int, limit: Int) -> Int {
        let longest = max(width, height)
        guard longest > 0, limit > 0 else { return 0 }
        return min(longest, limit)
    }

    /// Returns upright, metadata-free JPEG data, or nil if `data` isn't a readable image.
    nonisolated static func prepareJPEG(
        from data: Data,
        maxDimension: Int = 1280,
        quality: Double = 0.72
    ) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary),
              CGImageSourceGetCount(source) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int else {
            return nil
        }

        let side = targetLongestSide(width: width, height: height, limit: maxDimension)
        guard side > 0 else { return nil }

        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // bakes in the orientation
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: side,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            return nil
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            return nil
        }

        // Only the quality is passed on purpose: nothing from the source's metadata is carried over.
        let destinationOptions: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(destination, image, destinationOptions as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return output as Data
    }
}
