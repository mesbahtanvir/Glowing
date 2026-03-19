import SwiftUI
import SwiftData
import AuthenticationServices

struct SignInView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Branding
            VStack(spacing: 16) {
                Image(systemName: "sparkle")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("Glowing")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("AI-powered skincare\npersonalized for you")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Sign In Button + Privacy
            VStack(spacing: 16) {
                SignInWithAppleButton(.signUp) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    switch result {
                    case .success:
                        errorMessage = nil
                        AuthManager.shared.handleSignIn(result: result, modelContext: modelContext)
                    case .failure(let error):
                        let nsError = error as NSError
                        // Don't show error for user cancellation
                        if nsError.domain == ASAuthorizationError.errorDomain,
                           nsError.code == ASAuthorizationError.canceled.rawValue {
                            return
                        }
                        errorMessage = error.localizedDescription
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 12))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Text("Your data stays on your device.\nWe only use Apple Sign-In to create your account.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                #if DEBUG
                Button("Skip Sign-In (Dev Only)") {
                    AuthManager.shared.createDebugUser(modelContext: modelContext)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.top, 8)
                #endif
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 48)
        }
    }
}

#Preview {
    SignInView()
        .modelContainer(for: [UserProfile.self], inMemory: true)
}
