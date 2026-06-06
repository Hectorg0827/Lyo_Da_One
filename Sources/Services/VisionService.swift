import Foundation
import UIKit
import Photos

// MARK: - Vision Service
/// Service for AI-powered image analysis using Gemini Vision
class VisionService {

    // MARK: - Singleton
    static let shared = VisionService()

    private let networkClient = NetworkClient.shared
    private let logger = NetworkLogger()

    private init() {}

    // MARK: - Analysis Types

    /// Analyze image for general educational content
    func analyzeImage(_ image: UIImage, type: VisionAnalysisType = .educational) async throws -> VisionAnalysisResult {
        let imageData = try prepareImage(image)

        let result: VisionAnalysisResult = try await networkClient.upload(
            Endpoints.Vision.analyze(analysisType: type),
            data: imageData,
            fileName: "image.jpg",
            mimeType: "image/jpeg"
        )

        logger.log("✅ Vision analysis complete: \(type.rawValue)")
        return result
    }

    /// Extract text from image using OCR
    func extractText(from image: UIImage) async throws -> OCRResult {
        let imageData = try prepareImage(image)

        let result: OCRResult = try await networkClient.upload(
            Endpoints.Vision.ocr,
            data: imageData,
            fileName: "image.jpg",
            mimeType: "image/jpeg"
        )

        logger.log("✅ OCR extraction complete: \(result.text.count) characters")
        return result
    }

    /// Solve homework problem from image
    func solveHomework(_ image: UIImage, subject: String? = nil) async throws -> HomeworkSolution {
        let imageData = try prepareImage(image)

        // Add subject as form field if provided
        let endpoint = Endpoints.Vision.solve

        let result: HomeworkSolution = try await networkClient.upload(
            endpoint,
            data: imageData,
            fileName: "homework.jpg",
            mimeType: "image/jpeg"
        )

        logger.log("✅ Homework solved: \(result.steps.count) steps")
        return result
    }

    /// Explain diagram or chart
    func explainDiagram(_ image: UIImage) async throws -> DiagramExplanation {
        let imageData = try prepareImage(image)

        let result: DiagramExplanation = try await networkClient.upload(
            Endpoints.Vision.analyze(analysisType: .diagram),
            data: imageData,
            fileName: "diagram.jpg",
            mimeType: "image/jpeg"
        )

        logger.log("✅ Diagram explained")
        return result
    }

    /// Analyze chart or graph
    func analyzeChart(_ image: UIImage) async throws -> ChartAnalysis {
        let imageData = try prepareImage(image)

        let result: ChartAnalysis = try await networkClient.upload(
            Endpoints.Vision.analyze(analysisType: .chart),
            data: imageData,
            fileName: "chart.jpg",
            mimeType: "image/jpeg"
        )

        logger.log("✅ Chart analyzed")
        return result
    }

    /// Analyze code from screenshot
    func analyzeCode(_ image: UIImage) async throws -> CodeAnalysis {
        let imageData = try prepareImage(image)

        let result: CodeAnalysis = try await networkClient.upload(
            Endpoints.Vision.analyze(analysisType: .code),
            data: imageData,
            fileName: "code.jpg",
            mimeType: "image/jpeg"
        )

        logger.log("✅ Code analyzed")
        return result
    }

    // MARK: - Image Picker Helpers

    /// Request photo library permission
    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            return true

        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
                    continuation.resume(returning: newStatus == .authorized || newStatus == .limited)
                }
            }

        case .denied, .restricted:
            return false

        @unknown default:
            return false
        }
    }

    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            return true

        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)

        case .denied, .restricted:
            return false

        @unknown default:
            return false
        }
    }

    // MARK: - Image Processing

    private func prepareImage(_ image: UIImage) throws -> Data {
        // Resize if too large
        let resizedImage = resizeImage(image, maxDimension: 2048)

        // Compress to JPEG
        guard let imageData = resizedImage.jpegData(compressionQuality: AppConfig.imageCompressionQuality) else {
            throw LyoError.storage(.persistenceFailed)
        }

        // Check size
        if imageData.count > AppConfig.maxImageUploadSize {
            throw LyoError.network(.badRequest)
        }

        logger.log("📸 Image prepared: \(imageData.count / 1024)KB")
        return imageData
    }

    private func resizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        let maxSize = max(size.width, size.height)

        // Already small enough
        if maxSize <= maxDimension {
            return image
        }

        // Calculate new size
        let scale = maxDimension / maxSize
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)

        // Resize
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return resizedImage ?? image
    }
}

// MARK: - Vision Models

struct VisionAnalysisResult: Codable {
    let analysis: String
    let confidence: Double?
    let detectedObjects: [String]?
    let suggestedActions: [String]?
    let educationalContext: String?

    enum CodingKeys: String, CodingKey {
        case analysis
        case confidence
        case detectedObjects = "detected_objects"
        case suggestedActions = "suggested_actions"
        case educationalContext = "educational_context"
    }
}

struct OCRResult: Codable {
    let text: String
    let confidence: Double?
    let language: String?
    let blocks: [TextBlock]?

    struct TextBlock: Codable {
        let text: String
        let boundingBox: BoundingBox?
        let confidence: Double?

        enum CodingKeys: String, CodingKey {
            case text
            case boundingBox = "bounding_box"
            case confidence
        }
    }

    struct BoundingBox: Codable {
        let x: Double
        let y: Double
        let width: Double
        let height: Double
    }
}

struct HomeworkSolution: Codable {
    let problem: String
    let solution: String
    let steps: [SolutionStep]
    let explanation: String
    let subject: String?
    let difficulty: String?
    let relatedTopics: [String]?

    struct SolutionStep: Codable {
        let step: Int
        let description: String
        let equation: String?
        let explanation: String?
    }

    enum CodingKeys: String, CodingKey {
        case problem
        case solution
        case steps
        case explanation
        case subject
        case difficulty
        case relatedTopics = "related_topics"
    }
}

struct DiagramExplanation: Codable {
    let title: String?
    let description: String
    let components: [DiagramComponent]?
    let relationships: [String]?
    let keyTakeaways: [String]?

    struct DiagramComponent: Codable {
        let name: String
        let description: String
        let position: String?
    }

    enum CodingKeys: String, CodingKey {
        case title
        case description
        case components
        case relationships
        case keyTakeaways = "key_takeaways"
    }
}

struct ChartAnalysis: Codable {
    let chartType: String
    let title: String?
    let description: String
    let dataPoints: [DataPoint]?
    let trends: [String]?
    let insights: [String]?

    struct DataPoint: Codable {
        let label: String
        let value: Double
        let series: String?
    }

    enum CodingKeys: String, CodingKey {
        case chartType = "chart_type"
        case title
        case description
        case dataPoints = "data_points"
        case trends
        case insights
    }
}

struct CodeAnalysis: Codable {
    let language: String?
    let code: String
    let explanation: String
    let issues: [CodeIssue]?
    let suggestions: [String]?
    let complexity: String?

    struct CodeIssue: Codable {
        let line: Int?
        let severity: String
        let message: String
        let fix: String?
    }
}

// MARK: - Import AVFoundation for Camera

import AVFoundation
