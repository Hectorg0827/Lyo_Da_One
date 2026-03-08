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
    
    // Initialize directly to ensure instant loading
    init() {
        self.availableAds = Self.mockAds
    }
    
    @Published var availableAds: [LyoAd] = []
    
    func fetchAds() async {
        // Ads are now synchronously available directly on init.
        // If a real backend is implemented, fetch here and update self.availableAds without a fixed sleep.
        self.availableAds = Self.mockAds
    }
    
    // Hardcoded custom backend ads
    private static let mockAds: [LyoAd] = [
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
