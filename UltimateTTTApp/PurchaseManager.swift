import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    /// Create this non-consumable product with the same ID in App Store Connect.
    static let removeAdsProductID = "com.killjoy00.ultttt.remove_ads"

    @Published private(set) var adsRemoved = false
    @Published private(set) var product: Product?
    @Published private(set) var isPurchasing = false
    @Published var errorMessage: String?

    private var transactionUpdates: Task<Void, Never>?

    init() {
        transactionUpdates = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result,
                   transaction.productID == Self.removeAdsProductID {
                    await transaction.finish()
                }
                await self.refreshEntitlement()
            }
        }
    }

    deinit { transactionUpdates?.cancel() }

    func prepare() async {
        await refreshEntitlement()
        do {
            product = try await Product.products(for: [Self.removeAdsProductID]).first
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refreshEntitlement() async {
        var entitled = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            if transaction.productID == Self.removeAdsProductID,
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        adsRemoved = entitled
    }

    func buyRemoveAds() async {
        guard let product, !adsRemoved, !isPurchasing else { return }
        isPurchasing = true
        defer { isPurchasing = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                guard case .verified(let transaction) = verification else {
                    errorMessage = "The App Store couldn't verify this purchase."
                    return
                }
                guard transaction.productID == Self.removeAdsProductID else { return }
                await transaction.finish()
                await refreshEntitlement()
            case .pending, .userCancelled:
                break // Never grant an entitlement until a verified transaction arrives.
            @unknown default:
                break
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync() // Only call in response to an explicit tap.
            await refreshEntitlement()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
