//
//  SelectableTextView.swift
//  Lyo
//
//  UITextView wrapper providing native iOS text selection with custom
//  menu items: Copy, Note, Highlight, Explain This.
//  Supports rendering persisted highlights as yellow background spans.
//

import SwiftUI
import UIKit

// MARK: - Action Enum

/// Actions the user can trigger from the text-selection menu.
enum TextSelectionAction {
    case copy(String)
    case note(selectedText: String, range: NSRange)
    case highlight(selectedText: String, range: NSRange)
    case explain(String)
}

// MARK: - SwiftUI Wrapper

struct SelectableTextView: UIViewRepresentable {
    let content: String
    let messageId: String
    let highlights: [ChatHighlight]
    var onAction: ((TextSelectionAction) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(content: content, messageId: messageId, onAction: onAction)
    }

    func makeUIView(context: Context) -> LyoSelectableUITextView {
        let tv = LyoSelectableUITextView()
        tv.isEditable = false
        tv.isScrollEnabled = false
        tv.backgroundColor = .clear
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        tv.delegate = context.coordinator
        tv.coordinator = context.coordinator
        tv.dataDetectorTypes = .link
        tv.linkTextAttributes = [
            .foregroundColor: UIColor(red: 0.4, green: 0.7, blue: 1.0, alpha: 1),
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]

        // Keep text non-editable but selectable
        tv.isSelectable = true
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        tv.setContentHuggingPriority(.defaultHigh, for: .vertical)

        return tv
    }

    func updateUIView(_ uiView: LyoSelectableUITextView, context: Context) {
        context.coordinator.content = content
        context.coordinator.messageId = messageId
        context.coordinator.onAction = onAction

        let attributed = Self.buildAttributedString(content: content, highlights: highlights)
        uiView.attributedText = attributed
        // Ensure coordinator is up-to-date
        uiView.coordinator = context.coordinator
        uiView.invalidateIntrinsicContentSize()
    }

    // MARK: - Attributed String Builder

    /// Parses simple markdown (bold, italic, inline code) and overlays highlight backgrounds.
    static func buildAttributedString(
        content: String,
        highlights: [ChatHighlight]
    ) -> NSAttributedString {
        let baseFont = UIFont.systemFont(ofSize: 16, weight: .regular)
        let baseColor = UIColor.white.withAlphaComponent(0.9)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4

        let baseAttributes: [NSAttributedString.Key: Any] = [
            .font: baseFont,
            .foregroundColor: baseColor,
            .paragraphStyle: paragraphStyle
        ]

        // Parse simple inline markdown into NSAttributedString
        let result = NSMutableAttributedString(string: content, attributes: baseAttributes)

        // Apply bold (**text** or __text__)
        applyMarkdownPattern(result, pattern: #"\*\*(.+?)\*\*"#, attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: UIColor.white
        ])
        applyMarkdownPattern(result, pattern: #"__(.+?)__"#, attributes: [
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
            .foregroundColor: UIColor.white
        ])

        // Apply italic (*text* or _text_) – avoid matching ** or __
        applyMarkdownPattern(result, pattern: #"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)"#, attributes: [
            .font: UIFont.italicSystemFont(ofSize: 16),
            .foregroundColor: UIColor.white.withAlphaComponent(0.85)
        ])

        // Apply inline code (`text`)
        applyMarkdownPattern(result, pattern: #"`(.+?)`"#, attributes: [
            .font: UIFont.monospacedSystemFont(ofSize: 15, weight: .semibold),
            .foregroundColor: UIColor(red: 0.6, green: 0.85, blue: 1.0, alpha: 1),
            .backgroundColor: UIColor.white.withAlphaComponent(0.12)
        ])

        // Overlay persisted highlights
        for hl in highlights {
            let range = NSRange(location: hl.location, length: hl.length)
            guard range.location + range.length <= result.length else { continue }
            let color = UIColor(hexString: hl.color) ?? UIColor.yellow
            result.addAttribute(.backgroundColor, value: color.withAlphaComponent(0.35), range: range)
        }

        return result
    }

    // MARK: Regex helper

    private static func applyMarkdownPattern(
        _ attrString: NSMutableAttributedString,
        pattern: String,
        attributes: [NSAttributedString.Key: Any]
    ) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
        let fullRange = NSRange(location: 0, length: attrString.length)
        // Process matches in reverse to preserve ranges
        let matches = regex.matches(in: attrString.string, range: fullRange).reversed()
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let innerRange = match.range(at: 1)
            let innerText = (attrString.string as NSString).substring(with: innerRange)

            // Replace full match with inner text, then apply attributes
            attrString.replaceCharacters(in: match.range, with: innerText)
            let newRange = NSRange(location: match.range.location, length: innerText.count)
            attrString.addAttributes(attributes, range: newRange)
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UITextViewDelegate {
        var content: String
        var messageId: String
        var onAction: ((TextSelectionAction) -> Void)?

        init(content: String, messageId: String, onAction: ((TextSelectionAction) -> Void)?) {
            self.content = content
            self.messageId = messageId
            self.onAction = onAction
        }

        // Custom menu actions
        @objc func noteAction(_ sender: Any?) {
            guard let tv = sender as? UITextView,
                  let selectedRange = tv.selectedTextRange,
                  let selectedText = tv.text(in: selectedRange),
                  !selectedText.isEmpty else { return }
            let nsRange = nsRange(from: selectedRange, in: tv)
            onAction?(.note(selectedText: selectedText, range: nsRange))
            tv.selectedTextRange = nil
        }

        @objc func highlightAction(_ sender: Any?) {
            guard let tv = sender as? UITextView,
                  let selectedRange = tv.selectedTextRange,
                  let selectedText = tv.text(in: selectedRange),
                  !selectedText.isEmpty else { return }
            let nsRange = nsRange(from: selectedRange, in: tv)
            onAction?(.highlight(selectedText: selectedText, range: nsRange))
            tv.selectedTextRange = nil
        }

        @objc func explainAction(_ sender: Any?) {
            guard let tv = sender as? UITextView,
                  let selectedRange = tv.selectedTextRange,
                  let selectedText = tv.text(in: selectedRange),
                  !selectedText.isEmpty else { return }
            onAction?(.explain(selectedText))
            tv.selectedTextRange = nil
        }

        private func nsRange(from textRange: UITextRange, in tv: UITextView) -> NSRange {
            let start = tv.offset(from: tv.beginningOfDocument, to: textRange.start)
            let length = tv.offset(from: textRange.start, to: textRange.end)
            return NSRange(location: start, length: length)
        }
    }
}

// MARK: - Custom UITextView with Edit-Menu Overrides

class LyoSelectableUITextView: UITextView {
    weak var coordinator: SelectableTextView.Coordinator?

    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // Allow system copy + our custom actions
        if action == #selector(copy(_:)) { return true }
        if action == #selector(SelectableTextView.Coordinator.noteAction(_:)) { return true }
        if action == #selector(SelectableTextView.Coordinator.highlightAction(_:)) { return true }
        if action == #selector(SelectableTextView.Coordinator.explainAction(_:)) { return true }
        // Block paste, cut, select all, etc.
        return false
    }

    override var canBecomeFirstResponder: Bool { true }

    // Build the edit interaction menu (iOS 16+)
    #if compiler(>=5.7)
    override func buildMenu(with builder: UIMenuBuilder) {
        // Remove standard Edit menu items except Copy
        builder.remove(menu: .edit)
        builder.remove(menu: .format)
        builder.remove(menu: .share)
        builder.remove(menu: .lookup)
        builder.remove(menu: .learn)
        // Deliberately omit autoFill, spelling, etc.

        // Add custom Lyo menu items
        let noteCmd = UIKeyCommand(
            title: "Note",
            image: UIImage(systemName: "note.text"),
            action: #selector(SelectableTextView.Coordinator.noteAction(_:)),
            input: ""
        )
        let highlightCmd = UIKeyCommand(
            title: "Highlight",
            image: UIImage(systemName: "highlighter"),
            action: #selector(SelectableTextView.Coordinator.highlightAction(_:)),
            input: ""
        )
        let explainCmd = UIKeyCommand(
            title: "Explain This",
            image: UIImage(systemName: "sparkles"),
            action: #selector(SelectableTextView.Coordinator.explainAction(_:)),
            input: ""
        )

        let customMenu = UIMenu(
            title: "",
            options: .displayInline,
            children: [noteCmd, highlightCmd, explainCmd]
        )
        builder.insertSibling(customMenu, afterMenu: .standardEdit)

        super.buildMenu(with: builder)
    }
    #endif

    // Forward custom selectors to coordinator
    override func target(forAction action: Selector, withSender sender: Any?) -> Any? {
        if action == #selector(SelectableTextView.Coordinator.noteAction(_:)) ||
           action == #selector(SelectableTextView.Coordinator.highlightAction(_:)) ||
           action == #selector(SelectableTextView.Coordinator.explainAction(_:)) {
            return coordinator
        }
        return super.target(forAction: action, withSender: sender)
    }
}

// MARK: - UIColor hex helper (local)

private extension UIColor {
    convenience init?(hexString: String) {
        var hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6 else { return nil }
        var rgb: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&rgb)
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}
