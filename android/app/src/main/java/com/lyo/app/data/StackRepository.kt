package com.lyo.app.data

import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CreateStackItemRequest
import com.lyo.app.data.api.StackItemDto
import com.lyo.app.data.api.UpdateStackItemRequest

/**
 * Client-side logic over the real, backend-synced `/api/v1/stack/items`
 * API (see StackApiService.kt/StackDtos.kt) — the device- and
 * platform-agnostic replacement for RecentCourseStore's single-slot,
 * device-local pointer. A plain `object`, matching this app's established
 * no-DI convention (TokenManager, RecentCourseStore, ClassroomPreferences).
 *
 * The backend has no upsert-by-course semantics (`POST /items` always
 * inserts a new row — confirmed by reading `lyo_app/stack/crud.py`
 * directly, not assumed) — every write here does its own client-side
 * "does a stack item already exist for this course" check via `GET
 * /items` filtered to `item_type=course`, matching `content_id` against
 * the course id. This is the same shape of lookup iOS's local
 * `UIStackStore.upsertCourse` does against its own in-memory list, just
 * now against the real backend list instead of `UserDefaults`.
 *
 * Every function is `runCatching`-wrapped internally and returns null/no-
 * ops on failure rather than throwing — a failed stack sync must never
 * crash or block the classroom/course UI, matching this codebase's
 * resilience-over-crash convention throughout (JsonPointer.resolvePointer,
 * ClassroomServerEvent.parseServerEvent, HomeScreen's `runCatching {
 * ApiClient.api...}` calls).
 */
object StackRepository {

    private const val ITEM_TYPE_COURSE = "course"

    private suspend fun findCourseStackItem(courseId: String): StackItemDto? =
        runCatching { ApiClient.stack.items(itemType = ITEM_TYPE_COURSE, limit = 100) }
            .getOrNull()
            ?.items
            ?.firstOrNull { it.contentId == courseId }

    /** Called the moment a classroom session starts for `courseId` (see
     *  LyoNavHost's `Routes.CLASSROOM` composable and CourseDetailScreen's
     *  "Start Class" button) — creates a fresh stack entry if none exists
     *  yet for this course, or returns the existing one unchanged if it
     *  does (resuming a course must not spawn a duplicate stack card). */
    suspend fun upsertCourseOnStart(courseId: String, title: String): StackItemDto? {
        if (courseId.isBlank()) return null
        findCourseStackItem(courseId)?.let { return it }
        return runCatching {
            ApiClient.stack.createItem(
                CreateStackItemRequest(
                    title = title.ifBlank { "Course" },
                    itemType = ITEM_TYPE_COURSE,
                    contentId = courseId,
                    contentType = ITEM_TYPE_COURSE,
                ),
            )
        }.getOrNull()
    }

    /** Called as lesson/turn progress arrives (ClassroomEngine's
     *  `ProgressBar` component handling; CourseDetailScreen's lesson-
     *  completion flow) — `progress` is a 0f..1f fraction. The backend
     *  auto-derives `status` from this (see UpdateStackItemRequest's doc
     *  comment), so this never needs to send status itself. */
    suspend fun updateCourseProgress(courseId: String, progress: Float) {
        if (courseId.isBlank()) return
        val item = findCourseStackItem(courseId) ?: return
        runCatching {
            ApiClient.stack.updateItem(item.id, UpdateStackItemRequest(progress = progress.coerceIn(0f, 1f)))
        }
    }

    /** The Focus/Home tab's "Your Stacks" list — every saved course,
     *  most-recently-touched first. The backend sorts by
     *  `priority, created_at` (see routes.py/crud.py), NOT `updated_at`,
     *  so recency ordering is re-applied here client-side. */
    suspend fun listCourseStacks(): List<StackItemDto> =
        runCatching { ApiClient.stack.items(itemType = ITEM_TYPE_COURSE, limit = 50) }
            .getOrNull()
            ?.items
            ?.sortedByDescending { it.updatedAt ?: it.createdAt ?: "" }
            ?: emptyList()
}
