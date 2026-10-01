import SwiftUI

// MARK: - Course card
//
// One saved course, as a card that flips.
//
// The front carries the action, deliberately: tapping the card body flips it,
// but Resume is a button on the front face, so studying stays one tap. A flip
// that stood between a learner and the thing they opened the app for would be
// a worse screen with a nicer animation.
//
// What it will not do is draw a progress figure the stack does not have. The
// branching lives in `FocusPresentation`, which is unit-tested.

struct FocusCourseCard: View {
    let item: UIStackItem
    /// The course's own description, when one has been loaded. `nil` is the
    /// ordinary case for a course Lio has just generated.
    let description: String?
    let onAction: () -> Void

    @State private var isFlipped = false

    private var action: FocusCourseAction { FocusPresentation.action(for: item) }
    private var isFinished: Bool { FocusPresentation.isFinished(item) }
    private var blurb: FocusCourseBlurb { FocusPresentation.blurb(description: description, for: item) }

    private let height: CGFloat = 206
    private let corner: CGFloat = 21

    /// Instant, delayed to the midpoint of the 0.48s turn.
    private static let faceSwap: Animation = .linear(duration: 0.01).delay(0.22)

    var body: some View {
        ZStack {
            // The faces swap at the halfway point of the turn, so neither is
            // ever visible mirrored. The swap is animated per face rather than
            // on the container, so it cannot be captured by the spring below.
            front
                .opacity(isFlipped ? 0 : 1)
                .animation(Self.faceSwap, value: isFlipped)
            back
                .opacity(isFlipped ? 1 : 0)
                .animation(Self.faceSwap, value: isFlipped)
                .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
        }
        .frame(height: height)
        .rotation3DEffect(
            .degrees(isFlipped ? 180 : 0),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.35
        )
        .animation(.spring(response: 0.48, dampingFraction: 0.84), value: isFlipped)
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .onTapGesture { flip() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(item.title)
        .accessibilityAction(named: isFlipped ? "Show progress" : "Show description") { flip() }
    }

    private func flip() {
        HapticManager.shared.light()
        isFlipped.toggle()
    }

    // MARK: - Front

    private var front: some View {
        ZStack(alignment: .bottomLeading) {
            FocusCourseArtwork(title: item.title)

            LinearGradient(
                colors: [
                    Color.black.opacity(0.04),
                    Color.black.opacity(0.46),
                    Color.black.opacity(0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 9) {
                Text(item.title)
                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                metaLine

                FocusLessonTrack(
                    progress: FocusPresentation.progress(for: item),
                    isFinished: isFinished
                )

                HStack(spacing: 9) {
                    Button(action: onAction) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(action.title)
                                .font(.system(size: 12.5, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(Color(hex: "0A0D16"))
                        .padding(.vertical, 9)
                        .padding(.horizontal, 15)
                        .background(Color.white, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens this course in the classroom")

                    Spacer(minLength: 0)

                    if let subtitle = item.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.46))
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .overlay(alignment: .topLeading) { statusTag.padding(14) }
        .overlay(alignment: .topTrailing) { flipAffordance.padding(13) }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 10)
    }

    private var metaLine: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 10.5))
            Text(item.updatedAt, style: .relative)
            Text("ago")
            if let total = item.lessonCount, total > 0 {
                Circle()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 2.5, height: 2.5)
                Text("\(total) lessons")
            }
        }
        .font(.system(size: 10.5, weight: .medium))
        .foregroundStyle(.white.opacity(0.58))
        .lineLimit(1)
    }

    @ViewBuilder
    private var statusTag: some View {
        if isFinished {
            HStack(spacing: 4) {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                Text("Finished")
            }
            .font(.system(size: 9, weight: .bold))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(Color(hex: "BDF5DA"))
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(Color(hex: "10B981").opacity(0.22), in: RoundedRectangle(cornerRadius: 7))
            .overlay {
                RoundedRectangle(cornerRadius: 7)
                    .stroke(Color(hex: "10B981").opacity(0.45), lineWidth: 1)
            }
        } else if let concept = item.focusedConcept, concept {
            // A generated review targets one mastery concept. Saying so is the
            // difference between "why is this here?" and "right, my weak spot".
            Text("Review")
                .font(.system(size: 9, weight: .bold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(.white)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 7))
        }
    }

    private var flipAffordance: some View {
        Image(systemName: "arrow.counterclockwise")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(.ultraThinMaterial, in: Circle())
            .overlay { Circle().stroke(Color.white.opacity(0.16), lineWidth: 1) }
            .rotationEffect(.degrees(isFlipped ? -180 : 0))
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    // MARK: - Back

    private var back: some View {
        ZStack {
            FocusCourseArtwork(title: item.title)
                .opacity(0.16)

            Color(hex: "141A2A").opacity(0.86)

            VStack(alignment: .leading, spacing: 9) {
                Text("About this course")
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(DesignTokens.Colors.accentSecondaryLight)

                blurbText

                Spacer(minLength: 0)

                Button(action: onAction) {
                    HStack(spacing: 6) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(action.title)
                            .font(.system(size: 12.5, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 15)
                    .background(Color.white.opacity(0.11), in: Capsule())
                    .overlay { Capsule().stroke(Color.white.opacity(0.16), lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(16)
        }
        .overlay(alignment: .topTrailing) { flipAffordance.padding(13) }
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        }
        .shadow(color: .black.opacity(0.55), radius: 16, x: 0, y: 10)
    }

    @ViewBuilder
    private var blurbText: some View {
        switch blurb {
        case let .description(text):
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.78))
                .lineSpacing(2.5)
                .lineLimit(5)
        case let .subtitle(text):
            VStack(alignment: .leading, spacing: 5) {
                Text("You stopped on")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
                Text(text)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .lineLimit(3)
            }
        case .none:
            Text("No description was saved with this course.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.5))
        }
    }
}

// MARK: - Lesson track

/// One tick per lesson, filled for the lessons behind the learner.
///
/// Falls back to a plain bar when only a fraction is known, and draws nothing
/// at all when the stack carries no figure: an empty track would claim the
/// learner is at the start of a course the app simply has not synced.
struct FocusLessonTrack: View {
    let progress: FocusCourseProgress
    let isFinished: Bool

    /// Above this, individual ticks are thinner than a hairline and the bar
    /// reads better.
    private let maxTicks = 40

    var body: some View {
        switch progress {
        case let .lessons(total, completed) where total <= maxTicks:
            HStack(spacing: 7) {
                HStack(spacing: 2) {
                    ForEach(0..<total, id: \.self) { index in
                        Capsule()
                            .fill(tickColour(index: index, completed: completed))
                            .frame(height: 4)
                    }
                }
                readout("\(completed)/\(total)")
            }
        case let .lessons(total, completed):
            bar(Double(completed) / Double(max(total, 1)), label: "\(completed)/\(total)")
        case let .fraction(value):
            bar(value, label: "\(Int((value * 100).rounded()))%")
        case .unknown:
            Text("Progress not recorded yet")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.46))
        }
    }

    private func tickColour(index: Int, completed: Int) -> Color {
        if isFinished { return Color(hex: "3ED68E") }
        if index < completed - 1 { return DesignTokens.Colors.accentSecondaryLight }
        if index == completed - 1 { return .white }
        return Color.white.opacity(0.2)
    }

    private func bar(_ value: Double, label: String) -> some View {
        HStack(spacing: 7) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.2))
                    Capsule()
                        .fill(isFinished ? Color(hex: "3ED68E") : DesignTokens.Colors.accentSecondaryLight)
                        .frame(width: geo.size.width * min(max(value, 0), 1))
                }
            }
            .frame(height: 4)
            readout(label)
        }
    }

    private func readout(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .monospacedDigit()
            .foregroundStyle(.white.opacity(0.72))
    }
}
