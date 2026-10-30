import SwiftUI

/// A dedicated, hands-free stage for LYO Voice. The transcript is the same
/// canonical chat history the learner returns to when the session ends.
struct VoiceSessionBottomSheet: View {
    @ObservedObject var viewModel: LyoAIViewModel
    @ObservedObject private var speech = TextToSpeechService.shared
    @Environment(\.dismiss) private var dismiss
    @State private var showTranscript = false
    @State private var pulse = false

    private var spanish: Bool { Locale.current.languageCode == "es" }

    private var status: String {
        if viewModel.isAISpeaking { return spanish ? "Lyo está hablando" : "Lyo is speaking" }
        if viewModel.isAIThinking { return spanish ? "Lyo está pensando" : "Lyo is thinking" }
        return spanish ? "Escuchando" : "Listening"
    }

    private var liveCaption: String {
        if viewModel.isAISpeaking {
            return speech.liveSpokenText.isEmpty
                ? (spanish ? "Hablando…" : "Speaking…")
                : speech.liveSpokenText
        }
        if viewModel.isAIThinking {
            return viewModel.voiceWaitCue.isEmpty
                ? (spanish ? "Pensando en tu pregunta…" : "Thinking about your question…")
                : viewModel.voiceWaitCue
        }
        return viewModel.lastLiveTranscript.isEmpty
            ? (spanish ? "Adelante, te escucho." : "Go ahead. I'm listening.")
            : viewModel.lastLiveTranscript
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.04, green: 0.035, blue: 0.11),
                         Color(red: 0.14, green: 0.07, blue: 0.23),
                         Color(red: 0.05, green: 0.035, blue: 0.1)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label(spanish ? "En vivo con Lyo" : "Live with Lyo",
                              systemImage: "circle.fill")
                            .font(.headline)
                            .foregroundStyle(.mint)
                        Text(spanish ? "Tu compañero de aprendizaje" : "Your personal learning companion")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    Spacer()
                    Button {
                        viewModel.stopLiveMode()
                        dismiss()
                    } label: {
                        Label(spanish ? "Salir" : "End", systemImage: "xmark")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.12), in: Capsule())
                    }
                    .accessibilityLabel(spanish ? "Terminar conversación de voz" : "End live voice")
                }
                .padding(.horizontal, 24)
                .padding(.top, 18)

                Spacer(minLength: 16)

                ZStack {
                    Circle()
                        .fill((viewModel.isAISpeaking ? Color.orange : Color.purple).opacity(0.22))
                        .frame(width: 270, height: 270)
                        .blur(radius: 35)
                        .scaleEffect(pulse ? 1.13 : 0.95)
                    Circle()
                        .stroke(
                            viewModel.isAISpeaking ? Color.orange.opacity(0.65)
                                : Color.mint.opacity(0.35),
                            lineWidth: 2
                        )
                        .frame(width: 245, height: 245)
                        .scaleEffect(pulse ? 1.08 : 0.96)

                    if viewModel.isAIThinking {
                        AnimatedReadingMascotView(size: 205)
                            .transition(.opacity.combined(with: .scale))
                    } else {
                        EnhancedAnimatedLyoAvatar(
                            state: viewModel.isAISpeaking ? .speaking : .listening,
                            size: 205
                        )
                        .transition(.opacity.combined(with: .scale))
                    }
                }
                .frame(height: 270)
                .accessibilityLabel(status)

                VStack(spacing: 14) {
                    Text(status)
                        .font(.headline)
                        .foregroundStyle(.purple.opacity(0.8))
                    ScrollView {
                        Text(liveCaption)
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .id(liveCaption)
                    }
                    .frame(maxHeight: 120)
                    .accessibilityLabel(liveCaption)

                    Text(viewModel.isAISpeaking
                         ? (spanish ? "Habla para interrumpir a Lyo" : "Just start talking to interrupt Lyo")
                         : (spanish ? "Lyo responderá cuando termines de hablar"
                                    : "Lyo will answer when you finish speaking"))
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 30)

                Spacer(minLength: 12)

                if showTranscript {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(viewModel.messages.filter { !$0.content.isEmpty }) { message in
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(message.isFromUser
                                             ? (spanish ? "Tú" : "You") : "Lyo")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.white.opacity(0.5))
                                        Text(message.isFromUser ? message.content :
                                             (viewModel.isAISpeaking &&
                                              message.id == viewModel.messages.last?.id
                                                ? speech.liveSpokenText : message.content))
                                            .font(.subheadline)
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .padding(12)
                                    .background(message.isFromUser ? Color.purple.opacity(0.24)
                                                : Color.white.opacity(0.09),
                                                in: RoundedRectangle(cornerRadius: 14))
                                    .id(message.id)
                                }
                                if !viewModel.isAIThinking && !viewModel.isAISpeaking &&
                                    !viewModel.lastLiveTranscript.isEmpty {
                                    Text(viewModel.lastLiveTranscript)
                                        .foregroundStyle(.mint)
                                        .font(.subheadline)
                                }
                            }
                            .padding(14)
                        }
                        .frame(maxHeight: 250)
                        .background(.white.opacity(0.07),
                                    in: RoundedRectangle(cornerRadius: 20))
                        .onChange(of: viewModel.messages.count) { _, _ in
                            if let id = viewModel.messages.last?.id {
                                withAnimation { proxy.scrollTo(id, anchor: .bottom) }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showTranscript.toggle() }
                } label: {
                    Label(showTranscript
                          ? (spanish ? "Ocultar transcripción" : "Hide transcript")
                          : (spanish ? "Ver transcripción" : "View transcript"),
                          systemImage: "text.bubble")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 12)
                        .background(.white.opacity(0.12), in: Capsule())
                }
                .padding(.bottom, 22)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
        .onDisappear {
            if viewModel.isLiveMode { viewModel.stopLiveMode() }
        }
    }
}

#Preview {
    VoiceSessionBottomSheet(viewModel: LyoAIViewModel())
}
