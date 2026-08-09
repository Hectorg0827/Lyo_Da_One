//
//  MediaPickerService.swift
//  Lyo
//
//  Service for picking and processing media attachments
//

import Foundation
import AVFoundation
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import os

/// Result from media picking
struct PickedMedia: Identifiable {
    let id = UUID()
    let type: AttachmentType
    let data: Data
    let filename: String
    let mimeType: String
    let thumbnail: UIImage?
    let originalURL: URL?
}

/// Service for picking and processing media attachments
@MainActor
class MediaPickerService: ObservableObject {
    static let shared = MediaPickerService()
    
    // MARK: - Published State
    @Published var selectedMedia: [PickedMedia] = []
    @Published var isLoading = false
    @Published var error: MediaPickerError?
    
    // MARK: - Configuration
    let maxImageSize: Int64 = 10 * 1024 * 1024 // 10 MB
    let maxVideoSize: Int64 = 100 * 1024 * 1024 // 100 MB
    let maxFileSize: Int64 = 10 * 1024 * 1024 // 10 MB in AI chat
    let maxTotalSize: Int64 = 20 * 1024 * 1024 // 20 MB per message
    let maxAttachmentCount = 4
    let supportedImageTypes: [UTType] = [.image, .jpeg, .png, .heic, .gif, .webP]
    let supportedVideoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie]
    let supportedDocTypes: [UTType] = [
        .pdf,
        .plainText,
        .commaSeparatedText,
        .json,
        UTType(filenameExtension: "md") ?? .plainText,
    ]

    private let supportedChatMimeTypes: Set<String> = [
        "image/jpeg", "image/png", "image/webp", "image/heic",
        "application/pdf", "text/plain", "text/markdown", "text/csv", "application/json",
    ]
    
    private init() {}
    
    // MARK: - Process PhotosUI Selection
    
    /// Process items selected from PhotosPicker
    func processPhotoPickerItems(_ items: [PhotosPickerItem]) async {
        isLoading = true
        error = nil
        
        for item in items {
            do {
                guard selectedMedia.count < maxAttachmentCount else {
                    throw MediaPickerError.tooManyFiles
                }
                if let media = try await processPhotoPickerItem(item) {
                    try validateSelectionCapacity(for: media.data.count)
                    selectedMedia.append(media)
                    HapticManager.shared.playAttachmentAdded()
                }
            } catch {
                Log.net.error("Failed to process photo picker item: \(error)")
                self.error = (error as? MediaPickerError)
                    ?? .processingFailed(error.localizedDescription)
            }
        }
        
        isLoading = false
    }
    
    private func processPhotoPickerItem(_ item: PhotosPickerItem) async throws -> PickedMedia? {
        // Try to load as image first
        if item.supportedContentTypes.contains(where: { $0.conforms(to: .image) }),
           let rawData = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: rawData),
           let imageData = image.jpegData(compressionQuality: 0.88) {
            guard Int64(imageData.count) <= maxImageSize else {
                throw MediaPickerError.fileTooLarge
            }
            
            let thumbnail = image.thumbnail(maxSize: 200)
            let filename = "image_\(UUID().uuidString.prefix(8)).jpg"
            
            return PickedMedia(
                type: .image,
                data: imageData,
                filename: filename,
                mimeType: "image/jpeg",
                thumbnail: thumbnail,
                originalURL: nil
            )
        }
        
        // Try to load as video
        if let videoData = try? await loadVideo(from: item) {
            guard Int64(videoData.count) <= maxVideoSize else {
                throw MediaPickerError.fileTooLarge
            }
            
            let thumbnail = await generateVideoThumbnail(from: videoData)
            let filename = "video_\(UUID().uuidString.prefix(8)).mp4"
            
            return PickedMedia(
                type: .video,
                data: videoData,
                filename: filename,
                mimeType: "video/mp4",
                thumbnail: thumbnail,
                originalURL: nil
            )
        }
        
        return nil
    }
    
    private func loadVideo(from item: PhotosPickerItem) async throws -> Data? {
        // Load video as movie file
        if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
            return try Data(contentsOf: movie.url)
        }
        return nil
    }
    
    // MARK: - Document Picker
    
    /// Process document picker result
    func processDocumentURL(_ url: URL) async throws -> PickedMedia {
        guard url.startAccessingSecurityScopedResource() else {
            throw MediaPickerError.accessDenied
        }
        defer { url.stopAccessingSecurityScopedResource() }
        
        let data = try Data(contentsOf: url)
        
        guard Int64(data.count) <= maxFileSize else {
            throw MediaPickerError.fileTooLarge
        }
        
        let mimeType = mimeTypeForURL(url)
        guard supportedChatMimeTypes.contains(mimeType) else {
            throw MediaPickerError.unsupportedFormat
        }
        try validateSelectionCapacity(for: data.count)
        let mediaType = mediaTypeFromMime(mimeType)
        
        let media = PickedMedia(
            type: mediaType,
            data: data,
            filename: url.lastPathComponent,
            mimeType: mimeType,
            thumbnail: thumbnailForDocument(url),
            originalURL: url
        )
        
        selectedMedia.append(media)
        HapticManager.shared.playAttachmentAdded()
        
        return media
    }
    
    // MARK: - Camera Capture
    
    /// Process image captured from camera
    func processCameraImage(_ image: UIImage) async throws -> PickedMedia {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw MediaPickerError.processingFailed("Failed to compress image")
        }
        
        guard Int64(data.count) <= maxImageSize else {
            throw MediaPickerError.fileTooLarge
        }
        try validateSelectionCapacity(for: data.count)
        
        let thumbnail = image.thumbnail(maxSize: 200)
        let filename = "camera_\(UUID().uuidString.prefix(8)).jpg"
        
        let media = PickedMedia(
            type: .image,
            data: data,
            filename: filename,
            mimeType: "image/jpeg",
            thumbnail: thumbnail,
            originalURL: nil
        )
        
        selectedMedia.append(media)
        HapticManager.shared.playAttachmentAdded()
        
        return media
    }
    
    // MARK: - Upload Media
    
    /// Upload selected media to backend and return attachment IDs
    func uploadSelectedMedia() async throws -> [String] {
        var attachmentIds: [String] = []
        
        for media in selectedMedia {
            do {
                let attachment = try await uploadMedia(media)
                attachmentIds.append(attachment.id)
            } catch {
                Log.net.error("Failed to upload media: \(error)")
                throw MediaPickerError.uploadFailed(error.localizedDescription)
            }
        }
        
        return attachmentIds
    }
    
    /// Upload a single picked media file to the backend
    func uploadMedia(_ media: PickedMedia) async throws -> MessageAttachment {
        guard !media.data.isEmpty else {
            throw MediaPickerError.noData
        }
        guard supportedChatMimeTypes.contains(media.mimeType) else {
            throw MediaPickerError.unsupportedFormat
        }

        let result = try await CloudStorageService.shared.uploadFile(
            data: media.data,
            filename: media.filename,
            contentType: media.mimeType,
            folder: "chat"
        )
        guard let publicURL = result.publicURL else {
            throw MediaPickerError.uploadFailed("The server did not return a file URL")
        }

        return MessageAttachment(
            id: result.blobName ?? publicURL,
            type: media.type == .image ? .image : .document,
            url: publicURL,
            filename: media.filename,
            size: media.data.count,
            mimeType: media.mimeType
        )
    }
    
    // MARK: - Clear Selection
    
    func clearSelection() {
        selectedMedia.removeAll()
    }
    
    func removeMedia(at index: Int) {
        guard index < selectedMedia.count else { return }
        selectedMedia.remove(at: index)
    }
    
    func removeMedia(_ media: PickedMedia) {
        selectedMedia.removeAll { $0.id == media.id }
    }
    
    // MARK: - Helpers
    
    private func mimeTypeForURL(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "application/pdf"
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "txt": return "text/plain"
        case "md", "markdown": return "text/markdown"
        case "csv": return "text/csv"
        case "json": return "application/json"
        default: return "application/octet-stream"
        }
    }

    private func validateSelectionCapacity(for byteCount: Int) throws {
        guard selectedMedia.count < maxAttachmentCount else {
            throw MediaPickerError.tooManyFiles
        }
        let selectedBytes = selectedMedia.reduce(Int64(0)) { total, item in
            total + Int64(item.data.count)
        }
        guard selectedBytes + Int64(byteCount) <= maxTotalSize else {
            throw MediaPickerError.totalTooLarge
        }
    }
    
    private func mediaTypeFromMime(_ mime: String) -> AttachmentType {
        if mime.hasPrefix("image/") { return .image }
        if mime.hasPrefix("video/") { return .video }
        if mime.hasPrefix("audio/") { return .audio }
        if mime == "application/pdf" || mime.hasPrefix("text/") { return .document }
        return .file
    }
    
    private func thumbnailForDocument(_ url: URL) -> UIImage? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf":
            return UIImage(systemName: "doc.fill")
        case "doc", "docx":
            return UIImage(systemName: "doc.text.fill")
        case "txt":
            return UIImage(systemName: "text.alignleft")
        default:
            return UIImage(systemName: "doc.fill")
        }
    }
    
    private func generateVideoThumbnail(from data: Data) async -> UIImage? {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("temp_video_\(UUID().uuidString).mp4")
        
        do {
            try data.write(to: tempURL)
            defer { try? FileManager.default.removeItem(at: tempURL) }
            
            let asset = AVURLAsset(url: tempURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            let time = CMTime(seconds: 0.5, preferredTimescale: 600)
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return UIImage(cgImage: cgImage).thumbnail(maxSize: 200)
        } catch {
            Log.net.error("Failed to generate video thumbnail: \(error)")
            return UIImage(systemName: "video.fill")
        }
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("video_\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func thumbnail(maxSize: CGFloat) -> UIImage? {
        let scale = min(maxSize / size.width, maxSize / size.height)
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        draw(in: CGRect(origin: .zero, size: newSize))
        let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return thumbnail
    }
}

// MARK: - Errors

enum MediaPickerError: LocalizedError {
    case fileTooLarge
    case totalTooLarge
    case tooManyFiles
    case unsupportedFormat
    case accessDenied
    case noData
    case processingFailed(String)
    case uploadFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "Each attachment must be 10 MB or smaller"
        case .totalTooLarge:
            return "Attachments may total at most 20 MB"
        case .tooManyFiles:
            return "You can attach up to 4 files"
        case .unsupportedFormat:
            return "Unsupported file format"
        case .accessDenied:
            return "Access denied to file"
        case .noData:
            return "No data available for the selected file"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .uploadFailed(let message):
            return "Upload failed: \(message)"
        }
    }
}
