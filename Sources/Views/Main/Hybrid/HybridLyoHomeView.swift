import SwiftUI
import os

struct HybridLyoHomeView: View {
    @StateObject private var viewModel = LyoAIViewModel()
    @EnvironmentObject var rootViewModel: RootViewModel
    
    // Scroll State
    @State private var scrollOffset: CGFloat = 0
    
    // UI State
    @State private var isChatOverlayOpen = false
    
    private let transitionThreshold: CGFloat = -150 // Point where avatar transforms
    
    var userFirstName: String {
        if let name = rootViewModel.currentUser?.name {
            return name.components(separatedBy: " ").first ?? name
        }
        return "User"
    }
    
    var body: some View {
        ZStack {
            // Layer 1: Scrollable Content
            ScrollView {
                GeometryReader { proxy in
                    Color.clear.preference(
                        key: HybridScrollOffsetKey.self,
                        value: proxy.frame(in: .named("hybridScroll")).minY
                    )
                }
                .frame(height: 0)
                
                VStack(spacing: 0) {
                    // Hero Section
                    HeroSectionView(
                        viewModel: viewModel,
                        userName: userFirstName,
                        onChatTap: {
                            withAnimation { isChatOverlayOpen = true }
                        },
                        onVoiceTap: {
                            HapticManager.shared.medium()
                            Log.ui.info("🎙️ Voice Mode activated")
                            // Voice mode requires backend speech pipeline — future release
                        }
                    )
                    .opacity(calculateHeroOpacity())
                    
                    // Social Feed Section
                    SocialFeedSection(viewModel: viewModel)
                        .padding(.top, 20)
                }
            }
            .coordinateSpace(name: "hybridScroll")
            .onPreferenceChange(HybridScrollOffsetKey.self) { value in
                scrollOffset = value
            }
            
            
            // Layer 3: Chat Overlay
            if isChatOverlayOpen {
                ChatOverlayView(viewModel: viewModel) {
                    withAnimation { isChatOverlayOpen = false }
                }
                .zIndex(100)
            }
        }
        .background(Color("LyoBackground").ignoresSafeArea())
        .onAppear {
            Task {
                await viewModel.loadSocialData()
                await viewModel.loadCourseCards()
            }
        }
    }
    
    private func calculateHeroOpacity() -> Double {
        // Fade out hero as we scroll up
        let progress = min(max(scrollOffset / transitionThreshold, 0), 1)
        return 1.0 - progress
    }
}

struct HybridScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
