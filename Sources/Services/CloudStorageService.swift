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
        guard await tokenManager.getToken() != nil else {
            throw CloudStorageError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/uploads/presigned-url")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body = PresignedURLRequest(
            filename: filename,
            contentType: contentType,
            folder: folder
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CloudStorageError.invalidResponse
        }
        
        if httpResponse.statusCode == 401 {
            throw CloudStorageError.notAuthenticated
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            if let error = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw CloudStorageError.serverError(error.detail ?? "Upload failed")
            }
            throw CloudStorageError.serverError("Status: \(httpResponse.statusCode)")
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PresignedURLResponse.self, from: data)
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
        var request = URLRequest(url: URL(string: uploadURL)!)
        request.httpMethod = "PUT"
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        
        // Add any additional headers from presigned response
        if let headers = presigned.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Use upload task for progress tracking
        let (_, response) = try await URLSession.shared.upload(for: request, from: data)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.uploadFailed
        }
        
        print("✅ File uploaded: \(presigned.publicUrl ?? "unknown")")
        
        return UploadResult(
            success: true,
            publicURL: presigned.publicUrl,
            blobName: presigned.blobName
        )
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
        guard await tokenManager.getToken() != nil else {
            throw CloudStorageError.notAuthenticated
        }
        
        // Process image: resize and compress for avatar
        let processedImage = resizeImage(image, maxDimension: 400)
        
        guard let imageData = processedImage.jpegData(compressionQuality: 0.85) else {
            throw CloudStorageError.invalidFile
        }
        
        let url = URL(string: "\(baseURL)/api/v1/uploads/avatar")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        if let authToken = await tokenManager.getToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        // Create multipart form data
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"avatar.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.uploadFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(AvatarUploadResponse.self, from: data)
    }
    
    /// Delete current user's avatar
    func deleteAvatar() async throws {
        guard await tokenManager.getToken() != nil else {
            throw CloudStorageError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/uploads/avatar")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let authToken = await tokenManager.getToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.deleteFailed
        }
        
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
        guard await tokenManager.getToken() != nil else {
            throw CloudStorageError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/uploads/usage")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let authToken = await tokenManager.getToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(StorageUsageResponse.self, from: data)
    }
    
    // MARK: - Delete File
    
    /// Delete a file from cloud storage
    func deleteFile(blobName: String) async throws {
        guard await tokenManager.getToken() != nil else {
            throw CloudStorageError.notAuthenticated
        }
        
        let encodedBlobName = blobName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? blobName
        let url = URL(string: "\(baseURL)/api/v1/uploads/file/\(encodedBlobName)")!
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        if let authToken = await tokenManager.getToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.deleteFailed
        }
        
        print("✅ File deleted: \(blobName)")
    }
    
    // MARK: - Validate File
    
    /// Validate file before upload (check type and size constraints)
    func validateFile(contentType: String, size: Int, fileType: String? = nil) async throws -> FileValidationResult {
        guard await tokenManager.getToken() != nil else {
            throw CloudStorageError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/uploads/validate")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let authToken = await tokenManager.getToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let body = FileValidationRequest(
            contentType: contentType,
            size: size,
            fileType: fileType
        )
        
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        request.httpBody = try encoder.encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(FileValidationResult.self, from: data)
    }
    
    // MARK: - Get Supported File Types
    
    /// Get information about supported file types and size limits
    func getSupportedFileTypes() async throws -> SupportedFileTypesResponse {
        guard await tokenManager.getToken() != nil else {
            throw CloudStorageError.notAuthenticated
        }
        
        let url = URL(string: "\(baseURL)/api/v1/uploads/supported-types")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let authToken = await tokenManager.getToken() {
            request.setValue("Bearer \(authToken)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw CloudStorageError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(SupportedFileTypesResponse.self, from: data)
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
