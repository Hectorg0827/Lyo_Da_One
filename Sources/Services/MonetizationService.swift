import Foundation
import StoreKit

// MARK: - Monetization Service

/// Service for managing in-app purchases and subscription with the Lyo backend.
/// Uses StoreKit 2 for iOS 15+ with fallback handling.
@MainActor
final class MonetizationService: ObservableObject {
    static let shared = MonetizationService()
    
    private var baseURL: String { AppConfig.baseURL }
    private let tokenManager = TokenManager.shared
    
    // MARK: - Published State
    
    @Published var products: [Product] = []
    @Published var purchasedProductIDs: Set<String> = []
    @Published var currentTier: SubscriptionTier = .free
    @Published var energyCredits: Int = 10
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var availableProducts: [SubscriptionProduct] = []
    
    // Product identifiers (configure in App Store Connect)
    private let productIDs: Set<String> = [
        "com.lyo.premium.monthly",
        "com.lyo.premium.yearly",
        "com.lyo.energy.small",      // 50 energy credits
        "com.lyo.energy.large",      // 200 energy credits
        "com.lyo.course.unlock"      // Single course unlock
    ]
    
    private var transactionListener: Task<Void, Error>?
    
    private init() {
        // Start listening for transactions
        transactionListener = listenForTransactions()
        
        // Load products on init
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        transactionListener?.cancel()
    }
    
    // MARK: - Load Products from App Store
    
    func loadProducts() async {
        isLoading = true
        errorMessage = nil
        
        do {
            products = try await Product.products(for: productIDs)
            print("✅ Loaded \(products.count) products from App Store")
            
            // Also populate availableProducts for views that use SubscriptionProduct
            availableProducts = products.map { product in
                SubscriptionProduct(
                    id: product.id,
                    displayName: product.displayName,
                    price: product.price,
                    priceFormatted: product.displayPrice,
                    period: (product.subscription?.subscriptionPeriod.unit == .month) ? "month" : "year"
                )
            }
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "Failed to load products"
            
            // Provide fallback products for UI
            availableProducts = [
                SubscriptionProduct(id: "com.lyo.premium.monthly", displayName: "Monthly Premium", price: 9.99, priceFormatted: "$9.99", period: "month"),
                SubscriptionProduct(id: "com.lyo.premium.yearly", displayName: "Yearly Premium", price: 79.99, priceFormatted: "$79.99", period: "year")
            ]
        }
        
        isLoading = false
    }
    
    // MARK: - Check Purchased Products
    
    func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        
        // Check subscriptions
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            
            if transaction.revocationDate == nil {
                purchased.insert(transaction.productID)
            }
        }
        
        purchasedProductIDs = purchased
        
        // Update tier based on purchases
        if purchasedProductIDs.contains("com.lyo.premium.monthly") ||
           purchasedProductIDs.contains("com.lyo.premium.yearly") {
            currentTier = .premium
        } else {
            currentTier = .free
        }
        
        // Sync with backend
        await syncSubscriptionWithBackend()
    }
    
    // MARK: - Purchase Product
    
    /// Purchase using SubscriptionProduct wrapper (for views)
    func purchase(_ subscriptionProduct: SubscriptionProduct) async -> Bool {
        // Find the actual StoreKit Product
        guard let product = products.first(where: { $0.id == subscriptionProduct.id }) else {
            print("❌ Product not found: \(subscriptionProduct.id)")
            errorMessage = "Product not available"
            return false
        }
        
        do {
            let transaction = try await purchase(product)
            return transaction != nil
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    /// Purchase using StoreKit Product directly
    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        let result = try await product.purchase()
        
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            
            // Validate receipt with backend
            await validatePurchaseWithBackend(transaction: transaction)
            
            // Finish the transaction
            await transaction.finish()
            
            // Update local state
            await updatePurchasedProducts()
            
            print("✅ Purchase successful: \(product.id)")
            return transaction
            
        case .userCancelled:
            print("ℹ️ User cancelled purchase")
            return nil
            
        case .pending:
            print("ℹ️ Purchase pending approval")
            errorMessage = "Purchase pending approval"
            return nil
            
        @unknown default:
            print("❌ Unknown purchase result")
            return nil
        }
    }
    
    // MARK: - Restore Purchases
    
    func restorePurchases() async {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            print("✅ Purchases restored")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = "Failed to restore purchases"
        }
    }
    
    // MARK: - Transaction Listener
    
    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try await self.checkVerified(result)
                    
                    // Validate with backend
                    await self.validatePurchaseWithBackend(transaction: transaction)
                    
                    await transaction.finish()
                    
                    await MainActor.run {
                        Task {
                            _ = await self.updatePurchasedProducts()
                        }
                    }
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Verification
    
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw StoreError.failedVerification(error)
        case .verified(let item):
            return item
        }
    }
    
    // MARK: - Backend Sync
    
    /// Validate purchase with backend and sync subscription status
    private func validatePurchaseWithBackend(transaction: StoreKit.Transaction) async {
        guard await tokenManager.getToken() != nil else { return }
        
        do {
            let receipt = try await getAppStoreReceipt()
            
            let request = PurchaseValidationRequest(
                productId: transaction.productID,
                transactionId: String(transaction.id),
                originalTransactionId: transaction.id != transaction.originalID ? String(transaction.originalID) : nil,
                receipt: receipt,
                purchaseDate: transaction.purchaseDate.ISO8601Format()
            )
            
            _ = try await sendPurchaseValidation(request)
            print("✅ Purchase validated with backend")
            
        } catch {
            print("⚠️ Backend validation failed: \(error)")
            // Continue anyway - StoreKit is the source of truth
        }
    }
    
    /// Sync subscription status with backend
    func syncSubscriptionWithBackend() async {
        guard await tokenManager.getToken() != nil else { return }
        
        do {
            // Get current entitlements
            var activeProducts: [String] = []
            var expirationDate: Date?
            
            for await result in Transaction.currentEntitlements {
                guard case .verified(let transaction) = result else { continue }
                
                if transaction.revocationDate == nil {
                    activeProducts.append(transaction.productID)
                    
                    // Get subscription expiration
                    if let expDate = transaction.expirationDate {
                        if expirationDate == nil || expDate > expirationDate! {
                            expirationDate = expDate
                        }
                    }
                }
            }
            
            let syncRequest = SubscriptionSyncRequest(
                tier: currentTier.rawValue,
                activeProducts: activeProducts,
                expirationDate: expirationDate?.ISO8601Format()
            )
            
            let response = try await sendSubscriptionSync(syncRequest)
            
            // Update local state from backend response
            energyCredits = response.energyCredits
            
            print("✅ Subscription synced with backend. Energy: \(energyCredits)")
            
        } catch {
            print("⚠️ Subscription sync failed: \(error)")
        }
    }
    
    /// Get subscription status from backend
    func getSubscriptionStatus() async throws -> SubscriptionStatusResponse {
        guard let authToken = await tokenManager.getToken() else {
            throw MonetizationError.notAuthenticated
        }
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/users/me/subscription",
            method: .get,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Energy Credits
    
    /// Use energy credits for AI interactions
    func useEnergy(amount: Int = 1) async throws -> Bool {
        guard energyCredits >= amount else {
            throw MonetizationError.insufficientEnergy
        }
        
        // Optimistically update
        energyCredits -= amount
        
        // Sync with backend
        do {
            let request = UseEnergyRequest(amount: amount)
            let response = try await sendUseEnergy(request)
            energyCredits = response.remainingEnergy
            return true
        } catch {
            // Revert on failure
            energyCredits += amount
            throw error
        }
    }
    
    /// Refill energy credits (daily refresh or purchase)
    func refillEnergy() async {
        do {
            let response = try await getSubscriptionStatus()
            energyCredits = response.energyCredits
        } catch {
            print("⚠️ Energy refill check failed: \(error)")
        }
    }
    
    // MARK: - Network Helpers
    
    private func getAppStoreReceipt() async throws -> String {
        guard let receiptURL = Bundle.main.appStoreReceiptURL,
              FileManager.default.fileExists(atPath: receiptURL.path) else {
            throw MonetizationError.noReceipt
        }
        
        let receiptData = try Data(contentsOf: receiptURL)
        return receiptData.base64EncodedString()
    }
    
    private func sendPurchaseValidation(_ request: PurchaseValidationRequest) async throws -> PurchaseValidationResponse {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        let bodyDict = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        
        // Use AnyEncodable wrapper for the body
        let encodableBody = bodyDict?.mapValues { AnyEncodable(value: $0) }
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/purchases/validate",
            method: .post,
            body: encodableBody,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    private func sendSubscriptionSync(_ request: SubscriptionSyncRequest) async throws -> SubscriptionSyncResponse {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let bodyData = try encoder.encode(request)
        let bodyDict = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        
        // Use AnyEncodable wrapper for the body
        let encodableBody = bodyDict?.mapValues { AnyEncodable(value: $0) }
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/users/me/subscription/sync",
            method: .post,
            body: encodableBody,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    private func sendUseEnergy(_ request: UseEnergyRequest) async throws -> UseEnergyResponse {
        let encoder = JSONEncoder()
        // Note: UseEnergyRequest doesn't need snake_case conversion for 'amount'
        let bodyData = try encoder.encode(request)
        let bodyDict = try JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        
        // Use AnyEncodable wrapper for the body
        let encodableBody = bodyDict?.mapValues { AnyEncodable(value: $0) }
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/users/me/energy/use",
            method: .post,
            body: encodableBody,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Product Helpers
    
    func product(for id: String) -> Product? {
        products.first { $0.id == id }
    }
    
    var subscriptionProducts: [Product] {
        products.filter { $0.type == .autoRenewable }
    }
    
    var consumableProducts: [Product] {
        products.filter { $0.type == .consumable }
    }
    
    var isPremium: Bool {
        currentTier == .premium
    }
}

// MARK: - Subscription Tier

enum SubscriptionTier: String, Codable {
    case free = "FREE"
    case premium = "PREMIUM"
    
    var displayName: String {
        switch self {
        case .free: return "Free"
        case .premium: return "Premium"
        }
    }
    
    var dailyEnergyLimit: Int {
        switch self {
        case .free: return 10
        case .premium: return 100
        }
    }
    
    var features: [String] {
        switch self {
        case .free:
            return [
                "10 AI interactions per day",
                "Access to free courses",
                "Basic quiz features"
            ]
        case .premium:
            return [
                "100 AI interactions per day",
                "Access to all courses",
                "Advanced AI tutoring",
                "Priority support",
                "Offline access"
            ]
        }
    }
}

// MARK: - Request Models

struct PurchaseValidationRequest: Codable {
    let productId: String
    let transactionId: String
    let originalTransactionId: String?
    let receipt: String
    let purchaseDate: String
}

struct SubscriptionSyncRequest: Codable {
    let tier: String
    let activeProducts: [String]
    let expirationDate: String?
}

struct UseEnergyRequest: Codable {
    let amount: Int
}

// MARK: - Response Models

struct PurchaseValidationResponse: Codable {
    let valid: Bool
    let tier: String
    let energyCredits: Int?
    let message: String?
}

struct SubscriptionSyncResponse: Codable {
    let tier: String
    let energyCredits: Int
    let expirationDate: String?
}

struct SubscriptionStatusResponse: Codable {
    let tier: String
    let energyCredits: Int
    let subscriptionEndDate: String?
    let activeProducts: [String]?
}

struct UseEnergyResponse: Codable {
    let success: Bool
    let remainingEnergy: Int
    let message: String?
}

// MARK: - Errors

enum MonetizationError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case validationFailed
    case syncFailed
    case insufficientEnergy
    case energyUseFailed
    case noReceipt
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in to make purchases"
        case .invalidResponse:
            return "Invalid response from server"
        case .validationFailed:
            return "Purchase validation failed"
        case .syncFailed:
            return "Failed to sync subscription"
        case .insufficientEnergy:
            return "Not enough energy credits"
        case .energyUseFailed:
            return "Failed to use energy credits"
        case .noReceipt:
            return "No purchase receipt available"
        }
    }
}

enum StoreError: LocalizedError {
    case failedVerification(Error)
    
    var errorDescription: String? {
        switch self {
        case .failedVerification(let error):
            return "Verification failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Subscription Product (for StoreKit)
struct SubscriptionProduct: Identifiable {
    let id: String
    let displayName: String
    let price: Decimal
    let priceFormatted: String
    let period: String
    
    init(id: String, displayName: String = "", price: Decimal = 0, priceFormatted: String = "", period: String = "") {
        self.id = id
        self.displayName = displayName
        self.price = price
        self.priceFormatted = priceFormatted
        self.period = period
    }
}
