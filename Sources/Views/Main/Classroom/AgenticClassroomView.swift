//
//  AgenticClassroomView.swift
//  Lyo
//
//  The cinematic classroom view where students FEEL the invisible faculty.
//  Agent blocks appear with staggered animations, each with distinct styling
//  that subtly communicates which agent contributed without explicitly labeling.
//

import SwiftUI

struct AgenticClassroomView: View {
    @StateObject private var viewModel = AgenticClassroomViewModel()
    @State private var inputText: String = ""
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            headerView
            
            // MARK: - Content Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.messages) { message in
                            messageBubble(for: message)
                                .id(message.id)
                        }
                        
                        // Agent Blocks (cinematic reveal)
                        if !viewModel.visibleBlocks.isEmpty {
                            agentBlocksView
                        }
                        
                        // Processing indicator
                        if viewModel.isProcessing {
                            processingView
                        }
                        
                        // Error
                        if let error = viewModel.error {
                            errorView(error)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom)
                    }
                }
                .onChange(of: viewModel.visibleBlocks.count) { _, _ in
                    withAnimation {
                        proxy.scrollTo("agent_blocks_bottom", anchor: .bottom)
                    }
                }
            }
            
            // MARK: - Tier Indicator
            if viewModel.isProcessing {
                tierIndicator
            }
            
            // MARK: - Input Bar
            inputBar
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.primary)
            }
            
            Spacer()
            
            VStack(spacing: 2) {
                Text("Lyo Classroom")
                    .font(.headline)
                
                if let intent = viewModel.lastIntent {
                    Text(intent.tier.label.capitalized)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .transition(.opacity)
                }
            }
            
            Spacer()
            
            Button(action: { viewModel.startNewSession() }) {
                Image(systemName: "plus.circle")
                    .font(.title3)
                    .foregroundColor(.primary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Message Bubble
    
    private func messageBubble(for message: LyoMessage) -> some View {
        HStack {
            if message.isFromUser { Spacer(minLength: 60) }
            
            Text(message.content)
                .font(.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    message.isFromUser
                    ? Color.blue.opacity(0.15)
                    : Color(.secondarySystemBackground)
                )
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            
            if !message.isFromUser { Spacer(minLength: 60) }
        }
    }
    
    // MARK: - Agent Blocks View
    
    private var agentBlocksView: some View {
        VStack(spacing: 12) {
            ForEach(viewModel.visibleBlocks) { block in
                AgentBlockCard(block: block)
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
            }
            
            // Anchor for scrolling
            Color.clear.frame(height: 1).id("agent_blocks_bottom")
        }
    }
    
    // MARK: - Processing View
    
    private var processingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            Text(viewModel.skeletonHint)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    
    // MARK: - Tier Indicator
    
    private var tierIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tierColor(viewModel.currentTier))
                .frame(width: 6, height: 6)
            
            Text(tierLabel(viewModel.currentTier))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
        .padding(.bottom, 4)
        .transition(.opacity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Input Bar
    
    private var inputBar: some View {
        HStack(spacing: 12) {
            TextField("Ask anything...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isInputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isProcessing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        inputText = ""
        
        Task {
            await viewModel.sendMessage(text)
        }
    }
    
    // MARK: - Helpers
    
    private func tierColor(_ tier: MessageSpeedTier) -> Color {
        switch tier {
        case .instant:  return .green
        case .fast:     return .blue
        case .standard: return .orange
        case .deep:     return .purple
        }
    }
    
    private func tierLabel(_ tier: MessageSpeedTier) -> String {
        switch tier {
        case .instant:  return "Instant"
        case .fast:     return "Quick response"
        case .standard: return "Processing..."
        case .deep:     return "Faculty engaged"
        }
    }
}

// MARK: - Agent Block Card

struct AgentBlockCard: View {
    let block: AgentBlock
    @State private var isExpanded = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Subtle agent indicator (the user FEELS it, doesn't SEE it labeled)
            HStack(spacing: 6) {
                Image(systemName: block.agent.icon)
                    .font(.caption)
                    .foregroundColor(agentColor)
                
                Text(blockTypeLabel)
                    .font(.caption.weight(.medium))
                    .foregroundColor(agentColor)
                
                Spacer()
                
                if let meta = block.metadata, let readingTime = meta.readingTime {
                    Text("\(readingTime)s read")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            // Content
            Text(block.content)
                .font(.body)
                .lineLimit(isExpanded ? nil : 4)
                .animation(.easeInOut, value: isExpanded)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(.secondarySystemBackground))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(agentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .onTapGesture {
            withAnimation(.spring(response: 0.3)) {
                isExpanded.toggle()
            }
        }
    }
    
    private var agentColor: Color {
        switch block.agent {
        case .tutor:         return .blue
        case .sentiment:     return .pink
        case .quiz:          return .green
        case .content:       return .purple
        case .metaCognition: return .orange
        case .orchestrator:  return .gray
        }
    }
    
    private var blockTypeLabel: String {
        switch block.blockType {
        case .explanation:     return "Explanation"
        case .encouragement:   return "You're doing great"
        case .checkpoint:      return "Quick check"
        case .deepDive:        return "Deep dive"
        case .reflection:      return "Think about it"
        case .summary:         return "Summary"
        case .transition:      return "Next up"
        case .codeExample:     return "Code example"
        case .analogy:         return "Real-world analogy"
        case .visualization:   return "Visualization"
        case .practicePrompt:  return "Try this"
        case .quickTip:        return "Pro tip"
        case .crossReference:  return "Remember..."
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AgenticClassroomView_Previews: PreviewProvider {
    static var previews: some View {
        AgenticClassroomView()
    }
}
#endif
