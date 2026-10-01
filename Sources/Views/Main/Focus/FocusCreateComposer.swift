import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

// MARK: - Create a course
//
// The way into course creation, on the screen learners actually open.
//
// Before this existed, the only create affordance on Focus lived inside the
// "no active learning session" card, which disappears the moment one course is
// saved — so a returning learner had no way to start anything new from here,
// and no way to discover that the app will build a course from a PDF or from
// their own voice. Four input paths existed in code and none was visible.
//
// Every button here lands somewhere real:
//
//   - Typing, and the weak-concept chips, post `TriggerCourseCreation`, which
//     MainTabView already handles by opening Lio and sending the message.
//   - Speak and the attachment pickers post `presentLyoOverlay`, because the
//     overlay's input bar is the surface that renders attachments and runs the
//     voice session. The chat sheet's own attach button is still a stub.
//   - Photo and File write into `MediaPickerService.shared`, the same
//     singleton the overlay's input bar reads, so an attachment picked here is
//     already sitting in the composer when the overlay opens.
//
// "From a clip" is deliberately absent. `ClipService.generateCourseFromClip`
// exists but has no caller and there is no clip picker to feed it, so a button
// for it would lead nowhere.

struct FocusCreateComposer: View {
    /// Concepts the learner has actually struggled with. Empty hides the row
    /// rather than filling it with suggestions nothing measured.
    let weakConcepts: [String]

    @State private var topic = ""
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var attachmentError: String?

    @StateObject private var mediaService = MediaPickerService.shared
    @FocusState private var fieldIsFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            field
            modes
            if !weakConcepts.isEmpty { weakRow }
            if let attachmentError { errorRow(attachmentError) }
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color(hex: "17123A"), Color(hex: "110F26"), Color(hex: "0B0E1C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(DesignTokens.Colors.accentSecondary.opacity(0.28), lineWidth: 1)
        }
        .shadow(color: DesignTokens.Colors.accentSecondary.opacity(0.3), radius: 18, x: 0, y: 12)
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoItems,
            maxSelectionCount: max(1, mediaService.maxAttachmentCount - mediaService.selectedMedia.count),
            matching: .images
        )
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await receivePhotos(items) }
        }
        .fileImporter(
            isPresented: $showDocumentPicker,
            allowedContentTypes: mediaService.supportedDocTypes,
            allowsMultipleSelection: true
        ) { result in
            Task { await receiveDocuments(result) }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "sparkles")
                .font(.system(size: 13, weight: .semibold))
            Text("Create a course")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.4)
                .textCase(.uppercase)
        }
        .foregroundStyle(DesignTokens.Colors.accentSecondaryLight)
    }

    private var field: some View {
        HStack(spacing: 10) {
            TextField("Teach me…", text: $topic, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 13.5))
                .foregroundStyle(.white)
                .tint(DesignTokens.Colors.accentSecondaryLight)
                .lineLimit(1...3)
                .focused($fieldIsFocused)
                .submitLabel(.go)
                .onSubmit(submitTopic)

            Button(action: submitTopic) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "A275FF"), Color(hex: "7C3AED"), Color(hex: "5B2FD4")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 11, style: .continuous)
                    )
                    .opacity(trimmedTopic.isEmpty ? 0.45 : 1)
            }
            .buttonStyle(.plain)
            .disabled(trimmedTopic.isEmpty)
            .accessibilityLabel("Build this course")
        }
        .padding(.leading, 13)
        .padding(.trailing, 10)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.42), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        }
    }

    private var modes: some View {
        HStack(spacing: 6) {
            modeButton(title: "Speak", icon: "mic", hint: "Say what you want to learn") {
                FocusCreateComposer.openLio(mode: "voice")
            }
            modeButton(title: "Photo", icon: "camera", hint: "Build a course from a photo of your notes") {
                showPhotoPicker = true
            }
            modeButton(title: "File", icon: "doc.text", hint: "Build a course from a PDF or text file") {
                showDocumentPicker = true
            }
        }
    }

    private func modeButton(
        title: String,
        icon: String,
        hint: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            HapticManager.shared.light()
            action()
        } label: {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(DesignTokens.Colors.accentSecondaryLight)
                Text(title)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.6)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.68))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.07), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint(hint)
    }

    private var weakRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider().overlay(Color.white.opacity(0.08))

            Text("Shore up a weak concept")
                .font(.system(size: 9.5, weight: .bold))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.42))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(weakConcepts, id: \.self) { concept in
                        Button {
                            HapticManager.shared.light()
                            FocusCreateComposer.createCourse(topic: concept)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "target")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(concept)
                                    .font(.system(size: 11, weight: .semibold))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color(hex: "DBCFFF"))
                            .padding(.vertical, 7)
                            .padding(.horizontal, 11)
                            .background(DesignTokens.Colors.accentSecondary.opacity(0.15), in: Capsule())
                            .overlay {
                                Capsule().stroke(DesignTokens.Colors.accentSecondary.opacity(0.3), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Builds a focused review on \(concept)")
                    }
                }
            }
        }
    }

    private func errorRow(_ message: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 11))
            Text(message)
                .font(.system(size: 11))
        }
        .foregroundStyle(DesignTokens.Colors.warning)
    }

    // MARK: - Actions

    private var trimmedTopic: String {
        topic.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func submitTopic() {
        let subject = trimmedTopic
        guard !subject.isEmpty else { return }
        HapticManager.shared.medium()
        fieldIsFocused = false
        topic = ""
        FocusCreateComposer.createCourse(topic: subject)
    }

    @MainActor
    private func receivePhotos(_ items: [PhotosPickerItem]) async {
        attachmentError = nil
        await mediaService.processPhotoPickerItems(items)
        photoItems = []
        if let error = mediaService.error {
            attachmentError = error.localizedDescription
            return
        }
        FocusCreateComposer.openLio(mode: "attachment")
    }

    @MainActor
    private func receiveDocuments(_ result: Result<[URL], Error>) async {
        attachmentError = nil
        do {
            let urls = try result.get()
            let remaining = max(0, mediaService.maxAttachmentCount - mediaService.selectedMedia.count)
            guard remaining > 0 else {
                attachmentError = "You can attach up to \(mediaService.maxAttachmentCount) files."
                return
            }
            for url in urls.prefix(remaining) {
                _ = try await mediaService.processDocumentURL(url)
            }
            if urls.count > remaining {
                attachmentError = "You can attach up to \(mediaService.maxAttachmentCount) files."
            }
            FocusCreateComposer.openLio(mode: "attachment")
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    // MARK: - Routing
    //
    // Posted rather than called so Focus does not need to own the chat view
    // model or reach into MainTabView's presentation state.

    /// Hands a topic to Lio. `MainTabView` already listens for this and sends
    /// the message on the view-owned view model.
    static func createCourse(topic: String) {
        NotificationCenter.default.post(
            name: Notification.Name("TriggerCourseCreation"),
            object: nil,
            userInfo: ["topic": topic]
        )
    }

    /// Opens the Lio overlay — the surface with the working attachment bar and
    /// voice session.
    static func openLio(mode: String) {
        NotificationCenter.default.post(
            name: .presentLyoOverlay,
            object: nil,
            userInfo: ["mode": mode]
        )
    }
}
