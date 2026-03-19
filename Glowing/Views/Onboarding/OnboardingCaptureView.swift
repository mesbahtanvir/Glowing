import SwiftUI

struct OnboardingCaptureView: View {
    @Bindable var viewModel: OnboardingViewModel

    @State private var cameraVM = CameraViewModel()
    @State private var currentAngleIndex = 0
    @State private var captureFlash = false

    private let angles: [PhotoAngle] = PhotoAngle.faceAngles

    private var currentAngle: PhotoAngle {
        angles[currentAngleIndex]
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
            }
        }
        .onDisappear {
            cameraVM.stopSession()
        }
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            CameraPreviewView(session: cameraVM.captureSession)
                .ignoresSafeArea()

            CameraOverlayView(angle: currentAngle)
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
                    Text("Photo \(currentAngleIndex + 1) of 3")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.white.opacity(0.7))

                    // Step dots
                    HStack(spacing: 8) {
                        ForEach(0..<3, id: \.self) { index in
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
                VStack(spacing: 20) {
                    Text(currentAngle.displayName)
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text(currentAngle.guidanceText)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)

                    Button {
                        capturePhoto()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white, lineWidth: 4)
                                .frame(width: 72, height: 72)
                            Circle()
                                .fill(.white)
                                .frame(width: 62, height: 62)
                        }
                    }
                    .sensoryFeedback(.impact(flexibility: .solid), trigger: viewModel.capturedPhotos.count)
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
                // All 3 photos captured — start analysis
                viewModel.goToStep(.analyzing)
                Task { await viewModel.analyzePhotos() }
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
