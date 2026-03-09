//
//  A2UIPrimitive.swift
//  Lyo
//
//  22 composable primitive types for A2UI v2
//  Replaces the 150+ case A2UIElementType enum
//

import Foundation

// MARK: - A2UI Primitive (v2)

/// 22 composable primitives that replace 150+ legacy A2UIElementType cases.
/// Each primitive uses a `variant` string for sub-type behavior.
enum A2UIPrimitive: String, Codable, CaseIterable, Sendable {
    // ── Content ──
    case text           // variants: plain, heading, markdown, code, quote, callout, latex
    case media          // variants: image, video, audio, animation, icon, diagram
    case divider        // no variants

    // ── Input ──
    case input          // variants: text, number, slider, toggle, select, date, voice, camera, file, drawing
    case button         // variants: primary, secondary, link, icon, destructive

    // ── Layout ──
    case container      // variants: stack, grid, scroll, tabs, carousel, section, accordion
    case card           // variants: default, expandable, stat, feature
    case list           // variants: item, checklist, timeline

    // ── Navigation ──
    case nav            // variants: breadcrumb, tabs, pagination, toolbar

    // ── Learning Domain ──
    case quiz           // variants: mcq, true_false, fill_blank, matching, ordering, code, open_ended
    case quizResult     // variants: score, feedback, progress
    case course         // variants: overview, module, lesson, progress, certificate
    case flashcard      // variants: single, deck, result
    case plan           // variants: overview, session, goal, calendar, milestone
    case tracker        // variants: card, pattern, heatmap, insight
    case assignment     // variants: card, submission, rubric, feedback
    case document       // variants: viewer, summary, annotation

    // ── Engagement ──
    case progress       // variants: bar, xp, streak, level, achievement, leaderboard
    case aiBubble       // variants: message, thinking, suggestion, insight, source
    case social         // variants: profile, comment, feed, group

    // ── System ──
    case alert          // variants: toast, banner, error, empty, info
    case skeleton       // variants: block, list, card, full
}

// MARK: - Primitive Metadata

extension A2UIPrimitive {
    
    /// Valid variants for this primitive. Empty means no variant needed.
    var validVariants: [String] {
        switch self {
        case .text:       return ["plain", "heading", "markdown", "code", "quote", "callout", "latex"]
        case .media:      return ["image", "video", "audio", "animation", "icon", "diagram"]
        case .divider:    return []
        case .input:      return ["text", "number", "slider", "toggle", "select", "date", "voice", "camera", "file", "drawing"]
        case .button:     return ["primary", "secondary", "link", "icon", "destructive"]
        case .container:  return ["stack", "grid", "scroll", "tabs", "carousel", "section", "accordion"]
        case .card:       return ["default", "expandable", "stat", "feature"]
        case .list:       return ["item", "checklist", "timeline"]
        case .nav:        return ["breadcrumb", "tabs", "pagination", "toolbar"]
        case .quiz:       return ["mcq", "true_false", "fill_blank", "matching", "ordering", "code", "open_ended"]
        case .quizResult: return ["score", "feedback", "progress"]
        case .course:     return ["overview", "module", "lesson", "progress", "certificate"]
        case .flashcard:  return ["single", "deck", "result"]
        case .plan:       return ["overview", "session", "goal", "calendar", "milestone"]
        case .tracker:    return ["card", "pattern", "heatmap", "insight"]
        case .assignment: return ["card", "submission", "rubric", "feedback"]
        case .document:   return ["viewer", "summary", "annotation"]
        case .progress:   return ["bar", "xp", "streak", "level", "achievement", "leaderboard"]
        case .aiBubble:   return ["message", "thinking", "suggestion", "insight", "source"]
        case .social:     return ["profile", "comment", "feed", "group"]
        case .alert:      return ["toast", "banner", "error", "empty", "info"]
        case .skeleton:   return ["block", "list", "card", "full"]
        }
    }
    
    /// Default variant when none is specified.
    var defaultVariant: String? {
        switch self {
        case .text:       return "plain"
        case .media:      return "image"
        case .input:      return "text"
        case .button:     return "primary"
        case .container:  return "stack"
        case .card:       return "default"
        case .list:       return "item"
        case .nav:        return "tabs"
        case .quiz:       return "mcq"
        case .quizResult: return "score"
        case .course:     return "overview"
        case .flashcard:  return "single"
        case .plan:       return "overview"
        case .tracker:    return "card"
        case .assignment: return "card"
        case .document:   return "viewer"
        case .progress:   return "bar"
        case .aiBubble:   return "message"
        case .social:     return "profile"
        case .alert:      return "info"
        case .skeleton:   return "block"
        case .divider:    return nil
        }
    }

    /// Whether this primitive is an interactive input.
    var isInteractive: Bool {
        switch self {
        case .input, .button, .quiz, .flashcard: return true
        default: return false
        }
    }

    /// Whether this primitive can contain children.
    var isContainer: Bool {
        switch self {
        case .container, .card, .list, .nav: return true
        default: return false
        }
    }

    /// Whether this primitive supports TTS.
    var supportsTTS: Bool {
        switch self {
        case .text, .quiz, .flashcard, .aiBubble, .alert: return true
        default: return false
        }
    }
    
    /// Semantic category for grouping in tooling/analytics.
    var category: PrimitiveCategory {
        switch self {
        case .text, .media, .divider:                          return .content
        case .input, .button:                                   return .input
        case .container, .card, .list:                          return .layout
        case .nav:                                              return .navigation
        case .quiz, .quizResult, .course, .flashcard,
             .plan, .tracker, .assignment, .document:           return .learning
        case .progress, .aiBubble, .social:                     return .engagement
        case .alert, .skeleton:                                 return .system
        }
    }
}

enum PrimitiveCategory: String, Codable, CaseIterable {
    case content
    case input
    case layout
    case navigation
    case learning
    case engagement
    case system
}
