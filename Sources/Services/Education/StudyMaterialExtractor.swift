import Foundation

/// Lifts study material out of an assistant reply that only *describes* it.
///
/// Chat already renders `.flashcards`, `.studyPlan` and `.notes` bubbles, but it
/// only ever received them as `FlashcardsBlock` / `StudyPlanBlock` artifacts from
/// the backend. When the answer to "make me flashcards on X" arrives as ordinary
/// Markdown prose — the common case — the learner just sees a paragraph. This
/// extractor closes that gap on the client: it reads the finished reply and lifts
/// the term/definition pairs (or the day-by-day plan, or the sectioned notes) out
/// of the Markdown into real cards.
///
/// Deliberately conservative. It runs only on an explicit study-material ask (or
/// a reply that labels itself a deck), accepts only list-shaped lines — never
/// free prose, which would turn any sentence containing a colon into a card —
/// and needs `minimumCards` cards before it will restructure anything.
enum StudyMaterialExtractor {

    /// What the learner asked for.
    enum Ask: Equatable {
        case flashcards
        case studyPlan
        case notes
        /// Not a study-material ask.
        case unrelated
    }

    struct Result: Equatable {
        /// The reply with the lifted lines removed, for the text bubble above the cards.
        let displayText: String
        /// The cards to render under it.
        let contentTypes: [MessageContentType]
    }

    /// Fewest cards worth turning a prose answer into a deck.
    private static let minimumCards = 3
    private static let minimumPlanDays = 2
    private static let minimumNoteSections = 2

    /// Above this much leftover prose the reply is an explanation that happens to
    /// contain a list, not a deck. Restructuring it would hide the explanation,
    /// because the bubble suppresses message text once a card is present.
    private static let maximumLeftoverProse = 600

    // MARK: - Entry point

    static func extract(from reply: String, userAsk: String) -> Result? {
        let ask = classify(userAsk)
        let selfLabelledDeck = mentionsDeck(reply)
        guard ask != .unrelated || selfLabelledDeck else { return nil }

        let lines = reply.components(separatedBy: .newlines)

        // A fenced ```json payload is the most reliable signal, so read it first.
        if let fenced = fencedResult(in: reply) { return fenced }

        // Otherwise read the Markdown the model actually wrote.
        if ask == .flashcards || selfLabelledDeck,
            let deck = flashcardResult(from: lines, userAsk: userAsk, reply: reply) {
            return deck
        }
        if ask == .studyPlan,
            let plan = studyPlanResult(from: lines, reply: reply) {
            return plan
        }
        if ask == .notes,
            let notes = notesResult(from: lines, reply: reply) {
            return notes
        }
        return nil
    }

    // MARK: - Intent

    static func classify(_ userAsk: String) -> Ask {
        let text = userAsk.lowercased()
        if containsAny(
            text,
            [
                "flashcard", "flash card", "flash-card", "cue card", "study deck",
                "study cards", "key terms", "term and definition", "terms and definitions",
                "glossary", "quizlet",
            ])
        {
            return .flashcards
        }
        if containsAny(
            text,
            [
                "study plan", "study schedule", "revision plan", "revision schedule",
                "study timetable", "plan to study", "schedule to study",
            ])
        {
            return .studyPlan
        }
        if containsAny(
            text,
            [
                "study material", "study materials", "study guide", "study notes",
                "study sheet", "cheat sheet", "revision notes", "summary notes",
                "notes on", "notes for", "summarize for study",
            ])
        {
            return .notes
        }
        return .unrelated
    }

    /// A reply that opens by calling itself a deck is treated as one even when the
    /// ask was vague ("do that for chapter 4").
    private static func mentionsDeck(_ reply: String) -> Bool {
        let head = reply.prefix(400).lowercased()
        return head.contains("flashcard") || head.contains("flash card")
    }

    // MARK: - Fenced JSON payloads

    private struct FencedBlock {
        let raw: String
        let json: String
    }

    private static func fencedResult(in reply: String) -> Result? {
        for block in fencedJSONBlocks(in: reply) {
            guard let data = block.json.data(using: .utf8),
                let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            else { continue }
            let body = payloadBody(root)

            if let cards = decodeCards(fromJSON: body) ?? decodeCards(fromJSON: root), cards.count >= 2 {
                let title =
                    firstString(body, ["title", "topic"])
                    ?? firstString(root, ["title", "topic"])
                    ?? "Study deck"
                return Result(
                    displayText: stripping(
                        block.raw, from: reply, fallback: "Here's your deck 👇"),
                    contentTypes: [.flashcards(title: title, cards: cards)])
            }
            if let plan = decodePlan(fromJSON: body) ?? decodePlan(fromJSON: root) {
                return Result(
                    displayText: stripping(
                        block.raw, from: reply, fallback: "Here's your study plan 👇"),
                    contentTypes: [.studyPlan(plan: plan)])
            }
        }
        return nil
    }

    private static func fencedJSONBlocks(in source: String) -> [FencedBlock] {
        let pattern = "```(?:json)?\\s*([\\s\\S]*?)```"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        else { return [] }

        let full = source as NSString
        let matches = regex.matches(
            in: source, range: NSRange(location: 0, length: full.length))

        var blocks: [FencedBlock] = []
        for match in matches where match.numberOfRanges > 1 {
            let inner = full.substring(with: match.range(at: 1))
            guard let json = balancedObject(in: inner) else { continue }
            blocks.append(
                FencedBlock(raw: full.substring(with: match.range), json: json))
        }

        // Some replies carry the payload with no fence around it at all.
        if blocks.isEmpty, let json = balancedObject(in: source) {
            blocks.append(FencedBlock(raw: json, json: json))
        }
        return blocks
    }

    /// The first brace-balanced JSON object in `text`.
    ///
    /// A regex cannot do this job: a lazy `\{[\s\S]*?\}` stops at the first
    /// inner closing brace — so `{"cards": [{"front": …}]}` is captured as
    /// invalid JSON and silently dropped — while a greedy one swallows
    /// everything after the payload.
    private static func balancedObject(in text: String) -> String? {
        guard let start = text.firstIndex(of: "{") else { return nil }

        var depth = 0
        var insideString = false
        var escaped = false
        var index = start

        while index < text.endIndex {
            let character = text[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == "\"" {
                insideString.toggle()
            } else if !insideString {
                if character == "{" {
                    depth += 1
                } else if character == "}" {
                    depth -= 1
                    if depth == 0 { return String(text[start...index]) }
                }
            }
            index = text.index(after: index)
        }
        return nil
    }

    private static func payloadBody(_ root: [String: Any]) -> [String: Any] {
        for key in ["payload", "data", "content", "deck"] {
            if let nested = root[key] as? [String: Any] { return nested }
        }
        return root
    }

    private static func decodeCards(fromJSON body: [String: Any]) -> [Flashcard]? {
        var rows = body["cards"] as? [[String: Any]]
        if rows == nil { rows = body["flashcards"] as? [[String: Any]] }
        if rows == nil { rows = body["items"] as? [[String: Any]] }
        guard let rows = rows else { return nil }

        var cards: [Flashcard] = []
        for row in rows {
            guard let front = firstString(row, ["front", "term", "question", "prompt"]),
                let back = firstString(row, ["back", "definition", "answer", "response"])
            else { continue }
            cards.append(Flashcard(front: front, back: back))
        }
        return cards.isEmpty ? nil : cards
    }

    private static func decodePlan(fromJSON body: [String: Any]) -> StudyPlan? {
        var rows = body["schedule"] as? [[String: Any]]
        if rows == nil { rows = body["days"] as? [[String: Any]] }
        guard let rows = rows, !rows.isEmpty else { return nil }

        var days: [StudyDay] = []
        for (offset, row) in rows.enumerated() {
            let topic = firstString(row, ["topic", "title", "focus"]) ?? "Day \(offset + 1)"
            let number =
                int(row["day"]) ?? int(row["day_number"]) ?? int(row["dayNumber"]) ?? (offset + 1)

            var tasks: [StudyTask] = []
            for taskRow in (row["tasks"] as? [[String: Any]]) ?? [] {
                guard let title = firstString(taskRow, ["title", "name", "task"]) else { continue }
                let duration =
                    int(taskRow["duration_minutes"]) ?? int(taskRow["durationMinutes"])
                    ?? int(taskRow["minutes"]) ?? 20
                let kind =
                    firstString(taskRow, ["type", "activity_type", "activityType"]) ?? "read"
                tasks.append(
                    StudyTask(title: title, durationMinutes: duration, type: kind))
            }
            days.append(StudyDay(dayNumber: number, topic: topic, tasks: tasks))
        }

        guard days.count >= minimumPlanDays else { return nil }
        return StudyPlan(
            title: firstString(body, ["title", "name"]) ?? "Your study plan",
            description: firstString(body, ["description", "summary"]),
            schedule: days)
    }

    // MARK: - Markdown flashcards

    private struct ParsedCards {
        var cards: [Flashcard] = []
        var consumed: Set<Int> = []
    }

    private static func flashcardResult(
        from lines: [String], userAsk: String, reply: String
    ) -> Result? {
        var parsed = pairedCards(in: lines)
        if parsed.cards.count < minimumCards {
            parsed = inlineCards(in: lines)
        }
        guard parsed.cards.count >= minimumCards else { return nil }

        let leftovers =
            lines
            .enumerated()
            .filter { !parsed.consumed.contains($0.offset) }
            .map { $0.element }
        let remainder = prose(
            from: leftovers, fallback: "Here's your deck — tap a card to flip it 👇")
        guard remainder.count <= maximumLeftoverProse else { return nil }

        return Result(
            displayText: remainder,
            contentTypes: [
                .flashcards(
                    title: deckTitle(userAsk: userAsk, reply: reply), cards: parsed.cards)
            ])
    }

    private static let frontLabels = ["front:", "term:", "q:", "question:", "word:"]
    private static let backLabels = ["back:", "definition:", "a:", "answer:", "meaning:"]

    /// `Front: …` / `Back: …` and `Q: …` / `A: …` across two lines.
    private static func pairedCards(in lines: [String]) -> ParsedCards {
        var parsed = ParsedCards()
        var index = 0

        while index < lines.count {
            guard let front = labelledValue(lines[index], labels: frontLabels) else {
                index += 1
                continue
            }
            var next = index + 1
            while next < lines.count, listBody(lines[next]).isEmpty { next += 1 }
            guard next < lines.count,
                let back = labelledValue(lines[next], labels: backLabels)
            else {
                index += 1
                continue
            }
            parsed.cards.append(Flashcard(front: front, back: back))
            parsed.consumed.insert(index)
            parsed.consumed.insert(next)
            index = next + 1
        }
        return parsed
    }

    private static func labelledValue(_ rawLine: String, labels: [String]) -> String? {
        let line = listBody(rawLine)
        let lowered = line.lowercased()
        for label in labels where lowered.hasPrefix(label) {
            return tidy(String(line.dropFirst(label.count)))
        }
        return nil
    }

    /// One card per line: `- Term: definition`, `**Term** — definition`, `| Term | Definition |`.
    private static func inlineCards(in lines: [String]) -> ParsedCards {
        var parsed = ParsedCards()
        var seen: Set<String> = []

        for (index, rawLine) in lines.enumerated() {
            guard let pair = inlinePair(rawLine) else { continue }
            let key = pair.front.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            parsed.cards.append(Flashcard(front: pair.front, back: pair.back))
            parsed.consumed.insert(index)
        }
        return parsed
    }

    /// Only list items, bold-led lines and table rows become cards. Free prose is
    /// skipped on purpose — otherwise "Note: this matters" would become a card.
    private static func inlinePair(_ rawLine: String) -> (front: String, back: String)? {
        let line = rawLine.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty, !line.hasPrefix("#") else { return nil }

        if let row = tableRow(line) { return row }

        let isListItem = line.range(of: listMarkerPattern, options: .regularExpression) != nil
        guard isListItem || line.hasPrefix("**") else { return nil }

        let body = listBody(line)
        guard let separator = separatorRange(in: body) else { return nil }
        guard let front = tidy(String(body[body.startIndex..<separator.lowerBound])),
            let back = tidy(String(body[separator.upperBound...])),
            front.count >= 2, front.count <= 160, back.count >= 2
        else { return nil }

        return (front, back)
    }

    private static func tableRow(_ line: String) -> (front: String, back: String)? {
        guard line.hasPrefix("|") else { return nil }
        let cells =
            line
            .split(separator: "|", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard cells.count >= 2 else { return nil }

        // The `|---|---|` rule and the header row carry no card content.
        if cells[0].allSatisfy({ $0 == "-" || $0 == ":" }) { return nil }
        if ["term", "front", "question", "word", "concept"].contains(cells[0].lowercased()) {
            return nil
        }
        guard let front = tidy(cells[0]), let back = tidy(cells[1]),
            front.count >= 2, back.count >= 2
        else { return nil }
        return (front, back)
    }

    /// Earliest of the separators a model uses between a term and its definition.
    private static func separatorRange(in body: String) -> Range<String.Index>? {
        var earliest: Range<String.Index>?
        for candidate in [" — ", " – ", " -- ", ": ", " - ", "—", "–"] {
            guard let found = body.range(of: candidate) else { continue }
            if let current = earliest, current.lowerBound <= found.lowerBound { continue }
            earliest = found
        }
        return earliest
    }

    private static func deckTitle(userAsk: String, reply: String) -> String {
        if let heading = firstHeading(in: reply) { return heading }
        if let topic = topicPhrase(fromAsk: userAsk) { return "Flashcards: \(topic)" }
        return "Study deck"
    }

    /// Pulls "photosynthesis" out of "make flashcards on photosynthesis".
    private static func topicPhrase(fromAsk ask: String) -> String? {
        let lowered = ask.lowercased()
        for marker in [" on ", " about ", " for ", " covering ", " from "] {
            guard let range = lowered.range(of: marker) else { continue }
            if let tidied = tidy(String(lowered[range.upperBound...])),
                tidied.count >= 3, tidied.count <= 60 {
                return tidied
            }
        }
        return nil
    }

    // MARK: - Markdown study plan

    private static func studyPlanResult(from lines: [String], reply: String) -> Result? {
        var days: [StudyDay] = []
        var consumed: Set<Int> = []
        var openTopic: String?
        var openNumber = 0
        var openTasks: [StudyTask] = []

        func closeDay() {
            guard let topic = openTopic else { return }
            days.append(StudyDay(dayNumber: openNumber, topic: topic, tasks: openTasks))
            openTopic = nil
            openTasks = []
        }

        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let day = dayHeading(line) {
                closeDay()
                openNumber = day.number
                openTopic = day.topic
                consumed.insert(index)
                continue
            }
            if openTopic != nil, let task = planTask(line) {
                openTasks.append(task)
                consumed.insert(index)
            }
        }
        closeDay()

        guard days.count >= minimumPlanDays else { return nil }

        let leftovers =
            lines
            .enumerated()
            .filter { !consumed.contains($0.offset) }
            .map { $0.element }
        let remainder = prose(from: leftovers, fallback: "Here's your study plan 👇")
        guard remainder.count <= maximumLeftoverProse else { return nil }

        return Result(
            displayText: remainder,
            contentTypes: [
                .studyPlan(
                    plan: StudyPlan(
                        title: firstHeading(in: reply) ?? "Your study plan",
                        description: nil,
                        schedule: days))
            ])
    }

    private static func dayHeading(_ line: String) -> (number: Int, topic: String)? {
        let body =
            listBody(line)
            .replacingOccurrences(of: "#", with: "")
            .trimmingCharacters(in: .whitespaces)
        let lowered = body.lowercased()
        guard lowered.hasPrefix("day ") || lowered.hasPrefix("week ") else { return nil }

        let fromDigits = body.drop(while: { !$0.isNumber })
        let digits = String(fromDigits.prefix(while: { $0.isNumber }))
        guard let number = Int(digits) else { return nil }

        let rest = String(fromDigits.dropFirst(digits.count))
        return (number, tidy(rest) ?? "Study session \(number)")
    }

    private static func planTask(_ line: String) -> StudyTask? {
        guard line.range(of: listMarkerPattern, options: .regularExpression) != nil,
            let title = tidy(listBody(line))
        else { return nil }
        return StudyTask(
            title: title, durationMinutes: minutes(in: title) ?? 20, type: taskKind(title))
    }

    private static func minutes(in text: String) -> Int? {
        guard
            let match = text.range(
                of: "\\d+\\s*(?:min|minute)", options: [.regularExpression, .caseInsensitive])
        else { return nil }
        return Int(String(text[match]).prefix(while: { $0.isNumber }))
    }

    private static func taskKind(_ title: String) -> String {
        let lowered = title.lowercased()
        if lowered.contains("watch") || lowered.contains("video") { return "watch" }
        if lowered.contains("quiz") || lowered.contains("practice")
            || lowered.contains("problem") {
            return "practice"
        }
        return "read"
    }

    // MARK: - Markdown notes

    private static func notesResult(from lines: [String], reply: String) -> Result? {
        var sections: [NoteSection] = []
        var lead: [String] = []
        var openTitle: String?
        var openBody: [String] = []

        func closeSection() {
            guard let title = openTitle else { return }
            let body = openBody.joined(separator: "\n").trimmingCharacters(
                in: .whitespacesAndNewlines)
            if !body.isEmpty {
                sections.append(
                    NoteSection(title: title, contentMarkdown: body, isCallout: false))
            }
            openTitle = nil
            openBody = []
        }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if let heading = sectionHeading(line) {
                closeSection()
                openTitle = heading
                continue
            }
            if openTitle != nil {
                if !line.isEmpty { openBody.append(line) }
            } else if !line.isEmpty, !line.hasPrefix("#") {
                lead.append(line)
            }
        }
        closeSection()

        guard sections.count >= minimumNoteSections else { return nil }

        return Result(
            displayText: prose(from: lead, fallback: "Here are your study notes 👇"),
            contentTypes: [
                .notes(title: firstHeading(in: reply) ?? "Study notes", sections: sections)
            ])
    }

    private static func sectionHeading(_ line: String) -> String? {
        if line.hasPrefix("##") {
            return tidy(String(line.drop(while: { $0 == "#" })))
        }
        // A whole line in bold reads as a section heading, but a bold run inside a
        // sentence does not.
        if line.hasPrefix("**"), line.hasSuffix("**"), line.count > 4, !line.contains(". ") {
            return tidy(line)
        }
        return nil
    }

    // MARK: - Shared helpers

    private static let listMarkerPattern = "^(?:[-*+•]|\\d+[.)])\\s+"

    /// A line with its list marker (`-`, `*`, `1.`), Markdown emphasis and outer
    /// whitespace removed. Emphasis goes early so `**Term:** definition` — a very
    /// common shape — still exposes its `: ` separator.
    private static func listBody(_ rawLine: String) -> String {
        rawLine
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: listMarkerPattern, with: "", options: .regularExpression)
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    private static func tidy(_ text: String) -> String? {
        let stripped =
            text
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t*_—–-:"))
        return stripped.isEmpty ? nil : stripped
    }

    private static func firstHeading(in reply: String) -> String? {
        for rawLine in reply.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("#") else { continue }
            if let tidied = tidy(String(line.drop(while: { $0 == "#" }))),
                tidied.count >= 3, tidied.count <= 80 {
                return tidied
            }
        }
        return nil
    }

    /// The reply text left over once the cards have been lifted out. A couple of
    /// orphaned words is noise, so fall back to a short lead-in instead.
    private static func prose(from lines: [String], fallback: String) -> String {
        let kept =
            lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("|") }
        let text = kept.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        return text.count >= 12 ? text : fallback
    }

    private static func containsAny(_ haystack: String, _ needles: [String]) -> Bool {
        for needle in needles where haystack.contains(needle) { return true }
        return false
    }

    private static func firstString(_ row: [String: Any], _ keys: [String]) -> String? {
        for key in keys {
            if let value = string(row[key]) { return value }
        }
        return nil
    }

    private static func string(_ value: Any?) -> String? {
        guard let text = value as? String else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func int(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? Double { return Int(number) }
        if let text = value as? String { return Int(text) }
        return nil
    }

    /// `source` with `fragment` removed, or `fallback` when nothing readable is left.
    private static func stripping(
        _ fragment: String, from source: String, fallback: String
    ) -> String {
        let stripped =
            source
            .replacingOccurrences(of: fragment, with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return stripped.isEmpty ? fallback : stripped
    }
}
