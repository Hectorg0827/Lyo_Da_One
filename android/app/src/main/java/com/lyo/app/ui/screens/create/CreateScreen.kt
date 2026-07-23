package com.lyo.app.ui.screens.create

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Groups
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.People
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.SmartToy
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.ClipCreateRequest
import com.lyo.app.data.api.CommunityCreatePostRequest
import com.lyo.app.data.api.CreateCommunityEventRequest
import com.lyo.app.data.api.CreateStudyGroupRequest
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.Background
import com.lyo.app.ui.theme.LyoBlue
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPink
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.MultipartBody
import okhttp3.RequestBody.Companion.toRequestBody

private enum class CreateDialog {
    POST,
    EVENT,
    GROUP,
}

@Composable
fun CreateScreen(nav: NavHostController) {
    var dialog by remember { mutableStateOf<CreateDialog?>(null) }
    var pendingVideoUri by remember { mutableStateOf<Uri?>(null) }
    var statusMessage by remember { mutableStateOf<String?>(null) }

    val videoPicker = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        if (uri != null) pendingVideoUri = uri
    }

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(Background),
        contentPadding = PaddingValues(horizontal = 16.dp, vertical = 18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item {
            Text(
                text = "Create",
                style = MaterialTheme.typography.headlineLarge,
                color = TextPrimary,
            )
            Text(
                text = "Publish learning content and bring people together.",
                style = MaterialTheme.typography.bodyMedium,
                color = TextSecondary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }

        statusMessage?.let { message ->
            item {
                Text(
                    text = message,
                    style = MaterialTheme.typography.bodyMedium,
                    color = LyoGreen,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(LyoGreen.copy(alpha = 0.12f), RoundedCornerShape(12.dp))
                        .padding(12.dp),
                )
            }
        }

        item {
            CreateActionCard(
                icon = Icons.Filled.PlayCircle,
                title = "Create a clip",
                description = "Choose a video, upload it, and publish it to Clips.",
                accent = LyoPink,
                onClick = {
                    statusMessage = null
                    videoPicker.launch("video/*")
                },
            )
        }

        item {
            CreateActionCard(
                icon = Icons.Filled.People,
                title = "Community post",
                description = "Share a post, question, or study tip with the community.",
                accent = LyoBlue,
                onClick = {
                    statusMessage = null
                    dialog = CreateDialog.POST
                },
            )
        }

        item {
            Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
                CreateActionCard(
                    icon = Icons.Filled.Groups,
                    title = "Study group",
                    description = "Create a public or private learning group.",
                    accent = LyoGreen,
                    compact = true,
                    modifier = Modifier.weight(1f),
                    onClick = {
                        statusMessage = null
                        dialog = CreateDialog.GROUP
                    },
                )
                CreateActionCard(
                    icon = Icons.Filled.People,
                    title = "Event",
                    description = "Schedule an online or in-person learning event.",
                    accent = LyoPurple,
                    compact = true,
                    modifier = Modifier.weight(1f),
                    onClick = {
                        statusMessage = null
                        dialog = CreateDialog.EVENT
                    },
                )
            }
        }

        item {
            CreateActionCard(
                icon = Icons.Filled.MenuBook,
                title = "Generate an AI course",
                description = "Choose a topic and difficulty, then start a real course-generation request.",
                accent = LyoPurple,
                onClick = { nav.navigate(Routes.COURSES) },
            )
        }

        item {
            Spacer(Modifier.height(4.dp))
            GlassCard(
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { nav.navigate(Routes.CHAT) },
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.padding(16.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.SmartToy,
                        contentDescription = null,
                        tint = LyoPurple,
                        modifier = Modifier.size(26.dp),
                    )
                    Column(modifier = Modifier.padding(start = 12.dp)) {
                        Text(
                            text = "Need help deciding?",
                            style = MaterialTheme.typography.titleMedium,
                            color = TextPrimary,
                        )
                        Text(
                            text = "Ask Lyo to plan the content before you publish.",
                            style = MaterialTheme.typography.bodySmall,
                            color = TextSecondary,
                            modifier = Modifier.padding(top = 2.dp),
                        )
                    }
                }
            }
        }
    }

    when (dialog) {
        CreateDialog.POST -> CreatePostDialog(
            onDismiss = { dialog = null },
            onCreated = {
                dialog = null
                statusMessage = "Community post published."
            },
        )
        CreateDialog.EVENT -> CreateEventOrGroupDialog(
            groupMode = false,
            onDismiss = { dialog = null },
            onCreated = {
                dialog = null
                statusMessage = "Community event created."
            },
        )
        CreateDialog.GROUP -> CreateEventOrGroupDialog(
            groupMode = true,
            onDismiss = { dialog = null },
            onCreated = {
                dialog = null
                statusMessage = "Study group created."
            },
        )
        null -> Unit
    }

    pendingVideoUri?.let { uri ->
        PublishClipDialog(
            videoUri = uri,
            onDismiss = { pendingVideoUri = null },
            onPublished = {
                pendingVideoUri = null
                statusMessage = "Clip published."
            },
        )
    }
}

@Composable
private fun CreateActionCard(
    icon: ImageVector,
    title: String,
    description: String,
    accent: Color,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    GlassCard(modifier = modifier.clickable(onClick = onClick)) {
        Column(modifier = Modifier.padding(if (compact) 14.dp else 18.dp)) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = accent,
                modifier = Modifier.size(if (compact) 24.dp else 30.dp),
            )
            Text(
                text = title,
                style = if (compact) MaterialTheme.typography.titleSmall else MaterialTheme.typography.titleMedium,
                color = TextPrimary,
                modifier = Modifier.padding(top = 10.dp),
            )
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun CreatePostDialog(onDismiss: () -> Unit, onCreated: () -> Unit) {
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
                        tags = tags.split(',')
                            .map { it.trim().removePrefix("#") }
                            .filter { it.isNotEmpty() }
                            .ifEmpty { null },
                        postType = postType,
                    ),
                )
            }.onSuccess {
                onCreated()
            }.onFailure {
                error = it.localizedMessage ?: "Unable to create the post."
            }
            submitting = false
        }
    }

    AlertDialog(
        onDismissRequest = { if (!submitting) onDismiss() },
        title = { Text("Create community post") },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(
                        "text" to "Post",
                        "question_discussion" to "Question",
                        "study_tip" to "Study tip",
                    ).forEach { option ->
                        FilterChip(
                            selected = postType == option.first,
                            onClick = { postType = option.first },
                            label = { Text(option.second) },
                        )
                    }
                }
                OutlinedTextField(
                    value = content,
                    onValueChange = { content = it },
                    label = { Text("Content") },
                    minLines = 4,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = tags,
                    onValueChange = { tags = it },
                    label = { Text("Tags, comma separated") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                error?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            TextButton(onClick = ::submit, enabled = content.isNotBlank() && !submitting) {
                Text(if (submitting) "Publishing…" else "Publish")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancel") }
        },
    )
}

@Composable
private fun CreateEventOrGroupDialog(
    groupMode: Boolean,
    onDismiss: () -> Unit,
    onCreated: () -> Unit,
) {
    var title by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    var location by remember { mutableStateOf("") }
    val formatter = remember { DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm") }
    var starts by remember {
        mutableStateOf(LocalDateTime.now().plusDays(1).withSecond(0).withNano(0).format(formatter))
    }
    var ends by remember {
        mutableStateOf(LocalDateTime.now().plusDays(1).plusHours(1).withSecond(0).withNano(0).format(formatter))
    }
    var maximum by remember { mutableStateOf("20") }
    var privateGroup by remember { mutableStateOf(false) }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()

    fun submit() {
        if (title.isBlank() || submitting) return
        submitting = true
        error = null
        scope.launch {
            runCatching {
                if (groupMode) {
                    ApiClient.api.createStudyGroup(
                        CreateStudyGroupRequest(
                            name = title.trim(),
                            description = description.trim().ifEmpty { null },
                            privacy = if (privateGroup) "private" else "public",
                            maxMembers = maximum.toIntOrNull()?.coerceIn(2, 1_000) ?: 20,
                            requiresApproval = privateGroup,
                        ),
                    )
                } else {
                    val zone = ZoneId.systemDefault()
                    val startInstant = LocalDateTime.parse(starts, formatter).atZone(zone).toInstant()
                    val endInstant = LocalDateTime.parse(ends, formatter).atZone(zone).toInstant()
                    require(endInstant.isAfter(startInstant)) { "The event must end after it starts." }
                    ApiClient.api.createCommunityEvent(
                        CreateCommunityEventRequest(
                            title = title.trim(),
                            description = description.trim().ifEmpty { null },
                            location = location.trim().ifEmpty { "Online" },
                            maxAttendees = maximum.toIntOrNull()?.coerceIn(1, 10_000) ?: 20,
                            startTime = startInstant.toString(),
                            endTime = endInstant.toString(),
                            timezone = zone.id,
                        ),
                    )
                }
            }.onSuccess {
                onCreated()
            }.onFailure {
                error = it.localizedMessage ?: "Unable to create this item."
            }
            submitting = false
        }
    }

    AlertDialog(
        onDismissRequest = { if (!submitting) onDismiss() },
        title = { Text(if (groupMode) "Create study group" else "Create event") },
        text = {
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.fillMaxWidth(),
            ) {
                item {
                    OutlinedTextField(
                        value = title,
                        onValueChange = { title = it },
                        label = { Text(if (groupMode) "Group name" else "Event title") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                item {
                    OutlinedTextField(
                        value = description,
                        onValueChange = { description = it },
                        label = { Text("Description") },
                        minLines = 2,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                if (groupMode) {
                    item {
                        FilterChip(
                            selected = privateGroup,
                            onClick = { privateGroup = !privateGroup },
                            label = {
                                Text(if (privateGroup) "Private — approval required" else "Public group")
                            },
                        )
                    }
                } else {
                    item {
                        OutlinedTextField(
                            value = starts,
                            onValueChange = { starts = it },
                            label = { Text("Starts (yyyy-MM-dd HH:mm)") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    item {
                        OutlinedTextField(
                            value = ends,
                            onValueChange = { ends = it },
                            label = { Text("Ends (yyyy-MM-dd HH:mm)") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                    item {
                        OutlinedTextField(
                            value = location,
                            onValueChange = { location = it },
                            label = { Text("Location or Online") },
                            singleLine = true,
                            modifier = Modifier.fillMaxWidth(),
                        )
                    }
                }
                item {
                    OutlinedTextField(
                        value = maximum,
                        onValueChange = { value -> maximum = value.filter(Char::isDigit) },
                        label = { Text(if (groupMode) "Maximum members" else "Maximum attendees") },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth(),
                    )
                }
                error?.let { message ->
                    item {
                        Text(message, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
        },
        confirmButton = {
            TextButton(onClick = ::submit, enabled = title.isNotBlank() && !submitting) {
                Text(if (submitting) "Creating…" else "Create")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancel") }
        },
    )
}

@Composable
private fun PublishClipDialog(
    videoUri: Uri,
    onDismiss: () -> Unit,
    onPublished: () -> Unit,
) {
    var title by remember { mutableStateOf("") }
    var subject by remember { mutableStateOf("") }
    var submitting by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current

    fun publish() {
        if (title.isBlank() || submitting) return
        submitting = true
        error = null
        scope.launch {
            runCatching {
                val contentType = context.contentResolver.getType(videoUri) ?: "video/mp4"
                val bytes = withContext(Dispatchers.IO) {
                    context.contentResolver.openInputStream(videoUri)?.use { it.readBytes() }
                } ?: throw IllegalStateException("Could not read the selected video.")
                val extension = when (contentType) {
                    "video/quicktime" -> "mov"
                    "video/webm" -> "webm"
                    else -> "mp4"
                }
                val part = MultipartBody.Part.createFormData(
                    "file",
                    "clip.$extension",
                    bytes.toRequestBody(contentType.toMediaType()),
                )
                val uploaded = ApiClient.api.uploadMedia(
                    file = part,
                    folder = "clips".toRequestBody("text/plain".toMediaType()),
                )
                val url = uploaded.url ?: throw IllegalStateException("The video upload did not return a URL.")
                ApiClient.api.createClip(
                    ClipCreateRequest(
                        title = title.trim(),
                        videoUrl = url,
                        subject = subject.trim().ifEmpty { null },
                        tags = subject.trim().lowercase().let {
                            if (it.isBlank()) emptyList() else listOf(it)
                        },
                    ),
                )
            }.onSuccess {
                onPublished()
            }.onFailure {
                error = it.localizedMessage ?: "Unable to publish the clip."
            }
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
                    onValueChange = { title = it },
                    label = { Text("Title") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                OutlinedTextField(
                    value = subject,
                    onValueChange = { subject = it },
                    label = { Text("Subject, optional") },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth(),
                )
                if (submitting) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        CircularProgressIndicator(modifier = Modifier.size(18.dp), strokeWidth = 2.dp)
                        Text("Uploading…", modifier = Modifier.padding(start = 8.dp))
                    }
                }
                error?.let {
                    Text(it, color = MaterialTheme.colorScheme.error, style = MaterialTheme.typography.bodySmall)
                }
            }
        },
        confirmButton = {
            Button(
                onClick = ::publish,
                enabled = title.isNotBlank() && !submitting,
                colors = ButtonDefaults.buttonColors(containerColor = LyoPurple),
            ) {
                Text(if (submitting) "Publishing…" else "Publish")
            }
        },
        dismissButton = {
            TextButton(onClick = onDismiss, enabled = !submitting) { Text("Cancel") }
        },
    )
}
