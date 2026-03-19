import Foundation
import StoreKit
import SwiftData

@MainActor
@Observable
final class SubscriptionManager {
    static let shared = SubscriptionManager()

    static let monthlyProductID = "com.glowing.premium.monthly"
    private static let trialDays = 14

    var product: Product?
    var isSubscribed = false
    var purchaseError: String?

    private var updateListenerTask: Task<Void, Never>?

    private init() {
        updateListenerTask = listenForTransactionUpdates()
    }

    // MARK: - Trial

    var isTrialActive: Bool {
        guard let user = AuthManager.shared.currentUser else { return false }
        let elapsed = Date().timeIntervalSince(user.createdAt)
        return elapsed < Double(Self.trialDays * 86400)
    }

    var trialDaysRemaining: Int {
        guard let user = AuthManager.shared.currentUser else { return 0 }
        let elapsed = Date().timeIntervalSince(user.createdAt)
        let remaining = Double(Self.trialDays * 86400) - elapsed
        return max(0, Int(ceil(remaining / 86400)))
    }

    var isPremium: Bool {
        isTrialActive || isSubscribed
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.monthlyProductID])
            product = products.first
        } catch {
            purchaseError = "Could not load subscription options."
        }
    }

    // MARK: - Check Entitlements

    func checkEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                if transaction.productID == Self.monthlyProductID {
                    isSubscribed = true
                    return
                }
            }
        }
        isSubscribed = false
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
            purchaseError = "Subscription not available."
            return
        }

        purchaseError = nil

        do {
            let result = try await product.purchase()

            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                    isSubscribed = true
                }
            case .pending:
                purchaseError = "Purchase is pending approval."
            case .userCancelled:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseError = error.localizedDescription
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        try? await AppStore.sync()
        await checkEntitlements()
    }

    // MARK: - Transaction Listener

    private func listenForTransactionUpdates() -> Task<Void, Never> {
        Task.detached {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await MainActor.run {
                        if transaction.productID == SubscriptionManager.monthlyProductID {
                            self.isSubscribed = true
                        }
                    }
                }
            }
        }
    }
}
