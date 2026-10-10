import XCTest
@testable import Lyo

/// The same production-runner payloads are decoded by web and Android tests.
@MainActor
final class GuidedTeachingTests: XCTestCase {
    private struct FixtureScene: Decodable { let components: [SDUIComponent] }
    private struct Fixtures: Decodable {
        let scenes: [String: FixtureScene]
        let visuals: [ClassroomTeachingVisual]
    }

    private func fixtures() throws -> Fixtures {
        let url = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "GuidedTeaching", withExtension: "json"))
        return try JSONDecoder().decode(Fixtures.self, from: Data(contentsOf: url))
    }

    private func assertExamplesPreserved(
        _ step: ActiveLessonView.LessonStep,
        from components: [SDUIComponent],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expected = components.filter { $0.type == .exampleBlock }
        XCTAssertFalse(expected.isEmpty, "The fixture must include a worked example", file: file, line: line)
        XCTAssertEqual(
            step.workspaceComponents.filter { $0.type == .exampleBlock },
            expected,
            "Every original example must survive in the teaching workspace",
            file: file,
            line: line
        )
    }

    func testOrientationAndModelsKeepWorkedExamplesVisualsAndCanonicalContinue() throws {
        let fixture = try fixtures()
        for name in ["orientation", "model_1", "model_2"] {
            let components = try XCTUnwrap(fixture.scenes[name]?.components)
            let steps = ActiveLessonAdapter.steps(from: components)
            XCTAssertEqual(steps.count, 1)
            let step = try XCTUnwrap(steps.first)
            assertExamplesPreserved(step, from: components)
            XCTAssertNotNil(step.teachingVisual)
            XCTAssertEqual(step.activityId, components.first { $0.teachingVisual != nil }?.id)
            XCTAssertEqual(step.primaryActionComponentId, components.first { $0.type == .ctaButton }?.id)
            XCTAssertEqual(step.primaryActionIntent, "continue")
            XCTAssertNil(step.supporting)
            XCTAssertFalse(step.requiresOpenResponse)
        }
    }

    func testTheOpeningProbeAsksBeforeAnythingIsTaughtAndShipsNoAnswerKey() throws {
        // A unit opens by finding out where the learner is, before anything is
        // taught, and it asks with one tap: a learner who has never met the
        // skill can still answer, where a blank box in front of an unfamiliar
        // skill reads as a test. It reaches iOS through the components iOS
        // already renders, which is why the opening needed no client change —
        // only this fixture regenerated. These assertions keep it that way.
        let fixture = try fixtures()
        let components = try XCTUnwrap(fixture.scenes["diagnostic"]?.components)
        let step = try XCTUnwrap(ActiveLessonAdapter.steps(from: components).first)

        // The learner is asked something, and it is answerable in one tap.
        guard case .classroomQuiz(let question)? = step.supporting else {
            return XCTFail("The opening probe must be answerable with one tap")
        }
        // Four options: the answer, two named misconceptions, and somewhere to
        // say "not sure yet" so that not knowing never forces a guess.
        XCTAssertEqual(question.options?.count, 4)
        XCTAssertFalse(step.requiresOpenResponse)
        XCTAssertNil(components.first { $0.type == .inputField })

        // One teacher line, then the floor is the learner's.
        XCTAssertEqual(components.filter { $0.type == .teacherMessage }.count, 1)

        // A Continue here would make answering optional, which is the
        // monologue with an extra tap.
        XCTAssertNil(components.first { $0.type == .ctaButton })
        XCTAssertNil(step.primaryActionIntent)

        // Nothing on the board explains the answer above the question.
        XCTAssertNil(step.teachingVisual)

        // `SDUIQuizOption` decodes an id and a label and nothing else, so the
        // key, the per-option feedback and the misconception each distractor
        // reveals cannot reach this screen even if a payload carried them —
        // which `teaching-activity.test.mjs` asserts against the raw payload.
        XCTAssertEqual(question.options?.filter { !$0.label.isEmpty }.count, 4)
    }

    func testANearMissIsShownTheOneStepItTurnsOnRatherThanTheWholeExample() throws {
        // Tapping the near miss on the probe says the learner has the idea and
        // slipped on one step, so the example they get is cut to that step.
        // Same components as `orientation`, less of the teacher.
        let fixture = try fixtures()
        let components = try XCTUnwrap(fixture.scenes["focused_example"]?.components)
        let step = try XCTUnwrap(ActiveLessonAdapter.steps(from: components).first)

        assertExamplesPreserved(step, from: components)
        XCTAssertNotNil(step.teachingVisual)
        XCTAssertEqual(step.primaryActionIntent, "continue")
        // Teaching, not a question: the checkpoint comes after the step.
        XCTAssertNil(step.supporting)
        XCTAssertNil(components.first { $0.type == .quizCard })
        XCTAssertNil(components.first { $0.type == .inputField })
    }

    func testGuidedChoiceRetainsItsExampleAndVisualWhileFadedPracticeAsksForOneNumber() throws {
        let fixture = try fixtures()
        let guided = try XCTUnwrap(ActiveLessonAdapter.steps(from: fixture.scenes["guided"]!.components).first)
        guard case .classroomQuiz(let question)? = guided.supporting else { return XCTFail("Guided practice must be a choice") }
        XCTAssertEqual(question.options?.count, 2)
        assertExamplesPreserved(guided, from: fixture.scenes["guided"]!.components)
        XCTAssertEqual(guided.teachingVisual?.kind, "comparison")
        let faded = try XCTUnwrap(ActiveLessonAdapter.steps(from: fixture.scenes["faded"]!.components).first)
        guard case .classroomInput(let input)? = faded.supporting else { return XCTFail("Faded practice must retain the short answer input") }
        XCTAssertTrue(input.question?.contains("1/__") == true)
        XCTAssertEqual(input.minWords, 1)
        assertExamplesPreserved(faded, from: fixture.scenes["faded"]!.components)
    }

    func testEveryTeachingToolDecodesAndRoundTripsItsSavedValues() throws {
        let fixture = try fixtures()
        XCTAssertEqual(Set(fixture.visuals.map(\.kind)), Set(["fraction_bar", "comparison", "sequence", "graph"]))
        for visual in fixture.visuals {
            XCTAssertTrue(visual.isValid)
            let data = try JSONEncoder().encode(visual)
            XCTAssertEqual(try JSONDecoder().decode(ClassroomTeachingVisual.self, from: data), visual)
        }
        let graph = try XCTUnwrap(fixture.visuals.first { $0.kind == "graph" })
        let evaluate = try XCTUnwrap(ExpressionEvaluator.compile(graph.expression))
        XCTAssertEqual(evaluate(["x": 1, "a": 1]), 1)
        XCTAssertEqual(evaluate(["x": 1, "a": 2]), 2)
        XCTAssertEqual(graph.yMin, -10)
        XCTAssertEqual(graph.yMax, 10)
    }
}
