//
//  CourseCreationCoordinator.swift
//  Lyo
//
//  Coordinator for course creation flow with new Gemini enhancements
//

import SwiftUI
import os

/// Main entry point for course creation with settings
struct CourseCreationCoordinator: View {
    @State private var courseTopic = ""
    @State private var showSettings = false
    @State private var showProgress = false
    @State private var generationOptions = CourseGenerationOptions.recommended
    @State private var generatedCourseId: String?
    
    let onComplete: (String) -> Void  // Called with course_id
    let onCancel: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 8) {
                    Text("Create AI Course")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Powered by Gemini 2.5")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 40)
                
                // Topic Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("What do you want to learn?")
                        .font(.headline)
                    
                    TextField("e.g., Python Programming for Beginners",  text: $courseTopic)
                        .textFieldStyle(.roundedBorder)
                        .font(.body)
                }
                .padding(.horizontal)
                
                // Settings Button
                Button {
                    showSettings = true
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                        Text("Customize Settings")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                // Quick Settings Summary
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Quality", systemImage: generationOptions.qualityTier.icon)
                        Spacer()
                        Text(generationOptions.qualityTier.displayName)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Est. Cost", systemImage: "dollarsign.circle")
                        Spacer()
                        Text(String(format: "$%.4f", generationOptions.estimatedCost))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Est. Time", systemImage: "clock")
                        Spacer()
                        Text("\(generationOptions.estimatedTimeSec / 60) min")
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .padding()
                .background(Color.blue.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                
                Spacer()
                
                // Generate Button
                Button {
                    showProgress = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                        Text("Generate Course")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(courseTopic.isEmpty ? Color.gray : Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(courseTopic.isEmpty)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                NavigationStack {
                    CourseGenerationSettingsView(
                        options: $generationOptions,
                        topic: courseTopic
                    ) { updatedOptions in
                        generationOptions = updatedOptions
                        showSettings = false
                    }
                }
            }
            .fullScreenCover(isPresented: $showProgress) {
                GenerationProgressView(
                    topic: courseTopic,
                    options: generationOptions,
                    onComplete: { courseId in
                        showProgress = false
                        generatedCourseId = courseId
                        onComplete(courseId)
                    },
                    onCancel: {
                        showProgress = false
                    }
                )
            }
        }
    }
}

// MARK: - Preview

#Preview {
    CourseCreationCoordinator(
        onComplete: { courseId in
            Log.ui.info("Completed: \(courseId)")
        },
        onCancel: {
            Log.ui.info("Cancelled")
        }
    )
}
