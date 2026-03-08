import SwiftUI

// MARK: - Module Card View
/// Visual representation of a single course module with state-aware styling.
/// Shows locked → building → ready → failed states per the progressive blueprint.

struct ModuleCardView: View {
    let module: ProgressiveModule
    var onTap: (() -> Void)?

    private var previewLessons: [ProgressiveLesson] {
        Array((module.lessons ?? []).prefix(2))
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .stroke(progressRingColor.opacity(0.22), lineWidth: 6)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: progressRingValue)
                    .stroke(progressRingColor, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .frame(width: 52, height: 52)
                    .rotationEffect(.degrees(-90))

                stateIcon
                    .frame(width: 34, height: 34)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Module \(module.index)")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)

                        Text(module.title)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(titleColor)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)
                    statePill
                }

                if let subtitle = subtitleText {
                    Text(subtitle)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundColor(subtitleColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if !previewLessons.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(previewLessons) { lesson in
                            HStack(alignment: .top, spacing: 8) {
                                Circle()
                                    .fill(Color.white.opacity(0.22))
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 5)
                                Text(lesson.title ?? lesson.summary ?? "Lesson preview")
                                    .font(.caption)
                                    .foregroundColor(.primary.opacity(0.86))
                                    .lineLimit(2)
                            }
                        }
                    }
                }

                HStack(spacing: 10) {
                    labelChip(icon: "play.rectangle.on.rectangle", text: lessonCountText)
                    if let summary = module.summary, !summary.isEmpty, module.state == .ready {
                        labelChip(icon: "sparkles", text: "AI ready")
                    } else if module.state == .building {
                        labelChip(icon: "wand.and.stars", text: "Generating live")
                    }
                    Spacer(minLength: 0)
                    rightAccessory
                }
            }
        }
        .padding(16)
        .background(cardBackground)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(borderColor, lineWidth: 1)
        )
        .shadow(color: shadowColor, radius: 10, y: 4)
        .opacity(module.state == .locked ? 0.6 : 1.0)
        .allowsHitTesting(module.state == .ready || module.state == .failed)
        .onTapGesture {
            onTap?()
        }
        .modifier(module.state == .building ? ShimmerModifier() : IdentityModifier())
    }
    
    // MARK: - State Icon
    
    @ViewBuilder
    private var stateIcon: some View {
        switch module.state {
        case .locked:
            Image(systemName: "lock.fill")
                .font(.headline)
                .foregroundColor(.gray.opacity(0.5))
                .frame(width: 34, height: 34)
                .background(Color.gray.opacity(0.12))
                .clipShape(Circle())
            
        case .building:
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.12))
                ProgressView()
                    .tint(.blue)
            }
            
        case .ready:
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
                .frame(width: 34, height: 34)
                .background(Color.green.opacity(0.1))
                .clipShape(Circle())
            
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundColor(.orange)
                .frame(width: 34, height: 34)
                .background(Color.orange.opacity(0.1))
                .clipShape(Circle())
        }
    }

    @ViewBuilder
    private var statePill: some View {
        Text(stateLabel)
            .font(.caption2.bold())
            .foregroundColor(stateTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(stateBackground)
            .clipShape(Capsule())
    }
    
    // MARK: - Right Accessory
    
    @ViewBuilder
    private var rightAccessory: some View {
        switch module.state {
        case .ready:
            Image(systemName: "arrow.up.right.circle.fill")
                .font(.title3)
                .foregroundColor(.green)
        case .building:
            Text("Creating...")
                .font(.caption)
                .foregroundColor(.blue)
        case .failed:
            Button(action: { onTap?() }) {
                Text("Retry")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
        case .locked:
            EmptyView()
        }
    }
    
    // MARK: - Helpers
    
    private var titleColor: Color {
        switch module.state {
        case .locked: return .gray
        case .building: return .primary.opacity(0.7)
        case .ready: return .primary
        case .failed: return .orange
        }
    }

    private var subtitleColor: Color {
        switch module.state {
        case .failed: return .orange.opacity(0.85)
        case .building: return .blue.opacity(0.88)
        default: return .secondary
        }
    }
    
    private var subtitleText: String? {
        switch module.state {
        case .locked:
            return module.summary ?? "Coming up next once the previous module is ready."
        case .building:
            return module.summary ?? "AI is building the concepts, lesson flow, and practice for this module right now."
        case .ready:
            return module.summary ?? "Tap to open this module and continue learning."
        case .failed:
            return "Generation stalled. Tap retry to rebuild this module."
        }
    }
    
    private var lessonCountText: String {
        let count = module.lessons?.count ?? 0
        if count == 0 {
            return module.state == .building ? "Populating lessons" : "No lesson count yet"
        }
        return "\(count) lesson\(count == 1 ? "" : "s")"
    }

    private var stateLabel: String {
        switch module.state {
        case .locked: return "Locked"
        case .building: return "Building"
        case .ready: return "Ready"
        case .failed: return "Needs Retry"
        }
    }

    private var stateTextColor: Color {
        switch module.state {
        case .locked: return .gray
        case .building: return .blue
        case .ready: return .green
        case .failed: return .orange
        }
    }

    private var stateBackground: Color {
        switch module.state {
        case .locked: return Color.gray.opacity(0.12)
        case .building: return Color.blue.opacity(0.12)
        case .ready: return Color.green.opacity(0.12)
        case .failed: return Color.orange.opacity(0.12)
        }
    }

    private var progressRingColor: Color {
        switch module.state {
        case .locked: return .gray
        case .building: return .blue
        case .ready: return .green
        case .failed: return .orange
        }
    }

    private var progressRingValue: CGFloat {
        switch module.state {
        case .locked: return 0.12
        case .building: return 0.55
        case .ready: return 1.0
        case .failed: return 0.3
        }
    }

    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(backgroundGradient)
    }

    private var backgroundGradient: LinearGradient {
        switch module.state {
        case .locked:
            return LinearGradient(colors: [Color(.systemGray6).opacity(0.65), Color(.systemGray5).opacity(0.45)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .building:
            return LinearGradient(colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .ready:
            return LinearGradient(colors: [Color(.systemBackground), Color.green.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .failed:
            return LinearGradient(colors: [Color.orange.opacity(0.08), Color.red.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
    
    private var borderColor: Color {
        switch module.state {
        case .locked: return .clear
        case .building: return .blue.opacity(0.2)
        case .ready: return .green.opacity(0.3)
        case .failed: return .orange.opacity(0.3)
        }
    }

    private var shadowColor: Color {
        switch module.state {
        case .ready: return Color.green.opacity(0.08)
        case .building: return Color.blue.opacity(0.08)
        case .failed: return Color.orange.opacity(0.08)
        case .locked: return .clear
        }
    }

    private func labelChip(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption2.bold())
        }
        .foregroundColor(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Shimmer Effect for Building State

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.3), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .offset(x: phase)
                .animation(
                    .linear(duration: 1.5).repeatForever(autoreverses: false),
                    value: phase
                )
            )
            .clipped()
            .onAppear { phase = 300 }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

private struct IdentityModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 12) {
        ModuleCardView(module: ProgressiveModule(id: "1", index: 1, state: .ready, title: "Fraction Fundamentals", lessons: [
            ProgressiveLesson(id: "l1", title: "What is a Fraction?", content: "Content here", summary: nil, miniPractice: nil)
        ]))
        
        ModuleCardView(module: ProgressiveModule(id: "2", index: 2, state: .building, title: "Equivalent Fractions"))
        
        ModuleCardView(module: ProgressiveModule(id: "3", index: 3, state: .locked, title: "Simplifying Fractions"))
        
        ModuleCardView(module: ProgressiveModule(id: "4", index: 4, state: .failed, title: "Adding and Subtracting"))
    }
    .padding()
}
