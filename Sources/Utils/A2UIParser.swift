//
//  A2UIParser.swift
//  Lyo
//
//  Parses raw text responses from AI into structured A2UI widgets
//  Implements Hybrid Payload Parsing pattern
//

import Foundation

struct A2UIParser {
    
    /// Result of parsing an AI response
    struct ParseResult {
        let cleanText: String
        let contentTypes: [MessageContentType]
    }
    
    // MARK: - Main Parsing Function
    
    static func parse(_ text: String) -> ParseResult {
        var cleanText = text
        var contentTypes: [MessageContentType] = []
        
        // 1. Regex to find JSON blocks
        // Matches: ```json { ... } ``` OR just { ... } if it looks like our payload
        let jsonBlockPattern = #"```json\s*(\{[\s\S]*?\})\s*```"#
        let looseJsonPattern = #"(\{[\s\S]*?"type"\s*:\s*"(?:topic_selection|course_roadmap|flashcards|quiz|suggestions)"[\s\S]*?\})"#
        
        // We look for code blocks first as they are most reliable
        contentTypes.append(contentsOf: extractWidgets(from: text, pattern: jsonBlockPattern, isCodeBlock: true, cleanText: &cleanText))
        
        // Then look for loose JSON if we haven't found much, or if the backend sends it raw
        // Note: This is riskier as it might match random JSON code examples. 
        // We validate by checking for specific "type" fields in the decoder.
        contentTypes.append(contentsOf: extractWidgets(from: cleanText, pattern: looseJsonPattern, isCodeBlock: false, cleanText: &cleanText))
        
        // If content types were found, and the text is now empty or just whitespace, 
        // we might want to keep it empty. If it has leftovers, we trimming.
        cleanText = cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If no text remains but we have widgets, ensure we don't have an empty bubble
        if cleanText.isEmpty && !contentTypes.isEmpty {
           // cleanText = "" // Valid state, bubble will show just widgets
        }
        
        // Fallback: If no widgets found, return original text (but cleaned of JSON if it was consumed?)
        // Actually, extractWidgets removes the JSON from cleanText.
        
        // If we found content types, prepend .text type if there is remaining text
        var finalTypes: [MessageContentType] = []
        if !cleanText.isEmpty {
            finalTypes.append(.text)
        }
        finalTypes.append(contentsOf: contentTypes)
        
        return ParseResult(cleanText: cleanText, contentTypes: finalTypes)
    }
    
    // MARK: - Extraction Logic
    
    private static func extractWidgets(from text: String, pattern: String, isCodeBlock: Bool, cleanText: inout String) -> [MessageContentType] {
        var foundTypes: [MessageContentType] = []
        
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        
        let nsString = text as NSString
        let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
        
        // Process matches in reverse order to maintain string indices when replacing
        for match in matches.reversed() {
            let fullRange = match.range
            // Group 1 is the JSON content (without backticks if isCodeBlock)
            let jsonRange = isCodeBlock ? match.range(at: 1) : match.range(at: 0) 
            
            let jsonString = nsString.substring(with: jsonRange)
            
            if let widget = parseWidget(jsonString) {
                foundTypes.insert(widget, at: 0) // Prepend to keep order? Actually reverse loop implies we insert at 0 to keep original order? No, reverse loop means we process last match first. 
                // If we have text: Top [Match1] Middle [Match2] Bottom
                // Loop: Match2 -> Match1
                // Found: [Widget2] -> [Widget1, Widget2]
                
                // Remove from text
                if let range = Range(fullRange, in: cleanText) {
                    cleanText.replaceSubrange(range, with: "")
                }
            }
        }
        
        return foundTypes
    }
    
    // MARK: - Widget Decoding
    
    private static func parseWidget(_ jsonString: String) -> MessageContentType? {
        guard let data = jsonString.data(using: .utf8) else { return nil }
        
        let decoder = JSONDecoder()
        
        do {
            // Decode into a temporary shell to check "type"
            let shell = try decoder.decode(WidgetShell.self, from: data)
            
            switch shell.type {
            case "topic_selection":
                let payload = try decoder.decode(TopicSelectionPayload.self, from: data)
                // Map payload options to TopicOption
                let topics = payload.topics.map { dto in
                    TopicOption(
                        title: dto.title,
                        icon: dto.icon ?? "star.fill",
                        gradientColors: dto.gradientColors
                    )
                }
                return .topicSelection(title: payload.title ?? "Select a Topic", topics: topics)
                
            case "course_roadmap":
                let payload = try decoder.decode(A2UIParserCourseRoadmapPayload.self, from: data)
                let modules = payload.modules.map { dto in
                    CourseModule(
                        title: dto.title,
                        duration: dto.duration,
                        isCompleted: dto.isCompleted ?? false,
                        isLocked: dto.isLocked ?? false
                    )
                }
                return .courseRoadmap(
                    title: payload.title,
                    modules: modules,
                    totalModules: payload.totalModules ?? modules.count,
                    completedModules: payload.completedModules ?? 0
                )
                
            case "flashcards":
                let payload = try decoder.decode(FlashcardsPayload.self, from: data)
                let cards = payload.cards.map { dto in
                    Flashcard(front: dto.front, back: dto.back)
                }
                return .flashcards(title: payload.title ?? "Flashcards", cards: cards)
                
            case "quiz":
                let payload = try decoder.decode(A2UIParserQuizPayload.self, from: data)
                return .quiz(
                    question: payload.question,
                    options: payload.options,
                    correctIndex: payload.correctAnswerIndex ?? 0, // Fallback safely
                    explanation: payload.explanation
                )
                
            case "suggestions":
                let payload = try decoder.decode(SuggestionsPayload.self, from: data)
                return .suggestions(title: payload.title ?? "Suggestions", options: payload.items)
                
            default:
                return nil
            }
        } catch {
            // Not a valid widget JSON, likely just code example
            // print("Failed to decode widget: \(error)")
            return nil
        }
    }
}

// MARK: - Private DTOs

private struct WidgetShell: Codable {
    let type: String
}

private struct TopicSelectionPayload: Codable {
    let title: String?
    let topics: [TopicOptionDTO]
    
    struct TopicOptionDTO: Codable {
        let title: String
        let icon: String?
        let gradientColors: [String]?
    }
}

private struct A2UIParserCourseRoadmapPayload: Codable {
    let title: String
    let modules: [ModuleDTO]
    let totalModules: Int?
    let completedModules: Int?
    
    struct ModuleDTO: Codable {
        let title: String
        let duration: String?
        let isCompleted: Bool?
        let isLocked: Bool?
    }
}

private struct FlashcardsPayload: Codable {
    let title: String?
    let cards: [CardDTO]
    
    struct CardDTO: Codable {
        let front: String
        let back: String
    }
}

private struct A2UIParserQuizPayload: Codable {
    let question: String
    let options: [String]
    let correctAnswerIndex: Int?
    let explanation: String?
    
    enum CodingKeys: String, CodingKey {
        case question, options, explanation
        case correctAnswerIndex = "correct_answer" // Map snake_case or camelCase
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decode(String.self, forKey: .question)
        options = try container.decode([String].self, forKey: .options)
        explanation = try container.decodeIfPresent(String.self, forKey: .explanation)
        
        // Handle flexible key for index
        if let idx = try? container.decode(Int.self, forKey: .correctAnswerIndex) {
            correctAnswerIndex = idx
        } else {
            correctAnswerIndex = 0
        }
    }
}

private struct SuggestionsPayload: Codable {
    let title: String?
    let items: [String]
}
