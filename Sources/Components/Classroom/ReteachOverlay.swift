import SwiftUI

struct ReteachOverlay: View {
    @ObservedObject var viewModel: ClassroomViewModel
    @State private var isReadingAloud = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            // Content card
            VStack(spacing: 0) {
                // Header
                header
                
                // Scrollable content
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Explanation section
                        if let content = viewModel.reteachContent {
                            explanationSection(content.explanation)
                            
                            // Analogy section (highlighted)
                            if let analogy = content.analogy {
                                analogySection(analogy)
                            }
                            
                            // Diagram section
                            if let diagram = content.diagram {
                                diagramSection(diagram)
                            }
                            
                            // Alternative approach section
                            if let alternative = content.alternativeApproach {
                                alternativeSection(alternative)
                            }
                        }
                    }
                    .padding(32)
                }
                
                // Bottom actions
                bottomActions
            }
            .frame(maxWidth: 600)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color("LyoSurface"))
            )
            .shadow(color: .black.opacity(0.3), radius: 20)
            .padding(40)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            if viewModel.settings.autoplayNarration {
                readAloud()
            }
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 12) {
            // Icon
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 36))
                .foregroundColor(Color("LyoAccent"))
            
            // Title
            Text(headerTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            // Subtitle
            Text("Let's look at this from a different angle")
                .font(.system(size: 16))
                .foregroundColor(Color("LyoTextSecondary"))
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(
            Color("LyoBackground").opacity(0.5)
        )
    }
    
    private var headerTitle: String {
        guard viewModel.currentQuickCheck != nil,
              viewModel.reteachContent?.explanation != nil else {
            return "Let's try a different approach"
        }
        
        // Check if answer was close
        return "Close! Let's clarify."
    }
    
    // MARK: - Content Sections
    
    private func explanationSection(_ explanation: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Explanation", icon: "text.alignleft")
            
            Text(explanation)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .lineSpacing(8)
        }
    }
    
    private func analogySection(_ analogy: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Think of it this way", icon: "bubble.left.and.bubble.right")
            
            HStack(spacing: 16) {
                // Quote icon
                Image(systemName: "quote.opening")
                    .font(.system(size: 24))
                    .foregroundColor(Color("LyoAccent").opacity(0.5))
                
                Text(analogy)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(Color("LyoAccent"))
                    .italic()
                    .lineSpacing(8)
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("LyoAccent").opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color("LyoAccent").opacity(0.3), lineWidth: 2)
                    )
            )
        }
    }
    
    private func diagramSection(_ diagram: DiagramData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Visual Guide", icon: "chart.bar.doc.horizontal")
            
            // Diagram placeholder
            RoundedRectangle(cornerRadius: 16)
                .fill(Color("LyoBackground").opacity(0.5))
                .frame(height: 250)
                .overlay(
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48))
                            .foregroundColor(Color("LyoAccent").opacity(0.5))
                        
                        if let labels = diagram.labels, !labels.isEmpty {
                            // Show labels
                            HStack(spacing: 12) {
                                ForEach(labels, id: \.self) { label in
                                    Text(label)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color("LyoAccent"))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            Capsule()
                                                .fill(Color("LyoBackground"))
                                        )
                                }
                            }
                        }
                    }
                )
        }
    }
    
    private func alternativeSection(_ alternative: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Another way to think about it", icon: "arrow.triangle.branch")
            
            Text(alternative)
                .font(.system(size: 18))
                .foregroundColor(.white)
                .lineSpacing(8)
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color("LyoBackground").opacity(0.3))
                )
        }
    }
    
    private func sectionHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(Color("LyoAccent"))
            
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(Color("LyoAccent"))
        }
    }
    
    // MARK: - Bottom Actions
    
    private var bottomActions: some View {
        HStack(spacing: 16) {
            // Try again button
            Button {
                tryAgain()
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Try Again")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color("LyoBackground"))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
            }
            
            // Got it button
            Button {
                gotIt()
            } label: {
                HStack {
                    Text("Got it")
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color("LyoBackground"))
                .padding(.horizontal, 32)
                .padding(.vertical, 14)
                .background(
                    Capsule()
                        .fill(Color("LyoAccent"))
                )
            }
        }
        .padding(24)
        .background(
            Color("LyoBackground").opacity(0.5)
        )
    }
    
    // MARK: - Actions
    
    private func tryAgain() {
        viewModel.dismissReteach()
        
        // Return to quick check
        if viewModel.currentQuickCheck != nil {
            viewModel.state = .quickCheck
        }
    }
    
    private func gotIt() {
        viewModel.dismissReteach()
        
        // Continue to next slide
        if viewModel.settings.autoplayNarration {
            viewModel.startNarration()
        }
    }
    
    private func readAloud() {
        guard let content = viewModel.reteachContent else { return }
        
        // Combine all text for TTS
        var textToRead = ""
        
        textToRead += content.explanation + ". "
        
        if let analogy = content.analogy {
            textToRead += "Think of it this way: " + analogy + ". "
        }
        
        if let alternative = content.alternativeApproach {
            textToRead += "Another way to think about it: " + alternative + ". "
        }
        
        // TODO: Use TTS to read the content
        // This would integrate with ClassroomViewModel's TTS system
        isReadingAloud = true
        
        // Simulate reading for 20-30 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 25) {
            isReadingAloud = false
        }
    }
}
