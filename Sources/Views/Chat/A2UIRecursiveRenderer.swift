import SwiftUI

struct A2UIRecursiveRenderer: View {
    let component: DynamicComponent
    let onAction: ((String) -> Void)?

    var body: some View {
        switch component.payload {
        case .vstack(let data):
            VStack(alignment: mapVStackAlignment(data.alignment), spacing: data.spacing ?? 12) {
                ForEach(data.children) { child in
                    A2UIRecursiveRenderer(component: child, onAction: onAction)
                }
            }

        case .hstack(let data):
            HStack(alignment: mapHStackAlignment(data.alignment), spacing: data.spacing ?? 12) {
                ForEach(data.children) { child in
                    A2UIRecursiveRenderer(component: child, onAction: onAction)
                }
            }

        case .card(let data):
            VStack(alignment: .leading, spacing: 12) {
                if let title = data.title {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if let subtitle = data.subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(data.children) { child in
                    A2UIRecursiveRenderer(component: child, onAction: onAction)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(parseColor(data.backgroundColor) ?? Color.white.opacity(0.08))
            )

        case .text(let data):
            Text(data.content)
                .font(mapFont(data.fontStyle))
                .foregroundColor(parseColor(data.color) ?? .white)
                .multilineTextAlignment(mapTextAlignment(data.alignment))
                .frame(maxWidth: .infinity, alignment: mapFrameAlignment(data.alignment))

        case .button(let data):
            Button(action: { onAction?(data.actionId) }) {
                Text(data.label)
                    .font(.body)
                    .fontWeight(.medium)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity)
                    .background(buttonBackground(for: data.variant, disabled: data.isDisabled))
                    .foregroundColor(buttonForeground(for: data.variant, disabled: data.isDisabled))
                    .cornerRadius(8)
            }
            .disabled(data.isDisabled)
            .opacity(data.isDisabled ? 0.6 : 1.0)

        case .image(let data):
            AsyncImage(url: URL(string: data.url)) { image in
                image
                    .resizable()
                    .aspectRatio(parseAspectRatio(data.aspectRatio) ?? 1.0, contentMode: .fit)
            } placeholder: {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.white.opacity(0.7))
                            if let altText = data.altText {
                                Text(altText)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    )
            }
            .frame(maxHeight: 200)
            .cornerRadius(8)

        case .divider(let data):
            Divider()
                .overlay(parseColor(data.color) ?? Color.white.opacity(0.15))

        case .spacer(let data):
            Spacer()
                .frame(height: data.height ?? 16)

        case .quiz(let data):
            LegacyQuizRenderer(data: data, onAction: onAction)

        case .courseRoadmap(let data):
            LegacyCourseRoadmapRenderer(data: data, onAction: onAction)

        // AI Classroom Integration Components
        case .coursePreview(let data):
            CoursePreviewRenderer(data: data, onAction: onAction)

        case .learningNode(let data):
            LearningNodeRenderer(data: data, onAction: onAction)

        case .progressTracker(let data):
            ProgressTrackerRenderer(data: data, onAction: onAction)

        case .interactiveLesson(let data):
            InteractiveLessonRenderer(data: data, onAction: onAction)

        // Standard A2UI Components
        case .lessonCard(let data):
            LessonCardRenderer(data: data, onAction: onAction)
            
        case .courseCard(let data):
            LegacyCourseCardRenderer(data: data, onAction: onAction)
            
        case .grid(let data):
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: data.columns), spacing: data.spacing ?? 12) {
                ForEach(data.children) { child in
                    A2UIRecursiveRenderer(component: child, onAction: onAction)
                }
            }
            .padding(data.padding ?? 0)

        case .progressBar(let data):
            ProgressBarRenderer(data: data)

        case .placeholder(let data):
            VStack {
                Text("Unimplemented component: \\(component.type.rawValue)")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                if let children = data.children {
                    ForEach(children) { child in
                        A2UIRecursiveRenderer(component: child, onAction: onAction)
                    }
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(8)
        }
    }

    // MARK: - Helper Functions
    private func mapVStackAlignment(_ alignment: String) -> HorizontalAlignment {
        switch alignment.lowercased() {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func mapHStackAlignment(_ alignment: String) -> VerticalAlignment {
        switch alignment.lowercased() {
        case "top": return .top
        case "bottom": return .bottom
        default: return .center
        }
    }

    private func mapFont(_ style: String) -> Font {
        switch style.lowercased() {
        case "title": return .title
        case "headline": return .headline
        case "caption": return .caption
        case "code": return .system(.body, design: .monospaced)
        default: return .body
        }
    }

    private func mapTextAlignment(_ alignment: String) -> TextAlignment {
        switch alignment.lowercased() {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func mapFrameAlignment(_ alignment: String) -> Alignment {
        switch alignment.lowercased() {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func parseColor(_ colorString: String?) -> Color? {
        guard let colorString = colorString else { return nil }

        // Handle hex colors
        if colorString.hasPrefix("#") {
            return Color(hex: colorString)
        }

        // Handle named colors
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "yellow": return .yellow
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "primary": return .primary
        case "secondary": return .secondary
        default: return Color(hex: colorString)
        }
    }

    private func parseAspectRatio(_ ratioString: String?) -> CGFloat? {
        guard let ratioString = ratioString else { return nil }
        let components = ratioString.split(separator: ":")
        guard components.count == 2,
              let width = Double(components[0]),
              let height = Double(components[1]),
              height > 0 else { return nil }
        return CGFloat(width / height)
    }

    private func buttonBackground(for variant: String, disabled: Bool) -> Color {
        if disabled {
            return Color.gray.opacity(0.3)
        }

        switch variant.lowercased() {
        case "primary": return .blue
        case "secondary": return .gray
        case "destructive": return .red
        case "ghost": return .clear
        default: return .gray
        }
    }

    private func buttonForeground(for variant: String, disabled: Bool) -> Color {
        if disabled {
            return .gray
        }

        switch variant.lowercased() {
        case "primary": return .white
        case "secondary": return .white
        case "destructive": return .white
        case "ghost": return .blue
        default: return .white
        }
    }
}

// MARK: - Legacy Component Renderers
struct LegacyQuizRenderer: View {
    let data: RecursiveQuizPayload
    let onAction: ((String) -> Void)?

    @State private var selectedAnswer: Int? = nil
    @State private var showExplanation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Question
            Text(data.question)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .multilineTextAlignment(.leading)

            // Options
            VStack(spacing: 12) {
                ForEach(Array(data.options.enumerated()), id: \.offset) { index, option in
                    Button(action: {
                        selectedAnswer = index
                        showExplanation = true
                        onAction?("quiz_answer_\(index)")
                    }) {
                        HStack {
                            Text(option)
                                .font(.body)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.leading)
                            Spacer()

                            if selectedAnswer == index {
                                Image(systemName: isCorrectAnswer(index) ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(isCorrectAnswer(index) ? .green : .red)
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(backgroundColorForOption(index))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(borderColorForOption(index), lineWidth: 1)
                        )
                    }
                    .disabled(selectedAnswer != nil)
                }
            }

            // Explanation
            if showExplanation, let explanation = data.explanation, !explanation.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Explanation")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.7))

                    Text(explanation)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                }
                .padding()
                .background(Color.white.opacity(0.06))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func isCorrectAnswer(_ index: Int) -> Bool {
        return data.correctIndex == index
    }

    private func backgroundColorForOption(_ index: Int) -> Color {
        guard let selected = selectedAnswer else {
            return Color.white.opacity(0.06)
        }

        if selected == index {
            return isCorrectAnswer(index) ? Color.green.opacity(0.1) : Color.red.opacity(0.1)
        }

        return Color.white.opacity(0.06)
    }

    private func borderColorForOption(_ index: Int) -> Color {
        guard let selected = selectedAnswer else {
            return Color.white.opacity(0.15)
        }

        if selected == index {
            return isCorrectAnswer(index) ? .green : .red
        }

        return Color.white.opacity(0.15)
    }
}

struct LegacyCourseRoadmapRenderer: View {
    let data: CourseRoadmapPayload
    let onAction: ((String) -> Void)?

    @State private var expandedModules: Set<String> = []

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text(data.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                HStack {
                    Text("\(data.completedModules) of \(data.totalModules) modules completed")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))

                    Spacer()

                    // Progress indicator
                    let progress = data.totalModules > 0 ? Double(data.completedModules) / Double(data.totalModules) : 0
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(progress >= 0.7 ? .green : .orange)
                }
            }

            // Progress bar
            ProgressView(value: data.totalModules > 0 ? Double(data.completedModules) / Double(data.totalModules) : 0)
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))

            Divider()

            // Modules
            VStack(spacing: 12) {
                ForEach(Array(data.modules.enumerated()), id: \.element.id) { index, module in
                    ModuleRowView(
                        module: module,
                        index: index,
                        isCompleted: index < data.completedModules,
                        isExpanded: expandedModules.contains(module.id),
                        onToggleExpansion: {
                            if expandedModules.contains(module.id) {
                                expandedModules.remove(module.id)
                            } else {
                                expandedModules.insert(module.id)
                            }
                        },
                        onAction: onAction
                    )
                }
            }
            
            // Start Learning Button
            Button(action: {
                onAction?("OPEN_CLASSROOM")
            }) {
                HStack {
                    Text("Start Learning")
                        .fontWeight(.bold)
                    Image(systemName: "arrow.right.circle.fill")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top, 10)
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct ModuleRowView: View {
    let module: CourseModule
    let index: Int
    let isCompleted: Bool
    let isExpanded: Bool
    let onToggleExpansion: () -> Void
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Module header
            HStack {
                // Status indicator
                Circle()
                    .fill(isCompleted ? Color.green : Color.gray.opacity(0.5))
                    .frame(width: 12, height: 12)

                VStack(alignment: .leading, spacing: 4) {
                    Text(module.title)
                        .font(.headline)
                        .foregroundColor(.white)

                    if let description = module.description {
                        Text(description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .lineLimit(isExpanded ? nil : 2)
                    }

                    HStack {
                        if let lessons = module.lessons {
                            Text("\(lessons.count) lessons")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        if let duration = module.duration {
                            Text("• \(duration) min")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                Spacer()

                // Expand/collapse button
                Button(action: onToggleExpansion) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Expanded content
            if isExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    if let lessons = module.lessons, !lessons.isEmpty {
                        Text("Lessons")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)

                        ForEach(lessons) { lesson in
                            HStack {
                                Text("•")
                                    .foregroundColor(.white.opacity(0.7))

                                Text(lesson.title)
                                    .font(.body)
                                    .foregroundColor(.white)

                                Spacer()

                                if let duration = lesson.duration {
                                    Text(duration)
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                    }

                    // Action buttons
                    HStack(spacing: 12) {
                        Button(action: {
                            onAction?("start_module_\(module.id)")
                        }) {
                            Text(isCompleted ? "Review" : "Start")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(isCompleted ? Color.blue : Color.green)
                                .cornerRadius(6)
                        }

                        if isCompleted {
                            Button(action: {
                                onAction?("certificate_\(module.id)")
                            }) {
                                Text("Certificate")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(6)
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.06))
        .cornerRadius(8)
    }
}

// MARK: - AI Classroom Integration Renderers
struct CoursePreviewRenderer: View {
    let data: CoursePreviewPayload
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Course Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(data.subject)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text(data.gradeBand)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)

                    Text("\(data.estimatedMinutes) min")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Course Description
            Text(data.description)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(3)

            // Course Stats
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "book")
                        .font(.caption)
                    Text("\(data.totalNodes) lessons")
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                    Text("\(data.estimatedMinutes) minutes")
                        .font(.caption)
                }

                Spacer()
            }
            .foregroundColor(.white.opacity(0.7))

            Divider()

            // Action Buttons
            HStack(spacing: 12) {
                Button(action: { onAction?(data.previewActionId) }) {
                    Text("Preview")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                }

                Button(action: { onAction?(data.startActionId) }) {
                    Text("Start Course")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct LearningNodeRenderer: View {
    let data: LearningNodePayload
    let onAction: ((String) -> Void)?

    private var statusColor: Color {
        if data.isCompleted ?? false { return .green }
        if data.isCurrent ?? false { return .blue }
        return Color.gray.opacity(0.3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerSection
            
            contentSection

            footerSection
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private var headerSection: some View {
        HStack {
            Circle()
                .fill(statusColor)
                .frame(width: 12, height: 12)

            Text(data.title ?? "Lesson Node")
                .font(.headline)
                .fontWeight((data.isCurrent ?? false) ? .semibold : .medium)
                .foregroundColor((data.isCurrent ?? false) ? .primary : .secondary)

            Spacer()

            if let estimatedMinutes = data.estimatedMinutes {
                Text("\(estimatedMinutes) min")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
        }
    }

    private var contentSection: some View {
        Text(data.content ?? "")
            .font(.subheadline)
            .foregroundColor(.white.opacity(0.7))
            .lineLimit((data.isCurrent ?? false) ? nil : 2)
    }

    private var footerSection: some View {
        HStack {
            Text(data.type?.capitalized ?? "Lesson")
                .font(.caption)
        }
        .padding()
        .background((data.isCurrent ?? false) ? Color.blue.opacity(0.05) : Color.clear)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke((data.isCurrent ?? false) ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private func nodeTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "narrative": return .purple
        case "interaction": return .blue
        case "quiz": return .orange
        case "summary": return .green
        default: return .gray
        }
    }
}

struct ProgressTrackerRenderer: View {
    let data: ProgressTrackerPayload
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(data.courseTitle ?? "Course")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            // Progress Bar
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Progress")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Text("\(Int(data.completedPercentage))%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 8)
                            .cornerRadius(4)

                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: geometry.size.width * (data.completedPercentage / 100.0), height: 8)
                            .cornerRadius(4)
                    }
                }
                .frame(height: 8)
            }

            // Current Status
            VStack(alignment: .leading, spacing: 8) {
                if let currentNodeTitle = data.currentNodeTitle {
                    HStack {
                        Text("Current:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(currentNodeTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                if let nextNodeTitle = data.nextNodeTitle {
                    HStack {
                        Text("Next:")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                        Text(nextNodeTitle)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }

                Text("\(data.currentNode) of \(data.totalNodes) lessons completed")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }

            // Continue Button
            Button(action: { onAction?(data.continueActionId) }) {
                Text("Continue Learning")
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }
}

struct InteractiveLessonRenderer: View {
    let data: InteractiveLessonPayload
    let onAction: ((String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Lesson Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    Text(data.lessonType.capitalized)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(lessonTypeColor(data.lessonType).opacity(0.1))
                        .foregroundColor(lessonTypeColor(data.lessonType))
                        .cornerRadius(6)
                }

                Spacer()

                if let durationSeconds = data.durationSeconds {
                    VStack {
                        Image(systemName: "play.circle")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text("\(durationSeconds / 60):\(String(format: "%02d", durationSeconds % 60))")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }

            // Lesson Content
            Text(data.content)
                .font(.body)
                .foregroundColor(.white)
                .lineLimit(nil)

            // Media Preview (if available)
            if data.mediaUrl != nil {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(height: 120)
                    .cornerRadius(8)
                    .overlay(
                        VStack {
                            Image(systemName: mediaIconName(data.lessonType))
                                .font(.title)
                                .foregroundColor(.gray)
                            Text("Media Content")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    )
            }

            // Action Buttons
            HStack(spacing: 12) {
                if data.hasQuiz {
                    Button(action: { onAction?(data.quizActionId) }) {
                        HStack {
                            Image(systemName: "questionmark.circle")
                            Text("Take Quiz")
                        }
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                }

                Button(action: { onAction?(data.continueActionId) }) {
                    Text(data.hasQuiz ? "Continue" : "Complete Lesson")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(12)
    }

    private func lessonTypeColor(_ type: String) -> Color {
        switch type.lowercased() {
        case "video": return .red
        case "audio": return .purple
        case "interactive": return .blue
        case "text": return .green
        default: return .gray
        }
    }

    private func mediaIconName(_ type: String) -> String {
        switch type.lowercased() {
        case "video": return "play.rectangle"
        case "audio": return "waveform"
        case "interactive": return "hand.tap"
        default: return "doc.text"
        }
    }
}

// MARK: - Standard A2UI Renderers

struct LessonCardRenderer: View {
    let data: LessonCardPayload
    let onAction: ((String) -> Void)?
    
    var body: some View {
        Button(action: { onAction?(data.action) }) {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: iconForType(data.type))
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 48, height: 48)
                    .background(data.completed ? Color.green : Color.blue)
                    .cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(data.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(data.description ?? "")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                    
                    HStack {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(data.duration ?? "")
                            .font(.caption2)
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if data.completed {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Image(systemName: "play.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
    
    private func iconForType(_ type: String) -> String {
        switch type.lowercased() {
        case "video": return "play.rectangle.fill"
        case "reading": return "book.fill"
        case "quiz": return "questionmark.circle.fill"
        default: return "doc.text.fill"
        }
    }
}

struct LegacyCourseCardRenderer: View {
    let data: A2UICourseCardPayload
    let onAction: ((String) -> Void)?
    
    var body: some View {
        Button(action: { onAction?(data.action) }) {
            VStack(alignment: .leading, spacing: 12) {
                // Image or Placeholder
                if let imageUrl = data.imageUrl, let url = URL(string: imageUrl) {
                    AsyncImage(url: url) { image in
                        image.resizable()
                             .aspectRatio(contentMode: .fill)
                             .frame(height: 140)
                             .clipped()
                    } placeholder: {
                        Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 140)
                    }
                    .cornerRadius(8)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(data.title)
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(data.description)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                    
                    // Stats row
                    HStack {
                        Label(data.difficulty, systemImage: "chart.bar")
                        Spacer()
                        Label(data.duration, systemImage: "clock")
                    }
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    
                    // Progress
                    if data.progress > 0 {
                        VStack(spacing: 4) {
                            ProgressView(value: data.progress, total: 100)
                            Text("\(Int(data.progress))% Complete")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                }
            }
            .padding()
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}

struct ProgressBarRenderer: View {
    let data: ProgressBarPayload
    
    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 8)
                        .cornerRadius(4)
                    
                    Rectangle()
                        .fill(parseColor(data.color) ?? Color.blue)
                        .frame(width: geometry.size.width * (CGFloat(data.progress) / 100.0), height: 8)
                        .cornerRadius(4)
                }
            }
            .frame(height: 8)
        }
        .padding(.vertical, 4)
    }
    
    private func parseColor(_ colorString: String?) -> Color? {
        guard let colorString = colorString else { return nil }
        // Simple hex parser reuse or just return basic color
        if colorString.hasPrefix("#") { return Color(hex: colorString) }
        return .blue
    }
}