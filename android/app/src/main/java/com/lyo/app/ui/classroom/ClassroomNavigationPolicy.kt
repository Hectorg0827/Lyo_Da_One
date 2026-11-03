package com.lyo.app.ui.classroom

/** Never let display-mode changes or historical review bypass graded checkpoints. */
internal fun canAdvanceLiveLesson(
    reviewingPast: Boolean,
    canContinue: Boolean,
    activeCheckpoint: Boolean,
    failed: Boolean,
    paused: Boolean,
    awaitingResponse: Boolean = false,
): Boolean = !reviewingPast && canContinue && !activeCheckpoint && !failed && !paused && !awaitingResponse
