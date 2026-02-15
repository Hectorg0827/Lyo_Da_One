//
//  A2UIMiscViews.swift
//  Lyo
//
//  Document, Course, Navigation, Widget, Gamification, AI, Social, System views
//

import SwiftUI

// MARK: - Document Views

struct A2UIDocumentViewerView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text(props.title ?? "Document")
                    .font(.headline)
                Spacer()
            }
            
            if let content = props.documentContent {
                ScrollView {
                    Text(content)
                        .font(.body)
                }
            }
            
            if let highlights = props.highlights, !highlights.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Highlights")
                        .font(.caption.bold())
                    ForEach(highlights, id: \.id) { highlight in
                        Text("\"\(highlight.text)\"")
                            .font(.callout)
                            .padding(8)
                            .background(Color.yellow.opacity(0.3))
                            .cornerRadius(4)
                    }
                }
            }
        }
        .padding()
    }
}

struct A2UIAnnotationToolView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(spacing: 16) {
            ToolButton(icon: "highlighter", label: "Highlight", color: .yellow)
            ToolButton(icon: "pencil", label: "Draw", color: .blue)
            ToolButton(icon: "text.bubble", label: "Note", color: .green)
            ToolButton(icon: "bookmark", label: "Bookmark", color: .orange)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct A2UIAutoNotesView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI-Generated Notes")
                    .font(.headline)
            }
            
            if let notes = props.generatedNotes {
                Text(notes)
                    .font(.callout)
            } else if let body = props.body {
                Text(body)
                    .font(.callout)
            }
            
            HStack {
                Button("Copy Notes") {}
                    .buttonStyle(.bordered)
                Button("Edit") {}
                    .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(16)
    }
}

struct A2UIFlashcardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        PremiumFlashcardView(
            front: props.flashcardFront ?? props.title ?? "Question",
            back: props.flashcardBack ?? "Answer",
            hint: props.hint,
            showMasteryButton: false
        )
        .frame(height: 220)
    }
}

struct A2UIDocumentGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.fill")
                    .foregroundColor(.blue)
                Text(props.title ?? "Document")
                    .font(.headline)
            }
            if let body = props.body {
                Text(body).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Course Views

struct A2UICourseCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Cover image placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(height: 120)
                .overlay(
                    Image(systemName: "book.fill")
                        .font(.largeTitle)
                        .foregroundColor(.white.opacity(0.8))
                )
            
            Text(props.title ?? "Course")
                .font(.headline)
            
            if let subtitle = props.subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let progress = props.progressPercent {
                ProgressView(value: progress / 100)
                    .tint(.blue)
                Text("\(Int(progress))% complete")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
    }
}

struct A2UILessonCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(props.isCompleted == true ? Color.green : Color(.systemGray5))
                    .frame(width: 40, height: 40)
                if props.isCompleted == true {
                    Image(systemName: "checkmark")
                        .foregroundColor(.white)
                } else if let number = props.lessonNumber {
                    Text("\(number)")
                        .font(.headline)
                }
            }
            
            VStack(alignment: .leading) {
                Text(props.title ?? "Lesson")
                    .font(.subheadline.bold())
                if let duration = props.duration {
                    Text("\(duration) min")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if props.isLocked == true {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(props.isLocked == true ? 0.6 : 1)
    }
}

struct A2UICourseProgressView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("Course Progress")
                    .font(.headline)
                Spacer()
                Text("\(Int(props.progressPercent ?? 0))%")
                    .font(.title2.bold())
                    .foregroundColor(.blue)
            }
            
            ProgressView(value: (props.progressPercent ?? 0) / 100)
                .tint(.blue)
                .scaleEffect(y: 2)
            
            HStack {
                Label("\(props.completedLessons ?? 0) completed", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Spacer()
                Label("\(props.remainingLessons ?? 0) remaining", systemImage: "circle")
                    .foregroundColor(.secondary)
            }
            .font(.caption)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct A2UIModuleListView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let title = props.title {
                Text(title)
                    .font(.headline)
            }
            
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
        .padding()
    }
}

struct A2UICourseGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "book.circle.fill")
                    .foregroundColor(.blue)
                Text(props.title ?? "Course")
                    .font(.headline)
            }
            if let body = props.body {
                Text(body).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Navigation Views

struct A2UIButtonView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        styledButton
    }

    private var baseButton: some View {
        Button {
            // FIX: Prioritize explicit action type or title over random IDs
            // If the backend provided a specific action (e.g. "create_course"), use it
            // Otherwise use the button text which the AI can understand (e.g. "Quiz Me")
            let actionType = props.actionType
            let displayTitle = props.title ?? props.label ?? "Button"
            
            // Use action_title prop if available (legacy support)
            let legacyActionTitle = props.actionTitle
            
            let finalId = actionType ?? legacyActionTitle ?? displayTitle
            
            let action = A2UIAction(
                id: UUID().uuidString,
                trigger: .tap,
                type: .deepLink,
                payload: [
                    "id": .string(finalId),
                    "title": .string(displayTitle),
                    "action_type": .string(actionType ?? "user_intent")
                ]
            )
            onAction?(action)
        } label: {
            HStack {
                if let icon = props.iconName {
                    Image(systemName: icon)
                }
                Text(props.title ?? props.label ?? "Button")
            }
            .frame(maxWidth: props.isFullWidth == true ? .infinity : nil)
        }
    }

    @ViewBuilder
    private var styledButton: some View {
        switch props.buttonStyle {
        case "bordered":
            baseButton.buttonStyle(.bordered)
        case "borderedProminent":
            baseButton.buttonStyle(.borderedProminent)
        case "plain":
            baseButton.buttonStyle(.plain)
        default:
            baseButton.buttonStyle(.automatic)
        }
    }
}

struct A2UILinkView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        Button {
            // Handle navigation
        } label: {
            HStack {
                if let icon = props.iconName {
                    Image(systemName: icon)
                }
                Text(props.title ?? "Link")
                if props.showExternalIcon == true {
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
        }
        .foregroundColor(.blue)
    }
}

struct A2UINavBarView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack {
            if props.showBackButton != false {
                Button {
                    // Handle back
                } label: {
                    Image(systemName: "chevron.left")
                }
            }
            
            Spacer()
            
            Text(props.title ?? "")
                .font(.headline)
            
            Spacer()
            
            if let rightIcon = props.rightIconName {
                Button {
                    // Handle action
                } label: {
                    Image(systemName: rightIcon)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct A2UITabBarView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction) -> Void)?
    @State private var selectedTab = 0
    
    var body: some View {
        HStack {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                Button {
                    selectedTab = index
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: child.props.iconName ?? "circle")
                            .font(.title3)
                        Text(child.props.title ?? "")
                            .font(.caption2)
                    }
                    .foregroundColor(selectedTab == index ? .blue : .secondary)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

struct A2UIBreadcrumbView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
                if let items = props.breadcrumbItems {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        if index > 0 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Text(item)
                            .font(.caption)
                            .foregroundColor(index == items.count - 1 ? .primary : .blue)
                    }
                }
            }
        }
    }
}

struct A2UIFloatingActionView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        Button {
            // Handle action
        } label: {
            Image(systemName: props.iconName ?? "plus")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.blue)
                .clipShape(Circle())
                .shadow(radius: 4)
        }
    }
}

struct A2UINavigationGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        HStack {
            if let icon = props.iconName {
                Image(systemName: icon)
            }
            Text(props.title ?? "Navigation")
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Widget Views

struct A2UIProgressRingView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray5), lineWidth: 12)
            Circle()
                .trim(from: 0, to: (props.progressPercent ?? 0) / 100)
                .stroke(Color.blue, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            VStack {
                Text("\(Int(props.progressPercent ?? 0))%")
                    .font(.title.bold())
                if let label = props.label {
                    Text(label)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(width: props.size ?? 100, height: props.size ?? 100)
    }
}

struct A2UICountdownView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack {
            Text(props.timeRemaining ?? "00:00")
                .font(.system(size: 48, weight: .bold, design: .rounded))
            if let label = props.label {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct A2UIStatCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            if let icon = props.iconName {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            Text(props.statValue ?? "0")
                .font(.title.bold())
            Text(props.label ?? props.title ?? "Stat")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct A2UIQuoteView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\"\(props.quote ?? props.body ?? "")\"")
                .font(.title3.italic())
            if let author = props.quoteAuthor {
                Text("— \(author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct A2UITipView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "lightbulb.fill")
                .foregroundColor(.yellow)
            VStack(alignment: .leading) {
                Text("Tip")
                    .font(.caption.bold())
                Text(props.body ?? "")
                    .font(.callout)
            }
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
    }
}

struct A2UIAlertView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: alertIcon)
                .foregroundColor(alertColor)
            VStack(alignment: .leading) {
                if let title = props.alertTitle ?? props.title {
                    Text(title)
                        .font(.subheadline.bold())
                }
                Text(props.body ?? "")
                    .font(.callout)
            }
            Spacer()
            if props.isDismissible == true {
                Button {
                    // Dismiss
                } label: {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(alertColor.opacity(0.1))
        .cornerRadius(12)
    }
    
    private var alertIcon: String {
        switch props.alertType {
        case "error": return "xmark.circle.fill"
        case "warning": return "exclamationmark.triangle.fill"
        case "success": return "checkmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
    
    private var alertColor: Color {
        switch props.alertType {
        case "error": return .red
        case "warning": return .orange
        case "success": return .green
        default: return .blue
        }
    }
}

struct A2UIEmptyStateView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: props.iconName ?? "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(props.title ?? "Nothing here yet")
                .font(.headline)
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle = props.actionTitle {
                Button(actionTitle) {
                    // Handle action
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }
}

struct A2UIBannerView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack {
            if let icon = props.iconName {
                Image(systemName: icon)
            }
            VStack(alignment: .leading) {
                if let title = props.title {
                    Text(title).font(.subheadline.bold())
                }
                if let body = props.body {
                    Text(body).font(.caption)
                }
            }
            Spacer()
            if props.isDismissible == true {
                Button {
                    // Dismiss
                } label: {
                    Image(systemName: "xmark")
                }
            }
        }
        .padding()
        .background(bannerColor)
        .foregroundColor(.white)
    }
    
    private var bannerColor: Color {
        if let hex = props.backgroundColor {
            return Color(hex: hex)
        }
        return .blue
    }
}

struct A2UIWidgetGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title = props.title {
                Text(title).font(.headline)
            }
            if let body = props.body {
                Text(body).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Gamification Views

struct A2UIXPBarView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Level \(props.level ?? "\(props.levelNumber ?? 1)")")
                    .font(.headline)
                Spacer()
                Text("\(props.currentXP ?? 0)/\(props.nextLevelXP ?? 100) XP")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * xpProgress)
                }
            }
            .frame(height: 8)
        }
        .padding()
    }
    
    private var xpProgress: CGFloat {
        guard let current = props.currentXP, let next = props.nextLevelXP, next > 0 else {
            return 0
        }
        return CGFloat(current) / CGFloat(next)
    }
}

struct A2UIAchievementView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(props.isUnlocked == true ? Color.yellow : Color(.systemGray5))
                    .frame(width: 50, height: 50)
                Image(systemName: props.iconName ?? "star.fill")
                    .foregroundColor(props.isUnlocked == true ? .white : .gray)
            }
            
            VStack(alignment: .leading) {
                Text(props.title ?? "Achievement")
                    .font(.subheadline.bold())
                if let body = props.body {
                    Text(body)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if props.isUnlocked != true {
                Image(systemName: "lock.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .opacity(props.isUnlocked == true ? 1 : 0.6)
    }
}

struct A2UILeaderboardRowView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Text("\(props.rank ?? 0)")
                .font(.headline)
                .frame(width: 30)
            
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String((props.username ?? "?").prefix(1)).uppercased())
                        .font(.headline)
                )
            
            VStack(alignment: .leading) {
                Text(props.username ?? "User")
                    .font(.subheadline.bold())
                Text("\(props.score ?? 0) pts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if props.rank == 1 {
                Text("🥇")
            } else if props.rank == 2 {
                Text("🥈")
            } else if props.rank == 3 {
                Text("🥉")
            }
        }
        .padding()
    }
}

struct A2UIStreakDisplayView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack {
            Text("🔥")
                .font(.largeTitle)
            VStack(alignment: .leading) {
                Text("\(props.streakCount ?? 0) Day Streak!")
                    .font(.headline)
                Text("Keep learning to maintain your streak")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding()
        .background(
            LinearGradient(colors: [.orange.opacity(0.2), .yellow.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
        )
        .cornerRadius(16)
    }
}

struct A2UIBadgeView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Image(systemName: props.iconName ?? "star.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
            Text(props.title ?? "Badge")
                .font(.caption.bold())
            if let earnedDate = props.earnedDate {
                Text(earnedDate, style: .date)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct A2UIRewardAnimationView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    @State private var animate = false
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                ForEach(0..<6) { i in
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                        .offset(x: animate ? CGFloat.random(in: -50...50) : 0,
                                y: animate ? CGFloat.random(in: -50...50) : 0)
                        .opacity(animate ? 0 : 1)
                        .animation(.easeOut(duration: 1).delay(Double(i) * 0.1), value: animate)
                }
                
                Image(systemName: props.iconName ?? "gift.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .scaleEffect(animate ? 1.2 : 1)
                    .animation(.spring(), value: animate)
            }
            
            Text(props.title ?? "Reward!")
                .font(.title2.bold())
            
            if let xp = props.xpAwarded {
                Text("+\(xp) XP")
                    .font(.headline)
                    .foregroundColor(.green)
            }
        }
        .onAppear {
            animate = true
        }
    }
}

struct A2UIGamificationGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        HStack {
            Image(systemName: "gamecontroller.fill")
                .foregroundColor(.purple)
            Text(props.title ?? "Gamification")
                .font(.headline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - AI Assistant Views

struct A2UIAIMessageView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("LyoAvatar")
                .resizable()
                .frame(width: 32, height: 32)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 8) {
                Text(props.body ?? "")
                    .font(.body)
                
                if let suggestions = props.suggestions {
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                // Handle suggestion tap
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

struct A2UITypingIndicatorView: View {
    let props: A2UIProps
    @State private var animate = false
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Color.secondary)
                    .frame(width: 8, height: 8)
                    .offset(y: animate ? -4 : 4)
                    .animation(.easeInOut(duration: 0.5).repeatForever().delay(Double(i) * 0.15), value: animate)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemGray6))
        .cornerRadius(16)
        .onAppear {
            animate = true
        }
    }
}

struct A2UISuggestionChipsView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(props.suggestions ?? [], id: \.self) { suggestion in
                    Button(suggestion) {
                        // Handle tap
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(20)
                }
            }
        }
    }
}

struct A2UIThinkingView: View {
    let props: A2UIProps
    @State private var rotation = 0.0
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.title2)
                .foregroundColor(.purple)
                .rotationEffect(.degrees(rotation))
                .animation(.linear(duration: 2).repeatForever(autoreverses: false), value: rotation)
            
            Text(props.body ?? "Thinking...")
                .foregroundColor(.secondary)
        }
        .padding()
        .onAppear {
            rotation = 360
        }
    }
}

struct A2UIContextCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Context")
                    .font(.caption.bold())
            }
            Text(props.body ?? "")
                .font(.callout)
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
}

struct A2UIAIGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        HStack {
            Image(systemName: "brain")
                .foregroundColor(.purple)
            Text(props.title ?? "AI")
                .font(.headline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Social Views

struct A2UIUserCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: 50, height: 50)
                .overlay(
                    Text(String((props.username ?? "?").prefix(1)).uppercased())
                        .font(.headline)
                )
            
            VStack(alignment: .leading) {
                Text(props.username ?? "User")
                    .font(.subheadline.bold())
                if let bio = props.bio {
                    Text(bio)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button("Follow") {
                // Handle follow
            }
            .buttonStyle(.bordered)
        }
        .padding()
    }
}

struct A2UICommentView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 32, height: 32)
                Text(props.username ?? "User")
                    .font(.subheadline.bold())
                if let timestamp = props.timestamp {
                    Text(timestamp, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Text(props.body ?? "")
                .font(.callout)
            
            HStack(spacing: 16) {
                Button {
                    // Like
                } label: {
                    Label("\(props.likeCount ?? 0)", systemImage: "heart")
                        .font(.caption)
                }
                
                Button {
                    // Reply
                } label: {
                    Label("Reply", systemImage: "arrowshape.turn.up.left")
                        .font(.caption)
                }
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }
}

struct A2UIReactionBarView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        HStack(spacing: 24) {
            Button {
                // Like
            } label: {
                Label("\(props.likeCount ?? 0)", systemImage: props.isLiked == true ? "heart.fill" : "heart")
                    .foregroundColor(props.isLiked == true ? .red : .secondary)
            }
            
            Button {
                // Comment
            } label: {
                Label("\(props.commentCount ?? 0)", systemImage: "bubble.right")
            }
            
            Button {
                // Share
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            
            Spacer()
            
            Button {
                // Bookmark
            } label: {
                Image(systemName: props.isBookmarked == true ? "bookmark.fill" : "bookmark")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .padding()
    }
}

struct A2UIShareSheetView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Share")
                .font(.headline)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 20) {
                ShareOption(icon: "message.fill", label: "Message", color: .green)
                ShareOption(icon: "envelope.fill", label: "Email", color: .blue)
                ShareOption(icon: "doc.on.doc", label: "Copy", color: .gray)
                ShareOption(icon: "square.and.arrow.up", label: "More", color: .orange)
            }
        }
        .padding()
    }
}

struct A2UIStudyGroupCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .foregroundColor(.blue)
                Text(props.title ?? "Study Group")
                    .font(.headline)
                Spacer()
                Text("\(props.memberCount ?? 0) members")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
            
            Button("Join Group") {
                // Handle join
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(16)
    }
}

struct A2UISocialGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        HStack {
            Image(systemName: "person.2.fill")
                .foregroundColor(.blue)
            Text(props.title ?? "Social")
                .font(.headline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - System Views

struct A2UILoadingView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            if let message = props.loadingMessage ?? props.body {
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

struct A2UIErrorView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            Text(props.title ?? "Error")
                .font(.headline)
            
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if props.showRetry == true {
                Button("Try Again") {
                    // Handle retry
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct A2UISuccessView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text(props.title ?? "Success!")
                .font(.headline)
            
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }
}

struct A2UIPermissionRequestView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: props.iconName ?? "hand.raised.fill")
                .font(.system(size: 48))
                .foregroundColor(.blue)
            
            Text(props.title ?? "Permission Required")
                .font(.headline)
            
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 16) {
                Button("Not Now") {
                    // Dismiss
                }
                .buttonStyle(.bordered)
                
                Button("Allow") {
                    // Grant permission
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
}

struct A2UIDebugInfoView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Debug Info")
                .font(.caption.bold())
            
            Text(props.debugInfo ?? "No debug info")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct A2UISystemGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        HStack {
            Image(systemName: "gear")
                .foregroundColor(.gray)
            Text(props.title ?? "System")
                .font(.headline)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

// MARK: - Helper Views

private struct ToolButton: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        Button {
            // Handle tool selection
        } label: {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct ShareOption: View {
    let icon: String
    let label: String
    let color: Color
    
    var body: some View {
        Button {
            // Handle share
        } label: {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 50, height: 50)
                    Image(systemName: icon)
                        .foregroundColor(color)
                }
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

// FlowLayout has been moved to Sources/Components/Common/FlowLayout.swift
