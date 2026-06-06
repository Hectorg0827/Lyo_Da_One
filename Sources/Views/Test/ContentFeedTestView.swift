import SwiftUI

// MARK: - Content Feed Test View

/// Test view to verify that created content appears in the correct feeds
struct ContentFeedTestView: View {
    @StateObject private var contentStorage = ContentStorageService.shared
    @StateObject private var storyService = StoryService.shared
    @StateObject private var discoveryService = DiscoveryService.shared

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Recent Content Summary
                    recentContentSection

                    // Stories Section
                    storiesSection

                    // Discovery/Clips Section
                    discoverySection

                    // Debug Info
                    debugSection
                }
                .padding()
            }
            .navigationTitle("Content Feed Test")
            .refreshable {
                await refreshAllFeeds()
            }
        }
    }

    // MARK: - Recent Content Section

    private var recentContentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Created Content")
                .font(.headline)
                .foregroundColor(.primary)

            if contentStorage.recentContent.isEmpty {
                Text("No content created yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(contentStorage.recentContent.prefix(6)) { content in
                        ContentCard(content: content)
                    }
                }
            }
        }
    }

    // MARK: - Stories Section

    private var storiesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Stories Feed")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(storyService.stories.count) stories")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if storyService.stories.isEmpty {
                Text("No stories available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(storyService.stories) { story in
                            StoryTestCard(story: story)
                        }
                    }
                    .padding(.horizontal)
                }
            }

            // My Story
            if let myStory = storyService.myStory {
                VStack(alignment: .leading, spacing: 8) {
                    Text("My Story")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    StoryTestCard(story: myStory, isMyStory: true)
                }
            }
        }
    }

    // MARK: - Discovery Section

    private var discoverySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Discovery/Clips Feed")
                    .font(.headline)
                    .foregroundColor(.primary)

                Spacer()

                Text("\(discoveryService.myDiscoveries.count) discoveries")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if discoveryService.myDiscoveries.isEmpty {
                Text("No discoveries available")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    ForEach(discoveryService.myDiscoveries.prefix(4)) { discovery in
                        DiscoveryTestCard(discovery: discovery)
                    }
                }
            }
        }
    }

    // MARK: - Debug Section

    private var debugSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Debug Info")
                .font(.headline)
                .foregroundColor(.primary)

            VStack(alignment: .leading, spacing: 8) {
                debugRow("Upload Progress", "\(Int(contentStorage.uploadProgress * 100))%")
                debugRow("Is Uploading", contentStorage.isUploading ? "Yes" : "No")
                debugRow("Last Upload", contentStorage.lastUploadedContent?.title ?? "None")
                debugRow("Mock Mode", AppConfig.allowMockFallbacks ? "Enabled" : "Disabled")
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            Button("Clear All Content") {
                contentStorage.clearContent()
            }
            .foregroundColor(.red)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.red.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private func debugRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }

    // MARK: - Actions

    private func refreshAllFeeds() async {
        await storyService.loadStories()
        await discoveryService.loadMyDiscoveries()
    }
}

// MARK: - Content Cards

struct ContentCard: View {
    let content: CreatedContent

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: content.type.iconName)
                    .font(.caption)
                    .foregroundColor(content.type.color)

                Text(content.type.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)

                Spacer()
            }

            Text(content.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack {
                Text(formatDate(content.createdAt))
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Spacer()

                if !content.tags.isEmpty {
                    Text(content.tags.first ?? "")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(content.type.color, lineWidth: 1)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct StoryTestCard: View {
    let story: Story
    var isMyStory: Bool = false

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(isMyStory ? Color.blue : Color.purple)
                .frame(width: 60, height: 60)
                .overlay(
                    Text(String(story.userName.prefix(1)).uppercased())
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            Text(isMyStory ? "You" : story.userName)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)

            if story.isLive {
                Text("LIVE")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.red)
                    .cornerRadius(4)
            }
        }
        .frame(width: 80)
    }
}

struct DiscoveryTestCard: View {
    let discovery: Discovery

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 100)
                .cornerRadius(8)
                .overlay(
                    Image(systemName: "video.fill")
                        .font(.title)
                        .foregroundColor(.white)
                )

            Text(discovery.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(2)

            HStack {
                Image(systemName: "heart")
                    .font(.caption)
                Text("\(discovery.likes)")
                    .font(.caption)

                Spacer()

                Image(systemName: "eye")
                    .font(.caption)
                Text("\(discovery.views)")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}

// MARK: - Content Type Extensions

extension StorageContentType {
    var iconName: String {
        switch self {
        case .clip: return "video.fill"
        case .reel: return "play.rectangle.fill"
        case .story: return "camera.fill"
        case .post: return "square.and.pencil"
        case .course: return "graduationcap.fill"
        case .live: return "dot.radiowaves.left.and.right"
        }
    }

    var color: Color {
        switch self {
        case .clip: return .blue
        case .reel: return .red
        case .story: return .purple
        case .post: return .orange
        case .course: return .cyan
        case .live: return .pink
        }
    }
}

// MARK: - Preview

#Preview {
    ContentFeedTestView()
}