//
//  CourseLibraryService.swift
//  Lyo
//
//  Unified course library management service
//

import Foundation
import SwiftUI

// MARK: - Course Library Service

@MainActor
final class CourseLibraryService: ObservableObject {
    
    static let shared = CourseLibraryService()
    
    // MARK: - Published State
    
    @Published var inProgressCourses: [CourseCard] = []
    @Published var completedCourses: [CourseCard] = []
    @Published var savedCourses: [CourseCard] = []
    @Published var trendingCourses: [CourseCard] = []
    @Published var recommendedCourses: [CourseCard] = []
    @Published var allCourses: [CourseCard] = []
    
    @Published var isLoading: Bool = false
    @Published var error: String?
    
    // MARK: - Filters
    
    @Published var searchQuery: String = ""
    @Published var selectedTags: Set<String> = []
    @Published var selectedLevel: CourseLevel?
    
    // MARK: - Dependencies
    
    private let repository = LyoRepository.shared
    private let stackStore = UIStackStore.shared
    private let socialService = CourseSocialService.shared
    
    private init() {}
    
    // MARK: - Fetch Methods
    
    /// Fetch all user's courses
    func fetchMyCourses() async {
        isLoading = true
        error = nil
        
        do {
            // Fetch from backend
            let courses = try await repository.getChatCourses()
            
            // Fetch social stats for all courses
            let courseIds = courses.map { $0.id }
            _ = try? await socialService.fetchBulkSocialStats(courseIds: courseIds)
            
            // Convert to CourseCard format
            allCourses = courses.map { convertToCard($0) }
            
            // Categorize courses
            categorizeCourses()
            
            print("✅ Fetched \(allCourses.count) courses")
            
        } catch {
            self.error = error.localizedDescription
            print("❌ Failed to fetch courses: \(error)")
        }
        
        isLoading = false
    }
    
    /// Fetch trending courses
    func fetchTrendingCourses() async {
        do {
            let courses = try await repository.getChatCourses(limit: 20)
            
            // Fetch social stats
            let courseIds = courses.map { $0.id }
            _ = try? await socialService.fetchBulkSocialStats(courseIds: courseIds)
            
            // Sort by popularity (likes + ratings)
            var cards = courses.map { convertToCard($0) }
            cards.sort { course1, course2 in
                let score1 = Double(socialService.getLikeCount(courseId: course1.id)) + 
                            (socialService.getAverageRating(courseId: course1.id) * 10)
                let score2 = Double(socialService.getLikeCount(courseId: course2.id)) + 
                            (socialService.getAverageRating(courseId: course2.id) * 10)
                return score1 > score2
            }
            
            trendingCourses = Array(cards.prefix(10))
            
        } catch {
            print("❌ Failed to fetch trending: \(error)")
        }
    }
    
    /// Get recommended courses based on user history
    func fetchRecommendations() async {
        // TODO: Implement ML-based recommendations
        // For now, return courses the user hasn't started
        recommendedCourses = allCourses.filter { course in
            !inProgressCourses.contains(where: { $0.id == course.id }) &&
            !completedCourses.contains(where: { $0.id == course.id })
        }
    }
    
    // MARK: - Search & Filter
    
    func search(query: String) async {
        guard !query.isEmpty else {
            categorizeCourses()
            return
        }
        
        searchQuery = query
        
        do {
            let results = try await repository.getChatCourses(topic: query, limit: 50)
            allCourses = results.map { convertToCard($0) }
            categorizeCourses()
        } catch {
            print("❌ Search failed: \(error)")
        }
    }
    
    func applyFilters() {
        var filtered = allCourses
        
        // Filter by level (CourseCard doesn't have level, skip this filter for now)
        // TODO: Add level property to CourseCard if needed
        
        // Filter by tags
        if !selectedTags.isEmpty {
            filtered = filtered.filter { course in
                guard let tags = course.tags else { return false }
                return !Set(tags).isDisjoint(with: selectedTags)
            }
        }
        
        // Re-categorize with filtered results
        categorizeCourses(from: filtered)
    }
    
    // MARK: - Course Management
    
    func saveCourse(courseId: String) async {
        // Add to saved courses
        if let course = allCourses.first(where: { $0.id == courseId }) {
            if !savedCourses.contains(where: { $0.id == courseId }) {
                savedCourses.append(course)
            }
        }
        
        // Save to backend (via stack)
        _ = try? await repository.createStackItem(request: CreateStackItemRequest(
            type: .course,
            refId: courseId,
            tags: ["saved"],
            contextData: ["courseId": courseId]
        ))
    }
    
    func unsaveCourse(courseId: String) {
        savedCourses.removeAll { $0.id == courseId }
    }
    
    func markCourseCompleted(courseId: String) async {
        // Move from in-progress to completed
        if let index = inProgressCourses.firstIndex(where: { $0.id == courseId }) {
            let course = inProgressCourses.remove(at: index)
            if !completedCourses.contains(where: { $0.id == courseId }) {
                completedCourses.append(course)
            }
        }
        
        // Update backend
        // TODO: Add completion endpoint to backend
    }
    
    // MARK: - Helpers
    
    private func categorizeCourses(from courses: [CourseCard]? = nil) {
        let source = courses ?? allCourses
        
        // Get stack items to determine progress
        let stackItems = stackStore.items
        let courseStackItems = stackItems.filter { $0.type == .course }
        
        // Helper to check if a course matches a stack item
        func matchesCourse(_ item: UIStackItem, courseId: String) -> Bool {
            return item.courseId == courseId
        }
        
        // Categorize courses based on progress
        inProgressCourses = source.filter { course in
            courseStackItems.contains(where: { item in
                matchesCourse(item, courseId: course.id) && 
                (item.progress ?? 0) > 0 && 
                (item.progress ?? 0) < 1.0
            })
        }
        
        completedCourses = source.filter { course in
            courseStackItems.contains(where: { item in
                matchesCourse(item, courseId: course.id) && 
                (item.progress ?? 0) >= 1.0
            })
        }
        
        savedCourses = source.filter { course in
            let isInStack = courseStackItems.contains(where: { matchesCourse($0, courseId: course.id) })
            let notInProgress = !inProgressCourses.contains(where: { $0.id == course.id })
            let notCompleted = !completedCourses.contains(where: { $0.id == course.id })
            return isInStack && notInProgress && notCompleted
        }
    }
    
    private func convertToCard(_ course: ChatCourseRead) -> CourseCard {
        CourseCard(
            id: course.id,
            title: course.title,
            description: course.description,
            coverURL: nil,
            progress: nil,
            timeLeft: nil,
            lastOpened: nil,
            tags: course.learningObjectives,
            status: .suggested
        )
    }
}

// MARK: - Course Level Enum

enum CourseLevel: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"
}

// Note: CourseCard is defined in Models/LyoChat.swift
