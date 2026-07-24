package com.lyo.app.ui.screens.community

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lyo.app.ui.components.GlassCard
import com.lyo.app.ui.theme.TextPrimary
import com.lyo.app.ui.theme.TextSecondary

@Composable
internal fun InlineSourceError(
    title: String,
    message: String,
    onRetry: () -> Unit,
) {
    GlassCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.padding(14.dp)) {
            Text(
                text = title,
                style = MaterialTheme.typography.titleSmall,
                color = TextPrimary,
            )
            Text(
                text = message,
                style = MaterialTheme.typography.bodySmall,
                color = TextSecondary,
            )
            TextButton(onClick = onRetry) {
                Text("Retry")
            }
        }
    }
}
