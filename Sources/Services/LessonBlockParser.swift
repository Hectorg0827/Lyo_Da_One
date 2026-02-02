import Foundation

/// Parses JSON or Markdown into LessonBlock - NEVER throws, always returns something usable
struct LessonBlockParser {
    
    // MARK: - Parse from Data
    
    /// Parse JSON data into blocks - guaranteed to return at least one block
    static func parse(from jsonData: Data) -> [LessonBlock] {
        // Try array first (most common)
        if let blocks = try? JSONDecoder().decode([LessonBlock].self, from: jsonData) {
            print("✅ LessonBlockParser: Decoded \(blocks.count) blocks from array")
            return blocks.isEmpty ? [errorBlock("Empty blocks array")] : blocks
        }
        
        // Try single block
        if let block = try? JSONDecoder().decode(LessonBlock.self, from: jsonData) {
            print("✅ LessonBlockParser: Decoded single block")
            return [block]
        }
        
        // Try raw JSON dictionary approach
        do {
            let json = try JSONSerialization.jsonObject(with: jsonData)
            
            if let array = json as? [[String: Any]] {
                let blocks = array.enumerated().map { parseFromDictionary($1, index: $0) }
                print("✅ LessonBlockParser: Parsed \(blocks.count) blocks from JSON array")
                return blocks
            }
            
            if let dict = json as? [String: Any] {
                // Check if this is a wrapper with "blocks" key
                if let blocksArray = dict["blocks"] as? [[String: Any]] {
                    let blocks = blocksArray.enumerated().map { parseFromDictionary($1, index: $0) }
                    print("✅ LessonBlockParser: Parsed \(blocks.count) blocks from 'blocks' key")
                    return blocks
                }
                
                // Single block
                return [parseFromDictionary(dict, index: 0)]
            }
        } catch {
            print("⚠️ LessonBlockParser: JSON serialization failed: \(error)")
        }
        
        // Ultimate fallback
        print("❌ LessonBlockParser: All parsing attempts failed")
        return [errorBlock("Failed to parse lesson content")]
    }
    
    // MARK: - Parse from String (Markdown/HTML)
    
    /// Parse markdown or plain text content into blocks
    static func parseFromMarkdown(_ markdown: String) -> [LessonBlock] {
        var blocks: [LessonBlock] = []
        let lines = markdown.components(separatedBy: "\n")
        var currentParagraph: [String] = []
        var inCodeBlock = false
        var codeLanguage: String?
        var codeContent: [String] = []
        
        func flushParagraph() {
            guard !currentParagraph.isEmpty else { return }
            let text = currentParagraph.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(LessonBlock(
                    id: "para_\(blocks.count)",
                    type: .paragraph,
                    content: text
                ))
            }
            currentParagraph = []
        }
        
        func flushCodeBlock() {
            guard !codeContent.isEmpty else { return }
            blocks.append(LessonBlock(
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
                blocks.append(LessonBlock(id: "h3_\(blocks.count)", type: .heading, title: title, subtitle: "h3"))
                continue
            }
            if trimmed.hasPrefix("##") {
                flushParagraph()
                let title = trimmed.replacingOccurrences(of: "##", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(LessonBlock(id: "h2_\(blocks.count)", type: .heading, title: title, subtitle: "h2"))
                continue
            }
            if trimmed.hasPrefix("#") {
                flushParagraph()
                let title = trimmed.replacingOccurrences(of: "#", with: "").trimmingCharacters(in: .whitespaces)
                blocks.append(LessonBlock(id: "h1_\(blocks.count)", type: .heading, title: title, subtitle: "h1"))
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
                blocks.append(LessonBlock(
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
                blocks.append(LessonBlock(id: "div_\(blocks.count)", type: .divider))
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
        
        return blocks.isEmpty ? [LessonBlock(id: "empty", type: .paragraph, content: markdown)] : blocks
    }
    
    // MARK: - Dictionary Parser
    
    private static func parseFromDictionary(_ dict: [String: Any], index: Int) -> LessonBlock {
        let id = dict["id"] as? String ?? "block_\(index)"
        let typeString = dict["type"] as? String ?? "text"
        
        // Use memberwise init fallback or a proxy if Codable init is hard from dict
        // For simplicity, let's just use JSONSerialization to go back to Data then decode
        if let data = try? JSONSerialization.data(withJSONObject: dict),
           let block = try? JSONDecoder().decode(LessonBlock.self, from: data) {
            return block
        }
        
        // Absolute fallback construction
        return LessonBlock(id: id, type: .unknown, content: "Block parsing failed")
    }
    
    // MARK: - Error Block
    
    private static func errorBlock(_ message: String) -> LessonBlock {
        LessonBlock(
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

// Helper extension for memberwise init during manual construction
extension LessonBlock {
    init(
        id: String = UUID().uuidString,
        type: LessonBlockType,
        title: String? = nil,
        content: String? = nil,
        subtitle: String? = nil,
        imageURL: URL? = nil,
        videoURL: URL? = nil,
        audioURL: URL? = nil,
        altText: String? = nil,
        caption: String? = nil,
        code: String? = nil,
        language: String? = nil,
        isRunnable: Bool? = nil,
        question: String? = nil,
        options: [String]? = nil,
        correctIndex: Int? = nil,
        correctAnswer: String? = nil,
        explanation: String? = nil,
        hint: String? = nil,
        chartType: String? = nil,
        chartData: ChartDataPayload? = nil,
        latex: String? = nil,
        mermaid: String? = nil,
        front: String? = nil,
        back: String? = nil,
        cards: [FlashcardPayload]? = nil,
        headers: [String]? = nil,
        rows: [[String]]? = nil,
        style: BlockStylePayload? = nil,
        duration: Int? = nil,
        difficulty: String? = nil,
        tags: [String]? = nil
    ) {
        self.id = id
        self.type = type
        self.title = title
        self.content = content
        self.subtitle = subtitle
        self.imageURL = imageURL
        self.videoURL = videoURL
        self.audioURL = audioURL
        self.altText = altText
        self.caption = caption
        self.code = code
        self.language = language
        self.isRunnable = isRunnable
        self.question = question
        self.options = options
        self.correctIndex = correctIndex
        self.correctAnswer = correctAnswer
        self.explanation = explanation
        self.hint = hint
        self.chartType = chartType
        self.chartData = chartData
        self.latex = latex
        self.mermaid = mermaid
        self.front = front
        self.back = back
        self.cards = cards
        self.headers = headers
        self.rows = rows
        self.style = style
        self.duration = duration
        self.difficulty = difficulty
        self.tags = tags
    }
}
