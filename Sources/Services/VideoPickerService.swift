//
//  VideoPickerService.swift
//  Lyo
//
//  Service for picking videos from the photo library using PHPicker
//

import SwiftUI
import PhotosUI
import AVFoundation
import os

// MARK: - Video Picker Service

/// Service for selecting videos from the photo library
@MainActor
final class VideoPickerService: ObservableObject {
    static let shared = VideoPickerService()
    
    @Published var selectedVideoURL: URL?
    @Published var selectedThumbnail: UIImage?
    @Published var videoDuration: Double = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // Configuration
    let maxDurationSeconds: Double = 180 // 3 minutes max
    
    private init() {}
    
    // MARK: - Clear Selection
    
    func clearSelection() {
        selectedVideoURL = nil
        selectedThumbnail = nil
        videoDuration = 0
        errorMessage = nil
    }
    
    // MARK: - Process Selected Video
    
    /// Process a video from PHPickerResult
    func processSelectedVideo(_ result: PHPickerResult) async throws -> URL {
        isLoading = true
        errorMessage = nil
        
        defer { isLoading = false }
        
        guard result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) else {
            throw VideoPickerError.invalidFormat
        }
        
        // Load the video file
        let videoURL = try await loadVideo(from: result.itemProvider)
        
        // Validate duration
        let duration = await getVideoDuration(url: videoURL)
        if duration > maxDurationSeconds {
            throw VideoPickerError.tooLong(maxSeconds: Int(maxDurationSeconds))
        }
        
        // Generate thumbnail
        let thumbnail = await generateThumbnail(from: videoURL)
        
        // Update state
        selectedVideoURL = videoURL
        selectedThumbnail = thumbnail
        videoDuration = duration
        
        return videoURL
    }
    
    // MARK: - Load Video from Provider
    
    private func loadVideo(from provider: NSItemProvider) async throws -> URL {
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let sourceURL = url else {
                    continuation.resume(throwing: VideoPickerError.loadFailed)
                    return
                }
                
                // Copy to temp directory (source URL is ephemeral)
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mp4")
                
                do {
                    try FileManager.default.copyItem(at: sourceURL, to: tempURL)
                    continuation.resume(returning: tempURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Get Video Duration
    
    private func getVideoDuration(url: URL) async -> Double {
        let asset = AVAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            Log.media.warning("Failed to get video duration: \(error)")
            return 0
        }
    }
    
    // MARK: - Generate Thumbnail
    
    private func generateThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 512, height: 512)
        
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        
        do {
            let cgImage = try await imageGenerator.image(at: time).image
            return UIImage(cgImage: cgImage)
        } catch {
            Log.media.warning("Failed to generate thumbnail: \(error)")
            return nil
        }
    }
    
    // MARK: - Format Duration
    
    /// Format duration as mm:ss
    func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Video Picker Errors

enum VideoPickerError: LocalizedError {
    case invalidFormat
    case loadFailed
    case tooLong(maxSeconds: Int)
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "Please select a valid video file"
        case .loadFailed:
            return "Failed to load the video"
        case .tooLong(let maxSeconds):
            let minutes = maxSeconds / 60
            return "Video must be \(minutes) minutes or less"
        case .permissionDenied:
            return "Photo library access denied"
        }
    }
}

// MARK: - SwiftUI Video Picker

/// SwiftUI wrapper for PHPickerViewController (video only)
struct VideoPicker: UIViewControllerRepresentable {
    @Binding var selectedVideoURL: URL?
    @Binding var isPresented: Bool
    let onSelect: (URL) -> Void
    let onError: (Error) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(photoLibrary: .shared())
        config.filter = .videos
        config.selectionLimit = 1
        config.preferredAssetRepresentationMode = .current
        
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let parent: VideoPicker
        
        init(_ parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.isPresented = false
            
            guard let result = results.first else { return }
            
            Task { @MainActor in
                do {
                    let url = try await VideoPickerService.shared.processSelectedVideo(result)
                    parent.selectedVideoURL = url
                    parent.onSelect(url)
                } catch {
                    parent.onError(error)
                }
            }
        }
    }
}

// MARK: - Video Thumbnail View

/// Preview thumbnail for selected video
struct VideoThumbnailView: View {
    let thumbnail: UIImage?
    let duration: Double
    let onRemove: () -> Void
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let thumb = thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(16)
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .cornerRadius(16)
                    .overlay(
                        Image(systemName: "video.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
            
            // Duration badge
            if duration > 0 {
                Text(VideoPickerService.shared.formatDuration(duration))
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.black.opacity(0.7)))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }
            
            // Remove button
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(.white)
                    .shadow(radius: 4)
            }
            .padding(8)
        }
    }
}

// MARK: - Preview

#Preview {
    VideoThumbnailView(
        thumbnail: nil,
        duration: 45.5,
        onRemove: {}
    )
    .padding()
    .background(Color.black)
}
