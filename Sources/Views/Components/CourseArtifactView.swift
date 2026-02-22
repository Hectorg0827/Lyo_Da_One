//
//  CourseArtifactView.swift
//  Lyo
//
//  A rich, purpose-built view for rendering a course A2UI artifact inside
//  the Artifact Pane. Used instead of the generic A2UIRenderer when the
//  top-level component type is .courseCard / .courseRoadmap / .courseHeader.
//

import SwiftUI

// MARK: - CourseArtifactView

struct CourseArtifactView: View {
    let component: A2UIComponent
    let onAction: ((A2UIAction) -> Void)?

    // Convenience accessors
    private var props: A2UIProps { component.props }
    private var lessonChildren: [A2UIComponent] {
        (component.children ?? []).filter { $0.type == .lessonBlock }
    }
    private var moduleChildren: [A2UIComponent] {
        (component.children ?? []).filter {
            [A2UIElementType.moduleHeader, .chapterNav, .lessonList, .courseOutline].contains($0.type)
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                heroBanner
                    .padding(.bottom, 16)

                metaRow
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)

                if let objectives = props.objectives, !objectives.isEmpty {
                    objectivesSection(objectives)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }

                if !lessonChildren.isEmpty {
                    lessonSection
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                } else if let modules = props.modules, !modules.isEmpty {
                    modulesSection(modules)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                } else if !moduleChildren.isEmpty {
                    // Render child module/outline components via main renderer
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(moduleChildren, id: \.id) { child in
                            A2UIRenderer(component: child, onAction: { action, _ in
                                onAction?(action)
                            })
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }

                startLearningButton
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Hero Banner

    private var heroBanner: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 140)

            VStack(alignment: .leading, spacing: 4) {
                Text(props.title ?? props.courseName ?? "Course")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                    .lineLimit(2)
                if let subtitle = props.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(16)

            // faded icon overlay
            Image(systemName: "book.pages.fill")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.08))
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.trailing, 16)
        }
        .cornerRadius(16)
        .padding(.horizontal, 16)
    }

    // MARK: - Meta Row (level + duration)

    private var metaRow: some View {
        HStack(spacing: 8) {
            if let level = props.level, !level.isEmpty {
                Label(level.capitalized, systemImage: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(levelColor(level))
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(levelColor(level).opacity(0.12))
                    .cornerRadius(8)
            }
            if let mins = props.estimatedDuration, mins > 0 {
                Label("\(mins) min", systemImage: "clock")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.secondary)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            if let pct = props.completionPercentage ?? props.progressPercent, pct > 0 {
                Label("\(Int(pct))% done", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(.green)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
            Spacer()
        }
    }

    // MARK: - Objectives

    private func objectivesSection(_ objectives: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("What you'll learn")
                .font(.subheadline.bold())
            ForEach(objectives.prefix(4), id: \.self) { obj in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .padding(.top, 2)
                    Text(obj)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Lesson List (from children)

    private var lessonSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lessons")
                .font(.subheadline.bold())
            ForEach(lessonChildren.prefix(8), id: \.id) { lesson in
                lessonRow(lesson)
            }
            if lessonChildren.count > 8 {
                Text("+\(lessonChildren.count - 8) more lessons")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 4)
            }
        }
    }

    private func lessonRow(_ lesson: A2UIComponent) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(lesson.props.isCompleted == true ? Color.green : Color(.systemGray5))
                    .frame(width: 28, height: 28)
                if lesson.props.isCompleted == true {
                    Image(systemName: "checkmark").font(.caption2.bold()).foregroundColor(.white)
                } else if let n = lesson.props.lessonNumber {
                    Text("\(n)").font(.caption.bold()).foregroundColor(.primary)
                } else {
                    Image(systemName: "play.fill").font(.caption2).foregroundColor(.secondary)
                }
            }
            Text(lesson.props.title ?? "Lesson")
                .font(.subheadline)
                .lineLimit(1)
            Spacer()
            if let dur = lesson.props.estimatedDuration ?? lesson.props.duration {
                Text("\(dur)m")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Image(systemName: lesson.props.isLocked == true ? "lock.fill" : "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .opacity(lesson.props.isLocked == true ? 0.6 : 1)
    }

    // MARK: - Modules (from props.modules)

    private func modulesSection(_ modules: [A2UIModuleInfo]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Modules")
                .font(.subheadline.bold())
            ForEach(modules.prefix(6)) { module in
                HStack(spacing: 10) {
                    Image(systemName: module.isLocked ? "lock.fill" : "folder.fill")
                        .foregroundColor(module.isLocked ? .secondary : .blue)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(module.title)
                            .font(.subheadline)
                            .lineLimit(1)
                        Text("\(module.lessonCount) lessons")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    if let dur = module.duration, dur > 0 {
                        Text("\(dur)m")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .opacity(module.isLocked ? 0.6 : 1)
            }
        }
    }

    // MARK: - CTA Button

    private var startLearningButton: some View {
        Button {
            let action = A2UIAction(
                id: props.courseId ?? "start_course",
                trigger: .tap,
                type: .startStudy,
                payload: [
                    "course_id": .string(props.courseId ?? ""),
                    "title": .string(props.title ?? props.courseName ?? "Course"),
                    "message": .string("Start the course: \(props.title ?? props.courseName ?? "this course")")
                ]
            )
            onAction?(action)
        } label: {
            HStack {
                Image(systemName: "play.fill")
                Text("Start Learning")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                LinearGradient(colors: gradientColors, startPoint: .leading, endPoint: .trailing)
            )
            .foregroundColor(.white)
            .cornerRadius(14)
        }
    }

    // MARK: - Helpers

    private var gradientColors: [Color] {
        switch props.level?.lowercased() {
        case "beginner", "easy":       return [.teal, .blue]
        case "intermediate", "medium": return [.blue, .purple]
        case "advanced", "hard":       return [.purple, .pink]
        default:                       return [.blue, .indigo]
        }
    }

    private func levelColor(_ level: String) -> Color {
        switch level.lowercased() {
        case "beginner", "easy":       return .teal
        case "intermediate", "medium": return .blue
        case "advanced", "hard":       return .purple
        default:                       return .blue
        }
    }
}

// MARK: - Component Type Check Helper

extension A2UIElementType {
    /// Returns true when this type represents a top-level course artifact
    var isCourseArtifact: Bool {
        switch self {
        case .courseCard, .courseRoadmap, .courseHeader, .courseOutline: return true
        default: return false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct CourseArtifactView_Previews: PreviewProvider {
    static var previews: some View {
        var props = A2UIProps()
        props.title = "iOS Development Mastery"
        props.subtitle = "Build real apps from scratch"
        props.level = "intermediate"
        props.estimatedDuration = 480
        props.objectives = ["SwiftUI fundamentals", "Networking with URLSession", "Combine & async/await"]
        let component = A2UIComponent(
            id: "preview-course",
            type: .courseCard,
            props: props
        )
        return CourseArtifactView(component: component, onAction: nil)
            .previewLayout(.sizeThatFits)
    }
}
#endif
