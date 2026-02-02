import SwiftUI
import AVKit
import PhotosUI
import UIKit

struct CreateStoryView: View {
    @Binding var isPresented: Bool
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var storyService = StoryService.shared
    
    // UI State
    @State private var showPermissionsError = false
    @State private var selectedMediaItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var caption: String = ""
    @State private var isUploading = false
    
    // Preview
    @State private var showPreview = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if showPreview {
                // MARK: - Preview & Upload Screen
                previewLayer
            } else {
                // MARK: - Camera & Capture Screen
                cameraLayer
            }
            
            // Loading Overlay
            if isUploading {
                Color.black.opacity(0.7).ignoresSafeArea()
                ProgressView("Posting...")
                    .tint(.white)
                    .foregroundColor(.white)
            }
        }
        .onAppear {
            cameraManager.checkPermissions()
        }
        .onChange(of: cameraManager.permissionGranted) { granted in
            if !granted {
                showPermissionsError = true
            }
        }
        .onChange(of: selectedMediaItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.selectedImage = image
                        self.selectedVideoURL = nil
                        self.showPreview = true
                    }
                } else if let movie = try? await newItem?.loadTransferable(type: VideoTransferable.self) {
                     await MainActor.run {
                        self.selectedVideoURL = movie.url
                        self.selectedImage = nil
                        self.showPreview = true
                    }
                }
            }
        }
        // Handle captured photo/video from CameraManager
        .onReceive(cameraManager.$recordedVideoURL) { url in
            if let url = url {
                self.selectedVideoURL = url
                self.selectedImage = nil
                self.showPreview = true
            }
        }
    }
    
    // MARK: - Camera Layer
    
    var cameraLayer: some View {
        VStack {
            // Header
            HStack {
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                Spacer()
                
                Button(action: cameraManager.switchCamera) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.title2)
                        .foregroundColor(.white)
                        .padding()
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding()
            
            Spacer()
            
            // Camera Preview
            if cameraManager.permissionGranted {
                CameraPreview(session: cameraManager.session)
                    .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width * 16/9)
                    .cornerRadius(20)
                    .clipped()
            } else {
                Text("Camera access required")
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Controls
            HStack(spacing: 40) {
                // Gallery Picker
                PhotosPicker(selection: $selectedMediaItem, matching: .any(of: [.images, .videos])) {
                    Image(systemName: "photo.on.rectangle")
                        .font(.title)
                        .foregroundColor(.white)
                }
                
                // Shutter Button
                ZStack {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    if cameraManager.isRecording {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.red)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 65, height: 65)
                    }
                }
                .onTapGesture {
                    // Tap for photo disabled for now if only video supported, 
                    // or implement photo capture in manager
                    // For now let's assume video holding
                }
                .onLongPressGesture(minimumDuration: 0.5, pressing: { pressing in
                    if pressing {
                        cameraManager.startRecording()
                    } else {
                         cameraManager.stopRecording()
                    }
                }) {}
                
                Spacer()
                    .frame(width: 40)
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Preview Layer
    
    var previewLayer: some View {
        VStack {
            Spacer()
            
            // Media Display
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(20)
            } else if let url = selectedVideoURL {
                VideoPlayer(player: AVPlayer(url: url))
                    .scaledToFit()
                    .cornerRadius(20)
            }
            
            // Caption
            TextField("Add a caption...", text: $caption)
                .padding()
                .background(.ultraThinMaterial)
                .cornerRadius(12)
                .foregroundColor(.white)
                .padding()
            
            // Action Buttons
            HStack {
                Button("Retake") {
                    cameraManager.cleanup() // Reset
                    showPreview = false
                    selectedImage = nil
                    selectedVideoURL = nil
                    // Resume session
                    cameraManager.checkPermissions() 
                }
                .foregroundColor(.white)
                .padding()
                
                Spacer()
                
                Button("Post Your Story") {
                    postStory()
                }
                .font(.headline)
                .foregroundColor(.black)
                .padding()
                .background(Color.white)
                .cornerRadius(20)
            }
            .padding()
            
            Spacer()
        }
    }
    
    // MARK: - Actions
    
    func postStory() {
        guard !isUploading else { return }
        isUploading = true
        
        Task {
            do {
                var mediaURL = ""
                var type: Story.MediaType = .image
                
                if let videoURL = selectedVideoURL {
                    type = .video
                    mediaURL = try await storyService.uploadStoryMedia(videoURL: videoURL)
                } else if let image = selectedImage {
                    type = .image
                    mediaURL = try await storyService.uploadStoryMedia(image: image)
                } else {
                    return // Nothing to post
                }
                
                try await storyService.addStory(
                    mediaURL: mediaURL,
                    mediaType: type,
                    caption: caption.isEmpty ? nil : caption
                )
                
                isUploading = false
                isPresented = false
            } catch {
                print("Failed to post story: \(error)")
                isUploading = false
                // Handle error alert
            }
        }
    }
}
