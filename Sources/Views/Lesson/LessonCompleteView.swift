import SwiftUI

public struct LessonCompleteView: View {
    @ObservedObject var analytics = LyoAnalyticsManager.shared
    let activePalette: LyoLessonPalette
    let onFinish: () -> Void
    
    @State private var appearAnimation = false
    
    public init(palette: LyoLessonPalette, onFinish: @escaping () -> Void) {
        self.activePalette = palette
        self.onFinish = onFinish
    }
    
    public var body: some View {
        ZStack {
            AnimatedMeshBackground(palette: activePalette, phase: appearAnimation ? .pi : 0)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer().frame(height: 60)
                
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 80))
                    .foregroundColor(Color(hex: activePalette.color3Hex) ?? .yellow)
                    .scaleEffect(appearAnimation ? 1.0 : 0.5)
                    .opacity(appearAnimation ? 1.0 : 0)
                    .animation(.spring(response: 0.6, dampingFraction: 0.6).delay(0.2), value: appearAnimation)
                
                Text("Lesson Complete!")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(appearAnimation ? 1.0 : 0)
                    .offset(y: appearAnimation ? 0 : 20)
                    .animation(.easeOut(duration: 0.8).delay(0.4), value: appearAnimation)
                
                // Analytics Summary Box
                VStack(spacing: 24) {
                    MetricRow(
                        title: "Time Focused",
                        value: formatDuration(analytics.sessionDuration),
                        icon: "timer"
                    )
                    
                    if analytics.quizzesAttempted > 0 {
                        Divider().background(Color.white.opacity(0.2))
                        
                        MetricRow(
                            title: "Quizzes Mastered",
                            value: "\(analytics.quizzesCorrect) / \(analytics.quizzesAttempted)",
                            icon: "brain.head.profile"
                        )
                    }
                }
                .padding(32)
                .background(.ultraThinMaterial)
                .cornerRadius(24)
                .padding(.horizontal, 24)
                .opacity(appearAnimation ? 1.0 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.6), value: appearAnimation)
                
                Spacer()
                
                Button(action: onFinish) {
                    Text("Return to Hub")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color(hex: activePalette.color2Hex) ?? .blue)
                        .cornerRadius(30)
                        .padding(.horizontal, 32)
                        .shadow(color: (Color(hex: activePalette.color2Hex) ?? .blue).opacity(0.4), radius: 12, y: 8)
                }
                .opacity(appearAnimation ? 1.0 : 0)
                .offset(y: appearAnimation ? 0 : 20)
                .animation(.easeOut(duration: 0.8).delay(0.8), value: appearAnimation)
                
                Spacer().frame(height: 40)
            }
        }
        .onAppear {
            analytics.endSession()
            LyoHapticManager.shared.playQuizSuccess()
            withAnimation {
                appearAnimation = true
            }
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

fileprivate struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 32)
            
            Text(title)
                .font(.system(size: 20, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }
}
