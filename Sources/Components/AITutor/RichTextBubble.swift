import SwiftUI

/// A standalone component that renders a single text "Smart Block" within a message.
public struct RichTextBubble: View {
    let content: String
    let isFromUser: Bool
    
    public init(content: String, isFromUser: Bool = false) {
        self.content = content
        self.isFromUser = isFromUser
    }
    
    public var body: some View {
        markdownText(stripEmojis(content))
            .font(DesignTokens.Typography.bodyMedium)
            .fixedSize(horizontal: false, vertical: true)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func stripEmojis(_ text: String) -> String {
        text.unicodeScalars.filter { scalar in
            !(scalar.properties.isEmoji && scalar.properties.isEmojiPresentation)
                && scalar.value != 0xFE0F
        }.map { String($0) }.joined()
    }
    
    private func markdownText(_ content: String) -> Text {
        guard
            let attributed = try? AttributedString(
                markdown: content,
                options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
            )
        else {
            return Text(content).foregroundColor(.white)
        }
        var styled = attributed
        for run in styled.runs {
            if let intent = run.inlinePresentationIntent,
                intent.contains(.stronglyEmphasized)
            {
                styled[run.range].foregroundColor = .white
                styled[run.range].font = .system(size: 17, weight: .bold)
            } else {
                styled[run.range].foregroundColor = .white.opacity(0.9)
            }
        }
        return Text(styled)
    }
}
