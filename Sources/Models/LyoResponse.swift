//
//  LyoResponse.swift
//  Lyo
//
//  Unified SSE v2 response envelope.
//  One shape for both fast path (complete) and deep path (streamed).
//

import Foundation

// MARK: - Lyo Response (Unified Contract v2)

/// The single response envelope used by both fast and deep paths.
/// Fast path returns it complete; deep path streams fragments via SSE.
struct LyoResponse: Codable {
    /// Schema version (e.g. "2.0")
    let version: String
    
    /// Unique request identifier for tracing
    let requestId: String
    
    /// Plain-text AI response — always renderable even if `ui` is nil
    var message: String
    
    /// Optional structured UI component tree (v2 primitives)
    let ui: LyoUIComponent?
    
    /// Optional native command trigger (e.g. open_classroom, start_quiz)
    let command: LyoCommand?
    
    /// Context-aware suggestion chips
    let suggestions: [LyoSuggestion]?
    
    /// Conversation session identifier for continuity
    let conversationId: String?
    
    enum CodingKeys: String, CodingKey {
        case version
        case requestId = "request_id"
        case message
        case ui
        case command
        case suggestions
        case conversationId = "conversation_id"
    }
}

// MARK: - Lyo UI Component (v2)

/// Lightweight SSE UI component node.
/// This struct now only extracts text/emotion metadata for the chat pipeline.
struct LyoUIComponent: Codable, Identifiable, Equatable {
    let id: String
    let type: String
    let variant: String?
    
    /// Universal content properties (text, title, image, etc.)
    let content: LyoContentProps?
    
    /// Client-hint styling (client may override)
    let style: LyoStyleProps?
    
    /// Domain-specific typed data (quiz options, course modules, etc.)
    let data: [String: AnyCodableValue]?
    
    /// Recursive children for layout primitives
    let children: [LyoUIComponent]?
    
    /// Analytics / debug metadata
    let meta: LyoMetaProps?
    
    // MARK: - Init
    
    init(
        id: String = UUID().uuidString,
        type: String,
        variant: String? = nil,
        content: LyoContentProps? = nil,
        style: LyoStyleProps? = nil,
        data: [String: AnyCodableValue]? = nil,
        children: [LyoUIComponent]? = nil,
        meta: LyoMetaProps? = nil
    ) {
        self.id = id
        self.type = type
        self.variant = variant
        self.content = content
        self.style = style
        self.data = data
        self.children = children
        self.meta = meta
    }
    
    // MARK: - Custom Decoder
    
    private enum CodingKeys: String, CodingKey {
        case id, type, variant, content, style, data, children, meta
    }
    
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id       = (try? c.decodeIfPresent(String.self, forKey: .id)) ?? UUID().uuidString
        type     = (try? c.decode(String.self, forKey: .type)) ?? "text"
        variant  = try? c.decodeIfPresent(String.self, forKey: .variant)
        content  = try? c.decodeIfPresent(LyoContentProps.self, forKey: .content)
        style    = try? c.decodeIfPresent(LyoStyleProps.self, forKey: .style)
        data     = try? c.decodeIfPresent([String: AnyCodableValue].self, forKey: .data)
        
        children = try? c.decodeIfPresent([LyoUIComponent].self, forKey: .children)
        
        meta       = try? c.decodeIfPresent(LyoMetaProps.self, forKey: .meta)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: LyoUIComponent, rhs: LyoUIComponent) -> Bool {
        lhs.id == rhs.id && lhs.type == rhs.type && lhs.variant == rhs.variant
    }
    
}

// MARK: - Content Props

/// Universal content properties shared across all primitives.
/// Only populate what's relevant — no 180-field god bag.
struct LyoContentProps: Codable, Equatable {
    var text: String?
    var title: String?
    var subtitle: String?
    var body: String?           // markdown content
    var label: String?
    var placeholder: String?
    var hint: String?
    var icon: String?           // SF Symbol name or asset name
    var imageUrl: String?
    var mediaUrl: String?       // video / audio URL
    var altText: String?
    
    enum CodingKeys: String, CodingKey {
        case text, title, subtitle, body, label, placeholder, hint, icon
        case imageUrl = "image_url"
        case mediaUrl = "media_url"
        case altText  = "alt_text"
    }
    
    init(
        text: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        body: String? = nil,
        label: String? = nil,
        placeholder: String? = nil,
        hint: String? = nil,
        icon: String? = nil,
        imageUrl: String? = nil,
        mediaUrl: String? = nil,
        altText: String? = nil
    ) {
        self.text = text
        self.title = title
        self.subtitle = subtitle
        self.body = body
        self.label = label
        self.placeholder = placeholder
        self.hint = hint
        self.icon = icon
        self.imageUrl = imageUrl
        self.mediaUrl = mediaUrl
        self.altText = altText
    }
}

// MARK: - Style Props

/// Client-hint styling. The client CAN override all of these.
struct LyoStyleProps: Codable, Equatable {
    var foreground: String?
    var background: String?
    var spacing: Double?
    var padding: LyoEdgeInsets?
    var radius: Double?
    var axis: String?           // "h" or "v" for containers
    var columns: Int?           // for grid variant
    var fontSize: Double?
    var fontWeight: String?
    var alignment: String?
    var opacity: Double?
    var borderColor: String?
    var borderWidth: Double?
    
    enum CodingKeys: String, CodingKey {
        case foreground, background, spacing, padding, radius, axis, columns
        case fontSize = "font_size"
        case fontWeight = "font_weight"
        case alignment, opacity
        case borderColor = "border_color"
        case borderWidth = "border_width"
    }
    
    init(
        foreground: String? = nil,
        background: String? = nil,
        spacing: Double? = nil,
        padding: LyoEdgeInsets? = nil,
        radius: Double? = nil,
        axis: String? = nil,
        columns: Int? = nil,
        fontSize: Double? = nil,
        fontWeight: String? = nil,
        alignment: String? = nil,
        opacity: Double? = nil,
        borderColor: String? = nil,
        borderWidth: Double? = nil
    ) {
        self.foreground = foreground
        self.background = background
        self.spacing = spacing
        self.padding = padding
        self.radius = radius
        self.axis = axis
        self.columns = columns
        self.fontSize = fontSize
        self.fontWeight = fontWeight
        self.alignment = alignment
        self.opacity = opacity
        self.borderColor = borderColor
        self.borderWidth = borderWidth
    }
}

/// Simple edge insets for v2 style props
struct LyoEdgeInsets: Codable, Equatable {
    let top: Double
    let leading: Double
    let bottom: Double
    let trailing: Double
    
    static func all(_ v: Double) -> LyoEdgeInsets {
        LyoEdgeInsets(top: v, leading: v, bottom: v, trailing: v)
    }
    
    static func symmetric(h: Double = 0, v: Double = 0) -> LyoEdgeInsets {
        LyoEdgeInsets(top: v, leading: h, bottom: v, trailing: h)
    }
    
    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

import SwiftUI

// MARK: - Meta Props

/// Analytics, debug, and accessibility metadata.
struct LyoMetaProps: Codable, Equatable {
    var analyticsId: String?
    var debugLabel: String?
    var version: String?
    var tags: [String]?
    var speakableText: String?      // TTS override
    var accessibilityLabel: String?
    var accessibilityHint: String?
    
    enum CodingKeys: String, CodingKey {
        case analyticsId = "analytics_id"
        case debugLabel = "debug_label"
        case version, tags
        case speakableText = "speakable_text"
        case accessibilityLabel = "accessibility_label"
        case accessibilityHint = "accessibility_hint"
    }
}

// MARK: - Lyo Command

/// Explicit native command trigger — replaces the embedded OPEN_CLASSROOM regex hack.
struct LyoCommand: Codable, Equatable {
    /// Action identifier: "open_classroom", "start_quiz", "show_flashcards", etc.
    let action: String
    
    /// Action-specific payload
    let payload: [String: AnyCodableValue]?
}

// MARK: - Lyo Suggestion

/// Context-aware suggestion chip shown below the response.
struct LyoSuggestion: Codable, Equatable {
    let text: String
    let actionId: String?
    let icon: String?
    
    enum CodingKeys: String, CodingKey {
        case text
        case actionId = "action_id"
        case icon
    }
}

// MARK: - Lyo Stream Assembler

/// Accumulates SSE events into a complete LyoResponse.
/// Deep path streams fragments; this class assembles them.
@MainActor
final class LyoStreamAssembler {
    private(set) var version: String = "2.0"
    private(set) var requestId: String = UUID().uuidString
    private(set) var messageParts: [String] = []
    private(set) var ui: LyoUIComponent?
    private(set) var command: LyoCommand?
    private(set) var suggestions: [LyoSuggestion]?
    private(set) var conversationId: String?
    private(set) var isComplete = false
    
    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()
    
    /// Handle a single SSE event. Returns true when done.
    @discardableResult
    func handleEvent(name: String, data: Data) -> Bool {
        switch name {
        case "start":
            if let meta = try? decoder.decode(StreamStartEvent.self, from: data) {
                version = meta.version ?? "2.0"
                requestId = meta.requestId ?? UUID().uuidString
            }
            
        case "message":
            if let delta = try? decoder.decode(StreamMessageDelta.self, from: data) {
                messageParts.append(delta.delta)
            }
            
        case "ui":
            ui = try? decoder.decode(LyoUIComponent.self, from: data)
            
        case "command":
            command = try? decoder.decode(LyoCommand.self, from: data)
            
        case "suggestions":
            suggestions = try? decoder.decode([LyoSuggestion].self, from: data)
            
        case "done":
            isComplete = true
            return true
            
        default:
            break
        }
        return false
    }
    
    /// Current accumulated message text.
    var currentMessage: String {
        messageParts.joined()
    }
    
    /// Build the final assembled response.
    func build() -> LyoResponse {
        LyoResponse(
            version: version,
            requestId: requestId,
            message: currentMessage,
            ui: ui,
            command: command,
            suggestions: suggestions,
            conversationId: conversationId
        )
    }
    
    /// Reset for reuse.
    func reset() {
        version = "2.0"
        requestId = UUID().uuidString
        messageParts = []
        ui = nil
        command = nil
        suggestions = nil
        conversationId = nil
        isComplete = false
    }
}

// MARK: - Stream Event DTOs

private struct StreamStartEvent: Decodable {
    let version: String?
    let requestId: String?
}

private struct StreamMessageDelta: Decodable {
    let delta: String
}

