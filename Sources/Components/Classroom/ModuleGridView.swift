import SwiftUI

struct ModuleGridView: View {
    @ObservedObject var viewModel: ClassroomViewModel
    @State private var selectedModuleIndex: Int? = nil
    @State private var showSlideGrid = false
    
    var body: some View {
        ZStack {
            // Background blur
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    dismissGrid()
                }
            
            VStack(spacing: 0) {
                // Header
                header
                
                if showSlideGrid, let moduleIndex = selectedModuleIndex {
                    // Slide grid for selected module
                    slideGrid(for: moduleIndex)
                } else {
                    // Module grid
                    moduleGrid
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color("LyoSurface"))
            )
            .padding(40)
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    if value.translation.height > 100 {
                        dismissGrid()
                    }
                }
        )
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 12) {
            // Drag indicator
            Capsule()
                .fill(Color.white.opacity(0.3))
                .frame(width: 40, height: 4)
                .padding(.top, 12)
            
            HStack {
                // Back button (if in slide grid)
                if showSlideGrid {
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            showSlideGrid = false
                            selectedModuleIndex = nil
                        }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                
                // Title
                Text(showSlideGrid ? moduleTitle : "All Modules")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Close button
                Button {
                    dismissGrid()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
        }
        .background(Color("LyoBackground").opacity(0.5))
    }
    
    private var moduleTitle: String {
        guard let session = viewModel.session,
              let index = selectedModuleIndex,
              index < session.modules.count else {
            return ""
        }
        return session.modules[index].title
    }
    
    // MARK: - Module Grid
    
    private var moduleGrid: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 20),
                    GridItem(.flexible(), spacing: 20)
                ],
                spacing: 20
            ) {
                if let session = viewModel.session {
                    ForEach(Array(session.modules.enumerated()), id: \.offset) { index, module in
                        ModuleCardButton(
                            module: module,
                            moduleIndex: index,
                            isCurrent: index == viewModel.currentModuleIndex,
                            progress: moduleProgress(for: index)
                        ) {
                            selectModule(index)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Slide Grid
    
    private func slideGrid(for moduleIndex: Int) -> some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16),
                    GridItem(.flexible(), spacing: 16)
                ],
                spacing: 16
            ) {
                if let session = viewModel.session,
                   moduleIndex < session.modules.count {
                    let module = session.modules[moduleIndex]
                    ForEach(Array(module.slides.enumerated()), id: \.offset) { slideIndex, slide in
                        SlideCardButton(
                            slide: slide,
                            slideIndex: slideIndex,
                            isCurrent: moduleIndex == viewModel.currentModuleIndex && slideIndex == viewModel.currentSlideIndex,
                            isCompleted: isSlideCompleted(moduleIndex: moduleIndex, slideIndex: slideIndex)
                        ) {
                            jumpToSlide(moduleIndex: moduleIndex, slideIndex: slideIndex)
                        }
                    }
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Helper Methods
    
    private func moduleProgress(for index: Int) -> Double {
        guard let session = viewModel.session,
              let progress = session.progress.moduleProgress[session.modules[index].id] else {
            return 0.0
        }
        
        let totalSlides = session.modules[index].slides.count
        let completedSlides = progress.completedSlides.count
        return Double(completedSlides) / Double(totalSlides)
    }
    
    private func isSlideCompleted(moduleIndex: Int, slideIndex: Int) -> Bool {
        guard let session = viewModel.session else { return false }
        let module = session.modules[moduleIndex]
        guard let progress = session.progress.moduleProgress[module.id] else {
            return false
        }
        let slideId = module.slides[slideIndex].id
        return progress.completedSlides.contains(slideId)
    }
    
    private func selectModule(_ index: Int) {
        selectedModuleIndex = index
        withAnimation(.spring(response: 0.3)) {
            showSlideGrid = true
        }
    }
    
    private func jumpToSlide(moduleIndex: Int, slideIndex: Int) {
        viewModel.jumpToSlide(moduleIndex: moduleIndex, slideIndex: slideIndex)
        dismissGrid()
        
        // Auto-start narration if enabled
        if viewModel.settings.autoplayNarration {
            viewModel.startNarration()
        }
    }
    
    private func dismissGrid() {
        withAnimation(.spring(response: 0.3)) {
            viewModel.showModuleGrid = false
            showSlideGrid = false
            selectedModuleIndex = nil
        }
    }
}

// MARK: - Module Card Button

struct ModuleCardButton: View {
    let module: LessonModule
    let moduleIndex: Int
    let isCurrent: Bool
    let progress: Double
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                // Cover image
                if let coverURL = module.coverImageURL {
                    AsyncImage(url: URL(string: coverURL)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        placeholderCover
                    }
                    .frame(height: 120)
                    .clipped()
                } else {
                    placeholderCover
                        .frame(height: 120)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 8) {
                    // Module number
                    Text("Module \(moduleIndex + 1)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color("LyoAccent"))
                    
                    // Title
                    Text(module.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(2)
                    
                    // Metadata
                    HStack(spacing: 12) {
                        Label("\(module.slides.count)", systemImage: "doc.text")
                        Label("\(module.estimatedDuration / 60)m", systemImage: "clock")
                    }
                    .font(.system(size: 12))
                    .foregroundColor(Color("LyoTextSecondary"))
                    
                    // Progress bar
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.white.opacity(0.2))
                                .frame(height: 4)
                            
                            Rectangle()
                                .fill(Color("LyoAccent"))
                                .frame(width: geometry.size.width * progress, height: 4)
                        }
                        .clipShape(Capsule())
                    }
                    .frame(height: 4)
                }
                .padding(12)
            }
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color("LyoBackground").opacity(0.5))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(
                                isCurrent ? Color("LyoAccent") : Color.white.opacity(0.2),
                                lineWidth: isCurrent ? 3 : 1
                            )
                    )
            )
        }
    }
    
    private var placeholderCover: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color("Primary").opacity(0.3),
                    Color("Secondary").opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            Image(systemName: "function")
                .font(.system(size: 40))
                .foregroundColor(Color("LyoAccent").opacity(0.5))
        }
    }
}

// MARK: - Slide Card Button

struct SlideCardButton: View {
    let slide: Slide
    let slideIndex: Int
    let isCurrent: Bool
    let isCompleted: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                // Slide type icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color("LyoBackground").opacity(0.5))
                        .frame(height: 100)
                    
                    VStack(spacing: 8) {
                        Image(systemName: slideTypeIcon)
                            .font(.system(size: 32))
                            .foregroundColor(Color("LyoAccent"))
                        
                        Text(slideTypeName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(Color("LyoTextSecondary"))
                    }
                    
                    // Completed checkmark
                    if isCompleted {
                        VStack {
                            HStack {
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.green)
                                    .padding(8)
                            }
                            Spacer()
                        }
                    }
                }
                
                // Title
                Text(slide.content.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .padding(.horizontal, 8)
                
                // Slide number
                Text("Slide \(slideIndex + 1)")
                    .font(.system(size: 11))
                    .foregroundColor(Color("LyoTextSecondary"))
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color("LyoBackground").opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isCurrent ? Color("LyoAccent") : Color.white.opacity(0.1),
                                lineWidth: isCurrent ? 2 : 1
                            )
                    )
            )
        }
    }
    
    private var slideTypeIcon: String {
        switch slide.type {
        case .concept: return "lightbulb"
        case .diagram: return "chart.bar"
        case .example: return "doc.text"
        case .practice: return "pencil"
        case .summary: return "checkmark.seal"
        }
    }
    
    private var slideTypeName: String {
        switch slide.type {
        case .concept: return "Concept"
        case .diagram: return "Diagram"
        case .example: return "Example"
        case .practice: return "Practice"
        case .summary: return "Summary"
        }
    }
}
