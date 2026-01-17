//
//  SuggestionChipsView.swift
//  Lyo
//
//  Animated suggestion chips that appear after AI responses
//

import SwiftUI

struct SuggestionChipsView: View {
    let suggestions: [SuggestionChip]
    let onSelect: (SuggestionChip) -> Void
    
    @State private var appeared = false
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, chip in
                    SuggestionChipButton(chip: chip) {
                        HapticManager.shared.playSelection()
                        onSelect(chip)
                    }
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 10)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(index) * 0.08),
                        value: appeared
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .onAppear {
            appeared = true
        }
    }
}

struct SuggestionChipButton: View {
    let chip: SuggestionChip
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = chip.icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(chip.text)
                    .font(.subheadline)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.easeInOut(duration: 0.15)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}

// MARK: - Smart Context Chips

struct ContextualSuggestionsView: View {
    let context: ChatContext?
    let onSelect: (String) -> Void
    
    @State private var suggestions: [SuggestionChip] = []
    
    var body: some View {
        Group {
            if !suggestions.isEmpty {
                SuggestionChipsView(suggestions: suggestions) { chip in
                    onSelect(chip.text)
                }
            }
        }
        .onAppear {
            generateContextualSuggestions()
        }
        .onChange(of: context?.courseId) { _, _ in
            generateContextualSuggestions()
        }
    }
    
    private func generateContextualSuggestions() {
        var chips: [SuggestionChip] = []
        
        // If in course context
        if context?.courseId != nil {
            chips.append(SuggestionChip(id: "quiz", text: "Quiz me on this", icon: "brain", actionType: "quiz", context: nil))
            chips.append(SuggestionChip(id: "explain", text: "Explain differently", icon: "arrow.triangle.2.circlepath", actionType: "explain", context: nil))
            chips.append(SuggestionChip(id: "example", text: "Give an example", icon: "lightbulb", actionType: "example", context: nil))
            chips.append(SuggestionChip(id: "next", text: "Next topic", icon: "arrow.right", actionType: "next", context: nil))
        } else {
            // General suggestions
            chips.append(SuggestionChip(id: "course", text: "Create a course", icon: "plus.circle", actionType: "course", context: nil))
            chips.append(SuggestionChip(id: "help", text: "Help me study", icon: "book", actionType: "study", context: nil))
            chips.append(SuggestionChip(id: "explain", text: "Explain this", icon: "questionmark.circle", actionType: "explain", context: nil))
        }
        
        suggestions = chips
    }
}

// MARK: - Typing Indicator

struct TypingIndicatorView: View {
    @State private var animationPhase = 0
    
    private let timer = Timer.publish(every: 0.3, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar
            Image("LyoAvatar")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            
            // Dots
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color.secondary)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animationPhase == index ? 1.3 : 1.0)
                        .opacity(animationPhase == index ? 1.0 : 0.5)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                animationPhase = (animationPhase + 1) % 3
            }
        }
    }
}

// MARK: - Streaming Text View

struct StreamingTextView: View {
    let text: String
    let isComplete: Bool
    
    @State private var displayedText = ""
    @State private var currentIndex = 0
    
    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()
    
    var body: some View {
        Text(displayedText + (isComplete ? "" : "▊"))
            .font(.body)
            .animation(.easeInOut(duration: 0.05), value: displayedText)
            .onReceive(timer) { _ in
                guard currentIndex < text.count else { return }
                let index = text.index(text.startIndex, offsetBy: currentIndex)
                displayedText += String(text[index])
                currentIndex += 1
            }
            .onChange(of: text) { oldValue, newValue in
                if newValue.count < oldValue.count {
                    // Reset if text changed significantly
                    displayedText = ""
                    currentIndex = 0
                }
            }
    }
}

// MARK: - Quick Actions Bar

struct QuickActionsBar: View {
    let actions: [QuickAction]
    let onSelect: (QuickAction) -> Void
    
    struct QuickAction: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ForEach(actions) { action in
                Button {
                    HapticManager.shared.playLightImpact()
                    onSelect(action)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: action.icon)
                            .font(.title2)
                            .foregroundColor(action.color)
                        
                        Text(action.title)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(action.color.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SuggestionChipsView(
            suggestions: [
                SuggestionChip(id: "1", text: "Tell me more", icon: "text.bubble", actionType: "more", context: nil),
                SuggestionChip(id: "2", text: "Give an example", icon: "lightbulb", actionType: "example", context: nil),
                SuggestionChip(id: "3", text: "Create a course", icon: "plus.circle", actionType: "course", context: nil)
            ]
        ) { chip in
            print("Selected: \(chip.text)")
        }
        
        Spacer()
        
        TypingIndicatorView()
        
        Spacer()
        
        QuickActionsBar(actions: [
            .init(title: "Course", icon: "book.fill", color: .blue),
            .init(title: "Quiz", icon: "brain", color: .purple),
            .init(title: "Study", icon: "text.book.closed", color: .green),
            .init(title: "Help", icon: "questionmark.circle", color: .orange)
        ]) { action in
            print("Selected action: \(action.title)")
        }
    }
    .padding()
}

// MARK: - Inline Suggestions View (A2UI)
/// Renders suggestions directly inline within a message bubble
/// Used by EnhancedMessageBubble for .suggestions content type

struct InlineSuggestionsView: View {
    let title: String
    let options: [String]
    let onSelect: (String) -> Void
    
    @State private var appeared = false
    
    private func iconForOption(_ option: String) -> String {
        let lowered = option.lowercased()
        if lowered.contains("course") { return "plus.circle" }
        if lowered.contains("quiz") { return "brain" }
        if lowered.contains("example") { return "lightbulb" }
        if lowered.contains("more") { return "text.bubble" }
        if lowered.contains("explain") { return "questionmark.circle" }
        if lowered.contains("help") { return "lifepreserver" }
        return "sparkles"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.secondary)
            }
            
            // Horizontal scrollable chips
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                        Button {
                            HapticManager.shared.playSelection()
                            onSelect(option)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: iconForOption(option))
                                    .font(.caption)
                                Text(option)
                                    .font(.subheadline)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(Color(.systemGray6))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 18)
                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .foregroundColor(.primary)
                        }
                        .buttonStyle(.plain)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 10)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.7)
                                .delay(Double(index) * 0.08),
                            value: appeared
                        )
                    }
                }
            }
        }
        .onAppear {
            appeared = true
        }
    }
}

