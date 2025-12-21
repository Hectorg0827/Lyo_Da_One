import SwiftUI
import AVFoundation
import PhotosUI


struct VideoRecorderView: View {
    @Binding var isPresented: Bool
    @StateObject private var storyService = StoryService.shared
    @StateObject private var discoveryService = DiscoveryService.shared
    @StateObject private var cameraManager = CameraManager()
    
    @State private var isUploading = false
    @State private var uploadError: String?
    @State private var selectedItem: PhotosPickerItem?
    
    // Mode: Story or Discovery
    var mode: CreationOption
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            // Camera Preview
            if cameraManager.permissionGranted {
                CameraPreview(session: cameraManager.session)
                    .ignoresSafeArea()
            } else {
                Text("Camera Permission Required")
                    .foregroundColor(.white)
                    .onAppear {
                        cameraManager.checkPermissions()
                    }
            }
            
            // Controls
            VStack {
                HStack {
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding()
                    }
                    Spacer()
                }
                
                Spacer()
                
                
                // Gallery Picker
                PhotosPicker(selection: $selectedItem, matching: .videos) {
                    VStack {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title2)
                        Text("Upload")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                }
                .onChange(of: selectedItem) { newItem in
                    Task {
                        if let data = try? await newItem?.loadTransferable(type: Data.self) {
                            // Save to temporary file for upload
                            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
                            try? data.write(to: tempURL)
                            uploadVideo(url: tempURL)
                        }
                    }
                }
                .padding(.bottom, 20)
                
                // Record Button
                Button(action: {
                    if cameraManager.isRecording {
                        cameraManager.stopRecording()
                    } else {
                        cameraManager.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .stroke(Color.white, lineWidth: 4)
                            .frame(width: 80, height: 80)
                        
                        Circle()
                            .fill(cameraManager.isRecording ? Color.red : Color.white)
                            .frame(width: cameraManager.isRecording ? 40 : 70, height: cameraManager.isRecording ? 40 : 70)
                    }
                }
                .padding(.bottom, 30)
            }
            
            if isUploading {
                Color.black.opacity(0.7).ignoresSafeArea()
                ProgressView("Uploading...")
                    .foregroundColor(.white)
            }
        }
        .onChange(of: cameraManager.recordedVideoURL) { newValue in
            if let url = newValue {
                uploadVideo(url: url)
            }
        }
        .alert("Error", isPresented: Binding(get: { uploadError != nil }, set: { _ in uploadError = nil })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(uploadError ?? "Unknown error")
        }
    }
    
    private func uploadVideo(url: URL) {
        isUploading = true
        uploadError = nil
        
        Task {
            do {
                if mode == .story {
                    let mediaURL = try await storyService.uploadStoryMedia(videoURL: url)
                    try await storyService.addStory(mediaURL: mediaURL)
                } else {
                    let mediaURL = try await discoveryService.uploadDiscoveryVideo(videoURL: url)
                    try await discoveryService.addDiscovery(title: "My New Discovery", videoURL: mediaURL)
                }
                
                await MainActor.run {
                    isUploading = false
                    isPresented = false
                }
            } catch {
                await MainActor.run {
                    isUploading = false
                    uploadError = error.localizedDescription
                }
            }
        }
    }
}

