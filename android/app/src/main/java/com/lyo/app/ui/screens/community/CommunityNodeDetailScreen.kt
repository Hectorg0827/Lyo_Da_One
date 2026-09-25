package com.lyo.app.ui.screens.community

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.provider.CalendarContract
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.Cancel
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Directions
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.EventAvailable
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Language
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Phone
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Sell
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Videocam
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
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
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.viewmodel.compose.viewModel
import androidx.navigation.NavHostController
import coil.compose.AsyncImage
import com.lyo.app.data.api.LearningNodeDetailDto
import com.lyo.app.data.api.LearningNodeDto
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

private val reportReasons = listOf(
    "spam" to "Spam or advertising",
    "misinformation" to "Misleading or fake event",
    "inappropriate" to "Inappropriate content",
    "harassment" to "Harassment or hate",
    "other" to "Something else",
)

private enum class Confirm { CANCEL, DELETE }

/**
 * Full page for one event, group, tutor, or place. It reads the item from the
 * backend, so it also works for past, cancelled, and private events and for
 * links shared from another device.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CommunityNodeDetailScreen(nav: NavHostController, kind: String, nodeId: String) {
    // Share the map's state when opened from Community, so a save or RSVP
    // here is already reflected when the learner goes back.
    val communityEntry = remember(nav) { runCatching { nav.getBackStackEntry(Routes.COMMUNITY) }.getOrNull() }
    val vm: CommunityMapViewModel = if (communityEntry != null) viewModel(viewModelStoreOwner = communityEntry) else viewModel()
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val snackbar = remember { SnackbarHostState() }
    var loadError by remember { mutableStateOf<CommunityDiscovery.FriendlyError?>(null) }
    var attempt by remember { mutableIntStateOf(0) }
    var showReport by remember { mutableStateOf(false) }
    var confirm by remember { mutableStateOf<Confirm?>(null) }
    var working by remember { mutableStateOf(false) }
    val detail = vm.detail(kind, nodeId)

    LaunchedEffect(kind, nodeId, vm.revision, attempt) {
        try {
            vm.loadDetail(kind, nodeId)
            loadError = null
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            loadError = CommunityDiscovery.friendlyError(e, "load this")
        }
    }
    LaunchedEffect(vm) { vm.messages.collect { snackbar.showSnackbar(it) } }

    fun openLink(url: String) {
        try {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        } catch (_: ActivityNotFoundException) {
            vm.announce("No app on this device can open that link.")
        }
    }

    Scaffold(
        containerColor = Background,
        snackbarHost = { SnackbarHost(snackbar) },
        topBar = {
            TopAppBar(
                title = { Text(detail?.node?.categoryLabel() ?: "Details") },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, contentDescription = "Back", tint = TextPrimary)
                    }
                },
                actions = {
                    detail?.node?.let { node ->
                        IconButton(onClick = {
                            vm.track("community_event_shared", mapOf("kind" to node.kind))
                            val link = CommunityDiscovery.shareUrl(node.kind, node.id)
                            val text = listOfNotNull(node.title, node.whenText(), node.placeLine(), link).joinToString("\n")
                            val send = Intent(Intent.ACTION_SEND).setType("text/plain")
                                .putExtra(Intent.EXTRA_SUBJECT, node.title)
                                .putExtra(Intent.EXTRA_TEXT, text)
                            runCatching { context.startActivity(Intent.createChooser(send, "Share")) }
                        }) {
                            Icon(Icons.Default.Share, contentDescription = "Share", tint = TextPrimary)
                        }
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
            val error = loadError
            when {
                detail != null -> DetailContent(
                    detail = detail,
                    vm = vm,
                    staleError = error,
                    working = working,
                    onOpen = ::openLink,
                    onAddToCalendar = { node -> addToCalendar(context, node, vm) },
                    onEdit = { id -> nav.navigate(Routes.editEvent(id.toString())) },
                    onConfirm = { confirm = it },
                    onReport = { showReport = true },
                    onOpenRelated = { node -> nav.navigate(Routes.communityNode(node.kind, node.id)) },
                    onNavigate = { route -> nav.navigate(route) },
                )
                error != null -> CommunityStateMessage(
                    title = error.title,
                    body = error.body,
                    actions = if (error.retry) listOf("Try again" to { attempt += 1 }) else listOf("Go back" to { nav.popBackStack(); Unit }),
                    icon = if (error == CommunityDiscovery.offlineError) Icons.Default.WifiOff else Icons.Default.Place,
                )
                else -> Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(color = LyoPurple)
                }
            }
        }
    }

    if (showReport && detail != null) {
        var reason by remember { mutableStateOf("spam") }
        AlertDialog(
            onDismissRequest = { showReport = false },
            title = { Text("Report this event") },
            text = {
                Column {
                    Text("Our team reviews every report. The host isn't told who reported it.", color = TextSecondary)
                    Spacer(Modifier.height(8.dp))
                    reportReasons.forEach { (value, label) ->
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .heightIn(min = 44.dp)
                                .selectable(selected = reason == value, role = Role.RadioButton, onClick = { reason = value }),
                        ) {
                            RadioButton(selected = reason == value, onClick = null)
                            Spacer(Modifier.width(8.dp))
                            Text(label)
                        }
                    }
                }
            },
            confirmButton = {
                TextButton(onClick = {
                    showReport = false
                    vm.reportEvent(detail.node, reason)
                }) { Text("Send report") }
            },
            dismissButton = { TextButton(onClick = { showReport = false }) { Text("Cancel") } },
        )
    }

    val pending = confirm
    val eventId = detail?.event?.id
    if (pending != null && eventId != null) {
        AlertDialog(
            onDismissRequest = { confirm = null },
            title = { Text(if (pending == Confirm.DELETE) "Delete this event?" else "Cancel this event?") },
            text = {
                Text(
                    if (pending == Confirm.DELETE) "It will be removed for everyone. This can't be undone."
                    else "It stays visible as cancelled to people who RSVP'd, and leaves the map.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    confirm = null
                    if (pending == Confirm.CANCEL) {
                        vm.cancelEvent(eventId)
                    } else {
                        working = true
                        scope.launch {
                            try {
                                vm.deleteEvent(eventId)
                                nav.popBackStack()
                            } catch (e: CancellationException) {
                                throw e
                            } catch (e: Exception) {
                                vm.announce(CommunityDiscovery.friendlyError(e, "delete this event").message)
                            } finally {
                                working = false
                            }
                        }
                    }
                }) { Text(if (pending == Confirm.DELETE) "Delete" else "Cancel event", color = DangerRed) }
            },
            dismissButton = { TextButton(onClick = { confirm = null }) { Text("Keep it") } },
        )
    }
}

@Composable
private fun DetailContent(
    detail: LearningNodeDetailDto,
    vm: CommunityMapViewModel,
    staleError: CommunityDiscovery.FriendlyError?,
    working: Boolean,
    onOpen: (String) -> Unit,
    onAddToCalendar: (LearningNodeDto) -> Unit,
    onEdit: (Long) -> Unit,
    onConfirm: (Confirm) -> Unit,
    onReport: () -> Unit,
    onOpenRelated: (LearningNodeDto) -> Unit,
    onNavigate: (String) -> Unit,
) {
    val node = detail.node
    val color = categoryColor(node.category)
    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        CommunityDiscovery.safeWebUrl(node.imageUrl)?.let { image ->
            AsyncImage(
                model = image,
                contentDescription = null,
                contentScale = ContentScale.Crop,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(190.dp)
                    .padding(0.dp),
            )
        }
        Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(categoryIcon(node.category), contentDescription = null, tint = color, modifier = Modifier.size(18.dp))
                Text(node.categoryLabel(), color = color, style = MaterialTheme.typography.labelLarge, fontWeight = FontWeight.Bold)
                StatusBadge(node)
                if (node.isInvited == true && !detail.canEdit) {
                    Surface(color = LyoPurple.copy(alpha = 0.2f), shape = RoundedCornerShape(50)) {
                        Text(
                            "You're invited",
                            color = LyoPurple,
                            style = MaterialTheme.typography.labelSmall,
                            fontWeight = FontWeight.Bold,
                            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
                        )
                    }
                }
            }
            Text(
                node.title,
                color = TextPrimary,
                style = MaterialTheme.typography.headlineSmall,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.semantics { heading() },
            )
        }
        if (staleError != null) {
            Text("Couldn't refresh. Showing what we had.", color = TextSecondary, style = MaterialTheme.typography.bodySmall)
        }
        if (node.lifecycle == "cancelled") {
            Surface(color = DangerRed.copy(alpha = 0.12f), shape = RoundedCornerShape(12.dp), modifier = Modifier.fillMaxWidth()) {
                Text("This event was cancelled by the host.", color = DangerRed, modifier = Modifier.padding(12.dp))
            }
        }

        CommunityPrimaryActions(node = node, vm = vm)

        Surface(color = SurfaceElevated, shape = RoundedCornerShape(16.dp), modifier = Modifier.fillMaxWidth()) {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp), modifier = Modifier.padding(14.dp)) {
                node.whenText()?.let { CommunityInfoLine(Icons.Default.Schedule, it) }
                node.placeLine()?.let { place ->
                    CommunityInfoLine(Icons.Default.Place, listOfNotNull(place, node.distanceText()).joinToString(" · "))
                }
                node.organizerLine()?.let { CommunityInfoLine(Icons.Default.Person, it) }
                node.priceText()?.let { CommunityInfoLine(Icons.Default.Sell, it) }
                node.peopleLine()?.let { CommunityInfoLine(Icons.Default.Groups, it) }
                node.openingHours?.takeIf { it.isNotBlank() }?.let { CommunityInfoLine(Icons.Default.CalendarMonth, it) }
            }
        }

        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            CommunityDiscovery.directionsUrl(node)?.let { url ->
                DetailAction("Directions", Icons.Default.Directions) {
                    vm.track("community_directions_opened", mapOf("kind" to node.kind))
                    onOpen(url)
                }
            }
            if (node.kind == "event" && !node.hasEnded && node.startsAt != null) {
                DetailAction("Add to calendar", Icons.Default.EventAvailable) { onAddToCalendar(node) }
            }
            if (!node.hasEnded) {
                CommunityDiscovery.safeWebUrl(node.meetingUrl)?.let { url -> DetailAction("Join online", Icons.Default.Videocam) { onOpen(url) } }
            }
            CommunityDiscovery.safeWebUrl(node.websiteUrl ?: node.sourceUrl)?.let { url ->
                DetailAction("Website", Icons.Default.Language) { onOpen(url) }
            }
            node.phone?.filter { it.isDigit() || it == '+' }?.takeIf { it.count(Char::isDigit) >= 5 }?.let { phone ->
                DetailAction("Call", Icons.Default.Phone) { onOpen("tel:$phone") }
            }
            node.email?.takeIf { "@" in it && " " !in it }?.let { email ->
                DetailAction("Email", Icons.Default.Email) { onOpen("mailto:$email") }
            }
            node.courseId?.let { courseId ->
                DetailAction("Open course", Icons.Default.School) { onNavigate(Routes.courseDetail(courseId.toString())) }
            }
        }

        node.description?.takeIf { it.isNotBlank() }?.let { text ->
            DetailSection("About") { Text(text, color = TextSecondary, style = MaterialTheme.typography.bodyLarge) }
        }
        node.relevance?.takeIf { it.isNotBlank() }?.let { text ->
            DetailSection("Why it's here") { Text(text, color = TextSecondary, style = MaterialTheme.typography.bodyLarge) }
        }

        val record = detail.event
        if (detail.canEdit && record != null) {
            DetailSection("Your event") {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    if (CommunityDiscovery.canManageInvites(node, detail.canEdit)) {
                        DetailAction("Invite people", Icons.Default.PersonAdd, enabled = !working) {
                            onNavigate(Routes.eventInvites(record.id.toString()))
                        }
                    }
                    DetailAction("Edit event", Icons.Default.Edit, enabled = !working) { onEdit(record.id) }
                    if (node.lifecycle != "cancelled" && node.lifecycle != "past") {
                        DetailAction("Cancel event", Icons.Default.Cancel, tint = WarningAmber, enabled = !working) { onConfirm(Confirm.CANCEL) }
                    }
                    DetailAction("Delete event", Icons.Default.Delete, tint = DangerRed, enabled = !working) { onConfirm(Confirm.DELETE) }
                }
            }
        } else if (node.kind == "event" && node.isOwner != true) {
            TextButton(onClick = onReport) {
                Icon(Icons.Default.Flag, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(18.dp))
                Spacer(Modifier.width(6.dp))
                Text("Report this event", color = TextSecondary)
            }
        }

        if (detail.related.isNotEmpty()) {
            DetailSection("More like this nearby") {
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    detail.related.forEach { related ->
                        LearningNodeCard(node = related, onClick = { onOpenRelated(related) })
                    }
                }
            }
        }
        DetailAction("Ask Lyo about this", Icons.Default.AutoAwesome) { onNavigate(Routes.CHAT) }
        Spacer(Modifier.height(24.dp))
    }
}

@Composable
private fun DetailAction(
    label: String,
    icon: ImageVector,
    tint: Color = TextPrimary,
    enabled: Boolean = true,
    onClick: () -> Unit,
) {
    Surface(
        color = SurfaceElevated,
        shape = RoundedCornerShape(12.dp),
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier
            .fillMaxWidth()
            .heightIn(min = 48.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(horizontal = 14.dp, vertical = 12.dp)) {
            Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.size(20.dp))
            Spacer(Modifier.width(10.dp))
            Text(label, color = tint.copy(alpha = if (enabled) 1f else 0.5f), fontWeight = FontWeight.SemiBold)
        }
    }
}

@Composable
private fun DetailSection(title: String, content: @Composable () -> Unit) {
    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
        Text(
            title,
            color = TextPrimary,
            style = MaterialTheme.typography.titleMedium,
            fontWeight = FontWeight.SemiBold,
            modifier = Modifier.semantics { heading() },
        )
        content()
    }
}

/** The device calendar's own "new event" screen, prefilled; no calendar permission needed. */
private fun addToCalendar(context: android.content.Context, node: LearningNodeDto, vm: CommunityMapViewModel) {
    val start = CommunityDiscovery.parseInstant(node.startsAt) ?: return
    val end = CommunityDiscovery.parseInstant(node.endsAt) ?: start.plusSeconds(3_600)
    val place = listOfNotNull(node.venueName, node.address ?: node.locationName).filter { it.isNotBlank() }.joinToString(", ")
    val intent = Intent(Intent.ACTION_INSERT)
        .setData(CalendarContract.Events.CONTENT_URI)
        .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, start.toEpochMilli())
        .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end.toEpochMilli())
        .putExtra(CalendarContract.Events.TITLE, node.title)
        .putExtra(
            CalendarContract.Events.DESCRIPTION,
            listOfNotNull(node.description, CommunityDiscovery.shareUrl(node.kind, node.id)).joinToString("\n\n"),
        )
        .putExtra(CalendarContract.Events.EVENT_LOCATION, place)
    try {
        context.startActivity(intent)
    } catch (_: ActivityNotFoundException) {
        vm.announce("No calendar app is available on this device.")
    }
}
