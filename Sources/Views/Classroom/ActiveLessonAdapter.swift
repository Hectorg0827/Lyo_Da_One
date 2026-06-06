import Foundation

/// Bridges the WebSocket-driven `[SDUIComponent]` stream produced by
/// `LivingClassroomService` into the `[ActiveLessonView.LessonStep]`
/// shape that the new lesson UI consumes.
///
/// Strategy:
///   - Walk components in order.
///   - Each `TeacherMessage` starts a new step (the "spoken" line).
///   - The next `LessonBlock` (callout, comparison, diagram, code, …) and
///     `StudentPrompt` immediately following are attached to that step as
///     supporting content + key term, until the next TeacherMessage arrives.
///   - The final step inherits the `CTAButton` label as its primary action;
///     non-final steps use the default "Continue".
///   - If no TeacherMessage exists yet, no step is emitted (loading state).
enum ActiveLessonAdapter {

    // JSON mapping for the new v2 prompt output format
    struct DirectorTurn: Decodable {
        let type: String
        let speaker: String?
        let text: String?
        let state: String?
        let action: String?
        let content: String?
        let seconds: Int?
        let input: String?
        let options: [String]?
    }

    static func steps(from components: [SDUIComponent]) -> [ActiveLessonView.LessonStep] {
        var result: [ActiveLessonView.LessonStep] = []
        var pendingText: String?
        var pendingId: String?
        var pendingSpeakerName: String?
        var pendingSpeakerBadge: String?
        var pendingSpeakerImageName: String?

        var pendingSupporting: ActiveLessonView.LessonStep.SupportingBlock?
        var pendingKeyTerm: ActiveLessonView.LessonStep.KeyTerm?
        var finalCtaLabel: String?
        var finalCtaIntent: String?
        var finalCtaComponentId: String?
        var finalCtaPayload: [String: String]?

        func flush() {
            guard let id = pendingId, let text = pendingText, !text.isEmpty else {
                pendingId = nil; pendingText = nil
                pendingSpeakerName = nil; pendingSpeakerBadge = nil; pendingSpeakerImageName = nil
                pendingSupporting = nil; pendingKeyTerm = nil
                return
            }
            result.append(.init(
                id: id,
                teachingText: text,
                supporting: pendingSupporting,
                keyTerm: pendingKeyTerm,
                primaryActionLabel: "Continue",
                speakerName: pendingSpeakerName ?? "Teacher",
                speakerBadge: pendingSpeakerBadge ?? "AI Teacher ✨",
                speakerImageName: pendingSpeakerImageName
            ))
            pendingId = nil
            pendingText = nil
            pendingSpeakerName = nil
            pendingSpeakerBadge = nil
            pendingSpeakerImageName = nil
            pendingSupporting = nil
            pendingKeyTerm = nil
        }

        for component in components {
            switch component.type {
            case .teacherMessage:
                flush()
                // Attempt to parse as new v2 JSON array
                var resolvedTurns: [DirectorTurn]? = nil
                if let data = component.content.data(using: .utf8) {
                    resolvedTurns = try? JSONDecoder().decode([DirectorTurn].self, from: data)
                }
                
                // Fallback parser if JSONDecoder failed
                if resolvedTurns == nil {
                    resolvedTurns = FallbackTurnParser.parse(component.content)
                }

                if let turns = resolvedTurns {
                    for (turnIndex, turn) in turns.enumerated() {
                        if turn.type == "speech" || turn.type == "user_prompt" {
                            flush() // flush previous turn in the sequence
                            pendingId = "\(component.id)_turn_\(turnIndex)"
                            pendingText = turn.text
                            pendingSpeakerName = turn.speaker ?? "Teacher"

                            switch pendingSpeakerName {
                            case "Maya":
                                pendingSpeakerBadge = "Classmate"
                                pendingSpeakerImageName = "student_genius"
                            case "Sam":
                                pendingSpeakerBadge = "Classmate"
                                pendingSpeakerImageName = "student_clever"
                            case "Rio":
                                pendingSpeakerBadge = "Classmate"
                                pendingSpeakerImageName = "student_funny"
                            case "Zack":
                                pendingSpeakerBadge = "Classmate"
                                pendingSpeakerImageName = "student_dumb"
                            case "Lyo":
                                pendingSpeakerBadge = "Companion"
                                pendingSpeakerImageName = nil
                            default:
                                pendingSpeakerBadge = "AI Teacher ✨"
                                pendingSpeakerImageName = nil
                            }
                        } else if turn.type == "board", let content = turn.content {
                            // Map board content to a LiveLessonBlock dynamically!
                            let blockType: LessonBlockType
                            var mermaid: String? = nil
                            var latex: String? = nil
                            var code: String? = nil
                            var title = turn.action?.capitalized ?? "Board Insight"
                            
                            let contentLower = content.lowercased()
                            if content.hasPrefix("graph ") || content.hasPrefix("flowchart ") || content.contains("-->") || contentLower.contains("subgraph") {
                                blockType = .diagram
                                mermaid = content
                                title = "Visual Concept Map"
                            } else if content.contains("\\frac") || content.contains("\\sum") || content.contains("\\theta") || (content.hasPrefix("$") && content.hasSuffix("$")) {
                                blockType = .math
                                latex = content.replacingOccurrences(of: "$", with: "")
                                title = "Formula Analysis"
                            } else if contentLower.contains("def ") || contentLower.contains("func ") || contentLower.contains("let ") || contentLower.contains("import ") || contentLower.contains("class ") {
                                blockType = .code
                                code = content
                                title = "Code Example"
                            } else {
                                blockType = .callout
                                title = "Teacher's Chalkboard"
                            }
                            
                            let lessonBlock = LiveLessonBlock(
                                id: "\(component.id)_board_\(turnIndex)",
                                type: blockType,
                                title: title,
                                content: content,
                                subtitle: nil,
                                imageURL: nil,
                                videoURL: nil,
                                audioURL: nil,
                                altText: nil,
                                caption: nil,
                                code: code,
                                language: blockType == .code ? "swift" : nil,
                                isRunnable: blockType == .code,
                                question: nil,
                                options: nil,
                                correctIndex: nil,
                                correctAnswer: nil,
                                explanation: nil,
                                hint: nil,
                                chartType: nil,
                                chartData: nil,
                                latex: latex,
                                mermaid: mermaid,
                                front: nil,
                                back: nil,
                                cards: nil,
                                headers: nil,
                                rows: nil,
                                style: nil,
                                lyoCommentary: nil,
                                mood: nil,
                                duration: nil,
                                difficulty: nil,
                                tags: nil
                            )
                            pendingSupporting = .lessonBlock(lessonBlock)
                        }
                    }
                } else {
                    // Legacy single-message format or plain-text fallback
                    pendingId = component.id
                    pendingText = component.content
                    pendingSpeakerName = "Teacher"
                    pendingSpeakerBadge = "AI Teacher ✨"
                    pendingSpeakerImageName = nil
                }

            case .lessonBlock:
                if let block = component.lessonBlock {
                    if let comparison = comparisonModel(from: block) {
                        pendingSupporting = .comparison(comparison)
                    } else if let term = keyTerm(from: block) {
                        pendingKeyTerm = term
                    } else if pendingSupporting == nil {
                        pendingSupporting = .lessonBlock(block)
                    }
                }

            case .ctaButton:
                finalCtaLabel = component.content.isEmpty ? "Continue" : component.content
                finalCtaIntent = component.actionIntent
                finalCtaComponentId = component.id
                finalCtaPayload = component.actionPayload

            case .quizCard:
                if pendingText == nil {
                    pendingId = "quiz_intro_\(component.id)"
                    pendingText = component.content.isEmpty
                        ? "Before we move on, let's do a quick challenge."
                        : component.content
                    pendingSpeakerName = "Teacher"
                    pendingSpeakerBadge = "Checkpoint"
                    pendingSpeakerImageName = nil
                }
                pendingSupporting = .classroomQuiz(component)

            // StudentPrompt and lightweight components are folded into the current
            // teaching text or skipped for now. Keeps the screen calm.
            case .studentPrompt, .textBlock, .codeBlock, .progressBar, .unknown:
                continue
            }
        }

        flush()

        // Apply the final CTA label to the last step.
        if let label = finalCtaLabel, let last = result.last {
            result[result.count - 1] = .init(
                id: last.id,
                teachingText: last.teachingText,
                supporting: last.supporting,
                keyTerm: last.keyTerm,
                primaryActionLabel: label,
                primaryActionIntent: finalCtaIntent,
                primaryActionComponentId: finalCtaComponentId,
                primaryActionPayload: finalCtaPayload,
                speakerName: last.speakerName,
                speakerBadge: last.speakerBadge,
                speakerImageName: last.speakerImageName
            )
        }
        return result
    }

    // MARK: - LessonBlock → comparison

    private static func comparisonModel(
        from block: LiveLessonBlock
    ) -> ActiveLessonView.ConceptComparisonModel? {
        guard block.type == .comparison else { return nil }
        guard let headers = block.headers, headers.count >= 2,
              let rows = block.rows, !rows.isEmpty
        else { return nil }

        // Each row contributes one bullet to the left and right column.
        var leftBullets: [String] = []
        var rightBullets: [String] = []
        for row in rows {
            if row.count >= 2 {
                if !row[0].isEmpty { leftBullets.append(row[0]) }
                if !row[1].isEmpty { rightBullets.append(row[1]) }
            }
        }
        guard !leftBullets.isEmpty, !rightBullets.isEmpty else { return nil }

        return .init(
            title: block.title ?? "Comparison",
            leftHeading: headers[0],
            leftBullets: leftBullets,
            rightHeading: headers[1],
            rightBullets: rightBullets,
            takeaway: block.content
        )
    }

    // MARK: - LessonBlock → key term strip

    private static func keyTerm(
        from block: LiveLessonBlock
    ) -> ActiveLessonView.LessonStep.KeyTerm? {
        guard block.type == .callout else { return nil }
        guard let content = block.content, !content.isEmpty else { return nil }

        // Use title as the term; content as the definition.
        // If no title, render the strip as a generic "Note".
        let term = block.title?.isEmpty == false ? block.title! : "Note"
        return .init(term: term, definition: content, expandedDetail: nil)
    }
}

// MARK: - FallbackTurnParser

fileprivate struct FallbackTurnParser {
    static func parse(_ rawText: String) -> [ActiveLessonAdapter.DirectorTurn] {
        var turns: [ActiveLessonAdapter.DirectorTurn] = []
        
        // Lazy regex match to find each individual JSON object { ... }
        let pattern = "\\{(?:[^{}]|\\{[^{}]*\\})*\\}"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }
        
        let nsString = rawText as NSString
        let matches = regex.matches(in: rawText, options: [], range: NSRange(location: 0, length: nsString.length))
        
        for match in matches {
            let objectStr = nsString.substring(with: match.range)
            if let turn = parseObject(objectStr) {
                turns.append(turn)
            }
        }
        
        return turns
    }
    
    private static func parseObject(_ jsonStr: String) -> ActiveLessonAdapter.DirectorTurn? {
        let type = extractString(from: jsonStr, key: "type") ?? "speech"
        let speaker = extractString(from: jsonStr, key: "speaker")
        let text = extractString(from: jsonStr, key: "text")
        let state = extractString(from: jsonStr, key: "state")
        let action = extractString(from: jsonStr, key: "action")
        let content = extractString(from: jsonStr, key: "content")
        let input = extractString(from: jsonStr, key: "input")
        
        var seconds: Int? = nil
        if let secStr = extractValueWithoutQuotes(from: jsonStr, key: "seconds") {
            seconds = Int(secStr.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        var options: [String]? = nil
        if let optionsBlock = extractArray(from: jsonStr, key: "options") {
            let optPattern = "\"((?:[^\"\\\\]|\\\\.)*)\""
            if let optRegex = try? NSRegularExpression(pattern: optPattern, options: []) {
                let optNs = optionsBlock as NSString
                let optMatches = optRegex.matches(in: optionsBlock, options: [], range: NSRange(location: 0, length: optNs.length))
                var opts: [String] = []
                for optMatch in optMatches {
                    let optVal = optNs.substring(with: optMatch.range(at: 1))
                    opts.append(unescape(optVal))
                }
                if !opts.isEmpty {
                    options = opts
                }
            }
        }
        
        return ActiveLessonAdapter.DirectorTurn(
            type: type,
            speaker: speaker,
            text: text,
            state: state,
            action: action,
            content: content,
            seconds: seconds,
            input: input,
            options: options
        )
    }
    
    private static func extractString(from str: String, key: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\"((?:[^\"\\\\]|\\\\.)*)\""
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = str as NSString
        guard let match = regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        let rawVal = ns.substring(with: match.range(at: 1))
        return unescape(rawVal)
    }
    
    private static func extractValueWithoutQuotes(from str: String, key: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*([^,\\s}]+)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = str as NSString
        guard let match = regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: match.range(at: 1))
    }
    
    private static func extractArray(from str: String, key: String) -> String? {
        let pattern = "\"\(key)\"\\s*:\\s*\\[([^\\]]*)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let ns = str as NSString
        guard let match = regex.firstMatch(in: str, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        return ns.substring(with: match.range(at: 1))
    }
    
    private static func unescape(_ str: String) -> String {
        return str
            .replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
            .replacingOccurrences(of: "\\\\", with: "\\")
    }
}
