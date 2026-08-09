package com.lyo.app.data.api

import com.google.gson.JsonObject
import com.google.gson.annotations.SerializedName

/**
 * Wire shapes for the real, backend-synced Stack Items API
 * (`/api/v1/stack/items`) — device- and platform-agnostic by design (it's a
 * per-user, not per-device, resource: `lyo_app/stack/models.py`'s
 * `StackItem.user_id`). Field names/types are mirrored exactly from
 * `StackItemResponse`/`StackItemCreate`/`StackItemUpdate` in
 * `lyo_app/stack/routes.py` — that inline schema is what's actually wired
 * into the live router; a separate, differently-shaped `StackItemCreate`/
 * `StackItemRead` in `lyo_app/stack/schemas.py` (using `ref_id`/
 * `source_type`) is NOT used by these endpoints and is deliberately not
 * modeled here.
 */

data class StackItemDto(
    val id: Int,
    @SerializedName("user_id") val userId: Int? = null,
    val title: String,
    val description: String? = null,
    @SerializedName("item_type") val itemType: String,
    val status: String,
    val progress: Float = 0f,
    val priority: Int = 0,
    @SerializedName("content_id") val contentId: String? = null,
    @SerializedName("content_type") val contentType: String? = null,
    @SerializedName("extra_data") val extraData: JsonObject? = null,
    @SerializedName("created_at") val createdAt: String? = null,
    @SerializedName("updated_at") val updatedAt: String? = null,
)

data class CreateStackItemRequest(
    val title: String,
    val description: String? = null,
    @SerializedName("item_type") val itemType: String = "course",
    @SerializedName("content_id") val contentId: String? = null,
    @SerializedName("content_type") val contentType: String? = "course",
    val priority: Int = 0,
    @SerializedName("extra_data") val extraData: JsonObject? = null,
)

/** Server auto-derives `status` from `progress` when present
 *  (`>=1.0` -> completed, `>0` -> in_progress) — see
 *  `lyo_app/stack/crud.py::update_stack_item_progress` — so callers
 *  updating progress normally never need to also set `status`. */
data class UpdateStackItemRequest(
    val title: String? = null,
    val description: String? = null,
    val status: String? = null,
    val progress: Float? = null,
    val priority: Int? = null,
)

data class StackItemListResponse(
    val items: List<StackItemDto> = emptyList(),
    val total: Int = 0,
    val limit: Int = 0,
    val offset: Int = 0,
)
