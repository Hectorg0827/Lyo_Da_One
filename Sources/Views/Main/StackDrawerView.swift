import SwiftUI

struct StackDrawerView: View {
    @EnvironmentObject var stackService: StackService
    @Binding var isPresented: Bool
    
    // Story State
    @State private var selectedStoryId: String?
    @State private var isStoryViewerPresented = false
    @State private var isCreateStoryPresented = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            if isPresented {
                // Dimmed background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation {
                            isPresented = false
                        }
                    }
                
                // Drawer Content
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        DesignSystem.Typography.headline("Your Stack")
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            withAnimation {
                                isPresented = false
                            }
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding()
                    
                    // Stories Rail
                    StoriesRailView(
                        onStorySelect: { story in
                            selectedStoryId = story.id
                            isStoryViewerPresented = true
                        },
                        onAddStory: {
                            isCreateStoryPresented = true
                        }
                    )
                    .padding(.bottom)
                    
                    if stackService.isLoading {
                        ProgressView()
                            .tint(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = stackService.error {
                        Text("Error: \(error)")
                            .foregroundColor(.red)
                            .padding()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(stackService.items) { item in
                                    StackItemRow(item: item)
                                }
                            }
                            .padding()
                        }
                    }
                }
                .frame(width: UIScreen.main.bounds.width * 0.85)
                .background(.ultraThinMaterial)
                .transition(.move(edge: .trailing))
            }
        }
        .fullScreenCover(isPresented: $isStoryViewerPresented) {
            if let startId = selectedStoryId {
                StoryViewer(isPresented: $isStoryViewerPresented, startingStoryId: startId)
            }
        }
        .fullScreenCover(isPresented: $isCreateStoryPresented) {
            CreateFlowEntry(initialMode: .story) { isCreateStoryPresented = false }
        }
    }
}

struct StackItemRow: View {
    let item: StackItem
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: iconName(for: item.type))
                .font(.title3)
                .foregroundColor(DesignSystem.Colors.fallbackPrimary)
                .frame(width: 40, height: 40)
                .background(DesignSystem.Colors.fallbackPrimary.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.type.rawValue.capitalized)
                    .font(.headline)
                    .foregroundColor(.white)
                if let tags = item.tags, !tags.isEmpty {
                    Text(tags.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            if item.status == .completed {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    func iconName(for type: StackItemType) -> String {
        switch type {
        case .video: return "play.rectangle"
        case .lesson: return "book"
        case .event: return "calendar"
        case .question: return "questionmark.circle"
        default: return "doc"
        }
    }
}
// Helper view to unify creation flow presentation

struct CreateFlowEntry: View {
    let initialMode: CreateMode
    let onFinish: () -> Void
    
    var body: some View {
        // If CreateHubView is available, use it; otherwise fallback to minimal CreateView
        if isCreateHubViewAvailable() {
            CreateHubView(initialMode: initialMode, onPublish: { _ in
                onFinish()
            })
        } else {
            CreateViewWrapper(initialMode: initialMode, onFinish: onFinish)
        }
    }
    
    // A runtime check if CreateHubView exists is not possible in Swift,
    // so you can toggle this manually if needed.
    private func isCreateHubViewAvailable() -> Bool {
        // Change to `false` if CreateHubView is not present in the project
        true
    }
}

private struct CreateViewWrapper: View {
    let initialMode: CreateMode
    let onFinish: () -> Void
    
    @StateObject private var viewModel = CreateViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Create new \(initialMode == .story ? "Story" : "Item")")
                    .font(.title)
                    .padding()
                Spacer()
            }
            .navigationBarTitle("Create", displayMode: .inline)
            .navigationBarItems(trailing: Button("Close") {
                onFinish()
            })
        }
        .environmentObject(viewModel)
    }
}


