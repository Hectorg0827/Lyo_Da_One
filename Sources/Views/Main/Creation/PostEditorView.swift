import SwiftUI
import PhotosUI

struct PostEditorView: View {
    @Binding var isPresented: Bool
    @StateObject private var postService = PostService.shared
    
    @State private var content = ""
    @State private var isPosting = false
    @State private var errorMessage: String?
    
    // Media Selection
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var isImageLoading = false
    
    // Haptics
    private let haptics = HapticManager.shared
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0f172a").ignoresSafeArea() // Match app theme
                
                ScrollView {
                    VStack(spacing: 20) {
                        // MARK: - Media Picker Section
                        mediaSelectionSection
                        
                        // MARK: - Caption Section
                        captionSection
                        
                        if let error = errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .font(.caption)
                                .padding(.horizontal)
                        }
                    }
                    .padding()
                }
                
                if isPosting {
                    ZStack {
                        Color.black.opacity(0.5).ignoresSafeArea()
                        VStack(spacing: 16) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.5)
                            Text("Sharing Post...")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .cornerRadius(16)
                    }
                }
            }
            .navigationTitle("Create Post")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        haptics.light()
                        isPresented = false
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Share") {
                        createPost()
                    }
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(isReadyToPost ? Color(hex: "6366F1") : .gray)
                    .disabled(!isReadyToPost || isPosting)
                }
            }
            // Auto-trigger picker if we want Instagram-like feel? 
            // In Instagram, you don't even see the modal first, you see a grid.
            // But standard PhotosPicker is close enough for native implementation.
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Media Selection
    
    private var mediaSelectionSection: some View {
        VStack {
            if let image = selectedImage {
                // Interactive Preview
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    // Remove Image Button
                    Button {
                        haptics.selection()
                        withAnimation {
                            selectedImage = nil
                            selectedItem = nil
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .background(Circle().fill(Color.black.opacity(0.5)))
                    }
                    .padding(12)
                }
            } else {
                // Empty State Picker
                PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .frame(height: 200)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 2, dash: [8]))
                            )
                        
                        VStack(spacing: 12) {
                            if isImageLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 40))
                                    .foregroundColor(.white.opacity(0.5))
                                
                                Text("Select a Photo")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                }
                .onChange(of: selectedItem) { _, newItem in
                    Task {
                        await loadTransferable(from: newItem)
                    }
                }
            }
        }
    }
    
    // MARK: - Caption Section
    
    private var captionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Caption")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
            
            TextEditor(text: $content)
                .frame(minHeight: 120)
                .scrollContentBackground(.hidden)
                .font(.system(size: 16))
                .foregroundColor(.white)
                .padding(12)
                .background(Color.white.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
        }
    }
    
    // MARK: - Helpers
    
    private var isReadyToPost: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || selectedImage != nil
    }
    
    private func loadTransferable(from item: PhotosPickerItem?) async {
        guard let item = item else { return }
        
        isImageLoading = true
        do {
            if let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                await MainActor.run {
                    withAnimation {
                        self.selectedImage = image
                        self.isImageLoading = false
                    }
                }
            } else {
                await MainActor.run { isImageLoading = false }
            }
        } catch {
            print("Failed to load image: \(error.localizedDescription)")
            await MainActor.run { isImageLoading = false }
        }
    }
    
    private func createPost() {
        haptics.medium()
        isPosting = true
        errorMessage = nil
        
        Task {
            do {
                var finalMediaURLs: [String] = []
                
                // Upload Image if present
                if let image = selectedImage {
                    let mediaURL = try await postService.uploadPostMedia(image: image)
                    finalMediaURLs.append(mediaURL)
                }
                
                try await postService.createPost(content: content, mediaURLs: finalMediaURLs)
                
                await MainActor.run {
                    haptics.success()
                    isPosting = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    haptics.error()
                    isPosting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}
