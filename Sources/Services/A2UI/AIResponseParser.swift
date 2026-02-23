//
//  AIResponseParser.swift
//  Lyo
//
//  Google A2UI Protocol - AI Response Parsing
//

import Foundation
import os

// MARK: - A2UI Protocol Definitions

/// Parsed response from AI text (local to parser; different from A2UIResponse in A2UIComponent)
struct ParsedA2UIResponse {
    let displayText: String?
    let action: ParsedA2UIAction?
    let isSilentAction: Bool // If true, don't show a chat bubble, just run the action
    let uiBlocks: [UIBlock]?
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
            
            Log.a2ui.info("A2UI Protocol: Action Detected -> \(wrapper.type)")
            
            // Check if there was text *before* the JSON
            let textPart = extractTextBefore(original: trimmed, jsonBlock: jsonBlock)
            let isSilent = textPart.isEmpty
            
            // Is it a UI Block or a navigation Action?
            if isGenerativeUIBlock(type: wrapper.type) {
                // Decode the UIBlock directly from the json data. 
                // Because UIBlock handles its own custom Decodable, we can just throw the JSON at it
                var blocks: [UIBlock] = []
                if let block = try? JSONDecoder().decode(UIBlock.self, from: data) {
                    blocks.append(block)
                } else {
                    // Safety net fallback
                    blocks.append(.fallback(errorMessage: "Parser could not decode block type \(wrapper.type)", rawData: jsonBlock))
                }
                
                return ParsedA2UIResponse(
                    displayText: textPart.isEmpty ? nil : textPart,
                    action: nil,
                    isSilentAction: isSilent,
                    uiBlocks: blocks.isEmpty ? nil : blocks
                )
            } else {
                // Standard navigation action
                let action = convertToAction(wrapper)
                return ParsedA2UIResponse(
                    displayText: textPart.isEmpty ? nil : textPart,
                    action: action,
                    isSilentAction: isSilent,
                    uiBlocks: nil
                )
            }
        }
        
        // 2. Fallback: Standard Chat Message
        return ParsedA2UIResponse(displayText: trimmed, action: nil, isSilentAction: false, uiBlocks: nil)
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
        
        // We do not need to strictly define the block payloads here because 
        // the custom UIBlock Decodable handles that. We just ignore them in this wrapper.
        
        enum CodingKeys: String, CodingKey {
            case course
            case stack_item = "stack_item"
            case destination
        }
    }
    
    private func isGenerativeUIBlock(type: String) -> Bool {
        return type.hasSuffix("_BLOCK")
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
