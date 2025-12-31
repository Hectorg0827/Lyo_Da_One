//
//  CourseSocialService.swift
//  Lyo
//
//  Social features for courses (rating, liking, commenting)
//

import Foundation
import Combine

// MARK: - Course Social Service

@MainActor
final class CourseSocialService: ObservableObject {
    static let shared = CourseSocialService()
    
    // Local cache of social interactions (synced to backend)
    @Published private(set) var courseLikes: [String: Int] = [:]  // courseId -> like count
    @Published private(set) var courseRatings: [String: Double] = [:]  // courseId -> average rating
    @Published private(set) var userLikedCourses: Set<String> = []  // courseIds user has liked
    @Published private(set) var userRatings: [String: Int] = [:]  // courseId -> user's rating (1-5)
    
    private let repository = LyoRepository.shared
    private let cacheKey = "lyo_course_social_cache"
    
    private init() {
        loadFromCache()
    }
    
    // MARK: - Like/Unlike
    
    /// Like a course
    func likeCourse(courseId: String) async throws {
        // Optimistic update
        userLikedCourses.insert(courseId)
        courseLikes[courseId] = (courseLikes[courseId] ?? 0) + 1
        saveToCache()
        
        // Backend sync
        do {
            let response = try await repository.likeCourse(courseId: courseId)
            courseLikes[courseId] = response.totalLikes
            saveToCache()
            print("✅ Liked course: \(courseId) (total: \(response.totalLikes))")
        } catch {
            // Rollback on error
            userLikedCourses.remove(courseId)
            courseLikes[courseId] = max(0, (courseLikes[courseId] ?? 1) - 1)
            saveToCache()
            throw error
        }
    }
    
    /// Unlike a course
    func unlikeCourse(courseId: String) async throws {
        // Optimistic update
        userLikedCourses.remove(courseId)
        courseLikes[courseId] = max(0, (courseLikes[courseId] ?? 1) - 1)
        saveToCache()
        
        // Backend sync
        do {
            try await repository.unlikeCourse(courseId: courseId)
            print("✅ Unliked course: \(courseId)")
        } catch {
            // Rollback on error
            userLikedCourses.insert(courseId)
            courseLikes[courseId] = (courseLikes[courseId] ?? 0) + 1
            saveToCache()
            throw error
        }
    }
    
    /// Toggle like status for a course
    func toggleLike(courseId: String) async throws {
        if userLikedCourses.contains(courseId) {
            try await unlikeCourse(courseId: courseId)
        } else {
            try await likeCourse(courseId: courseId)
        }
    }
    
    /// Check if user has liked a course
    func hasLiked(courseId: String) -> Bool {
        userLikedCourses.contains(courseId)
    }
    
    /// Get like count for a course
    func getLikeCount(courseId: String) -> Int {
        courseLikes[courseId] ?? 0
    }
    
    // MARK: - Rating
    
    /// Rate a course (1-5 stars)
    func rateCourse(courseId: String, rating: Int) async throws {
        guard (1...5).contains(rating) else {
            throw CourseSocialError.invalidRating
        }
        
        // Optimistic update
        let previousRating = userRatings[courseId]
        userRatings[courseId] = rating
        saveToCache()
        
        // Backend sync
        do {
            let response = try await repository.rateCourse(courseId: courseId, rating: rating)
            courseRatings[courseId] = response.averageRating
            saveToCache()
            
            print("✅ Rated course \(courseId): \(rating) stars (avg: \(response.averageRating))")
        } catch {
            // Rollback on error
            if let prev = previousRating {
                userRatings[courseId] = prev
            } else {
                userRatings.removeValue(forKey: courseId)
            }
            saveToCache()
            throw error
        }
    }
    
    /// Get user's rating for a course
    func getUserRating(courseId: String) -> Int? {
        userRatings[courseId]
    }
    
    /// Get average rating for a course
    func getAverageRating(courseId: String) -> Double {
        courseRatings[courseId] ?? 0.0
    }
    
    // MARK: - Fetch Social Stats
    
    /// Fetch social stats for a course from backend
    func fetchCourseSocialStats(courseId: String) async throws {
        let stats = try await repository.getCourseSocialStats(courseId: courseId)
        courseLikes[courseId] = stats.likes
        courseRatings[courseId] = stats.rating
        saveToCache()
    }
    
    /// Bulk fetch social stats for multiple courses
    func fetchBulkSocialStats(courseIds: [String]) async throws {
        let bulkStats = try await repository.getBulkCourseSocialStats(courseIds: courseIds)
        for (courseId, stats) in bulkStats {
            courseLikes[courseId] = stats.likes
            courseRatings[courseId] = stats.rating
        }
        saveToCache()
    }
    
    // MARK: - Cache Management
    
    private func saveToCache() {
        let cache = CourseSocialCache(
            likes: courseLikes,
            ratings: courseRatings,
            userLiked: userLikedCourses,
            userRatings: userRatings
        )
        
        if let encoded = try? JSONEncoder().encode(cache) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }
    
    private func loadFromCache() {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cache = try? JSONDecoder().decode(CourseSocialCache.self, from: data) else {
            return
        }
        
        courseLikes = cache.likes
        courseRatings = cache.ratings
        userLikedCourses = cache.userLiked
        userRatings = cache.userRatings
    }
    
    /// Clear all cached social data
    func clearCache() {
        courseLikes.removeAll()
        courseRatings.removeAll()
        userLikedCourses.removeAll()
        userRatings.removeAll()
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

// MARK: - Supporting Types

private struct CourseSocialCache: Codable {
    let likes: [String: Int]
    let ratings: [String: Double]
    let userLiked: Set<String>
    let userRatings: [String: Int]
}

enum CourseSocialError: LocalizedError {
    case invalidRating
    case notAuthenticated
    case networkError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidRating:
            return "Rating must be between 1 and 5 stars"
        case .notAuthenticated:
            return "Please sign in to rate or like courses"
        case .networkError(let message):
            return message
        }
    }
}

// MARK: - Backend API Extension (TODO)

extension LyoRepository {
    // TODO: Add these backend endpoints:
    
    // func likeCourse(courseId: String) async throws -> LikeResponse
    // func unlikeCourse(courseId: String) async throws
    // func rateCourse(courseId: String, rating: Int) async throws -> RatingResponse
    // func getCourseSocialStats(courseId: String) async throws -> CourseSocialStats
    // func getBulkCourseSocialStats(courseIds: [String]) async throws -> [String: CourseSocialStats]
}

// Response models (TODO: Add to Models/)
// struct LikeResponse: Codable { let totalLikes: Int }
// struct RatingResponse: Codable { let averageRating: Double, totalRatings: Int }
// struct CourseSocialStats: Codable { let likes: Int, rating: Double, ratingCount: Int }
