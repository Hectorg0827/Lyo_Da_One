import Foundation
import SwiftUI
import Combine
import CoreLocation
import os

// MARK: - Campus ViewModel

@MainActor
class CampusViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var items: [CampusItem] = []
    @Published var searchQuery: String = ""
    @Published var selectedMode: CampusViewMode = .map
    @Published var selectedTypeFilter: CampusItemType?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Map region (SF Bay Area default)
    @Published var mapCenterLatitude: Double = 37.7749
    @Published var mapCenterLongitude: Double = -122.4194
    
    // MARK: - Library Content
    @Published var featuredContent: [ContentItem] = []
    @Published var quickWins: [ContentItem] = [] // Micro-lessons
    @Published var learningPaths: [ContentItem] = [] // Paths
    @Published var trendingContent: [ContentItem] = [] // Mini-courses
    @Published var allContent: [ContentItem] = []
    
    // MARK: - Dependencies
    private let contentRepository = DefaultContentRepository()
    
    // MARK: - Private Properties
    
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Local filtering based on search query and type filter
    var filteredItems: [CampusItem] {
        var result = items
        
        // Filter by type if selected
        if let typeFilter = selectedTypeFilter {
            result = result.filter { $0.type == typeFilter }
        }
        
        // Filter by search query (local, no AI)
        if !searchQuery.isEmpty {
            let query = searchQuery.lowercased()
            result = result.filter { item in
                item.title.lowercased().contains(query) ||
                item.subtitle.lowercased().contains(query) ||
                item.locationName.lowercased().contains(query) ||
                item.hostName.lowercased().contains(query) ||
                item.tags.contains { $0.lowercased().contains(query) }
            }
        }
        
        // Sort by start time (soonest first)
        return result.sorted { $0.startTime < $1.startTime }
    }
    
    /// Items that are currently live
    var liveItems: [CampusItem] {
        filteredItems.filter { $0.isLive }
    }
    
    /// Items happening today
    var todayItems: [CampusItem] {
        let calendar = Calendar.current
        return filteredItems.filter { calendar.isDateInToday($0.startTime) }
    }
    
    /// Items happening later (not today)
    var upcomingItems: [CampusItem] {
        let calendar = Calendar.current
        return filteredItems.filter { !calendar.isDateInToday($0.startTime) }
    }
    
    // MARK: - Initialization
    
    init() {
        Task {
            await loadEvents()
        }
    }
    
    // MARK: - Data Loading
    
    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        
        // Use DataService for unified data fetching
        items = await DataService.shared.fetchCampusEvents()
        
        if AuthService.shared.isDemoMode {
            Log.ui.info("CampusViewModel: Loaded \(self.items.count) events (Demo Mode)")
        } else {
            Log.ui.info("CampusViewModel: Loaded \(self.items.count) events from backend")
        }
        
        isLoading = false
        
        // Load library content
        await loadLibraryData()
    }
    
    func loadLibraryData() async {
        do {
            // Featured: Anchor Courses
            featuredContent = try await contentRepository.getFeaturedContent()
            
            // Quick Wins: Micro-lessons
            quickWins = try await contentRepository.getQuickWins()
            
            // Learning Paths
            learningPaths = try await contentRepository.getLearningPaths()
            
            // Trending: Mini-courses
            trendingContent = try await contentRepository.getTrendingMiniCourses()
            
            // All content flattened
            allContent = try await contentRepository.getAllContent()
        } catch {
            Log.ui.error("Error loading library data: \(error)")
            // Optionally set errorMessage state here
        }
    }
    
    func refresh() async {
        await loadEvents()
    }
    
    // MARK: - Actions
    
    /// Save a campus item to the user's Stack
    func saveToStack(item: CampusItem) {
        HapticManager.shared.success()
        
        if let roomId = item.roomId {
            // Save as collab room
            UIStackStore.shared.upsertCollab(
                roomId: roomId,
                title: item.title,
                subtitle: item.locationName
            )
        } else {
            // Save as generic chat context
            UIStackStore.shared.upsertChat(
                key: "campus-\(item.id)",
                title: item.title,
                subtitle: "\(item.type.displayName) at \(item.locationName)"
            )
        }
    }
    
    /// Join a collab room and navigate
    func joinCollabRoom(item: CampusItem, uiState: AppUIState) {
        HapticManager.shared.medium()
        
        // Save to stack
        saveToStack(item: item)
        
        // Handle different item types appropriately
        switch item.type {
        case .studyGroup:
            // Study groups are learning-focused, navigate to collab for the room
            if let roomId = item.roomId {
                uiState.currentCollabRoomId = roomId
                uiState.currentTab = .collab
            }
            
        case .event, .workshop, .meetup, .office:
            // For events with rooms, join the collab room
            if let roomId = item.roomId {
                uiState.currentCollabRoomId = roomId
                uiState.currentTab = .collab
            }
        }
    }
    
    /// Build context string for Lio chat
    func buildLioContext(for item: CampusItem) -> String {
        var context = "The user is interested in: \(item.title)"
        context += "\nType: \(item.type.displayName)"
        context += "\nLocation: \(item.locationName)"
        context += "\nTime: \(item.formattedDate) \(item.formattedTime)"
        context += "\nHost: \(item.hostName)"
        
        if !item.tags.isEmpty {
            context += "\nTopics: \(item.tags.joined(separator: ", "))"
        }
        
        if item.isLive {
            context += "\n[This event is currently LIVE]"
        }
        
        if let spots = item.spotsRemaining {
            context += "\nSpots remaining: \(spots)"
        }
        
        return context
    }
    
    // MARK: - Filter Helpers
    
    func toggleTypeFilter(_ type: CampusItemType) {
        if selectedTypeFilter == type {
            selectedTypeFilter = nil
        } else {
            selectedTypeFilter = type
        }
    }
    
    func clearFilters() {
        searchQuery = ""
        selectedTypeFilter = nil
    }
}
