import SwiftUI
import UIKit

struct LyoOverlayView: View {
    @Binding var isPresented: Bool
    var startFrame: CGRect // The frame of the tab bar button
    
    @EnvironmentObject var viewModel: LyoAIViewModel
    
    @State private var animationState: AnimationState = .initial
    // Local copy of thinking state for animation timing if needed, OR map to viewModel.isLoading
    // Keeping isThinking to allow for smooth transitions/animations separate from logic
    @State private var isThinking = false 
    
    enum AnimationState {
        case initial // At tab bar position
        case active // Center screen
        case chatting // Small in chat
    }
    
    // ChatMessage struct removed, using LyoMessage from ViewModel
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Blurred Background & Ambient Effects
                if animationState != .initial {
                    ZStack {
                        Rectangle()
                            .fill(.ultraThinMaterial)
                            .ignoresSafeArea()
                        
                        // Ambient "Alive" Particles
                        ForEach(0..<5) { i in
                            Circle()
                                .fill(Color(hex: "FF8C00").opacity(0.1))
                                .frame(width: CGFloat.random(in: 50...150), height: CGFloat.random(in: 50...150))
                                .position(
                                    x: CGFloat.random(in: 0...geometry.size.width),
                                    y: CGFloat.random(in: 0...geometry.size.height)
                                )
                                .blur(radius: 30)
                                .animation(
                                    Animation.easeInOut(duration: Double.random(in: 5...10))
                                        .repeatForever(autoreverses: true),
                                    value: animationState
                                )
                        }
                    }
                    .transition(.opacity)
                    .onTapGesture {
                        if animationState == .active {
                            close()
                        }
                    }
                }
                
                // Main Content Stack (Chat/Suggestions + Input)
                VStack(spacing: 0) {
                    if animationState == .chatting {
                        ScrollViewReader { proxy in
                            ScrollView {
                                VStack(spacing: 16) {
                                    ForEach(viewModel.messages) { message in
                                        ChatBubbleView(message: message)
                                            .id(message.id)
                                    }
                                }
                                .padding(.top, 60) // Space for header/back button
                                .padding(.bottom, 20) // Minimal space before input
                            }
                            .onChange(of: viewModel.messages.count) { _ in
                                if let lastId = viewModel.messages.last?.id {
                                    withAnimation {
                                        proxy.scrollTo(lastId, anchor: .bottom)
                                    }
                                }
                            }
                        }
                    } else {
                        Spacer()
                    }
                    
                    if animationState == .active {
                        // Suggestions
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(viewModel.suggestions) { chip in
                                    LyoSuggestionChip(text: chip.text) { 
                                        viewModel.inputText = chip.text
                                        submitText() 
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.bottom, 4)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    
                    if animationState != .initial {
                        // Input Bar
                        // Input Bar
                        HybridInputBar(
                            text: $viewModel.inputText,
                            isListening: Binding(
                                get: { viewModel.isVoiceActive },
                                set: { active in
                                    if active { viewModel.startListening() } else { viewModel.stopListening() }
                                }
                            ),
                            onSubmit: {
                                submitText()
                            }
                        )
                        .padding()
                        .padding(.bottom, animationState == .chatting ? 0 : 20)
                        .transition(.move(edge: .bottom))
                    }
                }
                
                // Avatar
                // We only show this "floating" avatar in .initial and .active states.
                // In .chatting state, it "disappears" (opacity 0) UNLESS it is thinking.
                if animationState != .chatting || isThinking {
                    LyoAvatarView(
                        size: animationState == .active ? 256 : (isThinking ? 100 : 60),
                        isListening: viewModel.isVoiceActive,
                        isThinking: isThinking
                    ) {
                        // On Tap Avatar
                    }
                    .position(
                        x: animationState == .active ? geometry.size.width / 2 : (isThinking ? geometry.size.width / 2 : startFrame.midX),
                        y: animationState == .active ? geometry.size.height / 2 - 50 : (isThinking ? geometry.size.height - 180 : startFrame.midY)
                    )
                    .opacity((animationState == .chatting && !isThinking) ? 0 : 1)
                }
                
                // Close Button (Top Right)
                if animationState != .initial {
                    VStack {
                        HStack {
                            Spacer()
                            Button(action: close) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .padding()
                        }
                        Spacer()
                    }
                }
            }
        }
        .onAppear {
            // Trigger the "Jump"
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
                animationState = .active
            }
        }
    }
    
    private func close() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            animationState = .initial
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            isPresented = false
        }
    }
    
    private func submitText() {
        guard !viewModel.inputText.isEmpty else { return }
        
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        
        // Trigger thinking animation
        withAnimation {
            isThinking = true
        }
        
        Task {
            await viewModel.sendMessage()
            
            await MainActor.run {
                withAnimation {
                    isThinking = false
                    // Transition to chatting state if not already
                    if animationState == .active {
                        animationState = .chatting
                    }
                }
                
                // Haptic: Response Received
                let responseGenerator = UINotificationFeedbackGenerator()
                responseGenerator.notificationOccurred(.success)
            }
        }
    }
}

struct LyoSuggestionChip: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(text)
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
        }
    }
}

struct HybridInputBar: View {
    @Binding var text: String
    @Binding var isListening: Bool
    var onSubmit: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Text Input with Send Button
            HStack {
                TextField("Ask Lyo...", text: $text)
                    .foregroundColor(.white)
                    .onSubmit(onSubmit)
                
                if !text.isEmpty {
                    Button(action: onSubmit) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(Color(hex: "FF8C00"))
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(25)
            
            // Mic Button (Smaller)
            Button(action: { isListening.toggle() }) {
                Image(systemName: isListening ? "waveform" : "mic.fill")
                    .font(.body) // Smaller font
                    .foregroundColor(.white)
                    .padding(10) // Smaller padding
                    .background(Color(hex: "FF8C00"))
                    .clipShape(Circle())
            }
        }
    }
}
