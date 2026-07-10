import Foundation
import os

/// Parses JSON or Markdown into LiveLessonBlock - NEVER throws, always returns something usable
struct LiveLessonBlockParser {
    
    // MARK: - Parse from Data
    
    /// Parse JSON data into blocks - guaranteed to return at least one block
    static func parse(from jsonData: Data) -> [LiveLessonBlock] {
        // Try array first (most common)
        if let blocks = try? JSONDecoder().decode([LiveLessonBlock].self, from: jsonData) {
            Log.classroom.info("LiveLessonBlockParser: Decoded \(blocks.count) blocks from array")
            return blocks.isEmpty ? [errorBlock("Empty blocks array")] : blocks
        }
        
        // Try single block
        if let block = try? JSONDecoder().decode(LiveLessonBlock.self, from: jsonData) {
            Log.classroom.info("LiveLessonBlockParser: Decoded single block")
            return [block]
        }
        
        // Try raw JSON dictionary approach
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData)
            
            if let array = json as? [[String: Any]] {
                let blocks = array.enumerated().map { parseFromDictionary($1, index: $0) }
                Log.classroom.info("LiveLessonBlockParser: Parsed \(blocks.count) blocks from JSON array")
                return blocks
            }
            
            if let dict = json as? [String: Any] {
                // Check if this is a wrapper with "blocks" key
                if let blocksArray = dict["blocks"] as? [[String: Any]] {
                    let blocks = blocksArray.enumerated().map { parseFromDictionary($1, index: $0) }
                    Log.classroom.info("LiveLessonBlockParser: Parsed \(blocks.count) blocks from 'blocks' key")
                    return blocks
                }
                
                // Single block
                return [parseFromDictionary(dict, index: 0)]
            }
        } catch {
            Log.classroom.warning("LiveLessonBlockParser: JSON serialization failed: \(error)")
        }
        
        // Ultimate fallback
        Log.classroom.error("LiveLessonBlockParser: All parsing attempts failed")
        return [errorBlock("Failed to parse lesson content")]
    }
    
    // MARK: - Parse from String (Markdown/HTML)
    
    /// Parse markdown or plain text content into blocks
    static func parseFromMarkdown(_ markdown: String) -> [LiveLessonBlock] {
        var blocks: [LiveLessonBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        var currentParagraph: [String] = []
        var inCodeBlock = false
        var codeLanguage: String?
        var codeContent: [String] = []
        
        func flushParagraph() {
            guard !currentParagraph.isEmpty else { return }
            let text = currentParagraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(LiveLessonBlock(
                    id: "para_\(blocks.count)",
                    type: .paragraph,
                    content: text
                ))
            }
            currentParagraph = []
        }
        
        func flushCodeBlock() {
            guard !codeContent.isEmpty else { return }
            blocks.append(LiveLessonBlock(
                id: "code_\(blocks.count)",
                type: .code,
                code: codeContent.joined(separator: "\n"),
                language: codeLanguage
            ))
            codeContent = []
            codeLanguage = nil
        }
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Code block handling
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    inCodeBlock = false
                    flushCodeBlock()
                } else {
                    flushParagraph()
                    inCodeBlock = true
                    codeLanguage = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    if codeLanguage?.isEmpty == true { codeLanguage = nil }
                }
                continue
            }
            
            if inCodeBlock {
                codeContent.append(line)
                continue
            }
            
            // Headers
            if trimmed.hasPrefix("###") {
                flushParagraph()
                let title = trimmed.replacingOccurrences(of: "###", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(LiveLessonBlock(id: "h3_\(blocks.count)", type: .heading, title: title, subtitle: "h3"))
                continue
            }
            if trimmed.hasPrefix("##") {
                flushParagraph()
                let title = trimmed.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(LiveLessonBlock(id: "h2_\(blocks.count)", type: .heading, title: title, subtitle: "h2"))
                continue
            }
            if trimmed.hasPrefix("#") {
                flushParagraph()
                let title = trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(LiveLessonBlock(id: "h1_\(blocks.count)", type: .heading, title: title, subtitle: "h1"))
                continue
            }
            
            // Images: ![alt](url)
            let imagePattern = #"!\[([^\]]*)\]\(([^)]+)\)"#
            if let regex = try? NSRegularExpression(pattern: imagePattern),
               let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) {
                flushParagraph()
                let altRange = Range(match.range(at: 1), in: trimmed)
                let urlRange = Range(match.range(at: 2), in: trimmed)
                let alt = altRange.map { String(trimmed[$0]) }
                let urlString = urlRange.map { String(trimmed[$0]) }
                blocks.append(LiveLessonBlock(
                    id: "img_\(blocks.count)",
                    type: .image,
                    imageURL: urlString.flatMap { URL(string: $0) },
                    altText: alt,
                    caption: alt
                ))
                continue
            }
            
            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushParagraph()
                blocks.append(LiveLessonBlock(id: "div_\(blocks.count)", type: .divider))
                continue
            }
            
            // Empty line = paragraph break
            if trimmed.isEmpty {
                flushParagraph()
                continue
            }
            
            // Regular content
            currentParagraph.append(line)
        }
        
        // Flush remaining
        if inCodeBlock { flushCodeBlock() }
        flushParagraph()
        
        return blocks.isEmpty ? [LiveLessonBlock(id: "empty", type: .paragraph, content: markdown)] : blocks
    }
    
    // MARK: - Dictionary Parser
    
    private static func parseFromDictionary(_ dict: [String: Any], index: Int) -> LiveLessonBlock {
        let id = dict["id"] as? String ?? "block_\(index)"
        _ = dict["type"] as? String ?? "text"
        
        // Use memberwise init fallback or a proxy if Codable init is hard from dict
        // For simplicity, let's just use JSONSerialization to go back to Data then decode
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let block = try? JSONDecoder().decode(LiveLessonBlock.self, from: data) {
            return block
        }
        
        // Absolute fallback construction
        return LiveLessonBlock(id: id, type: .unknown, content: "Block parsing failed")
    }
    
    // MARK: - Error Block
    
    private static func errorBlock(_ message: String) -> LiveLessonBlock {
        LiveLessonBlock(
            id: "error_\(UUID().uuidString.prefix(8))",
            type: .callout,
            title: "Content Error",
            content: message,
            style: BlockStylePayload(
                backgroundColor: "#FEE2E2",
                textColor: "#DC2626",
                borderColor: "#EF4444",
                icon: "exclamationmark.triangle",
                calloutType: "error"
            )
        )
    }
}

// NOTE: LiveLessonBlock memberwise init lives in LiveLessonModels.swift — do NOT duplicate here.
