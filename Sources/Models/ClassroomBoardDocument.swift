import Foundation

/// A bounded, subject-independent display document. No execution or evidence fields.
struct ClassroomBoardDocument: Codable, Equatable {
    let version: Int
    let blocks: [Block]

    struct Block: Codable, Equatable {
        enum Kind: String, Codable { case text, bullets, steps, code, table }
        let kind: Kind
        let text: String?
        let language: String?
        let items: [String]?
        let headers: [String]?
        let rows: [[String]]?

        private func bounded(_ text: String) -> Bool {
            !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && text.count <= 1500
        }
        var isValid: Bool {
            switch kind {
            case .text, .code:
                return text.map(bounded) == true && (language?.count ?? 0) <= 40
            case .bullets, .steps:
                guard let items, (1...20).contains(items.count) else { return false }
                return items.allSatisfy(bounded)
            case .table:
                guard let headers, let rows, (1...8).contains(headers.count),
                      (1...20).contains(rows.count), headers.allSatisfy(bounded) else { return false }
                return rows.allSatisfy { $0.count == headers.count && $0.allSatisfy(bounded) }
            }
        }
    }

    var isValid: Bool { version == 1 && (1...20).contains(blocks.count) && blocks.allSatisfy(\.isValid) }
}

extension SDUIComponent {
    var resolvedPresentationRole: String {
        let roles = ["narration", "board", "reference", "practice", "feedback", "recovery", "details"]
        if let presentationRole, roles.contains(presentationRole) { return presentationRole }
        if type == .quizCard || type == .inputField { return "practice" }
        if type == .teacherMessage { return "narration" }
        if id == "classroom-recovery/notice" { return "recovery" }
        if id.hasPrefix("classroom-recovery/") { return "feedback" }
        if id.contains("board-memory") || id.hasPrefix("memory-visual:") { return "reference" }
        return "board"
    }
}
