//
//  A2UIContentSynthesizer.swift
//  Lyo
//
//  The "Prompt-First" bridge: converts raw AI text (markdown/structured)
//  into A2UI component trees for rich rendering.
//
//  This is the middleware that bridges the gap between:
//  - LLM output (markdown text, bullet lists, code blocks)
//  - A2UI rendering (structured component trees)
//
//  Philosophy: Let the LLM speak naturally in markdown, then synthesize
//  the rich UI client-side. This avoids asking the LLM to generate JSON
//  component trees directly (fragile, slow, expensive).
//

import Foundation
import os

// MARK: - Content Block (Intermediate Representation)

/// An intermediate parsed block from markdown, before A2UI conversion
enum SynthesizedBlock: Equatable {
    case heading(level: Int, text: String)
    case paragraph(text: String)
    case bulletList(items: [String])
    case numberedList(items: [String])
    case codeBlock(language: String?, code: String)
    case blockquote(text: String)
    case divider
    case keyValue(key: String, value: String)
    case boldEmphasis(text: String)
}

// MARK: - A2UI Content Synthesizer

@MainActor
final class A2UIContentSynthesizer {
    static let shared = A2UIContentSynthesizer()
    
    private init() {}
    
    // MARK: - Main Entry Point
    
    /// Convert raw markdown text to an A2UI component tree
    func synthesize(markdown: String, context: SynthesisContext = .general) -> A2UIComponent {
        // 1. Parse markdown into intermediate blocks
        let blocks = parseMarkdown(markdown)
        
        // 2. Convert blocks to A2UI components based on context
        let children = blocks.compactMap { blockToComponent($0, context: context) }
        
        // 3. Wrap in a root VStack
        return A2UIComponent(
            id: "synth_\(UUID().uuidString.prefix(8))",
            type: .container,
            props: A2UIProps(spacing: 12, axis: "vertical"),
            children: children.isEmpty ? nil : children
        )
    }
    
    /// Convert agent blocks to A2UI components with agent-aware styling
    func synthesizeAgentBlocks(_ blocks: [AgentBlock]) -> A2UIComponent {
        let children = blocks.compactMap { agentBlockToComponent($0) }
        
        return A2UIComponent(
            id: "agent_response_\(UUID().uuidString.prefix(8))",
            type: .container,
            props: A2UIProps(spacing: 16, axis: "vertical"),
            children: children.isEmpty ? nil : children
        )
    }
    
    // MARK: - Markdown Parser
    
    /// Parse raw markdown text into structured blocks
    func parseMarkdown(_ text: String) -> [SynthesizedBlock] {
        var blocks: [SynthesizedBlock] = []
        let lines = text.components(separatedBy: "\n")
        var i = 0
        var currentBullets: [String] = []
        var currentNumbered: [String] = []
        var inCodeBlock = false
        var codeLanguage: String?
        var codeLines: [String] = []
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Code block handling
            if trimmed.hasPrefix("```") {
                if inCodeBlock {
                    // End code block
                    blocks.append(.codeBlock(language: codeLanguage, code: codeLines.joined(separator: "\n")))
                    codeLines = []
                    codeLanguage = nil
                    inCodeBlock = false
                } else {
                    // Flush any pending lists
                    flushBullets(&currentBullets, into: &blocks)
                    flushNumbered(&currentNumbered, into: &blocks)
                    
                    // Start code block
                    inCodeBlock = true
                    let langPart = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLanguage = langPart.isEmpty ? nil : langPart
                }
                i += 1
                continue
            }
            
            if inCodeBlock {
                codeLines.append(line)
                i += 1
                continue
            }
            
            // Empty line — flush pending lists
            if trimmed.isEmpty {
                flushBullets(&currentBullets, into: &blocks)
                flushNumbered(&currentNumbered, into: &blocks)
                i += 1
                continue
            }
            
            // Heading
            if let headingMatch = parseHeading(trimmed) {
                flushBullets(&currentBullets, into: &blocks)
                flushNumbered(&currentNumbered, into: &blocks)
                blocks.append(.heading(level: headingMatch.level, text: headingMatch.text))
                i += 1
                continue
            }
            
            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                flushBullets(&currentBullets, into: &blocks)
                flushNumbered(&currentNumbered, into: &blocks)
                blocks.append(.divider)
                i += 1
                continue
            }
            
            // Blockquote
            if trimmed.hasPrefix(">") {
                flushBullets(&currentBullets, into: &blocks)
                flushNumbered(&currentNumbered, into: &blocks)
                let quoteText = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
                blocks.append(.blockquote(text: quoteText))
                i += 1
                continue
            }
            
            // Bullet list item
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") || trimmed.hasPrefix("• ") {
                flushNumbered(&currentNumbered, into: &blocks)
                let itemText = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                currentBullets.append(itemText)
                i += 1
                continue
            }
            
            // Numbered list item
            if let numMatch = parseNumberedItem(trimmed) {
                flushBullets(&currentBullets, into: &blocks)
                currentNumbered.append(numMatch)
                i += 1
                continue
            }
            
            // Key-Value (bold key: value)
            if let kvMatch = parseKeyValue(trimmed) {
                flushBullets(&currentBullets, into: &blocks)
                flushNumbered(&currentNumbered, into: &blocks)
                blocks.append(.keyValue(key: kvMatch.key, value: kvMatch.value))
                i += 1
                continue
            }
            
            // Default: paragraph
            flushBullets(&currentBullets, into: &blocks)
            flushNumbered(&currentNumbered, into: &blocks)
            blocks.append(.paragraph(text: trimmed))
            i += 1
        }
        
        // Flush any remaining
        flushBullets(&currentBullets, into: &blocks)
        flushNumbered(&currentNumbered, into: &blocks)
        
        if inCodeBlock && !codeLines.isEmpty {
            blocks.append(.codeBlock(language: codeLanguage, code: codeLines.joined(separator: "\n")))
        }
        
        return blocks
    }
    
    // MARK: - Line Parsers
    
    private func parseHeading(_ line: String) -> (level: Int, text: String)? {
        var level = 0
        for char in line {
            if char == "#" { level += 1 }
            else { break }
        }
        guard level > 0, level <= 6 else { return nil }
        let text = String(line.dropFirst(level)).trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }
        return (level, text)
    }
    
    private func parseNumberedItem(_ line: String) -> String? {
        // Match "1." or "1)" patterns
        let pattern = #"^\d+[.)]\s+(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges > 1,
              let textRange = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[textRange])
    }
    
    private func parseKeyValue(_ line: String) -> (key: String, value: String)? {
        // Match **Key**: Value or **Key** - Value
        let pattern = #"^\*\*(.+?)\*\*\s*[:–-]\s*(.+)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges > 2,
              let keyRange = Range(match.range(at: 1), in: line),
              let valueRange = Range(match.range(at: 2), in: line) else {
            return nil
        }
        return (String(line[keyRange]), String(line[valueRange]))
    }
    
    private func flushBullets(_ bullets: inout [String], into blocks: inout [SynthesizedBlock]) {
        if !bullets.isEmpty {
            blocks.append(.bulletList(items: bullets))
            bullets = []
        }
    }
    
    private func flushNumbered(_ numbered: inout [String], into blocks: inout [SynthesizedBlock]) {
        if !numbered.isEmpty {
            blocks.append(.numberedList(items: numbered))
            numbered = []
        }
    }
    
    // MARK: - Block → A2UI Component
    
    private func blockToComponent(_ block: SynthesizedBlock, context: SynthesisContext) -> A2UIComponent? {
        switch block {
        case .heading(let level, let text):
            let fontSizes: [Int: Double] = [1: 28, 2: 24, 3: 20, 4: 18, 5: 16, 6: 14]
            return A2UIComponent(
                id: "heading_\(UUID().uuidString.prefix(6))",
                type: .heading,
                props: A2UIProps(
                    text: text,
                    fontSize: fontSizes[level] ?? 20,
                    fontWeight: level <= 2 ? "bold" : "semibold"
                )
            )
            
        case .paragraph(let text):
            return A2UIComponent(
                id: "para_\(UUID().uuidString.prefix(6))",
                type: .text,
                props: A2UIProps(
                    text: text,
                    fontSize: 16,
                    lineHeight: 1.5
                )
            )
            
        case .bulletList(let items):
            let listChildren = items.map { item in
                A2UIComponent(
                    id: "bullet_\(UUID().uuidString.prefix(6))",
                    type: .text,
                    props: A2UIProps(text: "• \(item)", fontSize: 15)
                )
            }
            return A2UIComponent(
                id: "list_\(UUID().uuidString.prefix(6))",
                type: .container,
                props: A2UIProps(spacing: 6, axis: "vertical", padding: A2UIEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 0)),
                children: listChildren
            )
            
        case .numberedList(let items):
            let listChildren = items.enumerated().map { index, item in
                A2UIComponent(
                    id: "num_\(UUID().uuidString.prefix(6))",
                    type: .text,
                    props: A2UIProps(text: "\(index + 1). \(item)", fontSize: 15)
                )
            }
            return A2UIComponent(
                id: "numlist_\(UUID().uuidString.prefix(6))",
                type: .container,
                props: A2UIProps(spacing: 6, axis: "vertical", padding: A2UIEdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 0)),
                children: listChildren
            )
            
        case .codeBlock(let language, let code):
            return A2UIComponent(
                id: "code_\(UUID().uuidString.prefix(6))",
                type: .codeBlock,
                props: A2UIProps(
                    text: language ?? "code",
                    foregroundColor: "#CDD6F4",
                    backgroundColor: "#1E1E2E",
                    borderRadius: 12,
                    code: code
                )
            )
            
        case .blockquote(let text):
            return A2UIComponent(
                id: "quote_\(UUID().uuidString.prefix(6))",
                type: .text,
                props: A2UIProps(
                    text: text,
                    padding: A2UIEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 8),
                    fontSize: 15,
                    foregroundColor: "#8B949E",
                    borderColor: "#3B82F6",
                    borderWidth: 3
                )
            )
            
        case .divider:
            return A2UIComponent(
                id: "divider_\(UUID().uuidString.prefix(6))",
                type: .divider,
                props: A2UIProps()
            )
            
        case .keyValue(let key, let value):
            return A2UIComponent(
                id: "kv_\(UUID().uuidString.prefix(6))",
                type: .container,
                props: A2UIProps(spacing: 4, axis: "horizontal"),
                children: [
                    A2UIComponent(
                        id: "kvk_\(UUID().uuidString.prefix(6))",
                        type: .text,
                        props: A2UIProps(text: key, fontSize: 15, fontWeight: "bold")
                    ),
                    A2UIComponent(
                        id: "kvv_\(UUID().uuidString.prefix(6))",
                        type: .text,
                        props: A2UIProps(text: value, fontSize: 15)
                    )
                ]
            )
            
        case .boldEmphasis(let text):
            return A2UIComponent(
                id: "bold_\(UUID().uuidString.prefix(6))",
                type: .text,
                props: A2UIProps(text: text, fontSize: 16, fontWeight: "bold")
            )
        }
    }
    
    // MARK: - Agent Block → A2UI Component
    
    private func agentBlockToComponent(_ block: AgentBlock) -> A2UIComponent? {
        let content = block.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return nil }
        
        // Parse the content markdown first
        let innerBlocks = parseMarkdown(content)
        let innerComponents = innerBlocks.compactMap { blockToComponent($0, context: agentContext(for: block.agent)) }
        
        // Wrap with agent-specific card styling
        let accentColor = agentAccentColor(for: block.agent)
        
        return A2UIComponent(
            id: "agent_\(block.agent.rawValue)_\(UUID().uuidString.prefix(6))",
            type: .card,
            props: A2UIProps(
                spacing: 8,
                axis: "vertical",
                padding: A2UIEdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14),
                borderColor: accentColor,
                borderWidth: 1,
                borderRadius: 16
            ),
            children: innerComponents.isEmpty ? nil : innerComponents,
            metadata: A2UIMetadata(
                analyticsId: nil,
                testId: nil,
                debugLabel: "\(block.agent.rawValue):\(block.blockType.rawValue)",
                version: nil,
                createdAt: block.timestamp,
                expiresAt: nil,
                priority: nil,
                tags: [block.agent.rawValue, block.blockType.rawValue]
            )
        )
    }
    
    // MARK: - Agent Styling
    
    private func agentAccentColor(for agent: AgentRole) -> String {
        switch agent {
        case .tutor:         return "#3B82F6"  // Blue
        case .sentiment:     return "#EC4899"  // Pink
        case .quiz:          return "#10B981"  // Green
        case .content:       return "#8B5CF6"  // Purple
        case .metaCognition: return "#F59E0B"  // Amber
        case .orchestrator:  return "#6B7280"  // Gray
        }
    }
    
    private func agentContext(for agent: AgentRole) -> SynthesisContext {
        switch agent {
        case .tutor:         return .lesson
        case .quiz:          return .quiz
        case .content:       return .reference
        default:             return .general
        }
    }
}

// MARK: - Synthesis Context

/// Hints for how to style/interpret content during synthesis
enum SynthesisContext {
    case general      // Default chat response
    case lesson       // Inside a lesson/classroom
    case quiz         // Quiz content
    case reference    // Reference material
    case studyPlan    // Study plan generation
}
