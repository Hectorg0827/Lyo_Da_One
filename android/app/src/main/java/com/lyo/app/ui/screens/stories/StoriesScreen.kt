package com.lyo.app.ui.screens.stories

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectTapGestures
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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
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
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.IOException
import kotlinx.coroutines.launch
import retrofit2.HttpException

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StoriesScreen(nav: NavHostController) {
    var stories by remember { mutableStateOf<List<StoryDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var loaded by remember { mutableStateOf(false) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var reloadVersion by remember { mutableIntStateOf(0) }
    var currentIndex by remember { mutableIntStateOf(0) }
    var pendingSeenIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var confirmedSeenIds by remember { mutableStateOf<Set<String>>(emptySet()) }
    var failedSeenStory by remember { mutableStateOf<StoryDto?>(null) }
    var seenError by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun markSeen(story: StoryDto) {
        val storyId = story.idStr
        if (storyId.isBlank()) {
            failedSeenStory = story
            seenError = "This story does not have a persistent identifier."
            return
        }
        if (storyId in pendingSeenIds || storyId in confirmedSeenIds) return

        pendingSeenIds = pendingSeenIds + storyId
        scope.launch {
            runCatching { ApiClient.api.markStorySeen(storyId) }
                .onSuccess {
                    confirmedSeenIds = confirmedSeenIds + storyId
                    if (failedSeenStory?.idStr == storyId) {
                        failedSeenStory = null
                        seenError = null
                    }
                }
                .onFailure { error ->
                    failedSeenStory = story
                    seenError = storyError(error, "sync this story view")
                }
            pendingSeenIds = pendingSeenIds - storyId
        }
    }

    LaunchedEffect(reloadVersion) {
        loading = true
        loaded = false
        loadError = null
        runCatching { ApiClient.api.stories() }
            .onSuccess { response ->
                stories = response.stories.orEmpty()
                currentIndex = 0
                loaded = true
            }
            .onFailure { error ->
                loadError = storyError(error, "load stories")
                loaded = true
            }
        loading = false
    }

    if (loading && stories.isEmpty()) {
        LoadingBox(modifier = Modifier.background(Color.Black))
        return
    }

    if (loadError != null && stories.isEmpty()) {
        StoriesStatusScreen(
            nav = nav,
            title = "Stories unavailable",
            message = loadError ?: "Stories could not be loaded.",
            actionLabel = "Retry",
            onAction = { reloadVersion += 1 },
        )
        return
    }

    if (loaded && stories.isEmpty()) {
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
                subtitle = "Stories from people you follow will appear here.",
                modifier = Modifier.padding(padding),
            )
        }
        return
    }

    val story = stories[currentIndex.coerceIn(0, stories.lastIndex)]

    LaunchedEffect(story.idStr) {
        markSeen(story)
    }

    fun goNext() {
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
                        text = story.caption,
                        style = MaterialTheme.typography.headlineMedium,
                        color = Color.White,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 32.dp),
                    )
                }
            }
        }

        Column(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .background(
                    Brush.verticalGradient(
                        listOf(Color.Black.copy(alpha = 0.6f), Color.Transparent),
                    ),
                )
                .statusBarsPadding()
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                stories.forEachIndexed { index, _ ->
                    Box(
                        modifier = Modifier
                            .weight(1f)
                            .height(3.dp)
                            .background(
                                if (index <= currentIndex) Color.White
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
                        text = story.name,
                        style = MaterialTheme.typography.titleMedium,
                        color = Color.White,
                    )
                    Text(
                        text = formatTimeAgo(story.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = Color.White.copy(alpha = 0.7f),
                    )
                }
                if (story.idStr in pendingSeenIds) {
                    CircularProgressIndicator(
                        color = Color.White,
                        strokeWidth = 2.dp,
                        modifier = Modifier
                            .padding(end = 8.dp)
                            .size(16.dp),
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

        if (seenError != null || (!story.mediaUrl.isNullOrBlank() && !story.caption.isNullOrBlank())) {
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .align(Alignment.BottomCenter)
                    .background(
                        Brush.verticalGradient(
                            listOf(Color.Transparent, Color.Black.copy(alpha = 0.78f)),
                        ),
                    )
                    .padding(horizontal = 20.dp, vertical = 28.dp),
            ) {
                seenError?.let { message ->
                    StorySeenError(
                        message = message,
                        onRetry = {
                            failedSeenStory?.let { failed ->
                                seenError = null
                                markSeen(failed)
                            }
                        },
                    )
                }
                if (!story.mediaUrl.isNullOrBlank() && !story.caption.isNullOrBlank()) {
                    Text(
                        text = story.caption,
                        style = MaterialTheme.typography.bodyLarge,
                        color = Color.White,
                        modifier = Modifier.padding(top = if (seenError != null) 12.dp else 0.dp),
                    )
                }
            }
        }
    }
}

private fun storyError(error: Throwable, operation: String): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "Your session cannot $operation. Sign in again and retry."
        404 -> "The story is no longer available."
        409 -> "Story state changed on another device. Retry the sync."
        else -> "Unable to $operation (${error.code()})."
    }
    is IOException -> "Check your connection and try to $operation again."
    else -> error.localizedMessage ?: "Unable to $operation."
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StoriesStatusScreen(
    nav: NavHostController,
    title: String,
    message: String,
    actionLabel: String,
    onAction: () -> Unit,
) {
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
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .padding(24.dp),
        ) {
            Text(title, style = MaterialTheme.typography.headlineSmall, color = TextPrimary)
            Text(
                message,
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 8.dp),
            )
            Text(
                actionLabel,
                style = MaterialTheme.typography.titleSmall,
                color = LyoPurple,
                modifier = Modifier
                    .padding(top = 14.dp)
                    .clickable(onClick = onAction)
                    .padding(8.dp),
            )
        }
    }
}

@Composable
private fun StorySeenError(
    message: String,
    onRetry: () -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.45f), RoundedCornerShape(12.dp))
            .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Text(
            text = message,
            style = MaterialTheme.typography.bodySmall,
            color = Color.White,
            modifier = Modifier.weight(1f),
        )
        Text(
            text = "Retry",
            style = MaterialTheme.typography.labelLarge,
            color = Color.White,
            modifier = Modifier
                .clickable(onClick = onRetry)
                .padding(6.dp),
        )
    }
}