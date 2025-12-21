import SwiftUI

struct HybridLyoHomeView: View {
    @StateObject private var viewModel = LyoAIViewModel()
    @EnvironmentObject var rootViewModel: RootViewModel
    
    // Scroll State
    @State private var scrollOffset: CGFloat = 0
    @State private var showFloatingOrb: Bool = false
    
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
                            // TODO: Implement Voice Mode
                            print("Voice Mode Tapped")
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
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    showFloatingOrb = scrollOffset < transitionThreshold
                }
            }
            
            // Layer 2: Floating Orb (Appears on scroll)
            if showFloatingOrb {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingOrbView {
                            withAnimation { isChatOverlayOpen = true }
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 40)
                        .transition(.scale.combined(with: .opacity))
                    }
                }
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
