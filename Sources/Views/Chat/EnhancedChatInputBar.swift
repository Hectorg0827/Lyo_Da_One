//
//  EnhancedChatInputBar.swift
//  Lyo
//
//  Perplexity/Gemini-style enhanced input bar with modes and voice features
//

import SwiftUI
import PhotosUI

enum AIChatMode: String, CaseIterable, Identifiable {
    case chat = "Chat"
    case course = "Course"
    case study = "Study"
    case test = "Test"
    case tutor = "Tutor"
    case quiz = "Quiz"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .chat: return "message.fill"
        case .course: return "book.fill"
        case .study: return "book.closed.fill"
        case .test: return "checkmark.circle.fill"
        case .tutor: return "person.fill.questionmark"
        case .quiz: return "questionmark.diamond.fill"
        }
    }
    
    var placeholder: String {
        switch self {
        case .chat: return "What would you like to learn?"
        case .course: return "What course would you like me to create?"
        case .study: return "What topic would you like to study?"
        case .test: return "What would you like to be tested on?"
        case .tutor: return "What do you need help understanding?"
        case .quiz: return "What topic should I quiz you on?"
        }
    }
}

enum VoiceInputMode {
    case speechToText  // Transcribes to text field
    case liveConversation  // Live voice chat with AI
}

struct EnhancedChatInputBar: View {
    @Binding var text: String
    @Binding var isLoading: Bool
    @Binding var selectedMode: AIChatMode
    let onSend: ([String]?) async -> Void
    
    // Services
    @StateObject private var voiceService = VoiceInputService.shared
    @StateObject private var mediaService = MediaPickerService.shared
    
    // State
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var voiceMode: VoiceInputMode = .speechToText
    @State private var showModeSelector = false
    @State private var isVoiceModeActive = false
    
    // Focus
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Attachment Preview Bar
            if !mediaService.selectedMedia.isEmpty {
                attachmentPreviewBar
            }
            
            // Voice Mode Active Indicator
            if isVoiceModeActive {
                voiceModeIndicator
            }
            
            // Main Input Container
            VStack(spacing: 12) {
                // Input Row
                HStack(alignment: .bottom, spacing: 12) {
                    // Attachment Button (+)
                    attachmentButton
                    
                    // Text Input Area
                    textInputArea
                    
                    // Voice Buttons
                    voiceButtonsStack
                }
                
                // Mode Selector Bar
                modeSelectorBar
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(inputBackground)
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoPickerItems,
            maxSelectionCount: 5,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: photoPickerItems) { _, newItems in
            Task {
                await mediaService.processPhotoPickerItems(newItems)
                photoPickerItems = []
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { url in
                if let url = url {
                    Task {
                        try? await mediaService.processDocumentURL(url)
                    }
                }
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView(isPresented: $showCamera) { image in
                Task {
                    try? await mediaService.processCameraImage(image)
                }
            }
        }
    }
    
    // MARK: - Attachment Preview Bar
    
    private var attachmentPreviewBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(mediaService.selectedMedia) { media in
                    MediaPreviewChip(media: media) {
                        mediaService.removeMedia(media)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(.systemGray6))
    }
    
    // MARK: - Voice Mode Indicator
    
    private var voiceModeIndicator: some View {
        HStack(spacing: 12) {
            // Animated waveform
            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(Color.accentColor)
                        .frame(width: 3, height: randomWaveHeight(index: index))
                        .animation(
                            .easeInOut(duration: 0.3)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                            value: isVoiceModeActive
                        )
                }
            }
            .frame(height: 20)
            
            Text("Voice Mode Active")
                .font(.subheadline.bold())
                .foregroundColor(.accentColor)
            
            Spacer()
            
            // Real-time transcription preview
            if !voiceService.transcript.isEmpty {
                Text(voiceService.transcript)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: 120)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.accentColor.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(Color.accentColor)
                .frame(height: 2),
            alignment: .bottom
        )
    }
    
    private func randomWaveHeight(index: Int) -> CGFloat {
        let heights: [CGFloat] = [12, 20, 16, 18, 14]
        return isVoiceModeActive ? heights[index % heights.count] : 8
    }
    
    // MARK: - Attachment Button
    
    private var attachmentButton: some View {
        Menu {
            Button {
                showPhotoPicker = true
            } label: {
                Label("Photo Library", systemImage: "photo.on.rectangle")
            }
            
            Button {
                showCamera = true
            } label: {
                Label("Camera", systemImage: "camera")
            }
            
            Button {
                showDocumentPicker = true
            } label: {
                Label("Files", systemImage: "folder")
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 36, height: 36)
                
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .onTapGesture {
            HapticManager.shared.playLightImpact()
        }
    }
    
    // MARK: - Text Input Area
    
    private var textInputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Placeholder label (shows when empty)
            if text.isEmpty && !isTextFieldFocused {
                Text(selectedMode.placeholder)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
                    .transition(.opacity)
            }
            
            // Text field
            TextField("", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .focused($isTextFieldFocused)
                .textFieldStyle(.plain)
                .font(.body)
                .disabled(isVoiceModeActive)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    // MARK: - Voice Buttons Stack
    
    private var voiceButtonsStack: some View {
        HStack(spacing: 8) {
            // Speech-to-Text Button
            Button {
                toggleSpeechToText()
            } label: {
                ZStack {
                    Circle()
                        .fill(voiceService.isRecording && !isVoiceModeActive ? Color.red.opacity(0.2) : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: voiceService.isRecording && !isVoiceModeActive ? "mic.fill" : "mic")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(voiceService.isRecording && !isVoiceModeActive ? .red : .primary)
                }
            }
            
            // Voice Mode Toggle
            Button {
                toggleVoiceMode()
            } label: {
                ZStack {
                    Circle()
                        .fill(isVoiceModeActive ? Color.accentColor.opacity(0.2) : Color(.systemGray5))
                        .frame(width: 36, height: 36)
                    
                    Image(systemName: isVoiceModeActive ? "waveform" : "waveform.circle")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(isVoiceModeActive ? .accentColor : .primary)
                }
            }
            
            // Send Button (when can send)
            if canSend {
                Button {
                    Task { await sendMessage() }
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.accentColor)
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .disabled(isLoading || isUploading)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }
    
    // MARK: - Mode Selector Bar
    
    private var modeSelectorBar: some View {
        HStack(spacing: 12) {
            // Mode picker
            Menu {
                ForEach(AIChatMode.allCases) { mode in
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            selectedMode = mode
                        }
                        HapticManager.shared.playLightImpact()
                    } label: {
                        Label(mode.rawValue, systemImage: mode.icon)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: selectedMode.icon)
                        .font(.caption)
                    Text(selectedMode.rawValue)
                        .font(.caption.weight(.medium))
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
                .foregroundColor(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(.systemGray6))
                .clipShape(Capsule())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Input Background
    
    private var inputBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Color(.systemBackground).opacity(0.95))
            )
            .overlay(
                Rectangle()
                    .fill(Color(.systemGray5).opacity(0.3))
                    .frame(height: 0.5),
                alignment: .top
            )
    }
    
    // MARK: - Computed Properties
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !mediaService.selectedMedia.isEmpty
    }
    
    // MARK: - Actions
    
    private func toggleSpeechToText() {
        if voiceService.isRecording {
            stopSpeechToText()
        } else {
            startSpeechToText()
        }
    }
    
    private func startSpeechToText() {
        Task {
            do {
                try await voiceService.startRecording()
                HapticManager.shared.playRecordingStarted()
            } catch {
                print("❌ Failed to start recording: \(error)")
            }
        }
    }
    
    private func stopSpeechToText() {
        voiceService.stopRecording()
        HapticManager.shared.playRecordingStopped()
        
        // Transfer transcribed text to input field
        if !voiceService.transcript.isEmpty {
            text += (text.isEmpty ? "" : " ") + voiceService.transcript
            voiceService.transcript = ""
        }
    }
    
    private func toggleVoiceMode() {
        withAnimation(.spring(response: 0.3)) {
            isVoiceModeActive.toggle()
        }
        
        if isVoiceModeActive {
            HapticManager.shared.playSuccess()
            isTextFieldFocused = false
            // Start live voice conversation
            startVoiceMode()
        } else {
            HapticManager.shared.playLightImpact()
            // Stop live voice conversation
            stopVoiceMode()
        }
    }
    
    private func startVoiceMode() {
        Task {
            do {
                try await voiceService.startRecording()
                // In voice mode, continuously listen and auto-send on pause
            } catch {
                print("❌ Failed to start voice mode: \(error)")
                isVoiceModeActive = false
            }
        }
    }
    
    private func stopVoiceMode() {
        voiceService.stopRecording()
        voiceService.transcript = ""
    }
    
    private func sendMessage() async {
        let messageText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty || !mediaService.selectedMedia.isEmpty else { return }
        
        HapticManager.shared.playMessageSent()
        
        // Upload attachments if any
        var attachmentIds: [String]? = nil
        if !mediaService.selectedMedia.isEmpty {
            isUploading = true
            do {
                attachmentIds = try await mediaService.uploadSelectedMedia()
                mediaService.clearSelection()
            } catch {
                print("❌ Failed to upload attachments: \(error)")
            }
            isUploading = false
        }
        
        // Clear input
        text = ""
        isTextFieldFocused = false
        
        // Send
        await onSend(attachmentIds)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        EnhancedChatInputBar(
            text: .constant(""),
            isLoading: .constant(false),
            selectedMode: .constant(.chat)
        ) { _ in }
    }
}
