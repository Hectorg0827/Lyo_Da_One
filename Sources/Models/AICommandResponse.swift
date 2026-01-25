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
    let language: String?  // Optional - backend may not include it
    let duration: String?
    let objectives: [String]
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
        
        // Try to extract JSON (handle cases where AI adds text before/after or markdown blocks)
        guard let jsonString = extractJSON(from: trimmed),
              let jsonData = jsonString.data(using: .utf8) else {
            return .chat(responseText)
        }
        
        // Attempt to decode as AICommandResponse
        do {
            let decoder = JSONDecoder()
            let command = try decoder.decode(AICommandResponse.self, from: jsonData)
            
            // Validate it's a known command type
            if command.type == .normalChat {
                return .chat(responseText)
            }
            
            print("🎯 Parsed AI command: \(command.type.rawValue)")
            return .command(command)
            
        } catch {
            // Not a valid command JSON, treat as chat
            print("⚠️ JSON parsing failed, treating as chat: \(error.localizedDescription)")
            return .chat(responseText)
        }
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
}
