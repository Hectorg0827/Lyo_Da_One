# A2A Protocol Implementation - Complete Guide

## Overview

The Lyo AI Classroom now uses **Google's A2A (Agent-to-Agent) Protocol** for multi-agent orchestrated course generation. This provides:

- **Specialized Agents**: Each with specific expertise (pedagogy, cinematics, QA, visuals, voice)
- **Self-Describing Discovery**: AgentCards for capability advertisement
- **Real-Time Streaming**: SSE-based progress updates during generation
- **Quality Gates**: Multi-stage validation ensuring educational excellence

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    A2A Course Generation Pipeline                │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  ┌──────────────────┐    ┌──────────────────┐                   │
│  │   iOS Client     │◄──►│   A2A Routes     │                   │
│  │  (A2ACourse     │    │   /api/v2/       │                   │
│  │   Service.swift) │    │   courses/       │                   │
│  └──────────────────┘    └────────┬─────────┘                   │
│                                   │                              │
│                         ┌─────────▼─────────┐                   │
│                         │   Orchestrator    │                   │
│                         │   (Pipeline Mgr)  │                   │
│                         └─────────┬─────────┘                   │
│                                   │                              │
│    ┌──────────────────────────────┼──────────────────────────┐  │
│    │                              │                           │  │
│    ▼                              ▼                           ▼  │
│  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  ┌────────┐  │  │
│  │Pedagogy│  │Cinematic│  │   QA   │  │ Visual │  │ Voice  │  │  │
│  │ Agent  │  │Director │  │Checker │  │Director│  │ Agent  │  │  │
│  └────────┘  └────────┘  └────────┘  └────────┘  └────────┘  │  │
│                                                               │  │
└───────────────────────────────────────────────────────────────┘  │
                                                                    │
└─────────────────────────────────────────────────────────────────┘
```

## Backend Components

### Location
```
/Users/hectorgarcia/Desktop/LyoBackendJune/lyo_app/ai_agents/a2a/
├── __init__.py              # Exports all components
├── schemas.py               # Core A2A protocol schemas
├── base.py                  # A2ABaseAgent generic class
├── pedagogy_agent.py        # Learning science expert
├── cinematic_director_agent.py  # Narrative/scene design
├── qa_checker_agent.py      # Quality validation
├── visual_director_agent.py # Image prompts/diagrams
├── voice_agent.py           # TTS scripts with SSML
├── orchestrator.py          # Pipeline coordination
└── routes.py                # FastAPI endpoints
```

### Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/v2/courses/generate-a2a` | POST | Synchronous course generation |
| `/api/v2/courses/stream-a2a` | POST | SSE streaming generation |
| `/api/v2/courses/status/{pipeline_id}` | GET | Pipeline status polling |
| `/api/v2/agents` | GET | List all agent cards |
| `/api/v2/agents/{agent_name}` | GET | Specific agent card |
| `/api/v2/agents/{agent_name}/execute` | POST | Direct agent execution |
| `/.well-known/agent.json` | GET | A2A protocol discovery |
| `/api/v2/a2a/health` | GET | Health check |

### Pipeline Phases

1. **Initialization** - Setup and validation
2. **Pedagogy Design** - Learning objectives, scaffolding
3. **Cinematic Design** - Scene flow, narrative arc
4. **Quality Check** - Initial validation
5. **Visual Generation** - Image prompts, diagrams
6. **Voice Generation** - TTS scripts with SSML
7. **Final Assembly** - Combine all outputs
8. **Quality Validation** - Final QA gate

## iOS Components

### Location
```
/Users/hectorgarcia/LYO_Da_ONE/Sources/
├── Models/AI/
│   └── A2AModels.swift           # Protocol models
├── Services/
│   └── A2ACourseService.swift    # API client service
└── Views/AI/
    └── A2AGenerationProgressView.swift  # Progress UI
```

### Key Types

**A2AModels.swift:**
- `A2AAgentCard` - Agent discovery with skills
- `A2APipelinePhase` - 8 phases with icons
- `A2APhaseStatus` - Status enum
- `A2AStreamingEvent` - SSE event model
- `A2AGenerateRequest` - Request payload
- `A2ACourseResponse` - Complete response
- `A2AGeneratedCourse` - Course structure
- `CourseQualityTier` - fast/standard/premium

**A2ACourseService.swift:**
- Agent discovery
- Streaming generation with SSE parsing
- Synchronous generation
- Pipeline status polling
- Direct agent execution
- Conversion to legacy format

**A2AGenerationProgressView.swift:**
- Real-time progress visualization
- Phase indicators with status
- Agent handoff animation
- Quality metrics display
- Event debug view

## Usage Examples

### iOS - Streaming Generation

```swift
let service = A2ACourseService.shared

service.generateCourseStreaming(
    topic: "Introduction to Machine Learning",
    qualityTier: .standard,
    enableVisuals: true,
    enableVoice: true
) { event in
    // Handle streaming events
    print("Phase: \(event.phase?.displayName)")
    print("Progress: \(event.progress)%")
}
```

### iOS - Synchronous Generation

```swift
Task {
    let course = try await service.generateCourse(
        topic: "Swift Programming Basics",
        qualityTier: .premium
    )
    print("Generated: \(course.title)")
    print("Modules: \(course.modules.count)")
}
```

### iOS - Agent Discovery

```swift
let agents = try await service.discoverAgents()
for agent in agents {
    print("\(agent.name): \(agent.description)")
}
```

### Backend - Direct API Call

```bash
# Generate course (streaming)
curl -X POST https://your-backend/api/v2/courses/stream-a2a \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "Data Science Fundamentals",
    "quality_tier": "standard",
    "enable_visuals": true,
    "enable_voice": true
  }'

# Get agent cards
curl https://your-backend/api/v2/agents \
  -H "Authorization: Bearer $TOKEN"

# A2A Protocol discovery
curl https://your-backend/.well-known/agent.json
```

## Quality Tiers

| Tier | Time | Features | Use Case |
|------|------|----------|----------|
| **Fast** | ~30s | Basic structure, minimal QA | Quick prototypes |
| **Standard** | ~2m | Full pipeline, balanced quality | Normal courses |
| **Premium** | ~5m | Maximum quality, all features | Production courses |

## Event Types

| Event | Description |
|-------|-------------|
| `pipeline_started` | Pipeline initialization complete |
| `phase_started` | Agent began working |
| `phase_completed` | Agent finished successfully |
| `phase_failed` | Agent encountered error |
| `agent_handoff` | Control passed to next agent |
| `artifact_generated` | Reusable output created |
| `quality_score` | QA score reported |
| `pipeline_completed` | All phases complete |
| `error` | Fatal error occurred |
| `progress` | Progress update |

## Deployment

The A2A routes are automatically registered in `enhanced_main.py`:

```python
# A2A Protocol - Google Agent-to-Agent Course Generation
try:
    from lyo_app.ai_agents.a2a import include_a2a_routes
    include_a2a_routes(app)
    logger.info("✅ A2A Protocol routes integrated")
except ImportError as e:
    logger.warning(f"⚠️ A2A routes not available: {e}")
```

## Testing

### Backend Health Check
```bash
curl https://your-backend/api/v2/a2a/health
# Response: {"status": "healthy", "agents": [...]}
```

### iOS Integration Test
```swift
// Test agent discovery
Task {
    do {
        let agents = try await A2ACourseService.shared.discoverAgents()
        XCTAssertEqual(agents.count, 5) // 5 specialized agents
    } catch {
        XCTFail("Failed: \(error)")
    }
}
```

## Monitoring

The orchestrator tracks:
- Pipeline execution time
- Per-phase duration
- Token usage per agent
- QA scores at each gate
- Error rates and types

These metrics are returned in the `A2APipelineMetrics` response.

## Future Enhancements

1. **Agent Marketplace** - Community-contributed agents
2. **Custom Pipelines** - User-defined agent sequences
3. **Caching Layer** - Redis-backed artifact cache
4. **Parallel Execution** - Run independent agents concurrently
5. **A/B Testing** - Compare pipeline configurations

---

**MIT Architecture Engineering**  
**A2A Protocol Implementation v1.0**  
**Last Updated: January 2025**
