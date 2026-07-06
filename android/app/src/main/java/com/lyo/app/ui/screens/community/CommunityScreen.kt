package com.lyo.app.ui.screens.community

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CreatePostRequest
import com.lyo.app.data.api.PostDto
import com.lyo.app.data.api.ReactionRequest
import com.lyo.app.data.api.StoryDto
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoViolet
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

@Composable
fun CommunityScreen(nav: NavHostController) {
    var stories by remember { mutableStateOf<List<StoryDto>>(emptyList()) }
    var posts by remember { mutableStateOf<List<PostDto>>(emptyList()) }
    var likedPostIds by remember { mutableStateOf(setOf<String>()) }
    var extraLikes by remember { mutableStateOf(mapOf<String, Int>()) }
    var loading by remember { mutableStateOf(true) }
    var composerText by remember { mutableStateOf("") }
    var posting by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()

    suspend fun refreshFeed() {
        runCatching { ApiClient.api.publicFeed(1, 20) }
            .onSuccess { posts = it.posts.orEmpty() }
    }

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.stories() }
            .onSuccess { stories = it.stories.orEmpty() }
        refreshFeed()
        loading = false
    }

    Column(modifier = Modifier.fillMaxSize()) {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Text(
                "Community",
                style = MaterialTheme.typography.headlineMedium,
                modifier = Modifier.weight(1f),
            )
            IconButton(onClick = { nav.navigate(Routes.GROUPS) }) {
                Icon(
                    Icons.Filled.Groups,
                    contentDescription = "Study Groups",
                    tint = TextPrimary,
                )
            }
        }

        if (loading) {
            LoadingBox()
            return@Column
        }

        LazyColumn(
            contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            // Stories rail
            item {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    item {
                        StoryCircle(
                            name = "Your story",
                            avatarUrl = Session.user?.avatarUrl,
                            displayName = Session.user?.displayName ?: "You",
                            isAddButton = true,
                            seen = true,
                            onClick = { nav.navigate(Routes.STORIES) },
                        )
                    }
                    itemsIndexed(stories) { _, story ->
                        StoryCircle(
                            name = story.name,
                            avatarUrl = story.avatarUrl,
                            displayName = story.name,
                            isAddButton = false,
                            seen = story.seen,
                            onClick = { nav.navigate(Routes.STORIES) },
                        )
                    }
                }
            }

            // Composer
            item {
                GlassCard(modifier = Modifier.fillMaxWidth()) {
                    Column(modifier = Modifier.padding(14.dp)) {
                        OutlinedTextField(
                            value = composerText,
                            onValueChange = { composerText = it },
                            placeholder = { Text("Share something…", color = TextSecondary) },
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = LyoPurple,
                                unfocusedBorderColor = BorderColor,
                                focusedTextColor = TextPrimary,
                                unfocusedTextColor = TextPrimary,
                            ),
                            modifier = Modifier.fillMaxWidth(),
                        )
                        Spacer(Modifier.height(10.dp))
                        Button(
                            onClick = {
                                if (composerText.isBlank() || posting) return@Button
                                posting = true
                                scope.launch {
                                    runCatching {
                                        ApiClient.api.createPost(CreatePostRequest(composerText.trim()))
                                    }.onSuccess {
                                        composerText = ""
                                        refreshFeed()
                                    }
                                    posting = false
                                }
                            },
                            enabled = composerText.isNotBlank() && !posting,
                            colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                            modifier = Modifier.align(Alignment.End),
                        ) {
                            Text(if (posting) "Posting…" else "Post")
                        }
                    }
                }
            }

            if (posts.isEmpty()) {
                item {
                    EmptyState(
                        title = "No posts yet",
                        subtitle = "Be the first to share something with the community",
                    )
                }
            } else {
                itemsIndexed(posts) { _, post ->
                    val id = post.idStr
                    PostCard(
                        post = post,
                        liked = id in likedPostIds,
                        likeCount = (post.likeCount ?: 0) + (extraLikes[id] ?: 0),
                        onLike = {
                            if (id !in likedPostIds) {
                                likedPostIds = likedPostIds + id
                                extraLikes = extraLikes + (id to (extraLikes[id] ?: 0) + 1)
                                scope.launch {
                                    runCatching {
                                        ApiClient.api.reactToPost(
                                            id,
                                            ReactionRequest(id.toLongOrNull() ?: 0),
                                        )
                                    }
                                }
                            }
                        },
                        onClick = { nav.navigate(Routes.postDetail(id)) },
                    )
                }
            }
        }
    }
}

@Composable
private fun StoryCircle(
    name: String,
    avatarUrl: String?,
    displayName: String,
    isAddButton: Boolean,
    seen: Boolean,
    onClick: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier.width(68.dp),
    ) {
        val ringBrush = if (!seen) {
            Brush.linearGradient(listOf(LyoPurple, LyoViolet, LyoPink))
        } else {
            Brush.linearGradient(listOf(TextSecondary.copy(alpha = 0.5f), TextSecondary.copy(alpha = 0.5f)))
        }
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(64.dp)
                .border(2.dp, ringBrush, CircleShape)
                .clickable(onClick = onClick),
        ) {
            LyoAvatar(name = displayName, avatarUrl = avatarUrl, size = 56)
            if (isAddButton) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .align(Alignment.BottomEnd)
                        .size(20.dp)
                        .background(LyoPurple, CircleShape)
                        .border(2.dp, SurfaceElevated, CircleShape),
                ) {
                    Icon(
                        Icons.Filled.Add,
                        contentDescription = "Add story",
                        tint = Color.White,
                        modifier = Modifier.size(14.dp),
                    )
                }
            }
        }
        Spacer(Modifier.height(4.dp))
        Text(
            name,
            style = MaterialTheme.typography.labelSmall,
            color = TextSecondary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
        )
    }
}

@Composable
private fun PostCard(
    post: PostDto,
    liked: Boolean,
    likeCount: Int,
    onLike: () -> Unit,
    onClick: () -> Unit,
) {
    val authorName = post.authorName ?: post.authorUsername ?: "User"
    GlassCard(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                LyoAvatar(name = authorName, avatarUrl = post.authorAvatar, size = 40)
                Spacer(Modifier.width(10.dp))
                Column {
                    Text(authorName, style = MaterialTheme.typography.titleMedium)
                    Text(
                        formatTimeAgo(post.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = TextSecondary,
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            Text(
                post.content.orEmpty(),
                style = MaterialTheme.typography.bodyLarge,
                color = TextPrimary,
            )
            Spacer(Modifier.height(10.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                IconButton(onClick = onLike, modifier = Modifier.size(28.dp)) {
                    Icon(
                        if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                        contentDescription = "Like",
                        tint = if (liked) LyoPink else TextSecondary,
                        modifier = Modifier.size(20.dp),
                    )
                }
                Spacer(Modifier.width(4.dp))
                Text(
                    likeCount.toString(),
                    style = MaterialTheme.typography.labelLarge,
                    color = TextSecondary,
                )
                Spacer(Modifier.width(20.dp))
                Icon(
                    Icons.Outlined.ChatBubbleOutline,
                    contentDescription = "Comments",
                    tint = TextSecondary,
                    modifier = Modifier.size(18.dp),
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    (post.commentCount ?: 0).toString(),
                    style = MaterialTheme.typography.labelLarge,
                    color = TextSecondary,
                )
            }
        }
    }
}
