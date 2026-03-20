import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var showSignOutConfirmation = false
    @State private var showStartFreshConfirmation = false
    @State private var showOnboarding = false

    #if DEBUG
    private static let openAIKeyName = "com.glowing.openai-api-key"
    @State private var debugAPIKey: String = KeychainHelper.read(key: openAIKeyName) ?? ""
    #endif

    var body: some View {
        Form {
            // Account
            Section("Account") {
                if let user = authManager.currentUser {
                    if !user.fullName.isEmpty {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(user.fullName)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if !user.email.isEmpty {
                        HStack {
                            Text("Email")
                            Spacer()
                            Text(user.email)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Button("Sign Out", role: .destructive) {
                    showSignOutConfirmation = true
                }
            }

            // Subscription
            Section("Subscription") {
                HStack {
                    Text("Status")
                    Spacer()
                    if subscriptionManager.isSubscribed {
                        Text("Premium")
                            .foregroundStyle(.green)
                            .fontWeight(.medium)
                    } else if subscriptionManager.isTrialActive {
                        Text("Trial — \(subscriptionManager.trialDaysRemaining) day\(subscriptionManager.trialDaysRemaining == 1 ? "" : "s") left")
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                    } else {
                        Text("Free")
                            .foregroundStyle(.secondary)
                    }
                }

                if !subscriptionManager.isSubscribed {
                    Button {
                        showPaywall = true
                    } label: {
                        Label("Upgrade to Premium", systemImage: "sparkle")
                    }
                }

                Button("Restore Purchases") {
                    Task { await subscriptionManager.restorePurchases() }
                }
            }

            // Notifications
            Section {
                NavigationLink {
                    NotificationSettingsView()
                } label: {
                    Label("Notifications", systemImage: "bell.fill")
                }
            }

            // Start Fresh
            Section {
                Button(role: .destructive) {
                    showStartFreshConfirmation = true
                } label: {
                    Label("Start Fresh", systemImage: "arrow.counterclockwise")
                }
            } footer: {
                Text("Deletes all routines, photos, and analysis data. You'll redo the photo scan to get new personalized routines.")
            }

            #if DEBUG
            // Developer
            Section("Developer") {
                HStack {
                    Text("Backend")
                    Spacer()
                    Text(APIConfig.useMockBackend ? "Mock (Direct OpenAI)" : "Production")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("OpenAI API Key")
                        .font(.subheadline)

                    SecureField("sk-...", text: $debugAPIKey)
                        .font(.caption)
                        .textContentType(.password)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: debugAPIKey) { _, newValue in
                            if newValue.isEmpty {
                                KeychainHelper.delete(key: Self.openAIKeyName)
                            } else {
                                KeychainHelper.save(key: Self.openAIKeyName, value: newValue)
                            }
                        }
                }
            }
            #endif

            // Version
            Section {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .confirmationDialog("Sign Out", isPresented: $showSignOutConfirmation) {
            Button("Sign Out", role: .destructive) {
                authManager.signOut(modelContext: modelContext)
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
        .confirmationDialog("Start Fresh", isPresented: $showStartFreshConfirmation) {
            Button("Delete Everything & Rescan", role: .destructive) {
                startFresh()
            }
        } message: {
            Text("This will delete all your routines, progress photos, and analysis history. You'll be taken back to the photo scan to generate new routines.")
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingFlowView()
        }
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.checkEntitlements()
        }
    }

    // MARK: - Start Fresh

    private func startFresh() {
        // Delete all routines (cascade deletes steps + day variants)
        do {
            let routines = try modelContext.fetch(FetchDescriptor<Routine>())
            for routine in routines { modelContext.delete(routine) }

            let logs = try modelContext.fetch(FetchDescriptor<RoutineLog>())
            for log in logs { modelContext.delete(log) }

            let photos = try modelContext.fetch(FetchDescriptor<ProgressPhoto>())
            for photo in photos { modelContext.delete(photo) }

            let analyses = try modelContext.fetch(FetchDescriptor<SkinAnalysis>())
            for analysis in analyses { modelContext.delete(analysis) }
        } catch {
            // Best effort cleanup
        }

        // Reset onboarding flag
        if let user = authManager.currentUser {
            user.hasCompletedOnboarding = false
        }

        // Clear any pending background analysis
        PendingAnalysisManager.shared.reset()

        // Launch onboarding
        showOnboarding = true
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
