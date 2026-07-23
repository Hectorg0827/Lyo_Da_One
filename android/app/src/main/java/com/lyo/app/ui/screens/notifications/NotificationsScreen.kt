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
import androidx.compose.material3.CircularProgressIndicator
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
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoAmber
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.io.IOException
import kotlinx.coroutines.launch
import retrofit2.HttpException

private val SystemTypes = setOf("system", "achievement", "course_complete", "event_reminder")
private val Filters = listOf("All", "Mentions", "Likes", "Comments", "System")

private fun matchesFilter(notification: NotificationDto, filter: String): Boolean {
    val type = notification.type ?: ""
    return when (filter) {
        "Mentions" -> type == "mention"
        "Likes" -> type == "like"
        "Comments" -> type == "comment" || type == "reply"
        "System" -> type in SystemTypes
        else -> true
    }
}

private fun dotColorFor(type: String?): Color = when (type) {
    "like" -> LyoRed
    "comment", "reply" -> LyoPurple
    "follow" -> LyoGreen
    "achievement" -> LyoAmber
    else -> TextSecondary
}

private fun supportedNotificationRoute(notification: NotificationDto): String? {
    val targetId = notification.targetId?.takeIf { it.isNotBlank() } ?: return null
    return when (notification.targetType?.lowercase()) {
        "post" -> Routes.postDetail(targetId)
        "user", "profile" -> Routes.userProfile(targetId)
        "course" -> Routes.courseDetail(targetId)
        else -> null
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun NotificationsScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()

    var notifications by remember { mutableStateOf<List<NotificationDto>>(emptyList()) }
    var unreadCount by remember { mutableIntStateOf(0) }
    var loading by remember { mutableStateOf(true) }
    var loaded by remember { mutableStateOf(false) }
    var loadError by remember { mutableStateOf<String?>(null) }
    var actionError by remember { mutableStateOf<String?>(null) }
    var pendingNotificationId by remember { mutableStateOf<String?>(null) }
    var markingAllRead by remember { mutableStateOf(false) }
    var filter by remember { mutableStateOf("All") }
    var reloadVersion by remember { mutableIntStateOf(0) }

    suspend fun refetch(preserveVisibleData: Boolean) {
        if (!preserveVisibleData || notifications.isEmpty()) loading = true
        loadError = null
        runCatching { ApiClient.api.notifications(1, 50) }
            .onSuccess { response ->
                notifications = response.notifications.orEmpty()
                unreadCount = response.unreadCount
                    ?: response.notifications.orEmpty().count { it.isRead != true }
                loaded = true
            }
            .onFailure { error ->
                loadError = notificationError(error, "load notifications")
                loaded = true
            }
        loading = false
    }

    fun openSupportedTarget(notification: NotificationDto) {
        supportedNotificationRoute(notification)?.let { route ->
            nav.navigate(route)
        }
    }

    fun handleNotificationTap(notification: NotificationDto) {
        if (pendingNotificationId != null) return
        if (notification.isRead == true) {
            openSupportedTarget(notification)
            return
        }

        val notificationId = notification.idStr
        if (notificationId.isBlank()) {
            actionError = "This notification does not have a persistent identifier."
            return
        }

        pendingNotificationId = notificationId
        actionError = null
        scope.launch {
            runCatching { ApiClient.api.markNotificationRead(notificationId) }
                .onSuccess {
                    notifications = notifications.map { item ->
                        if (item.idStr == notificationId) item.copy(isRead = true) else item
                    }
                    unreadCount = (unreadCount - 1).coerceAtLeast(0)
                    openSupportedTarget(notification)
                }
                .onFailure { error ->
                    actionError = notificationError(error, "mark the notification read")
                }
            pendingNotificationId = null
        }
    }

    LaunchedEffect(reloadVersion) {
        refetch(preserveVisibleData = false)
    }

    LaunchedEffect(Unit) {
        SyncClient.events.collect { event ->
            if (event.eventType in setOf("context_updated", "message_received")) {
                refetch(preserveVisibleData = true)
            }
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
                        enabled = !markingAllRead && pendingNotificationId == null,
                        onClick = {
                            scope.launch {
                                markingAllRead = true
                                actionError = null
                                runCatching { ApiClient.api.markAllNotificationsRead() }
                                    .onSuccess {
                                        notifications = notifications.map { it.copy(isRead = true) }
                                        unreadCount = 0
                                    }
                                    .onFailure { error ->
                                        actionError = notificationError(error, "mark all notifications read")
                                    }
                                markingAllRead = false
                            }
                        },
                    ) {
                        if (markingAllRead) {
                            CircularProgressIndicator(
                                color = LyoPurple,
                                strokeWidth = 2.dp,
                                modifier = Modifier.size(16.dp),
                            )
                        } else {
                            Text(
                                text = "Mark all read",
                                style = MaterialTheme.typography.labelLarge,
                                color = LyoPurple,
                            )
                        }
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
            Filters.forEach { item ->
                FilterChip(
                    selected = filter == item,
                    onClick = { filter = item },
                    label = { Text(item) },
                    colors = FilterChipDefaults.filterChipColors(
                        containerColor = Surface,
                        labelColor = TextSecondary,
                        selectedContainerColor = LyoPurple.copy(alpha = 0.2f),
                        selectedLabelColor = LyoPurple,
                    ),
                )
            }
        }

        actionError?.let { message ->
            NotificationErrorCard(
                title = "Notification action failed",
                message = message,
                actionLabel = "Dismiss",
                onAction = { actionError = null },
                modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
            )
        }

        val visible = notifications.filter { matchesFilter(it, filter) }
        when {
            loading && notifications.isEmpty() -> LoadingBox()
            loadError != null && notifications.isEmpty() -> NotificationErrorCard(
                title = "Notifications unavailable",
                message = loadError ?: "Notifications could not be loaded.",
                actionLabel = "Retry",
                onAction = { reloadVersion += 1 },
                modifier = Modifier.fillMaxSize(),
            )
            loaded && visible.isEmpty() -> EmptyState(
                title = if (filter == "All") "No notifications" else "No $filter notifications",
                subtitle = if (filter == "All") {
                    "New account activity will appear here."
                } else {
                    "Try another filter."
                },
            )
            else -> LazyColumn(modifier = Modifier.fillMaxSize()) {
                loadError?.let { message ->
                    item {
                        NotificationErrorCard(
                            title = "Refresh failed",
                            message = message,
                            actionLabel = "Retry",
                            onAction = { reloadVersion += 1 },
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 6.dp),
                        )
                    }
                }

                items(visible, key = { notification -> notification.idStr }) { notification ->
                    NotificationRow(
                        notification = notification,
                        pending = pendingNotificationId == notification.idStr,
                        onClick = { handleNotificationTap(notification) },
                    )
                }
            }
        }
    }
}

private fun notificationError(error: Throwable, operation: String): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "Your session cannot $operation. Sign in again and retry."
        404 -> "The notification is no longer available."
        409 -> "Notification state changed on another device. Refresh and retry."
        else -> "Unable to $operation (${error.code()})."
    }
    is IOException -> "Check your connection and try to $operation again."
    else -> error.localizedMessage ?: "Unable to $operation."
}

@Composable
private fun NotificationErrorCard(
    title: String,
    message: String,
    actionLabel: String,
    onAction: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier.padding(16.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, color = TextPrimary)
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = TextSecondary,
            modifier = Modifier.padding(top = 5.dp),
        )
        Text(
            actionLabel,
            style = MaterialTheme.typography.titleSmall,
            color = LyoPurple,
            modifier = Modifier
                .padding(top = 8.dp)
                .clickable(onClick = onAction)
                .padding(6.dp),
        )
    }
}

@Composable
private fun NotificationRow(
    notification: NotificationDto,
    pending: Boolean,
    onClick: () -> Unit,
) {
    val unread = notification.isRead != true
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .height(IntrinsicSize.Min)
            .background(if (unread) LyoPurple.copy(alpha = 0.08f) else Color.Transparent)
            .clickable(enabled = !pending, onClick = onClick),
    ) {
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

        if (pending) {
            CircularProgressIndicator(
                color = LyoPurple,
                strokeWidth = 2.dp,
                modifier = Modifier
                    .padding(end = 16.dp)
                    .size(18.dp),
            )
        }
    }
}