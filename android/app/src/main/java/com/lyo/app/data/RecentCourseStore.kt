package com.lyo.app.data

import android.content.Context

/**
 * Device-local pointer to the last real course opened on Android.
 *
 * This is deliberately not presented as cross-device enrollment data. The
 * course player rehydrates canonical progress from the backend whenever the
 * stored course is opened.
 */
object RecentCourseStore {
    private const val PREFERENCES = "lyo_recent_course"
    private const val KEY_ID = "course_id"
    private const val KEY_TITLE = "course_title"
    private const val KEY_OPENED_AT = "opened_at"

    data class RecentCourse(
        val id: String,
        val title: String,
        val openedAt: Long,
    )

    fun save(context: Context, courseId: String, title: String) {
        if (courseId.isBlank()) return
        context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_ID, courseId)
            .putString(KEY_TITLE, title.trim().ifEmpty { "Course" })
            .putLong(KEY_OPENED_AT, System.currentTimeMillis())
            .apply()
    }

    fun load(context: Context): RecentCourse? {
        val preferences = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
        val id = preferences.getString(KEY_ID, null)?.takeIf { it.isNotBlank() } ?: return null
        return RecentCourse(
            id = id,
            title = preferences.getString(KEY_TITLE, null)?.takeIf { it.isNotBlank() } ?: "Course",
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
