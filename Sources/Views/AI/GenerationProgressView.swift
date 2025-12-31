//
//  GenerationProgressView.swift
//  Lyo
//
//  Real-time progress view for course generation
//

import SwiftUI

struct GenerationProgressView: View {
    let topic: String
    let options: CourseGenerationOptions
    let onComplete: (String) -> Void  // Called with course_id
    let onCancel: () -> Void
    
    @StateObject private var streamingClient = CourseGenerationStreamingClient()
    
    @State private var events: [CourseGenerationEvent] = []
    @State private var currentProgress: Int = 0
    @State private var currentMessage: String = "Initializing..."
    @State private var lessonsCompleted: Int = 0
    @State private var totalLessons: Int = 0
    @State private var showError = false
    @State private var errorMessage: String = ""
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Generating Course")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(topic)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Progress Circle
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 200, height: 200)
                
                Circle()
                    .trim(from: 0, to: CGFloat(currentProgress) / 100.0)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.6), value: currentProgress)
                
                VStack(spacing: 4) {
                    Text("\(currentProgress)%")
                        .font(.system(size: 48, weight: .bold))
                    
                    if (totalLessons > 0) {
                        Text("\(lessonsCompleted)/\(totalLessons) lessons")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Current Status
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    if streamingClient.isStreaming {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    
                    Text(currentMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            // Event Log (last 5 events)
            VStack(alignment: .leading, spacing: 8) {
                Text("Activity Log")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(events.suffix(5).reversed(), id: \.message) { event in
                                HStack(spacing: 8) {
                                    eventIcon(for: event.type)
                                        .font(.caption)
                                    
                                    Text(event.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .id(event.message)
                            }
                        }
                    }
                    .frame(height: 120)
                }
            }
            
            Spacer()
            
            // Cancel Button
            Button(role: .destructive) {
                streamingClient.stopStreaming()
                onCancel()
            } label: {
                Text("Cancel Generation")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding()
        .navigationBarBackButtonHidden()
        .alert("Generation Failed", isPresented: $showError) {
            Button("OK") {
                onCancel()
            }
        } message: {
            Text(errorMessage)
        }
        .task {
            startGeneration()
        }
        .onChange(of: streamingClient.errorMessage) { _, errorMsg in
            if let errorMsg = errorMsg {
                errorMessage = errorMsg
                showError = true
            }
        }
    }
    
    // MARK: - Helpers
    
    private func startGeneration() {
        streamingClient.startStreaming(
            topic: topic,
            options: options
        ) { event in
            handleEvent(event)
        }
    }
    
    private func handleEvent(_ event: CourseGenerationEvent) {
        DispatchQueue.main.async {
            events.append(event)
            currentProgress = event.progress
            currentMessage = event.message
            
            // Update lesson progress
            if let completed = event.data?.completed,
               let total = event.data?.total {
                lessonsCompleted = completed
                totalLessons = total
            }
            
            // Handle completion
            if event.type == .completed,
               let courseId = event.data?.courseId {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    onComplete(courseId)
                }
            }
            
            // Handle error
            if event.type == .error {
                errorMessage = event.data?.error ?? event.message
                showError = true
            }
        }
    }
    
    private func eventIcon(for type: CourseGenerationEventType) -> some View {
        Group {
            switch type {
            case .started:
                Image(systemName: "play.circle.fill")
                    .foregroundStyle(.blue)
            case .agentWorking:
                Image(systemName: "brain.head.profile")
                    .foregroundStyle(.purple)
            case .lessonComplete:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            case .progress:
                Image(systemName: "arrow.right.circle.fill")
                    .foregroundStyle(.blue)
            case .costUpdate:
                Image(systemName: "dollarsign.circle.fill")
                    .foregroundStyle(.orange)
            case .completed:
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            case .error:
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GenerationProgressView(
            topic: "Python Programming for Beginners",
            options: .recommended,
            onComplete: { courseId in
                print("Completed: \(courseId)")
            },
            onCancel: {
                print("Cancelled")
            }
        )
    }
}
