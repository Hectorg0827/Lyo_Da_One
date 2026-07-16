import SwiftUI

struct MessageAudioButton: View {
    let messageId: String
    let text: String
    let isPlaying: Bool
    let progress: Double
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            ZStack {
                // Progress Ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 2)
                    .frame(width: 28, height: 28)
                
                if isPlaying {
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .blue],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                        .frame(width: 28, height: 28)
                        .rotationEffect(.degrees(-90))
                }
                
                // Play/Pause Icon
                Image(systemName: isPlaying ? "pause.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(isPlaying ? .purple : .secondary)
            }
        }
        .buttonStyle(.plain)
    }
}
