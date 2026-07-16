import SwiftUI

struct OrientationHintOverlay: View {
    let onDismiss: () -> Void
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }
            
            VStack(spacing: 32) {
                // Rotating phone icon animation
                ZStack {
                    Circle()
                        .fill(Color("LyoAccent").opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "iphone")
                        .font(.system(size: 60))
                        .foregroundColor(Color("LyoAccent"))
                        .rotationEffect(.degrees(isAnimating ? 90 : 0))
                        .animation(
                            .easeInOut(duration: 1.5)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                VStack(spacing: 16) {
                    // Title
                    Text("Best viewed horizontally")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    // Subtitle
                    Text("Rotate your device for the full classroom experience")
                        .font(.system(size: 16))
                        .foregroundColor(Color("LyoTextSecondary"))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                
                // Got it button
                Button {
                    onDismiss()
                } label: {
                    Text("Got it")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(Color("LyoBackground"))
                        .padding(.horizontal, 40)
                        .padding(.vertical, 14)
                        .background(
                            Capsule()
                                .fill(Color("LyoAccent"))
                        )
                }
            }
            .padding(40)
        }
        .onAppear {
            isAnimating = true
        }
    }
}
