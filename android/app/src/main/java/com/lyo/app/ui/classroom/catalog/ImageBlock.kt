package com.lyo.app.ui.classroom.catalog

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.lyo.app.ui.classroom.a2ui.A2uiRenderScope
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextSecondary

/**
 * A `board` `action: "image"` element — a Coil-loaded photo with a caption/
 * attribution. `url == null` (the backend is still resolving a search
 * result) shows a "finding a picture of…" placeholder instead of a broken
 * image, matching web's BoardElementView.
 */
@Composable
fun A2uiRenderScope.ImageBlockRenderer() {
    val url = resolveString("url")
    val caption = resolveString("caption")
    val query = resolveString("query")
    val attribution = resolveString("attribution")

    Column(modifier = Modifier.padding(vertical = 6.dp)) {
        if (url != null) {
            AsyncImage(
                model = url,
                contentDescription = caption ?: query,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(180.dp)
                    .background(Surface, RoundedCornerShape(12.dp)),
            )
        } else {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .background(Surface, RoundedCornerShape(12.dp))
                    .padding(12.dp),
            ) {
                Text(
                    text = "finding a picture of ${query ?: "this"}…",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                )
            }
        }
        if (caption != null) {
            Text(text = caption, color = TextSecondary, modifier = Modifier.padding(top = 4.dp))
        }
        if (attribution != null) {
            Text(
                text = attribution,
                color = TextSecondary.copy(alpha = 0.6f),
                style = MaterialTheme.typography.labelSmall,
            )
        }
    }
}
