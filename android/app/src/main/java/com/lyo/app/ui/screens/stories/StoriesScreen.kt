package com.lyo.app.ui.screens.stories

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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.StoryDto
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.TextPrimary
import androidx.compose.foundation.gestures.detectTapGestures
import kotlinx.coroutines.launch

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoriesScreen(nav: NavHostController) {
    var stories by remember { mutableStateOf<List<StoryDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var currentIndex by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.stories() }
            .onSuccess { stories = it.stories.orEmpty() }
        loading = false
    }

    if (loading) {
        LoadingBox(modifier = Modifier.background(Color.Black))
        return
    }

    if (stories.isEmpty()) {
        Scaffold(
            containerColor = Background,
            topBar = {
                TopAppBar(
                    title = { Text("Stories") },
                    navigationIcon = {
                        IconButton(onClick = { nav.popBackStack() }) {
                            Icon(
                                Icons.AutoMirrored.Filled.ArrowBack,
                                contentDescription = "Back",
                                tint = TextPrimary,
                            )
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(
                        containerColor = Background,
                        titleContentColor = TextPrimary,
                    ),
                )
            },
        ) { padding ->
            EmptyState(
                title = "No stories yet",
                subtitle = "Stories from people you follow will appear here",
                modifier = Modifier.padding(padding),
            )
        }
        return
    }

    val story = stories[currentIndex.coerceIn(0, stories.lastIndex)]

    fun markSeen(s: StoryDto) {
        scope.launch { runCatching { ApiClient.api.markStorySeen(s.idStr) } }
    }

    fun goNext() {
        markSeen(story)
        if (currentIndex < stories.lastIndex) {
            currentIndex++
        } else {
            nav.popBackStack()
        }
    }

    fun goPrevious() {
        if (currentIndex > 0) currentIndex--
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black)
            .pointerInput(currentIndex, stories.size) {
                detectTapGestures { offset ->
                    if (offset.x < size.width / 3f) goPrevious() else goNext()
                }
            },
    ) {
        // Media / gradient background
        if (!story.mediaUrl.isNullOrBlank()) {
            AsyncImage(
                model = story.mediaUrl,
                contentDescription = story.caption ?: "Story",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .fillMaxSize()
                    .background(CardGradients[currentIndex % CardGradients.size]),
            ) {
                if (!story.caption.isNullOrBlank()) {
                    Text(
                        story.caption,
                        style = MaterialTheme.typography.headlineMedium,
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 32.dp),
                    )
                }
            }
        }

        // Top overlay: progress bars + author row
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Black.copy(alpha = 0.6f), Color.Transparent)
                    )
                )
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                stories.forEachIndexed { i, _ ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(3.dp)
                            .background(
                                if (i <= currentIndex) Color.White
                                else Color.White.copy(alpha = 0.3f),
                                RoundedCornerShape(2.dp),
                            ),
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                LyoAvatar(name = story.name, avatarUrl = story.avatarUrl, size = 36)
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        story.name,
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                    )
                    Text(
                        formatTimeAgo(story.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White.copy(alpha = 0.7f),
                    )
                }
                IconButton(onClick = { nav.popBackStack() }) {
                    Icon(
                        Icons.Filled.Close,
                        contentDescription = "Close",
                        tint = Color.White,
                    )
                }
            }
        }

        // Bottom caption (when media is shown, caption goes at the bottom)
        if (!story.mediaUrl.isNullOrBlank() && !story.caption.isNullOrBlank()) {
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.7f))
                        )
                    )
                    .padding(horizontal = 20.dp, vertical = 28.dp),
            ) {
                Text(
                    story.caption,
                    style = MaterialTheme.typography.bodyLarge,
                    color = Color.White,
                )
            }
        }
    }
}
