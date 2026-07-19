//
//  AICommandResponse.swift
//  Lyo
//
//  AI Command Response Parser - Detects structured commands from AI responses
//

import Foundation
import os

// MARK: - AI Command Response Parser
/// Parses AI responses to detect structured commands (like OPEN_CLASSROOM)

enum AICommandType: String, Codable {
    case openClassroom = "OPEN_CLASSROOM"
    case showQuiz = "SHOW_QUIZ"
    case addToStack = "ADD_TO_STACK"
    case normalChat = "NORMAL_CHAT"
    case testPrep = "TEST_PREP"
}

struct AICommandResponse: Codable {
    let type: AICommandType
    let payload: AICommandPayload?
}

struct AICommandPayload: Codable {
    let stackItem: StackItemPayload?
    let course: CoursePayload?
    let testPrep: TestPrepPayload?

    init(stackItem: StackItemPayload? = nil, course: CoursePayload? = nil, testPrep: TestPrepPayload? = nil) {
        self.stackItem = stackItem
        self.course = course
        self.testPrep = testPrep
    }

    enum CodingKeys: String, CodingKey {
        case stackItem = "stack_item"
        case course
        case testPrep = "test_prep"
    }
}

struct TestPrepPayload: Codable {
    let subject: String
    let testType: String
    let testDateISO: String?
    let confidenceLevel: String?
    let dailyStudyHours: Double?
    let studyPlan: StudyPlan?
    let quizItems: [TestPrepQuizItem]?
    let flashcardSets: [TestPrepFlashcardSet]?

    enum CodingKeys: String, CodingKey {
        case subject, testType, confidenceLevel, studyPlan
        case testDateISO = "test_date_iso"
        case dailyStudyHours = "daily_study_hours"
        case quizItems = "quiz_items"
        case flashcardSets = "flashcard_sets"
    }
}

struct StackItemPayload: Codable {
    let category: String
    let title: String
    let subtitle: String
    let status: String
    let due: String?
}


struct CoursePayload: Codable {
    let id: String?  
    let title: String
    let topic: String
    let level: String
    let language: String?  
    let duration: String?
    let objectives: [String]
    
    enum CodingKeys: String, CodingKey {
        case id, title, topic, level, language, duration, objectives
        case learningObjectives = "learning_objectives"
        case estimatedHours = "estimated_hours"
        case estimatedDuration = "estimated_duration"
        case difficulty
        case lessons
        case description
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        topic = (try? container.decode(String.self, forKey: .topic)) ?? title
        
        // Handle level or difficulty
        if let l = try? container.decode(String.self, forKey: .level) {
            level = l
        } else if let d = try? container.decode(String.self, forKey: .difficulty) {
            level = d
        } else {
            level = "Beginner"
        }
        
        language = try? container.decodeIfPresent(String.self, forKey: .language)
        
        // Handle duration, estimated_duration, or estimated_hours
        if let d = try? container.decode(String.self, forKey: .duration) {
            duration = d
        } else if let ed = try? container.decode(String.self, forKey: .estimatedDuration) {
            duration = ed
        } else if let h = try? container.decode(Int.self, forKey: .estimatedHours) {
            duration = "\(h) hours"
        } else if let hString = try? container.decode(String.self, forKey: .estimatedHours) {
            duration = hString
        } else {
            duration = nil
        }
        
        // Handle objectives, learning_objectives, or extract from lessons
        if let obj = try? container.decode([String].self, forKey: .objectives) {
            objectives = obj
        } else if let obj = try? container.decode([String].self, forKey: .learningObjectives) {
            objectives = obj
        } else if let lessons = try? container.decode([[String: AnyCodableValue]].self, forKey: .lessons) {
            // Extract lesson titles as objectives
            objectives = lessons.prefix(6).compactMap { lesson in
                (lesson["title"]?.value as? String) ?? (lesson["description"]?.value as? String)
            }
        } else {
            objectives = []
        }
    }
    
    // Default initializer for manual creation
    init(id: String?, title: String, topic: String, level: String, language: String?, duration: String?, objectives: [String]) {
        self.id = id
        self.title = title
        self.topic = topic
        self.level = level
        self.language = language
        self.duration = duration
        self.objectives = objectives
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(topic, forKey: .topic)
        try container.encode(level, forKey: .level)
        try container.encodeIfPresent(language, forKey: .language)
        try container.encodeIfPresent(duration, forKey: .duration)
        try container.encode(objectives, forKey: .objectives)
    }
}

// MARK: - Response Parser

struct AICommandParser {
    
    /// Represents a parsed AI response - either a command or regular chat
    enum ParsedResponse {
        case command(AICommandResponse)
        case chat(String)
    }
    
    /// Parse an AI response string to detect if it's a JSON command or regular chat
    static func parse(_ responseText: String) -> ParsedResponse {
        let trimmed = responseText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        Log.ai.debug("AICommandParser.parse() - Input length: \(trimmed.count) chars")
        
        // 1. Try standard extraction and decoding
        if let jsonString = extractJSON(from: trimmed),
           let jsonData = jsonString.data(using: .utf8) {
            Log.ai.info("   ✅ Extracted JSON (\(jsonData.count) bytes)")
            if let result = attemptDecoding(jsonData: jsonData) {
                return result
            }
            Log.ai.error("   ⚠️ JSON extracted but decoding failed")
        } else {
            Log.ai.info("   ⚠️ No valid JSON structure found (no closing brace)")
        }
        
        // 2. If it failed, it might be truncated. Try healing the JSON.
        if let firstBrace = trimmed.firstIndex(of: "{") {
            let potentialJson = String(trimmed[firstBrace...])
            Log.ai.info("   🩹 Attempting JSON healing on \(potentialJson.prefix(100))...")
            let healed = healJSON(potentialJson)
            Log.ai.info("   🩹 Healed JSON length: \(healed.count) bytes")
            if let jsonData = healed.data(using: .utf8),
               let result = attemptDecoding(jsonData: jsonData) {
                Log.ai.info("   ✅ Successfully recovered truncated JSON through healing")
                return result
            }
            Log.ai.error("   ❌ Healing failed to produce valid course")
        }
        
        // 3. FALLBACK: Check if text contains an explicit OPEN_CLASSROOM JSON with broken structure
        // Only trigger when the response explicitly contains "OPEN_CLASSROOM" type marker
        // AND has course-like JSON keys — prevents false positives from normal markdown.
        if trimmed.contains("OPEN_CLASSROOM") && trimmed.contains("\"title\"") {
            Log.ai.info("   🧠 Detected explicit OPEN_CLASSROOM markers, attempting extraction...")
            
            if let titleMatch = extractField(from: trimmed, field: "title"),
               !titleMatch.isEmpty {
                Log.ai.info("   ✅ Extracted title: \(titleMatch)")
                
                let topic = extractField(from: trimmed, field: "topic") ?? titleMatch
                let objectives = extractArrayField(from: trimmed, field: "learning_objectives") 
                    ?? extractArrayField(from: trimmed, field: "objectives")
                    ?? []
                
                let course = CoursePayload(
                    id: nil,
                    title: titleMatch,
                    topic: topic,
                    level: extractField(from: trimmed, field: "level") ?? "Beginner",
                    language: nil,
                    duration: extractField(from: trimmed, field: "estimated_hours"),
                    objectives: objectives
                )
                
                let command = AICommandResponse(
                    type: .openClassroom,
                    payload: AICommandPayload(stackItem: nil, course: course)
                )
                Log.ai.info("   ✅ Created course command from partial OPEN_CLASSROOM data")
                return .command(command)
            }
        }
        
        // NOTE: Markdown fallback (parseMarkdownCourse) was removed.
        // Normal AI markdown responses (with ** bold ** or # headings) must NOT be
        // mis-interpreted as course commands. Trust the backend's explicit
        // open_classroom SSE event instead.
        
        Log.ai.error("   ❌ Treating as plain chat")
        return .chat(responseText)
    }
    
    // MARK: - Markdown Parser
    private static func parseMarkdownCourse(from text: String) -> CoursePayload? {
        // 1. EXTRACT TITLE
        var title = "New Course"
        var topic = "General"
        
        // Regex for Title: Matches "**I. Title**" or "**1. Title**" or "## Title"
        // We use a flexible pattern that looks for bold headings with numbers/roman numerals
        let patterns = [
            "\\*\\*(?:[XVI]+|\\d+)\\.?\\s*(.+?)\\*\\*", // **I. Title**
            "#+\\s*(.+)"                                 // # Title
        ]
        
        var foundTitle = false
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let nsString = text as NSString
                let range = NSRange(location: 0, length: nsString.length)
                if let match = regex.firstMatch(in: text, options: [], range: range) {
                    // Capture group 1 is the title
                    if match.numberOfRanges > 1 {
                        let titleRange = match.range(at: 1)
                        title = nsString.substring(with: titleRange).trimmingCharacters(in: .punctuationCharacters)
                        topic = title
                        foundTitle = true
                        break
                    }
                }
            }
        }
        
        // 2. EXTRACT OBJECTIVES
        // Look for lines starting with *, -, or 1.
        var objectives: [String] = []
        let listPattern = "(?:^|\\n)\\s*(?:[*+-]|\\d+\\.)\\s+(.+)"
        
        if let regex = try? NSRegularExpression(pattern: listPattern, options: []) {
            let nsString = text as NSString
            let range = NSRange(location: 0, length: nsString.length)
            let matches = regex.matches(in: text, options: [], range: range)
            
            for match in matches {
                if match.numberOfRanges > 1 {
                    let textRange = match.range(at: 1)
                    let rawLine = nsString.substring(with: textRange)
                    // Clean up bold markers from the objective text
                    let cleanLine = rawLine.replacingOccurrences(of: "**", with: "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    if cleanLine.count > 3 {
                        objectives.append(cleanLine)
                    }
                }
            }
        }
        
        // 3. VALIDATION
        // We need either a strong title signal OR a good list of objectives to consider this a course
        let hasGoodStructure = foundTitle || (objectives.count >= 2)
        
        guard hasGoodStructure else { return nil }
        
        // 4. CONSTRUCT PAYLOAD
        return CoursePayload(
            id: "gen_" + UUID().uuidString.prefix(8),
            title: title,
            topic: topic,
            level: "Adaptive",
            language: "en",
            duration: "\(max(15, objectives.count * 10)) min",
            objectives: Array(objectives.prefix(6))
        )
    }
    
    private static func attemptDecoding(jsonData: Data) -> ParsedResponse? {
        let decoder = JSONDecoder()
        
        // 1. Attempt to decode as standard AICommandResponse
        if let command = try? decoder.decode(AICommandResponse.self, from: jsonData) {
            if command.type != .normalChat {
                Log.ai.info("Parsed AI command: \(command.type.rawValue)")
                return .command(command)
            }
        }
        
        // 2. Fallback: Attempt to decode as raw CoursePayload
        // Sometimes AI returns only the course object without the command wrapper
        if let course = try? decoder.decode(CoursePayload.self, from: jsonData) {
            Log.ai.info("Detected raw CoursePayload, wrapping in OPEN_CLASSROOM command")
            
            let command = AICommandResponse(
                type: .openClassroom,
                payload: AICommandPayload(stackItem: nil, course: course)
            )
            return .command(command)
        }
        
        // 3. Last Resort: Manual mapping for very loose structures
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            if jsonObject["title"] != nil || jsonObject["learning_objectives"] != nil || jsonObject["topic"] != nil {
                Log.ai.info("Detected course-like JSON structure, attempting manual mapping...")
                
                let title = jsonObject["title"] as? String ?? jsonObject["topic"] as? String ?? "Custom Course"
                let topic = jsonObject["topic"] as? String ?? title
                let level = jsonObject["level"] as? String ?? "Beginner"
                let objectives = (jsonObject["objectives"] as? [String]) 
                    ?? (jsonObject["learning_objectives"] as? [String]) 
                    ?? []
                
                let course = CoursePayload(
                    id: jsonObject["course_id"] as? String ?? jsonObject["id"] as? String,
                    title: title,
                    topic: topic,
                    level: level,
                    language: jsonObject["language"] as? String,
                    duration: jsonObject["duration"] as? String ?? jsonObject["estimated_hours"] as? String,
                    objectives: objectives
                )
                
                let command = AICommandResponse(
                    type: .openClassroom,
                    payload: AICommandPayload(stackItem: nil, course: course)
                )
                return .command(command)
            }
        }
        
        return nil
    }
    
    /// Extract JSON object from a string that may contain extra text
    private static func extractJSON(from text: String) -> String? {
        // Find first { and last }
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return nil
        }
        
        let jsonSubstring = text[startIndex...endIndex]
        return String(jsonSubstring)
    }
    
    /// Simple utility to close unclosed braces/brackets in a JSON string
    private static func healJSON(_ jsonString: String) -> String {
        var healed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        var stack: [Character] = []
        var inString = false
        var isEscaped = false
        
        for char in healed {
            if char == "\"" && !isEscaped {
                inString.toggle()
            }
            
            if !inString {
                if char == "{" || char == "[" {
                    stack.append(char)
                } else if char == "}" {
                    if stack.last == "{" { _ = stack.popLast() }
                } else if char == "]" {
                    if stack.last == "[" { _ = stack.popLast() }
                }
            }
            
            if char == "\\" && inString {
                isEscaped.toggle()
            } else {
                isEscaped = false
            }
        }
        
        // If we are stuck in a string, close it
        if inString {
            healed.append("\"")
        }
        
        // Close all unclosed structures
        while let last = stack.popLast() {
            if last == "{" {
                healed.append("}")
            } else if last == "[" {
                healed.append("]")
            }
        }
        
        return healed
    }
    
    /// Extract a simple string field from potentially broken JSON
    private static func extractField(from text: String, field: String) -> String? {
        // Try to match "field": "value"
        let pattern = "\"\\(field)\"\\s*:\\s*\"([^\"]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        guard let valueRange = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[valueRange])
    }
    
    /// Extract an array field from potentially broken JSON
    private static func extractArrayField(from text: String, field: String) -> [String]? {
        // Try to match "field": ["item1", "item2", ...]
        let pattern = "\"\\(field)\"\\s*:\\s*\\[([^\\]]+)\\]"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }
        guard let arrayRange = Range(match.range(at: 1), in: text) else { return nil }
        
        let arrayContent = String(text[arrayRange])
        // Split by comma and clean up quotes
        let items = arrayContent.split(separator: ",").map { item -> String in
            item.trimmingCharacters(in: .whitespacesAndNewlines)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        }
        return items.isEmpty ? nil : items
    }
}
