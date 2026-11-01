import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

/// iOS version of the approved Android Lyo Live screen.
/// Voice is a mode of the existing UnifiedChatService conversation, never a
/// separate chat, transcript database or background recording session.
struct VoiceSessionBottomSheet: View {
    @ObservedObject var viewModel: LyoAIViewModel
    var onExit: () -> Void = {}

    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var mediaPicker = MediaPickerService.shared
    @FocusState private var inputFocused: Bool
    @State private var draft = ""
    @State private var pausedByUser = false
    @State private var showingTranscript = false
    @State private var showingFiles = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isSending = false
    @State private var uploadError: String?
    @State private var avatarTouched = false

    private var speaking: Bool { viewModel.isAISpeaking }
    private var thinking: Bool { viewModel.isAIThinking || viewModel.isLoading }
    private var listening: Bool { viewModel.isVoiceActive && !thinking && !speaking }

    private var palette: [Color] {
        speaking
            ? [Color(red: 1, green: 0.72, blue: 0.37),
               Color(red: 1, green: 0.43, blue: 0.43),
               Color(red: 0.96, green: 0.38, blue: 0.63)]
            : [Color(red: 0.43, green: 0.95, blue: 0.76),
               Color(red: 0.32, green: 0.67, blue: 0.97),
               Color(red: 0.72, green: 0.53, blue: 0.94)]
    }

    private var status: String {
        if speaking { return "Lyo is responding" }
        if thinking { return "Lyo is thinking" }
        if pausedByUser || inputFocused { return "Microphone paused" }
        if listening { return "I'm listening…" }
        return "Ready to listen"
    }

    private var headline: String {
        if speaking { return "Here's what I think…" }
        if thinking { return "One thought at a time." }
        return "Go on, I'm all ears."
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 8) {
                        hero(height: min(geometry.size.height * 0.39, 325))
                        statusPill
                        Text(headline)
                            .font(.system(size: geometry.size.width < 350 ? 30 : 35, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .minimumScaleFactor(0.76)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)

                        LyoLiveWave(
                            palette: palette,
                            level: speaking ? viewModel.aiLiveAudioLevel : viewModel.userLiveAudioLevel,
                            active: speaking || listening,
                            thinking: thinking,
                            reduceMotion: reduceMotion
                        )
                        .frame(height: 54)
                        .padding(.horizontal, 24)

                        Text(liveCaption)
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .frame(maxWidth: .infinity, minHeight: 32)
                            .padding(.horizontal, 22)

                        Button {
                            withAnimation(.easeInOut(duration: 0.18)) {
                                showingTranscript.toggle()
                            }
                        } label: {
                            Label(showingTranscript ? "Hide transcript" : "See transcript", systemImage: "text.alignleft")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.white.opacity(0.78))
                                .padding(.vertical, 12)
                        }
                        .accessibilityLabel(showingTranscript ? "Hide transcript" : "See transcript")

                        if showingTranscript {
                            transcript
                                .padding(.horizontal, 16)
                                .transition(.opacity)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .defaultScrollAnchor(.center)
                inputIsland
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }
            .background(Color(red: 0.015, green: 0.023, blue: 0.032).ignoresSafeArea())
        }
        .onChange(of: inputFocused) { _, focused in
            if focused {
                viewModel.pauseLiveMicrophone(userInitiated: false)
            } else if !pausedByUser && !isSending {
                viewModel.resumeLiveMicrophone()
            }
        }
        .onChange(of: photoItems) { _, newItems in
            Task { @MainActor in
                await mediaPicker.processPhotoPickerItems(newItems)
                photoItems = []
                if let error = mediaPicker.error {
                    uploadError = error.localizedDescription
                }
            }
        }
        .fileImporter(
            isPresented: $showingFiles,
            allowedContentTypes: [.image, .pdf, .plainText, .commaSeparatedText, .json],
            allowsMultipleSelection: true
        ) { result in
            Task { @MainActor in
                do {
                    let urls = try result.get()
                    for url in urls.prefix(4) {
                        _ = try await mediaPicker.processDocumentURL(url)
                    }
                } catch {
                    uploadError = error.localizedDescription
                }
            }
        }
        .onDisappear {
            // The parent owns the chat transition. Never synthesize another
            // message from the unfinished partial speech on dismissal.
            if viewModel.isLiveMode { viewModel.stopLiveMode() }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 13) {
            Circle()
                .fill(Color(red: 0.38, green: 0.96, blue: 0.75))
                .frame(width: 10, height: 10)
                .shadow(color: .mint.opacity(0.5), radius: 5)

            VStack(alignment: .leading, spacing: 5) {
                Text("Live with Lyo")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("YOUR PERSONAL LEARNING COMPANION")
                    .font(.system(size: 10, weight: .medium))
                    .tracking(1.05)
                    .foregroundStyle(Color.white.opacity(0.54))
            }
            Spacer()
            Button(action: endLive) {
                Image(systemName: "xmark")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 45, height: 45)
                    .background(Color.white.opacity(0.10), in: Circle())
            }
            .accessibilityLabel("End Live and return to chat")
        }
        .padding(.horizontal, 23)
        .padding(.top, 16)
        .padding(.bottom, 6)
    }

    private func hero(height: CGFloat) -> some View {
        ZStack {
            LyoLiveWave(
                palette: palette, level: speaking ? viewModel.aiLiveAudioLevel : viewModel.userLiveAudioLevel,
                active: speaking || listening, thinking: thinking, reduceMotion: reduceMotion
            )
            .frame(height: 100)
            .opacity(0.45)

            Circle()
                .stroke(AngularGradient(colors: palette + [palette[0]], center: .center), lineWidth: 2)
                .frame(width: min(height * 0.88, 278), height: min(height * 0.88, 278))
                .shadow(color: palette[0].opacity(speaking ? 0.45 : 0.16), radius: speaking ? 19 : 7)

            // The front-facing canonical Lyo asset, not the reading-book hero.
            Image("LyoAvatar")
                .resizable()
                .scaledToFit()
                .frame(width: min(height * 0.80, 253), height: min(height * 0.83, 265))
                .scaleEffect(avatarTouched ? 1.07 : 1.0)
                .onTapGesture {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    withAnimation(.spring(response: 0.27, dampingFraction: 0.52)) {
                        avatarTouched = true
                    }
                    Task {
                        try? await Task.sleep(nanoseconds: 350_000_000)
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.76)) {
                            avatarTouched = false
                        }
                    }
                }
                .accessibilityLabel("Touch Lyo for a reaction")
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
    }

    private var statusPill: some View {
        HStack(spacing: 9) {
            Image(systemName: speaking ? "waveform" : "waveform")
                .foregroundStyle(palette[0])
            Text(status)
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .medium))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.08), in: Capsule())
        .overlay(Capsule().stroke(palette[0].opacity(0.45), lineWidth: 1))
    }

    private var liveCaption: String {
        if listening && !viewModel.lastLiveTranscript.isEmpty {
            return viewModel.lastLiveTranscript
        }
        if speaking, let last = viewModel.messages.last(where: { !$0.isFromUser }) {
            return last.content
        }
        if thinking { return "Thinking about your question…" }
        return pausedByUser ? "Tap the microphone to continue." : "Take your time. I'm here."
    }

    private var transcript: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Conversation transcript")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.78))
            ForEach(viewModel.messages, id: \.id) { message in
                if !message.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(message.isFromUser ? "You" : "Lyo")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(message.isFromUser ? palette[0] : Color.white.opacity(0.78))
                        Text(message.content)
                            .font(.system(size: 14))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if listening && !viewModel.lastLiveTranscript.isEmpty {
                Text("You · live: " + viewModel.lastLiveTranscript)
                    .font(.system(size: 13))
                    .foregroundStyle(palette[0])
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
    }

    private var inputIsland: some View {
        HStack(spacing: 8) {
            Button {
                if speaking || thinking {
                    viewModel.interruptLiveAnswer()
                    if !pausedByUser && !inputFocused { viewModel.resumeLiveMicrophone() }
                } else if pausedByUser || !viewModel.isVoiceActive {
                    pausedByUser = false
                    inputFocused = false
                    viewModel.resumeLiveMicrophone()
                } else {
                    pausedByUser = true
                    viewModel.pauseLiveMicrophone(userInitiated: true)
                }
            } label: {
                Image(systemName: pausedByUser ? "mic.slash.fill" : "mic.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(speaking ? palette[0] : Color.mint)
                    .frame(width: 42, height: 42)
                    .overlay(Circle().stroke(palette[0].opacity(0.65), lineWidth: 1.5))
            }
            .accessibilityLabel(speaking || thinking ? "Interrupt Lyo to speak" :
                                pausedByUser ? "Resume microphone" : "Pause microphone")

            HStack(spacing: 5) {
                Menu {
                    PhotosPicker(selection: $photoItems, maxSelectionCount: 4, matching: .images) {
                        Label("Photo Library", systemImage: "photo")
                    }
                    Button {
                        showingFiles = true
                    } label: {
                        Label("Documents", systemImage: "doc")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                        .frame(width: 35, height: 42)
                }
                .disabled(isSending || mediaPicker.selectedMedia.count >= 4)
                .accessibilityLabel("Attach a photo or document")

                TextField(mediaPicker.selectedMedia.isEmpty ? "Ask Lyo…" :
                            "\(mediaPicker.selectedMedia.count) attachment(s) ready…",
                          text: $draft)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .focused($inputFocused)
                    .foregroundStyle(.white)
                    .font(.system(size: 15))
                    .onSubmit(send)

                Button(action: send) {
                    if isSending || mediaPicker.isLoading {
                        ProgressView().tint(.mint)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(canSend ? Color.mint : Color.gray)
                    }
                }
                .disabled(!canSend)
                .frame(width: 36, height: 42)
                .accessibilityLabel("Send to Lyo")
            }
            .padding(.horizontal, 8)
            .frame(height: 48)
            .background(Color(red: 0.07, green: 0.09, blue: 0.13), in: Capsule())
            .overlay(Capsule().stroke(Color.white.opacity(0.20), lineWidth: 1))
        }
        .padding(8)
        .background(Color(red: 0.09, green: 0.12, blue: 0.16), in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 1))
        .overlay(alignment: .topLeading) {
            if let uploadError {
                Text(uploadError)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -34)
            }
        }
    }

    private var canSend: Bool {
        !isSending && !mediaPicker.isLoading &&
        (!draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
         !mediaPicker.selectedMedia.isEmpty)
    }

    private func send() {
        guard canSend else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        let pending = mediaPicker.selectedMedia
        isSending = true
        inputFocused = false
        draft = ""
        uploadError = nil

        Task { @MainActor in
            do {
                if viewModel.isAISpeaking || viewModel.isLoading {
                    viewModel.interruptLiveAnswer()
                }
                for media in pending {
                    let attachment = try await mediaPicker.uploadMedia(media)
                    viewModel.addAttachment(attachment)
                }
                mediaPicker.clearSelection()
                viewModel.inputText = text
                await viewModel.sendMessage(mode: "Chat")
            } catch {
                // Never silently lose a typed message after an upload failure.
                draft = text
                uploadError = error.localizedDescription
            }
            isSending = false
        }
    }

    private func endLive() {
        viewModel.stopLiveMode()
        onExit()
        dismiss()
    }
}

private struct LyoLiveWave: View {
    let palette: [Color]
    let level: Float
    let active: Bool
    let thinking: Bool
    let reduceMotion: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let energy = thinking ? 0.05 : active ? max(0.08, min(CGFloat(level), 1)) : 0.025
                for layer in 0..<3 {
                    var path = Path()
                    for step in 0...90 {
                        let progress = CGFloat(step) / 90
                        let envelope = max(0, sin(progress * .pi))
                        let movement = sin(progress * 14 * .pi + CGFloat(time) * (2.6 + CGFloat(layer) * 0.22))
                        let y = size.height / 2 + movement * size.height * 0.42 * energy * envelope * (1 - CGFloat(layer) * 0.18)
                        let point = CGPoint(x: progress * size.width, y: y)
                        if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                    }
                    context.stroke(
                        path,
                        with: .linearGradient(Gradient(colors: palette), startPoint: .zero,
                                              endPoint: CGPoint(x: size.width, y: 0)),
                        style: StrokeStyle(lineWidth: layer == 0 ? 3 : CGFloat(10 - layer * 3), lineCap: .round)
                    )
                }
            }
        }
        .accessibilityHidden(true)
    }
}

#Preview {
    VoiceSessionBottomSheet(viewModel: LyoAIViewModel())
}