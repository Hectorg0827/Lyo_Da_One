import SwiftUI

// MARK: - Subscription/Paywall View
struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var monetization = MonetizationService.shared
    @State private var selectedProduct: SubscriptionProduct?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Hero Section
                    VStack(spacing: 16) {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        
                        Text("Lyo Premium")
                            .font(.largeTitle.bold())
                        
                        Text("Unlock unlimited AI-powered learning")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Benefits List
                    VStack(alignment: .leading, spacing: 16) {
                        benefitRow(icon: "infinity", title: "Unlimited AI Energy", description: "Never run out of AI interactions")
                        benefitRow(icon: "brain.head.profile", title: "Advanced AI Features", description: "Access to premium AI study modes")
                        benefitRow(icon: "chart.line.uptrend.xyaxis", title: "Detailed Analytics", description: "Track your learning progress in depth")
                        benefitRow(icon: "bell.badge.fill", title: "Priority Support", description: "Get help when you need it")
                        benefitRow(icon: "cloud.fill", title: "Cloud Sync", description: "Sync across all your devices")
                    }
                    .padding(.horizontal)
                    
                    // Pricing Options
                    VStack(spacing: 12) {
                        Text("Choose Your Plan")
                            .font(.headline)
                        
                        // Monthly Option
                        subscriptionOption(
                            title: "Monthly",
                            price: "$9.99",
                            period: "per month",
                            savings: nil,
                            product: monetization.availableProducts.first { $0.id == "com.lyo.premium.monthly" }
                        )
                        
                        // Yearly Option (Best Value)
                        subscriptionOption(
                            title: "Yearly",
                            price: "$79.99",
                            period: "per year",
                            savings: "Save 33%",
                            product: monetization.availableProducts.first { $0.id == "com.lyo.premium.yearly" },
                            isBestValue: true
                        )
                    }
                    .padding()
                    
                    // Purchase Button
                    Button {
                        purchaseSelected()
                    } label: {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Continue")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(selectedProduct != nil ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(selectedProduct == nil || isPurchasing)
                    .padding(.horizontal)
                    
                    // Error Message
                    if let error = errorMessage {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                    
                    // Restore & Terms
                    VStack(spacing: 8) {
                        Button("Restore Purchases") {
                            Task {
                                await monetization.restorePurchases()
                            }
                        }
                        .font(.subheadline)
                        
                        HStack(spacing: 16) {
                            Link("Terms of Service", destination: URL(string: "https://yourapp.com/terms")!)
                            Link("Privacy Policy", destination: URL(string: "https://yourapp.com/privacy")!)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            // Load products if not loaded
            if monetization.availableProducts.isEmpty {
                await monetization.loadProducts()
            }
        }
    }
    
    // MARK: - Helper Views
    
    private func benefitRow(icon: String, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    private func subscriptionOption(
        title: String,
        price: String,
        period: String,
        savings: String?,
        product: SubscriptionProduct?,
        isBestValue: Bool = false
    ) -> some View {
        let isSelected = selectedProduct?.id == product?.id
        
        return Button {
            selectedProduct = product
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(title)
                            .font(.headline)
                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2.bold())
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                    }
                    if let savings = savings {
                        Text(savings)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text(price)
                        .font(.title2.bold())
                    Text(period)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                    .cornerRadius(12)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Actions
    
    private func purchaseSelected() {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        errorMessage = nil
        
        Task {
            let success = await monetization.purchase(product)
            
            await MainActor.run {
                isPurchasing = false
                
                if success {
                    dismiss()
                } else {
                    errorMessage = "Purchase failed. Please try again."
                }
            }
        }
    }
}

// MARK: - Preview
struct SubscriptionView_Previews: PreviewProvider {
    static var previews: some View {
        SubscriptionView()
    }
}
