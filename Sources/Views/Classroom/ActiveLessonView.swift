import SwiftUI

/// Active Lesson screen.
///
/// Redesigned to be a premium, alive, swipe-based living AI classroom experience.
/// Implements:
/// 1. Swipe-based scene navigation (left/right gestures) with interactive lock logic.
/// 2. Lyo Board (navy/charcoal smart board) with progressive reveals and instant tap completion.
/// 3. Living Stage with standalone PNG classmate/teacher avatars and activity status tags.
/// 4. Balanced Dialogue Card supporting short explanations and interactive prompts.
/// 5. Bottom Lyo Dock containing helper lens transformations (Explain Easier, Visualize, etc.) and Lesson Map.
@MainActor
struct ActiveLessonView: View {

    // MARK: - Inputs

    let header: HeaderModel
    let steps: [LessonStep]
    var onAdvance: (LessonStep) -> Void = { _ in }
    var onAskLyo: (LessonStep) -> Void = { _ in }
    var onExplainEasier: (LessonStep) -> Void = { _ in }
    var onQuizAnswer: (SDUIComponent, SDUIQuizOption) -> Void = { _, _ in }
    var onBack: () -> Void = {}
    var onMenu: () -> Void = {}
    var onMic: () -> Void = {}
    var onTools: () -> Void = {}

    // MARK: - Models

    struct HeaderModel {
        let title: String
        let subtitle: String // E.g., "Lesson 1 of 6"
    }

    struct LessonStep: Identifiable {
        let id: String
        let teachingText: String
        let supporting: SupportingBlock?
        let keyTerm: KeyTerm?
        let primaryActionLabel: String
        var primaryActionIntent: String? = nil
        var primaryActionComponentId: String? = nil
        var primaryActionPayload: [String: String]? = nil

        // Multi-agent properties
        var speakerName: String = "Teacher"
        var speakerBadge: String = "AI Teacher ✨"
        var speakerImageName: String? = nil

        enum SupportingBlock {
            case comparison(ConceptComparisonModel)
            case lessonBlock(LiveLessonBlock)
            case classroomQuiz(SDUIComponent)
        }

        struct KeyTerm {
            let term: String
            let definition: String
            var expandedDetail: String? = nil
        }
    }

    struct ConceptComparisonModel {
        let title: String
        let leftHeading: String
        let leftBullets: [String]
        let rightHeading: String
        let rightBullets: [String]
        let takeaway: String?
    }

    // MARK: - State

    @State private var currentIndex: Int = 0
    @State private var quizSelections: [String: String] = [:]
    @State private var reflectionText: String = ""
    @State private var showLessonMap = false
    @State private var showLyoLens = false
    @State private var activeLensTab = "Ask"
    @State private var boardAnimateState: CGFloat = 0.0 // Progressive reveal factor
    @State private var showSwipeNudge = false
    @State private var shakeOffset: CGFloat = 0.0
    @State private var isBoardTappedToComplete = false

    private var currentStep: LessonStep? {
        steps.indices.contains(currentIndex) ? steps[currentIndex] : nil
    }

    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentIndex + 1) / Double(steps.count)
    }

    private var requiresInteraction: Bool {
        guard let step = currentStep else { return false }
        if case .classroomQuiz = step.supporting {
            return true
        }
        return false
    }

    private var isInteractionCompleted: Bool {
        guard let step = currentStep else { return true }
        if case .classroomQuiz(let component) = step.supporting {
            return quizSelections[component.id] != nil
        }
        return true
    }

    private var teacherIndex: Int {
        let hash = abs(header.title.hashValue)
        return (hash % 4) + 1
    }

    private var actualTeacherName: String {
        switch teacherIndex {
        case 1: return "Mr. Newton"
        case 2: return "Dr. Saria"
        case 3: return "Prof. Chen"
        case 4: return "Mr. Davis"
        default: return "Teacher"
        }
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            ClassroomTokens.backgroundGradient
                .ignoresSafeArea()

            ClassroomTokens.ambientGlow
                .frame(width: 480, height: 480)
                .offset(y: -120)
                .allowsHitTesting(false)

            // Falling floating dust particles for immersive learning environment
            ClassroomFloatingParticlesView()

            VStack(spacing: 0) {
                // ZONE 1: Top Header
                ClassroomHeaderView(
                    courseTitle: header.title,
                    currentSceneText: "Warm-Up • Scene \(currentIndex + 1) of \(steps.count)",
                    progress: progress,
                    onBack: onBack,
                    onMapTap: {
                        HapticManager.shared.playQuizSelection()
                        showLessonMap = true
                    }
                )
                .padding(.horizontal, ClassroomTokens.pagePadding)
                .padding(.top, 8)

                if let step = currentStep {
                    VStack(spacing: 12) {
                        // ZONE 2: Classroom Stage & Avatars
                        ClassroomStageView(
                            activeSpeaker: step.speakerName,
                            teacherImageName: step.speakerImageName ?? "lyo_teacher_\(teacherIndex)",
                            teacherName: step.speakerName == "Teacher" ? actualTeacherName : step.speakerName
                        )
                        .padding(.horizontal, ClassroomTokens.pagePadding)
                        .frame(height: 70)

                        // ZONE 3: Lyo Board (Interactive centerpiece)
                        LyoBoardView(
                            step: step,
                            quizSelections: quizSelections,
                            reflectionText: $reflectionText,
                            isTappedToComplete: $isBoardTappedToComplete,
                            onOptionSelected: { component, option in
                                quizSelections[component.id] = option.id
                                onQuizAnswer(component, option)
                                unlockAndAdvanceSoftly(step)
                            }
                        )
                        .offset(x: shakeOffset)
                        .padding(.horizontal, ClassroomTokens.pagePadding)
                        .onTapGesture {
                            withAnimation(.easeOut(duration: 0.2)) {
                                isBoardTappedToComplete = true
                            }
                        }

                        // ZONE 4: Dialogue Card
                        ClassroomDialogueCard(
                            speakerName: step.speakerName == "Teacher" ? actualTeacherName : step.speakerName,
                            speakerBadge: step.speakerBadge,
                            text: step.teachingText,
                            speakerImageName: step.speakerImageName ?? "lyo_teacher_\(teacherIndex)"
                        )
                        .padding(.horizontal, ClassroomTokens.pagePadding)

                        Spacer()
                    }
                    .id(step.id)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .trailing)),
                        removal: .opacity.combined(with: .move(edge: .leading))
                    ))
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        ProgressView().tint(ClassroomTokens.accent)
                        Text("Preparing your classroom...")
                            .font(.system(size: 14, weight: .regular))
                            .foregroundStyle(ClassroomTokens.textTertiary)
                    }
                    Spacer()
                }

                // Scene dots & Swipe indicator
                HStack(spacing: 6) {
                    ForEach(0..<steps.count, id: \.self) { idx in
                        Circle()
                            .fill(idx == currentIndex ? ClassroomTokens.accent : Color.white.opacity(0.15))
                            .frame(width: idx == currentIndex ? 8 : 6, height: idx == currentIndex ? 8 : 6)
                            .animation(.spring(), value: currentIndex)
                    }
                }
                .padding(.vertical, 8)

                if showSwipeNudge {
                    Text("Choose an answer to continue")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.red.opacity(0.85))
                        .transition(.opacity.combined(with: .scale))
                        .padding(.bottom, 4)
                } else {
                    Text("Swipe left to continue")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ClassroomTokens.textTertiary)
                        .padding(.bottom, 4)
                }

                // ZONE 5: Bottom Dock (Sleek Lens Toolbar)
                LyoLensDock(
                    onLensTap: { tab in
                        HapticManager.shared.playQuizSelection()
                        activeLensTab = tab
                        showLyoLens = true
                    },
                    onMicTap: onMic
                )
                .padding(.horizontal, ClassroomTokens.pagePadding)
                .padding(.bottom, 12)
            }
        }
        .preferredColorScheme(.dark)
        .gesture(
            DragGesture()
                .onEnded { gesture in
                    let horizontalAmount = gesture.translation.width
                    if horizontalAmount < -60 {
                        // Swipe left = Next
                        goToNextScene()
                    } else if horizontalAmount > 60 {
                        // Swipe right = Previous
                        goToPreviousScene()
                    }
                }
        )
        .sheet(isPresented: $showLessonMap) {
            LessonMapSheet(steps: steps, currentIndex: currentIndex) { targetIdx in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    currentIndex = targetIdx
                    isBoardTappedToComplete = false
                }
            }
        }
        .sheet(isPresented: $showLyoLens) {
            LyoLensSheet(activeTab: $activeLensTab, step: currentStep, onAction: { intent in
                if let step = currentStep {
                    if intent == "explain" {
                        onExplainEasier(step)
                    } else if intent == "visual" {
                        onAskLyo(step) // trigger visual/graph explain
                    } else {
                        onAskLyo(step)
                    }
                }
            })
        }
    }

    // MARK: - Navigation Gestures

    private func goToNextScene() {
        guard let step = currentStep else { return }

        // Swipe locked if answer is required but not selected
        if requiresInteraction && !isInteractionCompleted {
            triggerShakeNudge()
            return
        }

        let feedback = UIImpactFeedbackGenerator(style: .medium)
        feedback.impactOccurred()

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            if currentIndex < steps.count - 1 {
                onAdvance(step)
                currentIndex += 1
                isBoardTappedToComplete = false
            } else {
                // Last step in the current scene: notify the backend to load the next scene!
                onAdvance(step)
            }
        }
    }

    private func goToPreviousScene() {
        let feedback = UIImpactFeedbackGenerator(style: .light)
        feedback.impactOccurred()

        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
            if currentIndex > 0 {
                currentIndex -= 1
                isBoardTappedToComplete = false
            }
        }
    }

    private func unlockAndAdvanceSoftly(_ step: LessonStep) {
        // Auto advance after short delay if appropriate, or let user swipe
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if let current = currentStep, current.id == step.id {
                goToNextScene()
            }
        }
    }

    private func triggerShakeNudge() {
        HapticManager.shared.playQuizSelection()
        withAnimation(.default) {
            showSwipeNudge = true
        }
        // Shake sequence
        for tick in 0...5 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(tick) * 0.08) {
                withAnimation(.spring(response: 0.1, dampingFraction: 0.3)) {
                    if tick == 5 {
                        shakeOffset = 0
                    } else {
                        shakeOffset = tick % 2 == 0 ? -12 : 12
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            withAnimation {
                showSwipeNudge = false
            }
        }
    }
}

// MARK: - Zone 1: Classroom Header

@MainActor
struct ClassroomHeaderView: View {
    let courseTitle: String
    let currentSceneText: String
    let progress: Double
    var onBack: () -> Void
    var onMapTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.06), in: Circle())
                }

                Spacer()

                VStack(spacing: 2) {
                    Text(courseTitle)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(ClassroomTokens.textPrimary)
                        .lineLimit(1)
                    Text(currentSceneText)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(ClassroomTokens.accent)
                }

                Spacer()

                Button(action: onMapTap) {
                    Image(systemName: "map.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(ClassroomTokens.accent)
                        .frame(width: 36, height: 36)
                        .background(ClassroomTokens.accent.opacity(0.12), in: Circle())
                }
            }

            // High contrast elegant progress line
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 5)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [ClassroomTokens.accent, ClassroomTokens.accentDeep],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * CGFloat(progress), height: 5)
                        .shadow(color: ClassroomTokens.accentGlow.opacity(0.4), radius: 3)
                }
            }
            .frame(height: 5)
        }
    }
}

// MARK: - Zone 2: Living Stage View

@MainActor
struct ClassroomStageView: View {
    let activeSpeaker: String
    let teacherImageName: String
    let teacherName: String

    var body: some View {
        HStack(spacing: 12) {
            // Teacher standalone png representation
            HStack(spacing: 8) {
                Image(teacherImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 54)
                    .shadow(color: ClassroomTokens.accentGlow.opacity(activeSpeaker == "Teacher" ? 0.6 : 0.0), radius: 10)
                    .scaleEffect(activeSpeaker == "Teacher" ? 1.08 : 0.95)
                    .animation(.spring(), value: activeSpeaker)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(teacherName)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(activeSpeaker == "Teacher" ? "explaining live" : "observing class")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(activeSpeaker == "Teacher" ? ClassroomTokens.accent : ClassroomTokens.textTertiary)
                }
            }

            Spacer()

            // Standing Classmates avatars row
            HStack(spacing: -10) {
                ClassmateAvatarStage(name: "Maya", imageName: "student_genius", activeSpeaker: activeSpeaker, status: "curious")
                ClassmateAvatarStage(name: "Sam", imageName: "student_clever", activeSpeaker: activeSpeaker, status: "thinking")
                ClassmateAvatarStage(name: "Rio", imageName: "student_funny", activeSpeaker: activeSpeaker, status: "grinning")
                ClassmateAvatarStage(name: "Zack", imageName: "student_dumb", activeSpeaker: activeSpeaker, status: "confused")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 16))
    }
}

@MainActor
struct ClassmateAvatarStage: View {
    let name: String
    let imageName: String
    let activeSpeaker: String
    let status: String

    var isActive: Bool {
        activeSpeaker == name
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(imageName)
                .resizable()
                .scaledToFit()
                .frame(height: 42)
                .shadow(color: ClassroomTokens.accentGlow.opacity(isActive ? 0.6 : 0.0), radius: 6)
                .scaleEffect(isActive ? 1.15 : 0.95)
                .animation(.spring(), value: activeSpeaker)
            
            if isActive {
                Text("\(name) speaks")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(ClassroomTokens.accent)
                    .padding(.horizontal, 4)
                    .background(Color.black.opacity(0.4), in: Capsule())
            }
        }
    }
}

// MARK: - Zone 3: Lyo Board View

@MainActor
struct LyoBoardView: View {
    let step: ActiveLessonView.LessonStep
    let quizSelections: [String: String]
    @Binding var reflectionText: String
    @Binding var isTappedToComplete: Bool
    var onOptionSelected: (SDUIComponent, SDUIQuizOption) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Neon top ambient glowing label
            HStack {
                Circle()
                    .fill(ClassroomTokens.accent)
                    .frame(width: 6, height: 6)
                Text("LYO BOARD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(ClassroomTokens.accent)
                Spacer()
            }

            switch step.supporting {
            case .classroomQuiz(let component):
                quizContent(component)

            case .comparison(let model):
                comparisonContent(model)

            case .lessonBlock(let block):
                BlockRendererView(block: block)
                    .padding(4)

            case .none:
                defaultExplanationContent()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(hex: "0D0E23").opacity(0.92))
                .shadow(color: ClassroomTokens.accentGlow.opacity(0.12), radius: 15)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(ClassroomTokens.glassBorder, lineWidth: 1)
        )
    }

    private func defaultExplanationContent() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lesson Focus")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ClassroomTokens.textSecondary)

            Text(step.teachingText)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(ClassroomTokens.textPrimary)
                .lineSpacing(5)
                .opacity(isTappedToComplete ? 1.0 : 0.9)
                .animation(.easeOut, value: isTappedToComplete)
        }
    }

    private func quizContent(_ component: SDUIComponent) -> some View {
        let questionText = component.question?.isEmpty == false ? component.question! : component.content
        return VStack(alignment: .leading, spacing: 12) {
            Text("Concept Check")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(ClassroomTokens.accent)

            Text(questionText)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundStyle(ClassroomTokens.textPrimary)

            if let options = component.options {
                VStack(spacing: 8) {
                    ForEach(options) { option in
                        let selected = quizSelections[component.id] == option.id
                        Button {
                            onOptionSelected(component, option)
                        } label: {
                            HStack {
                                Circle()
                                    .fill(selected ? ClassroomTokens.accent : Color.white.opacity(0.08))
                                    .frame(width: 18, height: 18)
                                    .overlay(Circle().stroke(selected ? ClassroomTokens.accent : Color.white.opacity(0.2), lineWidth: 1))
                                Text(option.label)
                                    .font(.system(size: 14, weight: selected ? .bold : .medium))
                                    .foregroundStyle(ClassroomTokens.textPrimary)
                                Spacer()
                            }
                            .padding(12)
                            .background(selected ? ClassroomTokens.accent.opacity(0.12) : Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(selected ? ClassroomTokens.accent : Color.white.opacity(0.06), lineWidth: 1))
                        }
                    }
                }
            }
        }
    }

    private func comparisonContent(_ model: ActiveLessonView.ConceptComparisonModel) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(model.title)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(ClassroomTokens.textPrimary)

            HStack(alignment: .top, spacing: 12) {
                // Left Column
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.leftHeading)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ClassroomTokens.accent)
                    ForEach(model.leftBullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•").foregroundStyle(ClassroomTokens.accent)
                            Text(bullet).font(.system(size: 12)).foregroundStyle(ClassroomTokens.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Divider line
                Rectangle()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 1)
                    .frame(maxHeight: 120)

                // Right Column
                VStack(alignment: .leading, spacing: 6) {
                    Text(model.rightHeading)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(ClassroomTokens.accent)
                    ForEach(model.rightBullets, id: \.self) { bullet in
                        HStack(alignment: .top, spacing: 4) {
                            Text("•").foregroundStyle(ClassroomTokens.accent)
                            Text(bullet).font(.system(size: 12)).foregroundStyle(ClassroomTokens.textSecondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

// MARK: - Zone 4: Dialogue Card View

@MainActor
struct ClassroomDialogueCard: View {
    let speakerName: String
    let speakerBadge: String
    let text: String
    let speakerImageName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(speakerImageName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.1), in: Circle())

                Text(speakerName)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(ClassroomTokens.textPrimary)

                Text(speakerBadge)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(ClassroomTokens.accent)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(ClassroomTokens.accent.opacity(0.15), in: Capsule())
                Spacer()
            }

            Text(text)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(ClassroomTokens.textSecondary)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .classroomGlassCard()
    }
}

// MARK: - Zone 5: Bottom Dock View

@MainActor
struct LyoLensDock: View {
    var onLensTap: (String) -> Void
    var onMicTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Mic icon
            Button(action: onMicTap) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(ClassroomTokens.accentDeep, in: Circle())
            }

            // Quick lens buttons
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    LensButton(label: "Ask Lyo", icon: "sparkles") { onLensTap("Ask") }
                    LensButton(label: "Explain Easier", icon: "wand.and.stars") { onLensTap("Explain") }
                    LensButton(label: "Visualize", icon: "chart.bar.fill") { onLensTap("Visualize") }
                    LensButton(label: "Quiz Me", icon: "checkmark.seal.fill") { onLensTap("Quiz") }
                    LensButton(label: "Notes", icon: "note.text") { onLensTap("Notes") }
                }
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.03))
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(ClassroomTokens.glassBorder, lineWidth: 1))
    }
}

@MainActor
struct LensButton: View {
    let label: String
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                Text(label)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.06), in: Capsule())
        }
    }
}

// MARK: - Overlay: Lesson Map Sheet

@MainActor
struct LessonMapSheet: View {
    let steps: [ActiveLessonView.LessonStep]
    let currentIndex: Int
    var onJump: (Int) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "0A0B1F").ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        Text("Today's Course roadmap")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .padding(.top, 10)

                        ForEach(0..<steps.count, id: \.self) { idx in
                            let step = steps[idx]
                            Button {
                                onJump(idx)
                                dismiss()
                            } label: {
                                HStack(spacing: 16) {
                                    // Bullet status indicator
                                    ZStack {
                                        if idx < currentIndex {
                                            Circle()
                                                .fill(ClassroomTokens.accent)
                                                .frame(width: 28, height: 28)
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(.white)
                                        } else if idx == currentIndex {
                                            Circle()
                                                .stroke(ClassroomTokens.accent, lineWidth: 2)
                                                .frame(width: 28, height: 28)
                                            Circle()
                                                .fill(ClassroomTokens.accent)
                                                .frame(width: 12, height: 12)
                                        } else {
                                            Circle()
                                                .fill(Color.white.opacity(0.12))
                                                .frame(width: 28, height: 28)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Scene \(idx + 1)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(idx == currentIndex ? ClassroomTokens.accent : .secondary)
                                        Text(step.teachingText)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(idx == currentIndex ? .white : .white.opacity(0.6))
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                }
                                .padding(12)
                                .background(idx == currentIndex ? Color.white.opacity(0.05) : Color.clear, in: RoundedRectangle(cornerRadius: 14))
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
            .navigationTitle("Lesson Outline")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Overlay: Lyo Lens Sheet

@MainActor
struct LyoLensSheet: View {
    @Binding var activeTab: String
    let step: ActiveLessonView.LessonStep?
    var onAction: (String) -> Void
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color(hex: "0A0B1F").ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Image("LyoThinking")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Lyo Lens")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Ask me to clarify, summarize, or quiz you")
                            .font(.system(size: 12))
                            .foregroundStyle(ClassroomTokens.textSecondary)
                    }
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Main options grid
                ScrollView {
                    VStack(spacing: 14) {
                        LensOptionCard(title: "Explain Easier", subtitle: "Break this scene down into simpler, friendly terminology.", icon: "wand.and.stars") {
                            onAction("explain")
                            dismiss()
                        }
                        LensOptionCard(title: "Visualize Scene", subtitle: "Transform text descriptions into custom vector graph charts.", icon: "chart.bar.fill") {
                            onAction("visual")
                            dismiss()
                        }
                        LensOptionCard(title: "Mini Quiz Me", subtitle: "Test your comprehension right now on this core fact.", icon: "checkmark.seal.fill") {
                            onAction("quiz")
                            dismiss()
                        }
                        LensOptionCard(title: "Save to notes", subtitle: "Pin this smart board to your memory cards notebook.", icon: "note.text") {
                            onAction("notes")
                            dismiss()
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

@MainActor
struct LensOptionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundStyle(ClassroomTokens.accent)
                    .frame(width: 44, height: 44)
                    .background(ClassroomTokens.accent.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(ClassroomTokens.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
            }
            .padding(14)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(ClassroomTokens.glassBorder, lineWidth: 1))
        }
    }
}

// MARK: - Animated Floating Particles View

@MainActor
struct ClassroomFloatingParticlesView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for i in 0..<15 {
                    let seed = Double(i)
                    let x = size.width * CGFloat(abs(sin(seed + time * 0.1)))
                    let y = size.height * CGFloat(abs(cos(seed * 2 + time * 0.08)))
                    let radius = CGFloat(2 + sin(seed + time) * 1)
                    let rect = CGRect(x: x, y: y, width: radius, height: radius)
                    context.fill(Path(ellipseIn: rect), with: .color(ClassroomTokens.accent.opacity(0.12)))
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
