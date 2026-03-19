import SwiftUI

struct CameraOverlayView: View {
    let angle: PhotoAngle

    var body: some View {
        ZStack {
            // Subtle vignette to draw focus to center
            RadialGradient(
                colors: [.clear, .black.opacity(0.4)],
                center: .center,
                startRadius: 120,
                endRadius: 340
            )
            .ignoresSafeArea()

            // Face / body outline guide
            faceGuide

            // Instruction banners
            VStack(spacing: 0) {
                // Guidance text
                guidanceBanner
                    .padding(.top, 90)

                // Positioning tip
                positioningTip
                    .padding(.top, 8)

                Spacer()

                // Lighting tip pinned near bottom
                lightingTip
                    .padding(.bottom, 160)
            }
        }
        .allowsHitTesting(false)
    }

    // MARK: - Face Guide

    @ViewBuilder
    private var faceGuide: some View {
        switch angle {
        case .front:
            frontGuide
        case .left:
            sideGuide(flipped: false)
        case .right:
            sideGuide(flipped: true)
        }
    }

    // MARK: - Front Guide

    private var frontGuide: some View {
        ZStack {
            // Head oval
            Ellipse()
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [12, 8]))
                .frame(width: 200, height: 270)

            // Eye-level line with labels
            HStack(spacing: 0) {
                dashLine
                    .frame(width: 60)
                Spacer()
                dashLine
                    .frame(width: 60)
            }
            .frame(width: 200, height: 1)
            .offset(y: -40)

            // Chin marker
            Image(systemName: "chevron.up")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
                .offset(y: 125)

            // Vertical center line
            Rectangle()
                .fill(.white.opacity(0.12))
                .frame(width: 1, height: 240)

            // Shoulder alignment markers
            shoulderMarkers
        }
        .offset(y: -20)
    }

    // MARK: - Side Guide

    private func sideGuide(flipped: Bool) -> some View {
        ZStack {
            // Head oval shifted to guide profile positioning
            Ellipse()
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 2, dash: [12, 8]))
                .frame(width: 170, height: 240)
                .offset(x: flipped ? -20 : 20)

            // Ear position marker (small circle where ear should align)
            Circle()
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                .frame(width: 28, height: 28)
                .overlay {
                    Text("ear")
                        .font(.system(size: 7, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .offset(x: flipped ? 50 : -50, y: -30)

            // Jawline guide — curved path
            jawlineGuide(flipped: flipped)

            // Nose direction indicator
            Image(systemName: flipped ? "arrowtriangle.right.fill" : "arrowtriangle.left.fill")
                .font(.system(size: 16))
                .foregroundStyle(.white.opacity(0.35))
                .offset(x: flipped ? -95 : 95, y: -50)

            // Shoulder markers
            shoulderMarkers
        }
        .offset(y: -20)
    }

    // MARK: - Shared Components

    private var shoulderMarkers: some View {
        HStack {
            // Left shoulder tick
            VStack(spacing: 2) {
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 1.5)
                Text("shoulder")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }

            Spacer()

            // Right shoulder tick
            VStack(spacing: 2) {
                Rectangle()
                    .fill(.white.opacity(0.3))
                    .frame(width: 40, height: 1.5)
                Text("shoulder")
                    .font(.system(size: 7, weight: .medium))
                    .foregroundStyle(.white.opacity(0.3))
            }
        }
        .frame(width: 280)
        .offset(y: 150)
    }

    private var dashLine: some View {
        Rectangle()
            .fill(.white.opacity(0.2))
            .frame(height: 1)
    }

    private func jawlineGuide(flipped: Bool) -> some View {
        // Simple arc to suggest jawline path
        Circle()
            .trim(from: flipped ? 0.55 : 0.2, to: flipped ? 0.8 : 0.45)
            .stroke(.white.opacity(0.25), style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
            .frame(width: 160, height: 160)
            .offset(x: flipped ? -10 : 10, y: 30)
    }

    // MARK: - Guidance Banner

    private var guidanceBanner: some View {
        Text(angle.guidanceText)
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
            .clipShape(Capsule())
    }

    // MARK: - Positioning Tip

    private var positioningTip: some View {
        Text(angle.positioningTip)
            .font(.caption)
            .foregroundStyle(.white.opacity(0.7))
            .multilineTextAlignment(.center)
            .frame(maxWidth: 280)
    }

    // MARK: - Lighting Tip

    private var lightingTip: some View {
        HStack(spacing: 6) {
            Image(systemName: "light.max")
                .font(.caption)
                .foregroundStyle(.yellow.opacity(0.8))
            Text("Face a window for even, natural light")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
    }
}

#Preview("Front") {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraOverlayView(angle: .front)
    }
}

#Preview("Left") {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraOverlayView(angle: .left)
    }
}

#Preview("Right") {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraOverlayView(angle: .right)
    }
}
