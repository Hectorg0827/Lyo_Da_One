package com.lyo.app.ui.screens.clips

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ClipDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.theme.LyoPink
import kotlinx.coroutines.launch

@Composable
fun ClipsScreen(nav: NavHostController) {
    var clips by remember { mutableStateOf<List<ClipDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var likedIds by remember { mutableStateOf(setOf<String>()) }
    var savedIds by remember { mutableStateOf(setOf<String>()) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        val discovered = runCatching { ApiClient.api.discoverClips(1, 20).clips.orEmpty() }
            .getOrDefault(emptyList())
        clips = if (discovered.isNotEmpty()) {
            discovered
        } else {
            runCatching { ApiClient.api.clips(1, 20).clips.orEmpty() }
                .getOrDefault(emptyList())
        }
        loading = false
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        when {
            loading -> LoadingBox()
            clips.isEmpty() -> Column(modifier = Modifier.statusBarsPadding()) {
                ClipsHeader()
                EmptyState(
                    title = "No clips yet",
                    subtitle = "Educational clips will appear here",
                )
            }
            else -> {
                val pagerState = rememberPagerState(pageCount = { clips.size })

                LaunchedEffect(pagerState.currentPage) {
                    val clip = clips.getOrNull(pagerState.currentPage)
                    if (clip != null) {
                        runCatching { ApiClient.api.viewClip(clip.idStr) }
                    }
                }

                VerticalPager(
                    state = pagerState,
                    modifier = Modifier.fillMaxSize(),
                ) { page ->
                    val clip = clips[page]
                    val id = clip.idStr
                    ClipPage(
                        clip = clip,
                        index = page,
                        liked = id in likedIds,
                        saved = id in savedIds,
                        likeCount = (clip.likeCount ?: 0) + (if (id in likedIds) 1 else 0),
                        onLike = {
                            if (id !in likedIds) {
                                likedIds = likedIds + id
                                scope.launch { runCatching { ApiClient.api.likeClip(id) } }
                            }
                        },
                        onSave = {
                            if (id !in savedIds) {
                                savedIds = savedIds + id
                                scope.launch { runCatching { ApiClient.api.saveClip(id) } }
                            }
                        },
                    )
                }

                ClipsHeader(
                    modifier = Modifier
                        .align(Alignment.TopCenter)
                        .statusBarsPadding(),
                )
            }
        }
    }
}

@Composable
private fun ClipsHeader(modifier: Modifier = Modifier) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        Text(
            "Clips",
            style = MaterialTheme.typography.headlineMedium,
            color = Color.White,
        )
    }
}

@Composable
private fun ClipPage(
    clip: ClipDto,
    index: Int,
    liked: Boolean,
    saved: Boolean,
    likeCount: Int,
    onLike: () -> Unit,
    onSave: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        if (!clip.thumbnailUrl.isNullOrBlank()) {
            AsyncImage(
                model = clip.thumbnailUrl,
                contentDescription = clip.title ?: "Clip",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .background(CardGradients[index % CardGradients.size]),
            )
        }

        // Bottom scrim
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(220.dp)
                .align(Alignment.BottomCenter)
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Transparent, Color.Black.copy(alpha = 0.75f))
                    )
                ),
        )

        // Bottom-left info overlay
        Column(
            modifier = Modifier
                .align(Alignment.BottomStart)
                .fillMaxWidth(0.75f)
                .padding(start = 16.dp, bottom = 24.dp),
        ) {
            Text(
                clip.title ?: "Untitled Clip",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (!clip.description.isNullOrBlank()) {
                Spacer(Modifier.height(4.dp))
                Text(
                    clip.description,
                    style = MaterialTheme.typography.bodyMedium,
                    color = Color.White.copy(alpha = 0.85f),
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (!clip.subject.isNullOrBlank()) {
                Spacer(Modifier.height(8.dp))
                Box(
                    modifier = Modifier
                        .background(
                            Color.White.copy(alpha = 0.15f),
                            RoundedCornerShape(50),
                        )
                        .padding(horizontal = 10.dp, vertical = 4.dp),
                ) {
                    Text(
                        clip.subject,
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White,
                    )
                }
            }
        }

        // Right-side action rail
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 10.dp, bottom = 32.dp),
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onLike) {
                    Icon(
                        if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = "Like",
                        tint = if (liked) LyoPink else Color.White,
                        modifier = Modifier.size(30.dp),
                    )
                }
                Text(
                    likeCount.toString(),
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White,
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onSave) {
                    Icon(
                        if (saved) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                        contentDescription = "Save",
                        tint = Color.White,
                        modifier = Modifier.size(28.dp),
                    )
                }
                Text(
                    if (saved) "Saved" else "Save",
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White,
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Outlined.Visibility,
                    contentDescription = "Views",
                    tint = Color.White,
                    modifier = Modifier.size(26.dp),
                )
                Spacer(Modifier.height(4.dp))
                Text(
                    (clip.viewCount ?: 0).toString(),
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White,
                )
            }
        }
    }
}
