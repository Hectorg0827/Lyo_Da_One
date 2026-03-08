//
//  A2IPayloadMapper.swift
//  Lyo
//
//  Utility to map OpenClassroom A2UI payload components into the
//  renderer-facing `A2UIComponent` struct used by `A2UIRenderer`.
//

import Foundation

/// Mapper that translates backend OpenClassroom components into A2UI renderer components
struct A2IPayloadMapper {

    /// Map an OpenClassroomPayload (from OpenClassroomCommand) into renderer components
    static func mapComponents(from payload: OpenClassroomCommand.OpenClassroomPayload)
        -> [A2UIComponent]
    {
        guard let comps = payload.components else { return [] }
        return comps.compactMap { mapComponent($0) }
    }

    /// Map a single payload component into a renderer component.
    /// Supports text, image, media (video/gif), chart, quiz, roadmap.
    static func mapComponent(_ comp: OpenClassroomCommand.OpenClassroomComponent) -> A2UIComponent?
    {
        switch comp {
        case .text(let t):
            var props = A2UIProps()
            props.text = t.text
            props.body = t.text
            props.title = nil
            return A2UIComponent(type: .text, props: props)

        case .image(let i):
            var props = A2UIProps()
            props.imageUrl = i.url.absoluteString
            props.altText = i.alt
            props.thumbnailUrl = i.url.absoluteString
            props.aspectRatio = i.aspectRatio
            props.helperText = i.caption
            return A2UIComponent(type: .image, props: props)

        case .media(let m):
            var props = A2UIProps()
            switch m.type {
            case .video:
                props.videoUrl = m.url.absoluteString
                props.thumbnailUrl = m.posterURL?.absoluteString
                props.autoplay = m.autoplay
                props.controls = m.controls
                return A2UIComponent(type: .video, props: props)
            case .gif:
                props.imageUrl = m.url.absoluteString
                props.thumbnailUrl = m.posterURL?.absoluteString
                return A2UIComponent(type: .gif, props: props)
            }

        case .chart(let c):
            var props = A2UIProps()
            props.title = c.chartType.replacingOccurrences(of: "_", with: " ").capitalized
            props.helperText = "AI-generated visual summary"
            // Encode chart data as debugInfo / documentContent for renderer to consume
            if let json = try? jsonString(from: c.data) {
                props.debugInfo = "chart:\(c.chartType):\(json)"
                props.documentContent = json
            }
            return A2UIComponent(type: .chart, props: props)

        case .quiz(let q):
            var props = A2UIProps()
            props.intent = "quiz"
            props.title = q.title ?? "Knowledge Check"
            props.body = q.description
            props.question = q.title ?? q.description ?? (q.questionPool.first?.prompt ?? "")
            props.shuffleOptions = q.shuffle
            props.maxAttempts = q.maxQuestions
            props.helperText = "Answer the question below to check your understanding."
            // Map options from first question when available
            if let first = q.questionPool.first {
                props.options = first.choices?.map { choice in
                    A2UIQuizOption(id: choice.id, text: choice.text, imageUrl: nil, isCorrect: nil)
                }
                props.explanation = first.explanation
                // Put correct answers if present
                if let correctIds = first.answer?.correctChoiceIds {
                    props.correctAnswers = correctIds.map { .string($0) }
                }
            }
            // Choose a reasonable quiz element type
            let quizType: A2UIElementType = {
                if let first = q.questionPool.first {
                    switch first.type {
                    case .mcq: return .quizMcq
                    case .tf: return .quizTrueFalse
                    default: return .quizShortAnswer
                    }
                }
                return .quizMcq
            }()
            return A2UIComponent(type: quizType, props: props)

        case .roadmap(let r):
            var props = A2UIProps()
            props.title = r.title
            props.subtitle = r.etaSeconds.map { "ETA \($0 / 60)m" }
            props.helperText = "Your generated syllabus is being assembled module by module."
            props.objectives = r.milestones.map { $0.title }
            props.milestones = r.milestones.map { m in
                A2UIMilestone(
                    id: m.id, title: m.title, description: m.description, targetDate: nil,
                    isCompleted: (m.percent ?? 0) >= 100, xpReward: nil)
            }
            props.progress = r.percent
            props.progressPercent = r.percent
            return A2UIComponent(type: .courseRoadmap, props: props)

        case .rawPayload:
            return nil
        }
    }

    // MARK: - Helpers
    private static func jsonString(from dict: [String: AnyCodable]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        let wrapper = AnyCodableWrapper(value: dict)
        let data = try encoder.encode(wrapper)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

// Helper wrapper to encode dictionary of AnyCodable into JSON string
private struct AnyCodableWrapper: Codable {
    let value: [String: AnyCodable]

    init(value: [String: AnyCodable]) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.value = try container.decode([String: AnyCodable].self)
    }
}

// MARK: - Example Usage
extension A2IPayloadMapper {
    /// Decode an OpenClassroom payload from JSON and map to renderer components.
    /// Returns nil on decode failure.
    static func mapFromJSON(_ data: Data) -> [A2UIComponent]? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            let envelope = try decoder.decode(OpenClassroomEnvelope.self, from: data)
            return mapComponents(from: envelope.payload)
        } catch {
            // Try decoding as raw payload shape
            if let payload = try? decoder.decode(
                OpenClassroomCommand.OpenClassroomPayload.self, from: data)
            {
                return mapComponents(from: payload)
            }
            print("A2IPayloadMapper.mapFromJSON decode failed: \(error)")
            return nil
        }
    }
}

// Local helper envelope type for JSON decoding in example function
private struct OpenClassroomEnvelope: Codable {
    let type: String
    let payload: OpenClassroomCommand.OpenClassroomPayload
}
