//
//  ClipMetadataSheet.swift
//  Lyo
//
//  Sheet for entering clip metadata (title, description, subject, key points)
//  for AI course generation
//

import SwiftUI

// MARK: - Clip Metadata Sheet

/// Sheet for entering clip metadata before publishing
struct ClipMetadataSheet: View {
    @Environment(\.dismiss) var dismiss
    
    @Binding var title: String
    @Binding var description: String
    @Binding var subject: ClipSubject?
    @Binding var level: LearningLevel
    @Binding var keyPoints: [String]
    @Binding var enableCourseGeneration: Bool
    
    @State private var newKeyPoint: String = ""
    @State private var isExpanded = false
    
    let onPublish: () -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Title Section
                    titleSection
                    
                    // Description Section
                    descriptionSection
                    
                    // Subject & Level Section
                    subjectLevelSection
                    
                    // Key Points Section
                    keyPointsSection
                    
                    // AI Course Generation Toggle
                    courseGenerationSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Clip Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Publish") {
                        onPublish()
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .foregroundColor(title.isEmpty ? .gray : .blue)
                    .disabled(title.isEmpty)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Title Section
    
    private var titleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Title", systemImage: "textformat")
                .font(.headline)
                .foregroundColor(.white)
            
            TextField("What's this clip about?", text: $title)
                .textFieldStyle(.plain)
                .font(.body)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                .foregroundColor(.white)
        }
    }
    
    // MARK: - Description Section
    
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Description (Optional)", systemImage: "doc.text")
                .font(.headline)
                .foregroundColor(.white)
            
            TextEditor(text: $description)
                .font(.body)
                .frame(height: 80)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.1))
                )
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
        }
    }
    
    // MARK: - Subject & Level Section
    
    private var subjectLevelSection: some View {
        VStack(spacing: 16) {
            // Subject Picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Subject", systemImage: "books.vertical")
                    .font(.headline)
                    .foregroundColor(.white)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(ClipSubject.allCases) { subjectOption in
                            SubjectChip(
                                subject: subjectOption,
                                isSelected: subject == subjectOption
                            ) {
                                subject = subjectOption
                            }
                        }
                    }
                }
            }
            
            // Level Picker
            VStack(alignment: .leading, spacing: 8) {
                Label("Difficulty Level", systemImage: "chart.bar.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                
                HStack(spacing: 12) {
                    ForEach(LearningLevel.allCases, id: \.self) { levelOption in
                        LevelChip(
                            level: levelOption,
                            isSelected: level == levelOption
                        ) {
                            level = levelOption
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Key Points Section
    
    private var keyPointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Key Points", systemImage: "list.bullet")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("For AI to build courses")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            // Existing key points
            ForEach(keyPoints.indices, id: \.self) { index in
                HStack {
                    Text("• \(keyPoints[index])")
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button {
                        keyPoints.remove(at: index)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .padding(.vertical, 4)
            }
            
            // Add new key point
            HStack {
                TextField("Add a key point...", text: $newKeyPoint)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundColor(.white)
                
                Button {
                    addKeyPoint()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(newKeyPoint.isEmpty ? .gray : .green)
                }
                .disabled(newKeyPoint.isEmpty)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.1))
            )
        }
    }
    
    // MARK: - Course Generation Section
    
    private var courseGenerationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $enableCourseGeneration) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable AI Course Generation")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text("Allow AI to create courses from this clip")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .tint(.green)
            
            if enableCourseGeneration {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    
                    Text("Viewers can generate personalized courses from your content")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.yellow.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func addKeyPoint() {
        let trimmed = newKeyPoint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        keyPoints.append(trimmed)
        newKeyPoint = ""
    }
}

// MARK: - Subject Chip

struct SubjectChip: View {
    let subject: ClipSubject
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: subject.icon)
                Text(subject.rawValue)
            }
            .font(.subheadline)
            .foregroundColor(isSelected ? .white : .white.opacity(0.7))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.blue : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Level Chip

struct LevelChip: View {
    let level: LearningLevel
    let isSelected: Bool
    let action: () -> Void
    
    var levelColor: Color {
        switch level {
        case .beginner: return .green
        case .intermediate: return .yellow
        case .advanced: return .red
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(level.rawValue.capitalized)
                .font(.subheadline)
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? levelColor : Color.white.opacity(0.1))
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    ClipMetadataSheet(
        title: .constant("Math Tutorial"),
        description: .constant(""),
        subject: .constant(.mathematics),
        level: .constant(.beginner),
        keyPoints: .constant(["Quadratic formula", "Solving equations"]),
        enableCourseGeneration: .constant(true),
        onPublish: {}
    )
}
