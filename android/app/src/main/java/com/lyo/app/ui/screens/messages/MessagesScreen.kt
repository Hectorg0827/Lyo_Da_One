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
import androidx.compose.material3.CircularProgressIndicator
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
import java.io.IOException
import kotlin.math.max
import kotlinx.coroutines.launch
import retrofit2.HttpException

private fun otherParticipant(conversation: ConversationDto): ParticipantDto? {
    val myId = Session.user?.id
    return conversation.participants?.firstOrNull { it.idStr != myId }
        ?: conversation.participants?.firstOrNull()
}

private fun conversationTitle(conversation: ConversationDto): String =
    conversation.name ?: otherParticipant(conversation)?.name ?: "Conversation"

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MessagesScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()

    var conversations by remember { mutableStateOf<List<ConversationDto>>(emptyList()) }
    var conversationsLoading by remember { mutableStateOf(true) }
    var conversationsLoaded by remember { mutableStateOf(false) }
    var conversationError by remember { mutableStateOf<String?>(null) }
    var conversationReload by remember { mutableStateOf(0) }
    var search by remember { mutableStateOf("") }
    var activeConversation by remember { mutableStateOf<ConversationDto?>(null) }

    var messages by remember { mutableStateOf<List<MessageDto>>(emptyList()) }
    var messagesLoading by remember { mutableStateOf(false) }
    var messagesLoaded by remember { mutableStateOf(false) }
    var messagesError by remember { mutableStateOf<String?>(null) }
    var messagesReload by remember { mutableStateOf(0) }
    var draft by remember { mutableStateOf("") }
    var sending by remember { mutableStateOf(false) }
    var sendError by remember { mutableStateOf<String?>(null) }
    val listState = rememberLazyListState()

    LaunchedEffect(conversationReload) {
        conversationsLoading = true
        conversationsLoaded = false
        conversationError = null
        runCatching { ApiClient.api.conversations() }
            .onSuccess {
                conversations = it.conversations.orEmpty()
                conversationsLoaded = true
            }
            .onFailure {
                conversationError = messagingError(it, "load conversations")
                conversationsLoaded = true
            }
        conversationsLoading = false
    }

    LaunchedEffect(Unit) {
        SyncClient.events.collect { event ->
            if (event.eventType in setOf("message_sent", "message_received", "context_updated")) {
                runCatching { ApiClient.api.conversations() }
                    .onSuccess {
                        conversations = it.conversations.orEmpty()
                        conversationError = null
                    }
                    .onFailure {
                        if (conversations.isEmpty()) {
                            conversationError = messagingError(it, "refresh conversations")
                        }
                    }

                activeConversation?.let { conversation ->
                    runCatching { ApiClient.api.messages(conversation.idStr) }
                        .onSuccess {
                            messages = it.messages.orEmpty()
                            messagesError = null
                            messagesLoaded = true
                        }
                        .onFailure {
                            if (messages.isEmpty()) {
                                messagesError = messagingError(it, "refresh messages")
                            }
                        }
                }
            }
        }
    }

    LaunchedEffect(activeConversation?.idStr, messagesReload) {
        val conversation = activeConversation ?: return@LaunchedEffect
        messagesLoading = true
        messagesLoaded = false
        messagesError = null
        sendError = null
        messages = emptyList()
        runCatching { ApiClient.api.messages(conversation.idStr) }
            .onSuccess {
                messages = it.messages.orEmpty()
                messagesLoaded = true
            }
            .onFailure {
                messagesError = messagingError(it, "load messages")
                messagesLoaded = true
            }
        messagesLoading = false
    }

    LaunchedEffect(messages.size) {
        if (messages.isNotEmpty()) {
            listState.animateScrollToItem(max(0, messages.size - 1))
        }
    }

    BackHandler(enabled = activeConversation != null) {
        activeConversation = null
        messages = emptyList()
        messagesError = null
        sendError = null
        draft = ""
    }

    val conversation = activeConversation
    if (conversation == null) {
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
                conversationsLoading -> LoadingBox()
                conversationError != null && conversations.isEmpty() -> MessageRequestError(
                    title = "Messages unavailable",
                    message = conversationError ?: "Conversations could not be loaded.",
                    onRetry = { conversationReload += 1 },
                    modifier = Modifier.fillMaxSize(),
                )
                conversationsLoaded && conversations.isEmpty() -> EmptyState(
                    title = "No messages yet",
                    subtitle = "Start a conversation from a user's profile.",
                )
                else -> {
                    conversationError?.let { message ->
                        MessageRequestError(
                            title = "Refresh failed",
                            message = message,
                            onRetry = { conversationReload += 1 },
                            modifier = Modifier.padding(horizontal = 16.dp, vertical = 4.dp),
                        )
                    }

                    val filtered = conversations.filter {
                        search.isBlank() || conversationTitle(it).contains(search, ignoreCase = true)
                    }
                    if (filtered.isEmpty()) {
                        EmptyState(
                            title = "No matching conversations",
                            subtitle = "Try a different name.",
                        )
                    } else {
                        LazyColumn(modifier = Modifier.fillMaxSize()) {
                            items(filtered) { item ->
                                ConversationRow(
                                    conversation = item,
                                    onClick = {
                                        activeConversation = item
                                        scope.launch {
                                            runCatching {
                                                ApiClient.api.markConversationRead(item.idStr)
                                            }
                                        }
                                    },
                                )
                            }
                        }
                    }
                }
            }
        }
    } else {
        val other = otherParticipant(conversation)
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
                IconButton(
                    onClick = {
                        activeConversation = null
                        messages = emptyList()
                        messagesError = null
                        sendError = null
                        draft = ""
                    },
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "Back",
                        tint = TextPrimary,
                    )
                }
                LyoAvatar(
                    name = conversationTitle(conversation),
                    avatarUrl = other?.avatarUrl,
                    size = 36,
                )
                Text(
                    text = conversationTitle(conversation),
                    style = MaterialTheme.typography.titleMedium,
                    color = TextPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    modifier = Modifier.padding(start = 10.dp),
                )
            }

            Box(
                modifier = Modifier
                    .weight(1f)
                    .fillMaxWidth(),
            ) {
                when {
                    messagesLoading -> LoadingBox()
                    messagesError != null && messages.isEmpty() -> MessageRequestError(
                        title = "Conversation unavailable",
                        message = messagesError ?: "Messages could not be loaded.",
                        onRetry = { messagesReload += 1 },
                        modifier = Modifier.fillMaxSize(),
                    )
                    messagesLoaded && messages.isEmpty() -> EmptyState(
                        title = "No messages yet",
                        subtitle = "Send the first message in this conversation.",
                    )
                    else -> LazyColumn(
                        state = listState,
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                        contentPadding = PaddingValues(16.dp),
                        modifier = Modifier.fillMaxSize(),
                    ) {
                        items(messages, key = { message ->
                            message.idStr.ifBlank {
                                "${message.senderIdStr}:${message.createdAt}:${message.content}"
                            }
                        }) { message ->
                            DirectMessageBubble(message)
                        }
                    }
                }
            }

            sendError?.let { message ->
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodySmall,
                    color = Color(0xFFFF7B7B),
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Surface)
                        .padding(horizontal = 16.dp, vertical = 6.dp),
                )
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
                    onValueChange = {
                        draft = it
                        if (sendError != null) sendError = null
                    },
                    placeholder = { Text("Message…", color = TextSecondary) },
                    shape = RoundedCornerShape(24.dp),
                    maxLines = 4,
                    enabled = !sending,
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
                        if (text.isEmpty() || sending) return@IconButton

                        scope.launch {
                            sending = true
                            sendError = null
                            runCatching {
                                ApiClient.api.sendMessage(
                                    conversation.idStr,
                                    SendMessageRequest(text),
                                )
                            }.onSuccess { sentMessage ->
                                messages = (messages + sentMessage).distinctBy { message ->
                                    message.idStr.ifBlank {
                                        "${message.senderIdStr}:${message.createdAt}:${message.content}"
                                    }
                                }
                                messagesLoaded = true
                                draft = ""
                                runCatching { ApiClient.api.conversations() }
                                    .onSuccess { conversations = it.conversations.orEmpty() }
                            }.onFailure {
                                sendError = messagingError(it, "send message")
                            }
                            sending = false
                        }
                    },
                    enabled = draft.isNotBlank() && !sending,
                    modifier = Modifier
                        .padding(start = 8.dp)
                        .size(48.dp)
                        .clip(CircleShape)
                        .background(LyoPurple),
                ) {
                    if (sending) {
                        CircularProgressIndicator(
                            color = Color.White,
                            strokeWidth = 2.dp,
                            modifier = Modifier.size(20.dp),
                        )
                    } else {
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
}

private fun messagingError(error: Throwable, operation: String): String = when (error) {
    is HttpException -> when (error.code()) {
        401, 403 -> "Your session cannot $operation. Sign in again and retry."
        404 -> "The requested conversation is no longer available."
        409 -> "The conversation changed on another device. Refresh and retry."
        else -> "Unable to $operation (${error.code()})."
    }
    is IOException -> "Check your connection and try to $operation again."
    else -> error.localizedMessage ?: "Unable to $operation."
}

@Composable
private fun MessageRequestError(
    title: String,
    message: String,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = modifier.padding(20.dp),
    ) {
        Text(title, style = MaterialTheme.typography.titleMedium, color = TextPrimary)
        Text(
            message,
            style = MaterialTheme.typography.bodySmall,
            color = TextSecondary,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text(
            "Retry",
            style = MaterialTheme.typography.titleSmall,
            color = LyoPurple,
            modifier = Modifier
                .padding(top = 10.dp)
                .clickable(onClick = onRetry)
                .padding(6.dp),
        )
    }
}

@Composable
private fun ConversationRow(
    conversation: ConversationDto,
    onClick: () -> Unit,
) {
    val other = otherParticipant(conversation)
    val unread = conversation.unreadCount ?: 0
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 12.dp),
    ) {
        LyoAvatar(
            name = conversationTitle(conversation),
            avatarUrl = other?.avatarUrl,
            size = 48,
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp),
        ) {
            Text(
                text = conversationTitle(conversation),
                style = MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Text(
                text = conversation.lastMessage?.content ?: "No messages yet",
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Column(horizontalAlignment = Alignment.End) {
            Text(
                text = formatTimeAgo(conversation.updatedAt),
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
private fun DirectMessageBubble(message: MessageDto) {
    val isMine = message.senderIdStr == (Session.user?.id ?: "")
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
                text = message.content ?: "",
                style = MaterialTheme.typography.bodyLarge,
                color = if (isMine) Color.White else TextPrimary,
            )
        }
    }
}