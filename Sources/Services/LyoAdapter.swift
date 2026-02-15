import Foundation
import os

// MARK: - Lyo Core Protocol
// These match the Pydantic schemas in your System Prompt perfectly.

// MARK: - Lyo Core Protocol
// See LyoModels.swift for Pydantic schema mappings.

// MARK: - The Adapter

class LyoAdapter {
    
    // MARK: - Content Renderer
    
    /// Converts a semantic LyoBlock into a displayable A2UI Content Item
    static func render(_ block: LyoBlock) -> A2UIContent {
        // 🛡️ Safety Layer: Wrap rendering in do-catch to prevent crashes
        do {
            return try unsafeRender(block)
        } catch {
            Log.net.warning("LyoAdapter: Failed to render block \(block.id) of type \(String(describing: block.type)). Error: \(error)")
            // Fallback: Render as simple text so the user still sees the data
            return A2UIContent(
                type: .text,
                courseRoadmap: nil,
                quiz: nil,
                title: "Content Note",
                topics: nil,
                cards: nil,
                modules: nil,
                totalModules: nil,
                completedModules: nil,
                suggestions: nil,
                cinematic: nil,
                layout: .standard
            )
        }
    }
    
    private static func unsafeRender(_ block: LyoBlock) throws -> A2UIContent {
        
        // 1. Cinematic / Hero overrides (The "Superior Experience")
        if block.presentationHint == .cinematic || block.role == .hook {
            return renderCinematic(block)
        }
        
        // Determine Generative Layout
        let layout: A2UILayout
        switch block.presentationHint {
        case .hero: layout = .hero
        case .cinematic: layout = .overlay
        case .inline: layout = .standard
        case .none: layout = .standard
        }
        
        // 2. Standard Mapping
        switch block.type {
        case .concept:
            let payload = try block.content.decode(ConceptPayload.self)
            
            // Map Concept -> Flashcard if it has a key takeaway (Hero behavior)
            if block.presentationHint == .hero, let takeaway = payload.keyTakeaway {
                return A2UIContent(
                    type: .flashcards,
                    courseRoadmap: nil,
                    quiz: nil,
                    title: nil,
                    topics: nil,
                    cards: [A2UIFlashcard(front: takeaway, back: payload.markdown, hint: nil)],
                    modules: nil,
                    totalModules: nil,
                    completedModules: nil,
                    suggestions: nil,
                    cinematic: nil,
                    layout: layout
                )
            }
            
            // Standard Text
            return A2UIContent(
                type: .text,
                courseRoadmap: nil,
                quiz: nil,
                title: payload.keyTakeaway ?? "Note",
                topics: nil,
                cards: nil,
                modules: nil,
                totalModules: nil,
                completedModules: nil,
                suggestions: nil,
                cinematic: nil,
                layout: layout
            )
            
        case .quiz:
            let payload = try block.content.decode(QuizPayload.self)
            
            let a2Question = A2UIQuestion(
                question: payload.question,
                options: payload.options.map { $0.text },
                correctAnswer: payload.options.first(where: { $0.id == payload.correctOptionId })?.text ?? ""
            )
            
            let a2Quiz = A2UIQuiz(title: "Quick Check", questions: [a2Question])
            
            return A2UIContent(
                type: .quiz,
                courseRoadmap: nil,
                quiz: a2Quiz,
                title: nil,
                topics: nil,
                cards: nil,
                modules: nil,
                totalModules: nil,
                completedModules: nil,
                suggestions: nil,
                cinematic: nil,
                layout: layout
            )
            
        case .image, .video:
            // For now, treat media as cinematic cards to ensure they look great
            return renderCinematic(block)
            
        default:
            return A2UIContent(
                type: .processing,
                courseRoadmap: nil,
                quiz: nil,
                title: nil,
                topics: nil,
                cards: nil,
                modules: nil,
                totalModules: nil,
                completedModules: nil,
                suggestions: nil,
                cinematic: nil,
                layout: layout
            )
        }
    }
    
    // MARK: - AI Director (Mood -> Experience)
    
    private static func renderCinematic(_ block: LyoBlock) -> A2UIContent {
        // Map Lyo metadata to A2UI Cinematic payload
        let title = (try? block.content.decode(ConceptPayload.self).keyTakeaway) ?? "Immersive Moment"
        
        // 🎬 AI Director: Mood Mapping
        let mood = block.mood ?? "neutral"
        var audioTrack: String?
        var hapticPattern: String?
        
        switch mood {
        case "suspense":
            audioTrack = "ambient_suspense"
            hapticPattern = "medium"
        case "celebration":
            audioTrack = "upbeat_success"
            hapticPattern = "success"
        case "reflection":
            audioTrack = "soft_piano"
            hapticPattern = "soft"
        case "urgent":
            audioTrack = "ticking_clock"
            hapticPattern = "warning"
        default:
            audioTrack = nil
            hapticPattern = nil
        }
        
        let cinematicData = A2UICinematic(
            title: title,
            subtitle: "Tap to explore",
            mood: mood,
            videoUrl: nil, // In a real app, map block.id to a generated video URL
            audioTrack: audioTrack,
            hapticPattern: hapticPattern
        )
        
        return A2UIContent(
            type: .cinematic,
            courseRoadmap: nil,
            quiz: nil,
            title: nil,
            topics: nil,
            cards: nil,
            modules: nil,
            totalModules: nil,
            completedModules: nil,
            suggestions: nil,
            cinematic: cinematicData,
            layout: .overlay
        )
    }
}

// MARK: - Stream Processor

class LyoStreamProcessor {
    private var buffer: String = ""
    private var openBraces = 0
    private var lastValidIndex: String.Index?
    
    // Heuristic Streaming State
    var onSentenceReady: ((String) -> Void)?
    private var processedMarkdownLength = 0
    private var pendingSentenceBuffer = ""
    
    /// Accepts a chunk of text from the stream and attempts to parse valid LyoBlocks from it.
    /// Used for "Stream-Rendering" to animate UI elements as they are generated.
    func append(_ chunk: String) -> [A2UIContent] {
        buffer += chunk
        
        // ⚡️ Heuristic: Stream sentences for TTS before JSON is complete
        extractAndStreamSentences(from: buffer)
        
        var results: [A2UIContent] = []
        
        // Simple "Bracket Counter" parser to find top-level JSON objects
        // This assumes the stream creates discrete JSON objects one after another,
        // or a list that we peel items off of.
        // NOTE: This is a simplified parser for demonstration.
        
        var currentIndex = buffer.startIndex
        
        while currentIndex < buffer.endIndex {
            let char = buffer[currentIndex]
            
            if char == "{" {
                if openBraces == 0 {
                    lastValidIndex = currentIndex // Start of potential object
                }
                openBraces += 1
            } else if char == "}" {
                openBraces -= 1
                
                if openBraces == 0, let start = lastValidIndex {
                    // Potential end of object
                    let end = buffer.index(after: currentIndex)
                    let jsonString = String(buffer[start..<end])
                    
                    if let block = tryParseBlock(jsonString) {
                        results.append(LyoAdapter.render(block))
                        
                        // Remove processed part from buffer to prevent re-scanning
                        // We slice off everything up to 'end'
                        buffer.removeSubrange(buffer.startIndex..<end)
                        
                        // Reset streaming state for next block
                        processedMarkdownLength = 0
                        pendingSentenceBuffer = ""
                        
                        // Reset indices for the new buffer
                        currentIndex = buffer.startIndex
                        lastValidIndex = nil
                        continue // Restart loop with shortened buffer
                    }
                    lastValidIndex = nil
                }
            }
            
            // Advance index if we didn't just reset
            if currentIndex < buffer.endIndex {
                currentIndex = buffer.index(after: currentIndex)
            }
        }
        
        return results
    }
    
    private func tryParseBlock(_ json: String) -> LyoBlock? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LyoBlock.self, from: data)
    }
    
    // MARK: - Heuristic Extraction
    
    private func extractAndStreamSentences(from buffer: String) {
        // Look for "markdown": " pattern
        guard let markdownRange = buffer.range(of: "\"markdown\":\\s*\"", options: .regularExpression) else { return }
        
        let contentStart = markdownRange.upperBound
        
        // We only care about content AFTER the start marker
        if contentStart >= buffer.endIndex { return }
        
        let contentSubstring = buffer[contentStart...]
        
        // Find the text we haven't processed yet
        // We need to be careful about escaped quotes ending the string
        var currentText = ""
        var isEscaped = false
        
        // Scan until we hit an unescaped quote (end of string) or end of buffer
        for char in contentSubstring {
            if isEscaped {
                currentText.append(char)
                isEscaped = false
            } else if char == "\\" {
                isEscaped = true
            } else if char == "\"" {
                // End of JSON string - stop processing
                break
            } else {
                currentText.append(char)
            }
        }
        
        // Only look at *new* content
        if currentText.count > processedMarkdownLength {
            let newText = String(currentText.dropFirst(processedMarkdownLength))
            pendingSentenceBuffer += newText
            processedMarkdownLength = currentText.count
            
            processPendingBuffer()
        }
    }
    
    private func processPendingBuffer() {
        // Simple sentence splitter on . ? ! followed by space or newline
        // Using Regex for robustness: ([.?!])\s
        
        let sentencePattern = "([.?!])\\s+"
        
        while let range = pendingSentenceBuffer.range(of: sentencePattern, options: .regularExpression) {
            let sentenceEnd = range.upperBound
            let fullSentence = String(pendingSentenceBuffer[..<sentenceEnd])
            
            // Emit!
            let cleaned = fullSentence
                .replacingOccurrences(of: "\\n", with: " ")
                .replacingOccurrences(of: "\\\"", with: "\"")
            
            if !cleaned.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                 onSentenceReady?(cleaned)
            }
            
            // Remove from buffer
            pendingSentenceBuffer.removeSubrange(..<sentenceEnd)
        }
    }
}

// MARK: - Helper: AnyCodable
// See AnyCodable.swift for implementation.
