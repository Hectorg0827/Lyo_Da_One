package com.lyo.app.data

import android.content.Context

/**
 * Device-local pointer to the last real course route opened on Android.
 *
 * The course title and canonical progress are fetched from the backend when the
 * learner returns to Focus, so stale catalog metadata is never persisted here.
 */
object RecentCourseStore {
    private const val PREFERENCES = "lyo_recent_course"
    private const val KEY_ID = "course_id"
    private const val KEY_OPENED_AT = "opened_at"

    data class RecentCourse(
        val id: String,
        val openedAt: Long,
    )

    fun save(context: Context, courseId: String) {
        if (courseId.isBlank()) return
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ID, courseId)
            .putLong(KEY_OPENED_AT, System.currentTimeMillis())
            .apply()
    }

    fun load(context: Context): RecentCourse? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val id = preferences.getString(KEY_ID, null)?.takeIf { it.isNotBlank() } ?: return null
        return RecentCourse(
            id = id,
            openedAt = preferences.getLong(KEY_OPENED_AT, 0L),
        )
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .clear()
            .apply()
    }
}
