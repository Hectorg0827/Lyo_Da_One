import SwiftUI

// MARK: - Test prep, on Focus
//
// "I have a test on Friday. How ready am I, and what should I do first?"
//
// Test prep was already a real screen; Focus linked to it with a grey row that
// said nothing, so the answer was always one tap away and never visible. This
// card answers the question in place when there is a plan, and collapses to a
// single prompt when there is not.
//
// Every figure comes from `TestPrepPresentation`, not from formatting a Double
// here. That matters most for the case this app has been careful about since
// test prep shipped: a new plan carries a readiness of 0.0 with nothing
// assessed, and rendering that as "0% ready" tells someone they failed
// something nobody asked them. `.notStarted` and `.measured(0)` are one number
// apart and a world apart in what they claim about a person.
//
// Neither view here is a Button. The caller wraps them in a NavigationLink,
// and a button inside a link gives one row two competing tap targets.

struct FocusTestPrepCard: View {
    let readiness: PlanReadiness?
    let sessions: [PlannedSession]
    /// A refresh failed, so what is shown may predate the learner's last session.
    let isStale: Bool

    private var headline: MeasuredValue {
        TestPrepPresentation.readinessHeadline(readiness)
    }

    private var nextSession: PlannedSession? {
        TestPrepPresentation.openSessions(sessions).first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                gauge

                VStack(alignment: .leading, spacing: 3) {
                    Text(readiness?.subject ?? "Test prep")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    secondaryLine
                }

                Spacer(minLength: 4)

                if let days = TestPrepPresentation.daysLabel(readiness?.daysRemaining) {
                    Text(days)
                        .font(.system(size: 9.5, weight: .bold))
                        .monospacedDigit()
                        .foregroundStyle(DesignTokens.Colors.warning)
                        .padding(.vertical, 3)
                        .padding(.horizontal, 7)
                        .background(
                            DesignTokens.Colors.warning.opacity(0.14),
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(DesignTokens.Colors.warning.opacity(0.28), lineWidth: 1)
                        }
                        .fixedSize()
                }
            }

            if let nextSession {
                Divider()
                    .overlay(Color.white.opacity(0.08))
                    .padding(.vertical, 11)
                nextRow(nextSession)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    DesignTokens.Colors.warning.opacity(0.12),
                    Color.white.opacity(0.045)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 17, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(DesignTokens.Colors.warning.opacity(0.24), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens test prep")
    }

    // MARK: - Gauge

    private var gauge: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: gaugeFraction)
                .stroke(
                    DesignTokens.Colors.warning,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
            gaugeLabel
        }
        .frame(width: 52, height: 52)
        .accessibilityHidden(true)
    }

    /// Nothing measured draws no arc. An arc of zero length and "no reading
    /// yet" mean the same thing; an arc drawn to 0% with a 0 in the middle
    /// does not.
    private var gaugeFraction: CGFloat {
        switch headline {
        case let .measured(percent): return CGFloat(percent) / 100
        case .notStarted, .unknown: return 0
        }
    }

    @ViewBuilder
    private var gaugeLabel: some View {
        switch headline {
        case let .measured(percent):
            HStack(alignment: .top, spacing: 1) {
                Text("\(percent)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .padding(.top, 2)
            }
            .foregroundStyle(.white)
        case .notStarted, .unknown:
            Image(systemName: "calendar")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.warning)
        }
    }

    // MARK: - Lines

    private var secondaryText: String {
        if isStale { return "Last known reading — refresh failed" }
        switch headline {
        case .measured:
            guard let readiness else { return "Readiness measured" }
            return "\(readiness.topicsAssessed) of \(readiness.topicsTotal) topics assessed"
        case .notStarted:
            return "Nothing assessed yet — start a session"
        case .unknown:
            return "No topics to measure yet"
        }
    }

    private var secondaryLine: some View {
        Text(secondaryText)
            .font(.system(size: 11))
            .foregroundStyle(.white.opacity(isStale ? 0.52 : 0.62))
            .lineLimit(2)
            .multilineTextAlignment(.leading)
    }

    private func nextRow(_ session: PlannedSession) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "play.fill")
                .font(.system(size: 10))
                .foregroundStyle(.white)
                .frame(width: 25, height: 25)
                .background(Color.white.opacity(0.08), in: Circle())
                .overlay { Circle().stroke(Color.white.opacity(0.12), lineWidth: 1) }

            Text(nextLabel(session))
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.34))
        }
    }

    /// The planned length travels with the topic, because the plan screen
    /// promises it and a session that silently runs a different length makes
    /// that a promise the product does not keep. A non-positive length is left
    /// out rather than printed as "0 min".
    private func nextLabel(_ session: PlannedSession) -> String {
        let topic = session.topic.trimmingCharacters(in: .whitespacesAndNewlines)
        if session.durationMinutes > 0 {
            return topic.isEmpty
                ? "Next: \(session.durationMinutes) min"
                : "Next: \(session.durationMinutes) min · \(topic)"
        }
        return topic.isEmpty ? "Next session" : "Next: \(topic)"
    }
}

// MARK: - No plan yet

/// One line, when the learner has no test coming up.
///
/// Deliberately small: a prompt for something that may not apply should not
/// cost the same screen space as a live countdown.
struct FocusTestPrepPrompt: View {
    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: "calendar")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(DesignTokens.Colors.warning)
                .frame(width: 30, height: 30)
                .background(
                    DesignTokens.Colors.warning.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 10)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Have a test coming up?")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(.white)
                Text("Tell me what and when — I'll plan it with you")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.34))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(Color.white.opacity(0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens test prep, where you can build a study plan")
    }
}
