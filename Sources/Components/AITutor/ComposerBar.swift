import SwiftUI

struct ComposerBar: View {
    @Binding var text: String
    @Binding var attachments: [MessageAttachment]
    let isLoading: Bool
    let onSend: () -> Void
    let onAddAttachment: () -> Void
    let onRemoveAttachment: (MessageAttachment) -> Void
    
    @FocusState private var isFocused: Bool
    @State private var showingAttachmentMenu = false
    
    private let maxLines = 4
    
    var body: some View {
        VStack(spacing: 0) {
            // Attachment chips
            if !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments) { attachment in
                            AttachmentChip(attachment: attachment) {
                                onRemoveAttachment(attachment)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color("LyoBackground"))
            }
            
            // Composer input
            HStack(alignment: .bottom, spacing: 12) {
                // Attachment button
                Button {
                    showingAttachmentMenu = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color("LyoAccent"))
                }
                .confirmationDialog("Add Attachment", isPresented: $showingAttachmentMenu) {
                    Button("📁 Files") { onAddAttachment() }
                    Button("🖼️ Images") { onAddAttachment() }
                    Button("🔗 Links") { onAddAttachment() }
                    Button("🎙️ Voice Note") { onAddAttachment() }
                    Button("📷 Camera") { onAddAttachment() }
                    Button("Cancel", role: .cancel) { }
                }
                
                // Text input
                ZStack(alignment: .leading) {
                    if text.isEmpty {
                        Text("Ask anything… or say 'build me a 2-week algebra course'")
                            .font(.system(size: 15))
                            .foregroundColor(Color("LyoTextSecondary"))
                            .padding(.leading, 16)
                            .padding(.top, 12)
                    }
                    
                    TextEditor(text: $text)
                        .font(.system(size: 15))
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 40, maxHeight: CGFloat(maxLines) * 24)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .focused($isFocused)
                }
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color("LyoSurface"))
                )
                
                // Mic / Send button
                if text.isEmpty {
                    Button {
                        // Voice input
                    } label: {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Color("LyoAccent"))
                            .frame(width: 36, height: 36)
                    }
                } else {
                    Button {
                        onSend()
                    } label: {
                        if isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(width: 36, height: 36)
                        } else {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 36))
                                .foregroundColor(Color("LyoAccent"))
                        }
                    }
                    .disabled(isLoading)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(Color("LyoBackground"))
        }
    }
}

struct AttachmentChip: View {
    let attachment: MessageAttachment
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForType(attachment.type))
                .font(.system(size: 12))
                .foregroundColor(Color("LyoAccent"))
            
            Text(attachment.filename ?? "File")
                .font(.system(size: 13))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Button {
                onRemove()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(Color("LyoTextSecondary"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color("LyoSurface"))
        )
    }
    
    private func iconForType(_ type: MessageAttachment.AttachmentType) -> String {
        switch type {
        case .file: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "play.rectangle.fill"
        case .audio: return "waveform"
        case .link: return "link"
        }
    }
}
