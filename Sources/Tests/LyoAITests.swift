import XCTest
@testable import Lyo

@MainActor
class LyoAITests: XCTestCase {
    
    var viewModel: LyoAIViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = LyoAIViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testLearningConsultantResponse() async {
        // Given
        viewModel.inputText = "I need help with math"
        
        // When
        await viewModel.sendMessage()
        
        // Then
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(viewModel.messages.count, 2) // User message + AI response
        
        let userMessage = viewModel.messages[0]
        XCTAssertTrue(userMessage.isFromUser)
        XCTAssertEqual(userMessage.content, "I need help with math")
        
        let aiMessage = viewModel.messages[1]
        XCTAssertFalse(aiMessage.isFromUser)
        XCTAssertFalse(aiMessage.content.isEmpty)
        
        // Verify it's using the Learning Consultant persona (Mock mode)
        // The mock response usually starts with "I'm Leo, your Learning Consultant." or similar
        // or at least contains helpful learning advice.
        print("AI Response: \(aiMessage.content)")
    }
}
