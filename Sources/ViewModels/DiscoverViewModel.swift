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
    @Published var isLoadingMore: Bool = false
    @Published var hasMore: Bool = false
    @Published var errorMessage: String?
    @Published var toastMessage: String?
    private var nextOffset = 0
    private var feedGeneration = 0
    private var toastTask: Task<Void, Never>?
    /// Loaded videos that left the feed since page 1 loaded, by a report or
    /// a block. Each one moves later server pages up a place.
    private var removedSinceLoad = 0
    /// Reported videos and blocked owners stay out of every page merged
    /// later, including one already on its way when they were removed.
    private var reportedIds: Set<String> = []
    private var blockedOwnerIds: Set<String> = []
    
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
    
    /// Prepare items for sharing (Text, Links, etc.)
    func prepareShareItems(for item: DiscoverItem) -> [Any] {
        // If it's linked to a course, share as a course
        if let courseId = item.courseId {
            return CourseShareService.shared.shareItems(
                courseId: courseId,
                title: item.title,
                description: item.subtitle
            )
        } else {
            // Generic fallback for non-course clips
            // In a real app, this would be a deep link to the clip itself
            let shareText = """
            Check out this clip on Lyo: "\(item.title)"
            
            \(item.subtitle ?? "")
            
            Download Lyo to watch: https://lyo.app
            """
            
            if let url = item.videoURL ?? item.thumbnailURL {
                 return [shareText, url]
            }
            return [shareText]
        }
    }
    
    /// Open comments for an item
    func commentsAction(item: DiscoverItem) {
        selectedItemForComments = item
    }

    /// A reported video leaves this learner's feed at once; the server also
    /// stops sending it to them.
    func removeReported(_ item: DiscoverItem, message: String) {
        reportedIds.insert(item.id)
        let before = items.count
        items.removeAll { $0.id == item.id }
        removedSinceLoad += before - items.count
        showToast(message)
        refillIfShort()
    }

    /// Every video by someone blocked leaves the feed at once.
    func removeVideos(by ownerId: String, message: String) {
        blockedOwnerIds.insert(ownerId)
        let before = items.count
        items.removeAll { $0.authorId == ownerId }
        removedSinceLoad += before - items.count
        showToast(message)
        refillIfShort()
    }

    private func isHidden(_ item: DiscoverItem) -> Bool {
        if let owner = item.authorId, blockedOwnerIds.contains(owner) { return true }
        return reportedIds.contains(item.id)
    }

    /// A block can empty most of what is loaded; fetch more rather than show
    /// "No results" while the server still has videos.
    private func refillIfShort() {
        guard hasMore, items.count < 5 else { return }
        Task { await loadMore() }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard let self, !Task.isCancelled else { return }
            self.toastMessage = nil
        }
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
    
    /// Clip → classroom: the clip is the hook, the classroom is the depth.
    /// Opens the Living Classroom on this topic immediately and drops a card
    /// in the Focus stack so the thread survives the session. (Previously this
    /// fired an invisible background generation job — the button appeared to
    /// do nothing.)
    func convertToCourse(item: DiscoverItem) {
        HapticManager.shared.success()
        let topic = item.topic ?? item.title
        Log.ui.info("Clip → classroom: \(topic)")

        UIStackStore.shared.upsertCourse(
            courseId: "GENERATE:\(topic)",
            title: topic,
            subtitle: "From a clip you watched"
        )

        NotificationCenter.default.post(
            name: .openClassroom,
            object: nil,
            userInfo: [
                "courseId": "gen_clip_\(item.id)",
                "topic": topic,
                "shouldGenerateCourse": true,
                "courseTitle": topic,
                "lessonTitle": "Deep dive",
            ]
        )
    }
    
    /// Load items from backend or demo data
    func loadItems() async {
        feedGeneration += 1
        let generation = feedGeneration
        isLoading = true
        isLoadingMore = false
        nextOffset = 0
        removedSinceLoad = 0
        hasMore = false
        errorMessage = nil
        
        // Use DataService for unified data fetching
        // Note: DataService internally handles some fallbacks, but we should be aware of the auth state
        let firstPage = await DataService.shared.fetchDiscoverFeed(limit: 20, offset: 0)
        guard generation == feedGeneration else { return }
        self.items = firstPage.filter { !isHidden($0) }
        nextOffset = 20
        hasMore = !AuthService.shared.isDemoMode && firstPage.count == 20

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
    
    /// Append the next batch before the current reel reaches the feed boundary.
    func loadMore() async {
        guard hasMore && !isLoading && !isLoadingMore else { return }
        isLoadingMore = true
        let generation = feedGeneration
        let page = nextOffset / 20 + 1
        var next: [DiscoverItem] = []
        var lastPageCount = 0
        // After reports or blocks, the page before is fetched too, so the
        // videos that moved onto it are not skipped.
        for number in DiscoverSafety.pagesToFetch(page: page, removed: removedSinceLoad, perPage: 20) {
            let batch = await DataService.shared.fetchDiscoverFeed(limit: 20, offset: (number - 1) * 20)
            next.append(contentsOf: batch)
            lastPageCount = batch.count
        }
        guard generation == feedGeneration else { return }
        var known = Set(items.map(\.id))
        for item in next where !known.contains(item.id) && !isHidden(item) {
            items.append(item)
            known.insert(item.id)
        }
        nextOffset += 20
        hasMore = lastPageCount == 20
        isLoadingMore = false
    }

    /// Refresh items from backend
    func refresh() async {
        await loadItems()
    }
}
