import SwiftUI

struct LyoMessageBubbleView: View {
    let message: LyoMessage
    var onActionTap: ((MessageAction) -> Void)?
    var onQuickChipTap: ((String) -> Void)?
    var onCourseStart: ((CourseProposalData) -> Void)?
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            if !message.isFromUser {
                // Enhanced Lyo avatar with gradient
                PremiumLyoAvatar(size: 32)
            }
            
            VStack(alignment: message.isFromUser ? .trailing : .leading, spacing: DesignTokens.Spacing.xs) {
                // Message content with premium styling
                Text(message.content)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                    .lineSpacing(4)
                    .padding(.horizontal, DesignTokens.Spacing.md)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.sm)
                    .background(messageBackground)
                
                // Mentor Mode Content
                if let mode = message.responseMode {
                    switch mode {
                    case .explainer:
                        if let data = message.quickExplainer {
                            QuickExplainerView(data: data) { chip in
                                onQuickChipTap?(chip)
                            }
                        }
                    case .course:
                        if let data = message.courseProposal {
                            CourseProposalView(data: data) {
                                onCourseStart?(data)
                            }
                        }
                    case .chat:
                        EmptyView() // Handled by standard text view above
                    }
                }
                
                // Attachments
                if let attachments = message.attachments, !attachments.isEmpty {
                    ForEach(attachments) { attachment in
                        PremiumAttachmentView(attachment: attachment)
                    }
                }
                
                // Action pills (Lyo messages only)
                if !message.isFromUser, let actions = message.actions, !actions.isEmpty {
                    FlowLayout(spacing: DesignTokens.Spacing.xs) {
                        ForEach(actions) { action in
                            PremiumActionPillButton(action: action) {
                                HapticManager.shared.light()
                                onActionTap?(action)
                            }
                        }
                    }
                }
                
                // Timestamp and status
                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                    
                    if message.isFromUser, let status = message.status {
                        StatusIcon(status: status)
                    }
                }
            }
            
            if message.isFromUser {
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.xs)
    }
    
    @ViewBuilder
    private var messageBackground: some View {
        if message.isFromUser {
            // User message: gradient background
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .fill(DesignTokens.Colors.userMessageGradient)
                .applyMultiLayerShadow()
        } else {
            // AI message: glassmorphic effect
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .glassmorphic(borderColor: DesignTokens.Colors.accent)
                .applyShadow(DesignTokens.Shadow.md)
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Premium Lyo Avatar

struct PremiumLyoAvatar: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            // Gradient background
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "FCCC66"),
                            Color(hex: "ECA05B"),
                            Color(hex: "CC6F56")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // Glossy overlay
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
            
            // "L" letter
            Text("L")
                .font(.system(size: size * 0.5, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .shadow(color: .black.opacity(0.2), radius: 1, x: 0, y: 1)
        }
        .applyShadow(DesignTokens.Shadow.sm)
    }
}

// MARK: - Premium Attachment View

struct PremiumAttachmentView: View {
    let attachment: MessageAttachment
    
    var body: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            // Icon with gradient background
            ZStack {
                Circle()
                    .fill(DesignTokens.Colors.accentGradient)
                    .frame(width: 36, height: 36)
                
                Image(systemName: iconForType(attachment.type))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.filename ?? "File")
                    .font(DesignTokens.Typography.labelMedium)
                    .foregroundColor(DesignTokens.Colors.textPrimary)
                
                if let size = attachment.size {
                    Text(formatSize(size))
                        .font(DesignTokens.Typography.caption)
                        .foregroundColor(DesignTokens.Colors.textSecondary)
                }
            }
            
            Spacer()
        }
        .padding(DesignTokens.Spacing.sm)
        .glassmorphic(cornerRadius: DesignTokens.Radius.md)
        .frame(maxWidth: 260)
    }
    
    private func iconForType(_ type: MessageAttachment.AttachmentType) -> String {
        switch type {
        case .file: return "doc.fill"
        case .image: return "photo.fill"
        case .video: return "play.rectangle.fill"
        case .audio: return "waveform"
        case .link: return "link"
        }
    }
    
    private func formatSize(_ bytes: Int) -> String {
        let kb = Double(bytes) / 1024.0
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", kb / 1024.0)
    }
}

// MARK: - Premium Action Pill Button

struct PremiumActionPillButton: View {
    let action: MessageAction
    let onTap: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Button {
            withAnimation(DesignTokens.Animation.quick) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(DesignTokens.Animation.quick) {
                    isPressed = false
                }
                onTap()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: iconForAction(action.actionType))
                    .font(.system(size: 13, weight: .semibold))
                Text(action.label)
                    .font(DesignTokens.Typography.labelMedium)
            }
            .foregroundColor(DesignTokens.Colors.accent)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                ZStack {
                    Capsule()
                        .fill(DesignTokens.Colors.surface)
                    
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    DesignTokens.Colors.accent.opacity(0.5),
                                    DesignTokens.Colors.accentSecondary.opacity(0.3)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            lineWidth: 1.5
                        )
                }
            )
            .applyShadow(DesignTokens.Shadow.sm)
        }
        .scaleEffect(isPressed ? 0.96 : 1.0)
        .opacity(isPressed ? 0.85 : 1.0)
    }
    
    private func iconForAction(_ type: MessageAction.ActionType) -> String {
        switch type {
        case .createCourse: return "plus.circle.fill"
        case .quizMe: return "questionmark.circle.fill"
        case .addToLibrary: return "bookmark.fill"
        case .openDrawer: return "square.grid.2x2.fill"
        case .generateSyllabus: return "list.bullet.clipboard.fill"
        case .quickExplainer: return "lightbulb.fill"
        case .makeFlashcards: return "rectangle.stack.fill"
        case .extractKeyPoints: return "list.star"
        case .openClassroom: return "book.circle.fill"
        }
    }
}

// MARK: - Status Icon

struct StatusIcon: View {
    let status: LyoMessage.MessageStatus
    
    var body: some View {
        Image(systemName: iconName)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(color)
    }
    
    private var iconName: String {
        switch status {
        case .sending: return "clock.fill"
        case .sent: return "checkmark.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        }
    }
    
    private var color: Color {
        switch status {
        case .sending: return DesignTokens.Colors.textSecondary
        case .sent: return DesignTokens.Colors.accent
        case .failed: return DesignTokens.Colors.danger
        }
    }
}

// MARK: - Flow Layout for Action Pills

// FlowLayout moved to Sources/Components/Common/FlowLayout.swift

