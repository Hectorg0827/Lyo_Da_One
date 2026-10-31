package com.lyo.app.ui.screens.create

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
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
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.CommunityCreatePostRequest
import com.lyo.app.data.api.CreateStudyGroupRequest
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

private enum class CreateMode(
    val label: String,
    val symbol: String,
    val subtitle: String,
    val accent: Color,
) {
    POST("Post", "✏️", "Share to your feed", Color(0xFF3B82F6)),
    CLIP("Clip", "🎬", "Teach something in a short video", Color(0xFF8B5CF6)),
    COURSE("Course", "📚", "AI-generated course", Color(0xFF10B981)),
    EVENT("Event/Group", "🎉", "Create event or group", Color(0xFFEC4899)),
}

@Composable
fun CreateScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()
    var mode by remember { mutableStateOf(CreateMode.COURSE) }
    var busy by remember { mutableStateOf(false) }
    var error by remember { mutableStateOf<String?>(null) }
    var postContent by remember { mutableStateOf("") }
    var postTags by remember { mutableStateOf("") }
    var courseTopic by remember { mutableStateOf("") }
    var difficulty by remember { mutableStateOf("beginner") }
    var eventKind by remember { mutableStateOf("event") }
    var eventTitle by remember { mutableStateOf("") }
    var eventDescription by remember { mutableStateOf("") }

    fun publishPost() {
        if (postContent.isBlank() || busy) return
        busy = true
        error = null
        scope.launch {
            runCatching {
                ApiClient.api.createCommunityPost(
                    CommunityCreatePostRequest(
                        content = postContent.trim(),
                        tags = postTags.split(",").map { it.trim() }.filter { it.isNotEmpty() },
                    ),
                )
            }.onSuccess {
                nav.navigate(Routes.COMMUNITY) { launchSingleTop = true }
            }.onFailure {
                error = "Couldn't publish that post. Please try again."
            }
            busy = false
        }
    }

    fun createGroup() {
        if (eventTitle.isBlank() || busy) return
        busy = true
        error = null
        scope.launch {
            runCatching {
                ApiClient.api.createStudyGroup(
                    CreateStudyGroupRequest(
                        name = eventTitle.trim(),
                        description = eventDescription.trim().ifBlank { null },
                    ),
                )
            }.onSuccess {
                nav.navigate(Routes.GROUPS) { launchSingleTop = true }
            }.onFailure {
                error = "Couldn't create that group. Please try again."
            }
            busy = false
        }
    }

    val dark = Color(0xFF07080F)
    Column(
        modifier = Modifier.fillMaxSize().background(
            Brush.linearGradient(
                listOf(dark, mode.accent.copy(alpha = 0.34f).compositeOver(dark), dark),
            ),
        ),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 12.dp),
        ) {
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier.size(42.dp).clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.10f))
                    .clickable {
                        if (!nav.popBackStack()) nav.navigate(Routes.HOME)
                    },
            ) {
                Icon(Icons.Default.Close, contentDescription = "Close Create", tint = TextPrimary,
                    modifier = Modifier.size(20.dp))
            }
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.weight(1f),
            ) {
                Text("Create", style = MaterialTheme.typography.titleMedium,
                    fontWeight = FontWeight.Bold, color = TextPrimary)
                Text(mode.subtitle, style = MaterialTheme.typography.labelSmall,
                    color = TextSecondary, textAlign = TextAlign.Center)
            }
            Spacer(Modifier.size(42.dp))
        }

        Column(
            modifier = Modifier.weight(1f).fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 18.dp, vertical = 12.dp),
        ) {
            Column(
                verticalArrangement = Arrangement.spacedBy(15.dp),
                modifier = Modifier.fillMaxWidth()
                    .clip(RoundedCornerShape(24.dp))
                    .background(Color.White.copy(alpha = 0.07f))
                    .border(1.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(24.dp))
                    .padding(20.dp),
            ) {
                when (mode) {
                    CreateMode.CLIP -> {
                        CreateEditorTitle(
                            "Teach something in a short video",
                            "Your clip goes to Discover, where people can watch it, comment, and turn it into a course.",
                        )
                        CreatePrimaryAction("Choose a video", Color.White, Color(0xFF0A0D16), false) {
                            nav.navigate(Routes.CREATE_CLIP)
                        }
                    }
                    CreateMode.POST -> {
                        CreateEditorTitle("Share a useful idea",
                            "Your post will be saved to the shared Community feed.")
                        OutlinedTextField(
                            value = postContent,
                            onValueChange = { postContent = it.take(2000) },
                            placeholder = { Text("What have you been learning?") },
                            minLines = 5,
                            maxLines = 8,
                            colors = createFieldColors(),
                            modifier = Modifier.fillMaxWidth(),
                            shape = RoundedCornerShape(13.dp),
                        )
                        Text("${2000 - postContent.length} characters left",
                            color = TextSecondary, style = MaterialTheme.typography.labelSmall,
                            modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.End)
                        CreateEditorField(postTags, { postTags = it }, "Tags, comma separated")
                        CreatePrimaryAction("Publish Post", mode.accent, Color.White,
                            busy || postContent.isBlank(), ::publishPost)
                        TextButton(onClick = { nav.navigate(Routes.CREATE_POST) }) {
                            Text("Open full post editor", color = TextSecondary)
                        }
                    }
                    CreateMode.COURSE -> {
                        CreateEditorTitle("Build an AI course",
                            "LYO will generate the curriculum through the course-generation service.")
                        CreateEditorField(courseTopic, { courseTopic = it }, "Course topic")
                        Text("Difficulty", color = TextSecondary,
                            fontWeight = FontWeight.SemiBold,
                            style = MaterialTheme.typography.labelMedium)
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("beginner", "intermediate", "advanced").forEach { option ->
                                val selected = difficulty == option
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier.weight(1f)
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(if (selected) Color.White else Color.White.copy(alpha = 0.08f))
                                        .clickable { difficulty = option }
                                        .padding(vertical = 10.dp),
                                ) {
                                    Text(option.replaceFirstChar { it.uppercase() },
                                        color = if (selected) Color.Black else TextSecondary,
                                        style = MaterialTheme.typography.labelSmall,
                                        fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                        Text("This opens a chat with Lyo, who builds the course with you.",
                            style = MaterialTheme.typography.bodySmall, color = TextSecondary)
                        CreatePrimaryAction("Generate Course", mode.accent, Color.White,
                            courseTopic.isBlank()) {
                            nav.currentBackStackEntry?.savedStateHandle?.set(
                                "lyo_chat_seed_prompt",
                                "Create a ${difficulty} course on ${courseTopic.trim()}",
                            )
                            nav.navigate(Routes.CHAT) { launchSingleTop = true }
                        }
                        TextButton(onClick = { nav.navigate(Routes.COURSES) }) {
                            Text("Browse my courses", color = TextSecondary)
                        }
                    }
                    CreateMode.EVENT -> {
                        CreateEditorTitle("Create a learning gathering",
                            "Create a real virtual event or study group in Community.")
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            listOf("event", "group").forEach { option ->
                                val selected = eventKind == option
                                Box(
                                    contentAlignment = Alignment.Center,
                                    modifier = Modifier.weight(1f)
                                        .clip(RoundedCornerShape(10.dp))
                                        .background(if (selected) Color.White else Color.White.copy(alpha = 0.08f))
                                        .clickable { eventKind = option }
                                        .padding(vertical = 10.dp),
                                ) {
                                    Text(if (option == "event") "Event" else "Study Group",
                                        color = if (selected) Color.Black else TextSecondary,
                                        style = MaterialTheme.typography.labelMedium,
                                        fontWeight = FontWeight.SemiBold)
                                }
                            }
                        }
                        if (eventKind == "event") {
                            Text("Set the time and location in the full event editor.",
                                color = TextSecondary, style = MaterialTheme.typography.bodySmall)
                            CreatePrimaryAction("Continue to event details", mode.accent,
                                Color.White, false) { nav.navigate(Routes.CREATE_EVENT) }
                        } else {
                            CreateEditorField(eventTitle, { eventTitle = it }, "Group name")
                            OutlinedTextField(
                                value = eventDescription, onValueChange = { eventDescription = it },
                                placeholder = { Text("Description") },
                                minLines = 3, maxLines = 5,
                                colors = createFieldColors(),
                                modifier = Modifier.fillMaxWidth(),
                                shape = RoundedCornerShape(13.dp),
                            )
                            CreatePrimaryAction("Create Study Group", mode.accent, Color.White,
                                busy || eventTitle.isBlank(), ::createGroup)
                            TextButton(onClick = { nav.navigate(Routes.CREATE_GROUP) }) {
                                Text("Advanced group options", color = TextSecondary)
                            }
                        }
                    }
                }
                error?.let {
                    Text(it, color = Color(0xFFFFB0B0),
                        style = MaterialTheme.typography.bodySmall)
                }
                if (busy) {
                    CircularProgressIndicator(color = mode.accent, modifier = Modifier.size(22.dp))
                }
            }
        }

        // Every visible action is connected to a real service.
        Row(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            modifier = Modifier.fillMaxWidth()
                .background(Brush.verticalGradient(
                    listOf(Color.Transparent, Color.Black.copy(alpha = 0.78f)),
                ))
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 16.dp, vertical = 28.dp),
        ) {
            CreateMode.values().forEach { candidate ->
                val selected = mode == candidate
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(6.dp),
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(
                            if (selected) Brush.horizontalGradient(
                                listOf(Color(0xFF3B82F6), Color(0xFF06B6D4)),
                            ) else Brush.horizontalGradient(
                                listOf(Color.White.copy(alpha = 0.10f),
                                    Color.White.copy(alpha = 0.10f)),
                            ),
                        )
                        .clickable { mode = candidate; error = null }
                        .padding(horizontal = 16.dp, vertical = 10.dp),
                ) {
                    Text(candidate.symbol, style = MaterialTheme.typography.bodyMedium)
                    Text(candidate.label, color = if (selected) TextPrimary else TextSecondary,
                        fontWeight = FontWeight.Bold,
                        style = MaterialTheme.typography.labelMedium)
                }
            }
        }
    }
}

@Composable
private fun CreateEditorTitle(title: String, subtitle: String) {
    Column(verticalArrangement = Arrangement.spacedBy(5.dp)) {
        Text(title, style = MaterialTheme.typography.titleLarge,
            fontWeight = FontWeight.Bold, color = TextPrimary)
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = TextSecondary)
    }
}

@Composable
private fun CreateEditorField(
    value: String,
    onChange: (String) -> Unit,
    placeholder: String,
) {
    OutlinedTextField(
        value = value, onValueChange = onChange,
        placeholder = { Text(placeholder) },
        singleLine = true,
        shape = RoundedCornerShape(13.dp),
        colors = createFieldColors(),
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun createFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedContainerColor = Color.White.copy(alpha = 0.08f),
    unfocusedContainerColor = Color.White.copy(alpha = 0.08f),
    focusedBorderColor = Color.White.copy(alpha = 0.28f),
    unfocusedBorderColor = Color.White.copy(alpha = 0.12f),
    focusedTextColor = TextPrimary,
    unfocusedTextColor = TextPrimary,
    cursorColor = Color.White,
)

@Composable
private fun CreatePrimaryAction(
    label: String,
    background: Color,
    foreground: Color,
    disabled: Boolean,
    action: () -> Unit,
) {
    Box(
        contentAlignment = Alignment.Center,
        modifier = Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(background.copy(alpha = if (disabled) 0.35f else 1f))
            .clickable(enabled = !disabled, onClick = action)
            .padding(horizontal = 18.dp, vertical = 15.dp),
    ) {
        Text(label, color = foreground, fontWeight = FontWeight.Bold,
            style = MaterialTheme.typography.bodyMedium)
    }
}
