package com.lyo.app.ui.screens.community

import androidx.compose.foundation.layout.Arrangement
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
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.google.gson.JsonObject
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommentRequest
import com.lyo.app.data.api.ReactionRequest
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

private data class PostDetail(
    val content: String,
    val authorName: String,
    val likeCount: Int,
    val commentCount: Int,
    val createdAt: String?,
    val comments: List<CommentItem>,
)

private data class CommentItem(
    val content: String,
    val authorName: String,
    val createdAt: String?,
)

private fun JsonObject.str(key: String): String? =
    runCatching { get(key)?.takeIf { !it.isJsonNull }?.asString }.getOrNull()

private fun JsonObject.int(key: String): Int? =
    runCatching { get(key)?.takeIf { !it.isJsonNull }?.asInt }.getOrNull()

private fun parsePostDetail(obj: JsonObject): PostDetail {
    val comments = runCatching {
        obj.get("comments")?.takeIf { it.isJsonArray }?.asJsonArray
            ?.mapNotNull { el ->
                runCatching {
                    val c = el.asJsonObject
                    CommentItem(
                        content = c.str("content").orEmpty(),
                        authorName = c.str("author_name")
                            ?: c.str("author_username")
                            ?: "User",
                        createdAt = c.str("created_at"),
                    )
                }.getOrNull()
            }
            .orEmpty()
    }.getOrDefault(emptyList())

    return PostDetail(
        content = obj.str("content").orEmpty(),
        authorName = obj.str("author_name") ?: obj.str("author_username") ?: "User",
        likeCount = obj.int("like_count") ?: 0,
        commentCount = obj.int("comment_count") ?: comments.size,
        createdAt = obj.str("created_at"),
        comments = comments,
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostDetailScreen(nav: NavHostController, postId: String) {
    var post by remember { mutableStateOf<PostDetail?>(null) }
    var loading by remember { mutableStateOf(true) }
    var liked by remember { mutableStateOf(false) }
    var extraLikes by remember { mutableIntStateOf(0) }
    var commentText by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var refreshKey by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(postId, refreshKey) {
        runCatching { ApiClient.api.getPost(postId) }
            .onSuccess { post = parsePostDetail(it) }
        loading = false
    }

    Scaffold(
        containerColor = Background,
        topBar = {
            TopAppBar(
                title = { Text("Post") },
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
        bottomBar = {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                OutlinedTextField(
                    value = commentText,
                    onValueChange = { commentText = it },
                    placeholder = { Text("Add a comment…", color = TextSecondary) },
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = LyoPurple,
                        unfocusedBorderColor = BorderColor,
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary,
                        focusedContainerColor = Surface,
                        unfocusedContainerColor = Surface,
                    ),
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = {
                        if (commentText.isBlank() || sending) return@IconButton
                        sending = true
                        scope.launch {
                            runCatching {
                                ApiClient.api.createComment(
                                    CommentRequest(postId.toLongOrNull() ?: 0, commentText.trim())
                                )
                            }.onSuccess {
                                commentText = ""
                                refreshKey++
                            }
                            sending = false
                        }
                    },
                    enabled = commentText.isNotBlank() && !sending,
                ) {
                    Icon(
                        Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send comment",
                        tint = if (commentText.isNotBlank()) LyoPurple else TextSecondary,
                    )
                }
            }
        },
    ) { padding ->
        when {
            loading -> LoadingBox(modifier = Modifier.padding(padding))
            post == null -> EmptyState(
                title = "Post not found",
                subtitle = "This post may have been removed",
                modifier = Modifier.padding(padding),
            )
            else -> {
                val detail = post!!
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                ) {
                    item {
                        GlassCard(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(14.dp)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    LyoAvatar(name = detail.authorName, avatarUrl = null, size = 40)
                                    Spacer(Modifier.width(10.dp))
                                    Column {
                                        Text(detail.authorName, style = MaterialTheme.typography.titleMedium)
                                        Text(
                                            formatTimeAgo(detail.createdAt),
                                            style = MaterialTheme.typography.labelMedium,
                                            color = TextSecondary,
                                        )
                                    }
                                }
                                Spacer(Modifier.height(10.dp))
                                Text(
                                    detail.content,
                                    style = MaterialTheme.typography.bodyLarge,
                                    color = TextPrimary,
                                )
                                Spacer(Modifier.height(10.dp))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(
                                        onClick = {
                                            if (!liked) {
                                                liked = true
                                                extraLikes++
                                                scope.launch {
                                                    runCatching {
                                                        ApiClient.api.reactToPost(
                                                            postId,
                                                            ReactionRequest(postId.toLongOrNull() ?: 0),
                                                        )
                                                    }
                                                }
                                            }
                                        },
                                        modifier = Modifier.size(28.dp),
                                    ) {
                                        Icon(
                                            if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                                            contentDescription = "Like",
                                            tint = if (liked) LyoPink else TextSecondary,
                                            modifier = Modifier.size(20.dp),
                                        )
                                    }
                                    Spacer(Modifier.width(4.dp))
                                    Text(
                                        (detail.likeCount + extraLikes).toString(),
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
                                        detail.commentCount.toString(),
                                        style = MaterialTheme.typography.labelLarge,
                                        color = TextSecondary,
                                    )
                                }
                            }
                        }
                    }

                    item {
                        Text(
                            "Comments",
                            style = MaterialTheme.typography.headlineSmall,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }

                    if (detail.comments.isEmpty()) {
                        item {
                            EmptyState(
                                title = "No comments yet",
                                subtitle = "Be the first to reply",
                            )
                        }
                    } else {
                        items(detail.comments) { comment ->
                            GlassCard(modifier = Modifier.fillMaxWidth()) {
                                Row(
                                    verticalAlignment = Alignment.Top,
                                    modifier = Modifier.padding(12.dp),
                                ) {
                                    LyoAvatar(name = comment.authorName, avatarUrl = null, size = 32)
                                    Spacer(Modifier.width(10.dp))
                                    Column {
                                        Row(verticalAlignment = Alignment.CenterVertically) {
                                            Text(
                                                comment.authorName,
                                                style = MaterialTheme.typography.titleSmall,
                                            )
                                            Spacer(Modifier.width(8.dp))
                                            Text(
                                                formatTimeAgo(comment.createdAt),
                                                style = MaterialTheme.typography.labelMedium,
                                                color = TextSecondary,
                                            )
                                        }
                                        Spacer(Modifier.height(2.dp))
                                        Text(
                                            comment.content,
                                            style = MaterialTheme.typography.bodyMedium,
                                            color = TextPrimary,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
