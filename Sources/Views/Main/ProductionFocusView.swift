import SwiftUI

/// Production Focus surface.
///
/// Focus is the home of the learner's saved courses — and the only home they
/// have: `UIStackStore.items` is read by the classroom, Discover and test prep,
/// but nothing else renders it as a list you can browse. So this screen shows
/// that one list once, as one scrollable stack, rather than splitting the same
/// array into a hero carousel and an "all saved" section underneath.
///
/// Top to bottom, and in this order on purpose: who you are, how to start
/// something new, the test you have coming up, your courses, the people you
/// follow, this week's quest. The two things a learner comes here to do —
/// resume a course and start one — are both above the fold.
///
/// This view renders only values backed by the authenticated user, the
/// persisted course-session stack, the test-prep plan and the community feed.
/// It does not synthesize daily XP, durations, progress, social activity or
/// recommended courses. Where a figure is missing it says so; the branching
/// lives in `FocusPresentation` and `TestPrepPresentation`, which are tested.
struct FocusView: View {
    @EnvironmentObject private var rootViewModel: RootViewModel
    @EnvironmentObject private var uiState: AppUIState
    @EnvironmentObject private var uiStackStore: UIStackStore

    @StateObject private var testPrep = TestPrepViewModel()
    @StateObject private var followFeed = FocusFollowFeedModel()
    @ObservedObject private var memory = SmartMemoryService.shared

    @State private var isRefreshing = false
    @State private var filter: FocusPresentation.Filter = .all
    /// Saved courses start stacked, and open on a tap. See `courseStack`.
    @State private var deckExpanded = false

    private var user: User? { rootViewModel.currentUser }

    private var savedCourses: [UIStackItem] {
        FocusPresentation.courses(in: uiStackStore.items)
    }

    private var visibleCourses: [UIStackItem] {
        savedCourses.filter { FocusPresentation.matches($0, filter: filter) }
    }

    private var weakConcepts: [String] {
        FocusPresentation.weakConcepts(memory.memory?.struggles ?? [])
    }

    /// The screen's side gutter. Course cards cancel it to run nearly edge to
    /// edge; headings and chips keep it.
    private let gutter: CGFloat = 15

    var body: some View {
        NavigationStack {
            ZStack {
                focusBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        identityStrip
                        FocusCreateComposer(weakConcepts: weakConcepts)
                        testPrepSection
                        courseSection
                        followSection
                        WeeklyQuestBanner()
                    }
                    .padding(.horizontal, gutter)
                    .padding(.top, 14)
                    .padding(.bottom, 130)
                }
                .refreshable { await refresh() }

                if isRefreshing {
                    VStack {
                        ProgressView()
                            .tint(.white)
                            .padding(12)
                            .background(.ultraThinMaterial, in: Circle())
                            .padding(.top, 8)
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { await refresh() }
        }
    }

    // MARK: - Background

    private var focusBackground: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "050810"), Color(hex: "0A1020"), Color(hex: "0D0F18")],
                startPoint: .top,
                endPoint: .bottom
            )

            RadialGradient(
                colors: [Color(hex: "7C3AED").opacity(0.24), .clear],
                center: .topTrailing,
                startRadius: 30,
                endRadius: 420
            )

            RadialGradient(
                colors: [Color(hex: "0EA5E9").opacity(0.13), .clear],
                center: .bottomLeading,
                startRadius: 40,
                endRadius: 380
            )
        }
    }

    // MARK: - 1. Identity

    /// Greeting and the three figures the account actually carries, on one
    /// line. This replaced a 2×2 grid of metric tiles that cost around 255pt
    /// to report the same numbers and pushed every course below the fold.
    private var identityStrip: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 1) {
                Text(timeBasedGreeting)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
                Text(displayName)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Spacer(minLength: 4)

            if let user {
                HStack(spacing: 0) {
                    vital(value: "\(user.streak)", label: "Streak", icon: "flame.fill", tint: DesignTokens.Colors.warning)
                    divider
                    vital(value: user.xp.formatted(), label: "XP")
                    divider
                    vital(value: "\(user.level)", label: "Level")
                }
                .fixedSize()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var avatar: some View {
        ZStack {
            Circle()
                .stroke(DesignTokens.Colors.accentSecondary.opacity(0.55), lineWidth: 2)
                .frame(width: 46, height: 46)
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "4F3A8C"), Color(hex: "241C40")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 40, height: 40)
            Text(initial)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .accessibilityHidden(true)
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.09))
            .frame(width: 1, height: 26)
    }

    private func vital(
        value: String,
        label: String,
        icon: String? = nil,
        tint: Color = .white
    ) -> some View {
        VStack(alignment: .trailing, spacing: 3) {
            HStack(spacing: 3) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 10))
                        .foregroundStyle(tint)
                }
                Text(value)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.system(size: 8.5, weight: .bold))
                .tracking(0.9)
                .textCase(.uppercase)
                .foregroundStyle(.white.opacity(0.42))
        }
        .padding(.horizontal, 11)
    }

    // MARK: - 3. Test prep

    @ViewBuilder
    private var testPrepSection: some View {
        // Only a loaded plan gets the big card. A failed lookup is not the same
        // as "no test", so neither state invents the other: without a plan the
        // prompt is shown, which is true in both cases and costs one line.
        if testPrep.state.stage == .plan, testPrep.state.planId != nil {
            NavigationLink {
                TestPrepView()
            } label: {
                FocusTestPrepCard(
                    readiness: testPrep.state.readiness,
                    sessions: testPrep.state.sessions,
                    isStale: testPrep.state.readinessFailed || testPrep.state.refreshFailed
                )
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink {
                TestPrepView()
            } label: {
                FocusTestPrepPrompt()
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - 4. The stack

    private var courseSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Your courses")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text(countLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.42))
            }

            if !savedCourses.isEmpty { filterChips }

            if savedCourses.isEmpty {
                FocusEmptyLearningCard()
            } else if visibleCourses.isEmpty {
                emptyFilterNotice
            } else {
                courseStack
            }
        }
    }

    /// Saved courses, as a deck that opens.
    ///
    /// Shut, it is one card with the rest of the library stacked under it, so
    /// a screenful of courses does not begin as a wall of cards. Its Resume
    /// button is live in that state — only the card body's tap is taken over
    /// — so a learner coming back to a course never opens the deck first.
    ///
    /// Open, it is one row that scrolls sideways and snaps card to card. The
    /// whole library then costs the screen one card's height instead of one
    /// per course, which is what makes the rest of Focus reachable.
    private var courseStack: some View {
        VStack(spacing: 12) {
            if deckExpanded {
                openDeck
            } else if let top = visibleCourses.first {
                shutDeck(top: top)
            }

            deckControl
        }
        // Cards cancel the screen gutter and keep 2pt, so they run to ~99% of
        // the screen width while the headings above stay on the margin.
        .padding(.horizontal, -(gutter - 2))
    }

    /// One card, with the rest of the library stacked under it.
    private func shutDeck(top: UIStackItem) -> some View {
        ZStack(alignment: .top) {
            peekLayers

            FocusCourseCard(
                item: top,
                onAction: { openCourse(top) },
                onTapBody: topCardTap
            )
        }
        // Room for the peek cards, which are offset rather than laid out, so
        // they would otherwise overlap whatever comes next.
        .padding(.bottom, deepestPeekOffset)
    }

    /// Every saved course, in one row that scrolls sideways.
    ///
    /// Each card stops short of the container so the next one's edge is
    /// always showing. A card the full width of the screen would put every
    /// course after the first behind a swipe nothing signals, which is the
    /// mistake the carousel this screen replaced already made. The width and
    /// the gap come from `FocusPresentation`, so web and Android leave the
    /// same sliver showing.
    private var openDeck: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: CGFloat(FocusPresentation.deckCardGap)) {
                ForEach(Array(visibleCourses.enumerated()), id: \.element.id) { index, item in
                    FocusCourseCard(
                        item: item,
                        onAction: { openCourse(item) }
                    )
                    .containerRelativeFrame(.horizontal) { width, _ in
                        CGFloat(FocusPresentation.deckCardWidth(containerWidth: Double(width)))
                    }
                    .transition(deckTransition(index: index))
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal, 2)
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollClipDisabled()
    }

    private var deckLayers: [FocusPresentation.DeckLayer] {
        FocusPresentation.deckLayers(cardCount: visibleCourses.count)
    }

    private var deepestPeekOffset: CGFloat {
        CGFloat(deckLayers.last?.offset ?? 0)
    }

    /// Blank cards under the top one. They carry no title and no figures: they
    /// stand for courses the learner has, and a title drawn at 90% scale and
    /// half opacity would be a label nobody can read.
    private var peekLayers: some View {
        ForEach(deckLayers.reversed()) { layer in
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color(hex: "1C2436").opacity(layer.opacity))
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .stroke(Color.white.opacity(0.11), lineWidth: 1)
                }
                .frame(height: 206)
                .scaleEffect(x: CGFloat(layer.scale), y: 1, anchor: .top)
                .offset(y: CGFloat(layer.offset))
                .transition(.opacity)
                .accessibilityHidden(true)
        }
    }

    /// The top card opens the deck only while the deck is shut and there is
    /// something under it. Otherwise the card keeps its own tap, which turns
    /// it over for the description.
    private var topCardTap: (() -> Void)? {
        guard !deckExpanded, !deckLayers.isEmpty else { return nil }
        return { setDeck(expanded: true) }
    }

    /// Open the stack, or put it back.
    ///
    /// Shut, this says how many courses are waiting — the real number from
    /// the list, not the two cards drawn behind the top one.
    @ViewBuilder
    private var deckControl: some View {
        if let more = FocusPresentation.deckMoreLabel(cardCount: visibleCourses.count) {
            Button {
                setDeck(expanded: !deckExpanded)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "rectangle.stack")
                        .font(.system(size: 11, weight: .semibold))
                    Text(deckExpanded ? "Stack them back up" : more)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                    Image(systemName: deckExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
                .foregroundStyle(.white.opacity(0.7))
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.05), in: Capsule())
                .overlay {
                    Capsule().stroke(Color.white.opacity(0.08), lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint(
                deckExpanded
                    ? "Closes the list back into a stack"
                    : "Opens the stack into a list of every saved course"
            )
        }
    }

    /// Cards arrive one after another rather than all at once, which is what
    /// makes the deck read as opening instead of simply appearing. The delays
    /// are shared with web and Android and capped, so a large library does not
    /// mean waiting for the row.
    private func deckTransition(index: Int) -> AnyTransition {
        let delay = Double(FocusPresentation.deckStaggerMilliseconds(index: index)) / 1000
        return .asymmetric(
            insertion: .scale(scale: 0.96, anchor: .leading)
                .combined(with: .opacity)
                .animation(.spring(response: 0.42, dampingFraction: 0.88).delay(delay)),
            removal: .opacity.animation(.easeOut(duration: 0.14))
        )
    }

    private func setDeck(expanded: Bool) {
        HapticManager.shared.light()
        withAnimation(.spring(response: 0.44, dampingFraction: 0.86)) {
            deckExpanded = expanded
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(FocusPresentation.Filter.allCases) { option in
                    let count = savedCourses.filter { FocusPresentation.matches($0, filter: option) }.count
                    Button {
                        HapticManager.shared.light()
                        filter = option
                    } label: {
                        Text("\(option.title) \(count)")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(filter == option ? .white : .white.opacity(0.62))
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                filter == option
                                    ? DesignTokens.Colors.accentSecondary.opacity(0.22)
                                    : Color.white.opacity(0.045),
                                in: Capsule()
                            )
                            .overlay {
                                Capsule().stroke(
                                    filter == option
                                        ? DesignTokens.Colors.accentSecondaryLight.opacity(0.45)
                                        : Color.white.opacity(0.07),
                                    lineWidth: 1
                                )
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(filter == option ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, gutter)
        }
        .scrollClipDisabled()
        .padding(.horizontal, -gutter)
    }

    private var emptyFilterNotice: some View {
        Text("No courses in this filter.")
            .font(.system(size: 12))
            .foregroundStyle(.white.opacity(0.46))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 26)
            .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.065), lineWidth: 1)
            }
    }

    private var countLabel: String {
        let total = savedCourses.count
        if filter == .all { return total == 1 ? "1 saved" : "\(total) saved" }
        return "\(visibleCourses.count) of \(total)"
    }

    // MARK: - 6. People you follow

    private var followSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("From people you follow")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Spacer()
                Text("5 newest")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.42))
            }

            FocusFollowRail(
                state: followFeed.state,
                onSeeAll: openCommunity,
                onOpen: { _ in openCommunity() }
            )
        }
    }

    private func openCommunity() {
        HapticManager.shared.light()
        uiState.currentTab = .campus
    }

    // MARK: - Copy

    private var displayName: String {
        let trimmed = user?.name.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !trimmed.isEmpty else { return "Learner" }
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }

    private var initial: String {
        String(displayName.prefix(1)).uppercased()
    }

    private var timeBasedGreeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default: return "Welcome back"
        }
    }

    // MARK: - Data

    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        async let profile: Void = rootViewModel.refreshUserData()
        async let reviews: Void = uiStackStore.refreshDueReviews()
        async let plan: Void = testPrep.load()
        async let feed: Void = followFeed.load()
        async let struggles: Void = memory.fetchMemory()
        _ = await (profile, reviews, plan, feed, struggles)
    }

    private func openCourse(_ item: UIStackItem) {
        guard let courseId = item.courseId?.trimmingCharacters(in: .whitespacesAndNewlines),
              !courseId.isEmpty else {
            return
        }

        var userInfo: [AnyHashable: Any] = [
            "courseId": courseId,
            "courseTitle": item.title,
            "lessonTitle": item.subtitle ?? item.title,
            "shouldGenerateCourse": courseId.hasPrefix("GENERATE:")
        ]

        if let lessonId = item.lessonId, !lessonId.isEmpty {
            userInfo["lessonId"] = lessonId
        }
        if courseId.hasPrefix("GENERATE:") {
            userInfo["topic"] = String(courseId.dropFirst("GENERATE:".count))
        }

        HapticManager.shared.medium()
        NotificationCenter.default.post(
            name: .openClassroom,
            object: nil,
            userInfo: userInfo
        )
    }
}

// MARK: - Nothing saved yet

/// Shown when the stack is genuinely empty.
///
/// It no longer carries the only create button on the screen — the composer
/// above is always there — so this says what the stack is for and nothing more.
private struct FocusEmptyLearningCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("No saved courses yet")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
            Text("Ask Lio for a course above and it will be saved here, on every device you sign in on.")
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.55))
                .lineSpacing(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.11), lineWidth: 1)
        }
    }
}
