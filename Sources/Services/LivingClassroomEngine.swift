import Foundation
import os

// MARK: - SDUI Convenience Initializers
//
// `SDUIComponent` and `SDUIScene` define custom `init(from:)` decoders, which
// suppresses the automatic memberwise initializer. These extensions add
// ergonomic initializers so the on-device classroom engine can construct
// scenes that flow through the *exact same* rendering pipeline used for the
// server-driven (WebSocket) scenes.

extension SDUIComponent {
    init(
        id: String,
        type: ComponentType,
        content: String,
        delayMs: Int = 0,
        animation: String = "fade_in",
        emotion: String? = nil,
        studentName: String? = nil,
        question: String? = nil,
        options: [SDUIQuizOption]? = nil,
        actionIntent: String? = nil,
        actionPayload: [String: String]? = nil
    ) {
        self.id = id
        self.type = type
        self.content = content
        self.delayMs = delayMs
        self.animation = animation
        self.emotion = emotion
        self.studentName = studentName
        self.question = question
        self.options = options
        self.actionIntent = actionIntent
        self.actionPayload = actionPayload
    }
}

extension SDUIScene {
    init(id: String, sceneType: String, components: [SDUIComponent]) {
        self.id = id
        self.sceneType = sceneType
        self.components = components
    }
}

// MARK: - Living Classroom Engine
//
// A self-contained, on-device pedagogical engine that generates a *continuous*,
// adaptive lesson — one scene at a time — using the real backend LLM
// (`/api/v1/classroom/chat` via `OpenAIService`).
//
// Why this exists:
//   The flagship AI Classroom (`LivingClassroomView`) was a *passive* renderer of
//   server-pushed scenes with no client-side progression loop. When the backend
//   stopped streaming (typically after a handful of "scenes"), the screen went
//   dead. This engine guarantees the lesson never dead-ends: it produces real,
//   topic-specific, sequential content for as long as the learner wants to keep
//   going, and adapts to their quiz answers and questions.

@MainActor
final class LivingClassroomEngine {

    // MARK: - Types

    enum SceneKind: String {
        case intro
        case concept
        case example
        case checkpoint
        case recap
        case answer  // direct response to a learner question
    }

    /// A learner interaction fed back into generation for adaptivity.
    struct LearnerSignal {
        enum Kind { case answeredQuiz(correct: Bool, choice: String), askedQuestion(String), confused, tooEasy }
        let kind: Kind
        let detail: String
    }

    // MARK: - State

    private(set) var topic: String = ""
    private(set) var level: String = "beginner"
    private(set) var isReady: Bool = false
    private(set) var isComplete: Bool = false

    /// The course skeleton the engine works through.
    private(set) var outline: [String] = []
    private var sectionIndex: Int = 0
    private var scenesInCurrentSection: Int = 0
    private var totalScenes: Int = 0

    /// A rolling, compressed memory of everything taught so far so each new
    /// scene builds on the last (real continuity, not repetition).
    private var taughtSummary: [String] = []

    /// Pending learner signal to weave into the *next* scene.
    private var pendingSignal: LearnerSignal?

    private let maxScenesPerSection = 4
    private let logger = Logger(subsystem: "com.lyo.app", category: "ClassroomEngine")

    // MARK: - Lifecycle

    /// Build the lesson skeleton for a topic. Resilient: if the network/LLM is
    /// unavailable we synthesize a sensible, topic-specific outline so the
    /// lesson can still proceed.
    func bootstrap(topic: String, level: String = "beginner") async {
        self.topic = topic
        self.level = level
        self.sectionIndex = 0
        self.scenesInCurrentSection = 0
        self.totalScenes = 0
        self.taughtSummary = []
        self.pendingSignal = nil
        self.isComplete = false

        let prompt = """
        You are designing a focused micro-course on: "\(topic)".
        Learner level: \(level).
        Produce a tight learning outline of 5 to 7 section titles that take the
        learner from foundations to genuine competence. Each title must be
        concrete and specific to "\(topic)" (no generic filler like "Introduction").
        Return ONLY a JSON array of strings. Example: ["...", "...", "..."]
        """

        if let response = try? await OpenAIService.shared.sendMessage(
            message: prompt,
            systemPrompt: "You are an expert curriculum architect. Output strict JSON only."
        ), let parsed = Self.parseStringArray(response), parsed.count >= 3 {
            self.outline = parsed
            logger.info("Engine outline generated with \(parsed.count) sections")
        } else {
            self.outline = Self.fallbackOutline(for: topic)
            logger.warning("Engine using fallback outline for \(topic)")
        }

        self.isReady = true
    }

    // MARK: - Adaptivity

    /// Record a learner interaction so the next generated scene can respond to it.
    func record(_ signal: LearnerSignal) {
        pendingSignal = signal
    }

    /// Seed the engine with content the learner has already seen (e.g. scenes the
    /// backend delivered before stalling) so the on-device lesson continues
    /// smoothly instead of repeating from the beginning.
    func primePriorKnowledge(_ items: [String]) {
        let cleaned = items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !cleaned.isEmpty else { return }
        taughtSummary.append(contentsOf: cleaned.map { String($0.prefix(160)) })
        // Skip past the earliest sections proportionally to how much was covered.
        if !outline.isEmpty {
            let approxSections = min(outline.count - 1, cleaned.count / 2)
            sectionIndex = max(sectionIndex, approxSections)
        }
    }

    /// Whether the current section pointer is past the end of the outline.
    private var hasMoreSections: Bool { sectionIndex < outline.count }

    // MARK: - Scene Generation

    /// Generate the next scene in the lesson. Returns `nil` only when the entire
    /// curriculum has been delivered *and* a recap has been shown.
    func generateNextScene() async -> SDUIScene? {
        guard isReady else { return nil }

        // If a learner just asked a question, answer it immediately (study-mode
        // behavior) before resuming the curriculum.
        if let signal = pendingSignal, case let .askedQuestion(q) = signal.kind {
            pendingSignal = nil
            return await generateAnswerScene(question: q)
        }

        // Curriculum finished → deliver one recap, then end.
        if !hasMoreSections {
            if isComplete { return nil }
            isComplete = true
            return await generateRecapScene()
        }

        let sectionTitle = outline[sectionIndex]
        let signalNote = consumePendingSignalNote()

        let prompt = """
        TOPIC: \(topic)
        LEARNER LEVEL: \(level)
        FULL OUTLINE: \(outline.enumerated().map { "\($0.offset + 1). \($0.element)" }.joined(separator: " | "))
        CURRENT SECTION (\(sectionIndex + 1)/\(outline.count)): \(sectionTitle)
        SCENE NUMBER IN THIS SECTION: \(scenesInCurrentSection + 1) of up to \(maxScenesPerSection)
        ALREADY TAUGHT: \(taughtSummary.suffix(8).joined(separator: " • ").ifEmptyShow("nothing yet — this is the start"))
        \(signalNote)

        Teach the NEXT small step of this lesson as a single classroom "scene".
        Rules:
        - Advance the lesson; never repeat what was already taught.
        - One idea per scene. Be vivid, concrete, and use a real example.
        - Roughly every second scene, include ONE multiple-choice checkpoint that
          tests the idea you just taught (4 options, exactly one correct).
        - Keep narration warm and conversational, like a great human tutor.

        Return ONLY strict JSON in this shape:
        {
          "scene_type": "concept | example | checkpoint | recap",
          "narration": "what the tutor says out loud (2-4 sentences)",
          "blocks": [
            {"kind": "text", "content": "markdown explanation"},
            {"kind": "code", "language": "swift", "content": "optional code"},
            {"kind": "quiz", "question": "...", "options": ["a","b","c","d"], "answer_index": 0, "explanation": "why"}
          ],
          "summary": "one-line summary of what THIS scene taught",
          "advance_section": false,
          "lesson_complete": false
        }
        Only include a "code" block when code genuinely helps. Include at most one quiz block.
        """

        guard let response = try? await OpenAIService.shared.sendMessage(
            message: prompt,
            systemPrompt: "You are Lyo, a world-class AI tutor. Output strict JSON only — no prose, no markdown fences."
        ), let json = Self.parseObject(response) else {
            // Graceful degradation: emit a minimal but real scene so the lesson
            // continues instead of dead-ending.
            logger.warning("Engine scene generation failed; emitting graceful fallback scene")
            scenesInCurrentSection += 1
            advanceIfNeeded(forceAdvance: false)
            return fallbackScene(sectionTitle: sectionTitle)
        }

        totalScenes += 1
        scenesInCurrentSection += 1

        let scene = buildScene(from: json, sectionTitle: sectionTitle)

        if let summary = json["summary"] as? String, !summary.isEmpty {
            taughtSummary.append(summary)
        }

        let llmComplete = (json["lesson_complete"] as? Bool) ?? false
        let llmAdvance = (json["advance_section"] as? Bool) ?? false
        advanceIfNeeded(forceAdvance: llmAdvance)

        if llmComplete {
            // Honor an early completion signal but still cover remaining sections
            // unless we're already near the end.
            if sectionIndex >= max(0, outline.count - 1) {
                sectionIndex = outline.count
            }
        }

        return scene
    }

    /// Produce an immediate answer to a learner question, then return to the lesson.
    private func generateAnswerScene(question: String) async -> SDUIScene {
        let prompt = """
        TOPIC: \(topic)
        The learner just asked, mid-lesson: "\(question)"
        Context of what they've learned so far: \(taughtSummary.suffix(6).joined(separator: " • ").ifEmptyShow("just getting started"))

        Answer clearly and concisely as their tutor. Connect the answer back to the
        lesson. Return ONLY strict JSON:
        {
          "narration": "spoken answer (2-3 sentences)",
          "blocks": [{"kind": "text", "content": "fuller markdown answer"}]
        }
        """
        let response = (try? await OpenAIService.shared.sendMessage(
            message: prompt,
            systemPrompt: "You are Lyo, a precise and encouraging AI tutor. Output strict JSON only."
        )) ?? ""

        if let json = Self.parseObject(response) {
            return buildScene(from: json, sectionTitle: "Your question", kindOverride: .answer)
        }
        // Fallback answer scene
        return SDUIScene(
            id: "scene_answer_\(UUID().uuidString.prefix(8))",
            sceneType: SceneKind.answer.rawValue,
            components: [
                SDUIComponent(
                    id: "ans_\(UUID().uuidString.prefix(8))",
                    type: .teacherMessage,
                    content: "Great question. Let's keep that in mind as we continue — I'll tie it in as the concepts build up.",
                    delayMs: 0
                )
            ]
        )
    }

    private func generateRecapScene() async -> SDUIScene {
        let prompt = """
        TOPIC: \(topic)
        The learner has worked through: \(taughtSummary.joined(separator: " • "))
        Write an encouraging recap that consolidates the key takeaways and suggests
        one concrete next step to keep practicing. Return ONLY strict JSON:
        {
          "narration": "spoken recap (2-3 sentences)",
          "blocks": [{"kind": "text", "content": "bulleted key takeaways + a next step"}]
        }
        """
        let response = (try? await OpenAIService.shared.sendMessage(
            message: prompt,
            systemPrompt: "You are Lyo, an inspiring AI tutor wrapping up a lesson. Output strict JSON only."
        )) ?? ""

        if let json = Self.parseObject(response) {
            return buildScene(from: json, sectionTitle: "Recap", kindOverride: .recap)
        }
        return SDUIScene(
            id: "scene_recap_\(UUID().uuidString.prefix(8))",
            sceneType: SceneKind.recap.rawValue,
            components: [
                SDUIComponent(
                    id: "recap_\(UUID().uuidString.prefix(8))",
                    type: .teacherMessage,
                    content: "You've covered the essentials of \(topic). Keep practicing the parts that felt hardest — that's where real mastery is built.",
                    delayMs: 0
                )
            ]
        )
    }

    // MARK: - Scene Building

    private func buildScene(
        from json: [String: Any],
        sectionTitle: String,
        kindOverride: SceneKind? = nil
    ) -> SDUIScene {
        let sceneId = "scene_\(totalScenes)_\(UUID().uuidString.prefix(8))"
        let kind = kindOverride
            ?? SceneKind(rawValue: (json["scene_type"] as? String) ?? "concept")
            ?? .concept

        var components: [SDUIComponent] = []
        var delay = 0
        let step = 450

        func nextDelay() -> Int { defer { delay += step }; return delay }

        if let narration = json["narration"] as? String, !narration.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append(
                SDUIComponent(
                    id: "\(sceneId)_narration",
                    type: .teacherMessage,
                    content: narration,
                    delayMs: nextDelay()
                )
            )
        }

        let blocks = (json["blocks"] as? [[String: Any]]) ?? []
        for (i, block) in blocks.enumerated() {
            let kindStr = (block["kind"] as? String) ?? "text"
            switch kindStr {
            case "code":
                let code = (block["content"] as? String) ?? ""
                if !code.isEmpty {
                    components.append(
                        SDUIComponent(
                            id: "\(sceneId)_code_\(i)",
                            type: .codeBlock,
                            content: code,
                            delayMs: nextDelay()
                        )
                    )
                }
            case "quiz":
                let question = (block["question"] as? String) ?? ""
                let optionStrings = (block["options"] as? [String]) ?? []
                if !question.isEmpty, optionStrings.count >= 2 {
                    let answerIndex = (block["answer_index"] as? Int) ?? 0
                    let explanation = (block["explanation"] as? String) ?? ""
                    let options = optionStrings.enumerated().map { idx, label in
                        SDUIQuizOption(id: "opt_\(idx)", label: label)
                    }
                    var payload: [String: String] = [
                        "answer_index": String(answerIndex),
                        "answer_option_id": "opt_\(answerIndex)"
                    ]
                    if !explanation.isEmpty { payload["explanation"] = explanation }
                    components.append(
                        SDUIComponent(
                            id: "\(sceneId)_quiz_\(i)",
                            type: .quizCard,
                            content: question,
                            delayMs: nextDelay(),
                            question: question,
                            options: options,
                            actionIntent: "quiz_answer",
                            actionPayload: payload
                        )
                    )
                }
            default:  // "text"
                let text = (block["content"] as? String) ?? ""
                if !text.isEmpty {
                    components.append(
                        SDUIComponent(
                            id: "\(sceneId)_text_\(i)",
                            type: .textBlock,
                            content: text,
                            delayMs: nextDelay()
                        )
                    )
                }
            }
        }

        // Guarantee a non-empty scene.
        if components.isEmpty {
            components.append(
                SDUIComponent(
                    id: "\(sceneId)_fallback",
                    type: .teacherMessage,
                    content: "Let's keep going with \(sectionTitle).",
                    delayMs: 0
                )
            )
        }

        return SDUIScene(id: sceneId, sceneType: kind.rawValue, components: components)
    }

    private func fallbackScene(sectionTitle: String) -> SDUIScene {
        let sceneId = "scene_fb_\(totalScenes)_\(UUID().uuidString.prefix(8))"
        return SDUIScene(
            id: sceneId,
            sceneType: SceneKind.concept.rawValue,
            components: [
                SDUIComponent(
                    id: "\(sceneId)_t",
                    type: .teacherMessage,
                    content: "Let's look at \(sectionTitle). Tap Continue and I'll break this down step by step.",
                    delayMs: 0
                )
            ]
        )
    }

    // MARK: - Progression helpers

    private func advanceIfNeeded(forceAdvance: Bool) {
        if forceAdvance || scenesInCurrentSection >= maxScenesPerSection {
            sectionIndex += 1
            scenesInCurrentSection = 0
        }
    }

    private func consumePendingSignalNote() -> String {
        guard let signal = pendingSignal else { return "" }
        pendingSignal = nil
        switch signal.kind {
        case let .answeredQuiz(correct, choice):
            return correct
                ? "ADAPTIVE NOTE: The learner just answered a checkpoint CORRECTLY (chose \"\(choice)\"). Briefly affirm, then raise the depth slightly."
                : "ADAPTIVE NOTE: The learner just answered a checkpoint INCORRECTLY (chose \"\(choice)\"). Gently re-teach that idea a different way before moving on."
        case .confused:
            return "ADAPTIVE NOTE: The learner signaled confusion. Slow down and re-explain the last idea with a simpler analogy."
        case .tooEasy:
            return "ADAPTIVE NOTE: The learner signaled this is too easy. Increase the challenge and pace."
        case let .askedQuestion(q):
            return "ADAPTIVE NOTE: The learner asked: \"\(q)\". Address it as you continue."
        }
    }

    // MARK: - Parsing helpers

    static func parseObject(_ raw: String) -> [String: Any]? {
        guard let data = cleanJSON(raw).data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    static func parseStringArray(_ raw: String) -> [String]? {
        guard let data = cleanJSON(raw).data(using: .utf8) else { return nil }
        if let arr = (try? JSONSerialization.jsonObject(with: data)) as? [String] {
            return arr.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        }
        return nil
    }

    /// Strip markdown code fences and surrounding prose the LLM may add.
    static func cleanJSON(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        s = s.replacingOccurrences(of: "```json", with: "")
        s = s.replacingOccurrences(of: "```", with: "")
        // Extract the outermost JSON object or array if there's leading/trailing text.
        if let start = s.firstIndex(where: { $0 == "{" || $0 == "[" }) {
            let opener = s[start]
            let closer: Character = opener == "{" ? "}" : "]"
            if let end = s.lastIndex(of: closer) {
                s = String(s[start...end])
            }
        }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Fallback outline

    private static func fallbackOutline(for topic: String) -> [String] {
        [
            "Core ideas behind \(topic)",
            "How \(topic) works in practice",
            "A worked example of \(topic)",
            "Common mistakes with \(topic) and how to avoid them",
            "Putting \(topic) together: a small project",
            "Where to go next with \(topic)"
        ]
    }
}

private extension String {
    func ifEmptyShow(_ placeholder: String) -> String {
        trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? placeholder : self
    }
}
