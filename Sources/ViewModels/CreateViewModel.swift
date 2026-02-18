//
//  CreateViewModel.swift
//  Lyo
//
//  ViewModel for managing creation flows (Clip/Story/Post/Course/Event)
//

import SwiftUI
import AVFoundation
import Photos
import MapKit
import PhotosUI
import os

// MARK: - Creation Modes

enum CreateMode: String, CaseIterable, Identifiable {
    case clip = "Clip"
    case reel = "Reel"     // Alias for compatibility
    case story = "Story"
    case post = "Post"
    case course = "Course"
    case event = "Event/Group"
    case live = "Live"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .clip, .reel: return "film.stack"
        case .story: return "clock.arrow.circlepath"
        case .post: return "square.and.pencil"
        case .course: return "graduationcap.fill"
        case .event: return "person.3.fill"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }
    
    var color: Color {
        switch self {
        case .clip, .reel: return Color(hex: "8B5CF6") // Purple
        case .story: return Color(hex: "F97316") // Orange
        case .post: return Color(hex: "3B82F6") // Blue
        case .course: return Color(hex: "10B981") // Green
        case .event: return Color(hex: "EC4899") // Pink
        case .live: return Color(hex: "EF4444") // Red
        }
    }
    
    var description: String {
        switch self {
        case .clip, .reel: return "Educational video clip"
        case .story: return "Share for 24 hours"
        case .post: return "Share to your feed"
        case .course: return "AI-generated course"
        case .event: return "Create event or group"
        case .live: return "Go live with your audience"
        }
    }
    
    var requiresCamera: Bool {
        switch self {
        case .clip, .story, .reel, .live: return true
        case .post, .course, .event: return false
        }
    }
    
    var gradient: LinearGradient {
        switch self {
        case .clip:
            return LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "06B6D4")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .reel:
            return LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "F97316")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .story:
            return LinearGradient(colors: [Color(hex: "8B5CF6"), Color(hex: "EC4899")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .course:
            return LinearGradient(colors: [Color(hex: "06B6D4"), Color(hex: "8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .post:
            return LinearGradient(colors: [Color(hex: "F97316"), Color(hex: "EAB308")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .event:
            return LinearGradient(colors: [Color(hex: "EC4899"), Color(hex: "8B5CF6")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .live:
            return LinearGradient(colors: [Color(hex: "EF4444"), Color(hex: "EC4899")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    var displayName: String { rawValue }
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
    
    @Published var selectedMode: CreateMode = .clip  // Default to Clip (formerly Reel)
    @Published var state: CreateState = .idle
    @Published var progress: Double = 0
    
    // Camera State
    @Published var capturedImage: UIImage?
    @Published var capturedVideoURL: URL?
    @Published var recordingDuration: TimeInterval = 0
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var flashMode: AVCaptureDevice.FlashMode = .off
    @Published var isCameraSource: Bool = true
    @Published var videoThumbnail: UIImage?
    
    // Video Picker State
    @Published var showVideoPicker: Bool = false
    @Published var selectedPhotoItem: PhotosPickerItem?
    
    // Clip Metadata (for AI course generation)
    @Published var clipTitle: String = ""
    @Published var clipDescription: String = ""
    @Published var clipSubject: ClipSubject?
    @Published var clipLevel: LearningLevel = .beginner
    @Published var clipKeyPoints: [String] = []
    @Published var enableClipCourseGeneration: Bool = true
    @Published var showClipMetadataSheet: Bool = false
    
    // Post/Course Content
    @Published var contentText: String = "" {
        didSet {
            updateCharCount()
        }
    }
    @Published var charCount: Int = 0
    @Published var attachedFiles: [URL] = []
    
    // Course Generation
    @Published var courseTopic: String = ""
    @Published var courseLevel: String = "beginner"
    @Published var courseDescription: String = ""
    @Published var courseOutcomes: [String] = []
    @Published var isAIOutlineActive: Bool = false
    @Published var generatedModules: [String] = []
    
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
    private let storyService = StoryService.shared
    private let network = NetworkClient.shared
    
    // MARK: - Init
    init(initialMode: CreateMode = .reel) {
        self.selectedMode = initialMode
    }

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
        charCount = 0
        capturedImage = nil
        capturedVideoURL = nil
        videoThumbnail = nil
        learnLayers = []
        isAIOutlineActive = false
        generatedModules = []
        
        // Reset clip metadata
        clipTitle = ""
        clipDescription = ""
        clipSubject = nil
        clipLevel = .beginner
        clipKeyPoints = []
        enableClipCourseGeneration = true
    }
    
    private func updateCharCount() {
        charCount = contentText.count
    }
    
    func toggleAIOutline() {
        isAIOutlineActive.toggle()
        if isAIOutlineActive {
            // Mock AI generation
            generatedModules = [
                "Module 1: Introduction",
                "Module 2: Core Concepts",
                "Module 3: Practice",
                "Module 4: Assessment"
            ]
        } else {
            generatedModules = []
        }
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
            case .clip, .reel:
                try await publishClip()
            case .story:
                try await publishStory()
            case .post:
                try await publishPost()
            case .course:
                try await generateAndPublishCourse()
            case .event:
                try await publishEvent()
            case .live:
                try await publishEvent()
            }
            
            state = .complete
            
        } catch {
            state = .error(error.localizedDescription)
        }
    }
    
    // MARK: - Publishing Implementation
    
    private func buildLocation() -> Location {
        let trimmed = eventLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        let isVirtual = trimmed.isEmpty
        let name = isVirtual ? "Virtual" : trimmed
        let type: Location.LocationType = isVirtual ? .virtual : .coordinates
        let coordinate = CLLocationCoordinate2D(latitude: 0, longitude: 0)
        return Location(type: type, name: name, coordinate: coordinate)
    }

    /// Publish a clip with metadata using ClipService
    private func publishClip() async throws {
        guard let videoURL = capturedVideoURL else {
            throw CreateError.missingContent
        }
        
        guard !clipTitle.isEmpty else {
            throw CreateError.missingTitle
        }
        
        // Build clip metadata
        let metadata = ClipMetadata(
            subject: clipSubject?.rawValue,
            topic: nil,
            level: clipLevel,
            keyPoints: clipKeyPoints,
            transcript: nil, // Can be auto-generated later
            tags: [],
            enableCourseGeneration: enableClipCourseGeneration
        )
        
        // Use ClipService for real upload with progress
        let clip = try await ClipService.shared.createClip(
            videoURL: videoURL,
            title: clipTitle,
            description: clipDescription.isEmpty ? nil : clipDescription,
            metadata: metadata,
            isPublic: true
        ) { [weak self] progress in
            Task { @MainActor in
                self?.progress = progress
            }
        }
        
        Log.ui.info("Clip published: \(clip.title)")
        
        // Add to Stack
        await addToStack(
            type: .video, 
            title: clip.title, 
            subtitle: clipDescription.isEmpty ? "Shared to Discover" : clipDescription,
            refId: clip.id
        )
    }
    
    private func publishStory() async throws {
        progress = 0.1
        
        // Support both image and video for stories
        var mediaURL: String = ""
        var mediaType: Story.MediaType = .image
        
        if let image = capturedImage {
            // Convert image to data and upload
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                throw CreateError.invalidImage
            }
            
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("jpg")
            
            try imageData.write(to: tempURL)
            
            progress = 0.3
            
            // Upload to storage via StoryService
            mediaURL = try await storyService.uploadStoryMedia(imageURL: tempURL)
            mediaType = .image
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: tempURL)
            
        } else if let videoURL = capturedVideoURL {
            progress = 0.3
            
            // Upload video
            mediaURL = try await storyService.uploadStoryMedia(videoURL: videoURL)
            mediaType = .video
            
        } else {
            throw CreateError.missingContent
        }
        
        progress = 0.6
        
        // Create story via StoryService (handles backend call)
        try await storyService.addStory(
            mediaURL: mediaURL,
            mediaType: mediaType,
            caption: contentText.isEmpty ? nil : contentText,
            isLive: false
        )
        
        progress = 1.0
        
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
        let persistenceData = CourseCreationData(
            id: generatedCourse.courseId,
            title: generatedCourse.title,
            topic: courseTopic,
            level: courseLevel,
            modules: generatedCourse.modules.map { mod in
                CourseModuleData(
                    id: mod.id,
                    title: mod.title,
                    description: mod.description,
                    lessons: mod.lessons.map { les in
                        CourseLessonData(id: les.id, title: les.title, duration: "\(les.durationMinutes) min")
                    }
                )
            }
        )
        try await repository.saveCourse(data: persistenceData)
        
        progress = 1.0
        
        // Add to Stack
        await addToStack(type: .course, title: generatedCourse.title, subtitle: generatedCourse.description)
    }
    
    // MARK: - Course Creation with Classroom Navigation
    
    /// Generates a course using AI and immediately navigates to the classroom (cinematic view)
    func generateCourseAndOpenClassroom() async {
        guard !courseTopic.isEmpty else { return }
        
        state = .uploading
        progress = 0.1
        
        // Build CoursePayload for orchestrator
        let payload = CoursePayload(
            id: nil,
            title: courseTopic,
            topic: courseTopic,
            level: courseLevel,
            language: "en",
            duration: "~45 min",
            objectives: courseOutcomes.isEmpty 
                ? ["Learn \(courseTopic) fundamentals", "Apply practical skills"]
                : courseOutcomes
        )
        
        // Use CourseOrchestrator (optimistic navigation)
        // This will open the classroom immediately with a shell course
        // while real AI content loads in the background
        await CourseOrchestrator.shared.execute(proposal: payload)
        
        progress = 0.5
        
        // Add to stack for later access
        let description = courseDescription.isEmpty 
            ? "Learn \(courseTopic) at the \(courseLevel) level" 
            : courseDescription
        await addToStack(
            type: .course, 
            title: courseTopic, 
            subtitle: description
        )
        
        progress = 1.0
        state = .complete
    }
    
    private func publishEvent() async throws {
        guard !eventTitle.isEmpty else {
            throw CreateError.missingContent
        }
        
        progress = 0.4
        
        let organizer = User(
            id: 0,
            email: "",
            name: "Me",
            avatarURL: nil,
            createdAt: Date(),
            level: 1,
            xp: 0,
            streak: 0,
            totalLessonsCompleted: 0,
            achievements: []
        )
        let location = buildLocation()
        let description = eventDescription.isEmpty ? "Created via +" : eventDescription
        
        if isGroup {
            let group = StudyGroup(
                id: UUID().uuidString,
                title: eventTitle,
                description: description,
                organizer: organizer,
                location: location,
                schedule: .oneTime(date: eventDate, duration: 3600),
                maxAttendees: 10,
                currentAttendees: [],
                skillLevel: .beginner,
                relatedCourse: nil,
                cost: 0,
                tags: [],
                createdAt: Date(),
                isVerified: false
            )
            let created: StudyGroup = try await network.request(Endpoints.Community.createStudyGroup(group: group))
            progress = 1.0
            await addToStack(type: .group, title: created.title, subtitle: created.description, refId: created.id)
        } else {
            let event = EducationalEvent(
                id: UUID().uuidString,
                title: eventTitle,
                description: description,
                organizer: organizer,
                location: location,
                dateTime: eventDate,
                duration: 3600,
                capacity: 50,
                registeredUsers: [],
                cost: 0,
                skillLevel: .beginner,
                category: .workshop,
                tags: [],
                coverImageURL: nil,
                isVerified: false
            )
            let created: EducationalEvent = try await network.request(Endpoints.Community.createEvent(event: event))
            progress = 1.0
            await addToStack(type: .event, title: created.title, subtitle: created.description, refId: created.id)
        }
    }
    
    // MARK: - Stack Integration
    
    private func addToStack(type: StackItemType, title: String, subtitle: String, refId: String = UUID().uuidString) async {
        do {
            let request = CreateStackItemRequest(
                type: type,
                refId: refId,
                tags: [subtitle],
                contextData: ["title": title, "source": "create"]
            )
            
            let _ = try await repository.createStackItem(request: request)
            
        } catch {
            Log.ui.warning("Failed to add to Stack: \(error)")
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
    case missingTitle
    case invalidImage
    case uploadFailed
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .missingContent:
            return "Please add content before publishing"
        case .missingTitle:
            return "Please add a title for your clip"
        case .invalidImage:
            return "Invalid image format"
        case .uploadFailed:
            return "Failed to upload media"
        case .permissionDenied:
            return "Camera or photo library permission denied"
        }
    }
}

