import SwiftUI

struct OnboardingCaptureView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var cameraVM = CameraViewModel()
    @State private var currentAngleIndex = 0
    @State private var captureFlash = false

    // Auto-capture
    @State private var autoCaptureProgress: CGFloat = 0
    @State private var isAutoCapturing = false
    @State private var autoCaptureTask: Task<Void, Never>?

    private let angles: [PhotoAngle] = PhotoAngle.faceAngles

    private var currentAngle: PhotoAngle {
        angles[currentAngleIndex]
    }

    private var allConditionsMet: Bool {
        guard let face = cameraVM.currentFaceGuidance else { return false }
        let faceOK = face.readiness == .ready
        let lightingOK = cameraVM.currentLighting?.qualityScore != .poor
        return faceOK && lightingOK
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraVM.isAuthorized {
                cameraContent
            } else {
                permissionView
            }
        }
        .task {
            await cameraVM.checkAuthorization()
            if cameraVM.isAuthorized {
                cameraVM.setupSession()
                cameraVM.setLightingAnalysis(enabled: true)
                cameraVM.setFaceGuidance(enabled: true, angle: currentAngle)
            }
        }
        .onChange(of: currentAngleIndex) { _, _ in
            cameraVM.targetAngle = angles[currentAngleIndex]
            cancelAutoCapture()
        }
        .onChange(of: cameraVM.currentFaceGuidance?.readiness) { _, _ in
            if allConditionsMet {
                startAutoCapture()
            } else {
                cancelAutoCapture()
            }
        }
        .onChange(of: cameraVM.currentLighting?.qualityScore) { _, _ in
            if allConditionsMet {
                startAutoCapture()
            } else {
                cancelAutoCapture()
            }
        }
        .onDisappear {
            cameraVM.stopSession()
            autoCaptureTask?.cancel()
        }
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(session: cameraVM.captureSession)
                .ignoresSafeArea()

            CameraOverlayView(
                angle: currentAngle,
                lightingCondition: cameraVM.currentLighting,
                faceGuidance: cameraVM.currentFaceGuidance
            )
                .id(currentAngleIndex)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: currentAngleIndex)

            if captureFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            VStack {
                // Top info
                VStack(spacing: 8) {
                    Text("Photo \(currentAngleIndex + 1) of \(angles.count)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))

                    // Step dots
                    HStack(spacing: 8) {
                        ForEach(0..<angles.count, id: \.self) { index in
                            let isActive = index == currentAngleIndex
                            let isDone = index < currentAngleIndex
                            Capsule()
                                .fill(isDone || isActive ? Color.white : Color.white.opacity(0.3))
                                .frame(width: isActive ? 24 : 8, height: 8)
                        }
                    }
                }
                .padding(.top, 20)

                Spacer()

                // Bottom controls
                VStack(spacing: 16) {
                    VStack(spacing: 4) {
                        Text(currentAngle.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)

                        if isAutoCapturing {
                            Text("Hold still…")
                                .font(.caption2)
                                .foregroundStyle(.green.opacity(0.9))
                                .transition(.opacity)
                        }
                    }

                    Button {
                        cancelAutoCapture()
                        capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .trim(from: 0, to: autoCaptureProgress)
                                .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                                .frame(width: 80, height: 80)
                                .rotationEffect(.degrees(-90))

                            Circle()
                                .stroke(isAutoCapturing ? Color.green.opacity(0.4) : .white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 62, height: 62)
                        }
                    }
                    .sensoryFeedback(.impact(flexibility: .solid), trigger: viewModel.capturedPhotos.count)
                    .animation(.easeInOut(duration: 0.3), value: isAutoCapturing)
                }
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Capture

    private func capturePhoto() {
        Task {
            guard let image = await cameraVM.capturePhoto() else { return }

            let scaled = downsample(image, maxDimension: 1200)
            guard let data = scaled.jpegData(compressionQuality: 0.8) else { return }

            // Flash
            withAnimation(.easeIn(duration: 0.05)) { captureFlash = true }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.2)) { captureFlash = false }

            viewModel.capturedPhotos[currentAngle] = data

            if currentAngleIndex < angles.count - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentAngleIndex += 1
                }
            } else {
                // All photos captured — start new multi-step analysis
                cameraVM.setLightingAnalysis(enabled: false)
                cameraVM.setFaceGuidance(enabled: false)
                viewModel.goToStep(.extractingDetails)
            }
        }
    }

    private func downsample(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let longestSide = max(size.width, size.height)
        guard longestSide > maxDimension else { return image }

        let scale = maxDimension / longestSide
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    // MARK: - Auto Capture

    private static let autoCaptureDelay: Duration = .milliseconds(1500)
    private static let autoCaptureSteps = 15

    private func startAutoCapture() {
        guard !isAutoCapturing else { return }
        isAutoCapturing = true
        autoCaptureProgress = 0

        autoCaptureTask?.cancel()
        autoCaptureTask = Task {
            let stepDuration = Self.autoCaptureDelay / Self.autoCaptureSteps
            for step in 1...Self.autoCaptureSteps {
                try? await Task.sleep(for: stepDuration)
                guard !Task.isCancelled else { return }

                guard allConditionsMet else {
                    cancelAutoCapture()
                    return
                }

                withAnimation(.linear(duration: 0.08)) {
                    autoCaptureProgress = CGFloat(step) / CGFloat(Self.autoCaptureSteps)
                }
            }

            guard !Task.isCancelled else { return }
            capturePhoto()
            cancelAutoCapture()
        }
    }

    private func cancelAutoCapture() {
        autoCaptureTask?.cancel()
        autoCaptureTask = nil
        isAutoCapturing = false
        withAnimation(.easeOut(duration: 0.15)) {
            autoCaptureProgress = 0
        }
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.5))

            Text("Camera Access Required")
                .font(.title3)
                .fontWeight(.bold)
                .foregroundStyle(.white)

            Text("We need camera access to analyze your skin. Enable it in Settings.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}
