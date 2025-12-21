import SwiftUI

struct TTSVoiceBubbleView: View {
    @State private var animatingBars = [false, false, false]
    
    var body: some View {
        HStack(spacing: 6) {
            // Three animated bars
            ForEach(0..<3) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color("LyoAccent"))
                    .frame(width: 4, height: animatingBars[index] ? 20 : 8)
                    .animation(
                        .easeInOut(duration: 0.5)
                        .repeatForever(autoreverses: true)
                        .delay(Double(index) * 0.15),
                        value: animatingBars[index]
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(Color("LyoSurface"))
                .shadow(color: Color("LyoAccent").opacity(0.3), radius: 8)
        )
        .onAppear {
            // Start animation
            for i in 0..<3 {
                animatingBars[i] = true
            }
        }
    }
}
