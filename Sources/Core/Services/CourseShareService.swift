//
//  CourseShareService.swift
//  Lyo
//
//  Service for sharing courses and deep linking
//

import UIKit
import SwiftUI

@MainActor
final class CourseShareService: ObservableObject {
    static let shared = CourseShareService()
    
    private init() {}
    
    /// Share a course with a standardized link and message
    /// - Parameters:
    ///   - courseId: The unique identifier of the course
    ///   - title: The title of the course
    ///   - description: Optional description of the course
    ///   - from: The view controller to present the share sheet from
    func shareCourse(courseId: String, title: String, description: String?, from viewController: UIViewController) {
        let deepLink = "lyoapp://course/\(courseId)"
        let shareText = """
        Check out this course on Lyo: "\(title)"
        
        \(description ?? "Join me and learn something new today!")
        
        Join here: \(deepLink)
        """
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
        
        print("📤 Sharing course: \(courseId)")
        
        // 🏆 Award XP for viral contribution
        Task {
            try? await LyoRepository.shared.awardXP(amount: 50, category: "viral")
            try? await LyoRepository.shared.awardContributorXP(courseId: courseId, action: "share")
        }
    }
    
    /// Share a course completion achievement
    /// - Parameters:
    ///   - courseId: The unique identifier of the course
    ///   - title: The title of the course
    ///   - score: The completion score or XP earned
    ///   - from: The view controller to present the share sheet from
    func shareCompletion(courseId: String, title: String, score: Int, from viewController: UIViewController) {
        let deepLink = "lyoapp://course/\(courseId)"
        let shareText = """
        🎯 Just completed "\(title)" on Lyo!
        
        I earned \(score) XP and leveled up my skills.
        
        Check out this course: \(deepLink)
        """
        
        let activityVC = UIActivityViewController(activityItems: [shareText], applicationActivities: nil)
        
        // iPad support
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(activityVC, animated: true)
        
        print("🏆 Sharing completion for course: \(courseId)")
        
        // 🏆 Award XP for celebration
        Task {
            try? await LyoRepository.shared.awardXP(amount: 25, category: "social")
        }
    }
}
