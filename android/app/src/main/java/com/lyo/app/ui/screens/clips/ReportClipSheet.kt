package com.lyo.app.ui.screens.clips

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.selection.selectable
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.RadioButton
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
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.BlockUserRequest
import com.lyo.app.data.api.ClipDto
import com.lyo.app.data.api.ClipReportRequest
import com.lyo.app.ui.theme.LyoRed
import com.lyo.app.ui.theme.Surface
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * Report a Discover video, or block the person who posted it.
 *
 * The same choices and rules as the web sheet (ReportClipSheet.tsx): a
 * reason, an optional note, and Block with a confirmation when
 * DiscoverSafety.canBlock allows it. What the server answers decides the
 * outcome; a failure keeps the sheet open with the choices intact.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReportClipSheet(
    clip: ClipDto,
    canBlock: Boolean,
    onDismiss: () -> Unit,
    onReported: (DiscoverSafety.Outcome) -> Unit,
    onBlocked: (DiscoverSafety.Outcome) -> Unit,
) {
    var reason by remember(clip.idStr) { mutableStateOf<String?>(null) }
    var note by remember(clip.idStr) { mutableStateOf("") }
    var sending by remember(clip.idStr) { mutableStateOf(false) }
    var blocking by remember(clip.idStr) { mutableStateOf(false) }
    var confirmingBlock by remember(clip.idStr) { mutableStateOf(false) }
    var error by remember(clip.idStr) { mutableStateOf<String?>(null) }
    val busy = sending || blocking
    val scope = rememberCoroutineScope()
    val ownerName = clip.authorName?.takeIf { it.isNotBlank() } ?: "this person"

    fun send() {
        val chosen = reason ?: return
        if (busy) return
        sending = true
        error = null
        scope.launch {
            val status = try {
                ApiClient.api.reportClip(clip.idStr, ClipReportRequest(chosen, note.trim().ifEmpty { null })).code()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                0
            }
            val outcome = DiscoverSafety.reportOutcome(status)
            sending = false
            if (outcome.succeeded) {
                onReported(outcome)
            } else {
                error = outcome.message
            }
        }
    }

    fun block() {
        val owner = clip.ownerIdStr?.toLongOrNull() ?: return
        if (busy) return
        blocking = true
        error = null
        scope.launch {
            val status = try {
                ApiClient.api.blockUser(BlockUserRequest(owner)).code()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                0
            }
            val outcome = DiscoverSafety.blockOutcome(status, ownerName)
            blocking = false
            if (outcome.succeeded) {
                onBlocked(outcome)
            } else {
                error = outcome.message
            }
        }
    }

    ModalBottomSheet(onDismissRequest = { if (!busy) onDismiss() }, containerColor = Surface) {
        Column(
            verticalArrangement = Arrangement.spacedBy(4.dp),
            modifier = Modifier
                .fillMaxWidth()
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 16.dp)
                .navigationBarsPadding(),
        ) {
            Text("Report video", style = MaterialTheme.typography.titleMedium, color = TextPrimary)
            Text(
                clip.title.orEmpty(),
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            Spacer(Modifier.height(8.dp))
            Text("What's wrong with this video?", style = MaterialTheme.typography.bodyMedium, color = TextSecondary)
            DiscoverSafety.REPORT_REASONS.forEach { option ->
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .selectable(
                            selected = reason == option.value,
                            enabled = !busy,
                            role = Role.RadioButton,
                            onClick = { reason = option.value },
                        )
                        .padding(vertical = 4.dp),
                ) {
                    RadioButton(selected = reason == option.value, onClick = null, enabled = !busy)
                    Spacer(Modifier.width(8.dp))
                    Text(option.label, color = TextPrimary)
                }
            }
            OutlinedTextField(
                value = note,
                onValueChange = { note = it.take(DiscoverSafety.NOTE_LIMIT) },
                label = { Text("Anything else we should know? (optional)") },
                enabled = !busy,
                minLines = 2,
                maxLines = 5,
                modifier = Modifier.fillMaxWidth(),
            )
            error?.let { message ->
                Text(message, color = LyoRed, style = MaterialTheme.typography.bodySmall)
            }
            Spacer(Modifier.height(4.dp))
            Button(
                onClick = { send() },
                enabled = reason != null && !busy,
                modifier = Modifier.fillMaxWidth(),
            ) {
                if (sending) {
                    CircularProgressIndicator(color = Color.White, strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                } else {
                    Text("Send report")
                }
            }
            if (canBlock) {
                HorizontalDivider(modifier = Modifier.padding(vertical = 12.dp))
                OutlinedButton(
                    onClick = { confirmingBlock = true },
                    enabled = !busy,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    if (blocking) {
                        CircularProgressIndicator(strokeWidth = 2.dp, modifier = Modifier.size(18.dp))
                    } else {
                        Icon(Icons.Outlined.Block, contentDescription = null, modifier = Modifier.size(18.dp))
                        Spacer(Modifier.width(8.dp))
                        Text("Block $ownerName")
                    }
                }
            }
            Spacer(Modifier.height(16.dp))
        }
    }

    if (confirmingBlock) {
        AlertDialog(
            onDismissRequest = { confirmingBlock = false },
            title = { Text("Block $ownerName?") },
            text = {
                Text("You won't see each other's videos or comments in Discover. You can unblock them in Settings.")
            },
            confirmButton = {
                TextButton(onClick = {
                    confirmingBlock = false
                    block()
                }) { Text("Block", color = LyoRed) }
            },
            dismissButton = {
                TextButton(onClick = { confirmingBlock = false }) { Text("Cancel") }
            },
        )
    }
}
