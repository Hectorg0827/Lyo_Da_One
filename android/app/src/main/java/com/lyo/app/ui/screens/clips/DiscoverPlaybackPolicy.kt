package com.lyo.app.ui.screens.clips

internal data class DiscoverPlaybackIntent(
    val selected: Boolean,
    val foreground: Boolean,
    val userPaused: Boolean,
    val scrubbing: Boolean,
) {
    val shouldPlay: Boolean get() = selected && foreground && !userPaused && !scrubbing
}

internal fun nextDiscoverPage(currentPage: Int, finishedPage: Int, count: Int): Int? =
    if (currentPage == finishedPage && finishedPage >= 0 && finishedPage + 1 < count) finishedPage + 1 else null
