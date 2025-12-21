import Foundation

// MARK: - Mentor Chat Models

enum ResponseMode: String, Codable {
    case chat = "chat"
    case course = "course"
    case explainer = "explainer"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = (try? container.decode(String.self)) ?? "chat"
        switch raw {
        case "chat", "general":
            self = .chat
        case "course", "course_planner", "course_plan":
            self = .course
        case "explainer", "quick_explainer", "quick_explain":
            self = .explainer
        default:
            self = .chat
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(self.rawValue)
    }
}

struct QuickExplainerData: Codable {
    let concept: String
    let explanation: String
    let chips: [String]

    enum CodingKeys: String, CodingKey {
        // Legacy
        case concept
        case explanation
        case chips
        // Chat-module/iOS schema
        case keyPoints = "key_points"
        case relatedTopics = "related_topics"
        case keyPointsCamel = "keyPoints"
        case relatedTopicsCamel = "relatedTopics"
    }

    init(concept: String, explanation: String, chips: [String]) {
        self.concept = concept
        self.explanation = explanation
        self.chips = chips
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // explanation exists in both formats
        explanation = (try? container.decode(String.self, forKey: .explanation)) ?? ""

        // Legacy format provides concept + chips
        if let legacyConcept = try? container.decode(String.self, forKey: .concept) {
            concept = legacyConcept
            chips = (try? container.decode([String].self, forKey: .chips)) ?? []
            return
        }

        // Chat-module format: use relatedTopics/keyPoints as chips and leave concept empty (caller can set)
        let related = (try? container.decode([String].self, forKey: .relatedTopicsCamel))
            ?? (try? container.decode([String].self, forKey: .relatedTopics))
            ?? []
        let keyPoints = (try? container.decode([String].self, forKey: .keyPointsCamel))
            ?? (try? container.decode([String].self, forKey: .keyPoints))
            ?? []

        concept = ""
        chips = !related.isEmpty ? related : keyPoints
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(concept, forKey: .concept)
        try container.encode(explanation, forKey: .explanation)
        try container.encode(chips, forKey: .chips)
    }
}

struct CourseProposalData: Codable {
    let title: String
    let subtext: String
    let summary: String
    let modules: [String]
    let buttonText: String

    enum CodingKeys: String, CodingKey {
        // Legacy
        case title, subtext, summary, modules
        case buttonText = "button_text"
        // Chat-module/iOS schema
        case courseId = "course_id"
        case courseIdCamel = "courseId"
        case description
        case estimatedHours = "estimated_hours"
        case estimatedHoursCamel = "estimatedHours"
        case moduleCount = "module_count"
        case moduleCountCamel = "moduleCount"
        case learningObjectives = "learning_objectives"
        case learningObjectivesCamel = "learningObjectives"
    }

    init(title: String, subtext: String, summary: String, modules: [String], buttonText: String) {
        self.title = title
        self.subtext = subtext
        self.summary = summary
        self.modules = modules
        self.buttonText = buttonText
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Legacy (used by existing tests/UI)
        if let legacyTitle = try? container.decode(String.self, forKey: .title),
           let legacySubtext = try? container.decode(String.self, forKey: .subtext),
           let legacySummary = try? container.decode(String.self, forKey: .summary),
           let legacyModules = try? container.decode([String].self, forKey: .modules) {
            title = legacyTitle
            subtext = legacySubtext
            summary = legacySummary
            modules = legacyModules
            buttonText = (try? container.decode(String.self, forKey: .buttonText)) ?? "Start Now"
            return
        }

        // Chat-module schema
        title = (try? container.decode(String.self, forKey: .title)) ?? "Course"
        let descriptionText = (try? container.decode(String.self, forKey: .description)) ?? ""
        summary = descriptionText

        let hours = (try? container.decode(Double.self, forKey: .estimatedHoursCamel))
            ?? (try? container.decode(Double.self, forKey: .estimatedHours))
        let moduleCount = (try? container.decode(Int.self, forKey: .moduleCountCamel))
            ?? (try? container.decode(Int.self, forKey: .moduleCount))

        if let hours, let moduleCount {
            subtext = String(format: "%.1fh • %d modules", hours, moduleCount)
        } else if let moduleCount {
            subtext = "\(moduleCount) modules"
        } else {
            subtext = ""
        }

        let objectives = (try? container.decode([String].self, forKey: .learningObjectivesCamel))
            ?? (try? container.decode([String].self, forKey: .learningObjectives))
            ?? []
        modules = objectives

        buttonText = "Start Now"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(subtext, forKey: .subtext)
        try container.encode(summary, forKey: .summary)
        try container.encode(modules, forKey: .modules)
        try container.encode(buttonText, forKey: .buttonText)
    }
}

struct MentorMessageResponse: Codable, Identifiable {
    let id: Int // interaction_id
    let response: String
    let responseMode: ResponseMode
    let quickExplainer: QuickExplainerData?
    let courseProposal: CourseProposalData?
    
    enum CodingKeys: String, CodingKey {
        case id = "interaction_id"
        case response
        case responseMode = "response_mode"
        case quickExplainer = "quick_explainer"
        case courseProposal = "course_proposal"
    }
}
