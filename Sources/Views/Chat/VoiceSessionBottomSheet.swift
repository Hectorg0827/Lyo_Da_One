import SwiftUI

struct VoiceSessionBottomSheet: View {
    @ObservedObject var viewModel: LyoAIViewModel
    @Environment(\.dismiss) private var dismiss
    
    @State private var orbScale: CGFloat = 1.0
    @State private var orbRotation: Double = 0
    
    var body: some View {
        VStack(spacing: 30) {
            // Top Notch Handle
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
            
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                }
                Spacer()
                Text("Lyo Voice Session")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
                Button {
                    // Settings or Info
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            .padding(.horizontal, 24)
            
            Spacer()
            
            // Live Visualizer / Orb
            ZStack {
                // Background Glows
                Circle()
                    .fill(Color(hex: "FF8C00").opacity(0.2))
                    .frame(width: 250, height: 250)
                    .blur(radius: 40)
                    .scaleEffect(orbScale)
                
                // Outer Ring
                Circle()
                    .stroke(
                        AngularGradient(
                            colors: [.orange, .purple, .blue, .orange],
                            center: .center
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 220, height: 220)
                    .rotationEffect(.degrees(orbRotation))
                
                // Mascot / Icon
                VStack(spacing: 12) {
                    Image("lyo_avatar_large") // Assuming large avatar exists
                        .resizable()
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                    
                    Text(viewModel.isAISpeaking ? "Lyo is speaking..." : (viewModel.isAIThinking ? "Thinking..." : "Listening..."))
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                }
            }
            .padding(.bottom, 40)
            
            // Transcript Area
            VStack(spacing: 8) {
                if !viewModel.lastLiveTranscript.isEmpty {
                    Text(viewModel.lastLiveTranscript)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 30)
                        .transition(.opacity)
                } else if viewModel.isAISpeaking {
                    Text("The AI is generating a response...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                } else {
                    Text("Say something like 'Explain the solar system'...")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.4))
                }
            }
            .frame(height: 100)
            
            Spacer()
            
            // Controls
            HStack(spacing: 60) {
                Button {
                    // Mute toggle
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "mic.slash.fill")
                            .font(.title2)
                        Text("Mute")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
                
                Button {
                    if viewModel.isVoiceActive {
                        viewModel.stopListening()
                    } else {
                        viewModel.startListening()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(viewModel.isVoiceActive ? Color.red : Color.white)
                            .frame(width: 70, height: 70)
                        
                        Image(systemName: viewModel.isVoiceActive ? "stop.fill" : "mic.fill")
                            .font(.title)
                            .foregroundColor(viewModel.isVoiceActive ? .white : .black)
                    }
                }
                .shadow(color: (viewModel.isVoiceActive ? Color.red : Color.white).opacity(0.3), radius: 10)
                
                Button {
                    // Keyboard / Text mode
                    dismiss()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "keyboard")
                            .font(.title2)
                        Text("Chat")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
            }
            .padding(.bottom, 40)
        }
        .background(Color.black.opacity(0.95))
        .background(.ultraThinMaterial)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                orbScale = 1.1
            }
            withAnimation(.linear(duration: 4.0).repeatForever(autoreverses: false)) {
                orbRotation = 360
            }
        }
    }
}

#Preview {
    VoiceSessionBottomSheet(viewModel: LyoAIViewModel())
}
