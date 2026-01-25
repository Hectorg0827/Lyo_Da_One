//
//  CourseWizardHandler.swift
//  Lyo
//
//  Handles the multi-step course creation wizard dialog
//

import Foundation
import SwiftUI

// MARK: - Wizard Response

struct WizardResponse {
    let message: String
    let chips: [String]
    let showOutlineCard: Bool
    let outline: CourseOutline?
    let shouldStartCourseGeneration: Bool
    let courseGenerationTopic: String?
    let courseGenerationLevel: String?
}

extension WizardResponse {
    func toLioChatResponse() -> LioChatResponse {
        var contentTypes: [MessageContentType]? = nil
        if showOutlineCard, let outline = outline {
            let modules = outline.modules.map { moduleTitle in
                CourseModule(title: moduleTitle, duration: nil, isCompleted: false, isLocked: false)
            }
            contentTypes = [
                .courseRoadmap(
                    title: outline.title,
                    modules: modules,
                    totalModules: modules.count,
                    completedModules: 0
                )
            ]
        }

        var action: LioChatAction? = nil
        if shouldStartCourseGeneration,
           let topic = courseGenerationTopic,
           let level = courseGenerationLevel {
            action = LioChatAction(type: "generate_course", parameters: [
                "topic": topic,
                "level": level
            ])
        }

        return LioChatResponse(
            text: message,
            source: "local",
            action: action,
            suggestions: chips,
            meta: nil,
            contentTypes: contentTypes
        )
    }
}

// MARK: - Course Wizard Handler

@MainActor
final class CourseWizardHandler: ObservableObject {
    static let shared = CourseWizardHandler()
    
    @Published var currentOutline: CourseOutline?
    @Published var isGeneratingOutline: Bool = false
    
    private let classifier = ChatIntentClassifier.shared
    
    private init() {}
    
    // MARK: - Handle Wizard Step
    
    func handleWizardStep(action: CourseWizardAction) async -> WizardResponse {
        switch classifier.wizardStep {
        case .inactive:
            return WizardResponse(
                message: "No course wizard active.",
                chips: [],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        case .confirmingTopic(let topic):
            return await handleTopicConfirmation(topic: topic, action: action)
            
        case .selectingLevel(let topic):
            return await handleLevelSelection(topic: topic, action: action)
            
        case .showingOutline(let topic, let level, _):
            return await handleOutlineResponse(topic: topic, level: level, action: action)
            
        case .generatingCourse, .courseReady:
            return WizardResponse(
                message: "Course is being generated...",
                chips: [],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
        }
    }
    
    // MARK: - Start Course Wizard
    
    func startCourseWizard(topic: String) -> WizardResponse {
        classifier.startWizard(topic: topic)
        
        return WizardResponse(
            message: """
            🎓 I'd love to create a course on **\(topic)** for you!
            
            Before we begin, let me make sure I understand exactly what you want to learn. Is "\(topic)" the correct topic?
            """,
            chips: ["✅ Yes, that's right", "🔄 Change topic", "❌ Cancel"],
            showOutlineCard: false,
            outline: nil,
            shouldStartCourseGeneration: false,
            courseGenerationTopic: nil,
            courseGenerationLevel: nil
        )
    }
    
    // MARK: - Handle Topic Confirmation
    
    private func handleTopicConfirmation(topic: String, action: CourseWizardAction) async -> WizardResponse {
        switch action {
        case .confirmTopic:
            classifier.wizardStep = .selectingLevel(topic: topic)
            return WizardResponse(
                message: """
                Great! Now, what's your current level with **\(topic)**?
                
                This helps me tailor the course content to your needs.
                """,
                chips: ["🌱 Beginner", "📚 Intermediate", "🚀 Advanced"],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        case .cancel:
            classifier.resetWizard()
            return WizardResponse(
                message: "No problem! Let me know if you want to learn something else. 😊",
                chips: ["Ask a question", "Create a course", "Explore topics"],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        case .editOutline(let newTopic):
            let extractedTopic = extractNewTopic(from: newTopic) ?? topic
            classifier.wizardStep = .confirmingTopic(topic: extractedTopic)
            return WizardResponse(
                message: "Got it! So you want to learn about **\(extractedTopic)**. Is that correct?",
                chips: ["✅ Yes, that's right", "🔄 Change topic", "❌ Cancel"],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        default:
            return WizardResponse(
                message: "Please confirm if **\(topic)** is the topic you want to learn about.",
                chips: ["✅ Yes, that's right", "🔄 Change topic", "❌ Cancel"],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
        }
    }
    
    // MARK: - Handle Level Selection
    
    private func handleLevelSelection(topic: String, action: CourseWizardAction) async -> WizardResponse {
        switch action {
        case .selectLevel(let level):
            // Generate outline
            isGeneratingOutline = true
            let outline = await generateQuickOutline(topic: topic, level: level)
            isGeneratingOutline = false
            
            currentOutline = outline
            classifier.wizardStep = .showingOutline(topic: topic, level: level, outline: outline)
            
            let moduleList = outline.modules.enumerated().map { "**\($0.offset + 1).** \($0.element)" }.joined(separator: "\n")
            
            return WizardResponse(
                message: """
                Perfect! Here's what your **\(topic)** course will cover:
                
                📚 **\(outline.title)**
                \(outline.description)
                
                **Modules:**
                \(moduleList)
                
                ⏱️ Estimated time: \(outline.estimatedDuration) minutes
                📊 Level: \(outline.level.capitalized)
                
                Ready to start learning?
                """,
                chips: ["🚀 Start Course", "✏️ Edit outline", "❌ Cancel"],
                showOutlineCard: true,
                outline: outline,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        case .cancel:
            classifier.resetWizard()
            return WizardResponse(
                message: "No problem! Let me know when you're ready to learn something new. 😊",
                chips: ["Ask a question", "Create a course", "Explore topics"],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        default:
            return WizardResponse(
                message: "Please select your level for **\(topic)**:",
                chips: ["🌱 Beginner", "📚 Intermediate", "🚀 Advanced"],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
        }
    }
    
    // MARK: - Handle Outline Response
    
    private func handleOutlineResponse(topic: String, level: String, action: CourseWizardAction) async -> WizardResponse {
        switch action {
        case .startCourse:
            classifier.wizardStep = .generatingCourse(topic: topic, level: level)
            
            return WizardResponse(
                message: """
                🎉 **Excellent!** Let's begin your learning journey!
                
                I'm now creating your personalized course on **\(topic)**. This will take just a moment...
                
                ✨ Building modules and lessons...
                """,
                chips: [],
                showOutlineCard: false,
                outline: currentOutline,
                shouldStartCourseGeneration: true,
                courseGenerationTopic: topic,
                courseGenerationLevel: level
            )
            
        case .editOutline(let feedback):
            // For now, regenerate with feedback
            isGeneratingOutline = true
            let outline = await generateQuickOutline(topic: topic, level: level, feedback: feedback)
            isGeneratingOutline = false
            
            currentOutline = outline
            classifier.wizardStep = .showingOutline(topic: topic, level: level, outline: outline)
            
            let moduleList = outline.modules.enumerated().map { "**\($0.offset + 1).** \($0.element)" }.joined(separator: "\n")
            
            return WizardResponse(
                message: """
                I've updated the outline based on your feedback:
                
                📚 **\(outline.title)**
                
                **Modules:**
                \(moduleList)
                
                How does this look?
                """,
                chips: ["🚀 Start Course", "✏️ Edit more", "❌ Cancel"],
                showOutlineCard: true,
                outline: outline,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        case .cancel:
            classifier.resetWizard()
            currentOutline = nil
            return WizardResponse(
                message: "No worries! Feel free to ask me anything else. 😊",
                chips: ["Ask a question", "Create a course", "Explore topics"],
                showOutlineCard: false,
                outline: nil,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
            
        default:
            return WizardResponse(
                message: "Would you like to start the course or make any changes?",
                chips: ["🚀 Start Course", "✏️ Edit outline", "❌ Cancel"],
                showOutlineCard: true,
                outline: currentOutline,
                shouldStartCourseGeneration: false,
                courseGenerationTopic: nil,
                courseGenerationLevel: nil
            )
        }
    }
    
    // MARK: - Generate Quick Outline (Local - No full course generation)
    
    private func generateQuickOutline(topic: String, level: String, feedback: String? = nil) async -> CourseOutline {
        // Generate a quick outline without full course content
        // This is fast and doesn't require heavy AI processing
        
        let levelEmoji: String
        let modulesCount: Int
        let baseDuration: Int
        
        switch level.lowercased() {
        case "beginner":
            levelEmoji = "🌱"
            modulesCount = 3
            baseDuration = 30
        case "intermediate":
            levelEmoji = "📚"
            modulesCount = 4
            baseDuration = 45
        case "advanced":
            levelEmoji = "🚀"
            modulesCount = 5
            baseDuration = 60
        default:
            levelEmoji = "📖"
            modulesCount = 3
            baseDuration = 30
        }
        
        // Generate contextual modules based on topic
        let modules = generateModuleNames(for: topic, level: level, count: modulesCount)
        
        return CourseOutline(
            title: "\(levelEmoji) \(topic) Mastery",
            description: "A comprehensive \(level) course to help you master \(topic) through practical lessons and examples.",
            modules: modules,
            estimatedDuration: baseDuration,
            level: level
        )
    }
    
    private func generateModuleNames(for topic: String, level: String, count: Int) -> [String] {
        // Generate sensible module names based on topic
        let topicLower = topic.lowercased()
        
        // Common patterns for different topics
        if topicLower.contains("programming") || topicLower.contains("coding") || topicLower.contains("swift") || topicLower.contains("python") || topicLower.contains("javascript") {
            return [
                "Fundamentals & Setup",
                "Core Syntax & Data Types",
                "Control Flow & Functions",
                "Object-Oriented Concepts",
                "Real-World Projects"
            ].prefix(count).map { $0 }
        }
        
        if topicLower.contains("machine learning") || topicLower.contains("ai") || topicLower.contains("data science") {
            return [
                "Introduction to \(topic)",
                "Data Preprocessing",
                "Core Algorithms",
                "Model Training & Evaluation",
                "Practical Applications"
            ].prefix(count).map { $0 }
        }
        
        if topicLower.contains("math") || topicLower.contains("algebra") || topicLower.contains("calculus") {
            return [
                "Foundation Concepts",
                "Core Principles",
                "Problem-Solving Techniques",
                "Advanced Applications",
                "Practice & Review"
            ].prefix(count).map { $0 }
        }
        
        // Generic pattern for any topic
        return [
            "Introduction to \(topic)",
            "Core Concepts",
            "Practical Applications",
            "Advanced Techniques",
            "Mastery & Review"
        ].prefix(count).map { $0 }
    }
    
    // MARK: - Helper
    
    private func extractNewTopic(from message: String) -> String? {
        let keywords = ["about", "on", "for", "learn", "topic", "instead", "change to", "switch to"]
        var cleaned = message.lowercased()
        
        for keyword in keywords {
            if let range = cleaned.range(of: keyword) {
                cleaned = String(cleaned[range.upperBound...])
            }
        }
        
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "?!.,"))
        
        guard !cleaned.isEmpty else { return nil }
        
        if let first = cleaned.first {
            return first.uppercased() + cleaned.dropFirst()
        }
        return cleaned
    }
    
    // MARK: - Reset
    
    func reset() {
        classifier.resetWizard()
        currentOutline = nil
        isGeneratingOutline = false
    }
}
