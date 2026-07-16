package com.lyo.app.ui.screens.messages

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.Send
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.Session
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ConversationDto
import com.lyo.app.data.api.MessageDto
import com.lyo.app.data.api.ParticipantDto
import com.lyo.app.data.api.SendMessageRequest
import com.lyo.app.data.sync.SyncClient
import com.lyo.app.ui.components.EmptyState
import com.lyo.app.ui.components.LoadingBox
import com.lyo.app.ui.components.LyoAvatar
import com.lyo.app.ui.components.formatTimeAgo
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlin.math.max
import kotlinx.coroutines.launch

/** The participant to show for a conversation (not the signed-in user). */
private fun otherParticipant(conv: ConversationDto): ParticipantDto? {
    val myId = Session.user?.id
    return conv.participants?.firstOrNull { it.idStr != myId }
        ?: conv.participants?.firstOrNull()
}

private fun conversationTitle(conv: ConversationDto): String =
    conv.name ?: otherParticipant(conv)?.name ?: "Conversation"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MessagesScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()

    var conversations by remember { mutableStateOf<List<ConversationDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var search by remember { mutableStateOf("") }
    var activeConv by remember { mutableStateOf<ConversationDto?>(null) }

    var messages by remember { mutableStateOf<List<MessageDto>>(emptyList()) }
    var messagesLoading by remember { mutableStateOf(false) }
    var draft by remember { mutableStateOf("") }
    val listState = rememberLazyListState()

    LaunchedEffect(Unit) {
        runCatching { ApiClient.api.conversations() }
            .onSuccess { conversations = it.conversations.orEmpty() }
        loading = false
    }

    // Live cross-device sync: when this account sends/receives a message on
    // another platform (iOS/web), refresh without leaving the screen.
    LaunchedEffect(Unit) {
        SyncClient.events.collect { event ->
            if (event.eventType in setOf("message_sent", "message_received", "context_updated")) {
                runCatching { ApiClient.api.conversations() }
                    .onSuccess { conversations = it.conversations.orEmpty() }
                activeConv?.let { conv ->
                    runCatching { ApiClient.api.messages(conv.idStr) }
                        .onSuccess { messages = it.messages.orEmpty() }
                }
            }
        }
    }

    LaunchedEffect(activeConv) {
        val conv = activeConv ?: return@LaunchedEffect
        messagesLoading = true
        messages = emptyList()
        runCatching { ApiClient.api.messages(conv.idStr) }
            .onSuccess { messages = it.messages.orEmpty() }
        messagesLoading = false
    }

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(max(0, messages.size - 1))
        }
    }

    BackHandler(enabled = activeConv != null) { activeConv = null }

    val conv = activeConv
    if (conv == null) {
        // ── Conversation list mode ──
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Background),
        ) {
            TopAppBar(
                title = { Text("Messages", style = MaterialTheme.typography.headlineSmall) },
                navigationIcon = {
                    IconButton(onClick = { nav.popBackStack() }) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = TextPrimary,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = Background,
                    titleContentColor = TextPrimary,
                ),
            )

            OutlinedTextField(
                value = search,
                onValueChange = { search = it },
                placeholder = { Text("Search conversations", color = TextSecondary) },
                leadingIcon = {
                    Icon(Icons.Filled.Search, contentDescription = null, tint = TextSecondary)
                },
                singleLine = true,
                shape = RoundedCornerShape(14.dp),
                colors = OutlinedTextFieldDefaults.colors(
                    focusedBorderColor = LyoPurple,
                    unfocusedBorderColor = BorderColor,
                    focusedTextColor = TextPrimary,
                    unfocusedTextColor = TextPrimary,
                    cursorColor = LyoPurple,
                ),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            )

            when {
                loading -> LoadingBox()
                conversations.isEmpty() -> EmptyState(
                    title = "No messages yet",
                    subtitle = "Start a conversation from a user's profile",
                )
                else -> {
                    val filtered = conversations.filter {
                        search.isBlank() ||
                            conversationTitle(it).contains(search, ignoreCase = true)
                    }
                    LazyColumn(modifier = Modifier.fillMaxSize()) {
                        items(filtered) { c ->
                            ConversationRow(
                                conv = c,
                                onClick = {
                                    activeConv = c
                                    scope.launch {
                                        runCatching {
                                            ApiClient.api.markConversationRead(c.idStr)
                                        }
                                    }
                                },
                            )
                        }
                    }
                }
            }
        }
    } else {
        // ── Chat mode ──
        val other = otherParticipant(conv)
        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(Background)
                .imePadding(),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Surface)
                    .padding(horizontal = 8.dp, vertical = 10.dp),
            ) {
                IconButton(onClick = { activeConv = null }) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = TextPrimary,
                    )
                }
                LyoAvatar(
                    name = conversationTitle(conv),
                    avatarUrl = other?.avatarUrl,
                    size = 36,
                )
                Text(
                    text = conversationTitle(conv),
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(start = 10.dp),
                )
            }

            if (messagesLoading) {
                Box(modifier = Modifier.weight(1f)) { LoadingBox() }
            } else {
                LazyColumn(
                    state = listState,
                    verticalArrangement = Arrangement.spacedBy(6.dp),
                    contentPadding = PaddingValues(16.dp),
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                ) {
                    items(messages) { msg ->
                        DirectMessageBubble(msg)
                    }
                }
            }

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(Surface)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            ) {
                OutlinedTextField(
                    value = draft,
                    onValueChange = { draft = it },
                    placeholder = { Text("Message…", color = TextSecondary) },
                    shape = RoundedCornerShape(24.dp),
                    maxLines = 4,
                    colors = OutlinedTextFieldDefaults.colors(
                        focusedBorderColor = LyoPurple,
                        unfocusedBorderColor = BorderColor,
                        focusedTextColor = TextPrimary,
                        unfocusedTextColor = TextPrimary,
                        cursorColor = LyoPurple,
                    ),
                    modifier = Modifier.weight(1f),
                )
                IconButton(
                    onClick = {
                        val text = draft.trim()
                        if (text.isEmpty()) return@IconButton
                        draft = ""
                        scope.launch {
                            runCatching {
                                ApiClient.api.sendMessage(conv.idStr, SendMessageRequest(text))
                            }
                            runCatching { ApiClient.api.messages(conv.idStr) }
                                .onSuccess { messages = it.messages.orEmpty() }
                        }
                    },
                    enabled = draft.isNotBlank(),
                    modifier = Modifier
                        .padding(start = 8.dp)
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(LyoPurple),
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.Send,
                        contentDescription = "Send",
                        tint = Color.White,
                    )
                }
            }
        }
    }
}

@Composable
private fun ConversationRow(conv: ConversationDto, onClick: () -> Unit) {
    val other = otherParticipant(conv)
    val unread = conv.unreadCount ?: 0
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        LyoAvatar(
            name = conversationTitle(conv),
            avatarUrl = other?.avatarUrl,
            size = 48,
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp),
        ) {
            Text(
                text = conversationTitle(conv),
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = conv.lastMessage?.content ?: "No messages yet",
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = formatTimeAgo(conv.updatedAt),
                style = MaterialTheme.typography.labelMedium,
                color = TextSecondary,
            )
            if (unread > 0) {
                Box(
                    contentAlignment = Alignment.Center,
                    modifier = Modifier
                        .padding(top = 4.dp)
                        .size(20.dp)
                        .clip(CircleShape)
                        .background(LyoPurple),
                ) {
                    Text(
                        text = if (unread > 9) "9+" else unread.toString(),
                        style = MaterialTheme.typography.labelSmall,
                        color = Color.White,
                    )
                }
            }
        }
    }
}

@Composable
private fun DirectMessageBubble(msg: MessageDto) {
    val isMine = msg.senderIdStr == (Session.user?.id ?: "")
    Row(
        horizontalArrangement = if (isMine) Arrangement.End else Arrangement.Start,
        modifier = Modifier.fillMaxWidth(),
    ) {
        val shape = RoundedCornerShape(
            topStart = 16.dp,
            topEnd = 16.dp,
            bottomStart = if (isMine) 16.dp else 4.dp,
            bottomEnd = if (isMine) 4.dp else 16.dp,
        )
        Box(
            modifier = Modifier
                .widthIn(max = 280.dp)
                .clip(shape)
                .background(if (isMine) LyoPurple else Surface)
                .then(if (isMine) Modifier else Modifier.border(1.dp, BorderColor, shape))
                .padding(horizontal = 12.dp, vertical = 8.dp),
        ) {
            Text(
                text = msg.content ?: "",
                style = MaterialTheme.typography.bodyLarge,
                color = if (isMine) Color.White else TextPrimary,
            )
        }
    }
}
