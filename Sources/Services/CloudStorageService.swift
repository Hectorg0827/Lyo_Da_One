import Foundation
import UIKit

// MARK: - Cloud Storage Service

/// Service for managing file uploads with the Lyo backend.
/// Uses presigned URLs for direct upload to cloud storage.
final class CloudStorageService {
    static let shared = CloudStorageService()
    
    private var baseURL: String { AppConfig.baseURL }
    private let tokenManager = TokenManager.shared
    
    private init() {}
    
    // MARK: - Get Presigned URL
    
    /// Get a presigned URL for direct upload to cloud storage
    func getPresignedURL(
        filename: String,
        contentType: String,
        folder: String = "uploads"
    ) async throws -> PresignedURLResponse {
        let body = PresignedURLRequest(
            filename: filename,
            contentType: contentType,
            folder: folder
        )
        
        // Use DynamicEndpoint to match the specific path used by this service
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/uploads/presigned-url",
            method: .post,
            body: body,
            requiresAuth: true
        )
        
        do {
            return try await NetworkClient.shared.request(endpoint)
        } catch let error as LyoError {
            if case .network(.unauthorized) = error {
                throw CloudStorageError.notAuthenticated
            }
            throw error
        } catch {
            throw error
        }
    }
    
    // MARK: - Upload File
    
    /// Upload a file directly to cloud storage using presigned URL
    func uploadFile(
        data: Data,
        filename: String,
        contentType: String,
        folder: String = "uploads",
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> UploadResult {
        // 1. Get presigned URL from backend
        let presigned = try await getPresignedURL(
            filename: filename,
            contentType: contentType,
            folder: folder
        )
        
        guard presigned.success, let uploadURL = presigned.uploadUrl else {
            throw CloudStorageError.serverError(presigned.error ?? "Failed to get upload URL")
        }
        
        // 2. Upload directly to cloud storage
        guard let url = URL(string: uploadURL) else {
            throw CloudStorageError.serverError("Invalid upload URL")
        }
        
        do {
            try await NetworkClient.shared.uploadBinary(
                url: url,
                data: data,
                contentType: contentType,
                headers: presigned.headers
            )
            
            print("✅ File uploaded: \(presigned.publicUrl ?? "unknown")")
            
            return UploadResult(
                success: true,
                publicURL: presigned.publicUrl,
                blobName: presigned.blobName
            )
        } catch {
            print("❌ Upload failed: \(error)")
            throw CloudStorageError.uploadFailed
        }
    }
    
    // MARK: - Upload Image
    
    /// Upload an image with automatic compression
    func uploadImage(
        image: UIImage,
        filename: String? = nil,
        folder: String = "images",
        quality: CGFloat = 0.8,
        maxDimension: CGFloat? = 1920
    ) async throws -> UploadResult {
        // Resize if needed
        var processedImage = image
        if let maxDim = maxDimension {
            processedImage = resizeImage(image, maxDimension: maxDim)
        }
        
        // Convert to JPEG data
        guard let imageData = processedImage.jpegData(compressionQuality: quality) else {
            throw CloudStorageError.invalidFile
        }
        
        let finalFilename = filename ?? "image_\(UUID().uuidString).jpg"
        
        return try await uploadFile(
            data: imageData,
            filename: finalFilename,
            contentType: "image/jpeg",
            folder: folder
        )
    }
    
    /// Upload PNG image (preserves transparency)
    func uploadPNGImage(
        image: UIImage,
        filename: String? = nil,
        folder: String = "images",
        maxDimension: CGFloat? = 1920
    ) async throws -> UploadResult {
        var processedImage = image
        if let maxDim = maxDimension {
            processedImage = resizeImage(image, maxDimension: maxDim)
        }
        
        guard let imageData = processedImage.pngData() else {
            throw CloudStorageError.invalidFile
        }
        
        let finalFilename = filename ?? "image_\(UUID().uuidString).png"
        
        return try await uploadFile(
            data: imageData,
            filename: finalFilename,
            contentType: "image/png",
            folder: folder
        )
    }
    
    // MARK: - Upload Avatar
    
    /// Upload user avatar with automatic processing
    func uploadAvatar(image: UIImage) async throws -> AvatarUploadResponse {
        // Process image: resize and compress for avatar
        let processedImage = resizeImage(image, maxDimension: 400)
        
        guard let imageData = processedImage.jpegData(compressionQuality: 0.85) else {
            throw CloudStorageError.invalidFile
        }
        
        // Use DynamicEndpoint to match existing path structure
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/uploads/avatar",
            method: .post,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.upload(
            endpoint,
            data: imageData,
            fileName: "avatar.jpg",
            mimeType: "image/jpeg"
        )
    }
    
    /// Delete current user's avatar
    func deleteAvatar() async throws {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/uploads/avatar",
            method: .delete,
            requiresAuth: true
        )
        
        let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
        print("✅ Avatar deleted")
    }
    
    // MARK: - Upload Document
    
    /// Upload a document file (PDF, TXT, DOC, etc.)
    func uploadDocument(
        data: Data,
        filename: String,
        contentType: String
    ) async throws -> UploadResult {
        return try await uploadFile(
            data: data,
            filename: filename,
            contentType: contentType,
            folder: "documents"
        )
    }
    
    // MARK: - Storage Usage
    
    /// Get user's storage usage statistics
    func getStorageUsage() async throws -> StorageUsageResponse {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/uploads/usage",
            method: .get,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Delete File
    
    /// Delete a file from cloud storage
    func deleteFile(blobName: String) async throws {
        let encodedBlobName = blobName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? blobName
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/uploads/file/\(encodedBlobName)",
            method: .delete,
            requiresAuth: true
        )
        
        let _: EmptyResponse = try await NetworkClient.shared.request(endpoint)
        print("✅ File deleted: \(blobName)")
    }
    
    // MARK: - Validate File
    
    /// Validate file before upload (check type and size constraints)
    func validateFile(contentType: String, size: Int, fileType: String? = nil) async throws -> FileValidationResult {
        let body = FileValidationRequest(
            contentType: contentType,
            size: size,
            fileType: fileType
        )
        
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/uploads/validate",
            method: .post,
            body: body,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Get Supported File Types
    
    /// Get information about supported file types and size limits
    func getSupportedFileTypes() async throws -> SupportedFileTypesResponse {
        let endpoint = DynamicEndpoint(
            urlString: "/api/v1/uploads/supported-types",
            method: .get,
            requiresAuth: true
        )
        
        return try await NetworkClient.shared.request(endpoint)
    }
    
    // MARK: - Image Processing Helpers
    
    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        guard size.width > maxDimension || size.height > maxDimension else {
            return image
        }
        
        let ratio = min(maxDimension / size.width, maxDimension / size.height)
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// MARK: - Request Models

struct PresignedURLRequest: Codable {
    let filename: String
    let contentType: String
    let folder: String
}

struct FileValidationRequest: Codable {
    let contentType: String
    let size: Int
    let fileType: String?
}

// MARK: - Response Models

struct PresignedURLResponse: Codable {
    let success: Bool
    let uploadUrl: String?
    let publicUrl: String?
    let blobName: String?
    let expiresInSeconds: Int?
    let headers: [String: String]?
    let error: String?
}

struct AvatarUploadResponse: Codable {
    let success: Bool
    let avatarUrl: String?
    let message: String?
    let error: String?
}

struct UploadResult {
    let success: Bool
    let publicURL: String?
    let blobName: String?
}

struct StorageUsageResponse: Codable {
    let totalFiles: Int
    let totalSizeBytes: Int
    let totalSizeMb: Double
    let byType: [String: Int]
}

struct FileValidationResult: Codable {
    let valid: Bool
    let errors: [String]?
    let warnings: [String]?
}

struct SupportedFileTypesResponse: Codable {
    let image: FileTypeInfo
    let video: FileTypeInfo
    let audio: FileTypeInfo
    let document: FileTypeInfo
    let avatar: AvatarInfo
}

struct FileTypeInfo: Codable {
    let types: [String]
    let maxSizeMb: Double
    let extensions: [String]
}

struct AvatarInfo: Codable {
    let maxSizeMb: Double
    let allowedTypes: [String]
}

struct ErrorResponse: Codable {
    let detail: String?
}

// MARK: - Errors

enum CloudStorageError: LocalizedError {
    case notAuthenticated
    case invalidResponse
    case invalidFile
    case uploadFailed
    case deleteFailed
    case serverError(String)
    
    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "Please log in to upload files"
        case .invalidResponse:
            return "Invalid response from server"
        case .invalidFile:
            return "Invalid file format"
        case .uploadFailed:
            return "File upload failed"
        case .deleteFailed:
            return "Failed to delete file"
        case .serverError(let message):
            return message
        }
    }
}
