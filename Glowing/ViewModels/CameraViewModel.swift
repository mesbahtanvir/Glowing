import AVFoundation
import UIKit
import Vision

@Observable
final class CameraViewModel: NSObject {
    var isAuthorized = false
    var isCameraReady = false
    var error: String?

    // Live lighting feedback
    var currentLighting: LightingCondition?
    var isLightingAnalysisEnabled = false

    // Live face guidance
    var currentFaceGuidance: FaceGuidance?
    var targetAngle: PhotoAngle = .front
    private var isFaceGuidanceEnabled = false
    private var cachedScreenSize: CGSize = CGSize(width: 393, height: 852)

    let captureSession = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    private var continuation: CheckedContinuation<UIImage?, Never>?
    private let videoQueue = DispatchQueue(label: "com.glowing.camera.video", qos: .userInitiated)
    private var lastLightingCheck = Date.distantPast
    private let lightingCheckInterval: TimeInterval = 0.5 // analyze every 500ms

    func checkAuthorization() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            isAuthorized = false
        }
    }

    func setupSession() {
        guard !isCameraReady else { return }

        captureSession.beginConfiguration()
        captureSession.sessionPreset = .photo

        // Front camera for selfie-style progress photos
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device) else {
            error = "Unable to access the front camera."
            captureSession.commitConfiguration()
            return
        }

        if captureSession.canAddInput(input) {
            captureSession.addInput(input)
        }

        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
        }

        // Video output for live lighting analysis
        videoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        captureSession.commitConfiguration()
        isCameraReady = true

        Task.detached(priority: .userInitiated) { [captureSession] in
            captureSession.startRunning()
        }
    }

    func stopSession() {
        guard captureSession.isRunning else { return }
        Task.detached(priority: .userInitiated) { [captureSession] in
            captureSession.stopRunning()
        }
    }

    func capturePhoto() async -> UIImage? {
        guard isCameraReady else { return nil }

        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    /// Enable or disable live lighting analysis on camera preview frames
    func setLightingAnalysis(enabled: Bool) {
        isLightingAnalysisEnabled = enabled
        if !enabled {
            currentLighting = nil
        }
    }

    /// Enable or disable live face guidance on camera preview frames
    func setFaceGuidance(enabled: Bool, angle: PhotoAngle = .front) {
        isFaceGuidanceEnabled = enabled
        targetAngle = angle
        if enabled {
            cachedScreenSize = UIScreen.main.bounds.size
        }
        if !enabled {
            currentFaceGuidance = nil
        }
    }
}

// MARK: - AVCapturePhotoCaptureDelegate

extension CameraViewModel: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { continuation = nil }

        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            continuation?.resume(returning: nil)
            return
        }

        // Mirror the image horizontally to match what the user saw in the preview
        let mirrored = UIImage(cgImage: image.cgImage!, scale: image.scale, orientation: .leftMirrored)
        continuation?.resume(returning: mirrored)
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate (Live Analysis)

extension CameraViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard isLightingAnalysisEnabled || isFaceGuidanceEnabled else { return }

        // Throttle: only analyze every 500ms
        let now = Date()
        guard now.timeIntervalSince(lastLightingCheck) >= lightingCheckInterval else { return }
        lastLightingCheck = now

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        // Lighting analysis
        var condition: LightingCondition?
        if isLightingAnalysisEnabled {
            condition = LightingAnalyzer.shared.analyzeLiveFrame(pixelBuffer)
        }

        // Face detection
        var guidance: FaceGuidance?
        if isFaceGuidanceEnabled {
            guidance = detectFace(in: pixelBuffer)
        }

        Task { @MainActor in
            if let condition { self.currentLighting = condition }
            if let guidance { self.currentFaceGuidance = guidance }
        }
    }

    /// Run Vision face detection on a pixel buffer and return guidance
    private func detectFace(in pixelBuffer: CVPixelBuffer) -> FaceGuidance {
        let request = VNDetectFaceLandmarksRequest()
        // Use .leftMirrored to match front camera mirrored preview
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .leftMirrored, options: [:])

        let screenSize = cachedScreenSize

        do {
            try handler.perform([request])
        } catch {
            return FaceGuidance(faceBoundingBox: nil, faceYawDegrees: nil, targetAngle: targetAngle, screenSize: screenSize)
        }

        guard let face = request.results?.first else {
            return FaceGuidance(faceBoundingBox: nil, faceYawDegrees: nil, targetAngle: targetAngle, screenSize: screenSize)
        }

        let bbox = face.boundingBox
        let yawDegrees: Float? = face.yaw.map { $0.floatValue * 180 / .pi }

        return FaceGuidance(
            faceBoundingBox: bbox,
            faceYawDegrees: yawDegrees,
            targetAngle: targetAngle,
            screenSize: screenSize
        )
    }
}
