package com.lyo.app.ui.screens.classroom

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.ui.components.LoadingBox

/**
 * Public navigation adapter for the Android classroom.
 *
 * There used to be a second 900-line classroom runtime in this package with
 * its own socket, pacing, grading chrome and voice. Keeping two live teaching
 * engines meant fixes could compile in one while navigation still opened the
 * other. This entry point now resolves only the learner-facing title/course
 * context, then delegates to the single A2UI ClassroomScreen.
 */
@Composable
fun ClassroomScreen(
    nav: NavHostController,
    courseId: String,
    topicOverride: String? = null,
    teachingMode: String = "solo",
) {
    var resolvedTopic by remember(courseId, topicOverride) {
        mutableStateOf(topicOverride)
    }
    var resolved by remember(courseId, topicOverride) {
        mutableStateOf(topicOverride != null)
    }

    LaunchedEffect(courseId, topicOverride) {
        if (topicOverride != null) {
            resolvedTopic = topicOverride
            resolved = true
            return@LaunchedEffect
        }
        val course = runCatching { ApiClient.api.course(courseId) }.getOrNull()
        resolvedTopic = course?.title?.takeIf { it.isNotBlank() } ?: "AI Classroom"
        resolved = true
    }

    if (!resolved) {
        LoadingBox()
        return
    }

    com.lyo.app.ui.classroom.ClassroomScreen(
        nav = nav,
        topic = resolvedTopic ?: "AI Classroom",
        courseId = courseId,
        teachingMode = teachingMode,
        courseBacked = topicOverride == null,
    )
}
