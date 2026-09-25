package com.lyo.app.ui.screens.community

import android.content.Intent
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ContentCopy
import androidx.compose.material.icons.filled.Link
import androidx.compose.material.icons.filled.LinkOff
import androidx.compose.material.icons.filled.MailOutline
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.PersonRemove
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Surface
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.EventGuestDto
import com.lyo.app.data.api.EventInviteDto
import com.lyo.app.data.api.EventInvitesResponseDto
import com.lyo.app.data.api.InvitePreviewDto
import com.lyo.app.data.api.SearchUserDto
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

/**
 * An invite link the app was opened with (lyoapp://community/invite/<code>).
 * It waits here until the learner is signed in, then opens the invitation.
 */
object PendingCommunityInvite {
    var token by mutableStateOf<String?>(null)

    /** Keeps the invite code from a link; anything else is ignored. */
    fun capture(data: String?) {
        CommunityDiscovery.inviteTokenFromAppLink(data)?.let { token = it }
    }
}

/** The Community screen's state when it is on the back stack, else a fresh copy. */
@Composable
internal fun rememberCommunityViewModel(nav: NavHostController): CommunityMapViewModel {
    val communityEntry = remember(nav) { runCatching { nav.getBackStackEntry(Routes.COMMUNITY) }.getOrNull() }
    return if (communityEntry != null) viewModel(viewModelStoreOwner = communityEntry) else viewModel()
}

private val useOptions = listOf(0 to "Anyone", 1 to "1 person", 5 to "Up to 5", 25 to "Up to 25")
private val expiryOptions = listOf(7 to "7 days", 30 to "30 days", 90 to "90 days")

// ── Host: invite people ──────────────────────────────────────────────────────

/**
 * Host-only: who can get into a private or unlisted event. Invite links can
 * be limited and turned off; Lyo members can be invited by name (the backend
 * notifies them on every device); anyone on the guest list can be removed.
 * Links and guests live on the backend, never only on this phone.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun EventInvitesScreen(nav: NavHostController, eventId: String) {
    val vm = rememberCommunityViewModel(nav)
    val context = LocalContext.current
    val clipboard = LocalClipboardManager.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    val node = vm.detail("event", eventId)?.node
    var invitations by remember { mutableStateOf<EventInvitesResponseDto?>(null) }
    var loadError by remember { mutableStateOf<CommunityDiscovery.FriendlyError?>(null) }
    var attempt by remember { mutableIntStateOf(0) }
    var maxUses by rememberSaveable { mutableIntStateOf(0) }
    var expiresInDays by rememberSaveable { mutableIntStateOf(30) }
    var creating by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf<String?>(null) }
    var copiedId by remember { mutableStateOf<Long?>(null) }
    var query by rememberSaveable { mutableStateOf("") }
    var results by remember { mutableStateOf<List<SearchUserDto>>(emptyList()) }
    var searching by remember { mutableStateOf(false) }
    val trimmedQuery = query.trim()
    val guests = invitations?.guests.orEmpty()
    val links = invitations?.links.orEmpty()

    suspend fun reload() {
        try {
            invitations = vm.loadInvitations(eventId)
            loadError = null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            loadError = CommunityDiscovery.friendlyError(e, "load your guest list")
        }
    }

    LaunchedEffect(eventId, attempt) {
        if (vm.detail("event", eventId) == null) {
            // Opened without the event page first: read its title and host.
            try {
                vm.loadDetail("event", eventId)
            } catch (e: CancellationException) {
                throw e
            } catch (_: Exception) {
                // The guest list below says what went wrong.
            }
        }
        reload()
    }

    LaunchedEffect(trimmedQuery) {
        if (trimmedQuery.length < 2) {
            results = emptyList()
            searching = false
            return@LaunchedEffect
        }
        // Wait for a pause in typing; a new keystroke restarts this effect.
        delay(300)
        searching = true
        try {
            results = vm.searchMembers(trimmedQuery, node?.host?.id)
        } catch (e: CancellationException) {
            throw e
        } catch (_: Exception) {
            results = emptyList()
        } finally {
            searching = false
        }
    }

    fun linkUrl(link: EventInviteDto): String =
        CommunityDiscovery.safeWebUrl(link.url) ?: CommunityDiscovery.inviteUrl(link.token)

    fun say(message: String) {
        scope.launch { snackbar.showSnackbar(message) }
    }

    fun copy(link: EventInviteDto) {
        clipboard.setText(AnnotatedString(linkUrl(link)))
        copiedId = link.id
        say("Invite link copied")
        scope.launch {
            delay(2_000)
            if (copiedId == link.id) copiedId = null
        }
    }

    fun share(link: EventInviteDto) {
        val title = node?.title ?: "a Lyo event"
        val send = Intent(Intent.ACTION_SEND).setType("text/plain")
            .putExtra(Intent.EXTRA_SUBJECT, title)
            .putExtra(Intent.EXTRA_TEXT, "You're invited to $title on Lyo\n${linkUrl(link)}")
        runCatching { context.startActivity(Intent.createChooser(send, "Share invite link")) }
            .onFailure { copy(link) }
    }

    fun createLink() {
        creating = true
        scope.launch {
            try {
                val link = vm.createInvite(eventId, maxUses.takeIf { it > 0 }, expiresInDays)
                copy(link)
                reload()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                say(CommunityDiscovery.friendlyError(e, "create an invite link").message)
            } finally {
                creating = false
            }
        }
    }

    fun turnOff(link: EventInviteDto) {
        busy = "link:${link.id}"
        scope.launch {
            try {
                vm.revokeInvite(eventId, link.id)
                say("Link turned off. People who already joined keep their spot.")
                reload()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                say(CommunityDiscovery.friendlyError(e, "turn off this link").message)
            } finally {
                busy = null
            }
        }
    }

    fun invite(member: SearchUserDto, name: String) {
        val userId = member.idStr.toLongOrNull() ?: return
        busy = "user:$userId"
        scope.launch {
            try {
                vm.inviteMember(eventId, userId)
                say("Invited $name")
                query = ""
                results = emptyList()
                reload()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                say(CommunityDiscovery.friendlyError(e, "send this invitation").message)
            } finally {
                busy = null
            }
        }
    }

    fun remove(guest: EventGuestDto) {
        busy = "guest:${guest.user.id}"
        scope.launch {
            try {
                vm.removeGuest(eventId, guest.user.id)
                say("${guest.user.name} was removed from the guest list")
                reload()
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                say(CommunityDiscovery.friendlyError(e, "remove this guest").message)
            } finally {
                busy = null
            }
        }
    }

    Scaffold(
        containerColor = Background,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text("Invite people") },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = TextPrimary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Background, titleContentColor = TextPrimary),
            )
        },
    ) { padding ->
        LazyColumn(
            verticalArrangement = Arrangement.spacedBy(12.dp),
            contentPadding = PaddingValues(16.dp),
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            item {
                Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                    node?.title?.let {
                        Text(it, color = TextPrimary, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
                    }
                    Text(
                        if (node?.visibility == "unlisted") {
                            "This event is unlisted: it isn't on the map, so share an invite with the people you want."
                        } else {
                            "This event is private: only you and the people you invite can see it."
                        },
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            }

            item { InviteSectionTitle("New invite link") }
            item {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Text("Who can use it", color = TextSecondary, style = MaterialTheme.typography.labelMedium)
                    OptionChips(useOptions, maxUses) { maxUses = it }
                    Text("Link works for", color = TextSecondary, style = MaterialTheme.typography.labelMedium)
                    OptionChips(expiryOptions, expiresInDays) { expiresInDays = it }
                    Button(
                        onClick = { createLink() },
                        enabled = !creating,
                        colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                        modifier = Modifier
                            .fillMaxWidth()
                            .heightIn(min = 48.dp),
                    ) {
                        if (creating) {
                            CircularProgressIndicator(color = TextPrimary, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                        } else {
                            Icon(Icons.Default.Link, contentDescription = null, modifier = Modifier.size(18.dp))
                        }
                        Spacer(Modifier.width(8.dp))
                        Text("Create and copy invite link", fontWeight = FontWeight.SemiBold)
                    }
                }
            }

            if (links.isNotEmpty()) {
                item { InviteSectionTitle("Invite links") }
                items(links, key = { "link:${it.id}" }) { link ->
                    InviteLinkRow(
                        link = link,
                        copied = copiedId == link.id,
                        busy = busy == "link:${link.id}",
                        onCopy = { copy(link) },
                        onShare = { share(link) },
                        onTurnOff = { turnOff(link) },
                    )
                }
            }

            item { InviteSectionTitle("Invite a Lyo member by name") }
            item {
                OutlinedTextField(
                    value = query,
                    onValueChange = { query = it },
                    singleLine = true,
                    label = { Text("Name or username") },
                    leadingIcon = { Icon(Icons.Default.Search, contentDescription = null) },
                    trailingIcon = {
                        if (searching) CircularProgressIndicator(color = LyoPurple, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                    },
                    keyboardOptions = KeyboardOptions(imeAction = ImeAction.Search),
                    supportingText = { Text("They get a notification and find the event in My Community on every device.") },
                    modifier = Modifier.fillMaxWidth(),
                )
            }
            if (trimmedQuery.length >= 2 && !searching && results.isEmpty()) {
                item { EmptyCommunityText("No Lyo members match “$trimmedQuery”.") }
            }
            items(results, key = { "member:${it.idStr}" }) { member ->
                val name = member.name ?: member.username ?: "Lyo member"
                val already = guests.any { it.user.id.toString() == member.idStr }
                MemberRow(
                    name = name,
                    username = member.username,
                    already = already,
                    busy = busy == "user:${member.idStr}",
                    onInvite = { invite(member, name) },
                )
            }

            item { InviteSectionTitle(if (guests.isEmpty()) "Guest list" else "Guest list · ${guests.size}") }
            val error = loadError
            when {
                invitations == null && error == null -> item {
                    Box(modifier = Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
                        CircularProgressIndicator(color = LyoPurple)
                    }
                }
                invitations == null && error != null -> item {
                    CommunityStateMessage(
                        title = error.title,
                        body = error.body,
                        actions = listOf("Try again" to { attempt += 1 }),
                        icon = if (error == CommunityDiscovery.offlineError) Icons.Default.WifiOff else Icons.Default.Person,
                    )
                }
                guests.isEmpty() -> item { EmptyCommunityText("No guests yet. Invite someone by link or by name.") }
                else -> items(guests, key = { "guest:${it.user.id}" }) { guest ->
                    GuestRow(guest = guest, busy = busy == "guest:${guest.user.id}", onRemove = { remove(guest) })
                }
            }
            item { Spacer(Modifier.height(24.dp)) }
        }
    }
}

@Composable
private fun InviteSectionTitle(title: String) {
    Text(
        title,
        color = TextPrimary,
        style = MaterialTheme.typography.titleSmall,
        fontWeight = FontWeight.SemiBold,
        modifier = Modifier
            .padding(top = 6.dp)
            .semantics { heading() },
    )
}

@Composable
private fun OptionChips(options: List<Pair<Int, String>>, selected: Int, onSelect: (Int) -> Unit) {
    Row(
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier.horizontalScroll(rememberScrollState()),
    ) {
        options.forEach { (value, label) ->
            FilterChip(selected = selected == value, onClick = { onSelect(value) }, label = { Text(label) })
        }
    }
}

@Composable
private fun InviteLinkRow(
    link: EventInviteDto,
    copied: Boolean,
    busy: Boolean,
    onCopy: () -> Unit,
    onShare: () -> Unit,
    onTurnOff: () -> Unit,
) {
    Surface(color = SurfaceElevated, shape = RoundedCornerShape(14.dp), modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(6.dp), modifier = Modifier.padding(12.dp)) {
            Text(
                CommunityDiscovery.describeInviteLink(link),
                color = if (link.active) TextPrimary else TextSecondary,
                style = MaterialTheme.typography.bodyMedium,
            )
            if (link.active) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    TextButton(onClick = onCopy) {
                        Icon(if (copied) Icons.Default.Check else Icons.Default.ContentCopy, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text(if (copied) "Copied" else "Copy")
                    }
                    TextButton(onClick = onShare) {
                        Icon(Icons.Default.Share, contentDescription = null, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Share")
                    }
                    TextButton(onClick = onTurnOff, enabled = !busy) {
                        Icon(Icons.Default.LinkOff, contentDescription = null, tint = WarningAmber, modifier = Modifier.size(16.dp))
                        Spacer(Modifier.width(4.dp))
                        Text("Turn off", color = WarningAmber)
                    }
                }
            }
        }
    }
}

@Composable
private fun MemberRow(name: String, username: String?, already: Boolean, busy: Boolean, onInvite: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.weight(1f)) {
            Text(name, color = TextPrimary, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            username?.let {
                Text("@$it", color = TextSecondary, style = MaterialTheme.typography.bodySmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
            }
        }
        OutlinedButton(
            onClick = onInvite,
            enabled = !already && !busy,
            modifier = Modifier.semantics { contentDescription = if (already) "$name is invited" else "Invite $name" },
        ) {
            Icon(if (already) Icons.Default.Check else Icons.Default.PersonAdd, contentDescription = null, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(4.dp))
            Text(if (already) "Invited" else "Invite")
        }
    }
}

@Composable
private fun GuestRow(guest: EventGuestDto, busy: Boolean, onRemove: () -> Unit) {
    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.weight(1f)) {
            Text(guest.user.name, color = TextPrimary, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis)
            Text(CommunityDiscovery.describeGuest(guest), color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
        TextButton(
            onClick = onRemove,
            enabled = !busy,
            modifier = Modifier.semantics { contentDescription = "Remove ${guest.user.name} from the guest list" },
        ) {
            Icon(Icons.Default.PersonRemove, contentDescription = null, tint = DangerRed, modifier = Modifier.size(16.dp))
            Spacer(Modifier.width(4.dp))
            Text("Remove", color = DangerRed)
        }
    }
}

// ── Guest: accept an invitation ─────────────────────────────────────────────

/**
 * Where an invite link lands in the app: what the invitation is for, then
 * one tap puts this account on the guest list (so every device sees the
 * event) and opens it.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommunityInviteScreen(nav: NavHostController, token: String) {
    val vm = rememberCommunityViewModel(nav)
    val scope = rememberCoroutineScope()
    val validToken = remember(token) { CommunityDiscovery.inviteTokenFromText(token) }
    var preview by remember { mutableStateOf<InvitePreviewDto?>(null) }
    var loadError by remember { mutableStateOf<CommunityDiscovery.FriendlyError?>(null) }
    var attempt by remember { mutableIntStateOf(0) }
    var accepting by remember { mutableStateOf(false) }
    var acceptError by remember { mutableStateOf<String?>(null) }

    LaunchedEffect(validToken, attempt) {
        if (validToken == null) {
            loadError = CommunityDiscovery.FriendlyError(
                "This invite link isn't valid",
                "Check that you copied the whole link, or ask the host for a new one.",
                retry = false,
            )
            return@LaunchedEffect
        }
        try {
            preview = vm.previewInvite(validToken)
            loadError = null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            if (preview == null) loadError = CommunityDiscovery.inviteError(e)
        }
    }

    fun openEvent(eventId: String) {
        nav.navigate(Routes.communityNode("event", eventId)) {
            popUpTo(Routes.COMMUNITY_INVITE) { inclusive = true }
        }
    }

    fun browseCommunity() {
        nav.navigate(Routes.COMMUNITY) {
            popUpTo(Routes.COMMUNITY_INVITE) { inclusive = true }
            launchSingleTop = true
        }
    }

    fun accept() {
        val code = validToken ?: return
        accepting = true
        acceptError = null
        scope.launch {
            try {
                val node = vm.acceptInvite(code)
                openEvent(node.id)
            } catch (e: CancellationException) {
                throw e
            } catch (e: Exception) {
                acceptError = CommunityDiscovery.friendlyError(e, "accept this invite").message
                accepting = false
                // The link may have just expired or filled up: show why.
                attempt += 1
            }
        }
    }

    Scaffold(
        containerColor = Background,
        topBar = {
            TopAppBar(
                title = { Text("Invitation") },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = TextPrimary)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = Background, titleContentColor = TextPrimary),
            )
        },
    ) { padding ->
        Box(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding),
        ) {
            val invite = preview
            val error = loadError
            when {
                invite != null -> InviteContent(
                    invite = invite,
                    accepting = accepting,
                    acceptError = acceptError,
                    onAccept = { accept() },
                    onOpenEvent = { openEvent(invite.eventId.toString()) },
                    onBrowse = { browseCommunity() },
                )
                error != null -> CommunityStateMessage(
                    title = error.title,
                    body = error.body,
                    actions = if (error.retry) listOf("Try again" to { attempt += 1 }) else listOf("Browse Community" to { browseCommunity() }),
                    icon = if (error == CommunityDiscovery.offlineError) Icons.Default.WifiOff else Icons.Default.MailOutline,
                )
                else -> Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(12.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 80.dp),
                ) {
                    CircularProgressIndicator(color = LyoPurple)
                    Text("Opening your invitation…", color = TextSecondary)
                }
            }
        }
    }
}

@Composable
private fun InviteContent(
    invite: InvitePreviewDto,
    accepting: Boolean,
    acceptError: String?,
    onAccept: () -> Unit,
    onOpenEvent: () -> Unit,
    onBrowse: () -> Unit,
) {
    val hostName = invite.organizerName ?: invite.host?.name
    val notice = CommunityDiscovery.inviteNotice(invite.status)
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        CommunityDiscovery.safeWebUrl(invite.imageUrl)?.let { image ->
            AsyncImage(
                model = image,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(160.dp),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Text(
                when {
                    invite.isHost -> "YOUR EVENT"
                    invite.visibility == "private" -> "PRIVATE INVITATION"
                    else -> "INVITATION"
                },
                color = LyoPurple,
                style = MaterialTheme.typography.labelMedium,
                fontWeight = FontWeight.Bold,
            )
            Text(
                invite.title,
                color = TextPrimary,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.semantics { heading() },
            )
            if (hostName != null && !invite.isHost) {
                Text("$hostName invited you", color = TextSecondary)
            }
        }
        Surface(color = SurfaceElevated, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(14.dp)) {
                CommunityDiscovery.formatWhen(invite.startsAt, invite.endsAt)?.let { CommunityInfoLine(Icons.Default.Schedule, it) }
                val place = invite.locationName?.takeIf { it.isNotBlank() }
                when {
                    invite.attendanceMode == "online" -> CommunityInfoLine(Icons.Default.Videocam, "Online")
                    place != null -> CommunityInfoLine(
                        Icons.Default.Place,
                        if (invite.attendanceMode == "hybrid") "$place · also online" else place,
                    )
                }
                hostName?.let { CommunityInfoLine(Icons.Default.Person, "Hosted by $it") }
            }
        }

        when {
            invite.alreadyGuest || invite.isHost -> {
                Text(
                    if (invite.isHost) "You're the host of this event." else "You're already on the guest list.",
                    color = TextSecondary,
                )
                Button(
                    onClick = onOpenEvent,
                    colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
                ) { Text("Open event", fontWeight = FontWeight.SemiBold) }
            }
            notice != null -> {
                Surface(
                    color = SurfaceElevated,
                    shape = RoundedCornerShape(14.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .semantics(mergeDescendants = true) {},
                ) {
                    Column(verticalArrangement = Arrangement.spacedBy(4.dp), modifier = Modifier.padding(14.dp)) {
                        Text(notice.title, color = TextPrimary, fontWeight = FontWeight.SemiBold)
                        Text(notice.body, color = TextSecondary, style = MaterialTheme.typography.bodyMedium)
                    }
                }
                TextButton(onClick = onBrowse) { Text("Browse Community") }
            }
            else -> {
                Button(
                    onClick = onAccept,
                    enabled = !accepting,
                    colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                    modifier = Modifier
                        .fillMaxWidth()
                        .heightIn(min = 48.dp),
                ) {
                    if (accepting) {
                        CircularProgressIndicator(color = TextPrimary, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                    }
                    Text("Accept invitation", fontWeight = FontWeight.SemiBold)
                }
                acceptError?.let { Text(it, color = DangerRed, style = MaterialTheme.typography.bodySmall) }
                Text(
                    "Accepting adds this event to your Lyo account on every device. You can RSVP next.",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.fillMaxWidth(),
                )
            }
        }
    }
}

// ── My Community: paste a link ───────────────────────────────────────────────

/** Paste an invite link (or code) someone sent in a message or email. */
@Composable
internal fun InviteLinkField(onOpen: (String) -> Unit) {
    var text by rememberSaveable { mutableStateOf("") }
    var invalid by remember { mutableStateOf(false) }

    fun submit() {
        if (text.isBlank()) return
        val token = CommunityDiscovery.inviteTokenFromText(text)
        if (token == null) {
            invalid = true
        } else {
            text = ""
            onOpen(token)
        }
    }

    Surface(color = SurfaceElevated, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
        Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Default.Link, contentDescription = null, tint = LyoPurple, modifier = Modifier.size(20.dp))
                Spacer(Modifier.width(8.dp))
                Text("Have an invite link?", color = TextPrimary, fontWeight = FontWeight.SemiBold)
            }
            OutlinedTextField(
                value = text,
                onValueChange = {
                    text = it
                    invalid = false
                },
                singleLine = true,
                label = { Text("Paste it here") },
                isError = invalid,
                supportingText = if (invalid) {
                    { Text("That doesn't look like a Lyo invite link.") }
                } else {
                    null
                },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri, imeAction = ImeAction.Go),
                keyboardActions = KeyboardActions(onGo = { submit() }),
                modifier = Modifier.fillMaxWidth(),
            )
            Button(
                onClick = { submit() },
                enabled = text.isNotBlank(),
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
                modifier = Modifier
                    .fillMaxWidth()
                    .heightIn(min = 48.dp),
            ) { Text("Open invite") }
        }
    }
}
