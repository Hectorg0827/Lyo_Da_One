import AVFoundation
import AVKit
import Combine
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// Production creation surface.
///
/// The active Create Hub now exposes only operations backed by a working local
/// capture or server publishing path. The former placeholder camera, fake video
/// preview, empty filters, and decorative editing controls are intentionally not
/// part of this screen.
struct CreateHubView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @StateObject private var viewModel: CreateViewModel
    @StateObject private var camera = CreateCameraController()

    @State private var selectedPickerItem: PhotosPickerItem?
    @State private var showMediaPicker = false
    @State private var isLoadingSelection = false
    @State private var isCapturingPhoto = false

    let onPublish: ((CreateMode) -> Void)?

    init(initialMode: CreateMode = .reel, onPublish: ((CreateMode) -> Void)? = nil) {
        let supportedInitialMode: CreateMode = initialMode == .live ? .reel : initialMode
        _viewModel = StateObject(wrappedValue: CreateViewModel(initialMode: supportedInitialMode))
        self.onPublish = onPublish
    }

    var body: some View {
        ZStack {
            background

            if viewModel.selectedMode.requiresCamera {
                LinearGradient(
                    colors: [.clear, .black.opacity(0.2), .black.opacity(0.92)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            VStack(spacing: 0) {
                topBar

                if viewModel.selectedMode.requiresCamera {
                    cameraWorkspace
                } else {
                    editorWorkspace
                }

                CreateModePicker(
                    selectedMode: $viewModel.selectedMode,
                    onModeSelected: selectMode
                )
            }

            if viewModel.state == .uploading {
                uploadingOverlay
            }

            if case .error(let message) = viewModel.state {
                errorOverlay(message: message)
            }
        }
        .preferredColorScheme(.dark)
        .photosPicker(
            isPresented: $showMediaPicker,
            selection: $selectedPickerItem,
            matching: pickerFilter
        )
        .onChange(of: selectedPickerItem) { _, item in
            guard let item else { return }
            Task { await loadSelectedMedia(item) }
        }
        .onReceive(camera.$capturedImage.compactMap { $0 }) { image in
            isCapturingPhoto = false
            viewModel.capturePhoto(image)
        }
        .onReceive(camera.$recordedVideoURL.compactMap { $0 }) { url in
            viewModel.captureVideo(url)
        }
        .onReceive(camera.$recordingDuration) { duration in
            viewModel.recordingDuration = duration
        }
        .onReceive(camera.$errorMessage.compactMap { $0 }) { message in
            isCapturingPhoto = false
            viewModel.state = .error(message)
        }
        .onChange(of: viewModel.state) { _, state in
            if state == .complete {
                onPublish?(viewModel.selectedMode)
                dismiss()
            }
        }
        .onAppear {
            if viewModel.selectedMode.requiresCamera {
                camera.startSession()
            }
        }
        .onDisappear {
            camera.cleanup()
        }
    }

    // MARK: - Background

    @ViewBuilder
    private var background: some View {
        if viewModel.selectedMode.requiresCamera {
            if let image = viewModel.capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .ignoresSafeArea()
            } else if let videoURL = viewModel.capturedVideoURL {
                CreateCapturedVideoPreview(url: videoURL)
                    .id(videoURL)
                    .ignoresSafeArea()
            } else if camera.cameraPermissionGranted {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()
            } else {
                cameraPermissionBackground
            }
        } else {
            LinearGradient(
                colors: [Color(hex: "07080F"), viewModel.selectedMode.color.opacity(0.34)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }

    private var cameraPermissionBackground: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                Text("Camera access is required")
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("Enable camera access to capture a Story or Clip, or choose existing media from your library.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Button("Open Settings") {
                    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
                    openURL(settingsURL)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 12) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 42, height: 42)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .accessibilityLabel("Close Create Hub")

            Spacer()

            VStack(spacing: 2) {
                Text("Create")
                    .font(.headline.weight(.bold))
                Text(viewModel.selectedMode.description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.66))
            }

            Spacer()

            if viewModel.selectedMode.requiresCamera,
               viewModel.capturedImage == nil,
               viewModel.capturedVideoURL == nil {
                HStack(spacing: 8) {
                    if camera.torchAvailable {
                        Button {
                            camera.toggleTorch()
                        } label: {
                            Image(systemName: camera.isTorchOn ? "bolt.fill" : "bolt.slash.fill")
                                .font(.system(size: 16, weight: .bold))
                                .frame(width: 42, height: 42)
                                .background(.ultraThinMaterial, in: Circle())
                        }
                        .disabled(camera.isRecording)
                        .accessibilityLabel(camera.isTorchOn ? "Turn camera light off" : "Turn camera light on")
                    }

                    Button {
                        camera.switchCamera()
                    } label: {
                        Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                            .font(.system(size: 17, weight: .bold))
                            .frame(width: 42, height: 42)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .disabled(camera.isRecording)
                    .accessibilityLabel("Switch camera")
                }
            } else {
                Color.clear.frame(width: 42, height: 42)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Camera workflow

    private var cameraWorkspace: some View {
        VStack(spacing: 14) {
            if camera.isRecording {
                HStack(spacing: 8) {
                    Circle()
                        .fill(.red)
                        .frame(width: 9, height: 9)
                    Text(camera.formattedDuration)
                        .monospacedDigit()
                        .font(.subheadline.weight(.bold))
                    Text("/ 3:00")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer(minLength: 8)

            if hasCapturedMedia {
                capturedMediaMetadata
                    .padding(.horizontal, 16)
            }

            cameraActions
                .padding(.horizontal, 22)
                .padding(.bottom, 8)
        }
    }

    @ViewBuilder
    private var capturedMediaMetadata: some View {
        if viewModel.selectedMode == .clip || viewModel.selectedMode == .reel {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Clip title", text: $viewModel.clipTitle)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .padding(12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                TextField("Description (optional)", text: $viewModel.clipDescription, axis: .vertical)
                    .lineLimit(2...4)
                    .padding(12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                Menu {
                    Button("No subject") { viewModel.clipSubject = nil }
                    ForEach(ClipSubject.allCases) { subject in
                        Button(subject.rawValue) { viewModel.clipSubject = subject }
                    }
                } label: {
                    HStack {
                        Image(systemName: viewModel.clipSubject?.icon ?? "square.grid.2x2")
                        Text(viewModel.clipSubject?.rawValue ?? "Choose a subject")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        } else {
            HStack(spacing: 10) {
                Image(systemName: viewModel.capturedImage == nil ? "video.fill" : "photo.fill")
                    .foregroundStyle(viewModel.selectedMode.color)
                Text("Ready to share your Story")
                    .font(.subheadline.weight(.semibold))
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        }
    }

    private var cameraActions: some View {
        Group {
            if hasCapturedMedia {
                HStack(spacing: 12) {
                    Button {
                        retakeMedia()
                    } label: {
                        Label("Retake", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CreateSecondaryButtonStyle())

                    Button {
                        Task { await viewModel.publish() }
                    } label: {
                        Label("Publish", systemImage: "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(CreatePrimaryButtonStyle(color: viewModel.selectedMode.color))
                    .disabled(!canPublishCapturedMedia)
                }
            } else {
                HStack(alignment: .center) {
                    Button {
                        showMediaPicker = true
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title3.weight(.semibold))
                            Text("Library")
                                .font(.caption.weight(.semibold))
                        }
                        .frame(width: 72)
                    }
                    .disabled(camera.isRecording || isLoadingSelection)

                    Spacer()

                    Button {
                        captureAction()
                    } label: {
                        ZStack {
                            Circle()
                                .stroke(.white.opacity(0.9), lineWidth: 4)
                                .frame(width: 84, height: 84)

                            if isCapturingPhoto {
                                ProgressView()
                                    .tint(.white)
                            } else if viewModel.selectedMode == .story {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 68, height: 68)
                            } else {
                                RoundedRectangle(cornerRadius: camera.isRecording ? 10 : 36)
                                    .fill(.red)
                                    .frame(
                                        width: camera.isRecording ? 42 : 68,
                                        height: camera.isRecording ? 42 : 68
                                    )
                                    .animation(.spring(response: 0.25), value: camera.isRecording)
                            }
                        }
                    }
                    .disabled(!camera.cameraPermissionGranted || isCapturingPhoto || isLoadingSelection)
                    .accessibilityLabel(captureAccessibilityLabel)

                    Spacer()

                    VStack(spacing: 5) {
                        Image(systemName: viewModel.selectedMode == .story ? "camera.fill" : "video.fill")
                            .font(.title3.weight(.semibold))
                        Text(viewModel.selectedMode == .story ? "Photo" : "Video")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(width: 72)
                    .foregroundStyle(.white.opacity(0.72))
                }
                .foregroundStyle(.white)
            }
        }
    }

    private func captureAction() {
        if viewModel.selectedMode == .story {
            isCapturingPhoto = true
            camera.capturePhoto()
            return
        }

        if camera.isRecording {
            camera.stopRecording()
            viewModel.stopRecording()
        } else {
            camera.startRecording()
            viewModel.startRecording()
        }
    }

    private func retakeMedia() {
        camera.resetCapturedMedia()
        viewModel.capturedImage = nil
        viewModel.capturedVideoURL = nil
        viewModel.state = .idle
        viewModel.progress = 0
        camera.startSession()
    }

    // MARK: - Non-camera editors

    private var editorWorkspace: some View {
        ScrollView(showsIndicators: false) {
            Group {
                switch viewModel.selectedMode {
                case .post:
                    postEditor
                case .course:
                    courseEditor
                case .event:
                    eventEditor
                default:
                    EmptyView()
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var postEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorTitle("Share a useful idea", subtitle: "Your post will be saved to the shared Community feed.")

            TextEditor(text: $viewModel.contentText)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 190)
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                .overlay(alignment: .bottomTrailing) {
                    Text("\(viewModel.charCount)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.45))
                        .padding(10)
                }

            Button {
                showMediaPicker = true
            } label: {
                Label("Attach photo or video", systemImage: "paperclip")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(CreateSecondaryButtonStyle())

            if !viewModel.attachedFiles.isEmpty {
                VStack(spacing: 8) {
                    ForEach(viewModel.attachedFiles, id: \.self) { fileURL in
                        HStack(spacing: 10) {
                            Image(systemName: fileURL.pathExtension.lowercased() == "mov" || fileURL.pathExtension.lowercased() == "mp4" ? "video.fill" : "photo.fill")
                            Text(fileURL.lastPathComponent)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Button {
                                removeAttachment(fileURL)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                            }
                            .accessibilityLabel("Remove attachment")
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            publishButton(title: "Publish Post", enabled: !trimmed(viewModel.contentText).isEmpty)
        }
        .createEditorCard()
    }

    private var courseEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorTitle("Build an AI course", subtitle: "LYO will generate the real curriculum through the course-generation service.")

            TextField("Course topic", text: $viewModel.courseTopic)
                .padding(13)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))

            VStack(alignment: .leading, spacing: 8) {
                Text("Difficulty")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.65))

                Picker("Difficulty", selection: $viewModel.courseLevel) {
                    Text("Beginner").tag("beginner")
                    Text("Intermediate").tag("intermediate")
                    Text("Advanced").tag("advanced")
                }
                .pickerStyle(.segmented)
            }

            Text("No placeholder outline is shown. The modules displayed after publishing come from the generated server course.")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.58))

            publishButton(title: "Generate Course", enabled: !trimmed(viewModel.courseTopic).isEmpty)
        }
        .createEditorCard()
    }

    private var eventEditor: some View {
        VStack(alignment: .leading, spacing: 16) {
            editorTitle("Create a learning gathering", subtitle: "Create a real virtual event or study group in Community.")

            Picker("Type", selection: $viewModel.isGroup) {
                Text("Event").tag(false)
                Text("Study Group").tag(true)
            }
            .pickerStyle(.segmented)

            TextField(viewModel.isGroup ? "Group name" : "Event title", text: $viewModel.eventTitle)
                .padding(13)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))

            TextEditor(text: $viewModel.eventDescription)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .padding(12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 13))

            DatePicker(
                "Starts",
                selection: $viewModel.eventDate,
                in: Date()...,
                displayedComponents: [.date, .hourAndMinute]
            )
            .datePickerStyle(.compact)

            Label("Virtual location", systemImage: "video.fill")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.white.opacity(0.62))

            publishButton(
                title: viewModel.isGroup ? "Create Study Group" : "Create Event",
                enabled: !trimmed(viewModel.eventTitle).isEmpty
            )
        }
        .createEditorCard()
        .onAppear {
            // The current API model supports a truthful virtual location. A typed
            // address is not exposed until geocoding/coordinates are implemented.
            viewModel.eventLocation = ""
        }
    }

    private func editorTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.title3.weight(.bold))
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.62))
        }
    }

    private func publishButton(title: String, enabled: Bool) -> some View {
        Button {
            Task { await viewModel.publish() }
        } label: {
            Label(title, systemImage: "paperplane.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(CreatePrimaryButtonStyle(color: viewModel.selectedMode.color))
        .disabled(!enabled)
    }

    // MARK: - Media library

    private var pickerFilter: PHPickerFilter {
        switch viewModel.selectedMode {
        case .story, .post:
            return .any(of: [.images, .videos])
        case .clip, .reel:
            return .videos
        default:
            return .any(of: [.images, .videos])
        }
    }

    @MainActor
    private func loadSelectedMedia(_ item: PhotosPickerItem) async {
        isLoadingSelection = true
        defer {
            isLoadingSelection = false
            selectedPickerItem = nil
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw CreateHubMediaError.unreadableSelection
            }

            let contentType = item.supportedContentTypes.first ?? .data
            let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
            let fileExtension = contentType.preferredFilenameExtension ?? (isVideo ? "mov" : "jpg")
            let temporaryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("lyo-library-\(UUID().uuidString)")
                .appendingPathExtension(fileExtension)
            try data.write(to: temporaryURL, options: .atomic)

            if viewModel.selectedMode == .post {
                viewModel.attachedFiles.append(temporaryURL)
            } else if isVideo {
                viewModel.captureVideo(temporaryURL)
            } else if let image = UIImage(data: data) {
                viewModel.capturePhoto(image)
            } else {
                throw CreateHubMediaError.unreadableSelection
            }
        } catch {
            viewModel.state = .error(error.localizedDescription)
        }
    }

    private func removeAttachment(_ fileURL: URL) {
        viewModel.attachedFiles.removeAll { $0 == fileURL }
        try? FileManager.default.removeItem(at: fileURL)
    }

    // MARK: - State helpers

    private var hasCapturedMedia: Bool {
        viewModel.capturedImage != nil || viewModel.capturedVideoURL != nil
    }

    private var canPublishCapturedMedia: Bool {
        guard hasCapturedMedia else { return false }
        if viewModel.selectedMode == .clip || viewModel.selectedMode == .reel {
            return !trimmed(viewModel.clipTitle).isEmpty && viewModel.capturedVideoURL != nil
        }
        return true
    }

    private var captureAccessibilityLabel: String {
        if viewModel.selectedMode == .story {
            return "Take photo"
        }
        return camera.isRecording ? "Stop recording" : "Start recording"
    }

    private func selectMode(_ mode: CreateMode) {
        guard mode != .live else { return }
        if camera.isRecording {
            camera.stopRecording()
        }
        camera.resetCapturedMedia()
        viewModel.selectMode(mode)
        if mode.requiresCamera {
            camera.startSession()
        } else {
            camera.stopSession()
        }
    }

    private func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Overlays

    private var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: viewModel.progress, total: 1)
                    .progressViewStyle(.linear)
                    .tint(viewModel.selectedMode.color)
                    .frame(width: 220)
                Text("Publishing \(viewModel.selectedMode.rawValue)…")
                    .font(.headline)
                Text("\(Int(viewModel.progress * 100))%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.65))
            }
            .padding(28)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
        .foregroundStyle(.white)
        .zIndex(20)
    }

    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.76).ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 38))
                    .foregroundStyle(.yellow)
                Text("Couldn’t complete that action")
                    .font(.headline)
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))
                    .multilineTextAlignment(.center)
                Button("Back to Create") {
                    viewModel.state = hasCapturedMedia ? .captured : .idle
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(28)
            .frame(maxWidth: 340)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22))
        }
        .foregroundStyle(.white)
        .zIndex(30)
    }
}

private struct CreateCapturedVideoPreview: View {
    let url: URL
    @State private var player: AVPlayer

    init(url: URL) {
        self.url = url
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        VideoPlayer(player: player)
            .background(Color.black)
            .onAppear {
                player.isMuted = false
                player.play()
            }
            .onDisappear {
                player.pause()
            }
    }
}

private struct CreatePrimaryButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(color.opacity(configuration.isPressed ? 0.68 : 1), in: RoundedRectangle(cornerRadius: 14))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

private struct CreateSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(Color.white.opacity(configuration.isPressed ? 0.18 : 0.1), in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
            )
    }
}

private extension View {
    func createEditorCard() -> some View {
        self
            .foregroundStyle(.white)
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
    }
}

private enum CreateHubMediaError: LocalizedError {
    case unreadableSelection

    var errorDescription: String? {
        "The selected photo or video could not be loaded."
    }
}

#Preview {
    CreateHubView()
}
