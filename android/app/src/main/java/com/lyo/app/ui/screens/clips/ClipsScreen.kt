package com.lyo.app.ui.screens.clips

import android.content.Intent
import android.net.Uri
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ClipCommentDto
import com.lyo.app.data.api.ClipCreateRequest
import com.lyo.app.data.api.ClipDto
import com.lyo.app.data.api.CommunityCommentRequest
import com.lyo.app.ui.components.CardGradients
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClipsScreen(nav: NavHostController) {
    var clips by remember { mutableStateOf<List<ClipDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var likedIds by remember { mutableStateOf(setOf<String>()) }
    var savedIds by remember { mutableStateOf(setOf<String>()) }
    var commentsClipId by remember { mutableStateOf<String?>(null) }
    var pendingVideoUri by remember { mutableStateOf<Uri?>(null) }
    var refreshKey by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pendingVideoUri = uri
    }

    LaunchedEffect(refreshKey) {
        val discovered = runCatching { ApiClient.api.discoverClips(1, 20).clips.orEmpty() }
            .getOrDefault(emptyList())
        clips = if (discovered.isNotEmpty()) {
            discovered
        } else {
            runCatching { ApiClient.api.clips(1, 20).clips.orEmpty() }
                .getOrDefault(emptyList())
        }
        likedIds = clips.filter { it.isLiked == true }.map { it.idStr }.toSet()
        savedIds = clips.filter { it.isSaved == true }.map { it.idStr }.toSet()
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
                        isCurrent = pagerState.currentPage == page,
                        liked = id in likedIds,
                        saved = id in savedIds,
                        likeCount = (clip.likeCount ?: 0) + (if (id in likedIds && clip.isLiked != true) 1 else 0),
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
                        onComments = { commentsClipId = id },
                        onShare = {
                            val send = Intent(Intent.ACTION_SEND).apply {
                                type = "text/plain"
                                putExtra(
                                    Intent.EXTRA_TEXT,
                                    "${clip.title ?: "A clip"} on LYO\nhttps://lyoai.app/clips/$id",
                                )
                            }
                            context.startActivity(Intent.createChooser(send, "Share clip"))
                            scope.launch { runCatching { ApiClient.api.shareClip(id) } }
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

        FloatingActionButton(
            onClick = { videoPicker.launch("video/*") },
            containerColor = LyoPurple,
            contentColor = Color.White,
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .navigationBarsPadding()
                .padding(end = 16.dp, bottom = 96.dp),
        ) {
            Icon(Icons.Filled.Add, contentDescription = "Create clip")
        }
    }

    commentsClipId?.let { clipId ->
        ClipCommentsSheet(clipId = clipId, onDismiss = { commentsClipId = null })
    }

    pendingVideoUri?.let { uri ->
        PublishClipDialog(
            videoUri = uri,
            onDismiss = { pendingVideoUri = null },
            onPublished = {
                pendingVideoUri = null
                refreshKey++
            },
        )
    }
}

@Composable
private fun PublishClipDialog(videoUri: Uri, onDismiss: () -> Unit, onPublished: () -> Unit) {
    var title by remember { mutableStateOf("") }
    var subject by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    fun publish() {
        if (title.isBlank() || submitting) return
        submitting = true
        error = null
        scope.launch {
            runCatching {
                val contentType = context.contentResolver.getType(videoUri) ?: "video/mp4"
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(videoUri)?.use { it.readBytes() }
                } ?: throw IllegalStateException("Could not read the selected video")
                val extension = when (contentType) {
                    "video/quicktime" -> "mov"
                    "video/webm" -> "webm"
                    else -> "mp4"
                }
                val part = MultipartBody.Part.createFormData(
                    "file",
                    "reel.$extension",
                    bytes.toRequestBody(contentType.toMediaType()),
                )
                val uploaded = ApiClient.api.uploadMedia(
                    file = part,
                    folder = "clips".toRequestBody("text/plain".toMediaType()),
                )
                val url = uploaded.url ?: throw IllegalStateException("Upload failed")
                ApiClient.api.createClip(
                    ClipCreateRequest(
                        title = title.trim(),
                        videoUrl = url,
                        subject = subject.trim().ifEmpty { null },
                        tags = subject.trim().lowercase().let { if (it.isEmpty()) emptyList() else listOf(it) },
                    ),
                )
            }.onSuccess { onPublished() }
                .onFailure { error = it.localizedMessage ?: "Unable to publish the clip" }
            submitting = false
        }
    }

    AlertDialog(
        onDismissRequest = { if (!submitting) onDismiss() },
        title = { Text("Publish clip") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(title, { title = it }, label = { Text("Title") }, singleLine = true)
                OutlinedTextField(subject, { subject = it }, label = { Text("Subject (optional)") }, singleLine = true)
                if (submitting) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(8.dp))
                        Text("Uploading…", style = MaterialTheme.typography.bodySmall)
                    }
                }
                error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = {
            TextButton(onClick = ::publish, enabled = title.isNotBlank() && !submitting) {
                Text(if (submitting) "Publishing…" else "Publish")
            }
        },
        dismissButton = { TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancel") } },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ClipCommentsSheet(clipId: String, onDismiss: () -> Unit) {
    var comments by remember { mutableStateOf<List<ClipCommentDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var text by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val currentUserId = Session.user?.id.orEmpty()

    LaunchedEffect(clipId) {
        runCatching { ApiClient.api.clipComments(clipId).items.orEmpty() }
            .onSuccess { comments = it }
            .onFailure { error = "Unable to load comments" }
        loading = false
    }

    ModalBottomSheet(onDismissRequest = onDismiss, containerColor = Surface) {
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .heightIn(min = 240.dp, max = 560.dp)
                .padding(horizontal = 16.dp)
                .navigationBarsPadding(),
        ) {
            Text(
                "Comments (${comments.size})",
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
            )
            Spacer(Modifier.height(8.dp))
            when {
                loading -> LoadingBox(modifier = Modifier.height(160.dp))
                comments.isEmpty() -> EmptyState(title = "No comments yet", subtitle = "Be the first to reply")
                else -> LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.weight(1f, fill = false),
                ) {
                    items(comments, key = { it.id.orEmpty() }) { comment ->
                        Row(verticalAlignment = Alignment.Top) {
                            LyoAvatar(name = comment.authorName ?: "M", avatarUrl = comment.authorAvatar, size = 30)
                            Spacer(Modifier.width(10.dp))
                            Column(modifier = Modifier.weight(1f)) {
                                Row(verticalAlignment = Alignment.CenterVertically) {
                                    Text(
                                        comment.authorName ?: "Member",
                                        style = MaterialTheme.typography.titleSmall,
                                        color = TextPrimary,
                                    )
                                    Spacer(Modifier.width(8.dp))
                                    Text(
                                        formatTimeAgo(comment.createdAt),
                                        style = MaterialTheme.typography.labelSmall,
                                        color = TextSecondary,
                                    )
                                }
                                Text(
                                    comment.content.orEmpty(),
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = TextPrimary,
                                )
                            }
                            if (currentUserId.isNotEmpty() && comment.userIdStr == currentUserId) {
                                IconButton(
                                    onClick = {
                                        scope.launch {
                                            runCatching {
                                                val response = ApiClient.api.deleteClipComment(clipId, comment.id.orEmpty())
                                                check(response.isSuccessful) { "Unable to delete comment" }
                                            }.onSuccess {
                                                comments = comments.filterNot { it.id == comment.id }
                                            }.onFailure { error = it.localizedMessage ?: "Unable to delete comment" }
                                        }
                                    },
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
            error?.let {
                Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(bottom = 12.dp)) {
                OutlinedTextField(
                    value = text,
                    onValueChange = { text = it },
                    placeholder = { Text("Add a comment…", color = TextSecondary) },
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = {
                        sending = true
                        error = null
                        scope.launch {
                            runCatching {
                                ApiClient.api.createClipComment(clipId, CommunityCommentRequest(text.trim()))
                            }.onSuccess { created ->
                                comments = listOf(created) + comments
                                text = ""
                            }.onFailure { error = it.localizedMessage ?: "Unable to post comment" }
                            sending = false
                        }
                    },
                    enabled = text.isNotBlank() && !sending,
                ) {
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
    isCurrent: Boolean,
    liked: Boolean,
    saved: Boolean,
    likeCount: Int,
    onLike: () -> Unit,
    onSave: () -> Unit,
    onComments: () -> Unit,
    onShare: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        when {
            // Play the actual reel when this page is front-most; fall back to
            // the thumbnail (or a gradient) otherwise.
            isCurrent && !clip.videoUrl.isNullOrBlank() -> AndroidView(
                factory = { context ->
                    VideoView(context).apply {
                        setOnPreparedListener { player ->
                            player.isLooping = true
                            player.start()
                        }
                    }
                },
                update = { view ->
                    if (view.tag != clip.videoUrl) {
                        view.tag = clip.videoUrl
                        view.setVideoURI(Uri.parse(clip.videoUrl))
                    }
                },
                onRelease = { it.stopPlayback() },
                modifier = Modifier.fillMaxSize(),
            )
            !clip.thumbnailUrl.isNullOrBlank() -> AsyncImage(
                model = clip.thumbnailUrl,
                contentDescription = clip.title ?: "Clip",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
            else -> Box(
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
            if (!clip.authorName.isNullOrBlank()) {
                Spacer(Modifier.height(2.dp))
                Text(
                    clip.authorName,
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White.copy(alpha = 0.8f),
                )
            }
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
                IconButton(onClick = onComments) {
                    Icon(
                        Icons.Outlined.ChatBubbleOutline,
                        contentDescription = "Comments",
                        tint = Color.White,
                        modifier = Modifier.size(28.dp),
                    )
                }
                Text(
                    (clip.commentCount ?: 0).toString(),
                    style = MaterialTheme.typography.labelMedium,
                    color = Color.White,
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onShare) {
                    Icon(
                        Icons.Filled.Share,
                        contentDescription = "Share",
                        tint = Color.White,
                        modifier = Modifier.size(26.dp),
                    )
                }
                Text(
                    "Share",
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
