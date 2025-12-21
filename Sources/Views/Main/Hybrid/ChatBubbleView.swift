import SwiftUI
import UIKit

struct ChatBubbleView: View {
    let message: LyoMessage
    @State private var displayedText: String = ""
    @State private var isAnimating = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if message.isFromUser {
                Spacer()
                Text(message.content)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color(hex: "3B82F6"))
                    .cornerRadius(20)
                    .cornerRadius(4, corners: .bottomRight)
            } else {
                // AI Message with Small Lyo Avatar
                LyoAvatarView(size: 32, isListening: false)
                    .frame(width: 32, height: 32)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(displayedText)
                        .foregroundColor(.white)
                    
                    // Action Card: Check for Create Course / Quiz actions
                    if let actions = message.actions, !actions.isEmpty {
                        ForEach(actions) { action in
                            if action.actionType == .createCourse || action.actionType == .openClassroom {
                                CourseGeneratedCard(
                                    topic: action.data?["topic"] ?? "Course",
                                    onStart: {
                                        // Trigger navigation
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("TriggerLiveLesson"),
                                            object: nil,
                                            userInfo: ["lessonId": "intro_1", "topic": action.data?["topic"] ?? "Course"]
                                        )
                                    },
                                    onSave: {
                                        // Save to library
                                        NotificationCenter.default.post(
                                            name: NSNotification.Name("SaveCourseToLibrary"),
                                            object: nil,
                                            userInfo: ["topic": action.data?["topic"] ?? "Course"]
                                        )
                                    }
                                )
                                .padding(.top, 4)
                                .transition(.scale.combined(with: .opacity))
                            }
                        }
                    }
                }
                .padding()
                .background(Color(hex: "1E293B"))
                .cornerRadius(20)
                .cornerRadius(4, corners: .bottomLeft)
                .onAppear {
                    if !isAnimating && displayedText.isEmpty {
                        animateText()
                    }
                }
                Spacer()
            }
        }
        .padding(.horizontal)
        .transition(.scale.combined(with: .opacity))
    }
    
    private func animateText() {
        isAnimating = true
        displayedText = ""
        let chars = Array(message.content)
        
        // Faster typing for longer messages to keep it snappy
        let duration = min(0.02, 2.0 / Double(chars.count))
        
        for (index, char) in chars.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * duration) {
                displayedText.append(char)
                // Haptic feedback for first few chars to feel "tactile" but not annoying
                if index % 3 == 0 && index < 15 {
                    let generator = UIImpactFeedbackGenerator(style: .soft)
                    generator.impactOccurred()
                }
            }
        }
    }
}

// MARK: - Course Generated Card
struct CourseGeneratedCard: View {
    let topic: String
    let onStart: () -> Void
    let onSave: () -> Void
    
    @State private var isGenerating = true
    @State private var progress: CGFloat = 0.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if isGenerating {
                // Generating State
                HStack {
                    Image(systemName: "gearshape.2.fill")
                        .rotationEffect(.degrees(isGenerating ? 360 : 0))
                        .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: isGenerating)
                        .foregroundColor(.blue)
                    
                    Text("Building your course...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                
                // Progress Bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * progress, height: 6)
                            .animation(.linear(duration: 2.0), value: progress)
                    }
                }
                .frame(height: 6)
                .onAppear {
                    withAnimation {
                        progress = 1.0
                    }
                    
                    // Simulate generation time
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation(.spring()) {
                            isGenerating = false
                        }
                        // Haptic success
                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.success)
                    }
                }
            } else {
                // Ready State
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title2)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Course Ready")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(topic)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: onSave) {
                        Text("Save for Later")
                            .font(.subheadline.weight(.medium))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                    
                    Button(action: onStart) {
                        Text("Start Now")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity)
                            .background(
                                LinearGradient(colors: [Color(hex: "FF8C00"), Color(hex: "FF6B35")], startPoint: .leading, endPoint: .trailing)
                            )
                            .cornerRadius(10)
                            .shadow(color: Color(hex: "FF8C00").opacity(0.3), radius: 5, x: 0, y: 3)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(colors: [.white.opacity(0.2), .clear], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
    }
}


