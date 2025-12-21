import SwiftUI

struct PostEditorView: View {
    @Binding var isPresented: Bool
    @StateObject private var postService = PostService.shared
    
    @State private var content = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                TextEditor(text: $content)
                    .padding()
                    .frame(maxHeight: .infinity)
                
                if let error = errorMessage {
                    Text(error)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding()
                }
                
                if isPosting {
                    ProgressView()
                        .padding()
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Post") {
                        createPost()
                    }
                    .disabled(content.isEmpty || isPosting)
                }
            }
        }
    }
    
    private func createPost() {
        isPosting = true
        errorMessage = nil
        
        Task {
            do {
                try await postService.createPost(content: content)
                
                await MainActor.run {
                    isPosting = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isPosting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
