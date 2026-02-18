import Foundation
import Combine
import os

// MARK: - Discover ViewModel

@MainActor
final class DiscoverViewModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var items: [DiscoverItem] = []
    @Published var searchQuery: String = ""
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    
    // UI State for Context Sheet
    @Published var showVideoContextSheet: Bool = false
    @Published var selectedContextItem: DiscoverItem?
    @Published var selectedItemForComments: DiscoverItem? // For CommentsSheet
    
    // MARK: - Dependencies
    
    private let stackStore: UIStackStore
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    var filteredItems: [DiscoverItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return items }
        
        return items.filter { item in
            let haystack = (item.title + " " + (item.subtitle ?? "") + " " + (item.tag ?? "")).lowercased()
            return haystack.contains(query.lowercased())
        }
    }
    
    // MARK: - Init
    
    init(stackStore: UIStackStore = .shared) {
        self.stackStore = stackStore
        Task {
            await loadItems()
        }
    }
    
    // MARK: - Public Methods
    
    /// Save a discover item to the user's stack
    func saveToStack(item: DiscoverItem) {
        HapticManager.shared.success()
        
        switch item.type {
        case .courseSuggestion, .videoSnippet, .userClip:
            if let courseId = item.courseId {
                stackStore.upsertCourse(
                    courseId: courseId,
                    title: item.title,
                    subtitle: item.subtitle,
                    progress: 0.0
                )
            } else {
                stackStore.upsertChat(
                    key: "discover-\(item.id)",
                    title: "Discover: \(item.title)",
                    subtitle: item.subtitle
                )
            }
            
        case .pathSuggestion, .eventSuggestion:
            stackStore.upsertChat(
                key: "discover-\(item.id)",
                title: "Path: \(item.title)",
                subtitle: item.subtitle
            )
        }
    }
    
    /// Open comments for an item
    func commentsAction(item: DiscoverItem) {
        selectedItemForComments = item
    }
    
    /// Toggle like status for an item
    func toggleLike(for item: DiscoverItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        HapticManager.shared.light()
        
        // Optimistic update
        var updatedItem = items[index]
        updatedItem.isLiked.toggle()
        
        if updatedItem.isLiked {
            updatedItem.likeCount += 1
        } else {
            updatedItem.likeCount = max(0, updatedItem.likeCount - 1)
        }
        
        items[index] = updatedItem
        
        // Fire and forget backend request
        Task { 
            do {
                if updatedItem.isLiked {
                    try await DiscoveryService.shared.likeDiscovery(discoveryId: item.id)
                } else {
                    try await DiscoveryService.shared.unlikeDiscovery(discoveryId: item.id)
                }
            } catch {
                print("Failed to toggle like: \(error)")
                // Revert
                await MainActor.run {
                    if let revertIndex = items.firstIndex(where: { $0.id == item.id }) {
                        items[revertIndex].isLiked.toggle()
                        // Re-adjust count? Maybe complex if user spammed. Just toggle back.
                        if items[revertIndex].isLiked { items[revertIndex].likeCount += 1 }
                        else { items[revertIndex].likeCount = max(0, items[revertIndex].likeCount - 1) }
                    }
                }
            }
        }
    }
    
    /// Toggle save status for an item
    func toggleSave(for item: DiscoverItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        
        HapticManager.shared.medium()
        
        // Optimistic update
        var updatedItem = items[index]
        updatedItem.isSaved.toggle()
        items[index] = updatedItem
        
        Task {
            do {
                if updatedItem.isSaved {
                    try await DiscoveryService.shared.saveDiscovery(discoveryId: item.id)
                } else {
                    try await DiscoveryService.shared.unsaveDiscovery(discoveryId: item.id)
                }
            } catch {
                // Revert on failure
                await MainActor.run {
                    if let revertIndex = items.firstIndex(where: { $0.id == item.id }) {
                        items[revertIndex].isSaved.toggle()
                    }
                }
            }
        }
    }
    
    /// Build context string for asking Lio about an item
    func buildLioContext(for item: DiscoverItem) -> String {
        var context = "User is viewing a \(item.type.displayName) titled '\(item.title)'."
        if let subtitle = item.subtitle {
            context += " Context: \(subtitle)."
        }
        if let tag = item.tag {
            context += " Topic: \(tag)."
        }
        if let insight = item.aiInsight {
            context += " AI Insight: \(insight)."
        }
        
        // Add specific learning context
        context += "\nLearning Level: \(item.level.rawValue)."
        if !item.keyPoints.isEmpty {
            context += "\nKey Points: \(item.keyPoints.joined(separator: ", "))."
        }
        
        context += "\n\nYour goal: The user is interested in this content. Answer questions specifically about the video transcript or key points."
        
        return context
    }
    
    /// Trigger generation of a mini-course from this reel
    func convertToCourse(item: DiscoverItem) {
        HapticManager.shared.success()
        Log.ui.info("Generating mini-course for: \(item.title)")
        
        Task {
            do {
                let topic = item.topic ?? item.title
                let level = item.level.rawValue
                _ = try await CourseGenerationService.shared.generateCourse(
                    topic: topic,
                    level: level,
                    outcomes: item.keyPoints.isEmpty ? nil : item.keyPoints
                )
                Log.ui.info("Mini-course generated for: \(item.title)")
            } catch {
                Log.ui.warning("Failed to generate mini-course: \(error.localizedDescription)")
                await MainActor.run {
                    errorMessage = "Failed to generate course: \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// Load items from backend or demo data
    func loadItems() async {
        isLoading = true
        errorMessage = nil
        
        // Use DataService for unified data fetching
        // Note: DataService internally handles some fallbacks, but we should be aware of the auth state
        self.items = await DataService.shared.fetchDiscoverFeed()
        
        if AuthService.shared.isDemoMode {
            Log.ui.info("DiscoverViewModel: Loaded \(self.items.count) items (Demo Mode)")
        } else {
            if self.items.isEmpty {
                 Log.ui.warning("DiscoverViewModel: Loaded 0 items from backend. This might indicate an issue if not expected.")
            } else {
                Log.ui.info("DiscoverViewModel: Loaded \\(self.items.count) items from backend")
            }
        }
        
        isLoading = false
    }
    
    /// Refresh items from backend
    func refresh() async {
        await loadItems()
    }
}
