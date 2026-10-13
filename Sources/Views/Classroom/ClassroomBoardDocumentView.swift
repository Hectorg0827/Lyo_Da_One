import SwiftUI

/// Real teaching material in shared brand surfaces, independent of course names.
struct ClassroomBoardDocumentView: View {
    let document: ClassroomBoardDocument

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(document.blocks.indices, id: \.self) { index in
                let block = document.blocks[index]
                switch block.kind {
                case .text:
                    Text(.init(block.text ?? "")).textSelection(.enabled)
                case .code:
                    VStack(alignment: .leading, spacing: 8) {
                        if let language = block.language, !language.isEmpty {
                            Text(language.uppercased()).font(.caption2.bold()).foregroundStyle(ClassroomTokens.accent)
                        }
                        ScrollView(.horizontal) {
                            Text(block.text ?? "").font(.system(.callout, design: .monospaced)).textSelection(.enabled)
                        }
                    }
                    .padding(12)
                    .background(DesignTokens.Colors.background, in: RoundedRectangle(cornerRadius: 12))
                case .bullets, .steps:
                    let items = block.items ?? []
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(items.indices, id: \.self) { i in
                            HStack(alignment: .top, spacing: 10) {
                                Text(block.kind == .steps ? "\(i + 1)." : "•").bold().foregroundStyle(ClassroomTokens.accent)
                                Text(.init(items[i])).frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                case .table:
                    let headers = block.headers ?? []
                    let rows = block.rows ?? []
                    ScrollView(.horizontal) {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                            GridRow {
                                ForEach(headers.indices, id: \.self) { i in
                                    Text(headers[i]).bold().foregroundStyle(DesignTokens.Colors.textPrimary)
                                }
                            }
                            ForEach(rows.indices, id: \.self) { i in
                                GridRow {
                                    ForEach(rows[i].indices, id: \.self) { j in Text(rows[i][j]) }
                                }
                            }
                        }.padding(12)
                    }
                    .background(DesignTokens.Colors.background, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Lesson table")
                }
            }
        }
        .font(.callout)
        .foregroundStyle(DesignTokens.Colors.textSecondary)
    }
}

struct ClassroomBoardCard: View {
    let component: SDUIComponent
    var compactText = false

    private var role: String { component.resolvedPresentationRole }
    private var label: String {
        switch role {
        case "reference": return "Keep in view"
        case "feedback": return "Feedback"
        case "recovery": return "Lesson paused"
        default: return "Teaching tool"
        }
    }
    private var collapse: Bool {
        role == "details" || (compactText && role == "board" && component.content.count > 240
            && (component.boardDocument?.blocks.allSatisfy { $0.kind == .text } ?? true))
    }
    @ViewBuilder private var material: some View {
        if let visual = component.teachingVisual {
            ClassroomTeachingVisualView(visual: visual) { _ in false }.disabled(true)
        } else if let document = component.boardDocument {
            ClassroomBoardDocumentView(document: document)
        } else {
            Text(.init(component.lessonBlock?.content ?? component.content))
                .font(.callout).foregroundStyle(DesignTokens.Colors.textSecondary).textSelection(.enabled)
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label.uppercased()).font(.caption2.bold()).foregroundStyle(role == "recovery" ? DesignTokens.Colors.warning : ClassroomTokens.accent)
            if let title = component.title, !title.isEmpty { Text(title).font(.headline).foregroundStyle(DesignTokens.Colors.textPrimary) }
            if collapse { DisclosureGroup("Read supporting notes") { material.padding(.top, 8) } }
            else { material }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(role == "reference" ? DesignTokens.Colors.background : DesignTokens.Colors.surface, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(role == "recovery" ? DesignTokens.Colors.warning.opacity(0.4) : ClassroomTokens.glassBorder, lineWidth: 1))
    }
}
