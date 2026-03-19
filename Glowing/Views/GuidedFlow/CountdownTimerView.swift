import SwiftUI

struct CountdownTimerView: View {
    let secondsRemaining: Int
    let totalSeconds: Int
    let isRunning: Bool
    var accentColor: Color = .blue

    @State private var breathePhase: Bool = false

    private var elapsed: Int {
        max(0, totalSeconds - secondsRemaining)
    }

    private var fraction: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(elapsed) / Double(totalSeconds)
    }

    /// Friendly label: "2 min left", "30s left", or "Done"
    private var statusLabel: String {
        if secondsRemaining <= 0 { return "Done" }
        let mins = secondsRemaining / 60
        let secs = secondsRemaining % 60
        if mins >= 1 && secs == 0 {
            return "\(mins) min left"
        } else if mins >= 1 {
            return "\(mins) min \(secs)s left"
        } else {
            return "\(secs)s left"
        }
    }

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                // Outer soft glow — breathes in and out
                Circle()
                    .fill(accentColor.opacity(breathePhase ? 0.12 : 0.04))
                    .frame(width: 100, height: 100)
                    .scaleEffect(breathePhase ? 1.15 : 0.95)

                // Track ring
                Circle()
                    .stroke(accentColor.opacity(0.12), lineWidth: 4)
                    .frame(width: 72, height: 72)

                // Progress arc — fills as time passes
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(
                        accentColor.opacity(0.6),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: fraction)

                // Center dot that gently pulses
                Circle()
                    .fill(accentColor.opacity(breathePhase ? 0.35 : 0.15))
                    .frame(width: 8, height: 8)
            }

            // Soft status text instead of countdown digits
            Text(statusLabel)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(accentColor.opacity(0.7))
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.6), value: secondsRemaining)
        }
        .onAppear { startBreathing() }
        .onChange(of: isRunning) { _, running in
            if running { startBreathing() } else { breathePhase = false }
        }
    }

    private func startBreathing() {
        guard isRunning else { return }
        withAnimation(
            .easeInOut(duration: 3.5)
            .repeatForever(autoreverses: true)
        ) {
            breathePhase = true
        }
    }
}
