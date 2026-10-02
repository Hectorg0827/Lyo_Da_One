package com.lyo.app.ui.screens.classroom

import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.ui.classroom.ClassroomScreen as A2UIClassroomScreen
import com.lyo.app.ui.components.LoadingBox

/**
 * Compatibility entry point for existing navigation.
 *
 * Android previously carried two independent live-classroom runtimes:
 * this package owned one controller while ui.classroom owned the A2UI
 * turn queue. That split meant fixes to pacing, interruption, evidence,
 * visuals, or review mode could compile without reaching the routed screen.
 *
 * Navigation continues to call this stable function, but all teaching now
 * runs through the single A2UI ClassroomScreen.
 */
@Composable
fun ClassroomScreen(
    nav: NavHostController,
    courseId: String,
    topicOverride: String? = null,
    teachingMode: String = "solo",
) {
    var topic by remember(courseId, topicOverride) { mutableStateOf(topicOverride) }
    var resolved by remember(courseId, topicOverride) {
        mutableStateOf(topicOverride != null)
    }

    LaunchedEffect(courseId, topicOverride) {
        if (topicOverride != null) {
            topic = topicOverride
            resolved = true
        } else {
            val course = runCatching { ApiClient.api.course(courseId) }.getOrNull()
            topic = course?.title ?: "AI Classroom"
            resolved = true
        }
    }

    if (!resolved) {
        LoadingBox()
        return
    }

    A2UIClassroomScreen(
        nav = nav,
        topic = topic ?: "AI Classroom",
        courseId = courseId,
        teachingMode = teachingMode,
        courseBacked = topicOverride == null,
    )
}
