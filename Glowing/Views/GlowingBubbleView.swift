import SwiftUI

/// A mesmerizing glowing bubble animation used as a loading indicator
/// while AI analysis or routine generation is in progress.
struct GlowingBubbleView: View {
    var message: String = "Analyzing..."
    var submessage: String? = nil
    var accentColor: Color = .blue

    @State private var phase1: Bool = false
    @State private var phase2: Bool = false
    @State private var phase3: Bool = false
    @State private var rotationAngle: Double = 0
    @State private var particlePhase: Bool = false

    var body: some View {
        VStack(spacing: 28) {
            ZStack {
                // Outermost soft radial glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(phase1 ? 0.18 : 0.04),
                                accentColor.opacity(0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: 90
                        )
                    )
                    .frame(width: 180, height: 180)
                    .scaleEffect(phase1 ? 1.1 : 0.85)

                // Orbiting particle ring
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(accentColor.opacity(particlePhase ? 0.5 : 0.15))
                        .frame(width: particlePhase ? 6 : 4, height: particlePhase ? 6 : 4)
                        .offset(x: 58)
                        .rotationEffect(.degrees(Double(i) * 60 + rotationAngle))
                }

                // Middle pulsing ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [
                                accentColor.opacity(0.6),
                                accentColor.opacity(0.1),
                                accentColor.opacity(0.4),
                                accentColor.opacity(0.05),
                                accentColor.opacity(0.6)
                            ],
                            center: .center
                        ),
                        lineWidth: 3
                    )
                    .frame(width: 90, height: 90)
                    .rotationEffect(.degrees(rotationAngle))
                    .scaleEffect(phase2 ? 1.08 : 0.92)

                // Inner glowing bubble
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                accentColor.opacity(phase3 ? 0.55 : 0.3),
                                accentColor.opacity(phase3 ? 0.25 : 0.1),
                                accentColor.opacity(0.02)
                            ],
                            center: .center,
                            startRadius: 5,
                            endRadius: 36
                        )
                    )
                    .frame(width: 72, height: 72)
                    .scaleEffect(phase3 ? 1.12 : 0.88)

                // Core bright dot
                Circle()
                    .fill(accentColor.opacity(phase1 ? 0.9 : 0.4))
                    .frame(width: 16, height: 16)
                    .blur(radius: phase1 ? 4 : 2)

                // Specular highlight
                Circle()
                    .fill(.white.opacity(phase3 ? 0.6 : 0.2))
                    .frame(width: 6, height: 6)
                    .offset(x: -8, y: -10)
            }

            VStack(spacing: 8) {
                Text(message)
                    .font(.title3)
                    .fontWeight(.semibold)

                if let submessage {
                    Text(submessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }
        }
        .onAppear {
            // Phase 1: slow breathe
            withAnimation(
                .easeInOut(duration: 3.0)
                .repeatForever(autoreverses: true)
            ) {
                phase1 = true
            }
            // Phase 2: offset breathe
            withAnimation(
                .easeInOut(duration: 2.4)
                .repeatForever(autoreverses: true)
            ) {
                phase2 = true
            }
            // Phase 3: faster inner pulse
            withAnimation(
                .easeInOut(duration: 1.8)
                .repeatForever(autoreverses: true)
            ) {
                phase3 = true
            }
            // Particle twinkle
            withAnimation(
                .easeInOut(duration: 1.2)
                .repeatForever(autoreverses: true)
            ) {
                particlePhase = true
            }
            // Continuous rotation
            withAnimation(
                .linear(duration: 8)
                .repeatForever(autoreverses: false)
            ) {
                rotationAngle = 360
            }
        }
    }
}

#Preview("Blue") {
    GlowingBubbleView(
        message: "Analyzing Your Skin",
        submessage: "Our AI is evaluating your photos to understand your skin and build a personalized routine.",
        accentColor: .blue
    )
    .preferredColorScheme(.dark)
}

#Preview("Purple") {
    GlowingBubbleView(
        message: "Generating Routine",
        submessage: "Creating your personalized skincare routine...",
        accentColor: .purple
    )
    .preferredColorScheme(.light)
}
