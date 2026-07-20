//
//  CourseShareService.swift
//  Lyo
//
//  Service for sharing courses via UIActivityViewController
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Course Share Service

@MainActor
final class CourseShareService {
    static let shared = CourseShareService()
    
    private init() {}
    
    // MARK: - Share Methods
    
    /// Share a course with native iOS share sheet
    func shareItems(courseId: String, title: String, description: String? = nil) -> [Any] {
        var items: [Any] = [buildShareMessage(title: title, description: description)]
        if let url = buildCourseDeepLink(courseId: courseId) {
            items.append(url)
        }
        return items
    }

    func shareCourse(
        courseId: String,
        title: String,
        description: String? = nil,
        from viewController: UIViewController? = nil
    ) {
        // Build share URL with deep link
        let shareURL = buildCourseDeepLink(courseId: courseId)
        
        // Build share message
        let message = buildShareMessage(title: title, description: description)
        
        // Create share items
        var shareItems: [Any] = [message]
        if let url = shareURL {
            shareItems.append(url)
        }
        
        // Present activity view controller
        let activityVC = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        // Exclude irrelevant activities
        activityVC.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .openInIBooks
        ]
        
        // Present from current window
        if let vc = viewController ?? UIApplication.shared.keyWindow?.rootViewController {
            // iPad support: set popover presentation controller
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = vc.view
                popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            vc.present(activityVC, animated: true)
            print("📤 CourseShareService: Presented share sheet for course: \(title)")
        }
    }
    
    /// Share completion achievement (when user finishes a course)
    func shareCompletion(
        courseId: String,
        title: String,
        completionDate: Date,
        score: Int? = nil,
        from viewController: UIViewController? = nil
    ) {
        let shareURL = buildCourseDeepLink(courseId: courseId)
        
        let message: String
        if let score = score {
            message = """
            🎉 I just completed "\(title)" on Lyo!
            Score: \(score)%
            
            Check it out on Lyo - Learn Your Own Way!
            """
        } else {
            message = """
            🎉 I just completed "\(title)" on Lyo!
            
            Check it out on Lyo - Learn Your Own Way!
            """
        }
        
        var shareItems: [Any] = [message]
        if let url = shareURL {
            shareItems.append(url)
        }
        
        let activityVC = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        
        if let vc = viewController ?? UIApplication.shared.keyWindow?.rootViewController {
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = vc.view
                popover.sourceRect = CGRect(x: vc.view.bounds.midX, y: vc.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            vc.present(activityVC, animated: true)
        }
    }
    
    // MARK: - Deep Link Generation
    
    /// Build deep link URL for course
    private func buildCourseDeepLink(courseId: String) -> URL? {
        // Deep link format: lyoapp://course/{courseId}
        let urlString = "lyoapp://course/\(courseId)"
        return URL(string: urlString)
    }
    
    /// Build share message for course
    private func buildShareMessage(title: String, description: String?) -> String {
        if let description = description, !description.isEmpty {
            return """
            📚 Check out "\(title)" on Lyo!
            
            \(description)
            
            Learn your own way with AI-powered courses!
            """
        } else {
            return """
            📚 Check out "\(title)" on Lyo!
            
            Learn your own way with AI-powered courses!
            """
        }
    }
}

// MARK: - SwiftUI View Extension

extension View {
    /// Present native share sheet for course
    func shareSheet(
        isPresented: Binding<Bool>,
        courseId: String,
        title: String,
        description: String? = nil
    ) -> some View {
        self.background(
            ShareSheetController(
                isPresented: isPresented,
                courseId: courseId,
                title: title,
                description: description
            )
        )
    }
}

// MARK: - UIViewControllerRepresentable for SwiftUI

private struct ShareSheetController: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let courseId: String
    let title: String
    let description: String?
    
    func makeUIViewController(context: Context) -> UIViewController {
        UIViewController() // Placeholder
    }
    
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        if isPresented {
            presentShareSheet(from: uiViewController)
            isPresented = false
        }
    }
    
    private func presentShareSheet(from viewController: UIViewController) {
        CourseShareService.shared.shareCourse(
            courseId: courseId,
            title: title,
            description: description,
            from: viewController
        )
    }
}

// MARK: - UIApplication Extension

private extension UIApplication {
    var keyWindow: UIWindow? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
