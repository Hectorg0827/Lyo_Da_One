//
//  AgentCardService.swift
//  Lyo
//
//  Google A2A Protocol - Agent Card Discovery
//

import Foundation
import os

// Note: A2AAgentCard, A2ACapabilities, A2AAuthentication, A2ASkill, A2AExample
// are defined in A2AModels.swift


// MARK: - Agent Card Service

@MainActor
final class AgentCardService {
    static let shared = AgentCardService()
    
    private var cachedAgentCards: [String: A2AAgentCard] = [:]
    private let baseURL = AppConfig.baseURL
    
    private init() {}
    
    // MARK: - Discover Agent
    
    /// Discover an agent's capabilities via the /.well-known/agent.json endpoint
    func discoverAgent(at url: String) async throws -> A2AAgentCard {
        // Check cache first
        if let cached = cachedAgentCards[url] {
            return cached
        }
        
        // A2A spec: Agent cards are at /.well-known/agent.json
        let agentCardURL = url.hasSuffix("/") ? "\(url).well-known/agent.json" : "\(url)/.well-known/agent.json"
        
        // Using NetworkClient for requests - we'll need to adapt this if DynamicEndpoint isn't available
        // Assuming simple URLSession for now if DynamicEndpoint is complex to infer from context
        
        guard let requestURL = URL(string: agentCardURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, 
              (200...299).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        
        let agentCard = try JSONDecoder().decode(A2AAgentCard.self, from: data)
        
        // Cache it
        cachedAgentCards[url] = agentCard
        
        Log.ai.info("Discovered A2A agent: \(agentCard.name) with \(agentCard.skills.count) skills")
        
        return agentCard
    }
    
    /// Get Lyo's own agent card (for other agents to discover us)
    func getLyoAgentCard() -> A2AAgentCard {
        return A2AAgentCard(
            name: "Lyo Learning Agent",
            description: "AI-powered personal learning mentor that creates courses, quizzes, and provides tutoring",
            url: baseURL,
            provider: A2AAgentProvider(
                organization: "Lyo AI",
                url: baseURL
            ),
            version: AppConfig.version,
            capabilities: A2AAgentCapabilities(
                streaming: true,
                pushNotifications: true,
                batchProcessing: false
            ),
            skills: [
                A2AAgentSkill(
                    id: "course_generation",
                    name: "Course Generation",
                    description: "Generate personalized learning courses on any topic",
                    inputModes: ["text"],
                    outputModes: ["application/json"]
                ),
                A2AAgentSkill(
                    id: "quiz_generation",
                    name: "Quiz Generation",
                    description: "Generate quizzes and assessments",
                    inputModes: ["text"],
                    outputModes: ["application/json"]
                ),
                A2AAgentSkill(
                    id: "tutoring",
                    name: "AI Tutoring",
                    description: "Socratic-style tutoring and explanations",
                    inputModes: ["text"],
                    outputModes: ["text"]
                ),
                A2AAgentSkill(
                    id: "answer_verification",
                    name: "Answer Verification",
                    description: "Verify and explain quiz answers",
                    inputModes: ["application/json"],
                    outputModes: ["application/json"]
                )
            ],
            authentication: A2AAuthentication(
                schemes: ["bearer", "api_key"],
                credentials: nil
            )
        )
    }
    
    /// Clear cached agent cards
    func clearCache() {
        cachedAgentCards.removeAll()
    }
}
