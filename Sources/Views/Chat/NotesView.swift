//
//  NotesView.swift
//  Lyo
//
//  Premium Notes display and editing component
//  Uses NotesPayload and NoteSection from LyoCourseProtocol
//

import SwiftUI

// MARK: - Main Notes View

/// Displays structured notes with sections, callouts, and rich styling
/// Can be used in chat bubbles, course artifacts, or standalone
struct NotesView: View {
    let notes: NotesPayload
    var onCopy: (() -> Void)?
    var onShare: (() -> Void)?
    var onEdit: (() -> Void)?
    
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            notesHeader
            
            // Sections
            VStack(alignment: .leading, spacing: 12) {
                ForEach(notes.sections) { section in
                    NoteSectionView(
                        section: section,
                        isExpanded: expandedSections.contains(section.id),
                        onToggle: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                if expandedSections.contains(section.id) {
                                    expandedSections.remove(section.id)
                                } else {
                                    expandedSections.insert(section.id)
                                }
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Footer Actions
            notesFooter
        }
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(white: 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(
                    LinearGradient(
                        colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .onAppear {
            // Expand all sections by default
            expandedSections = Set(notes.sections.map { $0.id })
        }
    }
    
    // MARK: - Header
    
    private var notesHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.purple, Color.blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(notes.title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("\(notes.sections.count) sections")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            // AI Badge
            HStack(spacing: 4) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                Text("AI")
                    .font(.caption2.bold())
            }
            .foregroundColor(.purple)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.purple.opacity(0.15))
            .clipShape(Capsule())
        }
        .padding(16)
    }
    
    // MARK: - Footer
    
    private var notesFooter: some View {
        HStack(spacing: 16) {
            Spacer()
            
            // Copy
            Button(action: {
                copyNotesToClipboard()
                onCopy?()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "doc.on.doc")
                    Text("Copy")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }
            
            // Share
            Button(action: {
                shareNotes()
                onShare?()
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            }
            
            // Edit (optional)
            if onEdit != nil {
                Button(action: { onEdit?() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("Edit")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
    
    // MARK: - Actions
    
    private func copyNotesToClipboard() {
        let text = notes.sections.map { section in
            "## \(section.title)\n\(section.contentMarkdown)"
        }.joined(separator: "\n\n")
        
        UIPasteboard.general.string = "# \(notes.title)\n\n\(text)"
        HapticManager.shared.playSuccess()
    }
    
    private func shareNotes() {
        let text = notes.sections.map { section in
            "## \(section.title)\n\(section.contentMarkdown)"
        }.joined(separator: "\n\n")
        
        let fullText = "# \(notes.title)\n\n\(text)"
        
        let activityVC = UIActivityViewController(activityItems: [fullText], applicationActivities: nil)
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }
}

// MARK: - Note Section View

struct NoteSectionView: View {
    let section: NoteSection
    let isExpanded: Bool
    let onToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Section Header
            Button(action: onToggle) {
                HStack {
                    Image(systemName: section.isCallout ? "lightbulb.fill" : "text.alignleft")
                        .font(.caption)
                        .foregroundColor(section.isCallout ? .yellow : .blue)
                    
                    Text(section.title)
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            
            // Section Content
            if isExpanded {
                if section.isCallout {
                    // Callout Style
                    HStack(alignment: .top, spacing: 10) {
                        Rectangle()
                            .fill(Color.yellow)
                            .frame(width: 3)
                        
                        MarkdownTextView(text: section.contentMarkdown)
                            .foregroundColor(.white.opacity(0.85))
                    }
                    .padding(12)
                    .background(Color.yellow.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    // Normal Style
                    MarkdownTextView(text: section.contentMarkdown)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.leading, 4)
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Simple Markdown Text View

struct MarkdownTextView: View {
    let text: String
    
    var body: some View {
        // Parse simple markdown: **bold**, *italic*, `code`, - bullets
        VStack(alignment: .leading, spacing: 6) {
            ForEach(parsedLines, id: \.self) { line in
                if line.hasPrefix("- ") || line.hasPrefix("• ") {
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.blue)
                        Text(formattedText(String(line.dropFirst(2))))
                            .font(.callout)
                    }
                } else if line.hasPrefix("# ") {
                    Text(formattedText(String(line.dropFirst(2))))
                        .font(.headline)
                } else if line.hasPrefix("## ") {
                    Text(formattedText(String(line.dropFirst(3))))
                        .font(.subheadline.bold())
                } else if !line.isEmpty {
                    Text(formattedText(line))
                        .font(.callout)
                }
            }
        }
    }
    
    private var parsedLines: [String] {
        text.components(separatedBy: "\n")
    }
    
    private func formattedText(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // Bold: **text**
        if let boldRange = result.range(of: "**") {
            // Simple implementation - just remove markers for now
            result.replaceSubrange(boldRange, with: AttributedString(""))
        }
        
        return result
    }
}

// MARK: - Notes Block View (for Classroom)

struct NotesBlockView: View {
    let block: LessonBlock
    
    private var notesPayload: NotesPayload? {
        // Try to parse from block content
        guard let jsonString = block.content,
              let data = jsonString.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(NotesPayload.self, from: data)
    }
    
    var body: some View {
        if let notes = notesPayload {
            NotesView(notes: notes)
        } else {
            // Fallback: Simple notes display
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .foregroundColor(.purple)
                    Text(block.title ?? "Notes")
                        .font(.headline)
                }
                
                Text(block.safeContent)
                    .font(.body)
                    .foregroundColor(.primary.opacity(0.8))
                    .lineSpacing(6)
            }
            .padding()
            .background(Color.purple.opacity(0.08))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

// MARK: - Notes Chat Bubble View

struct NotesBubbleView: View {
    let title: String
    let sections: [NoteSection]
    
    var body: some View {
        NotesView(
            notes: NotesPayload(
                title: title,
                sections: sections
            )
        )
    }
}

// MARK: - Preview

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        ScrollView {
            NotesView(
                notes: NotesPayload(
                    title: "Swift Basics Cheat Sheet",
                    sections: [
                        NoteSection(
                            title: "Variables",
                            contentMarkdown: "- Use `let` for constants\n- Use `var` for variables\n- Swift infers types automatically",
                            isCallout: false
                        ),
                        NoteSection(
                            title: "Pro Tip",
                            contentMarkdown: "Always prefer `let` over `var` when possible. Immutability makes your code safer!",
                            isCallout: true
                        ),
                        NoteSection(
                            title: "Functions",
                            contentMarkdown: "- Define with `func` keyword\n- Parameters use `name: Type` syntax\n- Return type after `->`",
                            isCallout: false
                        )
                    ]
                )
            )
            .padding()
        }
    }
}

// MARK: - Notes Artifact View (for Course Runtime)

struct NotesArtifactView: View {
    let artifact: LyoArtifact
    let onComplete: () -> Void
    
    @State private var payload: NotesPayload?
    @State private var decodeError: String?
    
    var body: some View {
        ZStack {
            if let payload = payload {
                VStack(spacing: 0) {
                    ScrollView {
                        NotesView(notes: payload)
                            .padding()
                    }
                    
                    // Continue Button
                    Button(action: onComplete) {
                        Text("Continue")
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(
                                LinearGradient(
                                    colors: [Color.purple, Color.blue],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .padding()
                }
            } else if let error = decodeError {
                VStack(alignment: .leading, spacing: 10) {
                    Text("⚠️ Notes Error")
                        .font(.headline)
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Button("Skip") { onComplete() }
                        .buttonStyle(.bordered)
                }
                .padding()
            } else {
                ProgressView("Loading notes...")
            }
        }
        .onAppear {
            decodePayload()
        }
    }
    
    func decodePayload() {
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: artifact.content.value as Any)
            let decoded = try JSONDecoder().decode(NotesPayload.self, from: jsonData)
            payload = decoded
        } catch {
            decodeError = "Failed to decode notes: \(error.localizedDescription)"
        }
    }
}

