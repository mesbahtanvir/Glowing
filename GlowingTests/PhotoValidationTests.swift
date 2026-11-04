import Testing
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
@testable import Glowing

/// What `OutfitImagePreparer` accepts, rejects, and promises about what it produces.
///
/// The expectations about ImageIO's output (sizes, orientation, metadata) describe how the framework is
/// meant to behave. If one fails, check that expectation against the framework before suspecting the code.
@MainActor
@Suite("Photo preparation validation")
struct PhotoPreparationValidationTests {

    // MARK: Sizing rule

    @Test func theSizingRuleHoldsAtItsBoundaries() {
        let cases: [(width: Int, height: Int, limit: Int, expected: Int)] = [
            (1280, 720, 1280, 1280),     // exactly at the limit
            (1281, 720, 1280, 1280),     // one over
            (1279, 720, 1280, 1279),     // one under
            (720, 1280, 1280, 1280),     // portrait
            (1, 1, 1280, 1),             // the smallest possible photo
            (4000, 100, 1280, 1280),     // a panorama
            (100, 4000, 1280, 1280),     // a very tall strip
            (Int.max, 1, 1280, 1280),    // absurd, but must not overflow
            (0, 0, 1280, 0),             // nothing to render
            (-5, -5, 1280, 0),           // nonsense dimensions
            (100, 100, 0, 0),            // no room at all
            (100, 100, -1, 0),           // negative limit
        ]
        for c in cases {
            let side = OutfitImagePreparer.targetLongestSide(width: c.width, height: c.height, limit: c.limit)
            #expect(side == c.expected, "\(c.width)x\(c.height) with limit \(c.limit) gave \(side), expected \(c.expected)")
        }
    }

    // MARK: What comes out

    @Test func theOutputIsAlwaysAJPEG() {
        let sources: [(name: String, data: Data)] = [
            ("jpeg", makeImageData(width: 120, height: 80)),
            ("png", makeImageData(width: 120, height: 80, type: .png)),
            ("png with transparency", makeImageData(width: 120, height: 80, type: .png, hasAlpha: true)),
            ("tiff", makeImageData(width: 120, height: 80, type: .tiff)),
        ]
        for (name, data) in sources {
            #expect(!data.isEmpty, "the \(name) fixture should have been created")
            let prepared = OutfitImagePreparer.prepareJPEG(from: data)
            #expect(prepared.map(isJPEG) == true, "\(name) should come out as a JPEG")
        }
    }

    @Test func theLongestSideIsCappedAndNeverEnlarged() {
        let cases: [(width: Int, height: Int, limit: Int, expectedWidth: Int, expectedHeight: Int)] = [
            (2000, 1000, 300, 300, 150),     // landscape, shrunk
            (1000, 2000, 300, 150, 300),     // portrait, shrunk
            (1200, 1200, 300, 300, 300),     // square, shrunk
            (4000, 100, 1280, 1280, 32),     // panorama, shrunk
            (200, 100, 300, 200, 100),       // already small: left alone
            (300, 200, 300, 300, 200),       // exactly at the limit: left alone
            (1, 1, 300, 1, 1),               // one pixel
        ]
        for c in cases {
            let source = makeJPEG(width: c.width, height: c.height)
            let size = pixelSize(of: OutfitImagePreparer.prepareJPEG(from: source, maxDimension: c.limit))
            let label = "\(c.width)x\(c.height) capped at \(c.limit) should be about \(c.expectedWidth)x\(c.expectedHeight)"
            #expect(size != nil, "\(label): no output")
            if let size {
                // One pixel of slack for rounding on the shorter side.
                #expect(abs(size.width - c.expectedWidth) <= 1, "\(label), got \(size.width)x\(size.height)")
                #expect(abs(size.height - c.expectedHeight) <= 1, "\(label), got \(size.width)x\(size.height)")
            }
        }
    }

    @Test func rotatedPhotosComeOutUpright() {
        // Stored 200 wide by 100 tall but tagged "rotate 90 degrees clockwise", so it is shown 100 by 200.
        let source = makeImageData(width: 200, height: 100, metadata: [kCGImagePropertyOrientation: 6])
        #expect(imageProperties(of: source)?[kCGImagePropertyOrientation] as? Int == 6, "the fixture should carry the orientation tag")

        let prepared = OutfitImagePreparer.prepareJPEG(from: source)
        let size = pixelSize(of: prepared)
        #expect(size?.width == 100)
        #expect(size?.height == 200)

        // No tag may be left behind, or the rotation would be applied a second time.
        let orientation = prepared.flatMap(imageProperties(of:))?[kCGImagePropertyOrientation] as? Int
        #expect(orientation == nil || orientation == 1)
    }

    // MARK: Privacy

    @Test func locationAndDeviceMetadataDoNotSurvive() {
        let metadata = gpsMetadata().merging(deviceMetadata()) { first, _ in first }
        let source = makeImageData(width: 200, height: 100, metadata: metadata)

        // Make sure the fixture really carries what we expect to see removed.
        let sourceProperties = imageProperties(of: source)
        #expect(sourceProperties?[kCGImagePropertyGPSDictionary] != nil, "the fixture should carry a location")
        let sourceTIFF = sourceProperties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(sourceTIFF?[kCGImagePropertyTIFFMake] as? String == "TestCam", "the fixture should carry a camera make")
        let sourceExif = sourceProperties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(sourceExif?[kCGImagePropertyExifDateTimeOriginal] != nil, "the fixture should carry a capture time")

        let properties = OutfitImagePreparer.prepareJPEG(from: source).flatMap(imageProperties(of:))
        #expect(properties != nil)
        #expect(properties?[kCGImagePropertyGPSDictionary] == nil, "location survived")
        let tiff = properties?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        #expect(tiff?[kCGImagePropertyTIFFMake] == nil, "camera make survived")
        #expect(tiff?[kCGImagePropertyTIFFModel] == nil, "camera model survived")
        let exif = properties?[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifDateTimeOriginal] == nil, "capture time survived")
    }

    // MARK: What is refused

    @Test func unreadableInputYieldsNothing() {
        let inputs: [(name: String, data: Data)] = [
            ("empty data", Data()),
            ("plain text", Data("not an image".utf8)),
            ("a JPEG signature and nothing else", Data([0xFF, 0xD8, 0xFF])),
            ("256 arbitrary bytes", Data((0..<256).map { UInt8($0) })),
            ("1 KB of zeros", Data(count: 1024)),
        ]
        for (name, data) in inputs {
            #expect(OutfitImagePreparer.prepareJPEG(from: data) == nil, "\(name) should not be accepted")
        }
    }

    @Test func aLimitWithNoRoomIsRefused() {
        let source = makeJPEG(width: 100, height: 100)
        #expect(OutfitImagePreparer.prepareJPEG(from: source, maxDimension: 0) == nil)
        #expect(OutfitImagePreparer.prepareJPEG(from: source, maxDimension: -10) == nil)
    }
}

/// How the view model treats a photo on the way in.
@MainActor
@Suite("Photo intake validation")
struct PhotoIntakeValidationTests {

    private let photo = makeJPEG(width: 64, height: 48)

    private func makeViewModel(with data: Data? = nil) -> OutfitAdviceViewModel {
        let viewModel = OutfitAdviceViewModel(advisor: StubAdvisor(.success(sampleAdvice())))
        if let data {
            viewModel.setPhoto(preparedJPEG: data)
        }
        return viewModel
    }

    // MARK: setPhoto

    @Test func aPreparedPhotoMustBeDecodable() {
        let rejected: [(name: String, data: Data)] = [
            ("empty data", Data()),
            ("plain text", Data("hello".utf8)),
            ("a JPEG signature alone", Data([0xFF, 0xD8, 0xFF])),
        ]
        for (name, data) in rejected {
            let viewModel = makeViewModel()
            viewModel.setPhoto(preparedJPEG: data)

            #expect(!viewModel.hasPhoto, "\(name) should be rejected")
            #expect(viewModel.previewImage == nil, "\(name) should leave no preview")
            #expect(viewModel.notice?.kind == .error, "\(name) should explain itself")
            #expect(viewModel.notice?.message == OutfitAdviceViewModel.unreadablePhotoMessage)
        }
    }

    @Test func aBadPhotoDoesNotReplaceAGoodOne() {
        let viewModel = makeViewModel(with: photo)
        viewModel.setPhoto(preparedJPEG: Data("junk".utf8))

        #expect(viewModel.photoJPEG == photo)
        #expect(viewModel.previewImage != nil)
        #expect(viewModel.notice?.kind == .error)
    }

    @Test func aGoodPhotoClearsTheNoticeLeftByABadOne() {
        let viewModel = makeViewModel()
        viewModel.setPhoto(preparedJPEG: Data("junk".utf8))
        #expect(viewModel.notice != nil)

        viewModel.setPhoto(preparedJPEG: photo)
        #expect(viewModel.notice == nil)
        #expect(viewModel.hasPhoto)
    }

    // MARK: loadPhoto

    @Test func loadingAcceptsEveryFormatTheSystemCanRead() async {
        let formats: [(name: String, data: Data)] = [
            ("jpeg", makeImageData(width: 90, height: 60)),
            ("png", makeImageData(width: 90, height: 60, type: .png)),
            ("png with transparency", makeImageData(width: 90, height: 60, type: .png, hasAlpha: true)),
            ("tiff", makeImageData(width: 90, height: 60, type: .tiff)),
        ]
        for (name, data) in formats {
            let viewModel = makeViewModel()
            await viewModel.loadPhoto { data }

            #expect(viewModel.hasPhoto, "\(name) should load")
            #expect(viewModel.photoJPEG.map(isJPEG) == true, "\(name) should be stored as a JPEG")
            #expect(viewModel.notice == nil, "\(name) should load without a notice")
            #expect(!viewModel.isLoadingPhoto, "\(name) should finish loading")
        }
    }

    @Test func loadingRejectsWhatItCannotRead() async {
        let unreadable: [(name: String, data: Data?)] = [
            ("nothing at all", nil),
            ("empty data", Data()),
            ("plain text", Data("not an image".utf8)),
        ]
        for (name, data) in unreadable {
            let viewModel = makeViewModel()
            await viewModel.loadPhoto { data }

            #expect(!viewModel.hasPhoto, "\(name) should not become a photo")
            #expect(!viewModel.isLoadingPhoto, "\(name) should stop the loading state")
            #expect(viewModel.notice?.message == OutfitAdviceViewModel.unreadablePhotoMessage, "\(name) should explain itself")
        }
    }

    @Test func anUnreadableReplacementKeepsTheCurrentPhoto() async {
        let viewModel = makeViewModel(with: photo)

        await viewModel.loadPhoto { Data("not an image".utf8) }

        #expect(viewModel.photoJPEG == photo)
        #expect(viewModel.previewImage != nil)
        #expect(viewModel.notice?.kind == .error)
        #expect(!viewModel.isLoadingPhoto)
    }

    // MARK: Tickets

    @Test func startingALoadClearsAnOldNotice() {
        let viewModel = makeViewModel()
        viewModel.setPhoto(preparedJPEG: Data("junk".utf8))
        #expect(viewModel.notice != nil)

        _ = viewModel.beginPhotoLoad()
        #expect(viewModel.notice == nil)
        #expect(viewModel.isLoadingPhoto)
    }

    @Test func aSupersededLoadChangesNothingAtAll() {
        let viewModel = makeViewModel(with: photo)
        let older = viewModel.beginPhotoLoad()
        _ = viewModel.beginPhotoLoad()   // a newer load supersedes it

        // This would have shown an error notice and stopped the loading state, had it counted.
        viewModel.finishPhotoLoad(ticket: older, preparedJPEG: nil)

        #expect(viewModel.photoJPEG == photo)
        #expect(viewModel.notice == nil)
        #expect(viewModel.isLoadingPhoto, "the newer load is still running")
    }

    @Test func aTicketThatWasNeverIssuedIsIgnored() {
        let viewModel = makeViewModel()
        viewModel.finishPhotoLoad(ticket: 999, preparedJPEG: photo)

        #expect(!viewModel.hasPhoto)
        #expect(viewModel.notice == nil)
    }

    @Test func aCurrentFailedLoadReportsAndStopsLoading() {
        let viewModel = makeViewModel(with: photo)
        let ticket = viewModel.beginPhotoLoad()

        viewModel.finishPhotoLoad(ticket: ticket, preparedJPEG: nil)

        #expect(!viewModel.isLoadingPhoto)
        #expect(viewModel.notice?.kind == .error)
        #expect(viewModel.photoJPEG == photo)
    }
}
