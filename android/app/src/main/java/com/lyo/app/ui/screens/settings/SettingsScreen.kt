package com.lyo.app.ui.screens.settings

import android.content.Intent
import android.net.Uri
import android.provider.Settings
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
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.navigation.NavHostController
import com.lyo.app.BuildConfig
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
    val context = LocalContext.current

    var editingName by remember { mutableStateOf(false) }
    var nameDraft by remember { mutableStateOf(Session.user?.displayName.orEmpty()) }
    var savingName by remember { mutableStateOf(false) }
    var accountError by remember { mutableStateOf<String?>(null) }
    var showLogoutConfirmation by remember { mutableStateOf(false) }

    fun saveDisplayName() {
        if (savingName) return

        val newName = nameDraft.trim()
        if (newName.isBlank()) {
            accountError = "Display name cannot be empty."
            return
        }

        savingName = true
        accountError = null
        scope.launch {
            runCatching {
                ApiClient.api.updateProfile(UpdateProfileRequest(fullName = newName))
            }.onSuccess { updatedUser ->
                Session.updateUserLocally(updatedUser)
                editingName = false
            }.onFailure { error ->
                accountError = error.localizedMessage ?: "The display name could not be updated."
            }
            savingName = false
        }
    }

    fun openNotificationSettings() {
        val notificationIntent = Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
            putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
        }
        val fallbackIntent = Intent(
            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
            Uri.parse("package:${context.packageName}"),
        )

        runCatching { context.startActivity(notificationIntent) }
            .onFailure { context.startActivity(fallbackIntent) }
    }

    Column(
        verticalArrangement = Arrangement.spacedBy(16.dp),
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text(
            text = "Settings",
            style = MaterialTheme.typography.headlineMedium,
            color = TextPrimary,
        )

        SectionHeader("Account")
        GlassCard(modifier = Modifier.fillMaxWidth()) {
            Column(modifier = Modifier.padding(16.dp)) {
                if (editingName) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        OutlinedTextField(
                            value = nameDraft,
                            onValueChange = {
                                nameDraft = it
                                accountError = null
                            },
                            label = { Text("Display name") },
                            singleLine = true,
                            enabled = !savingName,
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
                            IconButton(onClick = ::saveDisplayName) {
                                Icon(
                                    Icons.Filled.Check,
                                    contentDescription = "Save display name",
                                    tint = LyoGreen,
                                )
                            }
                            IconButton(
                                onClick = {
                                    nameDraft = Session.user?.displayName.orEmpty()
                                    accountError = null
                                    editingName = false
                                },
                            ) {
                                Icon(
                                    Icons.Filled.Close,
                                    contentDescription = "Cancel editing",
                                    tint = TextSecondary,
                                )
                            }
                        }
                    }
                } else {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = "Display name",
                                style = MaterialTheme.typography.labelMedium,
                                color = TextSecondary,
                            )
                            Text(
                                text = Session.user?.displayName ?: "User",
                                style = MaterialTheme.typography.bodyLarge,
                                color = TextPrimary,
                                maxLines = 1,
                                overflow = TextOverflow.Ellipsis,
                                modifier = Modifier.padding(top = 2.dp),
                            )
                        }
                        IconButton(
                            onClick = {
                                nameDraft = Session.user?.displayName.orEmpty()
                                accountError = null
                                editingName = true
                            },
                        ) {
                            Icon(
                                Icons.Filled.Edit,
                                contentDescription = "Edit display name",
                                tint = TextSecondary,
                            )
                        }
                    }
                }

                accountError?.let { message ->
                    Text(
                        text = message,
                        style = MaterialTheme.typography.bodySmall,
                        color = MaterialTheme.colorScheme.error,
                        modifier = Modifier.padding(top = 8.dp),
                    )
                }

                ReadOnlyRow(label = "Email", value = Session.user?.email ?: "—")
                ReadOnlyRow(
                    label = "Username",
                    value = Session.user?.username?.let { "@$it" } ?: "—",
                )
            }
        }

        SectionHeader("Notifications")
        GlassCard(
            modifier = Modifier
                .fillMaxWidth()
                .clickable(onClick = ::openNotificationSettings),
        ) {
            ActionRow(
                icon = Icons.Filled.Notifications,
                title = "Android notification settings",
                description = "Control permission, sound, vibration, and alert visibility in the system settings that actually deliver notifications.",
            )
        }

        SectionHeader("About")
        GlassCard(modifier = Modifier.fillMaxWidth()) {
            Column {
                ActionRow(
                    icon = Icons.Filled.Info,
                    title = "Version",
                    description = BuildConfig.VERSION_NAME,
                    showChevron = false,
                )
            }
        }

        SectionHeader("Account session")
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .fillMaxWidth()
                .height(52.dp)
                .clip(RoundedCornerShape(14.dp))
                .background(LyoRed.copy(alpha = 0.15f))
                .clickable { showLogoutConfirmation = true },
        ) {
            Text(
                text = "Log Out",
                color = LyoRed,
                style = MaterialTheme.typography.titleMedium,
            )
        }

        Spacer(Modifier.height(16.dp))
    }

    if (showLogoutConfirmation) {
        AlertDialog(
            onDismissRequest = { showLogoutConfirmation = false },
            title = { Text("Log out of LYO?") },
            text = { Text("You will need to sign in again to access your account and synchronized learning progress.") },
            confirmButton = {
                TextButton(
                    onClick = {
                        showLogoutConfirmation = false
                        scope.launch {
                            Session.logout()
                            nav.navigate(Routes.LOGIN) { popUpTo(0) }
                        }
                    },
                ) {
                    Text("Log Out", color = LyoRed)
                }
            },
            dismissButton = {
                TextButton(onClick = { showLogoutConfirmation = false }) {
                    Text("Cancel")
                }
            },
        )
    }
}

@Composable
private fun ReadOnlyRow(label: String, value: String) {
    Column(modifier = Modifier.padding(top = 14.dp)) {
        Text(
            text = label,
            style = MaterialTheme.typography.labelMedium,
            color = TextSecondary,
        )
        Text(
            text = value,
            style = MaterialTheme.typography.bodyLarge,
            color = TextPrimary,
            maxLines = 1,
            overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}

@Composable
private fun ActionRow(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    title: String,
    description: String,
    showChevron: Boolean = true,
) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(16.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = LyoPurple,
            modifier = Modifier.size(24.dp),
        )
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(horizontal = 12.dp),
        ) {
            Text(
                text = title,
                style = MaterialTheme.typography.bodyLarge,
                color = TextPrimary,
            )
            Text(
                text = description,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        if (showChevron) {
            Icon(
                Icons.Filled.ChevronRight,
                contentDescription = null,
                tint = TextSecondary,
            )
        }
    }
}
