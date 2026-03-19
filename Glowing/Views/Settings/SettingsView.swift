import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showPaywall = false
    @State private var showSignOutConfirmation = false

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
        .task {
            await subscriptionManager.loadProducts()
            await subscriptionManager.checkEntitlements()
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .modelContainer(for: UserProfile.self, inMemory: true)
}
