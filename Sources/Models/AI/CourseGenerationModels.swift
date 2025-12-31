import Foundation

// MARK: - Quality Tier

/// User-selectable quality tiers for course generation
enum QualityTier: String, Codable, CaseIterable {
    case ultra = "ultra"
    case balanced = "balanced"
    case fast = "fast"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .ultra: return "Ultra Quality"
        case .balanced: return "Balanced"
        case .fast: return "Fast & Economical"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .ultra:
            return "Maximum quality using Gemini 2.5 Pro for all generation steps"
        case .balanced:
            return "Optimal balance of quality and cost (Recommended)"
        case .fast:
            return "Fastest generation with lowest cost using Gemini 1.5 Flash"
        case .custom:
            return "Customize model selection per agent"
        }
    }
    
    var icon: String {
        switch self {
        case .ultra: return "star.fill"
        case .balanced: return "star.leadinghalf.filled"
        case .fast: return "bolt.fill"
        case .custom: return "slider.horizontal.3"
        }
    }
    
    var estimatedCost: Double {
        switch self {
        case .ultra: return 0.20
        case .balanced: return 0.12
        case .fast: return 0.05
        case .custom: return 0.12
        }
    }
    
    var estimatedTimeSec: Int {
        switch self {
        case .ultra: return 45
        case .balanced: return 35
        case .fast: return 25
        case .custom: return 35
        }
    }
    
    var color: String {
        switch self {
        case .ultra: return "purple"
        case .balanced: return "blue"
        case .fast: return "green"
        case .custom: return "orange"
        }
    }
}

// MARK: - Course Generation Options

/// Configuration options for course generation
struct CourseGenerationOptions: Codable {
    var qualityTier: QualityTier = .balanced
    var includeCodeExamples: Bool = true
    var includePracticeExercises: Bool = true
    var includeFinalQuiz: Bool = true
    var includeMultimediaSuggestions: Bool = true
    var qaStrictness: String = "standard"
    var maxBudgetUSD: Double? = nil
    var targetLanguage: String = "en"
    
    enum CodingKeys: String, CodingKey {
        case qualityTier = "quality_tier"
        case includeCodeExamples = "enable_code_examples"
        case includePracticeExercises = "enable_practice_exercises"
        case includeFinalQuiz = "enable_final_quiz"
        case includeMultimediaSuggestions = "enable_multimedia_suggestions"
        case qaStrictness = "qa_strictness"
        case maxBudgetUSD = "max_budget_usd"
        case targetLanguage = "target_language"
    }
    
    /// Estimated cost based on current settings
    var estimatedCost: Double {
        var cost = qualityTier.estimatedCost
        
        if !includeCodeExamples { cost *= 0.85 }
        if !includePracticeExercises { cost *= 0.90 }
        if !includeFinalQuiz { cost *= 0.95 }
        
        return cost
    }
    
    /// Estimated time in seconds
    var estimatedTimeSec: Int {
        var time = qualityTier.estimatedTimeSec
        
        if !includeCodeExamples { time = Int(Double(time) * 0.90) }
        if !includePracticeExercises { time = Int(Double(time) * 0.95) }
        if !includeFinalQuiz { time = Int(Double(time) * 0.98) }
        
        return time
    }
    
    /// Default recommended settings
    static var recommended: CourseGenerationOptions {
        return CourseGenerationOptions()
    }
    
    /// Fast/economical settings
    static var economical: CourseGenerationOptions {
        return CourseGenerationOptions(
            qualityTier: .fast,
            includeCodeExamples: true,
            includePracticeExercises: false,
            includeFinalQuiz: false,
            includeMultimediaSuggestions: false
        )
    }
    
    /// Premium settings
    static var premium: CourseGenerationOptions {
        return CourseGenerationOptions(
            qualityTier: .ultra,
            includeCodeExamples: true,
            includePracticeExercises: true,
            includeFinalQuiz: true,
            includeMultimediaSuggestions: true,
            qaStrictness: "strict"
        )
    }
}

// MARK: - Cost Estimate

/// Response from cost estimation endpoint
struct CostEstimate: Codable {
    let estimatedCostUSD: Double
    let estimatedGenerationTimeSec: Int
    let qualityTier: String
    let breakdown: CostBreakdown?
    let recommendations: [String]
    
    enum CodingKeys: String, CodingKey {
        case estimatedCostUSD = "estimated_cost_usd"
        case estimatedGenerationTimeSec = "estimated_generation_time_sec"
        case qualityTier = "quality_tier"
        case breakdown
        case recommendations
    }
    
    var formattedCost: String {
        return String(format: "$%.4f", estimatedCostUSD)
    }
    
    var formattedTime: String {
        let minutes = estimatedGenerationTimeSec / 60
        let seconds = estimatedGenerationTimeSec % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct CostBreakdown: Codable {
    let tierInfo: TierInfo?
    let featureAdjustments: [String]?
    let lessonCountFactor: Double?
    let agentCosts: [String: AgentCost]?
    
    enum CodingKeys: String, CodingKey {
        case tierInfo = "tier_info"
        case featureAdjustments = "feature_adjustments"
        case lessonCountFactor = "lesson_count_factor"
        case agentCosts = "agent_costs"
    }
}

struct TierInfo: Codable {
    let name: String
    let description: String
    let estimatedCostUSD: Double
    let generationTimeEstimateSec: Int
    let bestFor: String
    
    enum CodingKeys: String, CodingKey {
        case name
        case description
        case estimatedCostUSD = "estimated_cost_usd"
        case generationTimeEstimateSec = "generation_time_estimate_sec"
        case bestFor = "best_for"
    }
}

struct AgentCost: Codable {
    let model: String
    let tokens: Int
    let costUSD: Double
    
    enum CodingKeys: String, CodingKey {
        case model
        case tokens
        case costUSD = "cost_usd"
    }
}

// MARK: - Cost Estimate Request

struct CostEstimateRequest: Codable {
    let topic: String
    let qualityTier: String
    let enableCodeExamples: Bool
    let enablePracticeExercises: Bool
    let enableFinalQuiz: Bool
    let estimatedLessonCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case topic
        case qualityTier = "quality_tier"
        case enableCodeExamples = "enable_code_examples"
        case enablePracticeExercises = "enable_practice_exercises"
        case enableFinalQuiz = "enable_final_quiz"
        case estimatedLessonCount = "estimated_lesson_count"
    }
    
    init(topic: String, options: CourseGenerationOptions, estimatedLessonCount: Int? = nil) {
        self.topic = topic
        self.qualityTier = options.qualityTier.rawValue
        self.enableCodeExamples = options.includeCodeExamples
        self.enablePracticeExercises = options.includePracticeExercises
        self.enableFinalQuiz = options.includeFinalQuiz
        self.estimatedLessonCount = estimatedLessonCount
    }
}
