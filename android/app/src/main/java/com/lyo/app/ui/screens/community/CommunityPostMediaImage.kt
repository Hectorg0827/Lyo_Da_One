package com.lyo.app.ui.screens.community

import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage

/**
 * Preserves the full image and adapts the post height to its real dimensions.
 * This matters for worksheets, diagrams, and tall photographs.
 */
@Composable
internal fun CommunityPostMediaImage(
    mediaUrl: String,
    modifier: Modifier = Modifier,
) {
    var ratio by remember(mediaUrl) { mutableFloatStateOf(1f) }

    AsyncImage(
        model = mediaUrl,
        contentDescription = "Post image",
        contentScale = ContentScale.Fit,
        onSuccess = { success ->
            val size = success.painter.intrinsicSize
            if (size.width.isFinite() && size.height.isFinite() &&
                size.width > 0f && size.height > 0f
            ) {
                ratio = (size.width / size.height).coerceIn(0.45f, 2.5f)
            }
        },
        modifier = modifier.aspectRatio(ratio),
    )
}
