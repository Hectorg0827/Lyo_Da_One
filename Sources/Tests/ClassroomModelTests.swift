import XCTest
@testable import Lyo

final class ClassroomModelTests: XCTestCase {
    func testSlideWithoutAuthoredQuickCheckDecodesWithoutInventingOne() throws {
        let data = """
        {
          "id": "slide-1",
          "type": "concept",
          "content": {"title": "Fracciones", "body": "Compara las partes."},
          "narration": "Compara las partes.",
          "estimated_read_time": 20
        }
        """.data(using: .utf8)!

        let slide = try JSONDecoder().decode(Slide.self, from: data)

        XCTAssertNil(slide.quickCheck)
    }

    func testSlideUsesItsServerAuthoredQuickCheck() throws {
        let data = """
        {
          "id": "slide-2",
          "type": "concept",
          "content": {"title": "Fracciones", "body": "Usa un denominador común."},
          "narration": "Usa un denominador común.",
          "estimated_read_time": 20,
          "quick_check": {
            "id": "fractions-check",
            "type": "multiple_choice",
            "question": "¿Qué necesitas antes de comparar?",
            "options": ["Un denominador común", "Un decimal al azar"],
            "correct_answer": "Un denominador común",
            "explanation": "Permite comparar partes del mismo tamaño.",
            "time_limit": null
          }
        }
        """.data(using: .utf8)!

        let slide = try JSONDecoder().decode(Slide.self, from: data)

        XCTAssertEqual(slide.quickCheck?.id, "fractions-check")
        XCTAssertEqual(slide.quickCheck?.question, "¿Qué necesitas antes de comparar?")
        XCTAssertEqual(slide.quickCheck?.type, .multipleChoice)
    }

    func testUnderSpecifiedLegacyCheckTypesAreNotExposed() {
        XCTAssertFalse(QuickCheck.CheckType.tapToOrder.isSupported)
        XCTAssertFalse(QuickCheck.CheckType.labelDiagram.isSupported)
        XCTAssertTrue(QuickCheck.CheckType.multipleChoice.isSupported)
    }
}
