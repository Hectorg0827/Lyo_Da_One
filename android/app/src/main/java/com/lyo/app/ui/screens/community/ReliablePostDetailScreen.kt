package com.lyo.app.ui.screens.community

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityCommentDto
import com.lyo.app.data.api.CommunityCommentRequest
import com.lyo.app.data.api.CommunityPostDto
import com.lyo.app.data.sync.SyncClient
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
import java.io.IOException
import kotlinx.coroutines.launch
import retrofit2.HttpException

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReliablePostDetailScreen(nav: NavHostController, postId: String) {
    var post by remember(postId) { mutableStateOf<CommunityPostDto?>(null) }
    var postLoading by remember(postId) { mutableStateOf(true) }
    var postLoaded by remember(postId) { mutableStateOf(false) }
    var postError by remember(postId) { mutableStateOf<String?>(null) }
    var postReload by remember(postId) { mutableIntStateOf(0) }

    var comments by remember(postId) { mutableStateOf<List<CommunityCommentDto>>(emptyList()) }
    var commentsLoading by remember(postId) { mutableStateOf(true) }
    var commentsLoaded by remember(postId) { mutableStateOf(false) }
    var commentsError by remember(postId) { mutableStateOf<String?>(null) }
    var commentsReload by remember(postId) { mutableIntStateOf(0) }

    var liked by remember(postId) { mutableStateOf(false) }
    var bookmarked by remember(postId) { mutableStateOf(false) }
    var postLikePending by remember(postId) { mutableStateOf(false) }
    var bookmarkPending by remember(postId) { mutableStateOf(false) }
    var postActionError by remember(postId) { mutableStateOf<String?>(null) }

    var commentText by remember(postId) { mutableStateOf("") }
    var sendingComment by remember(postId) { mutableStateOf(false) }
    var pendingCommentLikeIds by remember(postId) { mutableStateOf(setOf<String>()) }
    var pendingCommentDeleteIds by remember(postId) { mutableStateOf(setOf<String>()) }
    var commentActionError by remember(postId) { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    val currentUserId = Session.user?.id.orEmpty()

    suspend fun loadPost(preserveVisible: Boolean = true) {
        if (!preserveVisible || post == null) postLoading = true
        postError = null
        runCatching { ApiClient.api.communityPost(postId) }
            .onSuccess { response ->
                post = response
                liked = response.hasLiked == true
                bookmarked = response.hasBookmarked == true
                postLoaded = true
            }
            .onFailure { postError = postDetailFailureMessage(it, "load this post") }
        postLoading = false
    }

    suspend fun loadComments(preserveVisible: Boolean = true) {
        if (!preserveVisible || comments.isEmpty()) commentsLoading = true
        commentsError = null
        runCatching { ApiClient.api.communityComments(postId).items.orEmpty() }
            .onSuccess { response ->
                comments = response
                commentsLoaded = true
            }
            .onFailure { commentsError = postDetailFailureMessage(it, "load comments") }
        commentsLoading = false
    }

    LaunchedEffect(postId, postReload) {
        loadPost(preserveVisible = postReload > 0)
    }

    LaunchedEffect(postId, commentsReload) {
        loadComments(preserveVisible = commentsReload > 0)
    }

    LaunchedEffect(postId) {
        SyncClient.events.collect { event ->
            if (event.eventType in setOf("context_updated", "community_updated")) {
                // Refresh comments only. GET /community/posts/{id} records a view,
                // so background sync must not inflate views by reloading the post.
                loadComments()
            }
        }
    }

    fun togglePostLike() {
        if (postLikePending || post == null) return
        postLikePending = true
        postActionError = null
        scope.launch {
            runCatching {
                val response = ApiClient.api.toggleCommunityPostLike(postId)
                val confirmedLiked = response.liked
                    ?: throw IllegalStateException("The like response did not include its confirmed state")
                val confirmedCount = response.likeCount
                    ?: throw IllegalStateException("The like response did not include its confirmed count")
                confirmedLiked to confirmedCount
            }.onSuccess { (confirmedLiked, confirmedCount) ->
                liked = confirmedLiked
                post = post?.copy(hasLiked = confirmedLiked, likeCount = confirmedCount)
            }.onFailure {
                postActionError = postDetailFailureMessage(it, "update this post like")
            }
            postLikePending = false
        }
    }

    fun toggleBookmark() {
        if (bookmarkPending || post == null) return
        bookmarkPending = true
        postActionError = null
        scope.launch {
            runCatching {
                ApiClient.api.toggleCommunityPostBookmark(postId)
                    .get("bookmarked")
                    ?.asBoolean
                    ?: throw IllegalStateException("The bookmark response did not include its confirmed state")
            }.onSuccess { confirmedBookmarked ->
                bookmarked = confirmedBookmarked
                post = post?.copy(hasBookmarked = confirmedBookmarked)
            }.onFailure {
                postActionError = postDetailFailureMessage(it, "update this bookmark")
            }
            bookmarkPending = false
        }
    }

    fun toggleCommentLike(comment: CommunityCommentDto) {
        val commentId = comment.id.orEmpty()
        if (commentId.isBlank() || commentId in pendingCommentLikeIds) return
        pendingCommentLikeIds = pendingCommentLikeIds + commentId
        commentActionError = null
        scope.launch {
            runCatching {
                val response = ApiClient.api.toggleCommunityCommentLike(postId, commentId)
                val confirmedLiked = response.liked
                    ?: throw IllegalStateException("The comment like response did not include its confirmed state")
                val confirmedCount = response.likeCount
                    ?: throw IllegalStateException("The comment like response did not include its confirmed count")
                confirmedLiked to confirmedCount
            }.onSuccess { (confirmedLiked, confirmedCount) ->
                comments = comments.map { item ->
                    if (item.id == commentId) {
                        item.copy(hasLiked = confirmedLiked, likeCount = confirmedCount)
                    } else {
                        item
                    }
                }
            }.onFailure {
                commentActionError = postDetailFailureMessage(it, "update this comment like")
            }
            pendingCommentLikeIds = pendingCommentLikeIds - commentId
        }
    }

    fun deleteComment(comment: CommunityCommentDto) {
        val commentId = comment.id.orEmpty()
        if (commentId.isBlank() || commentId in pendingCommentDeleteIds) return
        pendingCommentDeleteIds = pendingCommentDeleteIds + commentId
        commentActionError = null
        scope.launch {
            runCatching {
                val response = ApiClient.api.deleteCommunityComment(postId, commentId)
                check(response.isSuccessful) { "The comment deletion was not accepted" }
            }.onSuccess {
                comments = comments.filterNot { it.id == commentId }
                post = post?.copy(commentCount = ((post?.commentCount ?: 0) - 1).coerceAtLeast(0))
            }.onFailure {
                commentActionError = postDetailFailureMessage(it, "delete this comment")
            }
            pendingCommentDeleteIds = pendingCommentDeleteIds - commentId
        }
    }

    fun submitComment() {
        val draft = commentText.trim()
        if (draft.isBlank() || sendingComment || post == null) return
        sendingComment = true
        commentActionError = null
        scope.launch {
            runCatching {
                ApiClient.api.createCommunityComment(
                    postId,
                    CommunityCommentRequest(draft),
                )
            }.onSuccess { created ->
                comments = listOf(created) + comments
                commentsLoaded = true
                commentText = ""
                post = post?.copy(commentCount = (post?.commentCount ?: comments.size - 1) + 1)
            }.onFailure {
                commentActionError = postDetailFailureMessage(it, "post this comment")
            }
            sendingComment = false
        }
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
            if (post != null) {
                CommentComposer(
                    text = commentText,
                    sending = sendingComment,
                    error = commentActionError,
                    onTextChange = {
                        commentText = it
                        commentActionError = null
                    },
                    onSend = ::submitComment,
                    onDismissError = { commentActionError = null },
                )
            }
        },
    ) { padding ->
        when {
            postLoading && post == null -> LoadingBox(modifier = Modifier.padding(padding))
            postError != null && post == null && !postLoaded -> PostDetailSourceError(
                title = "Post could not be loaded",
                message = postError.orEmpty(),
                onRetry = { postReload++ },
                modifier = Modifier.padding(padding),
            )
            postLoaded && post == null -> EmptyState(
                title = "Post not found",
                subtitle = "This post may have been removed",
                modifier = Modifier.padding(padding),
            )
            else -> {
                val detail = post ?: return@Scaffold
                LazyColumn(
                    contentPadding = PaddingValues(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp),
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(padding),
                ) {
                    postError?.let { message ->
                        item {
                            InlinePostDetailError(
                                message = message,
                                actionLabel = "Retry",
                                onAction = { postReload++ },
                            )
                        }
                    }

                    postActionError?.let { message ->
                        item {
                            InlinePostDetailError(
                                message = message,
                                actionLabel = "Dismiss",
                                onAction = { postActionError = null },
                            )
                        }
                    }

                    item {
                        ReliablePostCard(
                            post = detail,
                            liked = liked,
                            bookmarked = bookmarked,
                            likePending = postLikePending,
                            bookmarkPending = bookmarkPending,
                            onLike = ::togglePostLike,
                            onBookmark = ::toggleBookmark,
                            onShare = {
                                val send = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(
                                        Intent.EXTRA_TEXT,
                                        "${detail.authorName ?: "LYO Community"}: ${detail.content.orEmpty()}\nhttps://lyoai.app/community/$postId",
                                    )
                                }
                                context.startActivity(Intent.createChooser(send, "Share Community post"))
                            },
                        )
                    }

                    item {
                        Text(
                            "Comments",
                            style = MaterialTheme.typography.headlineSmall,
                            color = TextPrimary,
                            modifier = Modifier.padding(top = 6.dp),
                        )
                    }

                    when {
                        commentsLoading && comments.isEmpty() -> item {
                            LoadingBox(modifier = Modifier.height(160.dp))
                        }
                        commentsError != null && comments.isEmpty() && !commentsLoaded -> item {
                            InlineSourceError(
                                title = "Comments could not be loaded",
                                message = commentsError.orEmpty(),
                                onRetry = { commentsReload++ },
                            )
                        }
                        commentsLoaded && comments.isEmpty() -> item {
                            EmptyState(
                                title = "No comments yet",
                                subtitle = "Be the first to reply",
                            )
                        }
                        else -> {
                            commentsError?.let { message ->
                                item {
                                    InlineSourceError(
                                        title = "Comments may be out of date",
                                        message = message,
                                        onRetry = { commentsReload++ },
                                    )
                                }
                            }
                            items(comments, key = { it.id.orEmpty() }) { comment ->
                                ReliableCommentCard(
                                    comment = comment,
                                    currentUserId = currentUserId,
                                    likePending = comment.id.orEmpty() in pendingCommentLikeIds,
                                    deletePending = comment.id.orEmpty() in pendingCommentDeleteIds,
                                    onLike = { toggleCommentLike(comment) },
                                    onDelete = { deleteComment(comment) },
                                )
                            }
                        }
                    }
                }
            }
        }
    }
}

@Composable
private fun ReliablePostCard(
    post: CommunityPostDto,
    liked: Boolean,
    bookmarked: Boolean,
    likePending: Boolean,
    bookmarkPending: Boolean,
    onLike: () -> Unit,
    onBookmark: () -> Unit,
    onShare: () -> Unit,
) {
    val authorName = post.authorName ?: "Member"
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                LyoAvatar(name = authorName, avatarUrl = post.authorAvatar, size = 40)
                Spacer(Modifier.width(10.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(authorName, style = MaterialTheme.typography.titleMedium, color = TextPrimary)
                    Text(
                        formatTimeAgo(post.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = TextSecondary,
                    )
                }
                post.postType?.takeIf { it != "text" }?.let { type ->
                    Text(
                        when (type) {
                            "question_discussion" -> "Question"
                            "study_tip" -> "Study tip"
                            else -> type.replace('_', ' ')
                        },
                        style = MaterialTheme.typography.labelSmall,
                        color = LyoPurple,
                        modifier = Modifier
                            .background(LyoPurple.copy(alpha = 0.12f), RoundedCornerShape(50))
                            .padding(horizontal = 8.dp, vertical = 4.dp),
                    )
                }
            }

            Spacer(Modifier.height(10.dp))
            Text(post.content.orEmpty(), style = MaterialTheme.typography.bodyLarge, color = TextPrimary)

            if (!post.tags.isNullOrEmpty()) {
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier.padding(top = 8.dp),
                ) {
                    items(post.tags.orEmpty()) { tag ->
                        Text(
                            "#${tag.removePrefix("#")}",
                            style = MaterialTheme.typography.labelMedium,
                            color = LyoPurple,
                        )
                    }
                }
            }

            if (!post.mediaUrls.isNullOrEmpty()) {
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier.padding(top = 10.dp),
                ) {
                    items(post.mediaUrls.orEmpty()) { mediaUrl ->
                        AsyncImage(
                            model = mediaUrl,
                            contentDescription = "Post image",
                            contentScale = ContentScale.Crop,
                            modifier = Modifier
                                .fillParentMaxWidth()
                                .height(200.dp)
                                .clip(RoundedCornerShape(12.dp))
                                .background(SurfaceElevated),
                        )
                    }
                }
            }

            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                IconButton(onClick = onLike, enabled = !likePending) {
                    if (likePending) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Icon(
                            if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = if (liked) "Unlike" else "Like",
                            tint = if (liked) LyoPink else TextSecondary,
                        )
                    }
                }
                Text((post.likeCount ?: 0).toString(), color = TextSecondary)
                Icon(
                    Icons.Outlined.ChatBubbleOutline,
                    contentDescription = "Comments",
                    tint = TextSecondary,
                    modifier = Modifier.padding(start = 16.dp),
                )
                Text(
                    (post.commentCount ?: 0).toString(),
                    color = TextSecondary,
                    modifier = Modifier.padding(start = 6.dp),
                )
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onBookmark, enabled = !bookmarkPending) {
                    if (bookmarkPending) {
                        CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                    } else {
                        Icon(
                            if (bookmarked) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                            contentDescription = if (bookmarked) "Remove bookmark" else "Bookmark",
                            tint = if (bookmarked) LyoPurple else TextSecondary,
                        )
                    }
                }
                IconButton(onClick = onShare) {
                    Icon(Icons.Filled.Share, contentDescription = "Share", tint = TextSecondary)
                }
            }
        }
    }
}

@Composable
private fun ReliableCommentCard(
    comment: CommunityCommentDto,
    currentUserId: String,
    likePending: Boolean,
    deletePending: Boolean,
    onLike: () -> Unit,
    onDelete: () -> Unit,
) {
    val authorName = comment.authorName ?: "Member"
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.Top, modifier = Modifier.padding(12.dp)) {
            LyoAvatar(name = authorName, avatarUrl = comment.authorAvatar, size = 32)
            Spacer(Modifier.width(10.dp))
            Column(modifier = Modifier.weight(1f)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(authorName, style = MaterialTheme.typography.titleSmall, color = TextPrimary)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        formatTimeAgo(comment.createdAt),
                        style = MaterialTheme.typography.labelMedium,
                        color = TextSecondary,
                    )
                }
                Text(
                    comment.content.orEmpty(),
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextPrimary,
                    modifier = Modifier.padding(top = 2.dp),
                )
                Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 4.dp)) {
                    IconButton(onClick = onLike, enabled = !likePending, modifier = Modifier.size(28.dp)) {
                        if (likePending) {
                            CircularProgressIndicator(modifier = Modifier.size(15.dp), strokeWidth = 2.dp)
                        } else {
                            Icon(
                                if (comment.hasLiked == true) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                                contentDescription = if (comment.hasLiked == true) "Unlike comment" else "Like comment",
                                tint = if (comment.hasLiked == true) LyoPink else TextSecondary,
                                modifier = Modifier.size(16.dp),
                            )
                        }
                    }
                    if ((comment.likeCount ?: 0) > 0) {
                        Text(
                            (comment.likeCount ?: 0).toString(),
                            style = MaterialTheme.typography.labelMedium,
                            color = TextSecondary,
                            modifier = Modifier.padding(start = 2.dp),
                        )
                    }
                    if (currentUserId.isNotEmpty() && comment.authorIdStr == currentUserId) {
                        Spacer(Modifier.width(12.dp))
                        IconButton(onClick = onDelete, enabled = !deletePending, modifier = Modifier.size(28.dp)) {
                            if (deletePending) {
                                CircularProgressIndicator(modifier = Modifier.size(15.dp), strokeWidth = 2.dp)
                            } else {
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

@Composable
private fun CommentComposer(
    text: String,
    sending: Boolean,
    error: String?,
    onTextChange: (String) -> Unit,
    onSend: () -> Unit,
    onDismissError: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(Background)
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        error?.let { message ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    message,
                    color = MaterialTheme.colorScheme.error,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.weight(1f),
                )
                TextButton(onClick = onDismissError) { Text("Dismiss") }
            }
        }
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = text,
                onValueChange = onTextChange,
                placeholder = { Text("Add a comment…", color = TextSecondary) },
                enabled = !sending,
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
            IconButton(onClick = onSend, enabled = text.isNotBlank() && !sending) {
                if (sending) {
                    CircularProgressIndicator(modifier = Modifier.size(20.dp), strokeWidth = 2.dp)
                } else {
                    Icon(
                        Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send comment",
                        tint = if (text.isNotBlank()) LyoPurple else TextSecondary,
                    )
                }
            }
        }
    }
}

@Composable
private fun PostDetailSourceError(
    title: String,
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier
            .fillMaxSize()
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
        TextButton(onClick = onRetry, modifier = Modifier.padding(top = 10.dp)) { Text("Retry") }
    }
}

@Composable
private fun InlinePostDetailError(
    message: String,
    actionLabel: String,
    onAction: () -> Unit,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(10.dp)) {
            Text(
                message,
                style = MaterialTheme.typography.bodySmall,
                color = MaterialTheme.colorScheme.error,
                modifier = Modifier.weight(1f),
            )
            TextButton(onClick = onAction) { Text(actionLabel) }
        }
    }
}

private fun postDetailFailureMessage(error: Throwable, action: String): String = when (error) {
    is HttpException -> when (error.code()) {
        400, 422 -> "LYO could not $action because the request was invalid."
        401, 403 -> "Sign in again to $action."
        404 -> "This post or comment is no longer available."
        409 -> "This Community state changed elsewhere. Refresh and try again."
        429 -> "Too many Community requests. Wait a moment and try again."
        in 500..599 -> "LYO could not $action because the Community service is unavailable."
        else -> "LYO could not $action (${error.code()})."
    }
    is IOException -> "Check your connection and try to $action again."
    else -> error.localizedMessage ?: "LYO could not $action."
}
