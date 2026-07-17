package com.lyo.app.ui.screens.community

import android.content.Intent
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Delete
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityCommentRequest
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
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch
import coil.compose.AsyncImage

private data class PostDetail(
    val content: String,
    val authorName: String,
    val likeCount: Int,
    val commentCount: Int,
    val createdAt: String?,
    val mediaUrls: List<String>,
    val tags: List<String>,
    val postType: String,
    val comments: List<CommentItem>,
)

private data class CommentItem(
    val id: String,
    val authorId: String,
    val content: String,
    val authorName: String,
    val createdAt: String?,
    val likeCount: Int,
    val hasLiked: Boolean,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PostDetailScreen(nav: NavHostController, postId: String) {
    var post by remember { mutableStateOf<PostDetail?>(null) }
    var loading by remember { mutableStateOf(true) }
    var liked by remember { mutableStateOf(false) }
    var bookmarked by remember { mutableStateOf(false) }
    var postActionBusy by remember { mutableStateOf(false) }
    var extraLikes by remember { mutableIntStateOf(0) }
    var commentText by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var commentError by remember { mutableStateOf<String?>(null) }
    var refreshKey by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val currentUserId = Session.user?.id.orEmpty()

    fun updateComment(commentId: String, transform: (CommentItem) -> CommentItem) {
        post = post?.let { detail ->
            detail.copy(comments = detail.comments.map { if (it.id == commentId) transform(it) else it })
        }
    }

    // Optimistic like toggle, reverted on failure — same behavior as iOS + web
    fun toggleCommentLike(comment: CommentItem) {
        if (comment.id.isEmpty()) return
        val wasLiked = comment.hasLiked
        updateComment(comment.id) {
            it.copy(hasLiked = !wasLiked, likeCount = (it.likeCount + if (wasLiked) -1 else 1).coerceAtLeast(0))
        }
        scope.launch {
            runCatching { ApiClient.api.toggleCommunityCommentLike(postId, comment.id) }
                .onSuccess { response ->
                    updateComment(comment.id) {
                        it.copy(hasLiked = response.liked ?: !wasLiked, likeCount = response.likeCount ?: it.likeCount)
                    }
                }
                .onFailure {
                    updateComment(comment.id) {
                        it.copy(hasLiked = wasLiked, likeCount = (it.likeCount + if (wasLiked) 1 else -1).coerceAtLeast(0))
                    }
                }
        }
    }

    // Delete own comment (backend enforces author-only)
    fun deleteComment(comment: CommentItem) {
        if (comment.id.isEmpty()) return
        scope.launch {
            runCatching {
                val response = ApiClient.api.deleteCommunityComment(postId, comment.id)
                check(response.isSuccessful) { "Unable to delete comment" }
            }.onSuccess {
                post = post?.let { detail ->
                    detail.copy(
                        comments = detail.comments.filterNot { it.id == comment.id },
                        commentCount = (detail.commentCount - 1).coerceAtLeast(0),
                    )
                }
            }.onFailure { commentError = it.localizedMessage ?: "Unable to delete comment" }
        }
    }

    LaunchedEffect(postId, refreshKey) {
        // Community post + its comments (separate endpoint, same as iOS)
        val postResult = runCatching { ApiClient.api.communityPost(postId) }.getOrNull()
        val commentsResult = runCatching { ApiClient.api.communityComments(postId) }.getOrNull()
        if (postResult != null) {
            val comments = commentsResult?.items.orEmpty().map {
                CommentItem(
                    id = it.id.orEmpty(),
                    authorId = it.authorIdStr,
                    content = it.content.orEmpty(),
                    authorName = it.authorName ?: "Member",
                    createdAt = it.createdAt,
                    likeCount = it.likeCount ?: 0,
                    hasLiked = it.hasLiked == true,
                )
            }
            post = PostDetail(
                content = postResult.content.orEmpty(),
                authorName = postResult.authorName ?: "Member",
                likeCount = postResult.likeCount ?: 0,
                commentCount = postResult.commentCount ?: comments.size,
                createdAt = postResult.createdAt,
                mediaUrls = postResult.mediaUrls.orEmpty(),
                tags = postResult.tags.orEmpty(),
                postType = postResult.postType ?: "text",
                comments = comments,
            )
            liked = postResult.hasLiked == true
            bookmarked = postResult.hasBookmarked == true
        }
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
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                Row(verticalAlignment = Alignment.CenterVertically) {
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
                            sending = true
                            commentError = null
                            scope.launch {
                                runCatching {
                                    ApiClient.api.createCommunityComment(
                                        postId,
                                        CommunityCommentRequest(commentText.trim()),
                                    )
                                }.onSuccess {
                                    commentText = ""
                                    refreshKey++
                                }.onFailure {
                                    commentError = it.localizedMessage ?: "Unable to post comment"
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
                commentError?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
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
                                if (detail.postType != "text") {
                                    Text(
                                        if (detail.postType == "question_discussion") "Question" else "Study tip",
                                        style = MaterialTheme.typography.labelSmall,
                                        color = LyoPurple,
                                        modifier = Modifier.padding(top = 8.dp).background(LyoPurple.copy(alpha = 0.12f), RoundedCornerShape(50)).padding(horizontal = 8.dp, vertical = 4.dp),
                                    )
                                }
                                if (detail.tags.isNotEmpty()) {
                                    LazyRow(horizontalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(top = 8.dp)) {
                                        items(detail.tags) { tag ->
                                            Text("#${tag.removePrefix("#")}", style = MaterialTheme.typography.labelMedium, color = LyoPurple)
                                        }
                                    }
                                }
                                if (detail.mediaUrls.isNotEmpty()) {
                                    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(top = 10.dp)) {
                                        items(detail.mediaUrls) { mediaUrl ->
                                            AsyncImage(
                                                model = mediaUrl,
                                                contentDescription = "Post image",
                                                contentScale = ContentScale.Crop,
                                                modifier = Modifier.fillParentMaxWidth().height(200.dp).clip(RoundedCornerShape(12.dp)).background(SurfaceElevated),
                                            )
                                        }
                                    }
                                }
                                Spacer(Modifier.height(10.dp))
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    IconButton(
                                        onClick = {
                                            val wasLiked = liked
                                            liked = !wasLiked
                                            extraLikes += if (wasLiked) -1 else 1
                                            postActionBusy = true
                                            scope.launch {
                                                runCatching {
                                                    ApiClient.api.toggleCommunityPostLike(postId)
                                                }.onFailure {
                                                    liked = wasLiked
                                                    extraLikes += if (wasLiked) 1 else -1
                                                }
                                                postActionBusy = false
                                            }
                                        },
                                        enabled = !postActionBusy,
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
                                    Spacer(Modifier.weight(1f))
                                    IconButton(
                                        onClick = {
                                            val wasBookmarked = bookmarked
                                            bookmarked = !wasBookmarked
                                            postActionBusy = true
                                            scope.launch {
                                                runCatching { ApiClient.api.toggleCommunityPostBookmark(postId) }
                                                    .onFailure { bookmarked = wasBookmarked }
                                                postActionBusy = false
                                            }
                                        },
                                        enabled = !postActionBusy,
                                    ) {
                                        Icon(
                                            if (bookmarked) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                                            contentDescription = "Bookmark",
                                            tint = if (bookmarked) LyoPurple else TextSecondary,
                                        )
                                    }
                                    IconButton(
                                        onClick = {
                                            val send = Intent(Intent.ACTION_SEND).apply {
                                                type = "text/plain"
                                                putExtra(Intent.EXTRA_TEXT, "${detail.authorName}: ${detail.content}\nhttps://lyoapp.com/community/$postId")
                                            }
                                            context.startActivity(Intent.createChooser(send, "Share Community post"))
                                        },
                                    ) {
                                        Icon(Icons.Filled.Share, contentDescription = "Share", tint = TextSecondary)
                                    }
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
                                        Row(
                                            verticalAlignment = Alignment.CenterVertically,
                                            modifier = Modifier.padding(top = 4.dp),
                                        ) {
                                            IconButton(
                                                onClick = { toggleCommentLike(comment) },
                                                modifier = Modifier.size(26.dp),
                                            ) {
                                                Icon(
                                                    if (comment.hasLiked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                                                    contentDescription = if (comment.hasLiked) "Unlike comment" else "Like comment",
                                                    tint = if (comment.hasLiked) LyoPink else TextSecondary,
                                                    modifier = Modifier.size(16.dp),
                                                )
                                            }
                                            if (comment.likeCount > 0) {
                                                Spacer(Modifier.width(2.dp))
                                                Text(
                                                    comment.likeCount.toString(),
                                                    style = MaterialTheme.typography.labelMedium,
                                                    color = TextSecondary,
                                                )
                                            }
                                            if (currentUserId.isNotEmpty() && comment.authorId == currentUserId) {
                                                Spacer(Modifier.width(12.dp))
                                                IconButton(
                                                    onClick = { deleteComment(comment) },
                                                    modifier = Modifier.size(26.dp),
                                                ) {
                                                    Icon(
                                                        Icons.Outlined.Delete,
                                                        contentDescription = "Delete comment",
                                                        tint = TextSecondary,
                                                        modifier = Modifier.size(16.dp),
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
        }
    }
}
