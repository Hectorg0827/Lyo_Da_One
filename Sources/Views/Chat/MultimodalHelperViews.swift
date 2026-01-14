//
//  MultimodalHelperViews.swift
//  Lyo
//
//  Helper views for multimodal chat functionality
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Voice Waveform Visualization

struct VoiceWaveformView: View {
    let level: Float
    let barCount: Int = 20
    
    var body: some View {
        GeometryReader { _ in
            HStack(spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    WaveformBar(
                        level: level,
                        index: index,
                        barCount: barCount
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

private struct WaveformBar: View {
    let level: Float
    let index: Int
    let barCount: Int
    
    @State private var animatedHeight: CGFloat = 0.2
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(
                LinearGradient(
                    colors: [.purple.opacity(0.7), .blue.opacity(0.7)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(width: 3, height: animatedHeight * 40)
            .animation(.easeInOut(duration: 0.1), value: animatedHeight)
            .onAppear {
                updateHeight()
            }
            .onChange(of: level) { _ in
                updateHeight()
            }
    }
    
    private func updateHeight() {
        // Create wave pattern based on position and level
        let normalizedIndex = CGFloat(index) / CGFloat(barCount)
        let centerDistance = abs(normalizedIndex - 0.5) * 2
        let baseHeight: CGFloat = 0.2
        let levelContribution = CGFloat(level) * (1 - centerDistance * 0.5)
        let randomVariation = CGFloat.random(in: 0.8...1.2)
        
        animatedHeight = min(1.0, baseHeight + levelContribution * randomVariation)
    }
}

// MARK: - Pulse Animation Modifier

struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.2 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: 0.6)
                .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - Attachment Preview Chip

struct AttachmentPreviewChip: View {
    let attachment: MessageAttachment
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail or Icon
            Group {
                if false {
                    EmptyView()
                } else {
                    attachmentIcon
                }
            }
            
            // File Info
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename ?? "Attachment")
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                if let size = attachment.size {
                    Text(formatFileSize(size))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
    }
    
    private var attachmentIcon: some View {
        Image(systemName: iconForType(attachment.type))
            .font(.system(size: 16))
            .foregroundColor(.blue)
            .frame(width: 32, height: 32)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .document: return "doc"
        case .file: return "doc.text"
        case .link: return "link"
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        } else {
            return String(format: "%.1f MB", kb / 1024)
        }
    }
}

// MARK: - Media Preview Chip (for PickedMedia from picker)

struct MediaPreviewChip: View {
    let media: PickedMedia
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Thumbnail or Icon
            Group {
                if let thumbnail = media.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 32, height: 32)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    mediaIcon
                }
            }
            
            // File Info
            VStack(alignment: .leading, spacing: 2) {
                Text(media.filename)
                    .font(.caption)
                    .lineLimit(1)
                
                Text(formatFileSize(media.data.count))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Remove Button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.05))
        .clipShape(Capsule())
    }
    
    private var mediaIcon: some View {
        Image(systemName: iconForType(media.type))
            .font(.system(size: 16))
            .foregroundColor(.blue)
            .frame(width: 32, height: 32)
            .background(Color.blue.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
    
    private func iconForType(_ type: AttachmentType) -> String {
        switch type {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .document: return "doc"
        case .file: return "doc.text"
        case .link: return "link"
        }
    }
    
    private func formatFileSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        } else {
            let mb = kb / 1024
            return String(format: "%.1f MB", mb)
        }
    }
}

// MARK: - Photo Picker View (PhotosUI)

struct PHPickerView: UIViewControllerRepresentable {
    let onPick: (PickedMedia?) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.selectionLimit = 1
        config.filter = .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let onPick: (PickedMedia?) -> Void
        
        init(onPick: @escaping (PickedMedia?) -> Void) {
            self.onPick = onPick
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let result = results.first else {
                onPick(nil)
                return
            }
            
            // Check if it's a video
            if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { [weak self] url, error in
                    DispatchQueue.main.async {
                        if let url = url {
                            let media = PickedMedia(
                                type: .video,
                                data: (try? Data(contentsOf: url)) ?? Data(),
                                filename: url.lastPathComponent,
                                mimeType: "video/quicktime",
                                thumbnail: nil,
                                originalURL: url
                            )
                            self?.onPick(media)
                        } else {
                            self?.onPick(nil)
                        }
                    }
                }
            } else {
                // It's an image
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] object, error in
                    DispatchQueue.main.async {
                        if let image = object as? UIImage,
                           let data = image.jpegData(compressionQuality: 0.8) {
                            let media = PickedMedia(
                                type: .image,
                                data: data,
                                filename: "image.jpg",
                                mimeType: "image/jpeg",
                                thumbnail: image,
                                originalURL: nil
                            )
                            self?.onPick(media)
                        } else {
                            self?.onPick(nil)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Camera Picker View

struct CameraPickerView: UIViewControllerRepresentable {
    let onPick: (PickedMedia?) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.image", "public.movie"]
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let onPick: (PickedMedia?) -> Void
        
        init(onPick: @escaping (PickedMedia?) -> Void) {
            self.onPick = onPick
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let videoURL = info[.mediaURL] as? URL {
                let media = PickedMedia(
                    type: .video,
                    data: (try? Data(contentsOf: videoURL)) ?? Data(),
                    filename: videoURL.lastPathComponent,
                    mimeType: "video/quicktime",
                    thumbnail: nil,
                    originalURL: videoURL
                )
                onPick(media)
            } else if let image = info[.originalImage] as? UIImage,
                      let data = image.jpegData(compressionQuality: 0.8) {
                let media = PickedMedia(
                    type: .image,
                    data: data,
                    filename: "camera_image.jpg",
                    mimeType: "image/jpeg",
                    thumbnail: image,
                    originalURL: nil
                )
                onPick(media)
            } else {
                onPick(nil)
            }
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onPick(nil)
        }
    }
}



#if DEBUG
struct MultimodalHelperViews_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Waveform
            VoiceWaveformView(level: 0.6)
                .frame(height: 50)
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
            
            // Attachment Chip
            AttachmentPreviewChip(
                attachment: MessageAttachment(
                    id: "1",
                    type: .document,
                    url: "https://example.com/doc.pdf",
                    filename: "document.pdf",
                    size: 2048000,
                    mimeType: "application/pdf"
                ),
                onRemove: {}
            )
        }
        .padding()
    }
}
#endif
