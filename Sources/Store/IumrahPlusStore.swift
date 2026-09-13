import Foundation
import Combine
import StoreKit

/// StoreKit 2 compatibility for the existing `iumrah.plus` non-consumable.
/// This preserves ownership for customers of the published 1.0.x Flutter app.
@MainActor
final class IumrahPlusStore: ObservableObject {
    static let shared = IumrahPlusStore()
    static let productID = AppIdentity.iumrahPlusProductID

    @Published private(set) var product: Product?
    @Published private(set) var isEntitled: Bool
    @Published private(set) var lastError: String?

    private var updatesTask: Task<Void, Never>?
    private var hasStarted = false

    private init() {
        isEntitled = Self.readLegacyPremiumFlag()
        updatesTask = Task { [weak self] in
            await self?.listenForTransactions()
        }
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await loadProduct()
        await refreshEntitlement()
    }

    func loadProduct() async {
        do {
            product = try await Product.products(for: [Self.productID]).first
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    @discardableResult
    func purchase() async throws -> Bool {
        if product == nil { await loadProduct() }
        guard let product else { throw IumrahPlusStoreError.productUnavailable }

        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try Self.verified(verification)
            guard transaction.productID == Self.productID else { return false }
            await transaction.finish()
            setEntitled(true)
            return true
        case .pending, .userCancelled:
            return false
        @unknown default:
            return false
        }
    }

    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlement()
    }

    func refreshEntitlement() async {
        var verifiedStoreEntitlement = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            guard transaction.revocationDate == nil else { continue }
            verifiedStoreEntitlement = true
            break
        }
        setEntitled(verifiedStoreEntitlement || Self.readLegacyPremiumFlag())
    }

    private func listenForTransactions() async {
        for await result in Transaction.updates {
            guard !Task.isCancelled else { return }
            guard case .verified(let transaction) = result else { continue }
            guard transaction.productID == Self.productID else { continue }
            if transaction.revocationDate == nil { setEntitled(true) }
            await transaction.finish()
        }
    }

    private func setEntitled(_ value: Bool) {
        isEntitled = value
        guard value else { return }
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: "iumrah.plus.entitled")
        defaults.set(true, forKey: "is_premium")
        // Flutter shared_preferences uses the flutter.* prefix on Apple platforms.
        defaults.set(true, forKey: "flutter.is_premium")
    }

    private static func readLegacyPremiumFlag() -> Bool {
        let defaults = UserDefaults.standard
        return defaults.bool(forKey: "iumrah.plus.entitled")
            || defaults.bool(forKey: "is_premium")
            || defaults.bool(forKey: "flutter.is_premium")
    }

    private static func verified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .verified(let safe): return safe
        case .unverified: throw IumrahPlusStoreError.unverifiedTransaction
        }
    }
}

enum IumrahPlusStoreError: LocalizedError {
    case productUnavailable
    case unverifiedTransaction

    var errorDescription: String? {
        switch self {
        case .productUnavailable: return "iUmra Plus is not available from the App Store right now."
        case .unverifiedTransaction: return "The App Store transaction could not be verified."
        }
    }
}
