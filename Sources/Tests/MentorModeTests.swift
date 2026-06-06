import XCTest
@testable import Lyo

final class MentorModeTests: XCTestCase {
    
    func testMentorMessageResponseDecoding() throws {
        let json = """
        {
            "interaction_id": 123,
            "response": "Here is a quick explainer",
            "response_mode": "explainer",
            "quick_explainer": {
                "concept": "SwiftUI",
                "explanation": "A declarative framework",
                "chips": ["Declarative", "UI"]
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(MentorMessageResponse.self, from: json)
        
        XCTAssertEqual(response.id, 123)
        XCTAssertEqual(response.responseMode, .explainer)
        XCTAssertNotNil(response.quickExplainer)
        XCTAssertEqual(response.quickExplainer?.concept, "SwiftUI")
        XCTAssertEqual(response.quickExplainer?.chips.count, 2)
    }
    
    func testCourseProposalDecoding() throws {
        let json = """
        {
            "interaction_id": 456,
            "response": "Course proposal",
            "response_mode": "course",
            "course_proposal": {
                "title": "Learn Swift",
                "subtext": "Beginner to Pro",
                "summary": "Complete course",
                "modules": ["Basics", "Advanced"],
                "button_text": "Start Now"
            }
        }
        """.data(using: .utf8)!
        
        let decoder = JSONDecoder()
        let response = try decoder.decode(MentorMessageResponse.self, from: json)
        
        XCTAssertEqual(response.responseMode, .course)
        XCTAssertNotNil(response.courseProposal)
        XCTAssertEqual(response.courseProposal?.title, "Learn Swift")
        XCTAssertEqual(response.courseProposal?.buttonText, "Start Now")
    }
}
