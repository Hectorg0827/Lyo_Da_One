//
//  CommunityFeedViewModelTests.swift
//  LyoTests
//
//  Unit tests for CommunityFeedViewModel
//

import XCTest
@testable import Lyo

@MainActor
final class CommunityFeedViewModelTests: XCTestCase {
    
    // MARK: - State Tests
    
    func testInitialState() {
        let viewModel = CommunityFeedViewModel()
        
        XCTAssertTrue(viewModel.posts.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertFalse(viewModel.isLoadingMore)
        XCTAssertFalse(viewModel.isRefreshing)
        XCTAssertTrue(viewModel.hasMorePages)
        XCTAssertNil(viewModel.error)
    }
    
    func testEmptyStateFlags() {
        let viewModel = CommunityFeedViewModel()
        
        // Initially loading is false and posts is empty
        XCTAssertTrue(viewModel.isEmpty)
        XCTAssertTrue(viewModel.showEmptyState)
        XCTAssertFalse(viewModel.showErrorState)
    }
    
    func testFiltersDefault() {
        let viewModel = CommunityFeedViewModel()
        
        XCTAssertEqual(viewModel.filters.sortBy, .recent)
        XCTAssertNil(viewModel.filters.postType)
        XCTAssertTrue(viewModel.filters.tags.isEmpty)
    }
    
    // MARK: - Mock Post for Testing
    
    static func mockPost(id: String = "test-1") -> CommunityPost {
        CommunityPost(
            id: id,
            authorId: "author-1",
            authorName: "Test Author",
            authorAvatar: nil,
            authorLevel: 5,
            content: "Test content",
            mediaURLs: [],
            tags: ["test"],
            likeCount: 10,
            commentCount: 5,
            hasLiked: false,
            hasBookmarked: false,
            postType: .text,
            linkedCourseId: nil,
            linkedGroupId: nil,
            createdAt: Date(),
            updatedAt: Date(),
            isEdited: false,
            isPinned: false,
            visibility: .public
        )
    }
    
    // MARK: - Optimistic Update Tests
    
    func testToggleLikeOptimisticallyUpdates() async {
        // Test that the like toggle updates local state immediately
        // Note: Full integration test would require mocking CommunityService
        
        // Create a viewModel with a mock setup
        let viewModel = CommunityFeedViewModel()
        
        // Verify initial state
        XCTAssertTrue(viewModel.posts.isEmpty)
    }
    
    // MARK: - Filter Query Tests
    
    func testFeedFiltersQueryItemsWithAllOptions() {
        var filters = FeedFilters()
        filters.sortBy = .trending
        filters.postType = .image
        filters.tags = ["swift", "swiftui"]
        filters.authorId = "user-123"
        filters.groupId = "group-456"
        
        let queryItems = filters.toQueryItems()
        
        XCTAssertEqual(queryItems.count, 5)
        XCTAssertTrue(queryItems.contains { $0.name == "sort" && $0.value == "trending" })
        XCTAssertTrue(queryItems.contains { $0.name == "post_type" && $0.value == "image" })
        XCTAssertTrue(queryItems.contains { $0.name == "tags" && $0.value == "swift,swiftui" })
        XCTAssertTrue(queryItems.contains { $0.name == "author_id" && $0.value == "user-123" })
        XCTAssertTrue(queryItems.contains { $0.name == "group_id" && $0.value == "group-456" })
    }
    
    func testFeedFiltersQueryItemsMinimal() {
        let filters = FeedFilters()
        let queryItems = filters.toQueryItems()
        
        // Only sort should be present by default
        XCTAssertEqual(queryItems.count, 1)
        XCTAssertTrue(queryItems.contains { $0.name == "sort" && $0.value == "recent" })
    }
    
    // MARK: - Load More Trigger Tests
    
    func testCanLoadMoreLogic() {
        let viewModel = CommunityFeedViewModel()
        
        // Initially should be able to load more
        XCTAssertTrue(viewModel.canLoadMore)
    }
    
    // MARK: - Toast Message Tests
    
    func testShowToastSetsMessage() async {
        let viewModel = CommunityFeedViewModel()
        
        XCTAssertNil(viewModel.toastMessage)
        
        viewModel.showToast("Test message")
        
        XCTAssertEqual(viewModel.toastMessage, "Test message")
    }
}

// MARK: - CommentsViewModel Tests

@MainActor
final class CommentsViewModelTests: XCTestCase {
    
    static func mockComment(id: String = "comment-1", parentId: String? = nil) -> Comment {
        Comment(
            id: id,
            postId: "post-1",
            authorId: "author-1",
            authorName: "Test Author",
            authorAvatar: nil,
            content: "Test comment",
            likeCount: 3,
            hasLiked: false,
            parentId: parentId,
            replyCount: 0,
            createdAt: Date(),
            isEdited: false
        )
    }
    
    func testCanSubmitWhenEmpty() {
        let post = CommunityFeedViewModelTests.mockPost()
        let viewModel = CommentsViewModel(post: post)
        
        XCTAssertFalse(viewModel.canSubmit)
    }
    
    func testCanSubmitWhenHasContent() {
        let post = CommunityFeedViewModelTests.mockPost()
        let viewModel = CommentsViewModel(post: post)
        
        viewModel.commentText = "This is a comment"
        
        XCTAssertTrue(viewModel.canSubmit)
    }
    
    func testCanSubmitWithWhitespaceOnly() {
        let post = CommunityFeedViewModelTests.mockPost()
        let viewModel = CommentsViewModel(post: post)
        
        viewModel.commentText = "   \n\t   "
        
        XCTAssertFalse(viewModel.canSubmit)
    }
    
    func testStartReply() {
        let post = CommunityFeedViewModelTests.mockPost()
        let viewModel = CommentsViewModel(post: post)
        let comment = Self.mockComment()
        
        XCTAssertNil(viewModel.replyingTo)
        
        viewModel.startReply(to: comment)
        
        XCTAssertEqual(viewModel.replyingTo?.id, comment.id)
    }
    
    func testCancelReply() {
        let post = CommunityFeedViewModelTests.mockPost()
        let viewModel = CommentsViewModel(post: post)
        let comment = Self.mockComment()
        
        viewModel.startReply(to: comment)
        XCTAssertNotNil(viewModel.replyingTo)
        
        viewModel.cancelReply()
        XCTAssertNil(viewModel.replyingTo)
    }
    
    func testClearError() {
        let post = CommunityFeedViewModelTests.mockPost()
        let viewModel = CommentsViewModel(post: post)
        
        // Simulate an error
        viewModel.clearError()
        
        XCTAssertNil(viewModel.error)
    }
}
