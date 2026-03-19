import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var subscriptionManager = SubscriptionManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "sparkle")
                            .font(.system(size: 48))
                            .foregroundStyle(.tint)

                        Text("Glowing Premium")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Unlock the full power of AI skincare analysis")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)

                    // Features
                    VStack(alignment: .leading, spacing: 16) {
                        featureRow(icon: "sparkles", title: "AI Skin Analysis", description: "Get detailed analysis from your weekly photos")
                        featureRow(icon: "chart.line.uptrend.xyaxis", title: "Score Tracking", description: "Track your skin health improvements over time")
                        featureRow(icon: "clock.arrow.circlepath", title: "Full History", description: "Access all your past sessions and comparisons")
                        featureRow(icon: "trophy.fill", title: "Achievements", description: "Earn badges for consistency and improvement")
                    }
                    .padding(.horizontal, 24)

                    // Price
                    if let product = subscriptionManager.product {
                        VStack(spacing: 8) {
                            Text(product.displayPrice)
                                .font(.title)
                                .fontWeight(.bold)

                            Text("per month")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Subscribe Button
                    Button {
                        Task { await subscriptionManager.purchase() }
                    } label: {
                        Text("Subscribe Now")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.horizontal, 24)

                    // Restore
                    Button("Restore Purchases") {
                        Task { await subscriptionManager.restorePurchases() }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    if let error = subscriptionManager.purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(.horizontal, 24)
                    }

                    // Legal
                    Text("Payment will be charged to your Apple ID account. Subscription automatically renews unless cancelled at least 24 hours before the end of the current period.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 16)
                }
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .task {
                await subscriptionManager.loadProducts()
            }
        }
    }

    private func featureRow(icon: String, title: String, description: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    PaywallView()
}
