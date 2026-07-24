package com.lyo.app.ui.screens.clips

import android.content.Intent
import android.net.Uri
import android.widget.VideoView
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.text.style.TextAlign
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
import java.io.File
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.HttpException

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ClipsScreen(nav: NavHostController) {
    var clips by remember { mutableStateOf<List<ClipDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var loaded by remember { mutableStateOf(false) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var interactionError by remember { mutableStateOf<String?>(null) }
    var likedIds by remember { mutableStateOf(setOf<String>()) }
    var savedIds by remember { mutableStateOf(setOf<String>()) }
    var pendingLikeIds by remember { mutableStateOf(setOf<String>()) }
    var pendingSaveIds by remember { mutableStateOf(setOf<String>()) }
    var pendingViewIds by remember { mutableStateOf(setOf<String>()) }
    var viewedIds by remember { mutableStateOf(setOf<String>()) }
    var failedViewIds by remember { mutableStateOf(setOf<String>()) }
    var commentsClipId by remember { mutableStateOf<String?>(null) }
    var pendingVideoUri by remember { mutableStateOf<Uri?>(null) }
    var refreshKey by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pendingVideoUri = uri
    }

    LaunchedEffect(refreshKey) {
        if (clips.isEmpty()) loading = true
        loadError = null

        val discovery = runCatching { ApiClient.api.discoverClips(1, 20).clips.orEmpty() }
        val fallback = if (discovery.getOrNull().isNullOrEmpty()) {
            runCatching { ApiClient.api.clips(1, 20).clips.orEmpty() }
        } else {
            null
        }

        val resolved = when {
            discovery.isSuccess && discovery.getOrThrow().isNotEmpty() -> discovery.getOrThrow()
            fallback?.isSuccess == true -> fallback.getOrThrow()
            discovery.isSuccess -> discovery.getOrThrow()
            else -> null
        }

        if (resolved != null) {
            clips = resolved
            likedIds = resolved.filter { it.isLiked == true }.map { it.idStr }.toSet()
            savedIds = resolved.filter { it.isSaved == true }.map { it.idStr }.toSet()
            loaded = true
        } else {
            val cause = fallback?.exceptionOrNull() ?: discovery.exceptionOrNull()
            loadError = clipFailureMessage(cause, "load clips")
        }
        loading = false
    }

    fun toggleLike(id: String) {
        if (id.isBlank() || id in pendingLikeIds) return
        pendingLikeIds = pendingLikeIds + id
        interactionError = null
        scope.launch {
            runCatching {
                val response = ApiClient.api.likeClip(id)
                val confirmedLiked = response.get("isLiked")?.asBoolean
                    ?: throw IllegalStateException("The like response did not include its confirmed state")
                val confirmedCount = response.get("likeCount")?.asInt
                confirmedLiked to confirmedCount
            }.onSuccess { (confirmedLiked, confirmedCount) ->
                likedIds = if (confirmedLiked) likedIds + id else likedIds - id
                if (confirmedCount != null) {
                    clips = clips.map { clip ->
                        if (clip.idStr == id) clip.copy(likeCount = confirmedCount) else clip
                    }
                }
            }.onFailure {
                interactionError = clipFailureMessage(it, "update this like")
            }
            pendingLikeIds = pendingLikeIds - id
        }
    }

    fun toggleSave(id: String) {
        if (id.isBlank() || id in pendingSaveIds) return
        pendingSaveIds = pendingSaveIds + id
        interactionError = null
        scope.launch {
            runCatching {
                val response = ApiClient.api.saveClip(id)
                if (response.get("success")?.asBoolean == false) {
                    throw IllegalStateException("The save request was not accepted")
                }
                response.get("isSaved")?.asBoolean
                    ?: throw IllegalStateException("The save response did not include its confirmed state")
            }.onSuccess { confirmedSaved ->
                savedIds = if (confirmedSaved) savedIds + id else savedIds - id
            }.onFailure {
                interactionError = clipFailureMessage(it, "update this saved clip")
            }
            pendingSaveIds = pendingSaveIds - id
        }
    }

    fun syncView(id: String) {
        if (id.isBlank() || id in viewedIds || id in pendingViewIds) return
        pendingViewIds = pendingViewIds + id
        failedViewIds = failedViewIds - id
        scope.launch {
            runCatching {
                val response = ApiClient.api.viewClip(id)
                if (response.get("success")?.asBoolean != true) {
                    throw IllegalStateException("The view was not recorded")
                }
                response.get("viewCount")?.asInt
            }.onSuccess { confirmedCount ->
                viewedIds = viewedIds + id
                failedViewIds = failedViewIds - id
                if (confirmedCount != null) {
                    clips = clips.map { clip ->
                        if (clip.idStr == id) clip.copy(viewCount = confirmedCount) else clip
                    }
                }
            }.onFailure {
                failedViewIds = failedViewIds + id
            }
            pendingViewIds = pendingViewIds - id
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color.Black),
    ) {
        when {
            loading && clips.isEmpty() -> LoadingBox()
            loadError != null && clips.isEmpty() -> ClipsLoadError(
                message = loadError.orEmpty(),
                onRetry = { refreshKey++ },
            )
            loaded && clips.isEmpty() -> Column(modifier = Modifier.statusBarsPadding()) {
                ClipsHeader()
                EmptyState(
                    title = "No clips yet",
                    subtitle = "Educational clips will appear here",
                )
            }
            clips.isNotEmpty() -> {
                val pagerState = rememberPagerState(pageCount = { clips.size })
                val currentClipId = clips.getOrNull(pagerState.currentPage)?.idStr

                LaunchedEffect(currentClipId) {
                    currentClipId?.let(::syncView)
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
                        likePending = id in pendingLikeIds,
                        savePending = id in pendingSaveIds,
                        viewSyncFailed = id in failedViewIds,
                        likeCount = clip.likeCount ?: 0,
                        onLike = { toggleLike(id) },
                        onSave = { toggleSave(id) },
                        onRetryView = { syncView(id) },
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
                            scope.launch {
                                runCatching {
                                    val response = ApiClient.api.shareClip(id)
                                    if (response.get("success")?.asBoolean != true) {
                                        throw IllegalStateException("The share count was not recorded")
                                    }
                                }.onFailure {
                                    interactionError = "The clip was shared, but LYO could not sync the share count."
                                }
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

        val visibleError = interactionError ?: loadError?.takeIf { clips.isNotEmpty() }
        visibleError?.let { message ->
            ClipActionError(
                message = message,
                onDismiss = {
                    interactionError = null
                    if (clips.isNotEmpty()) loadError = null
                },
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .statusBarsPadding()
                    .padding(top = 64.dp, start = 16.dp, end = 16.dp),
            )
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
        ClipCommentsSheet(
            clipId = clipId,
            onDismiss = { commentsClipId = null },
            onCountChanged = { delta ->
                clips = clips.map { clip ->
                    if (clip.idStr == clipId) {
                        clip.copy(commentCount = ((clip.commentCount ?: 0) + delta).coerceAtLeast(0))
                    } else {
                        clip
                    }
                }
            },
        )
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
        val normalizedTitle = title.trim()
        if (normalizedTitle.isBlank() || submitting) return
        submitting = true
        error = null
        scope.launch {
            var temporaryFile: File? = null
            runCatching {
                val contentType = context.contentResolver.getType(videoUri) ?: "video/mp4"
                val extension = when (contentType) {
                    "video/quicktime" -> "mov"
                    "video/webm" -> "webm"
                    else -> "mp4"
                }
                temporaryFile = withContext(Dispatchers.IO) {
                    File.createTempFile("lyo-clip-", ".$extension", context.cacheDir).also { file ->
                        context.contentResolver.openInputStream(videoUri)?.use { input ->
                            file.outputStream().use { output -> input.copyTo(output) }
                        } ?: throw IllegalStateException("Could not read the selected video")
                    }
                }
                val file = temporaryFile ?: throw IllegalStateException("Could not prepare the selected video")
                val part = MultipartBody.Part.createFormData(
                    "file",
                    "clip.$extension",
                    file.asRequestBody(contentType.toMediaType()),
                )
                val uploaded = ApiClient.api.uploadMedia(
                    file = part,
                    folder = "clips".toRequestBody("text/plain".toMediaType()),
                )
                val url = uploaded.url ?: throw IllegalStateException("The upload did not return a media URL")
                val created = ApiClient.api.createClip(
                    ClipCreateRequest(
                        title = normalizedTitle,
                        videoUrl = url,
                        subject = subject.trim().ifEmpty { null },
                        tags = subject.trim().lowercase().let {
                            if (it.isEmpty()) emptyList() else listOf(it)
                        },
                    ),
                )
                if (created.success != true || created.clip == null) {
                    throw IllegalStateException("The clip was not confirmed by the server")
                }
            }.onSuccess {
                onPublished()
            }.onFailure {
                error = clipFailureMessage(it, "publish this clip")
            }
            withContext(Dispatchers.IO) { temporaryFile?.delete() }
            submitting = false
        }
    }

    AlertDialog(
        onDismissRequest = { if (!submitting) onDismiss() },
        title = { Text("Publish clip") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                OutlinedTextField(
                    value = title,
                    onValueChange = {
                        title = it
                        error = null
                    },
                    label = { Text("Title") },
                    singleLine = true,
                    enabled = !submitting,
                )
                OutlinedTextField(
                    value = subject,
                    onValueChange = {
                        subject = it
                        error = null
                    },
                    label = { Text("Subject (optional)") },
                    singleLine = true,
                    enabled = !submitting,
                )
                if (submitting) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                        Spacer(Modifier.width(8.dp))
                        Text("Uploading…", style = MaterialTheme.typography.bodySmall)
                    }
                }
                error?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            TextButton(onClick = ::publish, enabled = title.isNotBlank() && !submitting) {
                Text(if (submitting) "Publishing…" else "Publish")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancel") }
        },
    )
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ClipCommentsSheet(
    clipId: String,
    onDismiss: () -> Unit,
    onCountChanged: (Int) -> Unit,
) {
    var comments by remember(clipId) { mutableStateOf<List<ClipCommentDto>>(emptyList()) }
    var loading by remember(clipId) { mutableStateOf(true) }
    var loaded by remember(clipId) { mutableStateOf(false) }
    var loadError by remember(clipId) { mutableStateOf<String?>(null) }
    var actionError by remember(clipId) { mutableStateOf<String?>(null) }
    var text by remember(clipId) { mutableStateOf("") }
    var sending by remember(clipId) { mutableStateOf(false) }
    var pendingDeleteIds by remember(clipId) { mutableStateOf(setOf<String>()) }
    var reloadKey by remember(clipId) { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()
    val currentUserId = Session.user?.id.orEmpty()

    LaunchedEffect(clipId, reloadKey) {
        if (comments.isEmpty()) loading = true
        loadError = null
        runCatching { ApiClient.api.clipComments(clipId).items.orEmpty() }
            .onSuccess {
                comments = it
                loaded = true
            }
            .onFailure { loadError = clipFailureMessage(it, "load comments") }
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
                loading && comments.isEmpty() -> LoadingBox(modifier = Modifier.height(160.dp))
                loadError != null && comments.isEmpty() && !loaded -> CommentLoadError(
                    message = loadError.orEmpty(),
                    onRetry = { reloadKey++ },
                )
                loaded && comments.isEmpty() -> EmptyState(
                    title = "No comments yet",
                    subtitle = "Be the first to reply",
                )
                else -> LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier.weight(1f, fill = false),
                ) {
                    items(comments, key = { it.id ?: "comment-${comments.indexOf(it)}" }) { comment ->
                        val commentId = comment.id.orEmpty()
                        Row(verticalAlignment = Alignment.Top) {
                            LyoAvatar(
                                name = comment.authorName ?: "M",
                                avatarUrl = comment.authorAvatar,
                                size = 30,
                            )
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
                                if (commentId in pendingDeleteIds) {
                                    CircularProgressIndicator(
                                        modifier = Modifier.size(18.dp),
                                        strokeWidth = 2.dp,
                                    )
                                } else {
                                    IconButton(
                                        onClick = {
                                            if (commentId.isBlank()) return@IconButton
                                            pendingDeleteIds = pendingDeleteIds + commentId
                                            actionError = null
                                            scope.launch {
                                                runCatching {
                                                    val response = ApiClient.api.deleteClipComment(clipId, commentId)
                                                    check(response.isSuccessful) { "Unable to delete comment" }
                                                }.onSuccess {
                                                    comments = comments.filterNot { it.id == comment.id }
                                                    onCountChanged(-1)
                                                }.onFailure {
                                                    actionError = clipFailureMessage(it, "delete this comment")
                                                }
                                                pendingDeleteIds = pendingDeleteIds - commentId
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
            }

            val visibleError = actionError ?: loadError?.takeIf { comments.isNotEmpty() }
            visibleError?.let { message ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                ) {
                    Text(
                        message,
                        color = MaterialTheme.colorScheme.error,
                        style = MaterialTheme.typography.bodySmall,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(
                        onClick = {
                            actionError = null
                            if (comments.isNotEmpty()) loadError = null
                        },
                    ) { Text("Dismiss") }
                }
            }

            Spacer(Modifier.height(8.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(bottom = 12.dp),
            ) {
                OutlinedTextField(
                    value = text,
                    onValueChange = {
                        text = it
                        actionError = null
                    },
                    placeholder = { Text("Add a comment…", color = TextSecondary) },
                    enabled = !sending,
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = {
                        val draft = text.trim()
                        if (draft.isBlank() || sending) return@IconButton
                        sending = true
                        actionError = null
                        scope.launch {
                            runCatching {
                                ApiClient.api.createClipComment(
                                    clipId,
                                    CommunityCommentRequest(draft),
                                )
                            }.onSuccess { created ->
                                comments = listOf(created) + comments
                                loaded = true
                                text = ""
                                onCountChanged(1)
                            }.onFailure {
                                actionError = clipFailureMessage(it, "post this comment")
                            }
                            sending = false
                        }
                    },
                    enabled = text.isNotBlank() && !sending,
                ) {
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
    likePending: Boolean,
    savePending: Boolean,
    viewSyncFailed: Boolean,
    likeCount: Int,
    onLike: () -> Unit,
    onSave: () -> Unit,
    onRetryView: () -> Unit,
    onComments: () -> Unit,
    onShare: () -> Unit,
) {
    Box(modifier = Modifier.fillMaxSize()) {
        when {
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

        if (viewSyncFailed) {
            Text(
                text = "View sync failed · Retry",
                style = MaterialTheme.typography.labelMedium,
                color = Color.White,
                modifier = Modifier
                    .align(Alignment.TopCenter)
                    .statusBarsPadding()
                    .padding(top = 68.dp)
                    .background(Color.Black.copy(alpha = 0.65f), RoundedCornerShape(20.dp))
                    .clickable(onClick = onRetryView)
                    .padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }

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
                        .background(Color.White.copy(alpha = 0.15f), RoundedCornerShape(50))
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

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 10.dp, bottom = 32.dp),
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onLike, enabled = !likePending) {
                    if (likePending) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(24.dp),
                            strokeWidth = 2.dp,
                        )
                    } else {
                        Icon(
                            if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = if (liked) "Unlike" else "Like",
                            tint = if (liked) LyoPink else Color.White,
                            modifier = Modifier.size(30.dp),
                        )
                    }
                }
                Text(likeCount.toString(), style = MaterialTheme.typography.labelMedium, color = Color.White)
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
                Text("Share", style = MaterialTheme.typography.labelMedium, color = Color.White)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onSave, enabled = !savePending) {
                    if (savePending) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(24.dp),
                            strokeWidth = 2.dp,
                        )
                    } else {
                        Icon(
                            if (saved) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                            contentDescription = if (saved) "Remove saved clip" else "Save",
                            tint = Color.White,
                            modifier = Modifier.size(28.dp),
                        )
                    }
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

@Composable
private fun ClipsLoadError(message: String, onRetry: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .fillMaxSize()
            .padding(24.dp),
    ) {
        Text(
            "Clips could not be loaded",
            style = MaterialTheme.typography.headlineSmall,
            color = Color.White,
        )
        Text(
            message,
            style = MaterialTheme.typography.bodyMedium,
            color = Color.White.copy(alpha = 0.75f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 8.dp),
        )
        TextButton(onClick = onRetry, modifier = Modifier.padding(top = 12.dp)) {
            Text("Retry")
        }
    }
}

@Composable
private fun CommentLoadError(message: String, onRetry: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 28.dp),
    ) {
        Text("Comments could not be loaded", color = TextPrimary)
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = TextSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 4.dp),
        )
        TextButton(onClick = onRetry) { Text("Retry") }
    }
}

@Composable
private fun ClipActionError(message: String, onDismiss: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .background(Color.Black.copy(alpha = 0.82f), RoundedCornerShape(14.dp))
            .padding(start = 14.dp, top = 8.dp, bottom = 8.dp, end = 6.dp),
    ) {
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = Color.White,
            modifier = Modifier.weight(1f),
        )
        TextButton(onClick = onDismiss) { Text("Dismiss") }
    }
}

private fun clipFailureMessage(error: Throwable?, action: String): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "Sign in again to $action."
        404 -> "This clip is no longer available."
        413 -> "The selected video is too large to upload."
        429 -> "Too many requests. Wait a moment and try again."
        in 500..599 -> "LYO could not $action because the service is unavailable."
        else -> "LYO could not $action (${error.code()})."
    }
    is IOException -> "Check your connection and try to $action again."
    null -> "LYO could not $action."
    else -> error.localizedMessage ?: "LYO could not $action."
}
