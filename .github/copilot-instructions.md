# Copilot instructions (Lyo iOS)

## Project Overview
Lyo is an AI-powered learning iOS app built with **SwiftUI**. It uses a SaaS multi-tenant backend and features advanced AI capabilities like real-time course generation, Socratic tutoring, and a custom Server-Driven UI engine called **A2UI**.

## Critical Architectural Rules

### 1. Networking & SaaS Multi-Tenancy
**Strict Rule**: Do NOT use `URLSession.shared.data(for:)` directly.
- **Always** use `NetworkClient.shared.request(Endpoints.Scope.method)` for API calls.
- This ensures critical SaaS headers are injected automatically:
  - `X-API-Key` (from `AppConfig`)
  - `X-Tenant-Id` (from `TokenManager`)
  - `Authorization: Bearer <token>`
- **Endpoints**: Defined in `Sources/Core/Networking/Endpoint.swift`. Add new endpoints there, do not hardcode URL strings in views/services.

### 2. AI Service Architecture
The app has distinct specialized AI services. Use the correct one:
- **`BackendAIService`** (`Sources/Services/BackendAIService.swift`):
  - **Primary Engine**: Uses hybrid AI (Gemini + OpenAI) via backend.
  - **Use for**: Socratic tutoring, complex reasoning, and **A2UI** generation (structured UI responses).
  - **Streaming**: Supports SSE (Server-Sent Events) for real-time text using `NetworkClient.stream()`.
- **`CourseGenerationService`** (`Sources/Services/CourseGenerationService.swift`):
  - **Use for**: Creating full courses. Handles the long-running multi-agent pipeline and streaming progress updates.
- **`OpenAIService`** (`Sources/Services/OpenAIService.swift`):
  - **Use for**: Simple chat interactions or legacy features.
  - **Note**: Never use client-side API keys.

### 3. A2UI (AI-to-UI) Rendering Engine
**A2UI** is the custom Server-Driven UI framework located in `Sources/Core/A2UI`.
- **Logic**: The backend sends structured JSON (`OpenClassroomPayload`) describing UI components.
- **Rendering**: `A2UIRenderer` recursively maps these components to SwiftUI views.
- **Usage**: When adding AI features that need rich UI (charts, quizzes, roadmaps), utilize the A2UI component system.

### 4. Configuration & Environment
- **Source of Truth**: `AppConfig` (`Sources/Core/Configuration/AppConfig.swift`).
- **Secrets**: `Secrets.swift`. Never commit real keys.
- **Feature Flags**: Check `AppConfig` before enabling beta features (e.g. `isVisionEnabled`).
- **Environment**: Use `AppConfig.Environment` to switch between Dev/Staging/Prod.

## Common Patterns

### Repository Pattern
- Data access logic lives in `LyoRepository` (`Sources/Services/LyoRepository.swift`).
- ViewModels should call `LyoRepository` or specific Services, not `NetworkClient` directly if possible.

### ViewModels & Concurrency
- **Specific Rule**: Use `@MainActor` for all ViewModels publishing UI state.
- Prefer `Task` + `await` over completion handlers.

## File Structure Guide
- `Sources/LyoApp.swift`: Entry point, DI container.
- `Sources/Core/`: Foundation (Networking, Security, A2UI, Config).
- `Sources/Services/`: Business logic & API repositories.
- `Sources/Views/`: SwiftUI Views.
- `Sources/ViewModels/`: Logic for Views.
- `Sources/Models/`: Codable structs.

## Testing & Mocks
- **Mock Mode**: Set `LYO_ALLOW_MOCKS=1` in the scheme to enable local mock data (useful for offline dev).
- **Unit Tests**: Locate in `Tests/`.

## Logging + UX expectations
- Console logs commonly use emoji prefixes for key events/errors (e.g. streaming start/stop, failures). Preserve that style when editing adjacent code.
