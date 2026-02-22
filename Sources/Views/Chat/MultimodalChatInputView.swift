//
//  MultimodalChatInputView.swift
//  Lyo
//
//  Enhanced chat input view with multimodal capabilities
//

import SwiftUI
import PhotosUI
import os

struct MultimodalChatInputView: View {
    @Binding var text: String
    @Binding var isLoading: Bool
    let onSend: ([String]?) async -> Void  // Optional attachment IDs
    
    // Services
    @StateObject private var voiceService = VoiceInputService.shared
    @StateObject private var mediaService = MediaPickerService.shared
    
    // State
    @State private var isExpanded = false
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var showCamera = false
    @State private var photoPickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    
    // Focus
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Attachment Preview
            if !mediaService.selectedMedia.isEmpty {
                attachmentPreviewBar
            }
            
            // Voice Recording Indicator
            if voiceService.isRecording {
                voiceRecordingIndicator
            }
            
            // Main Input Area
            VStack(spacing: 12) {
                // Row 1: Text Input + Send/Mic
                HStack(alignment: .bottom, spacing: 12) {
                    // Text Input or Voice Waveform
                    if voiceService.isRecording {
                        voiceWaveform
                    } else {
                        textInputField
                    }
                    
                    // Voice / Send Button
                    voiceOrSendButton
                }
                
                // Row 2: Attachments
                HStack {
                    attachmentButton
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 24) // Extra bottom padding
            .background(Color(.systemBackground)) // Solid background
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .shadow(color: Color.black.opacity(0.08), radius: 15, x: 0, y: -5)
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
        .background(Color(.systemBackground))
    }
    
    // MARK: - Voice Recording Indicator
    
    private var voiceRecordingIndicator: some View {
        HStack(spacing: 12) {
            // Recording pulse
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.red.opacity(0.5), lineWidth: 2)
                        .scaleEffect(voiceService.isRecording ? 1.5 : 1.0)
                        .opacity(voiceService.isRecording ? 0 : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: false), value: voiceService.isRecording)
                )
            
            Text("Recording...")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Transcription preview
            if !voiceService.transcript.isEmpty {
                Text(voiceService.transcript)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.05))
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
                Label("Take Photo", systemImage: "camera")
            }
            
            Button {
                showDocumentPicker = true
            } label: {
                Label("Document", systemImage: "doc")
            }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.primary)
                .frame(width: 40, height: 40)
                .background(Color(.secondarySystemBackground))
                .clipShape(Circle())
        }
        .onTapGesture {
            HapticManager.shared.playLightImpact()
        }
    }
    
    // MARK: - Text Input Field
    
    private var textInputField: some View {
        TextField("Message Lyo...", text: $text, axis: .vertical)
            .lineLimit(1...6)
            .focused($isTextFieldFocused)
            .textFieldStyle(.plain)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(26)
    }
    
    // MARK: - Voice Waveform
    
    private var voiceWaveform: some View {
        HStack(spacing: 4) {
            ForEach(0..<12, id: \.self) { index in
                let waveAnimation = Animation.easeInOut(duration: 0.15)
                    .repeatForever(autoreverses: true)
                    .delay(Double(index) * 0.05)
                
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor)
                    .frame(width: 3, height: waveformHeight(for: index))
                    .animation(waveAnimation, value: voiceService.audioLevel)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 52)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(26)
    }
    
    private func waveformHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 8
        let maxAdditional: CGFloat = 20
        let audioLevel = CGFloat(voiceService.audioLevel)
        let variation = sin(Double(index) * 0.5 + Double(audioLevel) * 10)
        return baseHeight + maxAdditional * audioLevel * CGFloat(0.5 + variation * 0.5)
    }
    
    // MARK: - Voice or Send Button
    
    @ViewBuilder
    private var voiceOrSendButton: some View {
        if voiceService.isRecording {
            // Stop Recording Button
            Button {
                stopRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.red.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "stop.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
            }
        } else if canSend {
            // Send Button
            Button {
                Task { await sendMessage() }
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 48, height: 48)
                        .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    if isLoading || isUploading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
            }
            .disabled(isLoading || isUploading)
        } else {
            // Voice Button
            Button {
                startRecording()
            } label: {
                ZStack {
                    Circle()
                        .fill(
                             LinearGradient(
                                 colors: [Color(hex: "8B5CF6"), Color(hex: "3B82F6")],
                                 startPoint: .topLeading,
                                 endPoint: .bottomTrailing
                             )
                        )
                        .frame(width: 48, height: 48)
                        .shadow(color: Color(hex: "8B5CF6").opacity(0.4), radius: 8, x: 0, y: 4)
                    
                    Image(systemName: "mic.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    // MARK: - Input Background
    
    private var inputBackground: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Color(.systemBackground).opacity(0.8))
            )
    }
    
    // MARK: - Computed Properties
    
    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !mediaService.selectedMedia.isEmpty
    }
    
    // MARK: - Actions
    
    private func startRecording() {
        Task {
            do {
                try await voiceService.startRecording()
                HapticManager.shared.playRecordingStarted()
            } catch {
                Log.ai.error("Failed to start recording: \(error)")
            }
        }
    }
    
    private func stopRecording() {
        voiceService.stopRecording()
        HapticManager.shared.playRecordingStopped()
        
        // Transfer transcribed text to input field
        if !voiceService.transcript.isEmpty {
            text = voiceService.transcript
            voiceService.transcript = ""
        }
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
                Log.ai.error("Failed to upload attachments: \(error)")
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

// MARK: - End of MultimodalChatInputView
// Note: AttachmentPreviewChip is defined in MultimodalHelperViews.swift

// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        MultimodalChatInputView(
            text: .constant(""),
            isLoading: .constant(false)
        ) { _ in }
    }
}
