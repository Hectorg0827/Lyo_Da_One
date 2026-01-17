//
//  EnhancedMessageBubble.swift
//  Lyo
//
//  Gemini-style full-width message bubble with top-positioned avatar
//

import SwiftUI
import AVKit

struct EnhancedMessageBubble: View {
    let message: MultimodalMessage
    let onTTSToggle: (() -> Void)?
    let onQuizAnswer: ((Int) -> Void)?
    let onCourseOpen: ((String) -> Void)?
    let onTopicSelect: ((TopicOption) -> Void)?
    let onModuleSelect: ((CourseModule) -> Void)?
    let onSuggestionSelect: ((String) -> Void)?
    
    @StateObject private var audioService = AudioPlaybackService.shared
    @State private var showFullImage = false
    @State private var selectedImageURL: URL?
    
    init(
        message: MultimodalMessage,
        onTTSToggle: (() -> Void)? = nil,
        onQuizAnswer: ((Int) -> Void)? = nil,
        onCourseOpen: ((String) -> Void)? = nil,
        onTopicSelect: ((TopicOption) -> Void)? = nil,
        onModuleSelect: ((CourseModule) -> Void)? = nil,
        onSuggestionSelect: ((String) -> Void)? = nil
    ) {
        self.message = message
        self.onTTSToggle = onTTSToggle
        self.onQuizAnswer = onQuizAnswer
        self.onCourseOpen = onCourseOpen
        self.onTopicSelect = onTopicSelect
        self.onModuleSelect = onModuleSelect
        self.onSuggestionSelect = onSuggestionSelect
    }
    
    var body: some View {
        if message.role == .assistant {
            // AI Message - Full Width with Avatar on Top
            aiMessageView
        } else {
            // User Message - Keep as bubble on right
            userMessageView
        }
    }
    
    // MARK: - AI Message View (Full Width, Gemini Style)
    
    // MARK: - AI Message View (Full-Width Stream)
    
    private var aiMessageView: some View {
        HStack(alignment: .top, spacing: 16) {
            // Avatar (Small, floating left of content)
            avatarView
                .frame(width: 32, height: 32)
                .padding(.top, 4) // Align with first line of text
            
            // Full-width content area
            VStack(alignment: .leading, spacing: 12) {
                // Iterate over content types
                ForEach(message.contentTypes.indices, id: \.self) { index in
                    let contentType = message.contentTypes[index]
                    
                    switch contentType {
                    case .text:
                        if !message.content.isEmpty {
                            Text(LocalizedStringKey(message.content))
                                .font(.body)
                                .foregroundColor(.primary) // White in dark mode
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .fixedSize(horizontal: false, vertical: true) // Ensure wraps correctly
                        }
                        
                    case .processing(let step, let progress):
                        ProcessingBubbleView(step: step, progress: progress)
                        
                    case .topicSelection(let title, let topics):
                        TopicSelectionBubbleView(
                            title: title,
                            topics: topics,
                            onSelect: { topic in
                                onTopicSelect?(topic)
                            }
                        )
                        .padding(.horizontal, -8) // Slight bleed
                        
                    case .courseRoadmap(let title, let modules, let total, let completed):
                        CourseRoadmapBubbleView(
                            title: title,
                            modules: modules,
                            totalModules: total,
                            completedModules: completed,
                            onModuleSelect: { module in
                                onModuleSelect?(module)
                            }
                        )
                        
                    case .flashcards(let title, let cards):
                        FlashcardCarouselBubbleView(
                            title: title,
                            cards: cards
                        )
                        .padding(.horizontal, -8)
                        
                    case .quiz(let question, let options, let correctIndex, let explanation):
                        InteractiveQuizBubbleView(
                            question: question,
                            options: options,
                            correctIndex: correctIndex,
                            explanation: explanation,
                            onAnswerSelected: { index in
                                onQuizAnswer?(index)
                            }
                        )
                        
                    case .courseCard(let courseId, let title, let subtitle, _):
                         Button {
                             onCourseOpen?(courseId)
                         } label: {
                             VStack(alignment: .leading) {
                                 Text(title).font(.headline)
                                 if let subtitle { Text(subtitle).font(.caption) }
                             }
                             .padding()
                             .frame(maxWidth: .infinity, alignment: .leading)
                             .background(Color(.secondarySystemBackground))
                             .cornerRadius(12)
                         }
                    
                    case .suggestions(let title, let options):
                        InlineSuggestionsView(title: title, options: options) { selected in
                            onSuggestionSelect?(selected)
                        }
                         
                    default:
                        EmptyView()
                    }
                }
                
                // Attachments
                if !message.attachments.isEmpty {
                    attachmentsGrid(message.attachments)
                }
                
                // Message footer with TTS and timestamp
                HStack(spacing: 12) {
                    Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    // TTS button
                    ttsButton
                }
            }
        }
        .padding(.horizontal, 16) // "Internal padding of 16px"
        .padding(.vertical, 8)    // "Minimal vertical spacing"
        .frame(maxWidth: .infinity) // "Width: 99% to 100%"
        .background(
            Color(hex: "181818").opacity(0.3) // "Transparent or extremely subtle dark overlay"
        )
        .fullScreenCover(isPresented: $showFullImage) {
            FullImageView(url: selectedImageURL) {
                showFullImage = false
            }
        }
    }
    
    // MARK: - User Message View (Traditional Bubble)
    
    private var userMessageView: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Spacer(minLength: 60)
            
            VStack(alignment: .trailing, spacing: 8) {
                // Main content
                Text(LocalizedStringKey(message.content))
                    .font(.body)
                    .foregroundColor(.white)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .clipShape(ChatBubbleShape(isFromUser: true))
                
                // Attachments
                if !message.attachments.isEmpty {
                    attachmentsGrid(message.attachments)
                }
                
                // Metadata footer
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .time)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    
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
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }
    
    // MARK: - Avatar
    
    private var avatarView: some View {
        Image("LyoAvatar")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.accentColor.opacity(0.2), lineWidth: 2)
            )
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
}

// MARK: - Preview

#Preview {
    VStack(spacing: 16) {
        EnhancedMessageBubble(
            message: MultimodalMessage(
                id: UUID().uuidString,
                role: .assistant,
                content: "Here's a comprehensive explanation of SwiftUI. SwiftUI is Apple's modern framework for building user interfaces across all Apple platforms. It uses a declarative syntax that makes it easy to create complex UIs with less code.",
                attachments: [],
                timestamp: Date()
            )
        )
        
        EnhancedMessageBubble(
            message: MultimodalMessage(
                id: UUID().uuidString,
                role: .user,
                content: "Tell me about SwiftUI",
                attachments: [],
                timestamp: Date()
            )
        )
    }
    .padding()
}

