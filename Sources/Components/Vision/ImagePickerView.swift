import SwiftUI
import PhotosUI

// MARK: - Image Picker View
/// Modern image picker supporting camera and photo library
struct ImagePickerView: View {

    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool

    @State private var showingActionSheet = false
    @State private var showingCamera = false
    @State private var showingPhotoLibrary = false
    @State private var showingPermissionAlert = false
    @State private var permissionMessage = ""

    var body: some View {
        EmptyView()
            .confirmationDialog("Choose Image Source", isPresented: $showingActionSheet) {
                Button("Camera") {
                    requestCameraAccess()
                }

                Button("Photo Library") {
                    requestPhotoLibraryAccess()
                }

                Button("Cancel", role: .cancel) {
                    isPresented = false
                }
            }
            .onAppear {
                showingActionSheet = true
            }
            .sheet(isPresented: $showingCamera) {
                CameraView(image: $selectedImage, isPresented: $showingCamera)
            }
            .sheet(isPresented: $showingPhotoLibrary) {
                PhotoLibraryView(image: $selectedImage, isPresented: $showingPhotoLibrary)
            }
            .alert("Permission Required", isPresented: $showingPermissionAlert) {
                Button("Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(permissionMessage)
            }
    }

    // MARK: - Permission Requests

    private func requestCameraAccess() {
        Task {
            let hasPermission = await VisionService.shared.requestCameraPermission()

            await MainActor.run {
                if hasPermission {
                    showingCamera = true
                } else {
                    permissionMessage = "Lyo needs camera access to scan images. Please enable it in Settings."
                    showingPermissionAlert = true
                }
            }
        }
    }

    private func requestPhotoLibraryAccess() {
        Task {
            let hasPermission = await VisionService.shared.requestPhotoLibraryPermission()

            await MainActor.run {
                if hasPermission {
                    showingPhotoLibrary = true
                } else {
                    permissionMessage = "Lyo needs photo library access. Please enable it in Settings."
                    showingPermissionAlert = true
                }
            }
        }
    }
}

// MARK: - Camera View
struct CameraView: UIViewControllerRepresentable {

    var image: Binding<UIImage?>?
    var onCapture: ((UIImage) -> Void)?
    @Binding var isPresented: Bool

    init(image: Binding<UIImage?>, isPresented: Binding<Bool>) {
        self.image = image
        self.onCapture = nil
        self._isPresented = isPresented
    }

    init(isPresented: Binding<Bool>, onCapture: @escaping (UIImage) -> Void) {
        self.image = nil
        self.onCapture = onCapture
        self._isPresented = isPresented
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image?.wrappedValue = image
                parent.onCapture?(image)
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Photo Library View
struct PhotoLibraryView: UIViewControllerRepresentable {

    @Binding var image: UIImage?
    @Binding var isPresented: Bool

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .photoLibrary
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: PhotoLibraryView

        init(_ parent: PhotoLibraryView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }
}

// MARK: - Scan Button
/// Quick action button for scanning images
struct ScanButton: View {

    let action: (UIImage) -> Void

    @State private var showingPicker = false
    @State private var selectedImage: UIImage?

    var body: some View {
        Button(action: {
            showingPicker = true
        }) {
            HStack(spacing: 8) {
                Image(systemName: "camera.viewfinder")
                Text("Scan Image")
            }
            .font(.subheadline.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.accentColor)
            .cornerRadius(20)
        }
        .sheet(isPresented: $showingPicker) {
            ImagePickerView(
                selectedImage: $selectedImage,
                isPresented: $showingPicker
            )
        }
        .onChange(of: selectedImage) { _, newImage in
            if let image = newImage {
                action(image)
                selectedImage = nil
            }
        }
    }
}

// MARK: - Image Analysis View
/// Full-screen view for analyzing an image
struct ImageAnalysisView: View {

    let image: UIImage
    let analysisType: VisionAnalysisType
    let onDismiss: () -> Void

    @State private var result: String?
    @State private var isAnalyzing = true
    @State private var error: LyoError?

    var body: some View {
        NavigationView {
            ZStack {
                // Background Image (blurred)
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .ignoresSafeArea()

                // Content
                VStack(spacing: 0) {
                    // Image Preview
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 10)
                        .padding()

                    // Analysis Result
                    ScrollView {
                        if isAnalyzing {
                            VStack(spacing: 16) {
                                ProgressView()
                                    .scaleEffect(1.5)

                                Text("Analyzing image...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else if let result = result {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Analysis Result")
                                    .font(.title2.bold())

                                Text(result)
                                    .font(.body)
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(12)
                            .padding()
                        } else if let error = error {
                            ErrorView(
                                error: error,
                                onRetry: { Task { await analyzeImage() } },
                                onDismiss: onDismiss
                            )
                            .padding()
                        }
                    }
                }
            }
            .navigationTitle("Image Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        onDismiss()
                    }
                }
            }
        }
        .task {
            await analyzeImage()
        }
    }

    // MARK: - Analysis

    private func analyzeImage() async {
        isAnalyzing = true
        error = nil

        do {
            let visionResult = try await VisionService.shared.analyzeImage(image, type: analysisType)
            result = visionResult.analysis
        } catch let lyoError as LyoError {
            error = lyoError
        } catch {
            self.error = LyoError.from(error: error)
        }

        isAnalyzing = false
    }
}

// MARK: - Preview
#Preview {
    VStack {
        ScanButton { image in
            print("Scanned image: \(image.size)")
        }
    }
}
