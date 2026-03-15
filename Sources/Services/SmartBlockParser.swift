import Foundation

public class SmartBlockParser {
    private static let isoFormatter = ISO8601DateFormatter()
    
    /// Parses an AI response text containing `:::` markers into an array of IdentifiableLessonBlocks.
    public static func parseResponse(_ aiText: String) -> [IdentifiableLessonBlock] {
        var blocks: [IdentifiableLessonBlock] = []
        
        let rawChunks = aiText.components(separatedBy: ":::")
        
        for (index, chunk) in rawChunks.enumerated() {
            let processedChunk = chunk.trimmingCharacters(in: .whitespacesAndNewlines)
            if processedChunk.isEmpty { continue }
            
            if index % 2 != 0 {
                // This is a block. Identify its type.
                let lines = processedChunk.components(separatedBy: .newlines)
                guard let firstLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                    continue
                }
                
                let blockType = firstLine
                var properties: [String: String] = [:]
                
                var currentKey = ""
                var currentValue = ""
                
                for line in lines.dropFirst() {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    
                    if trimmed.hasPrefix("- ") && !currentKey.isEmpty {
                        currentValue += (currentValue.isEmpty ? "" : "\n") + trimmed
                    } else if let colonIndex = line.firstIndex(of: ":") {
                        if !currentKey.isEmpty {
                            properties[currentKey] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                        
                        let key = String(line[..<colonIndex]).trimmingCharacters(in: .whitespaces)
                        let value = String(line[line.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                        
                        currentKey = key
                        currentValue = value
                    } else {
                        currentValue += (currentValue.isEmpty ? "" : "\n") + line.trimmingCharacters(in: .whitespaces)
                    }
                }
                
                if !currentKey.isEmpty {
                    properties[currentKey] = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                if let block = mapToBlock(type: blockType, props: properties) {
                    blocks.append(IdentifiableLessonBlock(block: block))
                }
                
            } else {
                // Text chunk
                if !processedChunk.isEmpty {
                    blocks.append(IdentifiableLessonBlock(block: .text(processedChunk)))
                }
            }
        }
        
        return blocks
    }
    
    private static func mapToBlock(type: String, props: [String: String]) -> LegacyLessonBlock? {
        switch type {
        case "quiz":
            let optionsStr = props["options"] ?? ""
            let options = optionsStr.components(separatedBy: "\n").compactMap { line -> String? in
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("-") {
                    return String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                } else if !t.isEmpty {
                    return t
                }
                return nil
            }
            
            return .quiz(QuizData(
                type: props["type"] ?? "multiple_choice",
                question: props["question"] ?? "",
                options: options,
                correct: findCorrectIndex(answer: props["answer"], options: options),
                explanation: props["explanation"] ?? "",
                hint: props["hint"],
                difficulty: props["difficulty"]
            ))
            
        case "flashcard":
            return .flashcard(FlashcardData(
                front: props["front"] ?? "",
                back: props["back"] ?? "",
                tags: props["tags"]
            ))
            
        case "flashcard_set":
            let cardsStr = props["cards"] ?? ""
            let cards = parseFlashcards(cardsStr)
            return .flashcardSet(FlashcardSetData(
                title: props["title"] ?? "Flashcard Set",
                cards: cards
            ))
            
        case "progress":
            return .progress(ProgressData(
                completed: Int(props["completed"] ?? "0") ?? 0,
                total: Int(props["total"] ?? "1") ?? 1,
                label: props["label"],
                sublabel: props["sublabel"]
            ))
            
        case "image":
            return .image(ImageData(
                query: props["query"] ?? "",
                caption: props["caption"] ?? "",
                style: props["style"]
            ))
            
        case "summary":
            let pointsStr = props["points"] ?? ""
            let points = pointsStr.components(separatedBy: "\n").compactMap { line -> String? in
                let t = line.trimmingCharacters(in: .whitespaces)
                return t.hasPrefix("-") ? String(t.dropFirst()).trimmingCharacters(in: .whitespaces) : nil
            }
            return .summary(SummaryData(
                title: props["title"] ?? "Summary",
                points: points
            ))
            
        case "test_prep":
            let coursesStr = props["courses"] ?? ""
            let courses = coursesStr.components(separatedBy: "\n").compactMap { line -> String? in
                let t = line.trimmingCharacters(in: .whitespaces)
                if t.hasPrefix("-") {
                    return String(t.dropFirst()).trimmingCharacters(in: .whitespaces)
                } else if !t.isEmpty {
                    return t
                }
                return nil
            }
            return .testPrep(TestPrepBlockData(
                topic: props["topic"] ?? "",
                date: parseISO8601Date(props["date"]),
                description: props["description"],
                courses: courses
            ))
            
        case "study_plan":
            let sessionsStr = props["sessions"] ?? ""
            let sessions = parseStudySessions(sessionsStr)
            return .studyPlan(StudyPlanData(
                title: props["title"] ?? "Study Plan",
                examDate: parseISO8601Date(props["exam_date"]),
                sessions: sessions
            ))
            
        case "agent_card":
            return .agentCard(AgentCardData(
                name: props["name"] ?? "Lyo Agent",
                role: props["role"] ?? "Specialist",
                status: props["status"] ?? "working",
                message: props["message"],
                icon: props["icon"]
            ))
            
        case "cinematic_hook":
            return .cinematicHook(CinematicHookData(
                title: props["title"] ?? "Epic Discovery",
                hook: props["hook"] ?? "",
                visualDescription: props["visual_description"],
                callToAction: props["cta"] ?? props["call_to_action"],
                mediaUrl: props["media_url"]
            ))
            
        case "mastery_map":
            let nodesStr = props["nodes"] ?? ""
            let nodes = parseMasteryNodes(nodesStr)
            return .masteryMap(MasteryMapData(
                courseTitle: props["course"] ?? props["title"] ?? "Course",
                nodes: nodes
            ))
            
        default:
            return .customUI(type)
        }
    }
    
    private static func findCorrectIndex(answer: String?, options: [String]) -> Int {
        guard let answer = answer?.trimmingCharacters(in: .whitespaces).lowercased() else { return 0 }
        if let idx = options.firstIndex(where: { $0.trimmingCharacters(in: .whitespaces).lowercased() == answer }) {
            return idx
        }
        return Int(answer) ?? 0
    }
    
    private static func parseFlashcards(_ text: String) -> [FlashcardData] {
        var cards: [FlashcardData] = []
        let chunks = text.components(separatedBy: "- front:")
        
        for chunk in chunks {
            if chunk.isEmpty { continue }
            let parts = chunk.components(separatedBy: "back:")
            if parts.count >= 2 {
                let front = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let back = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                cards.append(FlashcardData(front: front, back: back))
            }
        }
        return cards
    }

    private static func parseISO8601Date(_ text: String?) -> Date? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return nil }
        return isoFormatter.date(from: text)
    }

    private static func parseStudySessions(_ text: String) -> [StudySession] {
        var sessions: [StudySession] = []
        
        // Find all occurrences of "- title:" and split.
        // We skip any text before the first "- title:"
        let components = text.components(separatedBy: "- title:")
        guard components.count > 1 else { return [] }
        
        for chunk in components.dropFirst() {
            var session = StudySession(title: "", description: "", durationMinutes: 0, date: Date())
            
            let lines = chunk.components(separatedBy: .newlines)
            // The first part of the first line is the title (up to the next key or newline)
            if let firstLine = lines.first {
                session.title = firstLine.trimmingCharacters(in: .whitespaces)
            }
            
            for line in lines.dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
                
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "desc", "description": session.description = value
                case "duration": session.durationMinutes = Int(value) ?? 0
                case "date": session.date = parseISO8601Date(value) ?? Date()
                default: break
                }
            }
            
            if !session.title.isEmpty {
                sessions.append(session)
            }
        }
        return sessions
    }
    
    private static func parseMasteryNodes(_ text: String) -> [MasteryNode] {
        var nodes: [MasteryNode] = []
        let components = text.components(separatedBy: "- title:")
        guard components.count > 1 else { return [] }
        
        for chunk in components.dropFirst() {
            var node = MasteryNode(title: "", status: "locked", masteryLevel: 0.0)
            
            let lines = chunk.components(separatedBy: .newlines)
            if let firstLine = lines.first {
                node.title = firstLine.trimmingCharacters(in: .whitespaces)
            }
            
            for line in lines.dropFirst() {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                guard let colonIndex = trimmed.firstIndex(of: ":") else { continue }
                
                let key = String(trimmed[..<colonIndex]).trimmingCharacters(in: .whitespaces).lowercased()
                let value = String(trimmed[trimmed.index(after: colonIndex)...]).trimmingCharacters(in: .whitespaces)
                
                switch key {
                case "status": node.status = value.lowercased()
                case "mastery", "level": 
                    let cleanValue = value.replacingOccurrences(of: "%", with: "")
                    if let val = Double(cleanValue) {
                        node.masteryLevel = val > 1.0 ? val / 100.0 : val
                    }
                default: break
                }
            }
            
            if !node.title.isEmpty {
                nodes.append(node)
            }
        }
        return nodes
    }
}
