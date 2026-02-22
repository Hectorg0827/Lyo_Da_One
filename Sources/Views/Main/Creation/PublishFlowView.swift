import SwiftUI
import AVFoundation

// MARK: - Publish Flow View

struct PublishFlowView: View {
    @Environment(\.dismiss) var dismiss

    let mode: CreateMode
    let capturedMedia: CapturedMedia?
    @ObservedObject var contentStorage: ContentStorageService
    let onComplete: () -> Void

    // State
    @State private var title = ""
    @State private var description = ""
    @State private var tags: [String] = []
    @State private var isPublishing = false
    @State private var publishError: String?
    @State private var showSuccess = false

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
                        // Media Preview
                        mediaPreviewSection

                        // Content Input
                        contentInputSection

                        // Tags Section
                        tagsSection

                        // Publish Button
                        publishButtonSection

                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }
            }
            .navigationTitle("Publish \(mode.displayName)")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .preferredColorScheme(.dark)
        .overlay(
            // Publishing overlay
            Group {
                if isPublishing {
                    publishingOverlay
                }
            }
        )
        .overlay(
            // Success animation
            Group {
                if showSuccess {
                    successOverlay
                }
            }
        )
        .alert("Publishing Error", isPresented: Binding(get: { publishError != nil }, set: { _ in publishError = nil })) {
            Button("OK") { }
        } message: {
            Text(publishError ?? "Unknown error occurred")
        }
    }

    // MARK: - Media Preview Section

    @ViewBuilder
    private var mediaPreviewSection: some View {
        if let media = capturedMedia {
            VStack(alignment: .leading, spacing: 12) {
                Text("Preview")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 200)

                    if let image = media.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 200)
                            .clipped()
                            .cornerRadius(16)
                    } else if let videoURL = media.videoURL {
                        VideoThumbnailView(url: videoURL)
                            .frame(height: 200)
                            .cornerRadius(16)

                        // Play button overlay
                        Button {
                            // Play video preview
                        } label: {
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

                // Media info
                HStack {
                    Image(systemName: mode.iconName)
                        .font(.system(size: 16))
                        .foregroundColor(mode.color)

                    Text(mode.displayName)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)

                    Spacer()

                    if let videoURL = media.videoURL {
                        Text(formatDuration(videoURL))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
        }
    }

    // MARK: - Content Input Section

    private var contentInputSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Content Details")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // Title
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

            // Description (for non-story modes)
            if mode != .story {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))

                    TextEditor(text: $description)
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                        .frame(height: 100)
                        .scrollContentBackground(.hidden)
                        .padding(16)
                        .background(.ultraThinMaterial)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
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
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            // Suggested tags
            VStack(alignment: .leading, spacing: 12) {
                Text("Suggested")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.8))

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
            }

            // Selected tags
            if !tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Selected")
                        .font(.system(size: 14, weight: .semibold))
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

    // MARK: - Publish Button Section

    private var publishButtonSection: some View {
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
                isReadyToPublish && !isPublishing ?
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

                Text("Publishing your \(mode.displayName.lowercased())...")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)

                Text("\(Int(contentStorage.uploadProgress * 100))% complete")
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.7))

                ProgressView(value: contentStorage.uploadProgress)
                    .progressViewStyle(LinearProgressViewStyle(tint: mode.color))
                    .frame(width: 200)
            }
        }
    }

    // MARK: - Success Overlay

    private var successOverlay: some View {
        ZStack {
            Color.black.opacity(0.9)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // Success animation
                ZStack {
                    Circle()
                        .fill(mode.gradient)
                        .frame(width: 100, height: 100)

                    Image(systemName: "checkmark")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                }
                .scaleEffect(showSuccess ? 1.0 : 0.1)
                .animation(.spring(response: 0.6, dampingFraction: 0.8), value: showSuccess)

                VStack(spacing: 8) {
                    Text("Published Successfully!")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)

                    Text("Your \(mode.displayName.lowercased()) is now live on Lyo")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                .opacity(showSuccess ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.3), value: showSuccess)

                Button("View in \(destinationFeedName)") {
                    onComplete()
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(mode.color)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1))
                .cornerRadius(25)
                .opacity(showSuccess ? 1.0 : 0.0)
                .animation(.easeOut(duration: 0.5).delay(0.6), value: showSuccess)
            }
        }
    }

    // MARK: - Helper Properties

    private var isReadyToPublish: Bool {
        !title.isEmpty
    }

    private var suggestedTags: [String] {
        switch mode {
        case .clip, .reel:
            return ["#learning", "#education", "#tutorial", "#tips", "#knowledge"]
        case .story:
            return ["#dailylearning", "#progress", "#insights", "#motivation"]
        case .course:
            return ["#course", "#comprehensive", "#structured", "#certification"]
        case .post:
            return ["#discussion", "#question", "#insight", "#community"]
        case .live:
            return ["#live", "#interactive", "#teaching", "#QnA"]
        case .event:
            return ["#event", "#community", "#connect", "#meetup"]
        }
    }

    private var destinationFeedName: String {
        switch mode {
        case .clip, .reel: return "Clips"
        case .story: return "Stories"
        case .post: return "Posts"
        case .course: return "Courses"
        case .live: return "Live"
        case .event: return "Events"
        }
    }

    // MARK: - Actions

    private func toggleTag(_ tag: String) {
        if tags.contains(tag) {
            tags.removeAll { $0 == tag }
        } else {
            tags.append(tag)
        }
        HapticManager.shared.light()
    }

    private func formatDuration(_ videoURL: URL) -> String {
        // Get video duration
        let asset = AVAsset(url: videoURL)
        let duration = CMTimeGetSeconds(asset.duration)

        if duration < 60 {
            return String(format: "%.0fs", duration)
        } else {
            let minutes = Int(duration) / 60
            let seconds = Int(duration) % 60
            return String(format: "%d:%02ds", minutes, seconds)
        }
    }

    private func publishContent() {
        guard let media = capturedMedia else { return }

        isPublishing = true

        Task {
            do {
                let _ = try await contentStorage.storeContent(
                    mode: mode,
                    videoURL: media.videoURL,
                    photo: media.image,
                    title: title,
                    description: description,
                    tags: tags
                )

                await MainActor.run {
                    isPublishing = false
                    showSuccess = true

                    // Auto dismiss after success animation
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        onComplete()
                    }
                }

            } catch {
                await MainActor.run {
                    isPublishing = false
                    publishError = error.localizedDescription
                    Log.media.error("Publishing failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Video Thumbnail View

struct VideoThumbnailView: View {
    let url: URL
    @State private var thumbnail: UIImage?

    var body: some View {
        Group {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    )
            }
        }
        .onAppear {
            generateThumbnail()
        }
    }

    private func generateThumbnail() {
        Task {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 400, height: 400)

            let time = CMTime(seconds: 0.5, preferredTimescale: 600)

            do {
                let cgImage = try await imageGenerator.image(at: time).image
                await MainActor.run {
                    self.thumbnail = UIImage(cgImage: cgImage)
                }
            } catch {
                Log.media.warning("Failed to generate video thumbnail: \(error)")
            }
        }
    }
}

// MARK: - Create Mode Extensions

extension CreateMode {
    var iconName: String {
        switch self {
        case .clip: return "video.fill"
        case .reel: return "play.rectangle.fill"
        case .story: return "camera.fill"
        case .course: return "graduationcap.fill"
        case .post: return "square.and.pencil"
        case .live: return "dot.radiowaves.left.and.right"
        case .event: return "person.3.fill"
        }
    }
}