import SwiftUI

struct AchievementUnlockView: View {
    let achievement: AchievementType
    var onDismiss: () -> Void

    @State private var showContent = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                if showContent {
                    // Confetti particles
                    ConfettiView()
                        .frame(height: 200)
                        .allowsHitTesting(false)

                    // Badge
                    ZStack {
                        Circle()
                            .fill(Color.yellow.opacity(0.2))
                            .frame(width: 100, height: 100)

                        Image(systemName: achievement.icon)
                            .font(.system(size: 44))
                            .foregroundStyle(.yellow)
                    }
                    .transition(.scale.combined(with: .opacity))

                    VStack(spacing: 8) {
                        Text("Achievement Unlocked!")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.yellow)
                            .textCase(.uppercase)
                            .tracking(1.5)

                        Text(achievement.name)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)

                        Text(achievement.description)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    Button {
                        onDismiss()
                    } label: {
                        Text("Awesome!")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 40)
                    .padding(.top, 8)
                    .transition(.opacity)
                }
            }
        }
        .sensoryFeedback(.success, trigger: showContent)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                showContent = true
            }
        }
    }
}
