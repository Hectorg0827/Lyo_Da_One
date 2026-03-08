import XCTest
@testable import Lyo

final class A2IPayloadMapperTests: XCTestCase {

    func testMapFromJSONProducesComponents() throws {
        let json = #"{
            "type": "open_classroom",
            "payload": {
                "course": {
                    "title": "Test Course",
                    "topic": "Testing",
                    "level": "beginner",
                    "language": null,
                    "duration": null,
                    "objectives": []
                },
                "components": [
                    { "type": "text", "payload": { "id": "t1", "text": "Hello world" } },
                    { "type": "image", "payload": { "id": "i1", "url": "https://example.com/pic.png", "alt": "pic" } },
                    { "type": "media", "payload": { "id": "m1", "url": "https://example.com/video.mp4", "type": "video", "posterURL": "https://example.com/poster.jpg" } },
                    { "type": "quiz", "payload": { "id": "q1", "title": "Simple Quiz", "questionPool": [ { "id": "q1a", "type": "mcq", "prompt": "2+2?", "choices": [ { "id": "c1", "text": "3" }, { "id": "c2", "text": "4" } ], "answer": { "correctChoiceIds": ["c2"] } } ] } }
                ]
            }
        }"#

        let data = Data(json.utf8)
        let comps = A2IPayloadMapper.mapFromJSON(data)
        XCTAssertNotNil(comps)
        XCTAssertEqual(comps?.count, 4)
        // Basic type checks
        XCTAssertEqual(comps?[0].type, .text)
        XCTAssertEqual(comps?[1].type, .image)
        XCTAssertTrue([.video, .gif].contains(comps?[2].type ?? .unknown))
        XCTAssertTrue([.quizMcq, .quizTrueFalse, .quizShortAnswer].contains(comps?[3].type))
    }
}
