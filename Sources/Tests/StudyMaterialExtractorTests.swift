import XCTest

@testable import Lyo

/// Covers the client-side rescue of study material: the backend answers a
/// "make me flashcards" ask with Markdown prose, and chat has to turn that into
/// real cards. The negative cases matter as much as the positive ones — an
/// ordinary explanation must never be collapsed into a deck.
final class StudyMaterialExtractorTests: XCTestCase {

    // MARK: Helpers

    private func deck(_ result: StudyMaterialExtractor.Result?) -> (
        title: String, cards: [Flashcard]
    )? {
        for type in result?.contentTypes ?? [] {
            if case .flashcards(let title, let cards) = type { return (title, cards) }
        }
        return nil
    }

    private func plan(_ result: StudyMaterialExtractor.Result?) -> StudyPlan? {
        for type in result?.contentTypes ?? [] {
            if case .studyPlan(let plan) = type { return plan }
        }
        return nil
    }

    private func notes(_ result: StudyMaterialExtractor.Result?) -> (
        title: String, sections: [NoteSection]
    )? {
        for type in result?.contentTypes ?? [] {
            if case .notes(let title, let sections) = type { return (title, sections) }
        }
        return nil
    }

    // MARK: Flashcards from Markdown

    func testBoldTermWithEmDashBecomesDeck() {
        let reply = """
            Here are 3 flashcards on photosynthesis:

            **Chlorophyll** — the green pigment that absorbs light energy
            **Stroma** — the fluid-filled space inside the chloroplast
            **Thylakoid** — stacked membrane where the light reactions happen

            Let me know if you want more!
            """
        let found = deck(
            StudyMaterialExtractor.extract(
                from: reply, userAsk: "make flashcards on photosynthesis"))

        XCTAssertEqual(found?.cards.count, 3)
        XCTAssertEqual(found?.cards.first?.front, "Chlorophyll")
        XCTAssertEqual(
            found?.cards.first?.back, "the green pigment that absorbs light energy")
    }

    /// `**Term:** definition` hides its separator inside the emphasis markers.
    func testColonInsideEmphasisStillSplits() {
        let reply = """
            **Mitosis:** cell division producing two identical cells
            **Meiosis:** division producing four gametes
            **Cytokinesis:** the physical split of the cytoplasm
            """
        let found = deck(
            StudyMaterialExtractor.extract(from: reply, userAsk: "flashcards for cell division"))

        XCTAssertEqual(found?.cards.count, 3)
        XCTAssertEqual(found?.cards[1].front, "Meiosis")
        XCTAssertEqual(found?.cards[1].back, "division producing four gametes")
    }

    func testBulletedAndNumberedPairsBecomeCards() {
        let reply = """
            Sure! Here's your deck:
            - Mitochondria: the powerhouse of the cell
            - Ribosome: builds proteins from amino acids
            1. Nucleus — stores the cell's DNA
            """
        let found = deck(
            StudyMaterialExtractor.extract(from: reply, userAsk: "key terms for cell biology"))

        XCTAssertEqual(found?.cards.count, 3)
        XCTAssertEqual(found?.cards.last?.front, "Nucleus")
    }

    func testQuestionAnswerPairsBecomeCards() {
        let reply = """
            Q: What is the capital of France?
            A: Paris
            Q: What is the capital of Japan?
            A: Tokyo
            Q: What is the capital of Peru?
            A: Lima
            """
        let found = deck(
            StudyMaterialExtractor.extract(from: reply, userAsk: "flashcards on capital cities"))

        XCTAssertEqual(found?.cards.count, 3)
        XCTAssertEqual(found?.cards.first?.front, "What is the capital of France?")
        XCTAssertEqual(found?.cards.first?.back, "Paris")
    }

    func testMarkdownTableBecomesCardsWithoutHeaderRow() {
        let reply = """
            | Term | Definition |
            |------|------------|
            | Osmosis | Water moving across a semipermeable membrane |
            | Diffusion | Particles spreading from high to low concentration |
            | Active transport | Movement requiring energy input |
            """
        let found = deck(
            StudyMaterialExtractor.extract(from: reply, userAsk: "make me a study deck on transport")
        )

        XCTAssertEqual(found?.cards.count, 3)
        XCTAssertEqual(found?.cards.first?.front, "Osmosis")
        XCTAssertFalse(found?.cards.contains(where: { $0.front == "Term" }) ?? true)
    }

    func testDeckTitleComesFromTheAskWhenTheReplyHasNoHeading() {
        let reply = """
            - Alpha: first letter
            - Beta: second letter
            - Gamma: third letter
            """
        let found = deck(
            StudyMaterialExtractor.extract(from: reply, userAsk: "flashcards on greek letters"))

        XCTAssertEqual(found?.title, "Flashcards: greek letters")
    }

    // MARK: Flashcards from a fenced JSON payload

    func testFencedJSONPayloadBecomesDeck() {
        let reply = """
            Here you go!

            ```json
            {"title": "Spanish verbs", "cards": [
              {"front": "hablar", "back": "to speak"},
              {"front": "comer", "back": "to eat"}
            ]}
            ```
            """
        let found = deck(
            StudyMaterialExtractor.extract(from: reply, userAsk: "make flashcards for spanish"))

        XCTAssertEqual(found?.title, "Spanish verbs")
        XCTAssertEqual(found?.cards.count, 2)
        XCTAssertEqual(found?.cards.first?.front, "hablar")
        XCTAssertEqual(found?.cards.first?.back, "to speak")
    }

    func testFencedJSONPayloadLeavesReadableProseAboveTheDeck() {
        let reply = """
            Here you go!

            ```json
            {"title": "Spanish verbs", "cards": [
              {"front": "hablar", "back": "to speak"},
              {"front": "comer", "back": "to eat"}
            ]}
            ```
            """
        let result = StudyMaterialExtractor.extract(
            from: reply, userAsk: "make flashcards for spanish")

        XCTAssertEqual(result?.displayText, "Here you go!")
    }

    // MARK: Negative cases

    func testOrdinaryExplanationIsLeftAlone() {
        let reply = """
            Photosynthesis is how plants make food. It happens in the chloroplast.
            Note: the light reactions come first, then the Calvin cycle.
            Remember: chlorophyll absorbs mostly red and blue light.
            In short: plants turn light into sugar.
            """
        XCTAssertNil(
            StudyMaterialExtractor.extract(from: reply, userAsk: "flashcards on photosynthesis"))
    }

    func testLongExplanationContainingAShortListIsLeftAlone() {
        let filler = String(
            repeating:
                "Plants capture light energy and store it as glucose, which powers food chains. ",
            count: 8)
        let reply = """
            \(filler)
            - Chlorophyll: the green pigment
            - Stroma: fluid in the chloroplast
            - Thylakoid: membrane stacks
            \(filler)
            """
        XCTAssertNil(
            StudyMaterialExtractor.extract(from: reply, userAsk: "flashcards on photosynthesis"))
    }

    func testTwoPairsAreTooFewForADeck() {
        let reply = """
            - Mitochondria: the powerhouse of the cell
            - Ribosome: builds proteins from amino acids
            """
        XCTAssertNil(
            StudyMaterialExtractor.extract(from: reply, userAsk: "flashcards on the cell"))
    }

    func testNoStudyAskMeansNoRestructuring() {
        let reply = """
            - Mitochondria: the powerhouse of the cell
            - Ribosome: builds proteins from amino acids
            - Nucleus: stores the cell's DNA
            """
        XCTAssertNil(
            StudyMaterialExtractor.extract(from: reply, userAsk: "what does a cell contain?"))
    }

    /// A reply that calls itself a deck is honoured even when the ask was vague.
    func testSelfLabelledDeckIsHonouredWithoutAnExplicitAsk() {
        let reply = """
            Flashcards for chapter 4:
            - Alpha: first letter
            - Beta: second letter
            - Gamma: third letter
            """
        XCTAssertEqual(
            deck(StudyMaterialExtractor.extract(from: reply, userAsk: "do that for chapter 4"))?
                .cards.count,
            3)
    }

    // MARK: Study plan and notes

    func testDayHeadingsBecomeAStudyPlan() {
        let reply = """
            # Three-day revision plan

            **Day 1 — Cell structure**
            - Read chapter 2 (30 min)
            - Practice 10 problems (20 min)

            **Day 2 — Cell division**
            - Watch the mitosis video (15 min)
            - Quiz yourself on the stages

            **Day 3 — Review**
            - Redo missed questions
            """
        let found = plan(
            StudyMaterialExtractor.extract(from: reply, userAsk: "build me a study plan"))

        XCTAssertEqual(found?.schedule.count, 3)
        XCTAssertEqual(found?.schedule.first?.dayNumber, 1)
        XCTAssertEqual(found?.schedule.first?.topic, "Cell structure")
        XCTAssertEqual(found?.schedule.first?.tasks.count, 2)
        XCTAssertEqual(found?.schedule.first?.tasks.first?.durationMinutes, 30)
        XCTAssertEqual(found?.schedule[1].tasks.first?.type, "watch")
    }

    func testHeadedSectionsBecomeNotes() {
        let reply = """
            # Photosynthesis study guide

            Use this before the test.

            ## Light reactions
            Happen in the thylakoid membrane and produce ATP and NADPH.

            ## Calvin cycle
            Happens in the stroma and fixes carbon into glucose.
            """
        let found = notes(
            StudyMaterialExtractor.extract(
                from: reply, userAsk: "give me study material on photosynthesis"))

        XCTAssertEqual(found?.sections.count, 2)
        XCTAssertEqual(found?.sections.first?.title, "Light reactions")
        XCTAssertEqual(found?.title, "Photosynthesis study guide")
    }

    // MARK: Intent classification

    func testClassification() {
        XCTAssertEqual(
            StudyMaterialExtractor.classify("make flashcards on osmosis"), .flashcards)
        XCTAssertEqual(StudyMaterialExtractor.classify("build a study plan for finals"), .studyPlan)
        XCTAssertEqual(StudyMaterialExtractor.classify("give me a study guide"), .notes)
        XCTAssertEqual(StudyMaterialExtractor.classify("why is the sky blue?"), .unrelated)
    }
}
