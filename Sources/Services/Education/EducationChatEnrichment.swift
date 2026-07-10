import Foundation

/// Lightweight action payload produced by enrichment (mapped to `LioChatService.ChatAction` in the VM).
struct EnrichedAssistantAction: Equatable {
    let type: String
    let parameters: [String: String]?
}

/// Parses fenced ```json payloads and numbered Markdown rails from `/api/v1/ai/chat`
/// replies into native `MessageContentType` payloads (education‑first UX in Focus chat).
enum EducationChatEnrichment {
    struct Result {
        let displayText: String
        let action: EnrichedAssistantAction?
        let contentTypes: [MessageContentType]
        let responseMode: ResponseMode?
        let quickExplainer: QuickExplainerData?
    }

    static func enrich(rawAssistantText: String) -> Result {
        let raw = rawAssistantText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let oc = openClassroomBranch(from: raw) {
            return oc
        }

        var widgets: [MessageContentType] = []
        var prose = stripFencedJSON(from: raw, widgets: &widgets)

        appendNumberedRoadmap(from: prose, widgets: &widgets)
        widgets = uniquesPreserveOrder(widgets)

        prose = prose
            .replacingOccurrences(of: "```json", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "```", with: "")
            .replacingOccurrences(of: #"[\t\n\r ]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if hasStructured(widgets), prose.count < 860 {
            if prose.contains("\"question\"")
                || prose.contains("\"type\"")
                || prose.contains("\"modules\"")
                || prose.firstIndex(of: "{") != nil {
                prose = ""
            }
        }

        if prose.isEmpty, !widgets.isEmpty {
            prose = "Here's something tailored to your studies 👇"
        }

        let explainerPayload = widgets.isEmpty ? synthesizeExplainer(from: prose) : nil

        return Result(
            displayText: prose.isEmpty ? raw : prose,
            action: nil,
            contentTypes: widgets,
            responseMode: explainerPayload != nil ? .explainer : nil,
            quickExplainer: explainerPayload
        )
    }

    // MARK: OPEN_CLASSROOM

    private static func openClassroomBranch(from raw: String) -> Result? {
        guard raw.contains("OPEN_CLASSROOM") else { return nil }
        guard case let .command(cmd) = AICommandParser.parse(raw),
              cmd.type == .openClassroom,
              let course = cmd.payload?.course else {
            return nil
        }

        let bullets = Array(course.objectives.prefix(6))
        var body = "I can put together a **\(course.title)** course for you 🎓"
        body += "\n• **Level**: \(course.level.capitalized)"
        if let duration = course.duration?.trimmingCharacters(in: .whitespacesAndNewlines), !duration.isEmpty {
            body += "\n• **Duration**: \(duration)"
        }
        if !bullets.isEmpty {
            body += "\n\nYou'll learn:"
            bullets.forEach { body += "\n• \($0)" }
        }
        body += "\n\nTap **Generate Course** below and I'll start building it."

        var params: [String: String] = [
            "topic": course.topic,
            "level": course.level,
            "title": course.title,
            "auto_generate": "true"
        ]
        if !bullets.isEmpty { params["objectives"] = bullets.joined(separator: "\n") }

        return Result(
            displayText: body,
            action: EnrichedAssistantAction(type: "generate_course", parameters: params),
            contentTypes: [.courseProposal(payload: course)],
            responseMode: nil,
            quickExplainer: nil)
    }

    // MARK: Fenced ```json blobs

    private static func stripFencedJSON(from source: String, widgets: inout [MessageContentType]) -> String {
        let finder =
            try! NSRegularExpression(
                pattern: "```(?:json)?\\s*(\\{[\\s\\S]*?\\})\\s*```",
                options: [.caseInsensitive])
        let buffer = NSMutableString(string: source)
        let snapshots =
            finder
                .matches(
                    in: source,
                    range: NSRange(location: 0, length: (source as NSString).length))
                .reversed()

        for snapshot in snapshots where snapshot.numberOfRanges > 1 {
            let jsonChunk =
                NSString(string: source).substring(with: snapshot.range(at: 1))
            if let data = jsonChunk.data(using: .utf8) {
                ingestJSONBlob(data: data, widgets: &widgets)
            }
            buffer.replaceCharacters(in: snapshot.range, with: "")
        }

        return String(buffer).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func ingestJSONBlob(data: Data, widgets: inout [MessageContentType]) {
        if let roadmap = decodeRoadmap(data) {
            widgets.append(roadmap); return }
        if let plan = decodeStudyPlan(data) {
            widgets.append(.studyPlan(plan: plan)); return }
        if let quiz = decodeQuiz(data) {
            widgets.append(quiz); return }
        if let deck = decodeFlashcards(data) {
            widgets.append(deck)
        }
    }

    // MARK: Numbered syllabus lines

    private static func appendNumberedRoadmap(from prose: String, widgets: inout [MessageContentType]) {
        if widgets.contains(where: { if case .courseRoadmap = $0 { return true }; return false }) {
            return
        }

        let rows =
            prose
                .replacingOccurrences(of: "\r", with: "")
                .split(separator: "\n")
                .compactMap(Self.numberedLesson)

        guard rows.count >= 3 else { return }

        widgets.append(
            .courseRoadmap(
                title: "Lesson outline",
                modules: rows,
                totalModules: rows.count,
                completedModules: 0))
    }

    private static func numberedLesson(_ rawSubstring: Substring) -> CourseModule? {
        let line = rawSubstring.trimmingCharacters(in: .whitespaces)
        guard line.range(of: #"^\d+\.\s+.+"#, options: .regularExpression) != nil else {
            return nil }
        let title =
            line
                .replacingOccurrences(of: #"^\d+\.\s*"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        guard title.count >= 6 else { return nil }
        return CourseModule(title: title)
    }

    // MARK: Decoders

    private static func decodeQuiz(_ data: Data) -> MessageContentType? {
        guard let root = loadJSON(data) else { return nil }
        let envelope = unwrapPayload(root)

        guard let stem = extractString(envelope["question"]).nonEmpty ??
                extractString(envelope["prompt"]).nonEmpty else { return nil }
        guard let options = quizSelections(from: envelope) else {
            return nil }

        let index =
            coerceInt(envelope["correctIndex"])
                ?? coerceInt(envelope["correct_index"])
                ?? coerceInt(envelope["answer_index"])
                ?? coerceInt(envelope["answer"])
                ?? coerceInt(envelope["answerIndex"])
                ?? 0

        guard index >= 0, index < options.count else { return nil }

        let rationale =
            extractString(envelope["explanation"]).nonEmpty ??
            extractString(envelope["feedback"]).nonEmpty ??
            extractString(envelope["rationale"]).nonEmpty

        return .quiz(question: stem, options: options, correctIndex: index, explanation: rationale)
    }

    private static func quizSelections(from envelope: [String: Any]) -> [String]? {
        if let direct = envelope["options"] as? [String],
           direct.count >= 2 { return direct }

        guard let blobs = envelope["choices"] as? [[String: Any]] else {
            return nil }

        let labels =
            blobs
                .compactMap { extractString($0["text"]).nonEmpty ?? extractString($0["label"]).nonEmpty }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

        return labels.count >= 2 ? labels : nil
    }

    private static func decodeFlashcards(_ data: Data) -> MessageContentType? {
        guard let root = loadJSON(data) else { return nil }
        let env = unwrapPayload(root)

        guard let decks = env["cards"] as? [[String: Any]]
                ?? root["cards"] as? [[String: Any]]
        else { return nil }

        let cards =
            decks.compactMap(Self.decodeFlashCard)
        guard cards.count >= 2 else {
            return nil }

        let label =
            extractString(root["title"]).nonEmpty ??
            extractString(env["title"]).nonEmpty ??
            extractString(root["topic"]).nonEmpty ??
            extractString(env["topic"]).nonEmpty ??
            "Study deck"

        return .flashcards(title: label, cards: cards)
    }

    private static func decodeFlashCard(_ row: [String: Any]) -> Flashcard? {
        guard let frontHead =
                extractString(row["front"]).nonEmpty
                ?? extractString(row["term"]).nonEmpty
                ?? extractString(row["prompt"]).nonEmpty,
              let flipped =
                extractString(row["back"]).nonEmpty
                ?? extractString(row["definition"]).nonEmpty
                ?? extractString(row["answer"]).nonEmpty
        else { return nil }

        let flagged =
            coerceBool(row["mastered"])
                ?? coerceBool(row["isMastered"])
                ?? coerceBool(row["completed"]) ?? false

        return Flashcard(front: frontHead, back: flipped, isMastered: flagged)
    }

    private static func decodeRoadmap(_ data: Data) -> MessageContentType? {
        guard let root = loadJSON(data) else { return nil }

        let env = unwrapPayload(root)
        guard let rows = env["modules"] as? [[String: Any]]
                ?? root["modules"] as? [[String: Any]],
              !rows.isEmpty else {
            return nil }

        let label =
            extractString(env["title"]).nonEmpty ??
            extractString(env["heading"]).nonEmpty ??
            extractString(root["title"]).nonEmpty ??
            extractString(root["heading"]).nonEmpty ??
            "Roadmap"

        let roadmapRows = rows.map(Self.moduleSkeleton)

        let done = roadmapRows.filter { $0.isCompleted }.count

        return .courseRoadmap(
            title: label,
            modules: roadmapRows,
            totalModules: roadmapRows.count,
            completedModules: done)
    }

    private static func moduleSkeleton(from row: [String: Any]) -> CourseModule {
        let headline =
            extractString(row["title"]).nonEmpty
                ?? extractString(row["module_title"]).nonEmpty
                ?? extractString(row["name"]).nonEmpty
                ?? extractString(row["heading"]).nonEmpty
                ?? "Lesson"

        let minutes =
            coerceInt(row["duration_minutes"]) ??
            coerceInt(row["estimated_minutes"])

        let detail =
            extractString(row["overview"]).nonEmpty ??
            extractString(row["description"]).nonEmpty ??
            extractString(row["summary"]).nonEmpty

        let completed =
            coerceBool(row["completed"]) ?? coerceBool(row["done"]) ?? false

        let locked =
            coerceBool(row["locked"]) ?? coerceBool(row["disabled"]) ?? false

        let nested = row["lessons"] as? [[String: Any]] ?? []

        let lessons = nested.compactMap(Self.miniLesson(from:))

        let pace = minutes.map { "\(max($0, 1)) min" }

        return CourseModule(
            title: headline,
            duration: pace,
            isCompleted: completed,
            isLocked: locked,
            description: detail,
            lessons: lessons.isEmpty ? nil : lessons)
    }

    private static func miniLesson(from row: [String: Any]) -> ModuleLessonData? {
        guard let titleRow =
                extractString(row["title"]).nonEmpty
                ?? extractString(row["name"]).nonEmpty else {
            return nil }

        let schedule =
            extractString(row["duration"]).nonEmpty ??
            coerceInt(row["estimated_minutes"]).map { "\(max($0, 1)) min" }

        let done =
            coerceBool(row["completed"]) ?? coerceBool(row["done"]) ?? false

        return ModuleLessonData(title: titleRow, duration: schedule, isCompleted: done)
    }

    private static func decodeStudyPlan(_ data: Data) -> StudyPlan? {
        if let decoded = try? JSONDecoder.lyoDecoder.decode(StudyPlan.self, from: data) {
            return decoded }
        guard let root = loadJSON(data),
              let repacked =
                try? JSONSerialization.data(withJSONObject: unwrapPayload(root), options: [])
        else { return nil }
        return try? JSONDecoder.lyoDecoder.decode(StudyPlan.self, from: repacked)
    }

    // MARK: Helpers

    private static func loadJSON(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func unwrapPayload(_ root: [String: Any]) -> [String: Any] {
        (root["payload"] as? [String: Any]) ?? root
    }

    private static func coerceInt(_ leaf: Any?) -> Int? {
        switch leaf {
        case let int as Int:
            return int
        case let number as NSNumber:
            return number.intValue
        case let literal as String:
            return Int(literal)
        default:
            return nil }
    }

    private static func coerceBool(_ leaf: Any?) -> Bool? {
        guard let value = leaf else { return nil }
        if let boolean = value as? Bool { return boolean }
        if let number = value as? NSNumber {
            return number.boolValue }

        guard let literal = value as? String else { return nil }
        switch literal.lowercased() {
        case "true", "yes", "1": return true
        case "false", "no", "0": return false
        default: return nil }
    }

    private static func extractString(_ leaf: Any?) -> String {
        switch leaf {
        case let literal as String:
            return literal
        case let numeric as NSNumber:
            return numeric.stringValue
        default:
            return "" }
    }

    private static func hasStructured(_ widgets: [MessageContentType]) -> Bool {
        widgets.contains {
            switch $0 {
            case .courseRoadmap, .courseProposal, .quiz, .flashcards, .studyPlan:
                return true
            default:
                return false }
        }
    }

    private static func uniquesPreserveOrder(_ values: [MessageContentType]) -> [MessageContentType] {
        var bucket: [MessageContentType] = []
        bucket.reserveCapacity(values.count)
        for value in values where !bucket.contains(where: { $0 == value }) {
            bucket.append(value)
        }
        return bucket
    }

    private static func synthesizeExplainer(from prose: String) -> QuickExplainerData? {
        guard prose.count > 180 else { return nil }

        let chips =
            prose
                .split(whereSeparator: \.isNewline)
                .compactMap(Self.bulletSnippet(from:))

        guard chips.count >= 3 else { return nil }

        let heading = firstHeading(from: prose)
        let conceptBanner =
            heading
                ?? prose
                    .split(whereSeparator: \.isNewline)
                    .map { Self.trimLine(String($0)) }
                    .first { !$0.isEmpty && !$0.hasPrefix("#") }
                ?? "Key ideas"

        let synopsis = explanatoryBlurb(from: prose, skippingFirstHeading: heading)
        guard synopsis.count >= 120 else { return nil }

        return QuickExplainerData(concept: conceptBanner, explanation: synopsis, chips: Array(chips.prefix(8)))
    }

    private static func bulletSnippet(from lineSub: Substring) -> String? {
        let line = trimLine(String(lineSub))
        let markers = ["- ", "• ", "* ", "– ", "— "]
        guard let marker = markers.first(where: { line.hasPrefix($0) }) else { return nil }
        var body = String(line.dropFirst(marker.count)).trimmingCharacters(in: .whitespacesAndNewlines)
        guard body.count >= 8 else { return nil }
        if body.count > 96 {
            body = String(body.prefix(93)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
        }
        return body
    }

    private static func trimLine(_ line: String) -> String {
        line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstHeading(from prose: String) -> String? {
        for raw in prose.split(whereSeparator: \.isNewline) {
            let line = trimLine(String(raw))
            guard line.hasPrefix("#") else { continue }
            let stripped = trimLine(line.replacingOccurrences(of: #"^#+\s*"#, with: "", options: .regularExpression))
            return stripped.isEmpty ? nil : stripped
        }
        return nil
    }

    private static func explanatoryBlurb(from prose: String, skippingFirstHeading heading: String?) -> String {
        var lines =
            prose
                .split(whereSeparator: \.isNewline)
                .map { trimLine(String($0)) }
                .filter { !$0.isEmpty }

        if let heading, let idx = lines.firstIndex(of: heading) {
            lines.remove(at: idx)
        }

        lines = lines.filter { line in
            if line.hasPrefix("#") { return false }
            if bulletSnippet(from: Substring(line)) != nil { return false }
            return true
        }

        let joined = lines.prefix(6).joined(separator: "\n\n")
        let limit = 720
        if joined.count <= limit { return joined }
        return String(joined.prefix(limit)).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }
}

private extension String {
    /// Trims whitespace; returns `nil` when empty (handy after `extractString`).
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
