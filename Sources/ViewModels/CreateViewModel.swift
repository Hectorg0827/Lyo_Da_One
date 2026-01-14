//
//  CreateViewModel.swift
//  Lyo
//
//  ViewModel for managing creation flows (Reel/Story/Post/Course/Event)
//

import SwiftUI
import AVFoundation
import Photos

// MARK: - Creation Modes

enum CreateMode: String, CaseIterable, Identifiable {
    case reel = "Reel"
    case story = "Story"
    case post = "Post"
    case course = "Course"
    case event = "Event/Group"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .reel: return "play.rectangle.fill"
        case .story: return "clock.arrow.circlepath"
        case .post: return "square.and.pencil"
        case .course: return "graduationcap.fill"
        case .event: return "person.3.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .reel: return Color(hex: "8B5CF6") // Purple
        case .story: return Color(hex: "F97316") // Orange
        case .post: return Color(hex: "3B82F6") // Blue
        case .course: return Color(hex: "10B981") // Green
        case .event: return Color(hex: "EC4899") // Pink
        }
    }
    
    var description: String {
        switch self {
        case .reel: return "Short video for Discover"
        case .story: return "Share for 24 hours"
        case .post: return "Share to your feed"
        case .course: return "AI-generated course"
        case .event: return "Create event or group"
        }
    }
    
    var requiresCamera: Bool {
        switch self {
        case .reel, .story: return true
        case .post, .course, .event: return false
        }
    }
}

// MARK: - Creation State

enum CreateState: Equatable {
    case idle
    case recording
    case captured
    case editing
    case uploading
    case complete
    case error(String)
    
    static func == (lhs: CreateState, rhs: CreateState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle),
             (.recording, .recording),
             (.captured, .captured),
             (.editing, .editing),
             (.uploading, .uploading),
             (.complete, .complete):
            return true
        case let (.error(lhsError), .error(rhsError)):
            return lhsError == rhsError
        default:
            return false
        }
    }
}

// MARK: - Create ViewModel

@MainActor
class CreateViewModel: ObservableObject {
    // MARK: - Published State
    
    @Published var selectedMode: CreateMode = .reel
    @Published var state: CreateState = .idle
    @Published var progress: Double = 0
    
    // Camera State
    @Published var capturedImage: UIImage?
    @Published var capturedVideoURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    
    // Post/Course Content
    @Published var contentText: String = ""
    @Published var attachedFiles: [URL] = []
    
    // Course Generation
    @Published var courseTopic: String = ""
    @Published var courseLevel: String = "beginner"
    @Published var courseOutcomes: [String] = []
    
    // Event/Group Creation
    @Published var eventTitle: String = ""
    @Published var eventDescription: String = ""
    @Published var eventDate: Date = Date()
    @Published var eventLocation: String = ""
    @Published var isGroup: Bool = false
    
    // Learn Layers (Educational Stickers)
    @Published var learnLayers: [LearnLayer] = []
    
    // MARK: - Services
    
    private let repository = LyoRepository.shared
    private let courseService = CourseGenerationService.shared
    
    // MARK: - Camera Permissions
    
    func checkCameraPermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }
    
    func checkPhotoLibraryPermission() async -> PHAuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .notDetermined {
            return await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        }
        return status
    }
    
    // MARK: - Mode Actions
    
    func selectMode(_ mode: CreateMode) {
        selectedMode = mode
        resetState()
    }
    
    private func resetState() {
        state = .idle
        progress = 0
        contentText = ""
        capturedImage = nil
        capturedVideoURL = nil
        learnLayers = []
    }
    
    // MARK: - Camera Actions
    
    func startRecording() {
        state = .recording
        recordingDuration = 0
    }
    
    func stopRecording() {
        state = .captured
    }
    
    func toggleCamera() {
        cameraPosition = cameraPosition == .back ? .front : .back
    }
    
    func toggleFlash() {
        flashMode = flashMode == .off ? .on : .off
    }
    
    func capturePhoto(_ image: UIImage) {
        capturedImage = image
        state = .captured
    }
    
    func captureVideo(_ url: URL) {
        capturedVideoURL = url
        state = .captured
    }
    
    // MARK: - Learn Layers
    
    func addLearnLayer(_ layer: LearnLayer) {
        learnLayers.append(layer)
    }
    
    func removeLearnLayer(_ id: UUID) {
        learnLayers.removeAll { $0.id == id }
    }
    
    // MARK: - Publishing Actions
    
    func publish() async {
        state = .uploading
        progress = 0
        
        do {
            switch selectedMode {
            case .reel:
                try await publishReel()
            case .story:
                try await publishStory()
            case .post:
                try await publishPost()
            case .course:
                try await generateAndPublishCourse()
            case .event:
                try await publishEvent()
            }
            
            state = .complete
            
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Publishing Implementation
    
    private func publishReel() async throws {
        guard let videoURL = capturedVideoURL else {
            throw CreateError.missingContent
        }
        
        progress = 0.3
        
        // Upload video to storage
        let videoAttachment = try await repository.uploadFile(url: videoURL)
        
        progress = 0.6
        
        // Create social post with video
        let _ = try await repository.createPost(
            content: contentText,
            attachments: [videoAttachment.id]
        )
        
        progress = 1.0
        
        // Add to Stack
        await addToStack(type: .video, title: "Reel", subtitle: "Shared to Discover")
    }
    
    private func publishStory() async throws {
        guard let image = capturedImage else {
            throw CreateError.missingContent
        }
        
        progress = 0.3
        
        // Convert image to data and create temporary file URL
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw CreateError.invalidImage
        }
        
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")
        
        try imageData.write(to: tempURL)
        
        progress = 0.6
        
        // Upload to storage
        let attachment = try await repository.uploadFile(url: tempURL)
        
        // Create story post (24h expiry)
        let _ = try await repository.createPost(
            content: contentText,
            attachments: [attachment.id]
        )
        
        progress = 1.0
        
        // Clean up temp file
        try? FileManager.default.removeItem(at: tempURL)
        
        // Add to Stack
        await addToStack(type: .video, title: "Story", subtitle: "Expires in 24h")
    }
    
    private func publishPost() async throws {
        guard !contentText.isEmpty else {
            throw CreateError.missingContent
        }
        
        progress = 0.5
        
        // Upload attachments if any
        var attachmentIds: [String] = []
        for fileURL in attachedFiles {
            let attachment = try await repository.uploadFile(url: fileURL)
            attachmentIds.append(attachment.id)
        }
        
        progress = 0.7
        
        // Create post
        let _ = try await repository.createPost(
            content: contentText,
            attachments: attachmentIds.isEmpty ? nil : attachmentIds
        )
        
        progress = 1.0
        
        // Add to Stack
        await addToStack(type: .video, title: "Post", subtitle: contentText.prefix(50).description)
    }
    
    private func generateAndPublishCourse() async throws {
        guard !courseTopic.isEmpty else {
            throw CreateError.missingContent
        }
        
        progress = 0.2
        
        // Generate course via backend AI
        let generatedCourse = try await courseService.generateCourse(
            topic: courseTopic,
            level: courseLevel,
            outcomes: courseOutcomes.isEmpty ? nil : courseOutcomes,
            teachingStyle: "interactive"
        )
        
        progress = 0.9
        
        // Save to library (via backend)
        try await repository.saveCourse(
            title: generatedCourse.title,
            description: generatedCourse.description,
            modules: generatedCourse.modules.map { $0.id }
        )
        
        progress = 1.0
        
        // Add to Stack
        await addToStack(type: .course, title: generatedCourse.title, subtitle: generatedCourse.description)
    }
    
    private func publishEvent() async throws {
        guard !eventTitle.isEmpty else {
            throw CreateError.missingContent
        }
        
        progress = 0.5
        
        // TODO: Create event via Community API
        // For now, add placeholder to Stack
        
        progress = 1.0
        
        // Add to Stack
        await addToStack(
            type: isGroup ? .group : .event,
            title: eventTitle,
            subtitle: eventDescription
        )
    }
    
    // MARK: - Stack Integration
    
    private func addToStack(type: StackItemType, title: String, subtitle: String) async {
        do {
            let request = CreateStackItemRequest(
                type: type,
                refId: UUID().uuidString,
                tags: [subtitle],
                contextData: ["title": title, "source": "create"]
            )
            
            let _ = try await repository.createStackItem(request: request)
            
        } catch {
            print("⚠️ Failed to add to Stack: \(error)")
        }
    }
}

// MARK: - Learn Layer Model

struct LearnLayer: Identifiable {
    let id: UUID = UUID()
    var type: LayerType
    var position: CGPoint
    var content: String
    
    enum LayerType {
        case definition
        case formula
        case fact
        case question
        case quiz
        
        var icon: String {
            switch self {
            case .definition: return "book.fill"
            case .formula: return "function"
            case .fact: return "lightbulb.fill"
            case .question: return "questionmark.circle.fill"
            case .quiz: return "brain.head.profile"
            }
        }
        
        var color: Color {
            switch self {
            case .definition: return .blue
            case .formula: return .purple
            case .fact: return .yellow
            case .question: return .orange
            case .quiz: return .green
            }
        }
    }
}

// MARK: - Errors

enum CreateError: LocalizedError {
    case missingContent
    case invalidImage
    case uploadFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .missingContent:
            return "Please add content before publishing"
        case .invalidImage:
            return "Invalid image format"
        case .uploadFailed:
            return "Failed to upload media"
        case .permissionDenied:
            return "Camera or photo library permission denied"
        }
    }
}

