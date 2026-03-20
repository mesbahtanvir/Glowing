import SwiftUI

struct CameraOverlayView: View {
    let angle: PhotoAngle
    var lightingCondition: LightingCondition?
    var faceGuidance: FaceGuidance?

    /// All conditions met for a good capture
    private var guidanceReady: Bool {
        guard let face = faceGuidance else { return false }
        let faceOK = face.readiness == .ready
        let lightingOK = lightingCondition?.qualityScore != .poor
        return faceOK && lightingOK
    }

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

                // Dynamic face guidance or static positioning tip
                if let guidance = faceGuidance {
                    liveGuidanceIndicator(guidance)
                        .padding(.top, 8)
                } else {
                    positioningTip
                        .padding(.top, 8)
                }

                Spacer()

                // Live lighting indicator (replaces static tip when available)
                if let condition = lightingCondition {
                    liveLightingIndicator(condition)
                        .padding(.bottom, 160)
                } else {
                    lightingTip
                        .padding(.bottom, 160)
                }
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
        case .smile:
            smileGuide
        }
    }

    // MARK: - Front Guide

    private var frontGuide: some View {
        ZStack {
            // Head oval — turns green when ready
            Ellipse()
                .stroke(
                    guidanceReady ? Color.green.opacity(0.6) : Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: guidanceReady ? 2.5 : 2, dash: [12, 8])
                )
                .frame(width: 200, height: 270)
                .animation(.easeInOut(duration: 0.4), value: guidanceReady)

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

    // MARK: - Smile Guide

    private var smileGuide: some View {
        ZStack {
            // Head oval — same as front, turns green when ready
            Ellipse()
                .stroke(
                    guidanceReady ? Color.green.opacity(0.6) : Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: guidanceReady ? 2.5 : 2, dash: [12, 8])
                )
                .frame(width: 200, height: 270)
                .animation(.easeInOut(duration: 0.4), value: guidanceReady)

            // Mouth-area highlight — dashed rectangle to guide smile positioning
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 6])
                )
                .frame(width: 80, height: 36)
                .offset(y: 60)

            // Smile icon hint
            Image(systemName: "face.smiling")
                .font(.system(size: 14, weight: .light))
                .foregroundStyle(.white.opacity(0.4))
                .offset(y: 95)

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
            // Head oval shifted to guide profile positioning — turns green when ready
            Ellipse()
                .stroke(
                    guidanceReady ? Color.green.opacity(0.6) : Color.white.opacity(0.5),
                    style: StrokeStyle(lineWidth: guidanceReady ? 2.5 : 2, dash: [12, 8])
                )
                .frame(width: 170, height: 240)
                .offset(x: flipped ? -20 : 20)
                .animation(.easeInOut(duration: 0.4), value: guidanceReady)

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

    // MARK: - Live Lighting Indicator

    private func liveLightingIndicator(_ condition: LightingCondition) -> some View {
        let (color, icon): (Color, String) = switch condition.qualityScore {
        case .good: (.green, "checkmark.circle.fill")
        case .acceptable: (.yellow, "exclamationmark.triangle.fill")
        case .poor: (.red, "xmark.circle.fill")
        }

        let message: String = if let issue = condition.issues.first {
            issue.shortMessage
        } else {
            "Good lighting"
        }

        return HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)

            Text(message)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            // Mini brightness bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.15))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(condition.faceBrightness))
                }
            }
            .frame(width: 40, height: 4)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(.black.opacity(0.6))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.3), value: condition.qualityScore.rawValue)
    }

    // MARK: - Live Face Guidance Indicator

    private func liveGuidanceIndicator(_ guidance: FaceGuidance) -> some View {
        let (color, icon, message): (Color, String, String) = switch guidance.readiness {
        case .ready:
            (.green, "checkmark.circle.fill", "Position looks great")
        case .adjusting:
            (.yellow, "arrow.triangle.2.circlepath", guidance.primaryIssue?.shortMessage ?? "Almost there")
        case .notReady:
            (.white, "face.dashed", guidance.primaryIssue?.shortMessage ?? "Position your face")
        }

        return VStack(spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(color)

                Text(message)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.6))
            .clipShape(Capsule())

            // Fit bar — shows how well face fills the guide ellipse
            if let fit = guidance.fitRatio, guidance.readiness != .ready {
                fitIndicator(ratio: fit)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: guidance.readiness.rawValue)
    }

    // MARK: - Fit Indicator

    /// A compact bar showing how the face size compares to the guide ellipse
    private func fitIndicator(ratio: CGFloat) -> some View {
        let clamped = min(max(ratio, 0.4), 1.6)
        let barPosition = (clamped - 0.4) / 1.2 // normalize 0.4–1.6 → 0–1
        let isIdeal = (0.80...1.20).contains(ratio)

        return HStack(spacing: 6) {
            Text("far")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))

            // The bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.12))

                    // Ideal zone highlight (center 33%)
                    Capsule()
                        .fill(.green.opacity(0.15))
                        .frame(width: geo.size.width * 0.33)
                        .offset(x: geo.size.width * 0.33)

                    // Current position dot
                    Circle()
                        .fill(isIdeal ? .green : .yellow)
                        .frame(width: 8, height: 8)
                        .offset(x: geo.size.width * barPosition - 4)
                }
            }
            .frame(width: 80, height: 6)

            Text("close")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(.black.opacity(0.5))
        .clipShape(Capsule())
        .animation(.easeInOut(duration: 0.25), value: ratio)
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

#Preview("Smile") {
    ZStack {
        Color.black.ignoresSafeArea()
        CameraOverlayView(angle: .smile)
    }
}
