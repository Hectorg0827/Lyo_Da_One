package com.lyo.app.ui.screens.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
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
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.lyo.app.data.api.ApiClient
import com.lyo.app.data.api.BlockedAccountDto
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.theme.LyoPurple
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.launch

/**
 * The accounts this learner has blocked, each with Unblock.
 *
 * A block hides both people from each other in Discover, and it is made
 * from Report on one of their videos (ReportClipSheet). Unblocking brings
 * their videos and comments back. Mirrors web BlockedAccounts.tsx.
 */
@Composable
fun BlockedAccountsSection() {
    var accounts by remember { mutableStateOf<List<BlockedAccountDto>>(emptyList()) }
    var loading by remember { mutableStateOf(true) }
    var failed by remember { mutableStateOf(false) }
    var busyIds by remember { mutableStateOf(setOf<Long>()) }
    var message by remember { mutableStateOf<String?>(null) }
    var reloadKey by remember { mutableIntStateOf(0) }
    val scope = rememberCoroutineScope()

    LaunchedEffect(reloadKey) {
        loading = true
        failed = false
        runCatching { ApiClient.api.blockedAccounts() }
            .onSuccess { accounts = it }
            .onFailure {
                if (it is CancellationException) throw it
                failed = true
            }
        loading = false
    }

    fun unblock(account: BlockedAccountDto) {
        if (account.userId in busyIds) return
        busyIds = busyIds + account.userId
        val name = account.userName ?: "this account"
        scope.launch {
            val status = try {
                ApiClient.api.unblockUser(account.userId).code()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (_: Exception) {
                0
            }
            busyIds = busyIds - account.userId
            // 404: the block is already gone, which is what was asked for.
            if (status in 200..299 || status == 404) {
                accounts = accounts.filterNot { it.userId == account.userId }
                message = "Unblocked $name."
            } else {
                message = "Couldn't unblock $name. Please try again."
            }
        }
    }

    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(16.dp)) {
            when {
                loading && accounts.isEmpty() -> CircularProgressIndicator(
                    color = LyoPurple,
                    strokeWidth = 2.dp,
                    modifier = Modifier.size(20.dp),
                )
                failed && accounts.isEmpty() -> Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        "Couldn't load your blocked accounts.",
                        color = TextSecondary,
                        style = MaterialTheme.typography.bodyMedium,
                        modifier = Modifier.weight(1f),
                    )
                    TextButton(onClick = { reloadKey++ }) { Text("Try again") }
                }
                accounts.isEmpty() -> Text(
                    "You haven't blocked anyone. To block someone, tap Report on one of their Discover videos.",
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodyMedium,
                )
                else -> accounts.forEach { account ->
                    Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.fillMaxWidth()) {
                        Icon(Icons.Outlined.Block, contentDescription = null, tint = TextSecondary, modifier = Modifier.size(20.dp))
                        Text(
                            account.userName ?: "Learner",
                            color = TextPrimary,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                            modifier = Modifier
                                .weight(1f)
                                .padding(horizontal = 12.dp),
                        )
                        TextButton(onClick = { unblock(account) }, enabled = account.userId !in busyIds) {
                            Text("Unblock")
                        }
                    }
                }
            }
            message?.let {
                Text(
                    it,
                    color = TextSecondary,
                    style = MaterialTheme.typography.bodySmall,
                    modifier = Modifier.padding(top = 8.dp),
                )
            }
        }
    }
}
