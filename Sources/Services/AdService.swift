import Foundation
import Combine

/// Represents an internal promotional advertisement
struct LyoAd: Identifiable, Codable {
    let id: String
    let title: String
    let subtitle: String
    let callToAction: String
    let imageURL: String?
    let destinationURL: String?
}

/// Service responsible for fetching and managing promotional content
@MainActor
class AdService: ObservableObject {
    static let shared = AdService()
    
    @Published var availableAds: [LyoAd] = []
    
    // Mock network delay to simulate fetching from backend
    func fetchAds() async {
        // In a real implementation this would hit /api/v1/ads
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Hardcoded custom backend ads for now
        self.availableAds = [
            LyoAd(
                id: "ad_1",
                title: "Lyo Premium 🌟",
                subtitle: "Unlock unlimited AI course generation and priority support.",
                callToAction: "Upgrade Now",
                imageURL: "https://images.unsplash.com/photo-1517694712202-14dd9538aa97?auto=format&fit=crop&q=80&w=1000",
                destinationURL: "lyo://upgrade"
            ),
            LyoAd(
                id: "ad_2",
                title: "Join the Lyo Community",
                subtitle: "Connect with thousands of learners in our Discord server.",
                callToAction: "Join Discord",
                imageURL: "https://images.unsplash.com/photo-1522071820081-009f0129c71c?auto=format&fit=crop&q=80&w=1000",
                destinationURL: "https://discord.gg/lyo"
            ),
            LyoAd(
                id: "ad_3",
                title: "Master Machine Learning",
                subtitle: "Check out our newest expert-curated learning path.",
                callToAction: "Start Path",
                imageURL: "https://images.unsplash.com/photo-1509228468518-180dd4864904?auto=format&fit=crop&q=80&w=1000",
                destinationURL: "lyo://path/ml"
            )
        ]
    }
}
