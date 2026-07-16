//
//  CommunityServiceTests.swift
//  LyoTests
//
//  Unit tests for CommunityService
//

import XCTest
@testable import Lyo

final class CommunityServiceTests: XCTestCase {
    
    // MARK: - Model Tests
    
    func testCommunityPostDecoding() throws {
        let json = """
        {
            "id": "post-123",
            "author_id": "user-456",
            "author_name": "John Doe",
            "author_avatar": "https://example.com/avatar.jpg",
            "author_level": 5,
            "content": "Hello, community!",
            "media_urls": ["https://example.com/image1.jpg"],
            "tags": ["swift", "ios"],
            "like_count": 42,
            "comment_count": 10,
            "has_liked": true,
            "has_bookmarked": false,
            "post_type": "text",
            "linked_course_id": null,
            "linked_group_id": null,
            "created_at": "2026-01-15T10:30:00Z",
            "updated_at": "2026-01-15T10:30:00Z",
            "is_edited": false,
            "is_pinned": false,
            "visibility": "public"
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let post = try decoder.decode(CommunityPost.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(post.id, "post-123")
        XCTAssertEqual(post.authorId, "user-456")
        XCTAssertEqual(post.authorName, "John Doe")
        XCTAssertEqual(post.likeCount, 42)
        XCTAssertEqual(post.commentCount, 10)
        XCTAssertTrue(post.hasLiked)
        XCTAssertFalse(post.hasBookmarked)
        XCTAssertEqual(post.postType, .text)
        XCTAssertEqual(post.visibility, .public)
        XCTAssertEqual(post.tags, ["swift", "ios"])
        XCTAssertEqual(post.mediaURLs, ["https://example.com/image1.jpg"])
    }
    
    func testCommentDecoding() throws {
        let json = """
        {
            "id": "comment-789",
            "post_id": "post-123",
            "author_id": "user-456",
            "author_name": "Jane Smith",
            "author_avatar": null,
            "content": "Great post!",
            "like_count": 5,
            "has_liked": false,
            "parent_id": null,
            "reply_count": 2,
            "created_at": "2026-01-15T11:00:00Z",
            "is_edited": false
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let comment = try decoder.decode(Comment.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(comment.id, "comment-789")
        XCTAssertEqual(comment.postId, "post-123")
        XCTAssertEqual(comment.authorName, "Jane Smith")
        XCTAssertNil(comment.authorAvatar)
        XCTAssertEqual(comment.likeCount, 5)
        XCTAssertFalse(comment.hasLiked)
        XCTAssertNil(comment.parentId)
        XCTAssertEqual(comment.replyCount, 2)
    }
    
    func testPaginatedResponseDecoding() throws {
        let json = """
        {
            "items": [
                {
                    "id": "post-1",
                    "author_id": "user-1",
                    "author_name": "User One",
                    "author_avatar": null,
                    "author_level": 3,
                    "content": "First post",
                    "media_urls": [],
                    "tags": [],
                    "like_count": 10,
                    "comment_count": 2,
                    "has_liked": false,
                    "has_bookmarked": false,
                    "post_type": "text",
                    "linked_course_id": null,
                    "linked_group_id": null,
                    "created_at": "2026-01-15T10:00:00Z",
                    "updated_at": "2026-01-15T10:00:00Z",
                    "is_edited": false,
                    "is_pinned": false,
                    "visibility": "public"
                }
            ],
            "page": 1,
            "limit": 20,
            "total_count": 100,
            "total_pages": 5
        }
        """
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let response = try decoder.decode(PaginatedResponse<CommunityPost>.self, from: json.data(using: .utf8)!)
        
        XCTAssertEqual(response.items.count, 1)
        XCTAssertEqual(response.page, 1)
        XCTAssertEqual(response.limit, 20)
        XCTAssertEqual(response.totalCount, 100)
        XCTAssertEqual(response.totalPages, 5)
        XCTAssertTrue(response.hasNextPage)
        XCTAssertFalse(response.hasPreviousPage)
    }
    
    func testCreatePostRequestEncoding() throws {
        let request = CreatePostRequest(
            content: "Hello, world!",
            mediaURLs: ["https://example.com/image.jpg"],
            tags: ["test"],
            postType: .image,
            visibility: .public
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["content"] as? String, "Hello, world!")
        XCTAssertEqual(json["media_urls"] as? [String], ["https://example.com/image.jpg"])
        XCTAssertEqual(json["tags"] as? [String], ["test"])
        XCTAssertEqual(json["post_type"] as? String, "image")
        XCTAssertEqual(json["visibility"] as? String, "public")
    }
    
    func testReportRequestEncoding() throws {
        let request = ReportRequest(
            targetType: .post,
            targetId: "post-123",
            reason: .harassment,
            description: "This user is being rude"
        )
        
        let encoder = JSONEncoder()
        let data = try encoder.encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        
        XCTAssertEqual(json["target_type"] as? String, "post")
        XCTAssertEqual(json["target_id"] as? String, "post-123")
        XCTAssertEqual(json["reason"] as? String, "harassment")
        XCTAssertEqual(json["description"] as? String, "This user is being rude")
    }
    
    // MARK: - Filter Tests
    
    func testFeedFiltersQueryItems() {
        var filters = FeedFilters()
        filters.sortBy = .popular
        filters.tags = ["swift", "ios"]
        
        let items = filters.toQueryItems()
        
        XCTAssertTrue(items.contains(where: { $0.name == "sort" && $0.value == "popular" }))
        XCTAssertTrue(items.contains(where: { $0.name == "tags" && $0.value == "swift,ios" }))
    }
    
    // MARK: - Post Type Tests
    
    func testAllPostTypes() {
        let types: [PostType] = [.text, .image, .video, .poll, .achievement, .courseShare, .questionDiscussion, .studyTip]
        
        for type in types {
            XCTAssertNotNil(type.rawValue)
        }
    }
    
    func testAllReportReasons() {
        let reasons = ReportReason.allCases
        
        XCTAssertEqual(reasons.count, 9)
        
        for reason in reasons {
            XCTAssertFalse(reason.displayName.isEmpty)
        }
    }
    
    // MARK: - Date Extension Tests
    
    func testTimeAgoDisplayJustNow() {
        let date = Date()
        XCTAssertEqual(date.timeAgoDisplay(), "Just now")
    }
    
    func testTimeAgoDisplayMinutes() {
        let date = Date().addingTimeInterval(-60 * 5) // 5 minutes ago
        XCTAssertEqual(date.timeAgoDisplay(), "5 mins ago")
    }
    
    func testTimeAgoDisplayHours() {
        let date = Date().addingTimeInterval(-60 * 60 * 3) // 3 hours ago
        XCTAssertEqual(date.timeAgoDisplay(), "3 hours ago")
    }
    
    func testTimeAgoDisplayDays() {
        let date = Date().addingTimeInterval(-60 * 60 * 24 * 2) // 2 days ago
        XCTAssertEqual(date.timeAgoDisplay(), "2 days ago")
    }
}
