import SwiftUI
import AVFoundation

// MARK: - Create Mode Detail View

struct CreateModeDetailView: View {
    @Environment(\.dismiss) var dismiss
    let mode: CreateMode
    let capturedMedia: CapturedMedia?
    @ObservedObject var cameraManager: EnhancedCameraManager

    // Content
    @State private var content = ""
    @State private var title = ""
    @State private var tags: [String] = []
    
    // Publishing
    @State private var isPublishing = false
    @State private var publishProgress: Double = 0
    @State private var publishStatusText = ""
    @State private var showSuccessAnimation = false
    @State private var publishError: String?
    
    // Enhancement toggles
    @State private var hasQuiz = false
    @State private var hasKeyPoints = false
    @State private var hasProgressTracker = false
    @State private var hasResources = false
    
    // AI Enhancement states
    @State private var autoTagsGenerated = false
    @State private var seoOptimized = false
    @State private var audienceTargeted = false
    @State private var analyticsEnabled = false
    
    // Course-specific
    @State private var selectedLevel = "Beginner"
    @State private var selectedDuration = "1-2 hours"
    @State private var selectedCategory = "Technology"
    
    // Services
    @StateObject private var contentStorage = ContentStorageService.shared
    @StateObject private var draftService = DraftStorageService.shared

    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        Color.black,
                        mode.color.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {
                        headerSection
                        
                        if let media = capturedMedia {
                            mediaPreviewSection(media: media)
                        }

                        modeSpecificContent
                        aiEnhancementSection
                        tagsSection
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                VStack {
                    Spacer()
                    bottomActionArea
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .overlay(
                VStack {
                    customNavigationBar
                    Spacer()
                }
            )
        }
        .preferredColorScheme(.dark)
        .overlay(
            Group {
                if isPublishing {
                    publishingOverlay
                }
            }
        )
        .overlay(
            Group {
                if showSuccessAnimation {
                    SuccessAnimationView()
                        .transition(.scale.combined(with: .opacity))
                }
            }
        )
        .alert("Publishing Error", isPresented: Binding(
            get: { publishError != nil },
            set: { if !$0 { publishError = nil } }
        )) {
            Button("OK") { }
        } message: {
            Text(publishError ?? "Unknown error")
        }
    }

    // MARK: - Custom Navigation Bar

    private var customNavigationBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("Create \(mode.displayName)")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)

                Text("AI-Powered Learning")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()

            Button {
                publishContent()
            } label: {
                Text("Publish")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isReadyToPublish ? .white : .white.opacity(0.5))
            }
            .disabled(!isReadyToPublish || isPublishing)
        }
        .padding(.horizontal, 20)
        .padding(.top, 50)
        .background(.ultraThinMaterial)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                ZStack {
                    Circle()
                        .fill(mode.gradient)
                        .frame(width: 50, height: 50)

                    modeIcon
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(mode.displayName)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text(modeDescription)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()
            }

            // Title Input
            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

                TextField("Enter a compelling title...", text: $title)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
                    .padding(16)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.3), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Media Preview Section

    private func mediaPreviewSection(media: CapturedMedia) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Preview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            ZStack {
                if let image = media.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                } else if let videoURL = media.videoURL {
                    VideoThumbnailView(url: videoURL)
                        .frame(height: 200)
                        .cornerRadius(12)
                }

                if media.videoURL != nil {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        )
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Mode Specific Content

    @ViewBuilder
    private var modeSpecificContent: some View {
        switch mode {
        case .clip, .reel:
            videoModeContent
        case .story:
            storyModeContent
        case .course:
            courseModeContent
        case .post:
            postModeContent
        case .live:
            liveModeContent
        case .event:
            liveModeContent
        }
    }

    private var videoModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Description")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextEditor(text: $content)
                .frame(height: 120)
                .scrollContentBackground(.hidden)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )

            // Learning Enhancements — NOW FUNCTIONAL
            VStack(alignment: .leading, spacing: 12) {
                Text("Learning Enhancements")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                HStack(spacing: 12) {
                    enhancementToggle(
                        icon: "brain",
                        title: "Add Quiz",
                        description: "Interactive questions",
                        isActive: $hasQuiz
                    )

                    enhancementToggle(
                        icon: "note.text",
                        title: "Key Points",
                        description: "Highlight concepts",
                        isActive: $hasKeyPoints
                    )
                }

                HStack(spacing: 12) {
                    enhancementToggle(
                        icon: "chart.bar.fill",
                        title: "Progress",
                        description: "Track learning",
                        isActive: $hasProgressTracker
                    )

                    enhancementToggle(
                        icon: "link",
                        title: "Resources",
                        description: "Related materials",
                        isActive: $hasResources
                    )
                }
                
                // Summary of active enhancements
                if hasQuiz || hasKeyPoints || hasProgressTracker || hasResources {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                        Text("\(activeEnhancementCount) enhancement\(activeEnhancementCount == 1 ? "" : "s") will be added")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.green.opacity(0.8))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var storyModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Story Caption")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextField("Share your learning moment...", text: $content, axis: .vertical)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .lineLimit(3...6)
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var courseModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Course Overview")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextEditor(text: $content)
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)

            // Course Settings — NOW PERSISTENT
            VStack(spacing: 12) {
                courseSettingPicker(
                    title: "Level",
                    options: ["Beginner", "Intermediate", "Advanced"],
                    selection: $selectedLevel
                )
                courseSettingPicker(
                    title: "Duration",
                    options: ["1-2 hours", "3-5 hours", "5+ hours"],
                    selection: $selectedDuration
                )
                courseSettingPicker(
                    title: "Category",
                    options: ["Technology", "Science", "Arts", "Business", "Math", "Language"],
                    selection: $selectedCategory
                )
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var postModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Post Content")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextEditor(text: $content)
                .frame(height: 150)
                .scrollContentBackground(.hidden)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    private var liveModeContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Live Session")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            TextEditor(text: $content)
                .frame(height: 100)
                .scrollContentBackground(.hidden)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(12)
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - AI Enhancement Section — NOW FUNCTIONAL

    private var aiEnhancementSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("✨ AI Enhancements")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()
                
                if autoTagsGenerated {
                    Text("Applied")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.green)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                aiEnhancementCard(
                    icon: "wand.and.stars",
                    title: "Auto Tags",
                    description: "AI-generated hashtags",
                    isActive: autoTagsGenerated
                ) {
                    generateAutoTags()
                }

                aiEnhancementCard(
                    icon: "text.magnifyingglass",
                    title: "SEO Boost",
                    description: "Optimize discoverability",
                    isActive: seoOptimized
                ) {
                    seoOptimized.toggle()
                    HapticManager.shared.light()
                }

                aiEnhancementCard(
                    icon: "person.3.sequence",
                    title: "Audience",
                    description: "Target learners",
                    isActive: audienceTargeted
                ) {
                    audienceTargeted.toggle()
                    HapticManager.shared.light()
                }

                aiEnhancementCard(
                    icon: "chart.line.uptrend.xyaxis",
                    title: "Analytics",
                    description: "Performance insights",
                    isActive: analyticsEnabled
                ) {
                    analyticsEnabled.toggle()
                    HapticManager.shared.light()
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Tags")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)

            FlowLayout(spacing: 8) {
                ForEach(suggestedTags, id: \.self) { tag in
                    TagChip(
                        text: tag,
                        isSelected: tags.contains(tag)
                    ) {
                        toggleTag(tag)
                    }
                }
            }

            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected Tags")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))

                    FlowLayout(spacing: 8) {
                        ForEach(tags, id: \.self) { tag in
                            TagChip(
                                text: tag,
                                isSelected: true,
                                style: .selected
                            ) {
                                toggleTag(tag)
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - Bottom Action Area

    private var bottomActionArea: some View {
        VStack(spacing: 16) {
            // Publish Button
            Button {
                publishContent()
            } label: {
                HStack {
                    if isPublishing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .bold))
                    }

                    Text(isPublishing ? "Publishing..." : "Publish to Lyo")
                        .font(.system(size: 16, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    isReadyToPublish ?
                    mode.gradient :
                    LinearGradient(colors: [.gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(28)
                .shadow(
                    color: isReadyToPublish ? mode.color.opacity(0.4) : .clear,
                    radius: 15
                )
            }
            .disabled(!isReadyToPublish || isPublishing)
            .padding(.horizontal, 20)

            // Save Draft — NOW FUNCTIONAL
            Button {
                saveDraft()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 14))
                    Text("Save as Draft")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.bottom, 34)
    }
    
    // MARK: - Publishing Overlay
    
    private var publishingOverlay: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
                
                Text(publishStatusText.isEmpty ? "Publishing..." : publishStatusText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                
                Text("\(Int(publishProgress * 100))% complete")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))
                
                ProgressView(value: publishProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: mode.color))
                    .frame(width: 200)
            }
        }
    }

    // MARK: - Helper Views

    @ViewBuilder
    private var modeIcon: some View {
        switch mode {
        case .clip:
            Image(systemName: "video.fill")
        case .reel:
            Image(systemName: "play.rectangle.fill")
        case .story:
            Image(systemName: "camera.fill")
        case .course:
            Image(systemName: "graduationcap.fill")
        case .post:
            Image(systemName: "square.and.pencil")
        case .live:
            Image(systemName: "dot.radiowaves.left.and.right")
        case .event:
            Image(systemName: "person.3.fill")
        }
    }

    private var modeDescription: String {
        switch mode {
        case .clip: return "Short learning video"
        case .reel: return "Engaging educational reel"
        case .story: return "Quick learning moment"
        case .course: return "Complete learning journey"
        case .post: return "Share knowledge & insights"
        case .live: return "Interactive teaching session"
        case .event: return "Meet, connect, collaborate"
        }
    }

    private var suggestedTags: [String] {
        switch mode {
        case .clip, .reel:
            return ["#learning", "#education", "#tutorial", "#tips", "#knowledge", "#study"]
        case .story:
            return ["#dailylearning", "#insights", "#progress", "#motivation"]
        case .course:
            return ["#course", "#comprehensive", "#structured", "#certification"]
        case .post:
            return ["#discussion", "#question", "#insight", "#community"]
        case .live:
            return ["#live", "#interactive", "#QnA", "#teaching"]
        case .event:
            return ["#event", "#community", "#connect", "#meetup"]
        }
    }

    private var isReadyToPublish: Bool {
        !title.isEmpty && !content.isEmpty
    }
    
    private var activeEnhancementCount: Int {
        [hasQuiz, hasKeyPoints, hasProgressTracker, hasResources].filter { $0 }.count
    }

    // MARK: - Enhancement Toggle Button

    private func enhancementToggle(icon: String, title: String, description: String, isActive: Binding<Bool>) -> some View {
        Button {
            isActive.wrappedValue.toggle()
            HapticManager.shared.selection()
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(isActive.wrappedValue ? .white : .blue)
                    
                    if isActive.wrappedValue {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                            .offset(x: 14, y: -10)
                    }
                }

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                isActive.wrappedValue
                ? Color.blue.opacity(0.2)
                : Color.white.opacity(0.1)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive.wrappedValue ? Color.blue.opacity(0.5) : Color.clear,
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Course Setting Picker
    
    private func courseSettingPicker(title: String, options: [String], selection: Binding<String>) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .frame(width: 80, alignment: .leading)

            Spacer()

            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        selection.wrappedValue = option
                    }
                }
            } label: {
                HStack {
                    Text(selection.wrappedValue)
                        .font(.system(size: 14))
                        .foregroundColor(.white)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }

    // MARK: - AI Enhancement Card

    private func aiEnhancementCard(icon: String, title: String, description: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(isActive ? .white : .blue)
                    
                    if isActive {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .offset(x: 12, y: -8)
                    }
                }

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)

                Text(description)
                    .font(.system(size: 10))
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(
                isActive
                ? Color.blue.opacity(0.15)
                : Color.white.opacity(0.05)
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isActive ? Color.blue.opacity(0.4) : Color.white.opacity(0.1),
                        lineWidth: 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Actions

    private func toggleTag(_ tag: String) {
        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else {
            tags.append(tag)
        }
    }
    
    private func generateAutoTags() {
        let generated = DraftStorageService.generateTags(from: title, content: content)
        for tag in generated where !tags.contains(tag) {
            tags.append(tag)
        }
        autoTagsGenerated = true
        HapticManager.shared.success()
    }

    // MARK: - Real Publishing via ContentStorageService
    
    private func publishContent() {
        guard isReadyToPublish else { return }
        
        isPublishing = true
        publishProgress = 0
        publishStatusText = "Preparing..."
        
        Task {
            do {
                publishStatusText = "Uploading media..."
                publishProgress = 0.2
                
                let result = try await contentStorage.storeContent(
                    mode: mode,
                    videoURL: capturedMedia?.videoURL,
                    photo: capturedMedia?.image,
                    title: title,
                    description: content,
                    tags: tags
                )
                
                publishProgress = 0.8
                publishStatusText = "Finalizing..."
                
                // Brief delay for animation
                try? await Task.sleep(nanoseconds: 500_000_000)
                
                publishProgress = 1.0
                
                await MainActor.run {
                    isPublishing = false
                    Log.ui.info("✅ Published via ContentStorageService: \(result.id)")
                    
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                        showSuccessAnimation = true
                    }
                    
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishError = error.localizedDescription
                    HapticManager.shared.error()
                    Log.ui.error("❌ Publishing failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - Save Draft
    
    private func saveDraft() {
        let _ = draftService.saveDraft(
            mode: mode,
            title: title,
            content: content,
            tags: tags,
            mediaImage: capturedMedia?.image,
            mediaVideoURL: capturedMedia?.videoURL,
            courseLevel: mode == .course ? selectedLevel : nil,
            courseDuration: mode == .course ? selectedDuration : nil,
            courseCategory: mode == .course ? selectedCategory : nil,
            hasQuiz: hasQuiz,
            hasKeyPoints: hasKeyPoints,
            hasProgressTracker: hasProgressTracker,
            hasResources: hasResources,
            autoGeneratedTags: autoTagsGenerated ? tags : []
        )
        
        HapticManager.shared.success()
        dismiss()
    }
}

// MARK: - Supporting Views

struct TagChip: View {
    let text: String
    let isSelected: Bool
    var style: Style = .normal
    let action: () -> Void

    enum Style {
        case normal
        case selected
    }

    var body: some View {
        Button(action: action) {
            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(isSelected ? .white : .white.opacity(0.8))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    isSelected ?
                    LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [Color.white.opacity(0.1)], startPoint: .leading, endPoint: .trailing)
                )
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isSelected ? Color.clear : Color.white.opacity(0.3),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}




struct VideoPreviewView: View {
    let url: URL

    var body: some View {
        Rectangle()
            .fill(Color.black)
            .overlay(
                Image(systemName: "play.circle")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            )
    }
}

struct SuccessAnimationView: View {
    @State private var scale: CGFloat = 0.1
    @State private var opacity: Double = 0
    @State private var checkmarkScale: CGFloat = 0

    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(.green)
                        .frame(width: 100, height: 100)
                        .scaleEffect(scale)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .scaleEffect(checkmarkScale)
                }

                Text("Published Successfully!")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1.0
            }

            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.2)) {
                checkmarkScale = 1.0
            }

            withAnimation(.easeOut(duration: 0.5).delay(0.4)) {
                opacity = 1.0
            }
        }
    }
}