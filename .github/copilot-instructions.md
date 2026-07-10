# Copilot instructions (Lyo iOS)

## Big picture
- SwiftUI app entry point is [Sources/LyoApp.swift](../Sources/LyoApp.swift) (AppDelegate config + `LyoApp` root; injects `RootViewModel`, `AppUIState`, `UIStackStore`).
- Most app logic lives under [Sources/](../Sources) split into `Views/`, `ViewModels/`, `Services/`, `Models/`, `Core/`.

## Backend + configuration
- Base URL comes from [Sources/Core/Configuration/AppConfig.swift](../Sources/Core/Configuration/AppConfig.swift) (`AppConfig.baseURL`).
  - Local backend: set env `LYO_USE_LOCALHOST=1` (uses `http://localhost:8000`).
  - Mock fallbacks are OFF by default; enable only when needed with `LYO_ALLOW_MOCKS=1`.
- Do not add client-side API secrets. AI keys live server-side; see [Sources/Core/Configuration/Secrets.swift](../Sources/Core/Configuration/Secrets.swift).
- Auth tokens/tenant/user IDs are stored in Keychain via actor [Sources/Core/Security/TokenManager.swift](../Sources/Core/Security/TokenManager.swift).
- Many requests also include an API key header (`X-API-Key`) sourced from `AppConfig.apiKey` (stored in Keychain). This is wired in [Sources/Core/Networking/NetworkClient.swift](../Sources/Core/Networking/NetworkClient.swift).

## SaaS Multi-Tenant Architecture (IMPORTANT)

This app uses a SaaS multi-tenant backend. **Every API request** must include:

| Header | Source | Required |
|--------|--------|----------|
| `X-API-Key` | `AppConfig.apiKey` | Always |
| `X-Tenant-Id` | `TokenManager.shared.getTenantId()` | When available |
| `Authorization` | `Bearer <token>` | For authenticated endpoints |

### For New Network Code

**Preferred**: Use `NetworkClient.shared.request(Endpoints.*)` — headers are automatic via interceptors.

**If using URLSession directly**: Use the centralized helper:
```swift
await SaaSHeaders.apply(to: &request)
```

Or manually add headers:
```swift
request.setValue(AppConfig.apiKey, forHTTPHeaderField: "X-API-Key")
if let tenantId = await tokenManager.getTenantId() {
    request.setValue(tenantId, forHTTPHeaderField: "X-Tenant-Id")
}
```

### Authentication Flow

Login responses include `tenant_id`. This is persisted via `TokenManager.shared.setTenantId()` and sent on all subsequent requests.

### Services Updated for SaaS
- ✅ `NetworkClient` - Automatic headers via interceptors
- ✅ `StreamingResponseManager` - Headers in `stream()` method
- ✅ `BackendAIService` - Headers in `post()`, `postPublic()`, streaming
- ✅ `OpenAIService` - Headers in `sendBackendMessage()`
- ✅ `CourseGenerationService` - Headers in backend generation methods
- ✅ `LyoRepository` - Captures `tenant_id` from login responses

## Networking conventions (important)
- Prefer the typed endpoint layer when adding/changing API calls:
  - Endpoint definitions live in [Sources/Core/Networking/Endpoint.swift](../Sources/Core/Networking/Endpoint.swift) (`Endpoints.*`).
  - Execution + retries/token refresh live in actor [Sources/Core/Networking/NetworkClient.swift](../Sources/Core/Networking/NetworkClient.swift).
- There is also legacy/direct URLSession code (e.g. [Sources/Services/LyoRepository.swift](../Sources/Services/LyoRepository.swift), [Sources/Services/OpenAIService.swift](../Sources/Services/OpenAIService.swift)). When touching these, keep the existing style, but for new work prefer `Endpoints` + `NetworkClient` unless the surrounding module already standardizes on URLSession.
- Paths are not uniformly prefixed with `/api`; follow existing endpoint constants (e.g. `Endpoints.Auth.*` uses `/auth/...` while many feature APIs use `/api/v1/...`). Avoid inventing new baseURL + "/api" concatenations.

## AI + streaming patterns
- Backend AI is the source of truth; route AI through backend endpoints (no client OpenAI key).
- Streaming/SSE patterns exist:
  - [Sources/Services/BackendAIService.swift](../Sources/Services/BackendAIService.swift) streams `/api/v1/ai/chat/stream` and parses `data:` SSE lines.
  - [Sources/Services/CourseGenerationService.swift](../Sources/Services/CourseGenerationService.swift) streams bytes from `/api/content/generate-course/stream` and updates `@Published` progress on `MainActor`.
- Service singletons are common (`static let shared`) and many are `@MainActor` when they own `@Published` UI state.

## Build / run / test workflows
- Primary workflow is Xcode + iOS simulator (`Lyo.xcodeproj`, scheme `Lyo`). VS Code tasks are defined in [/.vscode/tasks.json](../.vscode/tasks.json):
  - `Xcodebuild iOS Simulator`
  - `Build+Install Lyo (Simulator)` (boots a fixed simulator UDID, builds to DerivedData, installs + launches `com.lyo.app`).
- Tests exist as XCTest files in [/Tests](../Tests) and as an SPM test target at [Sources/Tests](../Sources/Tests). Prefer adding tests alongside existing ones.

## Logging + UX expectations
- Console logs commonly use emoji prefixes for key events/errors (e.g. streaming start/stop, failures). Preserve that style when editing adjacent code.
