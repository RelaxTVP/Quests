import Foundation
import StoreKit
import Combine

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    // Set this product in App Store Connect as a Non-Consumable.
    static let lifetimeProductID = "com.miguel.questapp.lifetime"

    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var isPremiumUnlocked = true
    @Published private(set) var isPurchaseInProgress = false
    @Published var purchaseErrorMessage: String?

    private var updatesTask: Task<Void, Never>?

    // Testing mode: disables paywall/purchase flow while keeping structure in place.
    var isPaywallEnabled: Bool { false }

    private init() {
        guard isPaywallEnabled else { return }

        updatesTask = observeTransactionUpdates()

        Task {
            await loadProducts()
            await refreshEntitlements()
        }
    }

    deinit {
        updatesTask?.cancel()
    }

    var localizedPrice: String {
        lifetimeProduct?.displayPrice ?? NSLocalizedString("premium_price_fallback", comment: "")
    }

    func loadProducts() async {
        guard isPaywallEnabled else { return }
        do {
            let products = try await Product.products(for: [Self.lifetimeProductID])
            lifetimeProduct = products.first
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func refreshEntitlements() async {
        guard isPaywallEnabled else {
            isPremiumUnlocked = true
            return
        }
        var unlocked = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.lifetimeProductID && transaction.revocationDate == nil {
                unlocked = true
            }
        }
        isPremiumUnlocked = unlocked
    }

    func purchaseLifetime() async {
        guard isPaywallEnabled else {
            isPremiumUnlocked = true
            return
        }
        guard let product = lifetimeProduct else {
            await loadProducts()
            if lifetimeProduct == nil {
                purchaseErrorMessage = NSLocalizedString("premium_error_product_unavailable", comment: "")
                return
            }
            await purchaseLifetime()
            return
        }

        isPurchaseInProgress = true
        defer { isPurchaseInProgress = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    purchaseErrorMessage = NSLocalizedString("premium_error_verification_failed", comment: "")
                    return
                }
                await transaction.finish()
                await refreshEntitlements()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        guard isPaywallEnabled else {
            isPremiumUnlocked = true
            return
        }
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            purchaseErrorMessage = error.localizedDescription
        }
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                guard case .verified(let transaction) = result else { continue }
                await transaction.finish()
                await refreshEntitlements()
            }
        }
    }
}
