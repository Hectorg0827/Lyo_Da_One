import XCTest
@testable import Lyo

final class VisualPersistenceTests: XCTestCase {
    @MainActor
    func testSavedVisualSurvivesCacheReloadAndPreservesOtherBlocksAndVerdicts() throws {
        let suite = "VisualPersistenceTests.\(UUID().uuidString)"
        let storage = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { storage.removePersistentDomain(forName: suite) }
        let manager = ConversationManager(userDefaults: storage, refreshFromServer: false)
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "SharedFractionPie", withExtension: "json"))
        let data = try Data(contentsOf: url)
        let original = try JSONDecoder().decode(SmartBlock.self, from: data)
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var content = try XCTUnwrap(object["content"] as? [String: Any])
        var visual = try XCTUnwrap(content["visual"] as? [String: Any])
        visual["parts"] = 8
        visual["value"] = 2
        content["visual"] = visual
        object["content"] = content
        let updated = try JSONDecoder().decode(SmartBlock.self, from: JSONSerialization.data(withJSONObject: object))
        let note = try JSONDecoder().decode(SmartBlock.self, from: Data(#"{"id":"note-1","schema_version":1,"type":"text","content":{"text":"Keep this explanation."}}"#.utf8))
        let verdict = try JSONDecoder().decode(CheckAnswerResult.self, from: Data(#"{"correct":false,"correct_index":0,"selected_index":1,"bailed_out":false}"#.utf8))
        let message = MultimodalMessage(
            id: "message-1", sessionId: "conv-1", role: .assistant,
            content: "Fractions", attachments: [], timestamp: Date(),
            smartBlocks: [original, note], checkResults: ["quiz-1": verdict]
        )
        let conversation = SavedConversation(id: "conv-1", title: "Fractions", lastMessagePreview: "Fractions",
                                             messageCount: 1, messages: [message])
        manager.saveConversation(conversation)
        manager.currentConversation = SavedConversation(id: "conv-2", title: "Another thread",
                                                         lastMessagePreview: "", messageCount: 0)
        manager.updateSavedVisual(conversationId: "conv-1", messageId: "message-1", block: updated)
        XCTAssertEqual(manager.currentConversation?.id, "conv-2")

        // Decode the bytes that a new app process loads, not the live array.
        let saved = try XCTUnwrap(storage.data(forKey: "saved_conversations"))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let reloaded = try decoder.decode([SavedConversation].self, from: saved)
        let restored = try XCTUnwrap(reloaded.first { $0.id == "conv-1" }?.messages.first)
        let restoredBlock = try XCTUnwrap(restored.smartBlocks?.first)
        guard case .interactive(let payload) = restoredBlock.content else {
            return XCTFail("Lost the saved diagram")
        }
        let raw = try XCTUnwrap(payload.visual)
        let restoredVisual = try JSONDecoder().decode(ClassroomTeachingVisual.self, from: JSONEncoder().encode(raw))
        XCTAssertEqual(restoredVisual.parts, 8)
        XCTAssertEqual(restoredVisual.value, 2)
        XCTAssertEqual(restored.smartBlocks?.last?.id, "note-1")
        XCTAssertEqual(restored.checkResults?["quiz-1"]?.selectedIndex, 1)
        XCTAssertEqual(restored.checkResults?["quiz-1"]?.correct, false)
    }
}
