import SwiftUI
import AVFoundation

// MARK: - Camera Preview Layer

struct StudioCameraPreviewLayer: UIViewRepresentable {
    let session: AVCaptureSession
    @Binding var focusPoint: CGPoint?

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Updates handled by the UIView itself
    }
}

class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            if let session = session {
                videoPreviewLayer.session = session
            }
        }
    }

    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    private var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        // layerClass guarantees this type; the guard avoids a force-cast crash.
        guard let previewLayer = layer as? AVCaptureVideoPreviewLayer else {
            return AVCaptureVideoPreviewLayer()
        }
        return previewLayer
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        videoPreviewLayer.videoGravity = .resizeAspectFill

        if let connection = videoPreviewLayer.connection {
            if #available(iOS 17.0, *) {
                connection.videoRotationAngle = 90
            } else {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
        }
    }
}

// MARK: - Glass Morphic Tool Button

struct GlassMorphicToolButton: View {
    let icon: String
    var isText: Bool = false
    var isActive: Bool = false
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    isPressed = false
                }
                action()
            }
        }) {
            ZStack {
                // Glass background
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial)
                    .frame(width: 50, height: 50)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isActive ?
                                LinearGradient(
                                    colors: [.white.opacity(0.8), .white.opacity(0.4)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [.white.opacity(0.2), .clear],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )

                // Icon or Text
                if isText {
                    Text(icon)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isActive ? .white : .white.opacity(0.9))
                }
            }
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .brightness(isActive ? 0.1 : 0)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Record Button

struct RecordButton: View {
    let mode: CreateMode
    let isRecording: Bool
    let scale: CGFloat
    let action: () -> Void

    @State private var pulseAnimation = false
    @State private var glowIntensity: Double = 0

    var body: some View {
        Button(action: action) {
            ZStack {
                // Outer Ring with Glow
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.8),
                                .white.opacity(0.4)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 4
                    )
                    .frame(width: 90, height: 90)
                    .shadow(color: mode.color.opacity(0.3), radius: 20)
                    .shadow(color: mode.color.opacity(glowIntensity), radius: 40)

                // Inner Button
                ZStack {
                    if isRecording {
                        // Recording State - Square with rounded corners
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                            .frame(width: 32, height: 32)
                            .shadow(color: .red.opacity(0.6), radius: 15)
                    } else {
                        // Idle State - Circle with mode color
                        Circle()
                            .fill(mode.gradient)
                            .frame(width: 70, height: 70)
                            .shadow(color: mode.color.opacity(0.4), radius: 15)

                        // Mode Icon Overlay
                        modeIcon
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .scaleEffect(pulseAnimation ? 1.05 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8)
                    .repeatForever(autoreverses: true),
                    value: pulseAnimation
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            pulseAnimation = true
        }
        .onChange(of: isRecording) { _, recording in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                glowIntensity = recording ? 0.6 : 0.2
            }
        }
        .onChange(of: mode) { _, newMode in
            // Animate color change
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                glowIntensity = 0.4
            }
        }
    }

    @ViewBuilder
    private var modeIcon: some View {
        switch mode {
        case .clip:
            Image(systemName: "video.fill")
        case .reel:
            Image(systemName: "play.rectangle.fill")
        case .story:
            Image(systemName: "camera.fill")
        case .course:
            Image(systemName: "graduationcap.fill")
        case .post:
            Image(systemName: "square.and.pencil")
        case .live:
            Image(systemName: "dot.radiowaves.left.and.right")
        case .event:
            Image(systemName: "person.3.fill")
        }
    }
}

// MARK: - Mode Selector

struct ModeSelector: View {
    @Binding var selectedMode: CreateMode
    let modes: [CreateMode]

    private let spacing: CGFloat = 40

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(modes) { mode in
                        StudioModeButton(
                            mode: mode,
                            isSelected: selectedMode == mode,
                            action: {
                                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                    selectedMode = mode
                                }
                            }
                        )
                        .id(mode.id)
                    }
                }
                .padding(.horizontal, 40)
            }
            .onChange(of: selectedMode) { _, newMode in
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    proxy.scrollTo(newMode.id, anchor: .center)
                }
            }
        }
    }
}

struct StudioModeButton: View {
    let mode: CreateMode
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(mode.displayName)
                    .font(.system(
                        size: isSelected ? 18 : 16,
                        weight: isSelected ? .bold : .medium,
                        design: .rounded
                    ))
                    .foregroundColor(.white)
                    .scaleEffect(isSelected ? 1.1 : 1.0)

                // Underline indicator
                if isSelected {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(mode.gradient)
                        .frame(width: 30, height: 3)
                        .shadow(color: mode.color.opacity(0.6), radius: 8)
                } else {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.clear)
                        .frame(width: 30, height: 3)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isSelected)
    }
}

// MARK: - AI Suggestions Panel

struct AISuggestionsPanel: View {
    let suggestions: [String]
    @Binding var isVisible: Bool
    let onSuggestionTap: (String) -> Void

    var body: some View {
        VStack {
            if isVisible {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        HStack(spacing: 8) {
                            Text("✨")
                                .font(.system(size: 18))

                            Text("Lyo Suggests")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Button {
                            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                isVisible = false
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 1), spacing: 12) {
                        ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                            SuggestionCard(
                                suggestion: suggestion,
                                delay: Double(index) * 0.1
                            ) {
                                onSuggestionTap(suggestion)
                            }
                        }
                    }
                }
                .padding(20)
                .background(.ultraThinMaterial)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.3), radius: 30)
                .padding(.horizontal, 20)
                .padding(.top, 120)
            }

            Spacer()
        }
    }
}

struct SuggestionCard: View {
    let suggestion: String
    let delay: Double
    let action: () -> Void

    @State private var isVisible = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.yellow)

                Text(suggestion)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)

                Spacer()

                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isVisible ? 1.0 : 0.8)
        .opacity(isVisible ? 1.0 : 0)
        .animation(
            .spring(response: 0.6, dampingFraction: 0.8).delay(delay),
            value: isVisible
        )
        .onAppear {
            isVisible = true
        }
    }
}

// MARK: - AI Suggestion Banner

struct AISuggestionBanner: View {
    let suggestion: String
    @Binding var isVisible: Bool

    var body: some View {
        VStack {
            if isVisible {
                HStack(spacing: 12) {
                    Text("✨")
                        .font(.system(size: 16))

                    Text(suggestion)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                            isVisible = false
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(16)
                .background(.ultraThinMaterial)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.blue.opacity(0.5), .purple.opacity(0.3)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: .black.opacity(0.2), radius: 15)
                .padding(.horizontal, 20)
                .padding(.top, 120)
            }

            Spacer()
        }
    }
}

// MARK: - Recording Progress Bar

struct RecordingProgressBar: View {
    let progress: Double
    let duration: String

    var body: some View {
        VStack(spacing: 8) {
            // Progress Bar
            HStack(spacing: 12) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 8, height: 8)
                    .scaleEffect(1.5)
                    .animation(
                        .easeInOut(duration: 0.6)
                        .repeatForever(autoreverses: true),
                        value: progress
                    )

                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .red))
                    .frame(height: 4)
                    .background(Color.white.opacity(0.3))
                    .cornerRadius(2)

                Text(duration)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .frame(minWidth: 50)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal, 20)
    }
}

// MARK: - Focus Animation View

struct FocusAnimationView: View {
    let point: CGPoint
    let size: CGSize

    @State private var scale: CGFloat = 1.5
    @State private var opacity: Double = 1.0

    var body: some View {
        Circle()
            .stroke(Color.yellow, lineWidth: 2)
            .frame(width: 60, height: 60)
            .scaleEffect(scale)
            .opacity(opacity)
            .position(
                x: point.x * size.width,
                y: point.y * size.height
            )
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.0
                }

                withAnimation(.easeOut(duration: 0.6)) {
                    opacity = 0.0
                }
            }
    }
}

