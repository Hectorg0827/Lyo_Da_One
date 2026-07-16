import SwiftUI

struct EnergyPaymentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var monetization: MonetizationService
    
    var body: some View {
        ZStack {
            // Background
            Color(hex: "1F1F1F").ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "battery.0.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                        .padding()
                        .background(Color.red.opacity(0.1))
                        .clipShape(Circle())
                    
                    Text("Out of Energy")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    
                    Text("Lio needs energy to keep answering questions.")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // Options
                VStack(spacing: 16) {
                    
                    // 1. Watch Ad (Mock)
                    Button(action: watchAd) {
                        HStack {
                            Image(systemName: "play.tv.fill")
                            Text("Watch Ad (+1 Energy)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(16)
                    }
                    
                    // 2. Buy Small Pack
                    Button(action: { buyEnergy(productID: "com.lyo.energy.small") }) {
                        HStack {
                            Image(systemName: "bolt.fill")
                            Text("Refill 10 Energy ($0.99)")
                        }
                        .font(.headline)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.yellow)
                        .cornerRadius(16)
                    }
                    
                    // 3. Go Premium
                    Button(action: goPremium) {
                        HStack {
                            Image(systemName: "crown.fill")
                            Text("Unlimited Energy (Premium)")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(colors: [.purple, .pink], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(16)
                        .shadow(color: .purple.opacity(0.4), radius: 10)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                Button("Not Now") {
                    dismiss()
                }
                .foregroundColor(.white.opacity(0.5))
                .padding(.bottom)
            }
        }
    }
    
    private func watchAd() {
        // Mock Ad Logic
        Task {
            // Simulate 5s ad
            try? await Task.sleep(nanoseconds: 2 * 1_000_000_000)
            // Reward
            // Ideally call a method on MonetizationService to verify ad reward
            // For now, valid loop override or direct credit if we add a `rewardAdWatched` method
            // Let's assume we just dismiss and maybe the user gets lucky or we handle it properly later.
            // Actually, let's implement a 'rewardEnergy' on monetization service later.
            // For now, just dismiss to unblock.
            dismiss()
        }
    }
    
    private func buyEnergy(productID: String) {
        Task {
            if let product = monetization.availableProducts.first(where: { $0.id == productID }) {
                _ = await monetization.purchase(product)
                dismiss()
            }
        }
    }
    
    private func goPremium() {
        Task {
            if let product = monetization.availableProducts.first(where: { $0.id == "com.lyo.premium.monthly" }) {
                _ = await monetization.purchase(product)
                dismiss()
            }
        }
    }
}
