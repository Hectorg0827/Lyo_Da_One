package com.lyo.app.ui.screens.community

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.AccountBalance
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.Bookmark
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.Handyman
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.LocalLibrary
import androidx.compose.material.icons.filled.LocalOffer
import androidx.compose.material.icons.filled.Museum
import androidx.compose.material.icons.filled.NearMe
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.School
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Today
import androidx.compose.material.icons.outlined.BookmarkBorder
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.StarBorder
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lyo.app.data.api.LearningNodeDto
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.SurfaceElevated
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

// Shared pieces of the Community map, preview, and detail screens.

internal val DangerRed = Color(0xFFEF4444)
internal val WarningAmber = Color(0xFFF59E0B)
internal val SuccessGreen = Color(0xFF10B981)

internal fun categoryIcon(category: String): ImageVector = when (category) {
    "event" -> Icons.Default.CalendarMonth
    "workshop" -> Icons.Default.Handyman
    "class" -> Icons.Default.School
    "study_group" -> Icons.Default.Groups
    "tutor" -> Icons.Default.Person
    "library" -> Icons.Default.LocalLibrary
    "museum" -> Icons.Default.Museum
    "educational_center" -> Icons.Default.AccountBalance
    else -> Icons.Default.Place
}

internal fun categoryColor(category: String): Color = when (category) {
    "event" -> Color(0xFFF97316)
    "workshop" -> Color(0xFFF59E0B)
    "class" -> Color(0xFF8B5CF6)
    "study_group" -> Color(0xFF3B82F6)
    "tutor" -> Color(0xFFEC4899)
    "library" -> Color(0xFF10B981)
    "museum" -> Color(0xFF06B6D4)
    "educational_center" -> Color(0xFF6366F1)
    else -> LyoPurple
}

internal fun filterIcon(id: String): ImageVector = when (id) {
    "events" -> Icons.Default.CalendarMonth
    "libraries" -> Icons.Default.LocalLibrary
    "museums" -> Icons.Default.Museum
    "classes" -> Icons.Default.School
    "workshops" -> Icons.Default.Handyman
    "study_groups" -> Icons.Default.Groups
    "schools" -> Icons.Default.AccountBalance
    "learning_centers" -> Icons.Default.Lightbulb
    "tutors" -> Icons.Default.Person
    "free" -> Icons.Default.LocalOffer
    "today" -> Icons.Default.Today
    "week" -> Icons.Default.DateRange
    "nearby" -> Icons.Default.NearMe
    else -> Icons.Default.AutoAwesome
}

internal fun LearningNodeDto.categoryLabel(): String = CommunityDiscovery.categoryLabel(category, placeType)

internal fun LearningNodeDto.whenText(): String? = CommunityDiscovery.formatWhen(startsAt, endsAt)

internal fun LearningNodeDto.distanceText(): String? = CommunityDiscovery.formatDistance(distanceKm)

internal fun LearningNodeDto.priceText(): String? = CommunityDiscovery.formatPrice(isFree, priceAmount, currency)

/** "Today", "Happening now", "Ended", "Cancelled", or the visibility of a hidden event. */
internal fun LearningNodeDto.statusBadge(): String? = when (lifecycle) {
    "today", "live", "past", "cancelled" -> CommunityDiscovery.lifecycleLabel(lifecycle)
    else -> when (visibility) {
        "private" -> "Private"
        "unlisted" -> "Unlisted"
        else -> null
    }
}

internal fun LearningNodeDto.statusColor(): Color = when (lifecycle) {
    "live", "today" -> SuccessGreen
    "cancelled" -> DangerRed
    "past" -> TextSecondary
    else -> Color(0xFFA78BFA)
}

internal fun LearningNodeDto.placeLine(): String? {
    if (attendanceMode == "online" || (isOnline && latitude == null && attendanceMode != "hybrid")) return "Online"
    val parts = listOfNotNull(venueName, address ?: locationName)
        .map { it.trim() }
        .filter { it.isNotEmpty() }
        .distinct()
    if (parts.isEmpty()) return null
    val text = parts.joinToString(", ")
    return if (attendanceMode == "hybrid") "$text · also online" else text
}

internal fun LearningNodeDto.organizerLine(): String? =
    organizerName?.takeIf { it.isNotBlank() }?.let { "Hosted by $it" } ?: host?.name?.let { "Hosted by $it" }

internal fun LearningNodeDto.peopleLine(): String? {
    if (kind == "event") {
        val parts = mutableListOf<String>()
        (goingCount ?: attendeeCount)?.takeIf { it > 0 }?.let { parts += "$it going" }
        interestedCount?.takeIf { it > 0 }?.let { parts += "$it interested" }
        capacity?.let { parts += if (isFull == true) "Full ($it spots)" else "$it spots" }
        return parts.takeIf { it.isNotEmpty() }?.joinToString(" · ")
    }
    return memberCount?.let { "$it ${if (it == 1) "member" else "members"}" }
}

internal fun LearningNodeDto.metaLine(): String =
    listOfNotNull(distanceText(), whenText(), priceText(), peopleLine()).joinToString(" · ")

@Composable
internal fun CommunityInfoLine(icon: ImageVector, text: String) {
    Row(verticalAlignment = Alignment.Top, modifier = Modifier.padding(vertical = 2.dp)) {
        Icon(icon, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(18.dp))
        Spacer(Modifier.width(8.dp))
        Text(text, color = TextPrimary, style = MaterialTheme.typography.bodyMedium)
    }
}

@Composable
internal fun StatusBadge(node: LearningNodeDto) {
    val badge = node.statusBadge() ?: return
    val color = node.statusColor()
    Surface(color = color.copy(alpha = 0.18f), shape = RoundedCornerShape(50)) {
        Text(
            badge,
            color = color,
            style = MaterialTheme.typography.labelSmall,
            fontWeight = FontWeight.Bold,
            modifier = Modifier.padding(horizontal = 8.dp, vertical = 2.dp),
        )
    }
}

/** A row in results and My Community. */
@Composable
internal fun LearningNodeCard(node: LearningNodeDto, onClick: () -> Unit) {
    val color = categoryColor(node.category)
    Surface(
        color = SurfaceElevated,
        shape = RoundedCornerShape(16.dp),
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClickLabel = "Show details", role = Role.Button, onClick = onClick),
    ) {
        Row(verticalAlignment = Alignment.Top, modifier = Modifier.padding(12.dp)) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(44.dp)
                    .background(color.copy(alpha = 0.16f), RoundedCornerShape(12.dp)),
            ) {
                Icon(categoryIcon(node.category), contentDescription = null, tint = color, modifier = Modifier.size(22.dp))
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(3.dp)) {
                Row(verticalAlignment = Alignment.Top) {
                    Text(
                        node.title,
                        color = TextPrimary,
                        fontWeight = FontWeight.SemiBold,
                        maxLines = 2,
                        overflow = TextOverflow.Ellipsis,
                        modifier = Modifier.weight(1f),
                    )
                    if (node.isSaved) {
                        Icon(Icons.Default.Bookmark, contentDescription = "Saved", tint = LyoPurple, modifier = Modifier.size(18.dp))
                    }
                }
                Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    Text(node.categoryLabel(), color = color, style = MaterialTheme.typography.labelSmall, fontWeight = FontWeight.Bold)
                    StatusBadge(node)
                }
                node.metaLine().takeIf { it.isNotBlank() }?.let {
                    Text(it, color = TextSecondary, style = MaterialTheme.typography.bodySmall, maxLines = 2, overflow = TextOverflow.Ellipsis)
                }
                node.placeLine()?.let {
                    Text(it, color = TextSecondary, style = MaterialTheme.typography.labelSmall, maxLines = 1, overflow = TextOverflow.Ellipsis)
                }
            }
        }
    }
}

/** A pill toggle with a 44dp touch target and a spoken on/off state. */
@Composable
internal fun ToggleAction(
    label: String,
    icon: ImageVector,
    selected: Boolean,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Surface(
        color = if (selected) LyoPurple else SurfaceElevated,
        shape = RoundedCornerShape(50),
        modifier = Modifier
            .heightIn(min = 44.dp)
            .clickable(enabled = enabled, role = Role.Button, onClick = onClick)
            .semantics { stateDescription = if (selected) "On" else "Off" },
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.padding(horizontal = 14.dp, vertical = 10.dp),
        ) {
            Icon(icon, contentDescription = null, tint = if (selected) Color.White else TextPrimary, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(6.dp))
            Text(
                label,
                color = (if (selected) Color.White else TextPrimary).copy(alpha = if (enabled) 1f else 0.5f),
                style = MaterialTheme.typography.labelLarge,
            )
        }
    }
}

/** RSVP / join and save: the same controls in the preview and on the detail page. */
@Composable
internal fun CommunityPrimaryActions(node: LearningNodeDto, vm: CommunityMapViewModel) {
    val busy = vm.isBusy(node.key)
    LazyRow(horizontalArrangement = Arrangement.spacedBy(8.dp), contentPadding = PaddingValues(vertical = 2.dp)) {
        when {
            node.kind == "event" && node.lifecycle == "cancelled" -> item {
                Text("Cancelled", color = DangerRed, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(vertical = 12.dp))
            }
            node.kind == "event" && node.lifecycle == "past" -> item {
                Text("This event has ended", color = TextSecondary, modifier = Modifier.padding(vertical = 12.dp))
            }
            node.kind == "event" -> {
                item {
                    val full = node.isFull == true && !node.isGoing
                    ToggleAction(
                        label = if (full) "Full" else "Going",
                        icon = if (node.isGoing) Icons.Default.CheckCircle else Icons.Outlined.CheckCircle,
                        selected = node.isGoing,
                        enabled = !busy && !full,
                        onClick = { vm.setRsvp(node, if (node.isGoing) null else "going") },
                    )
                }
                item {
                    ToggleAction(
                        label = "Interested",
                        icon = if (node.isInterested) Icons.Default.Star else Icons.Outlined.StarBorder,
                        selected = node.isInterested,
                        enabled = !busy,
                        onClick = { vm.setRsvp(node, if (node.isInterested) null else "interested") },
                    )
                }
            }
            node.kind == "study_group" -> item {
                ToggleAction(
                    label = if (node.isJoined) "Joined" else "Join group",
                    icon = if (node.isJoined) Icons.Default.CheckCircle else Icons.Default.PersonAdd,
                    selected = node.isJoined,
                    enabled = !busy,
                    onClick = { vm.toggleMembership(node) },
                )
            }
        }
        item {
            ToggleAction(
                label = if (node.isSaved) "Saved" else "Save",
                icon = if (node.isSaved) Icons.Default.Bookmark else Icons.Outlined.BookmarkBorder,
                selected = node.isSaved,
                enabled = !busy,
                onClick = { vm.toggleSave(node) },
            )
        }
    }
}

@Composable
internal fun CommunityStateMessage(
    title: String,
    body: String,
    actions: List<Pair<String, () -> Unit>> = emptyList(),
    icon: ImageVector = Icons.Default.Place,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(8.dp),
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 28.dp, horizontal = 16.dp)
            .semantics(mergeDescendants = true) {},
    ) {
        Icon(icon, contentDescription = null, tint = LyoPurple, modifier = Modifier.size(36.dp))
        Text(title, color = TextPrimary, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.SemiBold)
        Text(body, color = TextSecondary, style = MaterialTheme.typography.bodyMedium)
        Spacer(Modifier.height(4.dp))
        actions.forEachIndexed { index, (label, action) ->
            if (index == 0) {
                androidx.compose.material3.Button(
                    onClick = action,
                    colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = LyoPurple),
                ) { Text(label) }
            } else {
                androidx.compose.material3.OutlinedButton(onClick = action) { Text(label) }
            }
        }
    }
}

@Composable
internal fun EmptyCommunityText(text: String) {
    Text(text, color = TextSecondary, style = MaterialTheme.typography.bodySmall, modifier = Modifier.padding(vertical = 8.dp))
}
