//
//  A2UIHomeworkViews.swift
//  Lyo
//
//  Homework Helper renderer views for A2UI
//

import SwiftUI

// MARK: - Homework Views

struct A2UIHomeworkCardView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with status
            HStack {
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
                
                VStack(alignment: .leading) {
                    Text(props.title ?? "Assignment")
                        .font(.headline)
                    if let subject = props.subject {
                        Text(subject)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if let dueDate = props.dueDate {
                    VStack(alignment: .trailing) {
                        Text("Due")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(formattedDate(dueDate))
                            .font(.caption.bold())
                            .foregroundColor(isOverdue ? .red : .primary)
                    }
                }
            }
            
            Divider()
            
            // Description
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
            
            // Attachments
            if let attachments = props.attachments, !attachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(attachments, id: \.id) { attachment in
                            AttachmentChip(attachment: attachment)
                        }
                    }
                }
            }
            
            // Actions
            HStack {
                Button("Start Working") {
                    // Handle start
                }
                .buttonStyle(.borderedProminent)
                
                Spacer()
                
                Button(action: {}) {
                    Image(systemName: "ellipsis.circle")
                }
                .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
    
    private var statusIcon: String {
        switch props.status {
        case "completed": return "checkmark.circle.fill"
        case "in_progress": return "clock.fill"
        case "overdue": return "exclamationmark.circle.fill"
        default: return "circle"
        }
    }
    
    private var statusColor: Color {
        switch props.status {
        case "completed": return .green
        case "in_progress": return .blue
        case "overdue": return .red
        default: return .gray
        }
    }
    
    private var isOverdue: Bool {
        props.status == "overdue"
    }
}

struct A2UIGradeDisplayView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            // Grade circle
            ZStack {
                Circle()
                    .stroke(gradeColor.opacity(0.3), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: gradeProgress)
                    .stroke(gradeColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                
                VStack {
                    Text(props.grade ?? "A")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(gradeColor)
                    if let score = scoreValue {
                        Text("\(Int(score))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .frame(width: 120, height: 120)
            
            // Title
            Text(props.title ?? "Assignment Grade")
                .font(.headline)
            
            // Feedback
            if let feedback = props.feedback {
                Text(feedback)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            // Rubric breakdown
            if let rubric = props.rubric, !rubric.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Breakdown")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)
                    
                    ForEach(rubric, id: \.id) { item in
                        let earned = item.earnedPoints ?? 0
                        HStack {
                            Text(item.criterion)
                            Spacer()
                            Text("\(earned)/\(item.maxPoints)")
                                .foregroundColor(earned >= item.maxPoints / 2 ? .green : .orange)
                        }
                        .font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            }
        }
        .padding()
    }
    
    private var gradeColor: Color {
        guard let score = scoreValue else { return .blue }
        if score >= 90 { return .green }
        if score >= 70 { return .blue }
        if score >= 50 { return .orange }
        return .red
    }
    
    private var gradeProgress: Double {
        (scoreValue ?? 0) / 100
    }

    private var scoreValue: Double? {
        if let score = props.points { return Double(score) }
        if let grade = props.grade, let numeric = Double(grade) { return numeric }
        return nil
    }
}

struct A2UIRubricView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Grading Rubric")
                .font(.headline)
            
            if let rubric = props.rubric {
                ForEach(rubric, id: \.id) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.criterion)
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(item.maxPoints) pts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let feedback = item.feedback {
                            Text(feedback)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        // Score slider (for grading)
                        if props.isEditable == true {
                            Slider(value: .constant(Double(item.earnedPoints ?? 0)), in: 0...Double(item.maxPoints))
                                .tint(.blue)
                        } else {
                            ProgressView(value: Double(item.earnedPoints ?? 0), total: Double(item.maxPoints))
                                .tint(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
    }
}

struct A2UISubmissionStatusView: View {
    let props: A2UIProps
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(spacing: 16) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                Image(systemName: statusIcon)
                    .font(.system(size: 36))
                    .foregroundColor(statusColor)
            }
            
            Text(statusText)
                .font(.headline)
            
            if let body = props.body {
                Text(body)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let submittedAt = props.submittedDate {
                Text("Submitted: \(formattedDate(submittedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(statusColor.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var statusColor: Color {
        switch props.status {
        case "submitted": return .green
        case "pending": return .orange
        case "late": return .red
        case "graded": return .blue
        default: return .gray
        }
    }
    
    private var statusIcon: String {
        switch props.status {
        case "submitted": return "checkmark.circle.fill"
        case "pending": return "clock.fill"
        case "late": return "exclamationmark.triangle.fill"
        case "graded": return "star.fill"
        default: return "doc.fill"
        }
    }
    
    private var statusText: String {
        switch props.status {
        case "submitted": return "Submitted Successfully!"
        case "pending": return "Pending Submission"
        case "late": return "Late Submission"
        case "graded": return "Graded"
        default: return "Not Submitted"
        }
    }
}

struct A2UIHomeworkListView: View {
    let props: A2UIProps
    let children: [A2UIComponent]
    let onAction: ((A2UIAction, A2UIComponent) -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(props.title ?? "Homework")
                    .font(.headline)
                Spacer()
                if let count = props.totalCount {
                    Text("\(count) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            ForEach(children, id: \.id) { child in
                A2UIRenderer(component: child, onAction: onAction)
            }
        }
        .padding()
    }
}

struct A2UIHomeworkGenericView: View {
    let props: A2UIProps
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .foregroundColor(.blue)
                Text(props.title ?? "Homework")
                    .font(.headline)
            }
            
            if let body = props.body {
                Text(body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .none
    return formatter.string(from: date)
}

// MARK: - Supporting Views

private struct AttachmentChip: View {
    let attachment: A2UIAttachment
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: iconName)
            Text(attachment.name)
                .lineLimit(1)
        }
        .font(.caption)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }
    
    private var iconName: String {
        switch attachment.type {
        case "pdf": return "doc.fill"
        case "image": return "photo.fill"
        case "video": return "play.rectangle.fill"
        default: return "paperclip"
        }
    }
}
