package com.lyo.app.ui.screens.community

import android.annotation.SuppressLint
import android.content.Intent
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
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
import androidx.compose.foundation.layout.wrapContentWidth
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Add
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.Map
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.ViewList
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.ChatBubbleOutline
import androidx.compose.material.icons.outlined.FavoriteBorder
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityCreatePostRequest
import com.lyo.app.data.api.CommunityPostDto
import com.lyo.app.data.api.CreateCommunityEventRequest
import com.lyo.app.data.api.CreateStudyGroupRequest
import com.lyo.app.data.api.EventDto
import com.lyo.app.data.api.GroupDto
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.launch

@Composable
fun CommunityScreen(nav: NavHostController) {
    var posts by remember { mutableStateOf<List<CommunityPostDto>>(emptyList()) }
    var groups by remember { mutableStateOf<List<GroupDto>>(emptyList()) }
    var events by remember { mutableStateOf<List<EventDto>>(emptyList()) }
    var likedPostIds by remember { mutableStateOf(setOf<String>()) }
    var bookmarkedPostIds by remember { mutableStateOf(setOf<String>()) }
    var joinedGroupIds by remember { mutableStateOf(setOf<String>()) }
    var attendingEventIds by remember { mutableStateOf(setOf<String>()) }
    var busyIds by remember { mutableStateOf(setOf<String>()) }
    var selectedTab by remember { mutableStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }
    var showCreateDialog by remember { mutableStateOf(false) }
    var showCreatePostDialog by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    suspend fun refreshFeed() {
        runCatching { ApiClient.api.communityPosts(1, 20) }.onSuccess { response ->
            posts = response.items.orEmpty()
            likedPostIds = posts.filter { it.hasLiked == true }.map { it.idStr }.toSet()
            bookmarkedPostIds = posts.filter { it.hasBookmarked == true }.map { it.idStr }.toSet()
        }.onFailure { errorMessage = it.localizedMessage ?: "Unable to load posts" }
    }

    suspend fun refreshExplore() {
        runCatching { ApiClient.api.groups() }.onSuccess { response ->
            groups = response
            joinedGroupIds = response.filter { it.isMember == true }.map { it.idStr }.toSet()
        }.onFailure { errorMessage = it.localizedMessage ?: "Unable to load groups" }
        runCatching { ApiClient.api.events() }.onSuccess { response ->
            events = response
            attendingEventIds = response.filter { it.isAttending }.map { it.idStr }.toSet()
        }.onFailure { errorMessage = it.localizedMessage ?: "Unable to load events" }
    }

    LaunchedEffect(Unit) {
        refreshFeed()
        refreshExplore()
        loading = false
    }

    Column(modifier = Modifier.fillMaxSize()) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                Text("Community", style = MaterialTheme.typography.headlineLarge, color = TextPrimary)
                Text("One shared community on every device", style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            }
            IconButton(onClick = { if (selectedTab == 0) showCreatePostDialog = true else showCreateDialog = true }) {
                Icon(
                    Icons.Filled.Add,
                    contentDescription = if (selectedTab == 0) "Create post" else "Create event or group",
                    tint = LyoPurple,
                )
            }
        }

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 4.dp),
        ) {
            listOf("Posts", "Events").forEachIndexed { index, label ->
                Text(
                    label,
                    style = MaterialTheme.typography.labelLarge,
                    color = if (selectedTab == index) TextPrimary else TextSecondary,
                    modifier = Modifier
                        .weight(1f)
                        .background(if (selectedTab == index) LyoPurple else Color.Transparent, RoundedCornerShape(10.dp))
                        .clickable { selectedTab = index }
                        .padding(vertical = 10.dp)
                        .wrapContentWidth(Alignment.CenterHorizontally),
                )
            }
        }

        if (loading) {
            LoadingBox()
        } else if (selectedTab == 0) {
            LazyColumn(
                contentPadding = PaddingValues(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.fillMaxSize(),
            ) {
                if (posts.isEmpty()) {
                    item { EmptyState("No posts yet", "Be the first to share something with the community") }
                } else {
                    items(posts, key = { it.idStr }) { post ->
                        val id = post.idStr
                        CommunityPostCard(
                            post = post,
                            liked = id in likedPostIds,
                            bookmarked = id in bookmarkedPostIds,
                            onLike = {
                                if (id !in busyIds) {
                                    val wasLiked = id in likedPostIds
                                    likedPostIds = if (wasLiked) likedPostIds - id else likedPostIds + id
                                    busyIds = busyIds + id
                                    scope.launch {
                                        runCatching { ApiClient.api.toggleCommunityPostLike(id) }
                                            .onFailure {
                                                likedPostIds = if (wasLiked) likedPostIds + id else likedPostIds - id
                                                errorMessage = it.localizedMessage ?: "Unable to update like"
                                            }
                                        busyIds = busyIds - id
                                    }
                                }
                            },
                            onBookmark = {
                                if (id !in busyIds) {
                                    val wasBookmarked = id in bookmarkedPostIds
                                    bookmarkedPostIds = if (wasBookmarked) bookmarkedPostIds - id else bookmarkedPostIds + id
                                    busyIds = busyIds + id
                                    scope.launch {
                                        runCatching { ApiClient.api.toggleCommunityPostBookmark(id) }
                                            .onFailure {
                                                bookmarkedPostIds = if (wasBookmarked) bookmarkedPostIds + id else bookmarkedPostIds - id
                                                errorMessage = it.localizedMessage ?: "Unable to update bookmark"
                                            }
                                        busyIds = busyIds - id
                                    }
                                }
                            },
                            onShare = {
                                val send = Intent(Intent.ACTION_SEND).apply {
                                    type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, "${post.authorName ?: "LYO Community"}: ${post.content.orEmpty()}\nhttps://lyoapp.com/community/$id")
                                }
                                context.startActivity(Intent.createChooser(send, "Share Community post"))
                            },
                            onClick = { nav.navigate(Routes.postDetail(id)) },
                        )
                    }
                }
            }
        } else {
            CommunityExplore(
                groups = groups,
                events = events,
                joinedGroupIds = joinedGroupIds,
                attendingEventIds = attendingEventIds,
                busyIds = busyIds,
                onJoinGroup = { group ->
                    val id = group.idStr
                    if (id !in busyIds) {
                        val wasJoined = id in joinedGroupIds
                        joinedGroupIds = if (wasJoined) joinedGroupIds - id else joinedGroupIds + id
                        busyIds = busyIds + id
                        scope.launch {
                            runCatching {
                                if (wasJoined) {
                                    val response = ApiClient.api.leaveGroup(id)
                                    require(response.isSuccessful) { "Unable to leave group (${response.code()})" }
                                } else ApiClient.api.joinGroup(id)
                            }
                                .onFailure {
                                    joinedGroupIds = if (wasJoined) joinedGroupIds + id else joinedGroupIds - id
                                    errorMessage = it.localizedMessage ?: "Unable to update group membership"
                                }
                            busyIds = busyIds - id
                        }
                    }
                },
                onRsvp = { event ->
                    val id = event.idStr
                    if (id !in busyIds) {
                        val wasAttending = id in attendingEventIds
                        attendingEventIds = if (wasAttending) attendingEventIds - id else attendingEventIds + id
                        busyIds = busyIds + id
                        scope.launch {
                            runCatching {
                                if (wasAttending) {
                                    val response = ApiClient.api.unattendEvent(id)
                                    require(response.isSuccessful) { "Unable to leave event (${response.code()})" }
                                } else ApiClient.api.attendEvent(id)
                            }
                                .onFailure {
                                    attendingEventIds = if (wasAttending) attendingEventIds + id else attendingEventIds - id
                                    errorMessage = it.localizedMessage ?: "Unable to update RSVP"
                                }
                            busyIds = busyIds - id
                        }
                    }
                },
            )
        }
    }

    if (showCreateDialog) {
        CreateCommunityItemDialog(
            onDismiss = { showCreateDialog = false },
            onCreated = {
                showCreateDialog = false
                scope.launch { refreshExplore() }
            },
        )
    }
    if (showCreatePostDialog) {
        CreateCommunityPostDialog(
            onDismiss = { showCreatePostDialog = false },
            onCreated = {
                showCreatePostDialog = false
                scope.launch { refreshFeed() }
            },
        )
    }
    errorMessage?.let { message ->
        AlertDialog(
            onDismissRequest = { errorMessage = null },
            title = { Text("Community error") },
            text = { Text(message) },
            confirmButton = { TextButton(onClick = { errorMessage = null }) { Text("OK") } },
        )
    }
}

@Composable
private fun CreateCommunityPostDialog(onDismiss: () -> Unit, onCreated: () -> Unit) {
    var postType by remember { mutableStateOf("text") }
    var content by remember { mutableStateOf("") }
    var tags by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun submit() {
        if (content.isBlank() || submitting) return
        submitting = true
        error = null
        scope.launch {
            runCatching {
                ApiClient.api.createCommunityPost(
                    CommunityCreatePostRequest(
                        content = content.trim(),
                        tags = tags.split(',').map { it.trim().removePrefix("#") }.filter { it.isNotEmpty() }.ifEmpty { null },
                        postType = postType,
                    ),
                )
            }.onSuccess { onCreated() }.onFailure { error = it.localizedMessage ?: "Unable to create post" }
            submitting = false
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create post") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    items(listOf("text" to "Post", "question_discussion" to "Question", "study_tip" to "Study tip")) { (value, label) ->
                        FilterChip(selected = postType == value, onClick = { postType = value }, label = { Text(label) })
                    }
                }
                OutlinedTextField(
                    value = content,
                    onValueChange = { content = it },
                    placeholder = { Text(if (postType == "question_discussion") "Ask the community…" else "Share something…", color = TextSecondary) },
                    minLines = 4,
                    colors = communityTextFieldColors(),
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = tags,
                    onValueChange = { tags = it },
                    label = { Text("Tags (comma separated)") },
                    colors = communityTextFieldColors(),
                    modifier = Modifier.fillMaxWidth(),
                )
                error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = { TextButton(onClick = ::submit, enabled = content.isNotBlank() && !submitting) { Text(if (submitting) "Posting…" else "Post") } },
        dismissButton = { TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancel") } },
    )
}

@Composable
private fun CommunityPostCard(
    post: CommunityPostDto,
    liked: Boolean,
    bookmarked: Boolean,
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
                    Text(authorName, style = MaterialTheme.typography.titleMedium)
                    Text(formatTimeAgo(post.createdAt), style = MaterialTheme.typography.labelMedium, color = TextSecondary)
                }
                if (post.postType != null && post.postType != "text") {
                    Text(
                        if (post.postType == "question_discussion") "Question" else "Study tip",
                        style = MaterialTheme.typography.labelSmall,
                        color = LyoPurple,
                        modifier = Modifier.background(LyoPurple.copy(alpha = 0.12f), RoundedCornerShape(50)).padding(horizontal = 8.dp, vertical = 4.dp),
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
                            modifier = Modifier.background(LyoPurple.copy(alpha = 0.12f), RoundedCornerShape(50)).padding(horizontal = 8.dp, vertical = 4.dp),
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
                            modifier = Modifier.fillParentMaxWidth().height(200.dp).clip(RoundedCornerShape(12.dp)).background(SurfaceElevated),
                        )
                    }
                }
            }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                IconButton(onClick = onLike) { Icon(if (liked) Icons.Filled.Favorite else Icons.Outlined.FavoriteBorder, "Like", tint = if (liked) LyoPink else TextSecondary) }
                Text((post.likeCount ?: 0).toString(), color = TextSecondary)
                IconButton(onClick = onClick) { Icon(Icons.Outlined.ChatBubbleOutline, "Comments", tint = TextSecondary) }
                Text((post.commentCount ?: 0).toString(), color = TextSecondary)
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onBookmark) { Icon(if (bookmarked) Icons.Filled.Bookmark else Icons.Outlined.BookmarkBorder, "Bookmark", tint = if (bookmarked) LyoPurple else TextSecondary) }
                IconButton(onClick = onShare) { Icon(Icons.Filled.Share, "Share", tint = TextSecondary) }
            }
        }
    }
}

@Composable
private fun CommunityExplore(
    groups: List<GroupDto>,
    events: List<EventDto>,
    joinedGroupIds: Set<String>,
    attendingEventIds: Set<String>,
    busyIds: Set<String>,
    onJoinGroup: (GroupDto) -> Unit,
    onRsvp: (EventDto) -> Unit,
) {
    var filter by remember { mutableStateOf("all") }
    var viewMode by remember { mutableStateOf("map") }
    var search by remember { mutableStateOf("") }
    val query = search.trim().lowercase()
    val visibleEvents = events.filter { query.isEmpty() || "${it.displayTitle} ${it.description.orEmpty()} ${it.location.orEmpty()}".lowercase().contains(query) }
    val visibleGroups = groups.filter { query.isEmpty() || "${it.name.orEmpty()} ${it.description.orEmpty()}".lowercase().contains(query) }

    Column(modifier = Modifier.fillMaxSize()) {
        OutlinedTextField(
            value = search,
            onValueChange = { search = it },
            placeholder = { Text("Search events and groups", color = TextSecondary) },
            singleLine = true,
            colors = communityTextFieldColors(),
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(horizontal = 16.dp)) {
            listOf("all" to "All", "event" to "Events", "group" to "Groups").forEach { (value, label) ->
                FilterChip(selected = filter == value, onClick = { filter = value; if (value == "group") viewMode = "list" }, label = { Text(label) })
            }
            Spacer(Modifier.weight(1f))
            IconButton(onClick = { viewMode = "list" }) { Icon(Icons.Filled.ViewList, "List", tint = if (viewMode == "list") LyoPurple else TextSecondary) }
            IconButton(onClick = { if (filter != "group") viewMode = "map" }, enabled = filter != "group") { Icon(Icons.Filled.Map, "Map", tint = if (viewMode == "map") LyoPurple else TextSecondary) }
        }

        if (viewMode == "map" && filter != "group") {
            CommunityEventMap(visibleEvents)
        } else {
            LazyColumn(contentPadding = PaddingValues(16.dp), verticalArrangement = Arrangement.spacedBy(12.dp), modifier = Modifier.fillMaxSize()) {
                if (filter != "group") items(visibleEvents, key = { "event-${it.idStr}" }) { event ->
                    CommunityEventCard(event, event.idStr in attendingEventIds, event.idStr in busyIds) { onRsvp(event) }
                }
                if (filter != "event") itemsIndexed(visibleGroups) { _, group ->
                    CommunityGroupCard(group, group.idStr in joinedGroupIds, group.idStr in busyIds) { onJoinGroup(group) }
                }
                if (
                    (filter == "event" && visibleEvents.isEmpty())
                    || (filter == "group" && visibleGroups.isEmpty())
                    || (filter == "all" && visibleEvents.isEmpty() && visibleGroups.isEmpty())
                ) {
                    item { EmptyState("No items found", "Try a different search or create a Community item") }
                }
            }
        }
    }
}

@Composable
private fun CommunityEventCard(event: EventDto, attending: Boolean, busy: Boolean, onRsvp: () -> Unit) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(event.displayTitle, style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            event.description?.takeIf { it.isNotBlank() }?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = TextSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis) }
            Spacer(Modifier.height(6.dp))
            Text(listOfNotNull(event.startTime?.let(::formatTimeAgo), event.location).joinToString(" • ").ifEmpty { "Details TBA" }, style = MaterialTheme.typography.bodySmall, color = TextSecondary)
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Text("${event.attendeeCount ?: 0} going", style = MaterialTheme.typography.labelMedium, color = TextSecondary, modifier = Modifier.weight(1f))
                Button(onClick = onRsvp, enabled = !busy, colors = ButtonDefaults.buttonColors(containerColor = if (attending) SurfaceElevated else LyoPurple)) { Text(if (attending) "Going ✓" else "RSVP") }
            }
        }
    }
}

@Composable
private fun CommunityGroupCard(group: GroupDto, joined: Boolean, busy: Boolean, onJoin: () -> Unit) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(group.name ?: "Study group", style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            group.description?.takeIf { it.isNotBlank() }?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = TextSecondary, maxLines = 2, overflow = TextOverflow.Ellipsis) }
            Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
                Text("${group.memberCount ?: 0} members", style = MaterialTheme.typography.labelMedium, color = TextSecondary, modifier = Modifier.weight(1f))
                if (joined) OutlinedButton(onClick = onJoin, enabled = !busy) { Text("Leave") }
                else Button(onClick = onJoin, enabled = !busy, colors = ButtonDefaults.buttonColors(containerColor = LyoPurple)) { Text("Join") }
            }
        }
    }
}

@SuppressLint("SetJavaScriptEnabled")
@Composable
private fun CommunityEventMap(events: List<EventDto>) {
    val mappable = events.filter { it.latitude != null && it.longitude != null }
    var selectedId by remember(mappable) { mutableStateOf(mappable.firstOrNull()?.idStr) }
    val selected = mappable.firstOrNull { it.idStr == selectedId } ?: mappable.firstOrNull()
    if (selected == null) {
        Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) { EmptyState("No mapped events yet", "Create an event with coordinates to add it to the map") }
        return
    }
    val lat = selected.latitude!!
    val lng = selected.longitude!!
    val delta = 0.035
    val url = "https://www.openstreetmap.org/export/embed.html?bbox=${lng - delta},${lat - delta},${lng + delta},${lat + delta}&layer=mapnik&marker=$lat,$lng"
    Column(modifier = Modifier.fillMaxSize().padding(16.dp)) {
        AndroidView(
            factory = { context -> WebView(context).apply { settings.javaScriptEnabled = true; settings.domStorageEnabled = true; webViewClient = WebViewClient() } },
            update = { webView -> if (webView.tag != selected.idStr) { webView.tag = selected.idStr; webView.loadUrl(url) } },
            modifier = Modifier.fillMaxWidth().weight(1f).background(SurfaceElevated, RoundedCornerShape(16.dp)),
        )
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) {
            mappable.take(4).forEach { event -> FilterChip(selected = event.idStr == selected.idStr, onClick = { selectedId = event.idStr }, label = { Text(event.displayTitle, maxLines = 1) }) }
        }
    }
}

@Composable
private fun CreateCommunityItemDialog(onDismiss: () -> Unit, onCreated: () -> Unit) {
    var type by remember { mutableStateOf("event") }
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    val formatter = remember { DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm") }
    var starts by remember { mutableStateOf(LocalDateTime.now().plusDays(1).withSecond(0).withNano(0).format(formatter)) }
    var ends by remember { mutableStateOf(LocalDateTime.now().plusDays(1).plusHours(1).withSecond(0).withNano(0).format(formatter)) }
    var latitude by remember { mutableStateOf("") }
    var longitude by remember { mutableStateOf("") }
    var maxPeople by remember { mutableStateOf("20") }
    var isPrivate by remember { mutableStateOf(false) }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun submit() {
        if (title.isBlank() || submitting) return
        submitting = true
        error = null
        scope.launch {
            runCatching {
                if (type == "group") {
                    ApiClient.api.createStudyGroup(
                        CreateStudyGroupRequest(
                            name = title.trim(),
                            description = description.trim().ifEmpty { null },
                            privacy = if (isPrivate) "private" else "public",
                            maxMembers = maxPeople.toIntOrNull()?.coerceIn(2, 1_000) ?: 20,
                            requiresApproval = isPrivate,
                        ),
                    )
                } else {
                    val zone = ZoneId.systemDefault()
                    val start = LocalDateTime.parse(starts, formatter).atZone(zone).toInstant().toString()
                    val end = LocalDateTime.parse(ends, formatter).atZone(zone).toInstant().toString()
                    require(java.time.Instant.parse(end).isAfter(java.time.Instant.parse(start))) { "The event must end after it starts" }
                    ApiClient.api.createCommunityEvent(
                        CreateCommunityEventRequest(
                            title = title.trim(), description = description.trim().ifEmpty { null },
                            location = location.trim().ifEmpty { "Online" }, startTime = start, endTime = end,
                            maxAttendees = maxPeople.toIntOrNull()?.coerceIn(1, 10_000) ?: 20,
                            timezone = zone.id, latitude = latitude.toDoubleOrNull(), longitude = longitude.toDoubleOrNull(),
                        ),
                    )
                }
            }.onSuccess { onCreated() }.onFailure { error = it.localizedMessage ?: "Unable to create item" }
            submitting = false
        }
    }

    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Create in Community") },
        text = {
            Column(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.verticalScroll(rememberScrollState()),
            ) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    FilterChip(selected = type == "event", onClick = { type = "event"; maxPeople = "20" }, label = { Text("Event") })
                    FilterChip(selected = type == "group", onClick = { type = "group"; maxPeople = "20" }, label = { Text("Study group") })
                }
                OutlinedTextField(title, { title = it }, label = { Text(if (type == "event") "Event title" else "Group name") }, singleLine = true)
                OutlinedTextField(description, { description = it }, label = { Text("Description") }, minLines = 2)
                if (type == "event") {
                    OutlinedTextField(starts, { starts = it }, label = { Text("Starts (yyyy-MM-dd HH:mm)") }, singleLine = true)
                    OutlinedTextField(ends, { ends = it }, label = { Text("Ends (yyyy-MM-dd HH:mm)") }, singleLine = true)
                    OutlinedTextField(location, { location = it }, label = { Text("Location or Online") }, singleLine = true)
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        OutlinedTextField(latitude, { latitude = it }, label = { Text("Latitude") }, modifier = Modifier.weight(1f), singleLine = true)
                        OutlinedTextField(longitude, { longitude = it }, label = { Text("Longitude") }, modifier = Modifier.weight(1f), singleLine = true)
                    }
                } else {
                    FilterChip(
                        selected = isPrivate,
                        onClick = { isPrivate = !isPrivate },
                        label = { Text(if (isPrivate) "Private — approval required" else "Public group") },
                    )
                }
                OutlinedTextField(
                    maxPeople,
                    { value -> maxPeople = value.filter { character -> character.isDigit() } },
                    label = { Text(if (type == "event") "Maximum attendees" else "Maximum members") },
                    singleLine = true,
                )
                error?.let { Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall) }
            }
        },
        confirmButton = { TextButton(onClick = ::submit, enabled = title.isNotBlank() && !submitting) { Text(if (submitting) "Creating…" else "Create") } },
        dismissButton = { TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancel") } },
    )
}

@Composable
private fun communityTextFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = LyoPurple,
    unfocusedBorderColor = BorderColor,
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
)
