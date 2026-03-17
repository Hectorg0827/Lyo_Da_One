//
//  MultimodalMessageBubble.swift
//  Lyo
//
//  Rich message bubble supporting multimodal content
//

import SwiftUI
import AVKit

struct MultimodalMessageBubble: View {
    let message: MultimodalMessage
    let onTTSToggle: (() -> Void)?
    let onQuizAnswer: ((Int) -> Void)?
    let onCourseOpen: ((String) -> Void)?
    
    @StateObject private var audioService = AudioPlaybackService.shared
    @State private var showFullImage = false
    @State private var selectedImageURL: URL?
    
    init(
        message: MultimodalMessage,
        onTTSToggle: (() -> Void)? = nil,
        onQuizAnswer: ((Int) -> Void)? = nil,
        onCourseOpen: ((String) -> Void)? = nil
    ) {
        self.message = message
        self.onTTSToggle = onTTSToggle
        self.onQuizAnswer = onQuizAnswer
        self.onCourseOpen = onCourseOpen
    }
    
    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 0) {
            if message.role == .assistant {
                // AI Header: Mascot & Speaker ABOVE
                HStack(alignment: .center, spacing: 10) {
                    HStack(spacing: 8) {
                        if message.isStreaming {
                            AnimatedReadingMascotView(size: 28)
                        } else {
                            Image("Mascot_Standing")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 28, height: 28)
                                .clipShape(Circle())
                                .offset(y: 10)
                        }
                        
                        Text("Lyo")
                            .font(.caption.bold())
                            .foregroundColor(.primary.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // TTS button moved to header
                    ttsButton
                        .scaleEffect(0.85)
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                if message.role == .user {
                    Spacer(minLength: 40)
                }
                
                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
                    // Main content
                    bubbleContent
                    
                    // Attachments
                    if !message.attachments.isEmpty {
                        attachmentsGrid(message.attachments)
                    }
                    
                    // Metadata footer
                    messageFooter
                }
                .frame(maxWidth: message.role == .user ? UIScreen.main.bounds.width * 0.8 : UIScreen.main.bounds.width * 0.995, alignment: message.role == .user ? .trailing : .leading)
                
                if message.role == .assistant {
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .fullScreenCover(isPresented: $showFullImage) {
            FullImageView(url: selectedImageURL) {
                showFullImage = false
            }
        }
    }
    
    // MARK: - Avatar (No longer used on side)
    
    private var avatarView: some View {
        EmptyView()
    }
    
    // MARK: - Bubble Content
    
    @ViewBuilder
    private var bubbleContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Default text
            if !message.content.isEmpty {
                textBubble
            }
            
            // Rich Content
            if !message.contentTypes.isEmpty {
                VStack(spacing: 12) {
                    ForEach(Array(message.contentTypes.enumerated()), id: \.offset) { _, contentType in
                        renderContentType(contentType)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func renderContentType(_ contentType: MessageContentType) -> some View {
        switch contentType {
        case .quiz(let question, let options, let correctIndex, let explanation):
            PremiumQuizView(
                question: question,
                options: options,
                correctIndex: correctIndex,
                explanation: explanation,
                onAnswerSubmitted: { index, _ in
                    onQuizAnswer?(index)
                }
            )
            .padding(.horizontal, -8)
            
        case .flashcards(let title, let cards):
            FlashcardCarouselBubbleView(title: title, cards: cards)
            .padding(.horizontal, -8)
            
        case .notes(let title, let sections):
            NotesView(notes: NotesPayload(title: title, sections: sections))
            .padding(.horizontal, -8)
            
        default:
            EmptyView()
        }
    }
    
    // MARK: - Text Bubble
    
    private var textBubble: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(message.role == .user ? .white : .primary)
            .textSelection(.enabled)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bubbleBackground)
            .clipShape(ChatBubbleShape(isFromUser: message.role == .user))
    }
    
    // MARK: - TTS Button
    
    private var ttsButton: some View {
        Button {
            onTTSToggle?()
            HapticManager.shared.playLightImpact()
        } label: {
            Group {
                if audioService.currentMessageId == message.id && audioService.isPlaying {
                    Image(systemName: "stop.circle.fill")
                } else if audioService.currentMessageId == message.id && audioService.isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Image(systemName: "speaker.wave.2.circle.fill")
                }
            }
            .font(.system(size: 20))
            .foregroundColor(.accentColor.opacity(0.8))
        }
    }
    
    // MARK: - Image Bubble
    
    private func imageBubble(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                ProgressView()
                    .frame(width: 200, height: 150)
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 250, maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onTapGesture {
                        selectedImageURL = url
                        showFullImage = true
                    }
            case .failure:
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                    .frame(width: 200, height: 150)
            @unknown default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Audio Bubble
    
    private func audioBubble(url: URL) -> some View {
        HStack(spacing: 12) {
            Button {
                Task {
                    if audioService.currentMessageId == message.id && audioService.isPlaying {
                        audioService.pause()
                    } else if audioService.currentMessageId == message.id && audioService.isPaused {
                        audioService.resume()
                    } else {
                        await audioService.playAudioURL(url, messageId: message.id)
                    }
                }
            } label: {
                Image(systemName: audioService.currentMessageId == message.id && audioService.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor)
            }
            
            // Waveform / Progress
            VStack(alignment: .leading, spacing: 4) {
                AudioWaveformView(
                    progress: audioService.currentMessageId == message.id ? audioService.currentProgress : 0
                )
                .frame(height: 30)
                
                if audioService.currentMessageId == message.id && audioService.duration > 0 {
                    Text(formatDuration(audioService.duration * audioService.currentProgress))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    // MARK: - Video Bubble
    
    private func videoBubble(url: URL) -> some View {
        VideoPlayer(player: AVPlayer(url: url))
            .frame(width: 250, height: 180)
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Code Snippet Bubble
    
    private func codeSnippetBubble(_ code: CodeSnippetContent) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Text(code.language)
                    .font(.caption.bold())
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button {
                    UIPasteboard.general.string = code.code
                    HapticManager.shared.playSuccess()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
            }
            
            // Code
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.code)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.primary)
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .frame(maxWidth: 300)
    }
    
    // MARK: - Quiz Bubble
    
    private func quizBubble(_ quiz: QuizContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(quiz.question)
                .font(.subheadline.bold())
            
            ForEach(Array(quiz.options.enumerated()), id: \.offset) { index, option in
                Button {
                    onQuizAnswer?(index)
                    HapticManager.shared.playQuizSelection()
                } label: {
                    HStack {
                        Text("\(["A", "B", "C", "D"][index]).")
                            .font(.subheadline.bold())
                        Text(option)
                            .font(.subheadline)
                        Spacer()
                        
                        if let selected = quiz.selectedAnswer {
                            if selected == index {
                                Image(systemName: index == quiz.correctAnswer ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(index == quiz.correctAnswer ? .green : .red)
                            } else if index == quiz.correctAnswer {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }
                        }
                    }
                    .padding(10)
                    .background(quizOptionBackground(index: index, quiz: quiz))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .disabled(quiz.selectedAnswer != nil)
            }
            
            if quiz.selectedAnswer != nil, let explanation = quiz.explanation {
                Text(explanation)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 300)
    }
    
    private func quizOptionBackground(index: Int, quiz: QuizContent) -> Color {
        guard let selected = quiz.selectedAnswer else {
            return Color(.systemBackground)
        }
        
        if index == quiz.correctAnswer {
            return Color.green.opacity(0.2)
        } else if index == selected {
            return Color.red.opacity(0.2)
        }
        return Color(.systemBackground)
    }
    
    // MARK: - Course Card Bubble (Premium Gamified UI)
    
    private func courseCardBubble(_ course: CourseCardContent) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: AI Badge
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                    Text("AI GENERATED COURSE")
                        .font(.system(size: 9, weight: .black, design: .rounded))
                }
                .foregroundColor(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(Capsule())
                
                Spacer()
                
                if let duration = course.duration {
                    HStack(spacing: 4) {
                        Image(systemName: "clock.fill")
                        Text(duration)
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            }
            .padding(12)
            .padding(.bottom, -8) // Pull content up
            .zIndex(1)
            
            // Thumbnail
            if let thumbnail = course.thumbnail {
                AsyncImage(url: thumbnail) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    ZStack {
                        Color.accentColor.opacity(0.1)
                        Image(systemName: "play.tv.fill")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor.opacity(0.5))
                    }
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)
                .padding(.top, 12)
            }
            
            VStack(alignment: .leading, spacing: 6) {
                Text(course.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(2)
                
                if let description = course.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }
            .padding(14)
            
            // CTA Button
            Button {
                onCourseOpen?(course.courseId)
                HapticManager.shared.playSuccess()
            } label: {
                HStack {
                    Spacer()
                    Text("Start Course")
                        .font(.headline.weight(.bold))
                    Image(systemName: "play.circle.fill")
                        .font(.title3)
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: Color.accentColor.opacity(0.3), radius: 8, y: 4)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .background(
            ZStack {
                // Frosted Glass Base
                RoundedRectangle(cornerRadius: 20)
                    .fill(.ultraThickMaterial)
                
                // Subtle Glow Border
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [Color.accentColor.opacity(0.5), .clear, Color.accentColor.opacity(0.2)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            }
        )
        // Main Card Shadow
        .shadow(color: Color.black.opacity(0.1), radius: 15, y: 10)
        .frame(width: 280)
    }
    
    // MARK: - Poll Bubble
    
    private func pollBubble(_ poll: PollContent) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(poll.question)
                .font(.subheadline.bold())
            
            ForEach(Array(poll.options.enumerated()), id: \.offset) { index, option in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(option)
                            .font(.caption)
                        Spacer()
                        Text("\(poll.votes[index])%")
                            .font(.caption.bold())
                    }
                    
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(0.3))
                            .overlay(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.accentColor)
                                    .frame(width: geo.size.width * CGFloat(poll.votes[index]) / 100)
                            }
                    }
                    .frame(height: 8)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(maxWidth: 280)
    }
    
    // MARK: - Rich Card Bubble
    
    private func richCardBubble(_ card: RichCardContent) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let imageURL = card.imageURL {
                AsyncImage(url: imageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(.systemGray5))
                }
                .frame(height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            
            Text(card.title)
                .font(.headline)
            
            Text(card.body)
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let actions = card.actions, !actions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(actions) { action in
                        Button {
                            // Handle action based on actionType and payload
                            if action.actionType == "open_url", let payload = action.payload, let url = URL(string: payload) {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Text(action.label)
                                .font(.caption.bold())
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .frame(width: 280)
    }
    
    // MARK: - File Bubble
    
    private func fileBubble(url: URL) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(url.lastPathComponent)
                    .font(.subheadline)
                    .lineLimit(1)
                
                Text("Tap to open")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onTapGesture {
            UIApplication.shared.open(url)
        }
    }
    
    // MARK: - Attachments Grid
    
    private func attachmentsGrid(_ attachments: [ChatAttachment]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 8) {
            ForEach(attachments) { attachment in
                attachmentThumbnail(attachment)
            }
        }
    }
    
    @ViewBuilder
    private func attachmentThumbnail(_ attachment: ChatAttachment) -> some View {
        if attachment.type == .image, 
           let urlString = attachment.url,
           let url = URL(string: urlString) {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Color(.systemGray5)
            }
            .frame(width: 80, height: 80)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                selectedImageURL = url
                showFullImage = true
            }
        } else {
            VStack(spacing: 4) {
                Image(systemName: "doc.fill")
                    .font(.title2)
                Text(attachment.name)
                    .font(.caption2)
                    .lineLimit(1)
            }
            .frame(width: 80, height: 80)
            .background(Color(.systemGray5))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
    
    // MARK: - Message Footer
    
    private var messageFooter: some View {
        HStack(spacing: 4) {
            Text(message.timestamp, style: .time)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            if message.role == .user {
                if message.isStreaming {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Image(systemName: "checkmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
    
    // MARK: - Helpers
    
    private var bubbleBackground: Color {
        message.role == .user ? Color.accentColor : Color(.systemGray6)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Chat Bubble Shape

struct ChatBubbleShape: Shape {
    let isFromUser: Bool
    
    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = 6
        
        var path = Path()
        
        if isFromUser {
            // User bubble - tail on right
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            
            // Tail
            path.addLine(to: CGPoint(x: rect.maxX - radius + tailSize, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX + tailSize, y: rect.maxY + tailSize), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX - tailSize, y: rect.maxY + tailSize))
            
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        } else {
            // Assistant bubble - tail on left
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + radius), control: CGPoint(x: rect.maxX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(to: CGPoint(x: rect.maxX - radius, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            
            // Tail
            path.addQuadCurve(to: CGPoint(x: rect.minX - tailSize, y: rect.maxY + tailSize), control: CGPoint(x: rect.minX + tailSize, y: rect.maxY + tailSize))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius - tailSize, y: rect.maxY), control: CGPoint(x: rect.minX, y: rect.maxY))
            
            path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY - radius), control: CGPoint(x: rect.minX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(to: CGPoint(x: rect.minX + radius, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        }
        
        return path
    }
}

// MARK: - Audio Waveform View

struct AudioWaveformView: View {
    let progress: Double
    
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(0..<30, id: \.self) { index in
                    let barProgress = Double(index) / 30.0
                    RoundedRectangle(cornerRadius: 1)
                        .fill(barProgress <= progress ? Color.accentColor : Color(.systemGray4))
                        .frame(width: 3, height: randomHeight(for: index))
                }
            }
        }
    }
    
    private func randomHeight(for index: Int) -> CGFloat {
        // Generate pseudo-random heights based on index
        let heights: [CGFloat] = [8, 12, 20, 16, 24, 14, 18, 22, 10, 26, 14, 20, 16, 12, 24, 18, 22, 14, 20, 10, 26, 16, 18, 22, 12, 20, 14, 24, 16, 18]
        return heights[index % heights.count]
    }
}

// MARK: - Full Image View

struct FullImageView: View {
    let url: URL?
    let onDismiss: () -> Void
    
    @State private var scale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let url = url {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    scale = value
                                }
                                .onEnded { _ in
                                    withAnimation {
                                        scale = 1.0
                                    }
                                }
                        )
                } placeholder: {
                    ProgressView()
                }
            }
            
            VStack {
                HStack {
                    Spacer()
                    Button {
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white, Color(.systemGray3))
                    }
                    .padding()
                }
                Spacer()
            }
        }
    }
}
