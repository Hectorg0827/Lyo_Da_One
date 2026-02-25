//
//  CourseStartGateView.swift
//  Lyo
//
//  Monetization gate shown between "Start Class" / "Resume" and the live classroom.
//
//  • Non-premium  → 10-second ad placeholder (swap TODO block for real AdMob interstitial)
//  • Premium      → polished generative-AI loading animation with step timeline
//
//  After the gate resolves it calls `onProceed()` which triggers the real classroom.
//

import SwiftUI

struct CourseStartGateView: View {
    let courseId: String
    let courseTitle: String
    let onProceed: () -> Void

    @StateObject private var monetization = MonetizationService.shared

    // ── Ad-gate state ──────────────────────────────────────────────────
    @State private var secondsRemaining: Int = 10
    @State private var countdownTimer: Timer?
    @State private var canSkip = false

    // ── Premium animation state ────────────────────────────────────────
    @State private var orbPulse = false
    @State private var particlePhase: Double = 0
    @State private var stepIndex: Int = 0
    @State private var stepsDone: [Bool] = [false, false, false, false]

    private let premiumSteps: [(icon: String, label: String)] = [
        ("sparkles",              "Planning your curriculum"),
        ("books.vertical.fill",   "Building learning modules"),
        ("brain.head.profile",    "Personalizing content for you"),
        ("checkmark.seal.fill",   "Finalizing your course")
    ]

    // ── Body ──────────────────────────────────────────────────────────
    var body: some View {
        ZStack {
            // Shared dark background
            Color(hex: "07080F").ignoresSafeArea()
            LinearGradient(
                colors: [Color(hex: "1a0d3a").opacity(0.72), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            ).ignoresSafeArea()

            if monetization.isPremium {
                premiumContent
            } else {
                adGateContent
            }
        }
        .onAppear {
            if monetization.isPremium {
                startPremiumAnimation()
            } else {
                startAdCountdown()
            }
        }
        .onDisappear {
            countdownTimer?.invalidate()
        }
    }

    // MARK: - Ad Gate (Non-Premium) ─────────────────────────────────────

    private var adGateContent: some View {
        VStack(spacing: 0) {

            // Top bar
            HStack {
                Text("Your course is being prepared…")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.45))

                Spacer()

                if canSkip {
                    Button(action: onProceed) {
                        Text("Skip  ›")
                            .font(.caption.weight(.semibold))
                            .foregroundColor(Color(hex: "A78BFA"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(hex: "A78BFA").opacity(0.15))
                            .clipShape(Capsule())
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.35))
                        Text("Skip in \(secondsRemaining)s")
                            .font(.caption.weight(.semibold))
                            .monospacedDigit()
                            .foregroundColor(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.07))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 56)
            .padding(.bottom, 16)

            // ── Ad card ──────────────────────────────────────────────
            // TODO: Replace this ZStack with a real AdMob interstitial view once
            //       GADMobileAds (Google Mobile Ads SDK for iOS) is integrated.
            //       See /Desktop/LyoBackendJune/ios_integration/AdMobIntegration.swift
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "1E1B4B"), Color(hex: "2D2572")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(Color(hex: "6366F1").opacity(0.25), lineWidth: 1)
                    )

                VStack(spacing: 22) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 52, weight: .thin))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "A855F7"), Color(hex: "6366F1")],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Text("Learn faster with Lyo Premium")
                        .font(.title2.weight(.bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("Unlimited AI-generated courses,\nzero ads, and instant generation.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    // Ad-progress bar replacing numeric countdown
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .frame(height: 4)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "A855F7"), Color(hex: "6366F1")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(
                                    width: geo.size.width * CGFloat(10 - secondsRemaining) / 10.0,
                                    height: 4
                                )
                                .animation(.linear(duration: 0.9), value: secondsRemaining)
                        }
                    }
                    .frame(height: 4)
                    .padding(.horizontal, 8)
                }
                .padding(32)

                // AD badge
                VStack {
                    HStack {
                        Spacer()
                        Text("AD")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white.opacity(0.35))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.07))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                            .padding(14)
                    }
                    Spacer()
                }
            }
            .frame(height: 370)
            .padding(.horizontal, 16)

            Spacer()

            // Bottom section
            VStack(spacing: 14) {
                Text("Preparing: \(courseTitle)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 20)

                // Upgrade CTA
                Button(action: {
                    // TODO: Present paywall / subscription purchase screen
                    Log.ai.info("🔒 User tapped upgrade from gate")
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "crown.fill")
                            .font(.subheadline)
                        Text("Upgrade to Premium — Remove Ads")
                            .font(.subheadline.weight(.semibold))
                    }
                    .foregroundColor(Color(hex: "F59E0B"))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color(hex: "F59E0B").opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color(hex: "F59E0B").opacity(0.35), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 48)
        }
    }

    // MARK: - Premium Loading Animation ────────────────────────────────

    private var premiumContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Animated orb cluster
            ZStack {
                // Pulsing glow rings
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(hex: "7C3AED").opacity(0.45),
                                    Color(hex: "6366F1").opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                        .frame(
                            width: 110 + CGFloat(i * 38),
                            height: 110 + CGFloat(i * 38)
                        )
                        .scaleEffect(orbPulse ? 1.06 + Double(i) * 0.025 : 1.0)
                        .opacity(orbPulse ? 0.65 : 0.18)
                        .animation(
                            .easeInOut(duration: 1.9)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.38),
                            value: orbPulse
                        )
                }

                // Orbiting particles
                ForEach(0..<6, id: \.self) { i in
                    Circle()
                        .fill(
                            Color(hex: i % 2 == 0 ? "A855F7" : "6366F1")
                                .opacity(0.88)
                        )
                        .frame(width: 6, height: 6)
                        .offset(x: 62)
                        .rotationEffect(.degrees(particlePhase + Double(i) * 60))
                        .animation(
                            .linear(duration: 3.2).repeatForever(autoreverses: false),
                            value: particlePhase
                        )
                }

                // Core orb
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "C084FC"),
                                Color(hex: "6366F1"),
                                Color(hex: "2D1B69")
                            ],
                            center: .center,
                            startRadius: 4,
                            endRadius: 44
                        )
                    )
                    .frame(width: 88, height: 88)
                    .shadow(color: Color(hex: "A855F7").opacity(0.6), radius: 20)
                    .scaleEffect(orbPulse ? 1.06 : 0.94)
                    .animation(
                        .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: orbPulse
                    )
                    .overlay(
                        Image(systemName: "sparkles")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            .frame(width: 210, height: 210)

            // Course info
            VStack(spacing: 8) {
                Text("Building Your Course")
                    .font(.title2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.top, 12)

                Text(courseTitle)
                    .font(.subheadline)
                    .foregroundColor(Color(hex: "A78BFA"))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
            }

            // Steps timeline
            VStack(spacing: 18) {
                ForEach(premiumSteps.indices, id: \.self) { i in
                    HStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(
                                    stepsDone[i]
                                        ? Color(hex: "10B981").opacity(0.15)
                                        : (stepIndex == i
                                            ? Color(hex: "A855F7").opacity(0.15)
                                            : Color.white.opacity(0.05))
                                )
                                .frame(width: 34, height: 34)

                            if stepsDone[i] {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(Color(hex: "10B981"))
                            } else if stepIndex == i {
                                ProgressView()
                                    .progressViewStyle(
                                        CircularProgressViewStyle(tint: Color(hex: "A855F7"))
                                    )
                                    .scaleEffect(0.65)
                            } else {
                                Image(systemName: premiumSteps[i].icon)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                        }

                        Text(premiumSteps[i].label)
                            .font(.subheadline.weight(stepsDone[i] ? .semibold : .regular))
                            .foregroundColor(
                                stepsDone[i]
                                    ? .white
                                    : (stepIndex == i ? Color(hex: "A78BFA") : .white.opacity(0.28))
                            )
                            .animation(.easeInOut(duration: 0.3), value: stepIndex)

                        Spacer()

                        if stepsDone[i] {
                            Text("Done")
                                .font(.caption2.weight(.bold))
                                .foregroundColor(Color(hex: "10B981"))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 4)
                                .background(Color(hex: "10B981").opacity(0.12))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 36)
                }
            }
            .padding(.top, 28)

            Spacer()
        }
    }

    // MARK: - Logic ─────────────────────────────────────────────────────

    private func startAdCountdown() {
        secondsRemaining = 10
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { t in
            if secondsRemaining > 0 {
                secondsRemaining -= 1
            } else {
                t.invalidate()
                withAnimation { canSkip = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    onProceed()
                }
            }
        }
    }

    private func startPremiumAnimation() {
        orbPulse = true
        withAnimation(.linear(duration: 3.2).repeatForever(autoreverses: false)) {
            particlePhase = 360
        }
        // Advance step timeline — each step takes ~2 s
        let stepDuration = 1.85
        for i in premiumSteps.indices {
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i)) {
                withAnimation(.easeInOut(duration: 0.35)) { stepIndex = i }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + stepDuration * Double(i) + stepDuration * 0.82) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { stepsDone[i] = true }
            }
        }
        // Proceed once all steps are marked done (+ 0.6 s buffer)
        let totalTime = stepDuration * Double(premiumSteps.count) + 0.6
        DispatchQueue.main.asyncAfter(deadline: .now() + totalTime) {
            onProceed()
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Non-Premium") {
    CourseStartGateView(
        courseId: "demo-001",
        courseTitle: "SwiftUI Mastery: Build Beautiful Apps"
    ) {
        print("Proceed to classroom")
    }
}

#Preview("Premium") {
    CourseStartGateView(
        courseId: "demo-002",
        courseTitle: "Machine Learning for iOS Developers"
    ) {
        print("Proceed to classroom")
    }
    .onAppear {
        // Simulate premium for preview
    }
}
#endif
