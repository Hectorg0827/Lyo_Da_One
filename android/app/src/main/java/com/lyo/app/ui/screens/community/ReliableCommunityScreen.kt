package com.lyo.app.ui.screens.community

import android.annotation.SuppressLint
import android.content.Intent
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.MoreVert
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ViewList
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityPostDto
import com.lyo.app.data.api.EventDto
import com.lyo.app.data.api.GroupDto
import com.lyo.app.data.api.SearchUserDto
import com.lyo.app.data.sync.SyncClient
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.IOException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import retrofit2.HttpException

@Composable
fun ReliableCommunityScreen(nav: NavHostController) {
    var selectedTab by remember { mutableIntStateOf(0) }
    var createMenuExpanded by remember { mutableStateOf(false) }

    var posts by remember { mutableStateOf<List<CommunityPostDto>>(emptyList()) }
    var postsLoading by remember { mutableStateOf(true) }
    var postsLoaded by remember { mutableStateOf(false) }
    var postsError by remember { mutableStateOf<String?>(null) }
    var postsReload by remember { mutableIntStateOf(0) }

    var groups by remember { mutableStateOf<List<GroupDto>>(emptyList()) }
    var groupsLoading by remember { mutableStateOf(true) }
    var groupsLoaded by remember { mutableStateOf(false) }
    var groupsError by remember { mutableStateOf<String?>(null) }
    var groupsReload by remember { mutableIntStateOf(0) }

    var events by remember { mutableStateOf<List<EventDto>>(emptyList()) }
    var eventsLoading by remember { mutableStateOf(true) }
    var eventsLoaded by remember { mutableStateOf(false) }
    var eventsError by remember { mutableStateOf<String?>(null) }
    var eventsReload by remember { mutableIntStateOf(0) }

    var likedPostIds by remember { mutableStateOf(setOf<String>()) }
    var bookmarkedPostIds by remember { mutableStateOf(setOf<String>()) }
    var joinedGroupIds by remember { mutableStateOf(setOf<String>()) }
    var attendingEventIds by remember { mutableStateOf(setOf<String>()) }

    var pendingLikeIds by remember { mutableStateOf(setOf<String>()) }
    var pendingBookmarkIds by remember { mutableStateOf(setOf<String>()) }
    var pendingGroupIds by remember { mutableStateOf(setOf<String>()) }
    var pendingEventIds by remember { mutableStateOf(setOf<String>()) }
    var actionError by remember { mutableStateOf<String?>(null) }

    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    suspend fun loadPosts(preserveVisible: Boolean = true) {
        if (!preserveVisible || posts.isEmpty()) postsLoading = true
        postsError = null
        runCatching { ApiClient.api.communityPosts(1, 20).items.orEmpty() }
            .onSuccess { response ->
                posts = response
                likedPostIds = response.filter { it.hasLiked == true }.map { it.idStr }.toSet()
                bookmarkedPostIds = response.filter { it.hasBookmarked == true }.map { it.idStr }.toSet()
                postsLoaded = true
            }
            .onFailure { postsError = communityFailureMessage(it, "load Community posts") }
        postsLoading = false
    }

    suspend fun loadGroups(preserveVisible: Boolean = true) {
        if (!preserveVisible || groups.isEmpty()) groupsLoading = true
        groupsError = null
        runCatching { ApiClient.api.groups() }
            .onSuccess { response ->
                groups = response
                joinedGroupIds = response.filter { it.isMember == true }.map { it.idStr }.toSet()
                groupsLoaded = true
            }
            .onFailure { groupsError = communityFailureMessage(it, "load study groups") }
        groupsLoading = false
    }

    suspend fun loadEvents(preserveVisible: Boolean = true) {
        if (!preserveVisible || events.isEmpty()) eventsLoading = true
        eventsError = null
        runCatching { ApiClient.api.events() }
            .onSuccess { response ->
                events = response
                attendingEventIds = response.filter { it.isAttending }.map { it.idStr }.toSet()
                eventsLoaded = true
            }
            .onFailure { eventsError = communityFailureMessage(it, "load Community events") }
        eventsLoading = false
    }

    LaunchedEffect(postsReload) { loadPosts(preserveVisible = postsReload > 0) }
    LaunchedEffect(groupsReload) { loadGroups(preserveVisible = groupsReload > 0) }
    LaunchedEffect(eventsReload) { loadEvents(preserveVisible = eventsReload > 0) }

    LaunchedEffect(Unit) {
        SyncClient.events.collect { event ->
            if (event.eventType in setOf("context_updated", "community_updated")) {
                loadPosts()
                loadGroups()
                loadEvents()
            }
        }
    }

    fun togglePostLike(post: CommunityPostDto) {
        val id = post.idStr
        if (id.isBlank() || id in pendingLikeIds) return
        pendingLikeIds = pendingLikeIds + id
        actionError = null
        scope.launch {
            runCatching {
                val response = ApiClient.api.toggleCommunityPostLike(id)
                val confirmedLiked = response.liked
                    ?: throw IllegalStateException("The like response did not include its confirmed state")
                val confirmedCount = response.likeCount
                    ?: throw IllegalStateException("The like response did not include its confirmed count")
                confirmedLiked to confirmedCount
            }.onSuccess { (confirmedLiked, confirmedCount) ->
                likedPostIds = if (confirmedLiked) likedPostIds + id else likedPostIds - id
                posts = posts.map { item ->
                    if (item.idStr == id) {
                        item.copy(hasLiked = confirmedLiked, likeCount = confirmedCount)
                    } else {
                        item
                    }
                }
            }.onFailure { actionError = communityFailureMessage(it, "update this post like") }
            pendingLikeIds = pendingLikeIds - id
        }
    }

    fun togglePostBookmark(post: CommunityPostDto) {
        val id = post.idStr
        if (id.isBlank() || id in pendingBookmarkIds) return
        pendingBookmarkIds = pendingBookmarkIds + id
        actionError = null
        scope.launch {
            runCatching {
                ApiClient.api.toggleCommunityPostBookmark(id)
                    .get("bookmarked")
                    ?.asBoolean
                    ?: throw IllegalStateException("The bookmark response did not include its confirmed state")
            }.onSuccess { confirmedBookmarked ->
                bookmarkedPostIds = if (confirmedBookmarked) {
                    bookmarkedPostIds + id
                } else {
                    bookmarkedPostIds - id
                }
                posts = posts.map { item ->
                    if (item.idStr == id) item.copy(hasBookmarked = confirmedBookmarked) else item
                }
            }.onFailure { actionError = communityFailureMessage(it, "update this bookmark") }
            pendingBookmarkIds = pendingBookmarkIds - id
        }
    }

    fun toggleGroupMembership(group: GroupDto) {
        val id = group.idStr
        if (id.isBlank() || id in pendingGroupIds) return
        val currentlyJoined = id in joinedGroupIds
        pendingGroupIds = pendingGroupIds + id
        actionError = null
        scope.launch {
            runCatching {
                if (currentlyJoined) {
                    val response = ApiClient.api.leaveGroup(id)
                    check(response.isSuccessful) { "The group leave request was not accepted" }
                    false
                } else {
                    ApiClient.api.joinGroup(id)
                    true
                }
            }.onSuccess { confirmedJoined ->
                joinedGroupIds = if (confirmedJoined) joinedGroupIds + id else joinedGroupIds - id
                groups = groups.map { item ->
                    if (item.idStr == id) {
                        val delta = if (confirmedJoined) 1 else -1
                        item.copy(
                            isMember = confirmedJoined,
                            memberCount = ((item.memberCount ?: 0) + delta).coerceAtLeast(0),
                        )
                    } else {
                        item
                    }
                }
            }.onFailure { actionError = communityFailureMessage(it, "update this group membership") }
            pendingGroupIds = pendingGroupIds - id
        }
    }

    fun toggleEventAttendance(event: EventDto) {
        val id = event.idStr
        if (id.isBlank() || id in pendingEventIds) return
        val currentlyAttending = id in attendingEventIds
        pendingEventIds = pendingEventIds + id
        actionError = null
        scope.launch {
            runCatching {
                if (currentlyAttending) {
                    val response = ApiClient.api.unattendEvent(id)
                    check(response.isSuccessful) { "The event leave request was not accepted" }
                    false
                } else {
                    ApiClient.api.attendEvent(id)
                    true
                }
            }.onSuccess { confirmedAttending ->
                attendingEventIds = if (confirmedAttending) {
                    attendingEventIds + id
                } else {
                    attendingEventIds - id
                }
                events = events.map { item ->
                    if (item.idStr == id) {
                        val delta = if (confirmedAttending) 1 else -1
                        item.copy(
                            userAttendanceStatus = if (confirmedAttending) "attending" else null,
                            attendeeCount = ((item.attendeeCount ?: 0) + delta).coerceAtLeast(0),
                        )
                    } else {
                        item
                    }
                }
            }.onFailure { actionError = communityFailureMessage(it, "update this event RSVP") }
            pendingEventIds = pendingEventIds - id
        }
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Community", style = MaterialTheme.typography.headlineLarge, color = TextPrimary)
                Text(
                    "One shared community on every device",
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                )
            }
            Box {
                IconButton(onClick = { createMenuExpanded = true }) {
                    Icon(Icons.Filled.Add, contentDescription = "Create Community item", tint = LyoPurple)
                }
                DropdownMenu(
                    expanded = createMenuExpanded,
                    onDismissRequest = { createMenuExpanded = false },
                ) {
                    DropdownMenuItem(
                        text = { Text("New post") },
                        onClick = {
                            createMenuExpanded = false
                            nav.navigate(Routes.CREATE_POST)
                        },
                    )
                    DropdownMenuItem(
                        text = { Text("New study group") },
                        onClick = {
                            createMenuExpanded = false
                            nav.navigate(Routes.CREATE_GROUP)
                        },
                    )
                    DropdownMenuItem(
                        text = { Text("New event") },
                        onClick = {
                            createMenuExpanded = false
                            nav.navigate(Routes.CREATE_EVENT)
                        },
                    )
                }
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 4.dp),
        ) {
            listOf("Posts", "Explore").forEachIndexed { index, label ->
                Text(
                    label,
                    style = MaterialTheme.typography.labelLarge,
                    color = if (selectedTab == index) Color.White else TextSecondary,
                    textAlign = TextAlign.Center,
                    modifier = Modifier
                        .weight(1f)
                        .background(
                            if (selectedTab == index) LyoPurple else Color.Transparent,
                            RoundedCornerShape(10.dp),
                        )
                        .clickable { selectedTab = index }
                        .padding(vertical = 10.dp),
                )
            }
        }

        actionError?.let { message ->
            InlineCommunityError(
                message = message,
                onDismiss = { actionError = null },
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
            )
        }

        if (selectedTab == 0) {
            ReliablePostsTab(
                posts = posts,
                loading = postsLoading,
                loaded = postsLoaded,
                error = postsError,
                likedPostIds = likedPostIds,
                bookmarkedPostIds = bookmarkedPostIds,
                pendingLikeIds = pendingLikeIds,
                pendingBookmarkIds = pendingBookmarkIds,
                onRetry = { postsReload++ },
                onLike = ::togglePostLike,
                onBookmark = ::togglePostBookmark,
                onOpenPost = { nav.navigate(Routes.postDetail(it)) },
                onShare = { post ->
                    val id = post.idStr
                    val send = Intent(Intent.ACTION_SEND).apply {
                        type = "text/plain"
                        putExtra(
                            Intent.EXTRA_TEXT,
                            "${post.authorName ?: "LYO Community"}: ${post.content.orEmpty()}\nhttps://lyoai.app/community/$id",
                        )
                    }
                    context.startActivity(Intent.createChooser(send, "Share Community post"))
                },
            )
        } else {
            ReliableExploreTab(
                groups = groups,
                events = events,
                groupsLoading = groupsLoading,
                groupsLoaded = groupsLoaded,
                groupsError = groupsError,
                eventsLoading = eventsLoading,
                eventsLoaded = eventsLoaded,
                eventsError = eventsError,
                joinedGroupIds = joinedGroupIds,
                attendingEventIds = attendingEventIds,
                pendingGroupIds = pendingGroupIds,
                pendingEventIds = pendingEventIds,
                onRetryGroups = { groupsReload++ },
                onRetryEvents = { eventsReload++ },
                onToggleGroup = ::toggleGroupMembership,
                onToggleEvent = ::toggleEventAttendance,
                onOpenProfile = { nav.navigate(Routes.userProfile(it)) },
            )
        }
    }
}

@Composable
private fun ReliablePostsTab(
    posts: List<CommunityPostDto>,
    loading: Boolean,
    loaded: Boolean,
    error: String?,
    likedPostIds: Set<String>,
    bookmarkedPostIds: Set<String>,
    pendingLikeIds: Set<String>,
    pendingBookmarkIds: Set<String>,
    onRetry: () -> Unit,
    onLike: (CommunityPostDto) -> Unit,
    onBookmark: (CommunityPostDto) -> Unit,
    onOpenPost: (String) -> Unit,
    onShare: (CommunityPostDto) -> Unit,
) {
    when {
        loading && posts.isEmpty() -> LoadingBox()
        error != null && posts.isEmpty() && !loaded -> CommunitySourceError(
            title = "Posts could not be loaded",
            message = error,
            onRetry = onRetry,
        )
        loaded && posts.isEmpty() -> EmptyState(
            title = "No posts yet",
            subtitle = "Be the first to share something with the community",
        )
        else -> LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            error?.let { message ->
                item {
                    InlineCommunityError(message = message, onDismiss = onRetry)
                }
            }
            items(posts, key = { it.idStr }) { post ->
                val id = post.idStr
                ReliableCommunityPostCard(
                    post = post,
                    liked = id in likedPostIds,
                    bookmarked = id in bookmarkedPostIds,
                    likePending = id in pendingLikeIds,
                    bookmarkPending = id in pendingBookmarkIds,
                    onLike = { onLike(post) },
                    onBookmark = { onBookmark(post) },
                    onShare = { onShare(post) },
                    onClick = { onOpenPost(id) },
                )
            }
        }
    }
}

@Composable
private fun ReliableCommunityPostCard(
    post: CommunityPostDto,
    liked: Boolean,
    bookmarked: Boolean,
    likePending: Boolean,
    bookmarkPending: Boolean,
    onLike: () -> Unit,
    onBookmark: () -> Unit,
    onShare: () -> Unit,
    onClick: () -> Unit,
) {
    val authorName = post.authorName ?: "Member"
    GlassCard(modifier = Modifier.fillMaxWidth().clickable(onClick = onClick)) {
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
                Spacer(Modifier.height(10.dp))
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
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
                IconButton(onClick = onClick) {
                    Icon(Icons.Outlined.ChatBubbleOutline, "Comments", tint = TextSecondary)
                }
                Text((post.commentCount ?: 0).toString(), color = TextSecondary)
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
                    Icon(Icons.Filled.Share, "Share", tint = TextSecondary)
                }
            }
        }
    }
}

@Composable
private fun ReliableExploreTab(
    groups: List<GroupDto>,
    events: List<EventDto>,
    groupsLoading: Boolean,
    groupsLoaded: Boolean,
    groupsError: String?,
    eventsLoading: Boolean,
    eventsLoaded: Boolean,
    eventsError: String?,
    joinedGroupIds: Set<String>,
    attendingEventIds: Set<String>,
    pendingGroupIds: Set<String>,
    pendingEventIds: Set<String>,
    onRetryGroups: () -> Unit,
    onRetryEvents: () -> Unit,
    onToggleGroup: (GroupDto) -> Unit,
    onToggleEvent: (EventDto) -> Unit,
    onOpenProfile: (String) -> Unit,
) {
    var filter by remember { mutableStateOf("all") }
    var viewMode by remember { mutableStateOf("list") }
    var search by remember { mutableStateOf("") }
    var people by remember { mutableStateOf<List<SearchUserDto>>(emptyList()) }
    var peopleLoading by remember { mutableStateOf(false) }
    var peopleError by remember { mutableStateOf<String?>(null) }

    val query = search.trim().lowercase()
    val visibleEvents = events.filter {
        query.isEmpty() || "${it.displayTitle} ${it.description.orEmpty()} ${it.location.orEmpty()}"
            .lowercase()
            .contains(query)
    }
    val visibleGroups = groups.filter {
        query.isEmpty() || "${it.name.orEmpty()} ${it.description.orEmpty()}"
            .lowercase()
            .contains(query)
    }

    LaunchedEffect(search) {
        val normalized = search.trim()
        if (normalized.length < 2) {
            people = emptyList()
            peopleError = null
            peopleLoading = false
            return@LaunchedEffect
        }
        delay(250)
        peopleLoading = true
        peopleError = null
        runCatching { ApiClient.api.search(normalized, type = "users", limit = 6).users.orEmpty() }
            .onSuccess { people = it }
            .onFailure { peopleError = communityFailureMessage(it, "search for people") }
        peopleLoading = false
    }

    Column(modifier = Modifier.fillMaxSize()) {
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            placeholder = { Text("Search people, events, and groups", color = TextSecondary) },
            singleLine = true,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        )

        when {
            peopleLoading -> LinearCommunityLoading("Searching people…")
            peopleError != null -> InlineCommunityError(
                message = peopleError.orEmpty(),
                onDismiss = { peopleError = null },
                modifier = Modifier.padding(horizontal = 16.dp),
            )
            people.isNotEmpty() -> {
                Text(
                    "People",
                    style = MaterialTheme.typography.titleSmall,
                    color = TextPrimary,
                    modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                )
                LazyRow(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    contentPadding = PaddingValues(horizontal = 16.dp),
                ) {
                    items(people, key = { it.idStr }) { person ->
                        GlassCard(modifier = Modifier.clickable { onOpenProfile(person.idStr) }) {
                            Row(
                                verticalAlignment = Alignment.CenterVertically,
                                modifier = Modifier.padding(horizontal = 10.dp, vertical = 8.dp),
                            ) {
                                LyoAvatar(
                                    name = person.name ?: "M",
                                    avatarUrl = person.avatarUrl,
                                    size = 30,
                                )
                                Spacer(Modifier.width(8.dp))
                                Column {
                                    Text(
                                        person.name ?: "Member",
                                        style = MaterialTheme.typography.labelLarge,
                                        color = TextPrimary,
                                    )
                                    person.username?.takeIf { it.isNotBlank() }?.let {
                                        Text(
                                            "@$it",
                                            style = MaterialTheme.typography.labelSmall,
                                            color = TextSecondary,
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
        ) {
            listOf("all" to "All", "event" to "Events", "group" to "Groups").forEach { (value, label) ->
                FilterChip(
                    selected = filter == value,
                    onClick = {
                        filter = value
                        if (value == "group") viewMode = "list"
                    },
                    label = { Text(label) },
                )
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = { viewMode = "list" }) {
                Icon(
                    Icons.Filled.ViewList,
                    contentDescription = "List",
                    tint = if (viewMode == "list") LyoPurple else TextSecondary,
                )
            }
            IconButton(
                onClick = { viewMode = "map" },
                enabled = filter != "group",
            ) {
                Icon(
                    Icons.Filled.Map,
                    contentDescription = "Map",
                    tint = if (viewMode == "map") LyoPurple else TextSecondary,
                )
            }
        }

        if (viewMode == "map" && filter != "group") {
            when {
                eventsLoading && events.isEmpty() -> LoadingBox()
                eventsError != null && events.isEmpty() && !eventsLoaded -> CommunitySourceError(
                    title = "Events could not be loaded",
                    message = eventsError,
                    onRetry = onRetryEvents,
                )
                else -> ReliableCommunityEventMap(visibleEvents)
            }
            return
        }

        LazyColumn(
            contentPadding = PaddingValues(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
            modifier = Modifier.fillMaxSize(),
        ) {
            if (filter != "group") {
                when {
                    eventsLoading && events.isEmpty() -> item { LinearCommunityLoading("Loading events…") }
                    eventsError != null && events.isEmpty() && !eventsLoaded -> item {
                        InlineSourceError("Events could not be loaded", eventsError, onRetryEvents)
                    }
                    else -> {
                        eventsError?.let { item { InlineSourceError("Events may be out of date", it, onRetryEvents) } }
                        items(visibleEvents, key = { "event-${it.idStr}" }) { event ->
                            ReliableCommunityEventCard(
                                event = event,
                                attending = event.idStr in attendingEventIds,
                                busy = event.idStr in pendingEventIds,
                                onRsvp = { onToggleEvent(event) },
                            )
                        }
                    }
                }
            }

            if (filter != "event") {
                when {
                    groupsLoading && groups.isEmpty() -> item { LinearCommunityLoading("Loading groups…") }
                    groupsError != null && groups.isEmpty() && !groupsLoaded -> item {
                        InlineSourceError("Groups could not be loaded", groupsError, onRetryGroups)
                    }
                    else -> {
                        groupsError?.let { item { InlineSourceError("Groups may be out of date", it, onRetryGroups) } }
                        items(visibleGroups, key = { "group-${it.idStr}" }) { group ->
                            ReliableCommunityGroupCard(
                                group = group,
                                joined = group.idStr in joinedGroupIds,
                                busy = group.idStr in pendingGroupIds,
                                onJoin = { onToggleGroup(group) },
                            )
                        }
                    }
                }
            }

            val eventsConfirmedEmpty = filter == "group" || (eventsLoaded && visibleEvents.isEmpty())
            val groupsConfirmedEmpty = filter == "event" || (groupsLoaded && visibleGroups.isEmpty())
            if (eventsConfirmedEmpty && groupsConfirmedEmpty) {
                item {
                    EmptyState(
                        title = "No items found",
                        subtitle = "Try a different search or create a Community item",
                    )
                }
            }
        }
    }
}

@Composable
private fun ReliableCommunityEventCard(
    event: EventDto,
    attending: Boolean,
    busy: Boolean,
    onRsvp: () -> Unit,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(event.displayTitle, style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            event.description?.takeIf { it.isNotBlank() }?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            val detail = listOfNotNull(event.startTime?.let(::formatTimeAgo), event.location)
                .joinToString(" • ")
            if (detail.isNotBlank()) {
                Text(
                    detail,
                    style = MaterialTheme.typography.bodySmall,
                    color = TextSecondary,
                    modifier = Modifier.padding(top = 6.dp),
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Text(
                    "${event.attendeeCount ?: 0} going",
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                    modifier = Modifier.weight(1f),
                )
                Button(
                    onClick = onRsvp,
                    enabled = !busy,
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (attending) SurfaceElevated else LyoPurple,
                    ),
                ) {
                    if (busy) {
                        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                    } else {
                        Text(if (attending) "Leave" else "RSVP")
                    }
                }
            }
        }
    }
}

@Composable
private fun ReliableCommunityGroupCard(
    group: GroupDto,
    joined: Boolean,
    busy: Boolean,
    onJoin: () -> Unit,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(group.name ?: "Study group", style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            group.description?.takeIf { it.isNotBlank() }?.let {
                Text(
                    it,
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Text(
                    "${group.memberCount ?: 0} members",
                    style = MaterialTheme.typography.labelMedium,
                    color = TextSecondary,
                    modifier = Modifier.weight(1f),
                )
                if (joined) {
                    OutlinedButton(onClick = onJoin, enabled = !busy) {
                        if (busy) CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        else Text("Leave")
                    }
                } else {
                    Button(
                        onClick = onJoin,
                        enabled = !busy,
                        colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                    ) {
                        if (busy) CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
                        else Text("Join")
                    }
                }
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun ReliableCommunityEventMap(events: List<EventDto>) {
    val mappable = events.filter { it.latitude != null && it.longitude != null }
    var selectedId by remember(mappable) { mutableStateOf(mappable.firstOrNull()?.idStr) }
    val selected = mappable.firstOrNull { it.idStr == selectedId } ?: mappable.firstOrNull()

    if (selected == null) {
        EmptyState(
            title = "No mapped events yet",
            subtitle = "Events with coordinates will appear on the map",
        )
        return
    }

    val latitude = selected.latitude ?: return
    val longitude = selected.longitude ?: return
    val delta = 0.035
    val url = "https://www.openstreetmap.org/export/embed.html?bbox=${longitude - delta},${latitude - delta},${longitude + delta},${latitude + delta}&layer=mapnik&marker=$latitude,$longitude"

    Column(modifier = Modifier.fillMaxSize()) {
        AndroidView(
            factory = { context ->
                WebView(context).apply {
                    settings.javaScriptEnabled = true
                    webViewClient = WebViewClient()
                }
            },
            update = { webView ->
                if (webView.url != url) webView.loadUrl(url)
            },
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
        )
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(12.dp),
        ) {
            items(mappable, key = { it.idStr }) { event ->
                FilterChip(
                    selected = event.idStr == selected.idStr,
                    onClick = { selectedId = event.idStr },
                    label = { Text(event.displayTitle, maxLines = 1) },
                )
            }
        }
    }
}

@Composable
private fun CommunitySourceError(title: String, message: String, onRetry: () -> Unit) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
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
private fun InlineSourceError(title: String, message: String, onRetry: () -> Unit) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(title, style = MaterialTheme.typography.titleSmall, color = TextPrimary)
            Text(message, style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            TextButton(onClick = onRetry) { Text("Retry") }
        }
    }
}

@Composable
private fun InlineCommunityError(
    message: String,
    onDismiss: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .background(MaterialTheme.colorScheme.errorContainer, RoundedCornerShape(12.dp))
            .padding(start = 12.dp, end = 4.dp, top = 6.dp, bottom = 6.dp),
    ) {
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = MaterialTheme.colorScheme.onErrorContainer,
            modifier = Modifier.weight(1f),
        )
        TextButton(onClick = onDismiss) { Text("Dismiss") }
    }
}

@Composable
private fun LinearCommunityLoading(message: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp),
    ) {
        CircularProgressIndicator(modifier = Modifier.size(16.dp), strokeWidth = 2.dp)
        Text(message, style = MaterialTheme.typography.bodySmall, color = TextSecondary, modifier = Modifier.padding(start = 8.dp))
    }
}

private fun communityFailureMessage(error: Throwable, action: String): String = when (error) {
    is HttpException -> when (error.code()) {
        400, 422 -> "LYO could not $action because the request was invalid."
        401, 403 -> "Sign in again to $action."
        404 -> "The requested Community item is no longer available."
        409 -> "This Community state changed elsewhere. Refresh and try again."
        429 -> "Too many Community requests. Wait a moment and try again."
        in 500..599 -> "LYO could not $action because the Community service is unavailable."
        else -> "LYO could not $action (${error.code()})."
    }
    is IOException -> "Check your connection and try to $action again."
    else -> error.localizedMessage ?: "LYO could not $action."
}
