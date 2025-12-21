import SwiftUI

struct StoriesRailView: View {
    @StateObject private var storyService = StoryService.shared
    let onStorySelect: (Story) -> Void
    let onAddStory: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Stories")
                .font(.headline)
                .foregroundColor(.white) // Drawer context
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    // 1. Add Story
                    Button(action: onAddStory) {
                        AddStoryCircleView()
                    }
                    .buttonStyle(.plain)
                    
                    // 2. Stories List
                    ForEach(storyService.stories) { story in
                        Button(action: { onStorySelect(story) }) {
                            StoryCircleView(story: story, isSelected: false)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
        }
        .onAppear {
            if storyService.stories.isEmpty {
                Task {
                    await storyService.loadStories()
                }
            }
        }
    }
}
