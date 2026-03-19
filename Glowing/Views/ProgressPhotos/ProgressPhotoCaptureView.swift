import SwiftUI
import SwiftData

struct ProgressPhotoCaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var cameraVM = CameraViewModel()
    @State private var currentAngleIndex = 0
    @State private var capturedPhotos: [PhotoAngle: Data] = [:]
    @State private var showReview = false
    @State private var captureFlash = false
    @State private var showRetakeConfirmation = false
    @State private var showPhotoTips = false

    @AppStorage("hasSeenPhotoTips") private var hasSeenPhotoTips = false

    private let faceAngles: [PhotoAngle] = PhotoAngle.faceAngles
    private let sessionID = UUID()

    private var currentAngle: PhotoAngle {
        faceAngles[currentAngleIndex]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if cameraVM.isAuthorized {
                cameraContent
            } else {
                permissionView
            }

            if showReview {
                reviewOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
        .onAppear {
            if !hasSeenPhotoTips {
                showPhotoTips = true
            }
        }
        .sheet(isPresented: $showPhotoTips) {
            hasSeenPhotoTips = true
        } content: {
            PhotoTipsView()
        }
    }

    // MARK: - Camera Content

    private var cameraContent: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraVM.captureSession)
                .ignoresSafeArea()

            // Overlay guide for current angle
            CameraOverlayView(angle: currentAngle)
                .id(currentAngleIndex)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.3), value: currentAngleIndex)

            // Flash effect on capture
            if captureFlash {
                Color.white
                    .ignoresSafeArea()
                    .transition(.opacity)
            }

            // Controls
            VStack {
                topBar
                    .padding(.horizontal)
                    .padding(.top, 12)

                Spacer()

                bottomControls
                    .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }

            Spacer()

            // Step dots
            HStack(spacing: 8) {
                ForEach(0..<faceAngles.count, id: \.self) { index in
                    let isActive = index == currentAngleIndex
                    let isDone = index <= currentAngleIndex
                    Capsule()
                        .fill(isDone ? Color.white : Color.white.opacity(0.3))
                        .frame(width: isActive ? 24 : 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentAngleIndex)
                }
            }

            Spacer()

            // Invisible spacer for symmetry
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .opacity(0)
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Angle label
            Text(currentAngle.displayName)
                .font(.headline)
                .foregroundStyle(.white)
                .contentTransition(.interpolate)
                .animation(.easeInOut(duration: 0.3), value: currentAngleIndex)

            // Capture button
            Button {
                captureCurrentAngle()
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
            .sensoryFeedback(.impact(flexibility: .solid), trigger: capturedPhotos.count)
        }
    }

    // MARK: - Capture Logic

    private func captureCurrentAngle() {
        Task {
            guard let image = await cameraVM.capturePhoto() else { return }

            // Downscale for storage (max 1200px on longest side)
            let scaled = downsample(image, maxDimension: 1200)
            guard let data = scaled.jpegData(compressionQuality: 0.8) else { return }

            // Flash effect
            withAnimation(.easeIn(duration: 0.05)) { captureFlash = true }
            try? await Task.sleep(for: .milliseconds(100))
            withAnimation(.easeOut(duration: 0.2)) { captureFlash = false }

            capturedPhotos[currentAngle] = data

            if currentAngleIndex < faceAngles.count - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentAngleIndex += 1
                }
            } else {
                // All face photos done, go to review
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showReview = true
                }
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

    // MARK: - Review Overlay

    private var reviewOverlay: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Text("Review Photos")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                // Photo thumbnails
                HStack(spacing: 8) {
                    let reviewAngles = PhotoAngle.faceAngles
                    let thumbWidth: CGFloat = 100
                    let thumbHeight: CGFloat = 140

                    ForEach(reviewAngles, id: \.self) { angle in
                        VStack(spacing: 6) {
                            if let data = capturedPhotos[angle],
                               let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: thumbWidth, height: thumbHeight)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(width: thumbWidth, height: thumbHeight)
                                    .overlay {
                                        Image(systemName: "photo")
                                            .foregroundStyle(.white.opacity(0.3))
                                    }
                            }

                            Text(angle.displayName)
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }

                // Action buttons
                HStack(spacing: 16) {
                    Button {
                        showRetakeConfirmation = true
                    } label: {
                        Text("Retake")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    .confirmationDialog("Retake Photos?", isPresented: $showRetakeConfirmation) {
                        Button("Retake All Photos", role: .destructive) {
                            withAnimation {
                                showReview = false
                                currentAngleIndex = 0
                                capturedPhotos = [:]
                            }
                        }
                    } message: {
                        Text("This will discard all photos and restart the capture.")
                    }

                    Button {
                        savePhotos()
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.horizontal, 8)
            }
            .padding(32)
        }
        .sensoryFeedback(.success, trigger: showReview)
    }

    // MARK: - Save

    private func savePhotos() {
        let now = Date()
        var savedPhotos: [ProgressPhoto] = []
        for angle in PhotoAngle.faceAngles {
            guard let data = capturedPhotos[angle] else { continue }
            let photo = ProgressPhoto(
                angle: angle,
                imageData: data,
                sessionID: sessionID,
                capturedAt: now
            )
            modelContext.insert(photo)
            savedPhotos.append(photo)
        }

        // Auto-analyze if enabled
        let manager = SkinAnalysisManager.shared
        if manager.shouldAutoAnalyze {
            let sid = sessionID
            let context = modelContext
            Task {
                await manager.analyzeSession(
                    sessionID: sid,
                    photos: savedPhotos,
                    modelContext: context
                )
            }
        }
    }

    // MARK: - Permission View

    private var permissionView: some View {
        VStack(spacing: 20) {
            Image(systemName: "camera.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Camera Access Required")
                .font(.title3)
                .fontWeight(.bold)

            Text("Glowing needs camera access to take progress photos. Enable it in Settings.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                dismiss()
            }
            .foregroundStyle(.secondary)
        }
    }
}
