import XCTest
@testable import Lyo

/// Confirms `CheckAnswerResult`/`CheckAnswerRequest` speak the same wire
/// format as the backend (`CheckAnswerResponse`/`CheckAnswerRequest` in
/// lyo_app/api/v1/stream_lyo2.py) and web (`CheckAnswerResult` in
/// web/src/types/index.ts) — snake_case field names, decoded without a
/// blanket `.convertFromSnakeCase` strategy since these use explicit
/// `CodingKeys` instead.
final class CheckAnswerResultCodableTests: XCTestCase {

    // MARK: - Decoding a real server response

    func testDecodesACorrectVerdict() throws {
        let json = """
        {
            "correct": true,
            "correct_index": 0,
            "selected_index": 0,
            "explanation": "7 x 7 = 49.",
            "misconception": null,
            "bailed_out": false,
            "skill_id": "square_roots",
            "mastery": 0.62
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(CheckAnswerResult.self, from: json)

        XCTAssertTrue(result.correct)
        XCTAssertEqual(result.correctIndex, 0)
        XCTAssertEqual(result.selectedIndex, 0)
        XCTAssertEqual(result.explanation, "7 x 7 = 49.")
        XCTAssertNil(result.misconception)
        XCTAssertFalse(result.bailedOut)
        XCTAssertEqual(result.skillId, "square_roots")
        XCTAssertEqual(result.mastery, 0.62)
    }

    func testDecodesAWrongVerdictWithMisconception() throws {
        // The exact production bug this whole feature exists to fix: chat
        // must never call this "Spot on!" — the server names the specific
        // confusion instead.
        let json = """
        {
            "correct": false,
            "correct_index": 0,
            "selected_index": 1,
            "explanation": "7 x 7 = 49.",
            "misconception": "confusing the root with a nearby square",
            "bailed_out": false,
            "skill_id": "square_roots",
            "mastery": 0.31
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(CheckAnswerResult.self, from: json)

        XCTAssertFalse(result.correct)
        XCTAssertEqual(result.misconception, "confusing the root with a nearby square")
    }

    func testDecodesABailoutWithoutSkillOrMastery() throws {
        // An opt-out is not evidence of anything, so the server omits
        // skill_id/mastery entirely rather than sending a misleading value.
        let json = """
        {
            "correct": false,
            "correct_index": 0,
            "selected_index": 3,
            "bailed_out": true
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(CheckAnswerResult.self, from: json)

        XCTAssertTrue(result.bailedOut)
        XCTAssertFalse(result.correct)
        XCTAssertNil(result.skillId)
        XCTAssertNil(result.mastery)
    }

    // MARK: - Encoding what the server expects to receive

    func testRequestEncodesToTheFieldsTheServerReads() throws {
        // Deliberately does NOT carry the question or an answer key — see
        // CheckAnswerRequest's doc comment. This only asserts the request
        // sends what /chat/check's CheckAnswerRequest model expects.
        let request = CheckAnswerRequest(
            conversationId: "conv-1",
            blockId: "block-1",
            selectedIndex: 2,
            timeTakenMs: 4200,
            hintUsed: true
        )

        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["conversation_id"] as? String, "conv-1")
        XCTAssertEqual(object?["block_id"] as? String, "block-1")
        XCTAssertEqual(object?["selected_index"] as? Int, 2)
        XCTAssertEqual(object?["time_taken_ms"] as? Int, 4200)
        XCTAssertEqual(object?["hint_used"] as? Bool, true)
        // The question and any answer key must never be sent — the server
        // decides correctness by reading its own stored block, not by
        // trusting anything the client asserts about the question.
        XCTAssertNil(object?["question"])
        XCTAssertNil(object?["correct_index"])
    }

    func testRequestDefaultsTimeTakenAndHintUsed() throws {
        let request = CheckAnswerRequest(conversationId: "conv-1", blockId: "block-1", selectedIndex: 0)

        let data = try JSONEncoder().encode(request)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(object?["time_taken_ms"] as? Int, 0)
        XCTAssertEqual(object?["hint_used"] as? Bool, false)
    }
}
