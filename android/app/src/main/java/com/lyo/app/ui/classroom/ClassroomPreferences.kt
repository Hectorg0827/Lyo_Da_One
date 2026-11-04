package com.lyo.app.ui.classroom

import android.content.Context

/**
 * Per-device Classroom presentation preferences; never stores student answers,
 * transcript, API keys, or private learner records.
 * Server-owned progress and saved sessions remain authoritative.
 */
object ClassroomPreferences {
    var reducedMotion: Boolean = false

    private const val STORE = "lyo_classroom_preferences"
    private const val MODE_KEY = "preferred_visual_mode"

    fun savedDisplayMode(context: Context): ClassroomDisplayMode? {
        val value = context.applicationContext.getSharedPreferences(STORE, Context.MODE_PRIVATE)
            .getString(MODE_KEY, null) ?: return null
        return ClassroomDisplayMode.entries.firstOrNull { it.name == value }
    }

    fun saveDisplayMode(context: Context, mode: ClassroomDisplayMode?) {
        val editor = context.applicationContext
            .getSharedPreferences(STORE, Context.MODE_PRIVATE)
            .edit()
        if (mode == null) editor.remove(MODE_KEY) else editor.putString(MODE_KEY, mode.name)
        editor.apply()
    }
}
