//
//  AICommandResponse.swift
//  Lyo
//
//  AI Command Response Parser - Detects structured commands from AI responses
//

import Foundation

// MARK: - AI Command Response Parser
/// Parses AI responses to detect structured commands (like OPEN_CLASSROOM)

enum AICommandType: String, Codable {
    case openClassroom = "OPEN_CLASSROOM"
    case showQuiz = "SHOW_QUIZ"
    case addToStack = "ADD_TO_STACK"
    case normalChat = "NORMAL_CHAT"
}

struct AICommandResponse: Codable {
    let type: AICommandType
    let payload: AICommandPayload?
}

struct AICommandPayload: Codable {
    let stackItem: StackItemPayload?
    let course: CoursePayload?
    
    enum CodingKeys: String, CodingKey {
        case stackItem = "stack_item"
        case course
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
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        topic = (try? container.decode(String.self, forKey: .topic)) ?? title
        level = (try? container.decode(String.self, forKey: .level)) ?? "Beginner"
        language = try? container.decodeIfPresent(String.self, forKey: .language)
        
        // Handle duration or estimated_hours
        if let d = try? container.decode(String.self, forKey: .duration) {
            duration = d
        } else if let h = try? container.decode(Int.self, forKey: .estimatedHours) {
            duration = "\(h) hours"
        } else if let hString = try? container.decode(String.self, forKey: .estimatedHours) {
            duration = hString
        } else {
            duration = nil
        }
        
        // Handle objectives or learning_objectives
        if let obj = try? container.decode([String].self, forKey: .objectives) {
            objectives = obj
        } else if let obj = try? container.decode([String].self, forKey: .learningObjectives) {
            objectives = obj
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
        
        print("🔍 AICommandParser.parse() - Input length: \(trimmed.count) chars")
        
        // 1. Try standard extraction and decoding
        if let jsonString = extractJSON(from: trimmed),
           let jsonData = jsonString.data(using: .utf8) {
            print("   ✅ Extracted JSON (\(jsonData.count) bytes)")
            if let result = attemptDecoding(jsonData: jsonData) {
                return result
            }
            print("   ⚠️ JSON extracted but decoding failed")
        } else {
            print("   ⚠️ No valid JSON structure found (no closing brace)")
        }
        
        // 2. If it failed, it might be truncated. Try healing the JSON.
        if let firstBrace = trimmed.firstIndex(of: "{") {
            let potentialJson = String(trimmed[firstBrace...])
            print("   🩹 Attempting JSON healing on \(potentialJson.prefix(100))...")
            let healed = healJSON(potentialJson)
            print("   🩹 Healed JSON length: \(healed.count) bytes")
            if let jsonData = healed.data(using: .utf8),
               let result = attemptDecoding(jsonData: jsonData) {
                print("   ✅ Successfully recovered truncated JSON through healing")
                return result
            }
            print("   ❌ Healing failed to produce valid course")
        }
        
        // 3. FALLBACK: Check if text CONTAINS course-like keywords even if JSON is broken
        // This handles cases where the response has descriptive text + broken JSON
        if trimmed.contains("```json") || (trimmed.contains("\"title\"") && trimmed.contains("\"modules\"")) {
            print("   🧠 Detected course-like content markers, attempting extraction...")
            
            // Try to extract title and basic info even from broken JSON
            if let titleMatch = extractField(from: trimmed, field: "title"),
               !titleMatch.isEmpty {
                print("   ✅ Extracted title: \(titleMatch)")
                
                // Create a minimal course payload
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
                print("   ✅ Created course command from partial data")
                return .command(command)
            }
        }
        
        print("   ❌ Treating as plain chat")
        return .chat(responseText)
    }
    
    private static func attemptDecoding(jsonData: Data) -> ParsedResponse? {
        let decoder = JSONDecoder()
        
        // 1. Attempt to decode as standard AICommandResponse
        if let command = try? decoder.decode(AICommandResponse.self, from: jsonData) {
            if command.type != .normalChat {
                print("🎯 Parsed AI command: \(command.type.rawValue)")
                return .command(command)
            }
        }
        
        // 2. Fallback: Attempt to decode as raw CoursePayload
        // Sometimes AI returns only the course object without the command wrapper
        if let course = try? decoder.decode(CoursePayload.self, from: jsonData) {
            print("🚀 Detected raw CoursePayload, wrapping in OPEN_CLASSROOM command")
            
            let command = AICommandResponse(
                type: .openClassroom,
                payload: AICommandPayload(stackItem: nil, course: course)
            )
            return .command(command)
        }
        
        // 3. Last Resort: Manual mapping for very loose structures
        if let jsonObject = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            if jsonObject["title"] != nil || jsonObject["learning_objectives"] != nil || jsonObject["topic"] != nil {
                print("🧠 Detected course-like JSON structure, attempting manual mapping...")
                
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
