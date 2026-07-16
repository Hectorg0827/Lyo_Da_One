import SwiftUI

// Shared building blocks for module cards (used by ClassroomModuleCardView,
// QuickCheckOverlay, and MessageBubbleView).

// MARK: - Cover Area

struct CoverAreaView: View {
    let module: LessonModule
    let geometry: GeometryProxy
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color("BrandPrimary").opacity(0.3),
                    Color("BrandSecondary").opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            VStack(spacing: 20) {
                Spacer()
                
                // Module icon/illustration
                Image(systemName: "function")
                    .font(.system(size: 80))
                    .foregroundColor(Color("LyoAccent"))
                
                // Module metadata
                VStack(spacing: 8) {
                    Text(module.title)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    
                    HStack(spacing: 12) {
                        Label("\(module.slides.count) slides", systemImage: "doc.text")
                        Label("\(module.estimatedDuration / 60)m", systemImage: "clock")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Color("LyoTextSecondary"))
                }
                
                Spacer()
                
                // Concepts chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(module.concepts, id: \.self) { concept in
                            Text("#\(concept)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(Color("LyoAccent"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Color("LyoSurface"))
                                )
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding()
        }
    }
}

// MARK: - Slide Content

struct SlideContentView: View {
    let slide: Slide
    let settings: ClassroomSettings
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Title
                Text(slide.content.title)
                    .font(.system(size: titleFontSize, weight: .bold))
                    .foregroundColor(.white)
                
                // Body text
                if !slide.content.body.isEmpty {
                    Text(slide.content.body)
                        .font(.system(size: bodyFontSize))
                        .foregroundColor(Color("LyoTextSecondary"))
                        .lineSpacing(6)
                }
                
                // Bullet points
                if let bulletPoints = slide.content.bulletPoints {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(bulletPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: 12) {
                                Circle()
                                    .fill(Color("LyoAccent"))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 8)
                                
                                Text(point)
                                    .font(.system(size: bodyFontSize))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
                
                // Diagram
                if let diagram = slide.content.diagram {
                    DiagramView(diagram: diagram)
                }
                
                // Code snippet
                if let code = slide.content.codeSnippet {
                    CodeSnippetView(code: code)
                }
                
                Spacer(minLength: 100)
            }
            .padding(32)
        }
    }
    
    private var titleFontSize: CGFloat {
        switch settings.textSize {
        case .small: return 24
        case .medium: return 28
        case .large: return 32
        case .extraLarge: return 36
        }
    }
    
    private var bodyFontSize: CGFloat {
        switch settings.textSize {
        case .small: return 16
        case .medium: return 18
        case .large: return 20
        case .extraLarge: return 22
        }
    }
}

// MARK: - Diagram View

struct DiagramView: View {
    let diagram: DiagramData
    
    var body: some View {
        VStack(spacing: 12) {
            // Placeholder for diagram
            RoundedRectangle(cornerRadius: 12)
                .fill(Color("LyoSurface"))
                .frame(height: 200)
                .overlay(
                    VStack {
                        Image(systemName: "chart.xyaxis.line")
                            .font(.system(size: 48))
                            .foregroundColor(Color("LyoAccent"))
                        Text("Diagram")
                            .font(.system(size: 14))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                )
            
            // Labels if available
            if let labels = diagram.labels {
                HStack(spacing: 8) {
                    ForEach(labels, id: \.self) { label in
                        Text(label)
                            .font(.system(size: 12))
                            .foregroundColor(Color("LyoTextSecondary"))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color("LyoSurface").opacity(0.5))
                            )
                    }
                }
            }
        }
    }
}

// MARK: - Code Snippet View

struct CodeSnippetView: View {
    let code: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 12))
                Text("Code")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
            }
            .foregroundColor(Color("LyoAccent"))
            
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(.body, design: .monospaced))
                    .foregroundColor(.white)
                    .padding()
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.5))
            )
        }
    }
}
