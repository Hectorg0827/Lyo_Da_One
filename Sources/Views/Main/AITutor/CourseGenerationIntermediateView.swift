//
//  CourseGenerationIntermediateView.swift
//  Lyo
//
//  Intermediate view that generates a course from AI command and opens classroom
//

import SwiftUI
import os

struct CourseGenerationIntermediateView: View {
    let topic: String
    let title: String
    let level: String
    let objectives: [String]
    let onComplete: () -> Void
    
    @StateObject private var courseService = CourseGenerationService.shared
    @State private var generatedCourse: GeneratedCourseResponse?
    @State private var error: String?
    @State private var showClassroom = false
    
    var body: some View {
        ZStack {
            // Background
            PremiumBackground()
            
            if let error = error {
                // Error State
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text("Course Generation Failed")
                        .font(.title2.weight(.bold))
                    
                    Text(error)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Try Again") {
                        self.error = nil
                        generateCourse()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Close") {
                        onComplete()
                    }
                    .buttonStyle(.bordered)
                }
                
            } else if let course = generatedCourse, showClassroom {
                // Show Classroom with generated course
                AIGeneratedClassroomView(
                    course: course,
                    onDismiss: {
                        onComplete()
                    }
                )
                
            } else {
                // Loading State
                VStack(spacing: 30) {
                    // Animated Lio Avatar
                    Image("LyoAvatar")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .shadow(color: Color(hex: "6366F1").opacity(0.5), radius: 20)
                    
                    VStack(spacing: 12) {
                        Text("Creating Your Course")
                            .font(.title2.weight(.bold))
                        
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    
                    // Progress Bar
                    VStack(spacing: 8) {
                        ProgressView(value: courseService.progress)
                            .progressViewStyle(.linear)
                            .tint(Color(hex: "6366F1"))
                            .frame(width: 250)
                        
                        Text(courseService.currentStep)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Learning Objectives Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("What You'll Learn:")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.secondary)
                        
                        ForEach(objectives.prefix(3), id: \.self) { objective in
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "6366F1"))
                                Text(objective)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding()
            }
        }
        .onAppear {
            generateCourse()
        }
    }
    
    private func generateCourse() {
        Task {
            do {
                Log.course.info("Generating course: \(topic) at \(level) level")
                let course = try await courseService.generateCourse(
                    topic: topic,
                    level: level,
                    outcomes: objectives.isEmpty ? [] : objectives,
                    teachingStyle: "interactive"
                )
                
                Log.course.info("Course generated: \(course.title)")
                generatedCourse = course
                
                // Small delay for smooth transition
                try await Task.sleep(nanoseconds: 500_000_000)
                showClassroom = true
                
            } catch {
                Log.course.error("Course generation error: \(error)")
                self.error = error.localizedDescription
            }
        }
    }
}

// MARK: - AI Generated Classroom View

struct AIGeneratedClassroomView: View {
    let course: GeneratedCourseResponse
    let onDismiss: () -> Void
    
    @State private var currentModuleIndex = 0
    @State private var currentLessonIndex = 0
    
    var currentModule: GenerationCourseModule {
        course.modules[currentModuleIndex]
    }
    
    var currentLesson: GenerationCourseLesson {
        currentModule.lessons[currentLessonIndex]
    }
    
    var body: some View {
        ZStack {
            PremiumBackground()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    HStack {
                        Button(action: onDismiss) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        Spacer()
                        
                        Text("\(currentModuleIndex + 1)/\(course.modules.count)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Text(course.title)
                        .font(.title3.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    Text(currentModule.title)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding()
                .background(Color(hex: "6366F1").opacity(0.9))
                
                // Lesson Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Lesson Title
                        Text(currentLesson.title)
                            .font(.title2.weight(.bold))
                        
                        // Lesson Content
                        Text(currentLesson.content)
                            .font(.body)
                            .lineSpacing(6)
                        
                        Spacer(minLength: 40)
                    }
                    .padding()
                }
                
                // Navigation
                HStack(spacing: 16) {
                    if canGoBack {
                        Button(action: goBack) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Previous")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(12)
                        }
                    }
                    
                    if canGoForward {
                        Button(action: goForward) {
                            HStack {
                                Text("Next")
                                Image(systemName: "chevron.right")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(hex: "6366F1"))
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: onDismiss) {
                            HStack {
                                Text("Complete")
                                Image(systemName: "checkmark.circle.fill")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
        }
        .foregroundColor(.white)
    }
    
    private var canGoBack: Bool {
        currentModuleIndex > 0 || currentLessonIndex > 0
    }
    
    private var canGoForward: Bool {
        currentLessonIndex < currentModule.lessons.count - 1 ||
        currentModuleIndex < course.modules.count - 1
    }
    
    private func goBack() {
        if currentLessonIndex > 0 {
            currentLessonIndex -= 1
        } else if currentModuleIndex > 0 {
            currentModuleIndex -= 1
            currentLessonIndex = course.modules[currentModuleIndex].lessons.count - 1
        }
    }
    
    private func goForward() {
        if currentLessonIndex < currentModule.lessons.count - 1 {
            currentLessonIndex += 1
        } else if currentModuleIndex < course.modules.count - 1 {
            currentModuleIndex += 1
            currentLessonIndex = 0
        }
    }
}
