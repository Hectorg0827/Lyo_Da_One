package com.lyo.app.ui.screens.clips

import android.content.Intent
import android.widget.Toast
import android.net.Uri
import androidx.media3.common.C
import androidx.media3.common.AudioAttributes
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.common.PlaybackException
import androidx.media3.exoplayer.ExoPlayer
import androidx.media3.ui.PlayerView
import androidx.media3.ui.AspectRatioFrameLayout
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.pager.VerticalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Pause
import androidx.compose.material.icons.filled.VolumeOff
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.Delete
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material.icons.outlined.Flag
import androidx.compose.material.icons.outlined.Visibility
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.Slider
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.mutableStateMapOf
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableLongStateOf
import androidx.compose.runtime.rememberUpdatedState
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.platform.LocalUriHandler
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavHostController
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import coil.compose.AsyncImage
import com.lyo.app.R
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
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.asRequestBody
import okhttp3.RequestBody.Companion.toRequestBody
import retrofit2.HttpException

private enum class DiscoverFeed(val label: String, val sort: String) {
    FOR_YOU("For You", "for_you"),
    LATEST("Latest", "latest"),
    POPULAR("Popular", "popular"),
    SAVED("Saved", "saved"),
}

private suspend fun discoverPage(
    page: Int,
    feed: DiscoverFeed,
    subject: String?,
    query: String?,
): List<ClipDto> =
    if (feed == DiscoverFeed.SAVED) {
        ApiClient.api.savedClips(page, 20, subject, query).clips.orEmpty()
    } else {
        ApiClient.api.discoverClips(page, 20, subject, feed.sort, query).clips.orEmpty()
    }

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
    var reportingClip by remember { mutableStateOf<ClipDto?>(null) }
    // Loaded videos that left the feed since page 1 loaded, by a report or a
    // block. Each one moves later server pages up a place.
    var removedSinceLoad by remember { mutableIntStateOf(0) }
    // Reported videos and blocked owners stay out of every page merged later,
    // including one already on its way when they were removed.
    var reportedIds by remember { mutableStateOf(setOf<String>()) }
    var blockedOwnerIds by remember { mutableStateOf(setOf<String>()) }
    fun hidden(clip: ClipDto): Boolean =
        clip.idStr in reportedIds || clip.ownerIdStr?.let { it in blockedOwnerIds } == true
    var pendingVideoUri by remember { mutableStateOf<Uri?>(null) }
    var refreshKey by remember { mutableIntStateOf(0) }
    var feedMode by remember { mutableStateOf(DiscoverFeed.FOR_YOU) }
    var selectedSubject by remember { mutableStateOf<String?>(null) }
    var availableSubjects by remember { mutableStateOf<List<String>>(emptyList()) }
    var searchOpen by remember { mutableStateOf(false) }
    var searchDraft by remember { mutableStateOf("") }
    var submittedQuery by remember { mutableStateOf("") }
    var nextPage by remember { mutableIntStateOf(2) }
    var hasMore by remember { mutableStateOf(true) }
    var loadingMore by remember { mutableStateOf(false) }
    var pausedClipId by remember { mutableStateOf<String?>(null) }
    var scrubbingClipId by remember { mutableStateOf<String?>(null) }
    var pendingAdvanceId by remember { mutableStateOf<String?>(null) }
    var muted by remember { mutableStateOf(false) }
    var feedGeneration by remember { mutableIntStateOf(0) }
    val lifecycleOwner = LocalLifecycleOwner.current
    var foreground by remember(lifecycleOwner) { mutableStateOf(lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)) }
    // Exactly three small player instances at most: current, previous, next.
    // Unlike VideoView, ExoPlayer prepares upcoming clips before a swipe.
    val players = remember { mutableStateMapOf<String, ExoPlayer>() }
    val playerSources = remember { mutableMapOf<String, String>() }
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, _ ->
            foreground = lifecycleOwner.lifecycle.currentState.isAtLeast(Lifecycle.State.RESUMED)
            if (!foreground) players.values.forEach { it.playWhenReady = false }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose {
            lifecycleOwner.lifecycle.removeObserver(observer)
            players.values.forEach { it.playWhenReady = false }
        }
    }
    DisposableEffect(Unit) {
        onDispose {
            players.values.forEach { it.release() }
            players.clear()
            playerSources.clear()
        }
    }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    LaunchedEffect(clips.isEmpty()) {
        if (clips.isEmpty()) {
            players.values.forEach { it.release() }
            players.clear()
            playerSources.clear()
        }
    }

    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pendingVideoUri = uri
    }

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.discoverClipFilters() }
            .onSuccess { response ->
                availableSubjects = response.subjects.map { it.name.trim() }
                    .filter { it.isNotEmpty() }.distinct()
            }
    }

    LaunchedEffect(refreshKey, feedMode, selectedSubject, submittedQuery) {
        val generation = ++feedGeneration
        val requestedFeed = feedMode
        val requestedSubject = selectedSubject
        val requestedQuery = submittedQuery.trim().takeIf { it.isNotEmpty() }
        loading = true
        loaded = false
        clips = emptyList()
        loadingMore = false
        pendingAdvanceId = null
        loadError = null

        val discovery = runCatching { discoverPage(1, requestedFeed, requestedSubject, requestedQuery) }
        // An unfiltered For You feed can fall back to the public library if
        // Discover has no clips; a filtered search must never show unrelated videos.
        val fallback = if (requestedFeed == DiscoverFeed.FOR_YOU &&
            requestedSubject == null && requestedQuery == null &&
            discovery.getOrNull().isNullOrEmpty()
        ) {
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

        currentCoroutineContext().ensureActive()
        if (generation != feedGeneration) return@LaunchedEffect
        if (resolved != null) {
            clips = resolved.filterNot { hidden(it) }
            likedIds = resolved.filter { it.isLiked == true }.map { it.idStr }.toSet()
            savedIds = resolved.filter { it.isSaved == true }.map { it.idStr }.toSet()
            loaded = true
            nextPage = 2
            removedSinceLoad = 0
            hasMore = resolved.size >= 20
            loadingMore = false
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

    val subjectChoices = (
        availableSubjects + clips.mapNotNull { it.subject?.trim() } + listOfNotNull(selectedSubject)
    ).filter { it.isNotBlank() }.distinct()

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
            loaded && clips.isEmpty() -> EmptyState(
                title = if (feedMode == DiscoverFeed.SAVED) "No saved videos" else "No clips found",
                subtitle = if (submittedQuery.isNotBlank() || selectedSubject != null)
                    "No videos match this search or topic. Try another filter."
                else if (feedMode == DiscoverFeed.SAVED)
                    "Save a clip to find it here."
                else
                    "Educational clips will appear here",
            )
            clips.isNotEmpty() -> {
                val pagerState = rememberPagerState(pageCount = { clips.size })
                val currentClipId = clips.getOrNull(pagerState.currentPage)?.idStr
                val playbackAllowed = foreground && !searchOpen && commentsClipId == null && pendingVideoUri == null && reportingClip == null

                // Keep only the visible reel and its immediate neighbours in
                // memory. Preparing the next clip ahead of the swipe removes
                // the per-item buffering delay of VideoView.
                LaunchedEffect(clips.map { it.idStr to it.videoUrl }, pagerState.currentPage, pausedClipId, scrubbingClipId, playbackAllowed, muted) {
                    val index = pagerState.currentPage
                    val neighbours = (index - 1..index + 1)
                        .mapNotNull { clips.getOrNull(it) }
                        .filter { !it.videoUrl.isNullOrBlank() }
                    val keep = neighbours.map { it.idStr }.toSet()
                    players.keys.toList().filterNot { it in keep }.forEach { key ->
                        players.remove(key)?.release()
                        playerSources.remove(key)
                    }
                    neighbours.forEach { clip ->
                        if (playerSources[clip.idStr] != clip.videoUrl) {
                            players.remove(clip.idStr)?.release()
                            playerSources[clip.idStr] = clip.videoUrl!!
                        }
                        val player = players[clip.idStr] ?: ExoPlayer.Builder(context).build().apply {
                            repeatMode = Player.REPEAT_MODE_OFF
                            setAudioAttributes(AudioAttributes.Builder().setUsage(C.USAGE_MEDIA).setContentType(C.AUDIO_CONTENT_TYPE_MOVIE).build(), true)
                            setHandleAudioBecomingNoisy(true)
                            setMediaItem(MediaItem.fromUri(clip.videoUrl!!))
                            prepare()
                        }.also { players[clip.idStr] = it }
                        player.volume = if (muted) 0f else 1f
                        player.playWhenReady = DiscoverPlaybackIntent(clip.idStr == currentClipId, playbackAllowed, pausedClipId == clip.idStr, scrubbingClipId == clip.idStr).shouldPlay
                    }
                }

                LaunchedEffect(pagerState.currentPage, clips.size, hasMore, loading, refreshKey) {
                    if (loading || !hasMore || loadingMore || pagerState.currentPage < clips.size - 4) return@LaunchedEffect
                    loadingMore = true
                    val generation = feedGeneration
                    val page = nextPage
                    // This request belongs to the feed, so a swipe does not cancel it.
                    scope.launch {
                        try {
                            // After reports or blocks, the page before is fetched too, so
                            // the videos that moved onto it are not skipped.
                            val fetched = mutableListOf<ClipDto>()
                            var lastBatch = emptyList<ClipDto>()
                            for (number in DiscoverSafety.pagesToFetch(page, removedSinceLoad, 20)) {
                                lastBatch = discoverPage(number, feedMode, selectedSubject, submittedQuery.trim().takeIf { it.isNotEmpty() })
                                fetched += lastBatch
                            }
                            if (generation != feedGeneration) return@launch
                            val known = clips.map { it.idStr }.toSet()
                            clips = clips + fetched.distinctBy { it.idStr }.filterNot { it.idStr in known || hidden(it) }
                            nextPage = page + 1
                            hasMore = lastBatch.size == 20
                        } catch (cancelled: CancellationException) {
                            throw cancelled
                        } catch (_: Exception) {
                            if (generation == feedGeneration) {
                                hasMore = false
                                interactionError = "More clips could not be loaded. Refresh Discover to retry."
                            }
                        } finally {
                            if (generation == feedGeneration) loadingMore = false
                        }
                    }
                }

                LaunchedEffect(currentClipId) {
                    if (pendingAdvanceId != currentClipId) pendingAdvanceId = null
                    if (pausedClipId != currentClipId) pausedClipId = null
                    if (scrubbingClipId != currentClipId) scrubbingClipId = null
                    currentClipId?.let(::syncView)
                }

                LaunchedEffect(pendingAdvanceId, currentClipId, clips.size, playbackAllowed) {
                    if (pendingAdvanceId != null && pendingAdvanceId == currentClipId && playbackAllowed) {
                        val page = pagerState.currentPage
                        val next = nextDiscoverPage(page, page, clips.size)
                        if (next != null) {
                            pendingAdvanceId = null
                            pagerState.animateScrollToPage(page + 1)
                        }
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
                        player = players[id],
                        isPaused = pausedClipId == id,
                        foreground = playbackAllowed,
                        isScrubbing = scrubbingClipId == id,
                        muted = muted,
                        onToggleMute = { muted = !muted },
                        onScrubbingChange = { scrubbing ->
                            if (scrubbing) { pendingAdvanceId = null; scrubbingClipId = id }
                            else if (scrubbingClipId == id) scrubbingClipId = null
                        },
                        onSeek = { position ->
                            if (pagerState.currentPage == page && playbackAllowed) players[id]?.seekTo(position)
                        },
                        onRetry = {
                            if (pagerState.currentPage == page && playbackAllowed) {
                                pendingAdvanceId = null
                                pausedClipId = null
                                players[id]?.prepare()
                                players[id]?.playWhenReady = scrubbingClipId != id
                            }
                        },
                        onExternalPause = { if (pagerState.currentPage == page) pausedClipId = id },
                        onTogglePlayback = {
                            pendingAdvanceId = null
                            if (players[id]?.playbackState == Player.STATE_ENDED) {
                                players[id]?.seekTo(0)
                                pausedClipId = null
                            } else pausedClipId = if (pausedClipId == id) null else id
                        },
                        onPlaybackEnded = {
                            if (pagerState.currentPage == page && playbackAllowed) pendingAdvanceId = id
                        },
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
                        onReport = if (DiscoverSafety.canReport(clip.ownerIdStr, Session.user?.id)) {
                            { reportingClip = clip }
                        } else {
                            null
                        },
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

            }
        }

        ClipsHeader(
            feed = feedMode,
            selectedSubject = selectedSubject,
            subjects = subjectChoices,
            searchOpen = searchOpen,
            searchDraft = searchDraft,
            onFeedSelected = { mode ->
                selectedSubject = null
                feedMode = mode
            },
            onSubjectSelected = { subject ->
                selectedSubject = subject
                feedMode = DiscoverFeed.FOR_YOU
            },
            onToggleSearch = {
                searchDraft = submittedQuery
                searchOpen = !searchOpen
            },
            onSearchDraftChange = { searchDraft = it },
            onSearchSubmit = {
                submittedQuery = searchDraft.trim()
                searchOpen = false
            },
            modifier = Modifier
                .align(Alignment.TopCenter)
                .statusBarsPadding(),
        )

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
                    .padding(top = 132.dp, start = 16.dp, end = 16.dp),
            )
        }

        if (!searchOpen) {
            CreateVideoPill(
                onClick = { videoPicker.launch("video/*") },
                // Keep creation on the left of the reel, outside the right-side
                // Like/Comment/Share/Save rail even on narrow Android phones.
                modifier = Modifier
                    .align(Alignment.TopStart)
                    .statusBarsPadding()
                    .padding(top = 78.dp, start = 12.dp),
            )
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

    reportingClip?.let { clip ->
        // A reported video, and every video by someone blocked, leaves the
        // feed at once; the server also stops sending them.
        fun leaveFeed(message: String, gone: (ClipDto) -> Boolean) {
            reportingClip = null
            val before = clips.size
            clips = clips.filterNot(gone)
            removedSinceLoad += before - clips.size
            Toast.makeText(context, message, Toast.LENGTH_SHORT).show()
            if (clips.isEmpty() && hasMore) refreshKey++
        }
        ReportClipSheet(
            clip = clip,
            canBlock = DiscoverSafety.canBlock(
                clip.ownerIdStr,
                Session.user?.id,
                isLibrary = clip.attribution?.displayLine != null,
            ),
            onDismiss = { reportingClip = null },
            onReported = { outcome ->
                reportedIds = reportedIds + clip.idStr
                leaveFeed(outcome.message) { it.idStr == clip.idStr }
            },
            onBlocked = { outcome ->
                val owner = clip.ownerIdStr
                if (owner != null) blockedOwnerIds = blockedOwnerIds + owner
                leaveFeed(outcome.message) { owner != null && it.ownerIdStr == owner }
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

/**
 * TikTok-style Discover chrome: the real LYO brand mark and search control are
 * anchored, while the server-backed feed and subject filters scroll between.
 * A compact gradient leaves the video visible under the controls.
 */
@Composable
private fun ClipsHeader(
    feed: DiscoverFeed,
    selectedSubject: String?,
    subjects: List<String>,
    searchOpen: Boolean,
    searchDraft: String,
    onFeedSelected: (DiscoverFeed) -> Unit,
    onSubjectSelected: (String) -> Unit,
    onToggleSearch: () -> Unit,
    onSearchDraftChange: (String) -> Unit,
    onSearchSubmit: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    listOf(Color(0xE6000000), Color(0x99000000), Color.Transparent),
                ),
            )
            .padding(bottom = 14.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .height(64.dp)
                .padding(horizontal = 10.dp),
        ) {
            Image(
                painter = painterResource(R.drawable.lyo_discover_logo),
                contentDescription = "LYO",
                contentScale = ContentScale.Fit,
                modifier = Modifier.size(44.dp),
            )
            Spacer(Modifier.width(8.dp))
            LazyRow(
                modifier = Modifier.weight(1f),
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(horizontal = 2.dp),
            ) {
                items(DiscoverFeed.entries.toList()) { choice ->
                    DiscoverFilterTab(
                        label = choice.label,
                        selected = selectedSubject == null && feed == choice,
                        onClick = { onFeedSelected(choice) },
                    )
                }
                items(subjects) { subject ->
                    DiscoverFilterTab(
                        label = subject,
                        selected = selectedSubject == subject,
                        onClick = { onSubjectSelected(subject) },
                    )
                }
            }
            Spacer(Modifier.width(4.dp))
            IconButton(
                onClick = onToggleSearch,
                modifier = Modifier.size(44.dp),
            ) {
                Icon(
                    Icons.Filled.Search,
                    contentDescription = "Search Discover videos",
                    tint = Color.White,
                    modifier = Modifier.size(28.dp),
                )
            }
        }

        if (searchOpen) {
            OutlinedTextField(
                value = searchDraft,
                onValueChange = onSearchDraftChange,
                placeholder = { Text("Search videos or subjects…", color = Color.White.copy(alpha = 0.6f)) },
                singleLine = true,
                keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                keyboardActions = KeyboardActions(onSearch = { onSearchSubmit() }),
                trailingIcon = {
                    IconButton(onClick = onSearchSubmit) {
                        Icon(Icons.Filled.Search, contentDescription = "Apply search", tint = Color.White)
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 4.dp),
            )
        }
    }
}

@Composable
private fun DiscoverFilterTab(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .clickable(onClick = onClick)
            .padding(horizontal = 6.dp, vertical = 8.dp),
    ) {
        Text(
            text = label,
            color = Color.White.copy(alpha = if (selected) 1f else 0.65f),
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
            style = MaterialTheme.typography.bodyMedium,
            maxLines = 1,
        )
        Spacer(Modifier.height(6.dp))
        Box(
            modifier = Modifier
                .width(26.dp)
                .height(3.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(
                    if (selected) Brush.horizontalGradient(
                        listOf(Color(0xFF5F7BFF), Color(0xFFAC67FF)),
                    ) else Brush.horizontalGradient(listOf(Color.Transparent, Color.Transparent)),
                ),
        )
    }
}

@Composable
private fun CreateVideoPill(onClick: () -> Unit, modifier: Modifier = Modifier) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        modifier = modifier
            .clip(RoundedCornerShape(50.dp))
            .background(Brush.horizontalGradient(listOf(Color(0xFF2563EB), Color(0xFF9333EA))))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 8.dp),
    ) {
        Icon(Icons.Filled.Add, contentDescription = null, tint = Color.White, modifier = Modifier.size(16.dp))
        Text("Create video", color = Color.White, fontWeight = FontWeight.SemiBold,
            style = MaterialTheme.typography.labelMedium)
    }
}

@Composable
private fun ClipPage(
    clip: ClipDto,
    index: Int,
    isCurrent: Boolean,
    player: ExoPlayer?,
    isPaused: Boolean,
    foreground: Boolean,
    isScrubbing: Boolean,
    muted: Boolean,
    onToggleMute: () -> Unit,
    onScrubbingChange: (Boolean) -> Unit,
    onSeek: (Long) -> Unit,
    onRetry: () -> Unit,
    onExternalPause: () -> Unit,
    onTogglePlayback: () -> Unit,
    onPlaybackEnded: () -> Unit,
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
    onReport: (() -> Unit)?,
) {
    var playbackError by remember(clip.idStr) { mutableStateOf<String?>(null) }

    val canAdvance by rememberUpdatedState(DiscoverPlaybackIntent(isCurrent, foreground, isPaused, isScrubbing).shouldPlay)
    val endedCallback by rememberUpdatedState(onPlaybackEnded)
    val externalPauseCallback by rememberUpdatedState(onExternalPause)
    var position by remember(player) { mutableLongStateOf(0L) }
    var duration by remember(player) { mutableLongStateOf(0L) }
    LaunchedEffect(player, isCurrent, foreground, isScrubbing) {
        if (player == null || !isCurrent || !foreground) return@LaunchedEffect
        while (true) {
            if (!isScrubbing) position = player.currentPosition.coerceAtLeast(0)
            duration = player.duration.takeIf { it != C.TIME_UNSET && it > 0 } ?: 0
            delay(200)
        }
    }

    DisposableEffect(player) {
        if (player == null) {
            onDispose { }
        } else {
            val listener = object : Player.Listener {
                override fun onPlaybackStateChanged(state: Int) {
                    if (state == Player.STATE_READY) playbackError = null
                    if (state == Player.STATE_ENDED && canAdvance) endedCallback()
                }
                override fun onPlayWhenReadyChanged(playWhenReady: Boolean, reason: Int) {
                    if (!playWhenReady && reason == Player.PLAY_WHEN_READY_CHANGE_REASON_AUDIO_BECOMING_NOISY) externalPauseCallback()
                }
                override fun onPlayerError(error: PlaybackException) {
                    playbackError = "This video could not be played."
                }
            }
            player.addListener(listener)
            onDispose { player.removeListener(listener) }
        }
    }

    Box(modifier = Modifier.fillMaxSize()) {
        if (!clip.thumbnailUrl.isNullOrBlank()) {
            AsyncImage(
                model = clip.thumbnailUrl,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(
                modifier = Modifier.fillMaxSize()
                    .background(CardGradients[index % CardGradients.size]),
            )
        }

        if (player != null) {
            AndroidView(
                factory = { context ->
                    PlayerView(context).apply {
                        useController = false
                        resizeMode = AspectRatioFrameLayout.RESIZE_MODE_ZOOM
                        setShutterBackgroundColor(android.graphics.Color.TRANSPARENT)
                    }
                },
                update = { view -> view.player = player },
                onRelease = { view -> view.player = null },
                modifier = Modifier.fillMaxSize().clickable(onClick = onTogglePlayback),
            )
        }
        if (isCurrent && player != null && playbackError == null) {
            Column(modifier = Modifier.align(Alignment.BottomCenter).fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
                Slider(
                    value = position.toFloat().coerceIn(0f, duration.coerceAtLeast(1).toFloat()),
                    onValueChange = { value -> onScrubbingChange(true); position = value.toLong() },
                    onValueChangeFinished = { onSeek(position); onScrubbingChange(false) },
                    valueRange = 0f..duration.coerceAtLeast(1).toFloat(),
                    enabled = duration > 0 && foreground,
                    modifier = Modifier.semantics { contentDescription = "Seek video" },
                )
                Row(verticalAlignment = Alignment.CenterVertically) {
                    IconButton(onClick = onTogglePlayback) {
                        Icon(if (isPaused || player.playbackState == Player.STATE_ENDED) Icons.Filled.PlayArrow else Icons.Filled.Pause,
                            contentDescription = if (isPaused) "Play video" else "Pause video", tint = Color.White)
                    }
                    Text(clipPlaybackTime(position) + " / " + clipPlaybackTime(duration), color = Color.White, style = MaterialTheme.typography.labelSmall)
                    Spacer(Modifier.weight(1f))
                    IconButton(onClick = onToggleMute) {
                        Icon(if (muted) Icons.Filled.VolumeOff else Icons.Filled.VolumeUp,
                            contentDescription = if (muted) "Unmute video" else "Mute video", tint = Color.White)
                    }
                }
            }
        }

        if (isPaused && isCurrent) {
            Icon(
                Icons.Filled.PlayArrow,
                contentDescription = "Paused — tap to resume",
                tint = Color.White,
                modifier = Modifier.align(Alignment.Center).size(44.dp),
            )
        }
        if (playbackError != null && isCurrent) {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.align(Alignment.Center)
                    .background(Color.Black.copy(alpha = 0.8f), RoundedCornerShape(12.dp))
                    .padding(16.dp),
            ) {
                Text(playbackError.orEmpty(), color = Color.White)
                Row {
                    TextButton(onClick = { playbackError = null; onRetry() }) {
                        Text("Retry", color = Color.White)
                    }
                    TextButton(onClick = onPlaybackEnded) {
                        Text("Next clip", color = Color.White)
                    }
                }
            }
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
                .padding(start = 16.dp, bottom = 96.dp),
        ) {
            Text(
                clip.title ?: "Untitled Clip",
                style = MaterialTheme.typography.titleLarge,
                fontWeight = FontWeight.Bold,
                color = Color.White,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            // Library videos carry their creator and licence: open licences
            // are only honoured when the credit travels with the video.
            clip.attribution?.displayLine?.let { credit ->
                val source = clip.attribution?.sourceLink
                val uriHandler = LocalUriHandler.current
                Spacer(Modifier.height(2.dp))
                Text(
                    credit,
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White.copy(alpha = 0.75f),
                    textDecoration = if (source != null) TextDecoration.Underline else null,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                    modifier = if (source != null) {
                        Modifier.clickable { runCatching { uriHandler.openUri(source) } }
                    } else {
                        Modifier
                    },
                )
            }
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
            verticalArrangement = Arrangement.spacedBy(6.dp),
            modifier = Modifier
                .align(Alignment.BottomEnd)
                .padding(end = 10.dp, bottom = 104.dp),
        ) {
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onLike, enabled = !likePending, modifier = Modifier.size(44.dp)) {
                    if (likePending) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(22.dp),
                            strokeWidth = 2.dp,
                        )
                    } else {
                        Icon(
                            if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder,
                            contentDescription = if (liked) "Unlike" else "Like",
                            tint = if (liked) LyoPink else Color.White,
                            modifier = Modifier.size(24.dp),
                        )
                    }
                }
                Text(likeCount.toString(), style = MaterialTheme.typography.labelSmall, color = Color.White)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onComments, modifier = Modifier.size(44.dp)) {
                    Icon(
                        Icons.Outlined.ChatBubbleOutline,
                        contentDescription = "Comments",
                        tint = Color.White,
                        modifier = Modifier.size(24.dp),
                    )
                }
                Text(
                    (clip.commentCount ?: 0).toString(),
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                )
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onShare, modifier = Modifier.size(44.dp)) {
                    Icon(
                        Icons.Filled.Share,
                        contentDescription = "Share",
                        tint = Color.White,
                        modifier = Modifier.size(23.dp),
                    )
                }
                Text("Share", style = MaterialTheme.typography.labelSmall, color = Color.White)
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                IconButton(onClick = onSave, enabled = !savePending, modifier = Modifier.size(44.dp)) {
                    if (savePending) {
                        CircularProgressIndicator(
                            color = Color.White,
                            modifier = Modifier.size(22.dp),
                            strokeWidth = 2.dp,
                        )
                    } else {
                        Icon(
                            if (saved) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder,
                            contentDescription = if (saved) "Remove saved clip" else "Save",
                            tint = Color.White,
                            modifier = Modifier.size(24.dp),
                        )
                    }
                }
                Text(
                    if (saved) "Saved" else "Save",
                    style = MaterialTheme.typography.labelSmall,
                    color = Color.White,
                )
            }
            // Report (and Block, inside the sheet); not on the learner's own video.
            onReport?.let { report ->
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    IconButton(onClick = report, modifier = Modifier.size(44.dp)) {
                        Icon(
                            Icons.Outlined.Flag,
                            contentDescription = "Report video",
                            tint = Color.White,
                            modifier = Modifier.size(23.dp),
                        )
                    }
                    Text("Report", style = MaterialTheme.typography.labelSmall, color = Color.White)
                }
            }
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Icon(
                    Icons.Outlined.Visibility,
                    contentDescription = "Views",
                    tint = Color.White,
                    modifier = Modifier.size(23.dp),
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    (clip.viewCount ?: 0).toString(),
                    style = MaterialTheme.typography.labelSmall,
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

private fun clipPlaybackTime(milliseconds: Long): String {
    val seconds = (milliseconds / 1000).coerceAtLeast(0)
    return "%d:%02d".format(seconds / 60, seconds % 60)
}
