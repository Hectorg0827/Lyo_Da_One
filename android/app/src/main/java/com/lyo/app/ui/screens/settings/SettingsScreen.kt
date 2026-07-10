package com.lyo.app.ui.screens.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
import com.lyo.app.data.api.UpdateProfileRequest
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.components.SectionHeader
import com.lyo.app.ui.navigation.Routes
import com.lyo.app.ui.theme.BorderColor
import com.lyo.app.ui.theme.LyoGreen
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.launch

@Composable
fun SettingsScreen(nav: NavHostController) {
    val scope = rememberCoroutineScope()

    // Account: inline display name editing
    var editingName by remember { mutableStateOf(false) }
    var nameDraft by remember { mutableStateOf(Session.user?.displayName ?: "") }
    var savingName by remember { mutableStateOf(false) }

    // Notifications (local state)
    var notifLikes by remember { mutableStateOf(true) }
    var notifComments by remember { mutableStateOf(true) }
    var notifFollows by remember { mutableStateOf(true) }
    var notifAchievements by remember { mutableStateOf(true) }
    var notifWeeklyDigest by remember { mutableStateOf(false) }

    // Privacy (local state)
    var publicProfile by remember { mutableStateOf(true) }
    var onlineStatus by remember { mutableStateOf(true) }

    fun saveDisplayName() {
        if (savingName) return
        val newName = nameDraft.trim()
        if (newName.isBlank()) {
            editingName = false
            return
        }
        savingName = true
        scope.launch {
            runCatching {
                ApiClient.api.updateProfile(UpdateProfileRequest(fullName = newName))
            }.onSuccess { Session.updateUserLocally(it) }
            savingName = false
            editingName = false
        }
    }

    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            "Settings",
            style = MaterialTheme.typography.headlineMedium,
            color = TextPrimary,
        )

        // ── Account ──
        SectionHeader("Account")
        GlassCard(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                if (editingName) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = nameDraft,
                            onValueChange = { nameDraft = it },
                            label = { Text("Display name") },
                            singleLine = true,
                            shape = RoundedCornerShape(12.dp),
                            colors = OutlinedTextFieldDefaults.colors(
                                focusedBorderColor = LyoPurple,
                                unfocusedBorderColor = BorderColor,
                                focusedLabelColor = LyoPurple,
                                unfocusedLabelColor = TextSecondary,
                                cursorColor = LyoPurple,
                            ),
                            modifier = Modifier.weight(1f),
                        )
                        if (savingName) {
                            CircularProgressIndicator(
                                color = LyoPurple,
                                strokeWidth = 2.dp,
                                modifier = Modifier
                                    .padding(start = 12.dp)
                                    .size(20.dp),
                            )
                        } else {
                            IconButton(onClick = { saveDisplayName() }) {
                                Icon(
                                    Icons.Filled.Check,
                                    contentDescription = "Save",
                                    tint = LyoGreen,
                                )
                            }
                            IconButton(onClick = {
                                nameDraft = Session.user?.displayName ?: ""
                                editingName = false
                            }) {
                                Icon(
                                    Icons.Filled.Close,
                                    contentDescription = "Cancel",
                                    tint = TextSecondary,
                                )
                            }
                        }
                    }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                "Display name",
                                style = MaterialTheme.typography.labelMedium,
                                color = TextSecondary,
                            )
                            Text(
                                Session.user?.displayName ?: "User",
                                style = MaterialTheme.typography.bodyLarge,
                                color = TextPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(top = 2.dp),
                            )
                        }
                        IconButton(onClick = {
                            nameDraft = Session.user?.displayName ?: ""
                            editingName = true
                        }) {
                            Icon(
                                Icons.Filled.Edit,
                                contentDescription = "Edit display name",
                                tint = TextSecondary,
                            )
                        }
                    }
                }

                ReadOnlyRow(label = "Email", value = Session.user?.email ?: "—")
                ReadOnlyRow(
                    label = "Username",
                    value = Session.user?.username?.let { "@$it" } ?: "—",
                )
            }
        }

        // ── Notifications ──
        SectionHeader("Notifications")
        GlassCard(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(vertical = 4.dp)) {
                SwitchRow(
                    label = "Likes",
                    description = "When someone likes your posts or clips",
                    checked = notifLikes,
                    onCheckedChange = { notifLikes = it },
                )
                SwitchRow(
                    label = "Comments",
                    description = "When someone comments on your content",
                    checked = notifComments,
                    onCheckedChange = { notifComments = it },
                )
                SwitchRow(
                    label = "New Followers",
                    description = "When someone follows you",
                    checked = notifFollows,
                    onCheckedChange = { notifFollows = it },
                )
                SwitchRow(
                    label = "Achievements",
                    description = "When you unlock a new achievement",
                    checked = notifAchievements,
                    onCheckedChange = { notifAchievements = it },
                )
                SwitchRow(
                    label = "Weekly Digest",
                    description = "Summary of your learning week",
                    checked = notifWeeklyDigest,
                    onCheckedChange = { notifWeeklyDigest = it },
                )
            }
        }

        // ── Privacy ──
        SectionHeader("Privacy")
        GlassCard(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(vertical = 4.dp)) {
                SwitchRow(
                    label = "Public Profile",
                    description = "Anyone can view your profile and content",
                    checked = publicProfile,
                    onCheckedChange = { publicProfile = it },
                )
                SwitchRow(
                    label = "Online Status",
                    description = "Show when you're active on LYO",
                    checked = onlineStatus,
                    onCheckedChange = { onlineStatus = it },
                )
            }
        }

        // ── About ──
        SectionHeader("About")
        GlassCard(modifier = Modifier.fillMaxWidth()) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Text(
                    "Version",
                    style = MaterialTheme.typography.bodyLarge,
                    color = TextPrimary,
                    modifier = Modifier.weight(1f),
                )
                Text(
                    "1.0.0",
                    style = MaterialTheme.typography.bodyMedium,
                    color = TextSecondary,
                )
            }
        }

        // ── Danger zone ──
        SectionHeader("Danger Zone")
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(LyoRed.copy(alpha = 0.15f))
                .clickable {
                    scope.launch {
                        Session.logout()
                        nav.navigate(Routes.LOGIN) { popUpTo(0) }
                    }
                },
        ) {
            Text(
                "Log Out",
                color = LyoRed,
                style = MaterialTheme.typography.titleMedium,
            )
        }

        Spacer(Modifier.height(16.dp))
    }
}

// ── Private sub-composables ──────────────────────────────────────────────────

@Composable
private fun ReadOnlyRow(label: String, value: String) {
    Column(modifier = Modifier.padding(top = 14.dp)) {
        Text(
            label,
            style = MaterialTheme.typography.labelMedium,
            color = TextSecondary,
        )
        Text(
            value,
            style = MaterialTheme.typography.bodyLarge,
            color = TextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}

@Composable
private fun SwitchRow(
    label: String,
    description: String,
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            Text(
                label,
                style = MaterialTheme.typography.bodyLarge,
                color = TextPrimary,
            )
            Text(
                description,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onCheckedChange,
            colors = SwitchDefaults.colors(
                checkedTrackColor = LyoPurple,
                checkedThumbColor = Color.White,
                uncheckedTrackColor = Color.White.copy(alpha = 0.12f),
                uncheckedThumbColor = TextSecondary,
                uncheckedBorderColor = BorderColor,
            ),
        )
    }
}
