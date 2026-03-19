import SwiftUI

struct WelcomeStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "sparkle")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 12) {
                    Text("Welcome to Glowing")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("AI-powered skincare, personalized to your skin. Let's take a few photos to build your routine.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                // Feature highlights
                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "camera.fill", text: "Quick 3-angle photo scan")
                    featureRow(icon: "wand.and.stars", text: "AI analyzes your skin health")
                    featureRow(icon: "list.bullet.clipboard", text: "Get a personalized routine")
                    featureRow(icon: "chart.line.uptrend.xyaxis", text: "Track improvements weekly")
                }
                .padding(.top, 8)
            }

            Spacer()

            Button {
                viewModel.advance()
            } label: {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(.tint)
                .frame(width: 28)

            Text(text)
                .font(.subheadline)
        }
        .padding(.horizontal, 40)
    }
}
