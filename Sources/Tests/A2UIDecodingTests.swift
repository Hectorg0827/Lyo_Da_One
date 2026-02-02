import XCTest
@testable import Lyo

class A2UIDecodingTests: XCTestCase {

    func testVStackDecodingWithAlign() throws {
        // This JSON simulates the backend response that was failing
        // It uses "align" in props, which should map to "alignment" in the struct
        let json = """
        {
            "id": "test-vstack",
            "type": "vstack",
            "payload": {
                "props": {
                    "spacing": 20,
                    "align": "center",
                    "padding": 16
                },
                "children": []
            }
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let component = try decoder.decode(DynamicComponent.self, from: json)

        XCTAssertEqual(component.type, .vstack)
        
        if case .vstack(let payload) = component.payload {
            XCTAssertEqual(payload.alignment, "center")
            XCTAssertEqual(payload.spacing, 20)
        } else {
            XCTFail("Payload should be vstack")
        }
    }
    
    func testRecursiveDecoding() throws {
        let json = """
        {
            "id": "root",
            "type": "vstack",
            "payload": {
                "children": [
                    {
                        "id": "child1",
                        "type": "text",
                        "payload": {
                            "props": {
                                "content": "Hello",
                                "align": "leading"
                            }
                        }
                    }
                ]
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let component = try decoder.decode(DynamicComponent.self, from: json)
        
        if case .vstack(let payload) = component.payload {
            XCTAssertEqual(payload.children.count, 1)
            let child = payload.children[0]
            XCTAssertEqual(child.type, .text)
            if case .text(let textPayload) = child.payload {
                XCTAssertEqual(textPayload.content, "Hello")
                XCTAssertEqual(textPayload.alignment, "leading")
            } else {
                XCTFail("Child payload should be text")
            }
        } else {
            XCTFail("Root payload should be vstack")
        }
    }
}
