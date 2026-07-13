package com.lyo.app.ui.screens.notifications

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.NotificationDto
import com.lyo.app.data.sync.SyncClient
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

private val SystemTypes = setOf("system", "achievement", "course_complete", "event_reminder")

private val Filters = listOf("All", "Mentions", "Likes", "Comments", "System")

private fun matchesFilter(n: NotificationDto, filter: String): Boolean {
    val type = n.type ?: ""
    return when (filter) {
        "Mentions" -> type == "mention"
        "Likes" -> type == "like"
        "Comments" -> type == "comment"
        "System" -> type in SystemTypes
        else -> true
    }
}

private fun dotColorFor(type: String?): Color = when (type) {
    "like" -> LyoRed
    "comment" -> LyoPurple
    "follow" -> LyoGreen
    "achievement" -> LyoAmber
    else -> TextSecondary
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()

    var notifications by remember { mutableStateOf<List<NotificationDto>>(emptyList()) }
    var unreadCount by remember { mutableIntStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var filter by remember { mutableStateOf("All") }

    suspend fun refetch() {
        runCatching { ApiClient.api.notifications(1, 50) }
            .onSuccess { resp ->
                notifications = resp.notifications.orEmpty()
                unreadCount = resp.unreadCount
                    ?: resp.notifications.orEmpty().count { it.isRead != true }
            }
        loading = false
    }

    LaunchedEffect(Unit) { refetch() }

    // Live cross-device sync: actions on other platforms (likes, follows,
    // achievements) populate this feed without leaving the screen.
    LaunchedEffect(Unit) {
        SyncClient.events.collect { event ->
            if (event.eventType in setOf("context_updated", "message_received")) refetch()
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
    ) {
        TopAppBar(
            title = { Text("Notifications", style = MaterialTheme.typography.headlineSmall) },
            navigationIcon = {
                IconButton(onClick = { nav.popBackStack() }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = TextPrimary,
                    )
                }
            },
            actions = {
                if (unreadCount > 0) {
                    TextButton(
                        onClick = {
                            scope.launch {
                                runCatching { ApiClient.api.markAllNotificationsRead() }
                                refetch()
                            }
                        },
                    ) {
                        Text(
                            text = "Mark all read",
                            style = MaterialTheme.typography.labelLarge,
                            color = LyoPurple,
                        )
                    }
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = Background,
                titleContentColor = TextPrimary,
            ),
        )

        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 4.dp),
        ) {
            Filters.forEach { f ->
                FilterChip(
                    selected = filter == f,
                    onClick = { filter = f },
                    label = { Text(f) },
                    colors = FilterChipDefaults.filterChipColors(
                        containerColor = Surface,
                        labelColor = TextSecondary,
                        selectedContainerColor = LyoPurple.copy(alpha = 0.2f),
                        selectedLabelColor = LyoPurple,
                    ),
                )
            }
        }

        val visible = notifications.filter { matchesFilter(it, filter) }
        when {
            loading -> LoadingBox()
            visible.isEmpty() -> EmptyState(
                title = "No notifications",
                subtitle = "You're all caught up!",
            )
            else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                items(visible) { notification ->
                    NotificationRow(
                        notification = notification,
                        onClick = {
                            if (notification.isRead != true) {
                                notifications = notifications.map {
                                    if (it.idStr == notification.idStr) it.copy(isRead = true)
                                    else it
                                }
                                unreadCount = (unreadCount - 1).coerceAtLeast(0)
                                scope.launch {
                                    runCatching {
                                        ApiClient.api.markNotificationRead(notification.idStr)
                                    }
                                }
                            }
                        },
                    )
                }
            }
        }
    }
}

@Composable
private fun NotificationRow(notification: NotificationDto, onClick: () -> Unit) {
    val unread = notification.isRead != true
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .background(if (unread) LyoPurple.copy(alpha = 0.08f) else Color.Transparent)
            .clickable(onClick = onClick),
    ) {
        // Left unread accent bar.
        Box(
            modifier = Modifier
                .width(3.dp)
                .fillMaxHeight()
                .background(if (unread) LyoPurple else Color.Transparent),
        )

        Box(modifier = Modifier.padding(start = 13.dp, top = 12.dp, bottom = 12.dp)) {
            LyoAvatar(
                name = notification.actorDisplayName ?: "LYO",
                avatarUrl = notification.actorAvatarUrl,
                size = 44,
            )
            // Small type indicator dot overlaying the avatar corner.
            Box(
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(Background)
                    .padding(2.dp)
                    .clip(CircleShape)
                    .background(dotColorFor(notification.type)),
            )
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp, vertical = 12.dp),
        ) {
            Text(
                text = notification.body ?: notification.title ?: "Notification",
                style = MaterialTheme.typography.bodyMedium,
                fontWeight = if (unread) FontWeight.SemiBold else FontWeight.Normal,
                color = TextPrimary,
                maxLines = 3,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = formatTimeAgo(notification.createdAt),
                style = MaterialTheme.typography.labelMedium,
                color = TextSecondary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}
