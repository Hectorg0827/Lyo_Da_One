import Foundation

// MARK: - Course Stack Sync Models
//
// The REAL backend contract for `/api/v1/stack/items` — verified directly
// against lyo_app/stack/routes.py's inline Pydantic schemas (StackItemCreate/
// StackItemUpdate/StackItemResponse/StackItemListResponse), which are what
// those routes actually validate against. This is deliberately a separate,
// parallel model set from StackModels.swift's StackItem/StackItemType/
// CreateStackItemRequest/UpdateStackItemRequest, which target a DIFFERENT
// shape — lyo_app/stack/schemas.py's `ref_id`/`context_data`/
// active-completed-archived shape, which the real routes do not use at all.
// That mismatch means StackService/CreateViewModel.addToStack/
// AICommandHandler.addToStack/ProfileView/CourseLibraryService's existing
// calls into `/api/v1/stack/items` already send/expect the wrong shape
// (wrong enum raw values, wrong response envelope — the real endpoint
// returns `{items, total, limit, offset}`, not a bare array) and would fail
// against the real backend today. Fixing those call sites is a separate,
// larger change; this file intentionally only adds the correctly-shaped
// surface UIStackStore's course sync needs, without touching the existing
// (already broken) ones.

/// Matches StackItemResponse exactly. `extra_data`/`started_at`/
/// `completed_at` are omitted — Codable silently ignores JSON keys with no
/// matching property, so decoding still succeeds; this sync path never
/// needs them.
struct BackendStackItem: Codable {
    let id: Int
    let userId: Int
    let title: String
    let description: String?
    let itemType: String
    let status: String
    let progress: Double
    let priority: Int
    let contentId: String?
    let contentType: String?
    let createdAt: Date?
    let updatedAt: Date?
}

/// Matches StackItemListResponse exactly.
struct BackendStackItemListResponse: Codable {
    let items: [BackendStackItem]
    let total: Int
    let limit: Int
    let offset: Int
}

/// Matches StackItemCreate. Always `item_type`/`content_type` == "course"
/// for this sync path.
struct CreateBackendStackItemRequest: Codable {
    let title: String
    let itemType: String
    let contentId: String
    let contentType: String
}

/// Matches StackItemUpdate — only `progress` is ever sent here. `status` is
/// derived server-side from `progress` (see crud.py's
/// update_stack_item_progress: >=1.0 → completed, >0 → in_progress), so it
/// is deliberately never included.
struct UpdateBackendStackItemProgressRequest: Codable {
    let progress: Double
}
