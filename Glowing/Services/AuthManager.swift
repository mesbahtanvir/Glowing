import Foundation
import AuthenticationServices
import SwiftData

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()

    var isSignedIn = false
    var currentUser: UserProfile?

    private static let appleUserIDKey = "com.glowing.apple-user-id"

    private init() {}

    // MARK: - Load on Launch

    func loadUser(modelContext: ModelContext) {
        guard let storedID = KeychainHelper.read(key: Self.appleUserIDKey) else {
            isSignedIn = false
            currentUser = nil
            return
        }

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserID == storedID }
        )
        if let profile = try? modelContext.fetch(descriptor).first {
            currentUser = profile
            isSignedIn = true
        } else {
            // Profile deleted but keychain still has ID — clean up
            KeychainHelper.delete(key: Self.appleUserIDKey)
            isSignedIn = false
            currentUser = nil
        }
    }

    // MARK: - Check Credential State

    func checkCredentialState() async {
        guard let userID = KeychainHelper.read(key: Self.appleUserIDKey) else { return }

        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await provider.credentialState(forUserID: userID)
            if state == .revoked || state == .notFound {
                signOut(modelContext: nil)
            }
        } catch {
            // Silently handle — don't force sign out on transient errors
        }
    }

    // MARK: - Handle Sign-In Result

    func handleSignIn(result: Result<ASAuthorization, Error>, modelContext: ModelContext) {
        switch result {
        case .success(let authorization):
            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                return
            }

            let userID = credential.user
            let fullName = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            let email = credential.email ?? ""

            // Save user ID to Keychain for credential state checks
            KeychainHelper.save(key: Self.appleUserIDKey, value: userID)

            // Check if profile already exists (re-sign-in)
            let descriptor = FetchDescriptor<UserProfile>(
                predicate: #Predicate { $0.appleUserID == userID }
            )
            if let existing = try? modelContext.fetch(descriptor).first {
                // Update name/email if Apple provided them (only on first sign-in)
                if !fullName.isEmpty { existing.fullName = fullName }
                if !email.isEmpty { existing.email = email }
                currentUser = existing
            } else {
                let profile = UserProfile(
                    appleUserID: userID,
                    fullName: fullName,
                    email: email
                )
                modelContext.insert(profile)
                currentUser = profile
            }

            isSignedIn = true

        case .failure:
            // User cancelled or error — do nothing
            break
        }
    }

    // MARK: - Debug Sign-In

    #if DEBUG
    func createDebugUser(modelContext: ModelContext) {
        let debugID = "debug-user-\(UUID().uuidString)"
        KeychainHelper.save(key: Self.appleUserIDKey, value: debugID)

        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate { $0.appleUserID == debugID }
        )
        if let existing = try? modelContext.fetch(descriptor).first {
            currentUser = existing
        } else {
            let profile = UserProfile(
                appleUserID: debugID,
                fullName: "Dev User",
                email: "dev@glowing.test"
            )
            modelContext.insert(profile)
            currentUser = profile
        }
        isSignedIn = true
    }
    #endif

    // MARK: - Sign Out

    func signOut(modelContext: ModelContext?) {
        KeychainHelper.delete(key: Self.appleUserIDKey)
        if let context = modelContext, let user = currentUser {
            context.delete(user)
        }
        currentUser = nil
        isSignedIn = false
    }
}
