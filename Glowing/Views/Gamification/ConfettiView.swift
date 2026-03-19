import SwiftUI

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []
    @State private var animationTick = false

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate

                for particle in particles {
                    let age = time - particle.startTime
                    guard age < particle.lifetime else { continue }

                    let progress = age / particle.lifetime
                    let x = particle.startX + particle.velocityX * age + sin(age * particle.wobble) * 20
                    let y = particle.startY + particle.velocityY * age + 120 * age * age
                    let opacity = 1.0 - progress

                    guard x >= 0, x <= size.width, y >= 0, y <= size.height else { continue }

                    let rect = CGRect(
                        x: x - particle.size / 2,
                        y: y - particle.size / 2,
                        width: particle.size,
                        height: particle.size * 1.5
                    )

                    context.opacity = opacity
                    context.fill(
                        RoundedRectangle(cornerRadius: 2).path(in: rect),
                        with: .color(particle.color)
                    )
                }
            }
        }
        .onAppear {
            let now = Date.timeIntervalSinceReferenceDate
            let colors: [Color] = [.yellow, .orange, .blue, .green, .pink, .purple, .red, .teal]

            particles = (0..<50).map { _ in
                ConfettiParticle(
                    startX: Double.random(in: 50...300),
                    startY: Double.random(in: -20...20),
                    velocityX: Double.random(in: -60...60),
                    velocityY: Double.random(in: -200 ... -50),
                    size: Double.random(in: 4...8),
                    color: colors.randomElement()!,
                    wobble: Double.random(in: 2...6),
                    lifetime: Double.random(in: 1.5...3.0),
                    startTime: now + Double.random(in: 0...0.3)
                )
            }
        }
    }
}

private struct ConfettiParticle {
    let startX: Double
    let startY: Double
    let velocityX: Double
    let velocityY: Double
    let size: Double
    let color: Color
    let wobble: Double
    let lifetime: Double
    let startTime: Double
}
