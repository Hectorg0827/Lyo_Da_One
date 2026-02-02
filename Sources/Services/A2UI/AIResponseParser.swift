//
//  AIResponseParser.swift
//  Lyo
//
//  Google A2UI Protocol - AI Response Parsing
//

import Foundation

// MARK: - A2UI Protocol Definitions

/// Parsed response from AI text (local to parser; different from A2UIResponse in A2UIComponent)
struct ParsedA2UIResponse {
    let displayText: String?
    let action: ParsedA2UIAction?
    let isSilentAction: Bool // If true, don't show a chat bubble, just run the action
}

/// Parsed A2UI action from AI response (different from A2UIAction model in A2UIComponent)
enum ParsedA2UIAction {
    case openClassroom(CoursePayload)
    case addToStack(StackItemPayload)
    case navigate(String)
}

// MARK: - A2UI Parser for Google/Gemini Structured Output

@MainActor
final class AIResponseParser {
    static let shared = AIResponseParser()
    
    private init() {}
    
    /// Scans the raw AI text for the Structured JSON Protocol
    func parse(_ rawResponse: String) -> ParsedA2UIResponse {
        let trimmed = rawResponse.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 1. Check for Protocol JSON (defined in BackendAIService system prompt)
        if let jsonBlock = extractJSONBlock(from: trimmed),
           let data = jsonBlock.data(using: .utf8),
           let wrapper = try? JSONDecoder().decode(AIActionWrapper.self, from: data) {
            
            print("🤖 A2UI Protocol: Action Detected -> \(wrapper.type)")
            
            // Check if there was text *before* the JSON
            let textPart = extractTextBefore(original: trimmed, jsonBlock: jsonBlock)
            let action = convertToAction(wrapper)
            
            return ParsedA2UIResponse(
                displayText: textPart.isEmpty ? nil : textPart,
                action: action,
                isSilentAction: textPart.isEmpty
            )
        }
        
        // 2. Fallback: Standard Chat Message
        return ParsedA2UIResponse(displayText: trimmed, action: nil, isSilentAction: false)
    }

    
    // MARK: - Parsing Helpers
    
    // Configured to match the Gemini "OPEN_CLASSROOM" schema
    private struct AIActionWrapper: Codable {
        let type: String
        let payload: AIActionPayload
    }
    
    private struct AIActionPayload: Codable {
        let course: CoursePayload?
        let stack_item: StackItemPayload?
        let destination: String?
        
        enum CodingKeys: String, CodingKey {
            case course
            case stack_item = "stack_item"
            case destination
        }
    }
    
    private func convertToAction(_ wrapper: AIActionWrapper) -> ParsedA2UIAction? {
        switch wrapper.type.uppercased() {
        case "OPEN_CLASSROOM":
            guard let course = wrapper.payload.course else { return nil }
            return .openClassroom(course)
        case "ADD_TO_STACK":
            guard let item = wrapper.payload.stack_item else { return nil }
            return .addToStack(item)
        case "NAVIGATE":
            guard let dest = wrapper.payload.destination else { return nil }
            return .navigate(dest)
        default:
            return nil
        }
    }
    
    private func extractJSONBlock(from text: String) -> String? {
        // Find the first { and the last }
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
              
        return String(text[start...end])
    }
    
    private func extractTextBefore(original: String, jsonBlock: String) -> String {
        return original.replacingOccurrences(of: jsonBlock, with: "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
