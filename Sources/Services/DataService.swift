import Foundation
import os

/// Unified data service that handles real backend calls and demo mode fallback
@MainActor
final class DataService: ObservableObject {
    static let shared = DataService()
    
    @Published var isLoading = false
    @Published var lastError: String?
    
    private let apiClient = LyoAPIClient.shared
    
    private init() {}
    
    // MARK: - Check Mode
    
    private var isInDemoMode: Bool {
        AuthService.shared.isDemoMode
    }
    
    // MARK: - Courses
    
    func fetchCourses() async -> [Course] {
        if isInDemoMode {
            Log.data.info("Demo Mode: returning mock courses")
            return mockCourses()
        }
        
        do {
            let courses = try await apiClient.fetchCourses()
            Log.data.info("Fetched \(courses.count) courses from backend")
            return courses
        } catch {
            Log.data.error("Failed to fetch courses: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return [] // Return empty list instead of mocks
        }
    }
    
    // MARK: - Discover Feed
    
    func fetchDiscoverFeed() async -> [DiscoverItem] {
        if isInDemoMode {
            Log.data.info("Demo Mode: returning mock discover items")
            return mockDiscoverItems()
        }
        
        do {
            // Fetch real discoveries from clips/discover
            let response = try await apiClient.fetchDiscoveriesFeed(limit: 20, offset: 0)
            
            // Map Discovery models to DiscoverItems
            let discoveryItems = response.discoveries.map { discovery -> DiscoverItem in
                return DiscoverItem(
                    id: String(discovery.id),
                    type: .userClip,
                    title: discovery.title,
                    subtitle: discovery.description ?? "",
                    tag: discovery.userName ?? "New",
                    estimatedMinutes: 2, // Placeholder
                    thumbnailURL: discovery.thumbnailURL.flatMap { URL(string: $0) },
                    videoURL: discovery.videoURL.flatMap { URL(string: $0) },
                    aiInsight: nil,
                    subject: "Community",
                    level: .beginner,
                    xpReward: 20,
                    keyPoints: [],
                    quizMoments: [],
                    isLiked: discovery.isLiked,
                    likeCount: discovery.likes,
                    viewCount: discovery.views,
                    shareCount: 0,
                    isSaved: discovery.isSaved,
                    authorName: discovery.userName ?? "Lyo User",
                    authorAvatarURL: nil // Could add if available in model
                )
            }
            
            Log.data.info("Fetched \(discoveryItems.count) discoveries from backend")
            return discoveryItems
            
        } catch {
            Log.data.error("Failed to fetch discover feed: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return [] 
        }
    }
    
    // MARK: - Campus Events
    
    func fetchCampusEvents() async -> [CampusItem] {
        if isInDemoMode {
            Log.data.info("Demo Mode: returning mock campus items")
            return mockCampusItems()
        }
        
        do {
            let items = try await apiClient.fetchCampusEvents()
            Log.data.info("Fetched \(items.count) campus items from backend")
            return items
        } catch {
            Log.data.error("Failed to fetch campus events: \(error.localizedDescription)")
            lastError = error.localizedDescription
            return [] // Return empty list instead of mocks
        }
    }
    
    // MARK: - Community Events
    
    func fetchCommunityEvents() async -> [CommunityEvent] {
        if isInDemoMode {
            return mockCommunityEvents()
        }
        
        do {
            let events = try await apiClient.fetchCommunityEvents()
            if events.isEmpty {
                return mockCommunityEvents()
            }
            return events
        } catch {
            Log.data.error("Failed to fetch community events: \(error)")
            return mockCommunityEvents()
        }
    }
    
    // MARK: - Mock Data
    
    private func mockCourses() -> [Course] {
        [
            Course(
                id: "mock-1",
                title: "SwiftUI Masterclass",
                description: "Build beautiful iOS apps with SwiftUI",
                shortDescription: "iOS development",
                instructorId: 1,
                difficultyLevel: "intermediate",
                category: "Programming",
                tags: ["iOS", "SwiftUI", "Mobile"],
                thumbnailURL: nil,
                isPublished: true,
                isFeatured: true,
                lessonCount: 12,
                enrollmentCount: 150,
                estimatedDurationHours: 8,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "mock-2",
                title: "Python for Data Science",
                description: "Learn Python programming for data analysis",
                shortDescription: "Data science basics",
                instructorId: 1,
                difficultyLevel: "beginner",
                category: "Data Science",
                tags: ["Python", "Data Science"],
                thumbnailURL: nil,
                isPublished: true,
                isFeatured: false,
                lessonCount: 10,
                enrollmentCount: 200,
                estimatedDurationHours: 6,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "mock-3",
                title: "Advanced Machine Learning",
                description: "Deep dive into neural networks and AI",
                shortDescription: "Advanced ML",
                instructorId: 1,
                difficultyLevel: "advanced",
                category: "Data Science",
                tags: ["ML", "AI", "Deep Learning"],
                thumbnailURL: nil,
                isPublished: true,
                isFeatured: true,
                lessonCount: 15,
                enrollmentCount: 75,
                estimatedDurationHours: 10,
                createdAt: Date(),
                updatedAt: Date()
            ),
            Course(
                id: "mock-4",
                title: "Web Development Bootcamp",
                description: "Full-stack web development from scratch",
                shortDescription: "Web dev basics",
                instructorId: 1,
                difficultyLevel: "beginner",
                category: "Web Development",
                tags: ["Web", "JavaScript", "React"],
                thumbnailURL: nil,
                isPublished: true,
                isFeatured: false,
                lessonCount: 20,
                enrollmentCount: 300,
                estimatedDurationHours: 12,
                createdAt: Date(),
                updatedAt: Date()
            )
        ]
    }
    
    private func mockDiscoverItems() -> [DiscoverItem] {
        [
            DiscoverItem(
                id: "d1",
                type: .courseSuggestion,
                title: "SwiftUI Animations",
                subtitle: "Create stunning animations in your iOS apps",
                tag: "Popular",
                estimatedMinutes: 5,
                aiInsight: "This matches your goal to learn iOS Development.",
                subject: "Mobile Dev",
                level: .intermediate,
                xpReward: 15,
                keyPoints: ["Implicit vs Explicit Animations", "Using withAnimation", "Transitions"],
                linkedGoalId: "goal-ios",
                quizMoments: [
                    QuizMoment(timestamp: 5, question: "Which modifier encloses a state change to animate it?", options: ["withAnimation", "animate()", "transition"], correctIndex: 0, explanation: "withAnimation { } tells SwiftUI to animate any changes that happen inside the closure.")
                ],
                isLiked: true,
                likeCount: 1240,
                viewCount: 5600,
                shareCount: 45,
                authorName: "Sarah Code",
                authorAvatarURL: nil
            ),
            DiscoverItem(
                id: "d2",
                type: .videoSnippet,
                title: "Understanding Async/Await",
                subtitle: "Modern concurrency in Swift explained simply",
                tag: "Trending",
                estimatedMinutes: 3,
                videoURL: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4"),
                subject: "Swift",
                level: .beginner,
                xpReward: 20,
                keyPoints: ["Async functions suspend", "Await marks suspension points", "Structured Concurrency"],
                quizMoments: [
                    QuizMoment(timestamp: 10, question: "What happens when access is awaited?", options: ["Thread blocks", "Execution suspends", "App crashes"], correctIndex: 1, explanation: "Await allows the function to suspend execution, freeing the thread to do other work.")
                ],
                likeCount: 8900,
                viewCount: 45000,
                shareCount: 1200,
                authorName: "Swift Ninja",
                authorAvatarURL: nil
            ),
            DiscoverItem(
                id: "d3",
                type: .eventSuggestion,
                title: "Live Coding Session",
                subtitle: "Build a complete app in 1 hour",
                tag: "Live",
                estimatedMinutes: 60,
                subject: "Community",
                level: .advanced,
                xpReward: 50,
                keyPoints: ["Real-time problem solving", "Architecture decisions", "Q&A with Instructor"],
                relatedGroupId: "iOS-Study-Group-NYC",
                likeCount: 340,
                viewCount: 1200,
                shareCount: 12,
                authorName: "Dev Community",
                authorAvatarURL: nil
            ),
            DiscoverItem(
                id: "d4",
                type: .pathSuggestion,
                title: "Meet Sarah - iOS Expert",
                subtitle: "10 years of Apple development experience",
                tag: "Featured",
                estimatedMinutes: 2,
                subject: "Career",
                level: .beginner,
                xpReward: 5,
                keyPoints: ["Career Trajectory", "Key Skills Needed", "Day in the Life"],
                isLiked: true,
                likeCount: 45,
                viewCount: 150,
                shareCount: 2,
                authorName: "Career Coach",
                authorAvatarURL: nil
            ),
            DiscoverItem(
                id: "d5",
                type: .courseSuggestion,
                title: "Combine Framework Deep Dive",
                subtitle: "Master reactive programming in Swift",
                tag: "Advanced",
                estimatedMinutes: 15,
                subject: "Reactive",
                level: .advanced,
                xpReward: 30,
                keyPoints: ["Publishers & Subscribers", "Operators", "Memory Management"],
                likeCount: 89,
                viewCount: 400,
                shareCount: 5,
                authorName: "Reactive Pro",
                authorAvatarURL: nil
            )
        ]
    }
    
    private func mockCampusItems() -> [CampusItem] {
        let calendar = Calendar.current
        let now = Date()
        
        return [
            CampusItem(
                id: "c1",
                type: .studyGroup,
                title: "SwiftUI Study Circle",
                subtitle: "Weekly meetup for SwiftUI enthusiasts",
                locationName: "Virtual Room A",
                coordinate: CampusCoordinate(latitude: 37.7749, longitude: -122.4194),
                startTime: calendar.date(byAdding: .hour, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                roomId: "virtual-a",
                hostName: "Alex Chen",
                hostAvatarURL: nil,
                attendeeCount: 8,
                maxAttendees: 12,
                tags: ["SwiftUI", "iOS"]
            ),
            CampusItem(
                id: "c2",
                type: .workshop,
                title: "Live: Building APIs with FastAPI",
                subtitle: "Hands-on backend development",
                locationName: "Stream Room 1",
                coordinate: CampusCoordinate(latitude: 37.7751, longitude: -122.4180),
                startTime: now,
                endTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                roomId: "stream-1",
                hostName: "Maria Santos",
                hostAvatarURL: nil,
                attendeeCount: 45,
                maxAttendees: 100,
                tags: ["Python", "Backend"]
            ),
            CampusItem(
                id: "c3",
                type: .studyGroup,
                title: "Hackathon Prep Team",
                subtitle: "Preparing for the upcoming hackathon",
                locationName: "Collab Space",
                coordinate: CampusCoordinate(latitude: 37.7755, longitude: -122.4170),
                startTime: calendar.date(byAdding: .hour, value: 2, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 4, to: now) ?? now,
                roomId: "collab-1",
                hostName: "Dev Squad",
                hostAvatarURL: nil,
                attendeeCount: 4,
                maxAttendees: 6,
                tags: ["Hackathon", "Team"]
            ),
            CampusItem(
                id: "c4",
                type: .workshop,
                title: "Ask Me Anything: Career in Tech",
                subtitle: "Tips for breaking into the industry",
                locationName: "Main Hall",
                coordinate: CampusCoordinate(latitude: 37.7760, longitude: -122.4160),
                startTime: calendar.date(byAdding: .day, value: 1, to: now) ?? now,
                endTime: calendar.date(byAdding: .hour, value: 26, to: now) ?? now,
                roomId: "main-hall",
                hostName: "Senior Dev Panel",
                hostAvatarURL: nil,
                attendeeCount: 156,
                maxAttendees: 500,
                tags: ["Career", "Advice"]
            )
        ]
    }
    
    private func mockCommunityEvents() -> [CommunityEvent] {
        [
            CommunityEvent(
                id: 1,
                title: "iOS Study Group",
                description: "Weekly iOS development meetup",
                eventType: "study_group",
                startTime: Date().addingTimeInterval(3600),
                endTime: Date().addingTimeInterval(7200),
                location: "Virtual",
                organizerId: 1,
                hostName: "Alex Chen",
                attendeeCount: 12,
                maxAttendees: 20,
                isOnline: true,
                imageUrl: nil,
                organizerProfile: nil
            ),
            CommunityEvent(
                id: 2,
                title: "Algorithm Challenge",
                description: "Solve coding problems together",
                eventType: "workshop",
                startTime: Date().addingTimeInterval(86400),
                endTime: Date().addingTimeInterval(90000),
                location: "Online",
                organizerId: 2,
                hostName: "Maria Santos",
                attendeeCount: 8,
                maxAttendees: 15,
                isOnline: true,
                imageUrl: nil,
                organizerProfile: nil
            )
        ]
    }
}
