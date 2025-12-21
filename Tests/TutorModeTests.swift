
import XCTest
@testable import Lyo

@MainActor
final class TutorModeTests: XCTestCase {
    
    var viewModel: TutorViewModel!
    var mockClient: LyoAPIClient!
    
    override func setUp() async throws {
        // Setup Mock URL Session
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        
        mockClient = LyoAPIClient(session: session)
        viewModel = TutorViewModel(courseId: "test_course", lessonId: "test_lesson", apiClient: mockClient)
    }
    
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        viewModel = nil
        mockClient = nil
    }
    
    func testSetupSessionSuccess() async throws {
        // Mock Response
        let sessionData = """
        {
            "id": "session_123",
            "course_id": "test_course",
            "lesson_id": "test_lesson",
            "user_id": "user_1",
            "created_at": "2023-10-27T10:00:00Z",
            "updated_at": "2023-10-27T10:00:00Z"
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            // Expecting POST /api/v1/tutor/sessions
            XCTAssertEqual(request.url?.path, "/api/v1/tutor/sessions")
            XCTAssertEqual(request.httpMethod, "POST")
            
            return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, sessionData)
        }
        
        // Also mock the subsequent fetch messages call (returning empty list)
        // Note: MockURLProtocol as implemented handles one handler. 
        // We'll update logic to handle multiple or just checking the first one then switching?
        // Actually, simplest is to check path in handler.
        
        MockURLProtocol.requestHandler = { request in
            if request.url?.path.contains("/tutor/sessions") == true && request.httpMethod == "POST" {
                 return (HTTPURLResponse(url: request.url!, statusCode: 201, httpVersion: nil, headerFields: nil)!, sessionData)
            } else if request.url?.path.contains("/messages") == true && request.httpMethod == "GET" {
                return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, "[]".data(using: .utf8)!)
            }
            throw URLError(.badURL)
        }
        
        await viewModel.setupSession()
        
        XCTAssertNotNil(viewModel.session)
        XCTAssertEqual(viewModel.session?.id, "session_123")
        XCTAssertNil(viewModel.errorMessage)
    }
    
    func testSendMessage() async throws {
        // Pre-set session
        viewModel.session = TutorSession(
            id: "session_123",
            courseId: "c1",
            lessonId: "l1",
            userId: "u1",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        viewModel.inputText = "Hello AI"
        
        let responseMessage = """
        {
            "id": "msg_ai_1",
            "session_id": "session_123",
            "sender": "ai",
            "content": "Hello User!",
            "created_at": "2023-10-27T10:00:05Z"
        }
        """.data(using: .utf8)!
        
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/v1/tutor/messages")
            XCTAssertEqual(request.httpMethod, "POST")
            
            return (HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!, responseMessage)
        }
        
        await viewModel.send()
        
        // Should have 2 messages: 1 user (optimistic), 1 ai (response)
        XCTAssertEqual(viewModel.messages.count, 2)
        XCTAssertEqual(viewModel.messages.first?.content, "Hello AI") // Optimistic
        XCTAssertEqual(viewModel.messages.last?.content, "Hello User!") // Response
        XCTAssertTrue(viewModel.inputText.isEmpty)
        XCTAssertFalse(viewModel.isLoading)
    }
}
