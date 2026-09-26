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

    func testOrientationAndModelsKeepWorkedExamplesVisualsAndCanonicalContinue() throws {
        let fixture = try fixtures()
        for name in ["orientation", "model_1", "model_2"] {
            let components = try XCTUnwrap(fixture.scenes[name]?.components)
            let steps = ActiveLessonAdapter.steps(from: components)
            XCTAssertEqual(steps.count, 1)
            let step = try XCTUnwrap(steps.first)
            XCTAssertFalse(step.teachingExamples.isEmpty, "Adding the CTA must preserve the example")
            XCTAssertNotNil(step.teachingVisual)
            XCTAssertEqual(step.activityId, components.first { $0.teachingVisual != nil }?.id)
            XCTAssertEqual(step.primaryActionComponentId, components.first { $0.type == .ctaButton }?.id)
            XCTAssertEqual(step.primaryActionIntent, "continue")
            XCTAssertNil(step.supporting)
            XCTAssertFalse(step.requiresOpenResponse)
        }
    }

    func testTheOpeningProbeAsksBeforeAnythingIsTaughtAndShipsNoAnswerKey() throws {
        // A unit now opens by finding out where the learner is, before anything
        // is taught. It reaches iOS through the components iOS already renders,
        // which is why the new opening needed no client change — only this
        // fixture regenerated. These assertions keep it that way.
        let fixture = try fixtures()
        let components = try XCTUnwrap(fixture.scenes["diagnostic"]?.components)
        let step = try XCTUnwrap(ActiveLessonAdapter.steps(from: components).first)

        // The learner is asked something, and asked it in their own words.
        guard case .classroomInput(let input)? = step.supporting else {
            return XCTFail("The opening probe must ask for the learner's own answer")
        }
        XCTAssertFalse((input.question ?? "").isEmpty)

        // One teacher line, then the floor is the learner's.
        XCTAssertEqual(components.filter { $0.type == .teacherMessage }.count, 1)

        // A Continue here would make answering optional, which is the
        // monologue with an extra tap.
        XCTAssertNil(components.first { $0.type == .ctaButton })
        XCTAssertNil(step.primaryActionIntent)

        // The learner writes a short answer, not an essay. The rubric and the
        // rung this evidence counts as are server-side and `SDUIComponent`
        // does not decode them, so nothing here can leak either — which is
        // what `teaching-activity.test.mjs` asserts against the raw payload.
        XCTAssertEqual(input.minWords, 1)
    }

    func testGuidedChoiceRetainsItsExampleAndVisualWhileFadedPracticeAsksForOneNumber() throws {
        let fixture = try fixtures()
        let guided = try XCTUnwrap(ActiveLessonAdapter.steps(from: fixture.scenes["guided"]!.components).first)
        guard case .classroomQuiz(let question)? = guided.supporting else { return XCTFail("Guided practice must be a choice") }
        XCTAssertEqual(question.options?.count, 2)
        XCTAssertFalse(guided.teachingExamples.isEmpty)
        XCTAssertEqual(guided.teachingVisual?.kind, "comparison")
        let faded = try XCTUnwrap(ActiveLessonAdapter.steps(from: fixture.scenes["faded"]!.components).first)
        guard case .classroomInput(let input)? = faded.supporting else { return XCTFail("Faded practice must retain the short answer input") }
        XCTAssertTrue(input.question?.contains("1/__") == true)
        XCTAssertEqual(input.minWords, 1)
        XCTAssertFalse(faded.teachingExamples.isEmpty)
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
