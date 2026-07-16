import SwiftUI

struct ProactiveHintBanner: View {
    @ObservedObject var memoryService = SmartMemoryService.shared
    @State private var isVisible = false
    @State private var isDismissed = false
    
    let onTap: () -> Void
    
    var body: some View {
        if let hint = memoryService.proactiveHint, !isDismissed {
            HStack {
                Text(hint)
                    .font(.subheadline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onTap) {
                    Text("Review")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Button(action: { isDismissed = true }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [.purple, .blue],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .padding(.horizontal)
            .offset(y: isVisible ? 0 : -100)
            .opacity(isVisible ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: isVisible)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isVisible = true
                }
            }
        }
    }
}
